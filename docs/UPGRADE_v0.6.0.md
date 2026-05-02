# Upgrading to v0.6.0

> **Status:** v0.6.0 cut on 2026-05-02 (commit `5088981`). v0.6.1 follow-on
> on the same day (`983daa4`). Verify gate **722 / 722 PASS / 0 FAIL /
> 0 SKIP** at v0.6.1. Self-host fixed point md5 `98112a76…`. Self-host
> peak 568–597 MB / ~5 s wall (well under the 770 MB per-process budget;
> 1 GB e-stop is the safety kill, not a target).

**TL;DR:** v0.6.0 is the **substrate** ship — the language additions
needed before the v0.6 embedded + AI-inference theme proper can land.
Adopter-visible changes are surgical:

1. (Recursion-bounded adopters) `#[max_depth = N]` static analysis
   accepts more proven shapes (helper-guard, no-recurse-callback,
   param-flow, SCC, stride). Previously-rejected programs may now
   compile.
2. (Effects-aware adopters) `with [...]` effects-in-function-types
   substrate ships. New diagnostics `error[EFF-001..EFF-005]` (incl.
   `EFF-003: call to X requires effect 'Alloc' but caller is declared
   with [no_alloc]`).
3. (Tail-expression adopters) `fn foo() -> T { expr; }` (note the
   trailing `;` on a non-void return type) is now an `error[TYP-026]`
   instead of a silent miscompute. Previously the parser ate the `;`
   and lowered the value through to the caller despite the discard
   intent.

Everything else from v0.5.x compiles unchanged. No public ABI breaks.

This document covers v0.5.35 → v0.6.1. For the v0.5.0 atomic cut see
`UPGRADE_v0.5.0.md`.

---

## Substantive changes

### 1. `#[max_depth = N]` static analysis — extended surface (RFC-0014)

The v0.5 baseline accepted exactly one proven recursion shape:

```nucleor
#[max_depth = 100]
fn deep_traversal(depth: i64, ...) -> ... {
    if depth >= 100 { return base_case(...); }
    deep_traversal(depth + 1, ...)
}
```

v0.6.0 extends the static prover to recognise four additional
proven shapes. **`error[DEPTH-001]` no longer fires on these.**

| Shape | Fixture | What's accepted |
|---|---|---|
| **Helper guard** | `tests/features/rfc0014_max_depth_helper_guard.nr` | Entry-guard logic factored into a helper fn (`if check_depth(d, N) { return base; }`) is now traced by the prover. |
| **No-recurse callback** | `tests/features/rfc0014_max_depth_no_recurse_callback.nr` | Calling a non-recursive callback or function-pointer inside the body no longer trips the prover. |
| **Parameter flow** | `tests/features/rfc0014_max_depth_param_flow.nr` | The depth argument can flow through a let-binding (`let next = depth + 1; recurse(next, ...)`). |
| **Strongly-connected components** | `tests/features/rfc0014_max_depth_scc.nr` | Mutual recursion `f → g → f` where both members declare composing bounds is provably bounded. |
| **Stride bound** | `tests/features/rfc0014_max_depth_stride.nr` | Monotonic increment of `depth + K` (constant `K > 0`) instead of strictly `depth + 1`. |

Negative fixtures (5) lock the conservative-surface boundary:
`err_depth_001_callback_unknown`, `err_depth_001_helper_unproven`,
`err_depth_001_non_monotonic`, `err_depth_002_stride_bound`,
`err_depth_003_scc_unproven`.

**Adopter migration:** none required. If you previously suppressed
DEPTH-001 with `#[allow_fn(DEPTH-001)]` on a fn that now matches one
of the new proven shapes, the suppression becomes a no-op — leave it,
or remove it.

### 2. `with [...]` effects-in-function-types substrate (RFC-0033)

v0.6.0 ships the substrate for effects-in-function-types. Effects
that previously lived on the function as attributes (`#[no_alloc]`,
`#[no_panic]`, `#[no_dyn]`) can now appear in the function *type*:

```nucleor
fn rt_path(handler: fn(i64) -> i64 with [no_alloc, no_panic]) -> i64 {
    handler(42)
}
```

The function-type `fn(i64) -> i64 with [no_alloc, no_panic]`
encodes the effect contract at the type level, so passing a callback
that *might* allocate is rejected at the call site rather than
discovered after lowering.

**New diagnostics:**

| Code | Meaning | Fires when |
|---|---|---|
| `EFF-001` | Effect annotation on void return when caller declares non-void effect | type mismatch shape A |
| `EFF-002` | Effect set on `with [...]` includes an unknown effect | unknown effect name |
| `EFF-003` | Call requires an effect not granted by the caller's signature | the canonical "alloc inside no_alloc" case |
| `EFF-004` | `with [...]` on FFI declaration must be empty or `extern_unsafe` | FFI rule |
| `EFF-005` | Effect annotations on `Self` parameter conflict with trait declaration | trait coherence |

**Adopter migration:** none required for v0.5 code. The substrate is
opt-in — code that doesn't write `with [...]` continues to use the
attribute form. Future ships will gradually migrate stdlib
declarations to the `with [...]` form for ergonomics.

### 3. `error[TYP-026]` extended to tail-expression with eaten semi

Pre-v0.6.1 the parser silently consumed a trailing `;` on the last
expression of a fn body and the lowerer treated the kind-25 AST node
as a value-producing tail. Result: `fn nothing() -> i32 { 5; }`
returned `5` to the caller despite the `;` signalling discard intent.

v0.6.1 tracks `had_semi` on kind-25 nodes (`parse_stmt` line ~2444).
The TYP-026 check at body-tail validation now fires on
`kind-25 + had_semi==1` the same way it already fires on kind-20 (let)
and kind-21 (assign). Same diagnostic text, same always-returning RHS
escape hatch (match-with-all-arms-return, if-with-both-branches-return).

**Adopter-visible repros that now fail to compile:**

```nucleor
// Pre-v0.6.1: returned 5. Now: error[TYP-026].
fn nothing() -> i32 {
    5;
}
```

```nucleor
// Pre-v0.6.1: returned a + b. Now: error[TYP-026].
fn add(a: i32, b: i32) -> i32 {
    a + b;
}
```

**Migration:** drop the trailing `;` (turn it into a real tail
expression):

```nucleor
fn nothing() -> i32 {
    5
}

fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

…or, if the `;` was intentional (the value really should be
discarded), add an explicit `return val;` or change the signature
to `-> void`.

### 4. Memory budget — unchanged from v0.5.14

Per-process budgets remain at v0.5.14 levels:

- self-host (`compiler/nucleor_s1_compiler.nr`): **770 MB** hard cap
- tools-suite (`compiler/nucleor_tools_suite.nr`): **580 MB** hard cap
- real-time e-stop ceiling (any sample crossing → process tree killed):
  **1 GB / 1024 MB**

The e-stop is the safety kill, not a baseline. v0.5.32's NVec inline-
buffer SBO + per-fn IR free during emit dropped the actual self-host
peak to ~580–620 MB across stage1/2/3 — comfortable headroom under
the 770 MB cap. **Do not raise these caps without a documented
investigation in the same PR.**

### 5. Tooling — memory-verify optimization

v0.6.0 ships three new PowerShell helpers driven by the
effects-types-mem-tightened branch:

- `tools/rss_estop_lib.ps1` — shared library implementing the
  process-tree RSS sampler with configurable e-stop.
- `tools/run_with_rss_estop.ps1` — wraps an arbitrary command under
  the sampler.
- `tools/run_verify_rss_estop.ps1` — wraps `verify.sh` specifically;
  the recommended replacement for the older `run_with_peakmem.ps1`
  for routine ship runs.

Plus refreshed `tools/measure_peak_build.ps1` and
`tools/check_perf_regression.ps1`.

**Adopter migration:** none required. The older `run_with_peakmem.ps1`
continues to work; the new helpers are additive and expose a cleaner
contract for non-verify workloads.

---

## Bookkeeping

### Versions in this arc

| Ship | Commit | One-liner |
|---|---|---|
| v0.6.0-pre | `751a095` | merge: max-depth-extensions + effects-types-mem-tightened |
| v0.6.0 | `5088981` | cut bookkeeping (CHANGELOG + RELEASES + heartbeat + inbox question) |
| v0.6.1 | `983daa4` | typ-026 closure — expr-stmt-with-semi at fn-body tail diagnosed |

### Validation evidence

- Stage1/2/3 self-host fixed point byte-identical (md5 `98112a76…` at v0.6.1).
- Bootstrap seed `bootstrap/nucleor_s1_seed.ll` regenerated; drift gate
  5/5 OK.
- Full verify gate at v0.6.1: 722 / 722 PASS / 0 FAIL / 0 SKIP / 700 s wall.
- New surface exercised: step 715 (`RFC-0014 max_depth static analysis +
  runtime wrapper`), T3.33 RFC-0033 effects checks, plus the new TYP-026
  negative fixture `err_typ_026_tail_expr_with_semi.nr`.

### Known issue (open)

Flaky `error[OWN-008]` once-in-five on stage1 self-host of
`priv_mangle_private_fns` — heap-corruption path beyond the v0.5.32
`vec_insert_at` fix. Stage2/3 always pass. Filed in
`findings/inbox/_questions.md`. Not blocking the v0.6.0 cut.

---

## Pointers

- `CHANGELOG.md` `[0.6.0]` and `[0.6.1]` entries.
- `Desktop/Nucleor_Build_Spine/BUILD_PATH_v0.4_to_v1.3.md` §8.3 (Tracks
  X / Y / Z spike ledger), §8.7 (post-v0.5.0 closures), §8.9 (legacy
  handoff doc reconciliation).
- `docs/milestones/v0.6.0.md` (v0.6 theme: embedded targets, AI
  inference loaders, `nuc serve` MVP, ML expansion lanes E/F/G/I/J).
  These are ahead of v0.6.1 — substrate ships first, theme work next.
