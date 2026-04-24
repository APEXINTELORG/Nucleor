# Memory Architecture

How Nucleor's compiler manages allocation, why it's fast, and how
the design got there.

## Headline numbers

The s1 self-host compile (compiler builds itself from
`compiler/nucleor_s1_compiler.nr` — 485 KB source, ~10 K LOC):

| Metric                        | Value         |
|-------------------------------|--------------:|
| Tracked allocation (peak)     | **67 MB**     |
| Wall-clock                    | **5.2 s**     |
| Output (LLVM IR)              | 2.7 MB        |
| Output (executable)           | 837 KB        |
| Self-host fixed point         | byte-identical iter 2 == iter 3 |

Tools-suite compile (`compiler/nucleor_tools_suite.nr` — 822 KB
source, 1.7× larger): ~110 MB tracked, ~9 s wall-clock.

## Architecture overview

The compiler is intentionally a single-pass, batch-oriented design:

1. **Lex** — produces a flat token Vec
2. **Parse** — produces a flat AST node pool (Vec of Vec)
3. **Type-check** — walks AST, fills env Vec with `(name, type)` pairs
4. **Ownership / borrow check** — walks AST with separate `own` env
5. **Lower** — walks AST, builds IR
6. **Emit** — stringifies IR into one big SB, hands to `clang` for link

Memory cost comes from four sources, all traced via `NUC_TRACE_ALLOC=1`:

- `vec_new` — Vec headers + initial backing arrays
- `str_concat` — heap-allocated concatenation results
- `str_substring` — heap-allocated substring slices
- `sb_new` — string-builder data buffers (mostly the IR emitter)

## Key design decisions

### 1. Per-category allocation tracing (v0.2.158)

Every allocator increments a counter under `NUC_TRACE_ALLOC=1`, and an
`atexit` handler prints a five-line summary. This is the diagnostic
backbone for every memory decision below — without it, optimizations
would be guesswork.

```
[NUC_TRACE_ALLOC]
  vec_new:         800798 calls     52189216 B (   49 MB)
  str_concat:      599733 calls      4607354 B (    4 MB)
  str_substring:   218152 calls      1579789 B (    1 MB)
  sb_new:           13519 calls     12269808 B (   11 MB)
  TOTAL TRACKED:                   70646167 B (   67 MB)
```

### 2. Non-allocating prefix and positional probes (v0.2.159 + v0.2.160)

Source-scan loops were the dominant allocator. The pattern
`if str_eq(str_substring(source, i, i+tlen), target)` allocated a
substring per iteration — for a 485 KB source × thousands of scan
invocations, that totaled 9.5 GB of transient allocations.

Two helpers, both walk-the-bytes-no-allocation:

```nucleor
fn str_starts_with(s: str, prefix: str) -> i64 { ... }
fn str_eq_at(source: str, pos: i64, target: str) -> i64 { ... }
```

Eighteen call sites converted across `find_linecol_in_source`,
`type_base_name`, `is_tainted_type`, `line_contains_text`,
`source_box_binding_type`, `text_contains`, `rewrite_use_path`,
`resolve_source_with_records`, `extract_directives`, and the bench
CLI parser.

**Cost**: one critical implementation detail. The first cut of
`str_eq_at` called `str_len(source)` for a bounds check. Since
`str_len` is O(n), placing it inside an O(n) outer loop creates an
O(n²) hang — the s1 self-host went from 25 s to 5 minutes. Fixed by
omitting the source bounds check and documenting that callers'
loop bounds (`while i <= slen - tlen`) already guarantee `pos +
len(target) <= len(source)`.

**Saved**: 9.5 GB → 2 MB on `str_substring` (5,000× drop). Largest
single-ship reduction in the chain.

### 3. Structural allocator sizing (v0.2.166 + v0.2.167)

Most data structures stay tiny their whole lives. The defaults
were sized for the worst case and wasted memory on the common case:

- **String builder**: 4 KB initial → **256 B initial**
  (saved 49 MB across 13 K SBs)
- **Vec**: 16 elements initial → **4 elements initial**
  (saved 70 MB across 800 K Vecs)

Both rely on the runtime's existing realloc-doubling growth pattern
to handle the long tail of large structures correctly. The cost
is one or two extra reallocs for structures that grow past the
new initial — amortized to ~0.7 s on the 5.2 s self-host.

### 4. Identifier interner (v0.2.164) and string arena (v0.2.165)

Architectural foundations for the next memory wave:

- **`str_intern(s)`** returns a stable canonical pointer per unique
  input. Future calls with content-equal input return the SAME
  pointer; comparisons become O(1) `i64 ==` instead of O(n) byte
  walk plus possible transient allocations.
- **`str_arena_new()`** + `str_arena_concat` + `str_arena_substring`
  + `str_arena_free` provide a bump-allocated, lifetime-scoped
  alternative to global `str_concat` for transient string work.
  Caller frees the entire arena in one call at end-of-scope.

Both are wired and tested but not yet consumed by the compiler's
own type checker — that's the next architectural ship (Ship 3
"TypeId interner" in `MEMORY_FIX_PUNCHLIST.md`).

### 5. Targeted lifetime fixes (v0.2.163)

Some env-snapshot Vecs in the type checker were leaking on every
match arm / if-else branch. Re-enabled `vec_free(arm_env)`,
`vec_free(then_env)`, `vec_free(else_env)` in `type_check_stmts`
after a careful UAF audit confirmed the type pass's snapshots have
bounded lifetime (the recursive `type_check_stmts` consumes them
fully before the next iteration).

The check-pass siblings (`own_restore`, `own_merge_moved` called
from `check_expr`) are NOT yet free-eligible — those env Vecs
have references held by downstream check helpers that need to be
audited first. Kept disabled with a documented reason.

## How the gate enforces memory budget

`tools/verify.sh` runs the s1 self-host with `NUC_TRACE_ALLOC=1`
and parses the `TOTAL TRACKED` line. If allocation exceeds the
budget (currently **100 MB**, ratcheted down from 400 → 250 → 100
across v0.2.161, v0.2.166, v0.2.167), the gate fails with
diagnostic guidance:

```
       FAIL: self-host compile used NN MB; budget MM MB
       Recent changes may have re-introduced an allocate-then-discard pattern.
       Run NUC_TRACE_ALLOC=1 bin/nucleor.exe build compiler/nucleor_s1_compiler.nr --no-cache
       to see per-category breakdown.
```

This is the standard production-compiler regression-prevention
pattern (LLVM's `buildbot-track`, Rust's `rustc-perf`) adapted to
a single-binary self-host.

## Cumulative reduction

The compiler self-host went from a 19 GB blow-up that crashed
overnight CI runs to a 67 MB compile that fits comfortably in any
laptop's L3 cache.

| Stage              | Tracked  | Wall-clock | Notes                              |
|--------------------|---------:|-----------:|------------------------------------|
| Pre-fix baseline   | 19 GB    | 25 s       | Caused OOM cascades during the gate |
| v0.2.159           | 185 MB   | 4.5 s      | str_eq_at landed                   |
| v0.2.166           | 137 MB   | 4.5 s      | SB cap tuned                       |
| v0.2.167           | **67 MB**| **5.2 s**  | Vec cap tuned                      |
| **Cumulative**     | **283×** | **~5×**    | **memory · speed**                 |

## How to investigate a regression

1. Run the gate. If `self-host memory budget` step fails:

   ```
   NUC_TRACE_ALLOC=1 bin/nucleor.exe build compiler/nucleor_s1_compiler.nr --no-cache
   ```

2. Compare the per-category output against the baseline above.
   Whichever line jumped is the responsible category.

3. For `str_substring` regressions: search for the
   `str_eq(str_substring(...))` anti-pattern in your diff and
   replace with `str_starts_with` (prefix probe) or `str_eq_at`
   (positional probe).

4. For `vec_new` regressions: a new fn allocating Vecs in a hot
   loop. Consider lifting the Vec out of the loop and reusing
   via `vec_clear`, or pre-sizing if the final length is known.

5. For `sb_new` regressions: a new code path creating SBs in a
   loop, or one that should hold a single SB across many appends
   instead of creating new ones.

## What's deferred

Tracked in `MEMORY_FIX_PUNCHLIST.md`:

- **Ship B: TypeId interner.** Replace stringly-typed types with
  canonical type IDs. Estimated additional reduction: 67 MB → ~50 MB
  + significant speedup for type comparisons.
- **Ship D2: type-checker arena migration.** Move the type
  checker's transient diag-message construction onto the v0.2.165
  string arena. Estimated additional reduction: ~5 MB plus removal
  of small `str_concat` leaks.
- **Check-pass UAF audit.** Identify all downstream consumers of
  `own_restore` / `own_merge_moved` snapshots, then re-enable the
  free pattern. Estimated additional reduction: ~10 MB.

Each has a clear test target (the gate's 100 MB budget will
ratchet down further as each ships) and a clear correctness
target (the self-host fixed point and the 248-step gate).
