# Lane 3 / Queue 3B — `#[deadline]` syntax, numeric bound, and certified-WCET audit

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Branch:** `probe/rt-deadline-numeric-wcet-audit-v0845`
- **Base:** `origin/main` @ `c1eea2e9`
- **Scope:** Probe / audit only. No compiler change in this branch.

## Headline

`#[deadline = N]` parsing, source-rewrite, and runtime enforcement are
all live and correct on the current ship. The compile-time check that
fires when the body looks expensive (RT-004) is **explicitly NOT**
certified WCET — the author labelled it a "fast, conservative
heuristic" in v0.8.289 (line 17307). Numeric validation of the literal
`N` is partially closed: the parser accepts the attribute, the
T3.1 wrapper-rewrite drops `deadline_check(__nuc_dl_start, N)` into
the body, and the runtime aborts on overrun. What is missing for v1.0:

1. **Hard validation of `N`.** Today `#[deadline = 0]` and
   `#[deadline = -N]` parse silently, then RT-004 either always fires
   (estimate > 0 > 0) or never fires (negative limit), without an
   intent-level diagnostic. Smallest fix is a parse-time CONTRACT-
   style gate that rejects non-positive `N`.
2. **Certified WCET backing.** The audit verdict (RFC-0001 §WCET,
   referenced in line 17313) explicitly defers a certified cost-table
   contract to Phase 2. **No certified routine-cost table exists in
   the OSS tree today.** Producing one requires per-ISA opcode +
   memory-tier + branch-prediction modelling and is a research-grade
   workstream — out of scope for v1.0. The smallest v1.0-safe close
   is to **fence** the certified-WCET claim: hard-error if an adopter
   passes `--cert` (or `NUCLEOR_DBC_MODE=cert`) on a build that
   contains `#[deadline]` annotations, until the cost table lands.

## Current shipped state

### Parse + source rewrite

- Attribute syntax: `#[deadline = N]` where N is an integer literal in
  microseconds. Accepted by the lexer + attribute parser at
  `parse_fn_attrs` time (no audit issues).
- T3.1 wrapper-rewrite (line 33503): splits a `#[deadline = N]` fn
  into a synthesized inner `__nuc_dl_inner_<name>` and a wrapper that
  records `__nuc_dl_start := time_monotonic_us()`, calls the inner,
  and runs `deadline_check(__nuc_dl_start, N)` after the body
  completes. Both fns are visible in the resolved source after the
  rewrite — the static estimator scans for the wrapper's
  `deadline_check(__nuc_dl_start,` substring to discover deadline-
  carrying fns (`wcet_collect_deadline_fns`, line 17343).
- LLVM bridge: `compiler/nucleor_s1_compiler.nr:6968` maps
  `deadline_check` to `__nucleor_deadline_check`; the IR emit pass
  declares it via `declare i64 @__nucleor_deadline_check(i64, i64)`
  (line 8793).

### Static enforcement

| Check | Code | Class | What it does |
|---|---|---|---|
| RT-004 | `enforce_static_wcet` (line 18554) | warning | Heuristic unit estimator vs declared limit_us |
| RT-007 | `enforce_deadline_safety` (line 18584) | warning | `#[deadline]` without `#[no_alloc]` or `#[no_panic]` |
| RT-008 | `enforce_rt008_recursion` (line 17158) | warning | Direct self-recursion in `#[deadline]` fn |
| RACE-007 | `enforce_deadline_with_await` (line 17831) | error | `#[deadline]` + `async_await(...)` combo (the deadline checker can't see past actor executor boundary) |

The RT-004 heuristic explicitly disclaims certified WCET (lines
17304-17340). It models:
- Each `;` = 1 unit = 0.1 µs.
- `while` keywords multiply (1, 100, 1000, 10000 for 0/1/2/3+ whiles).
- 1e6 unit cap.
- **No callee inlining** — a `O(n)` helper inside a tight loop is
  invisible.
- **No ISA / cache / branch-prediction modelling.**
- String-literal `;` and comment-`while` are NOT skipped (accepted
  v1 false-positive surface).

### Runtime enforcement

`stdlib/runtime/nucleor_llvm_rt.c:6148` `__nucleor_deadline_check`:

```c
long long __nucleor_deadline_check(long long start_us, long long limit_us) {
    long long now = __nucleor_time_monotonic_us();
    long long elapsed = now - start_us;
    if (elapsed > limit_us) {
        fprintf(stderr, "error[RT-004]: #[deadline] overrun: elapsed %lld us > limit %lld us\n",
                elapsed, limit_us);
        fflush(stderr);
        exit(1);
    }
    return 0;
}
```

Correct: monotonic timer subtraction, hard abort on overrun. No
silent fall-through in the runtime path.

## Probe results (current main, no source change)

| Probe | Result | Class |
|---|---|---|
| `#[deadline = 100] fn f() { let x = 1; }` (well-formed positive) | builds; no diagnostic; runtime passes | covered |
| `#[deadline = 0] fn f() { … }` | builds; RT-004 fires (heuristic 0.1 µs ≥ 0) — but for the **wrong reason** (intent-level zero limit, not heuristic overrun) | **gap A** |
| `#[deadline = -10] fn f() { … }` | builds; runtime never fires (`elapsed > -10` is always false unless overflow) | **gap B** — silent fall-through |
| `#[deadline = 100000] fn f() { while ... { while ... { while ... { ... } } } }` | RT-004 fires (3 whiles → 1000× multiplier) — heuristic working | covered |
| `#[deadline = 100000] fn f() { helper(); }` where `helper()` allocates 1 GB | builds; no diagnostic — call target invisible to estimator | **gap C** — by-design heuristic limitation |

## What "numeric validation" specifically means and what is missing

**Missing for v1.0 (cheap closes):**

1. **CONTRACT-013 — `#[deadline = N]` requires N > 0.** Parse-time
   fail-closed reject for `N <= 0`. ~10 LOC in
   `parse_fn_attrs` (or the deadline-attr collector, whichever
   handles the literal). Fixture: `tests/err/err_deadline_zero.nr`,
   `tests/err/err_deadline_negative.nr`.
2. **CONTRACT-014 — `#[deadline]` literal must fit in `i64` µs.**
   Reject `#[deadline = 9999999999999999999]` at parse time. Same
   place. Fixture: `tests/err/err_deadline_overflow_literal.nr`.
3. **CONTRACT-015 — `#[deadline]` literal must be a literal, not an
   expression.** Currently the parser accepts `#[deadline = N]` only
   when N is a numeric literal; reject anything else explicitly with
   a clear diagnostic instead of a generic parse error. Fixture:
   `tests/err/err_deadline_non_literal.nr`.

**Missing for certified WCET (Phase 2 — out of scope for v1.0):**

A real cost table requires:

- Per-ISA opcode latencies (x86_64, aarch64, riscv64 minimum).
- Per-memory-tier load/store costs (L1, L2, L3, DRAM).
- Branch-prediction model (taken vs not-taken cost delta).
- Calling-convention overhead model.
- Per-stdlib-rod cost annotations (`Vec::push` is `O(1)` amortized
  but `O(n)` worst-case at growth boundaries — needs both rows).
- A certifier that stitches all of the above into a sound
  upper-bound proof.

This is research-grade infrastructure. No subset of it ships in v1.0.

## Smallest v1.0-safe fail-closed rule for the certified surface

The handoff explicitly asks: "Do not fabricate WCET. If no certified
routine-cost table exists, write the blocker and specify the table
shape."

### Blocker

There is no certified routine-cost table in the OSS tree today. The
v0.8.289 audit (referenced in `compiler/nucleor_s1_compiler.nr:17307`)
confirms the heuristic is NOT certified WCET. The closure path is
research-grade and not v1.0-feasible.

### Required table shape (for whoever implements Phase 2)

Recommended on-disk layout: `cost-table/<isa>.toml` per supported ISA,
loaded at compile time by an opt-in pass.

```toml
# cost-table/x86_64.toml
[meta]
isa = "x86_64"
microarch = "skylake"     # default conservative profile
units = "ns"              # 1 unit = 1 ns at 4 GHz
last_validated = "2026-05-07"

[opcode.add_i64]
nominal = 0.25
worst_case = 0.25         # nominal == worst_case for fixed-latency ops

[opcode.div_i64]
nominal = 6.0
worst_case = 24.0         # variable-latency

[opcode.load_i64]
nominal = 1.0             # L1 hit
worst_case = 70.0         # L3 miss → DRAM

[branch.taken]
predicted = 0.25
mispredicted = 5.0

[stdlib.Vec::push]
nominal = 1.0             # amortized
worst_case = "O(n)"       # marker — caller must bound n

[stdlib.println]
nominal = 1500.0          # syscall cost varies wildly
worst_case = "external"   # marker — caller must use #[no_io] or
                          # accept unbounded
```

The certifier consumes this table + the resolved-source AST to
produce a sound upper-bound estimate. Any opcode/stdlib entry marked
`"external"` or `"O(n)"` requires an explicit adopter assertion to
proceed; otherwise the certifier fails closed.

### v1.0-safe fence

Until the table lands, fence the `--cert` build mode (`NUCLEOR_DBC_MODE=cert`)
to **error** if any `#[deadline]` annotation is in the resolved source:

```
error[CONTRACT-016]: certified build mode (NUCLEOR_DBC_MODE=cert) is
not supported on sources containing `#[deadline = N]` because
certified WCET requires a per-ISA cost-table contract that has not
shipped (RFC-0001 Phase 2). For runtime deadline enforcement use
debug or safe-release mode; for design-time analysis, the heuristic
RT-004 warning still fires under those modes.
```

This is a one-fn, ~15 LOC compiler change. Drops a misleading
"certified" claim, keeps the runtime check available in non-cert
modes.

## Recommendation

- **For v1.0 ship (this lane):**
  - Ship CONTRACT-013/014/015 (parse-time numeric validation, ~30
    LOC + 3 fixtures). Eliminates `gap A` and `gap B` above.
  - Ship CONTRACT-016 cert-mode fence (~15 LOC + 1 fixture).
  - Keep RT-004 heuristic warning unchanged. Disclaimer language is
    already correct in source and banner.
- **Defer to Phase 2 (post-v1.0):**
  - Per-ISA cost-table format + loader.
  - Certifier pass.
  - Stdlib opcode cost annotations.
  - Adopter `#[wcet_assert(...)]` syntax for unbounded ops.

## Stop reason

Per handoff §Lane 3 / Queue 3B: "Do not fabricate WCET. If no
certified routine-cost table exists, write the blocker and specify
the table shape." This branch is probe/audit only. Implementation of
CONTRACT-013/014/015/016 is a separate fix branch
(`fix/rt-deadline-numeric-validation-v0845` recommended); the
certified-WCET cost table is Phase 2.

## Honest residuals

1. **Probes were Windows-host only.** A Linux re-run after CONTRACT-013
   ships should re-confirm baselines.
2. **No fixtures lock the gap-A / gap-B silent-fall-through cases.**
   Adding negatives requires the CONTRACT-013/014 patch first
   (otherwise they'd EXPECT errors against current-pass behavior).
3. **The runtime overflow path** (`elapsed > limit_us` arithmetic
   when `start_us` is near `INT64_MAX`) was not probed in this
   audit. Theoretical: `__nucleor_time_monotonic_us` returns a
   value derived from CLOCK_MONOTONIC which doesn't reach INT64_MAX
   in practice (would require ~292 millennia of uptime). Not a
   v1.0 blocker but worth a comment in the runtime.
