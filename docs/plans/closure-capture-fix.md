# Plan: Closure Capture Correctness (Production-Ready)

**Branch:** `claude/closure-capture-fix` (off `origin/main` @ a8a6548)
**Author:** development working plan
**Status:** drafting → execution

## 0. TL;DR

The current closure capture runtime is process-global state keyed by the
*closure literal's lex-time id*. Two closures produced from the same literal
share storage, so any subsequent call to the producing function stomps the
prior closure's captures. This is a correctness bug, demonstrated by the
failing repro at `tests/lang/closure_capture_recursion.nr` (committed on this
branch). There is also a secondary codegen bug: `cap_id` is passed the value
of `clo_id` rather than the per-capture slot index, so even multi-capture
closures collide on slot 0.

The fix is to give each *closure value* its own captures, threaded through
the indirect call ABI as an environment handle. This plan:

1. Locks the failing test surface.
2. Replaces the per-literal table with per-instance environments.
3. Threads the environment handle through closure-typed function pointers and
   indirect calls.
4. Holds the cold-compile budget — measured baseline on this Linux env is
   ~5.4–6.4s for the self-host compile; the gate to beat is the Windows
   release gate of 3.95s on its own hardware. We measure on every change.

## 1. Evidence — Bug Confirmed

### 1.1 Repro
`tests/lang/closure_capture_recursion.nr`:

```nr
fn make_doubler(k: i64) -> i64 {
    let g: i64 = |x| x * k;       // captures k
    return g;
}
fn main() -> i64 {
    let g10:  i64 = make_doubler(10);
    let g100: i64 = make_doubler(100);
    let a: i64 = apply(g10,  2);  // expected 20
    let b: i64 = apply(g100, 2);  // expected 200
    // observed: a=200, b=200
}
```

Observed on this branch: `got a=200, b=200` (exit code 1, FAIL).

### 1.2 Root cause in IR

`make_doubler` emits, on every call, into the same global slot:

```
%r.3 = load i64, ptr %r.0                         ; load k
%r.4 = add  i64 0, 0                              ; clo_id = 0 (constant)
call  i64 @__nucleor_capture_set(i64 %r.4,        ; clo_id = 0
                                 i64 %r.4,        ; cap_id = 0 (BUG: reused clo_id)
                                 i64 %r.3)        ; value = k
%r.7 = ptrtoint ptr @__closure_0 to i64           ; return fn ptr
```

And `__closure_0` reads:

```
%r.3 = add  i64 0, 0
call  i64 @__nucleor_capture_get(i64 %r.3, i64 %r.3)   ; clo_id=0, cap_id=0
```

So:

- The slot index `(clo_id, cap_id)` is *static* for the closure literal.
- The closure value returned (`@__closure_0`) is a bare function pointer; no
  per-instance state.
- Two `make_doubler` calls share `g_capture_table[0][0]`. Last writer wins.
- The reused `clo_id`/`cap_id` typo means within a single closure, multiple
  captures would alias on slot 0 too.

### 1.3 Runtime storage

`stdlib/runtime/nucleor_llvm_rt.c:8676-8712`:

```c
#define NUC_MAX_CLOSURES 8192
#define NUC_MAX_CAPTURES 32
static long long g_capture_table[NUC_MAX_CLOSURES][NUC_MAX_CAPTURES];
long long __nucleor_capture_set(long long clo_id, long long cap_id, long long value);
long long __nucleor_capture_get(long long clo_id, long long cap_id);
```

Comment is explicit: "Calling the same closure from multiple threads with
different capture values is undefined." Recursion is even worse and is *not*
disclosed.

### 1.4 Cold-compile baseline (Linux, this branch, 5 runs)

```
run 1: 5.595s
run 2: 6.416s
run 3: 5.612s
run 4: 5.580s
run 5: 5.408s
```

Windows release gate: cold 3.95s, ceiling 4.25s, hot 0.12s, RSS 352 MB
(`docs/benchmarks.md`). Linux gate is correctness-only today; this is the
working baseline for this branch.

## 2. Target Design

### 2.1 Closure value representation

A closure value becomes a **heap-allocated environment record**:

```
struct NucClosureEnv {
    i64  fn_ptr;       // address of the closure body function
    i64  cap_count;    // number of captured slots
    i64  caps[cap_count];
};
```

The closure body's first parameter is an **env pointer** (passed as `i64`,
consistent with the i64-everywhere ABI). It reads captures by offset from
that pointer, not from a global table.

A closure value at the surface remains a single `i64` — the pointer to its
`NucClosureEnv`. This keeps the surface ABI (`let f: i64 = |x| ...;`) and the
existing higher-order call surface unchanged.

### 2.2 Allocation site

The closure *literal* — the place in source where `|args| body` is evaluated
— is where the env record is materialized. Every evaluation produces a fresh
allocation with a fresh capture snapshot.

Closures continue to capture *by reference of value* (the current semantics
documented at `compiler/nucleor_s1_compiler.nr:2518`). That means at literal
evaluation time, the current values of the captured locals are copied into
`env->caps[i]`. This matches today's behavior; it is **not** a move-capture
or upvalue-cell semantics change. `move` closures stay rejected as today
(`compiler/nucleor_s1_compiler.nr:2523`).

### 2.3 Indirect call

Today `ir_indirect_call(d, closure_reg, args)` lowers to a direct call to a
function pointer with no env (`compiler/nucleor_s1_compiler.nr:6300`).

New form: at the call site,

1. Load `fn_ptr` from `closure_reg + 0` (the env record's first slot).
2. Call that function pointer with `closure_reg` prepended to `args`.

Direct, non-closure indirect calls (function pointers without env) are
detected by structural shape: a function pointer stored as a raw symbol
address still works — we add a small disambiguation tag (see §2.4).

### 2.4 Function-pointer-vs-closure disambiguation

Today the language conflates "function pointer" and "closure" — both are
`i64`. The user-visible surface stays the same. Internally:

- A **bare function pointer** value (taken via `let f = some_fn_name;`) is
  an `i64` whose low bit is `0` and whose high bits are the function's text
  address.
- A **closure value** (from a `|args| body` literal) is an `i64` whose low
  bit is `1` and whose remaining bits are `env_ptr | 1`.

The indirect call site:

```
if (raw & 1) {
    env_ptr = raw & ~1
    fn_ptr  = *(i64*)env_ptr
    call fn_ptr(env_ptr, args...)
} else {
    call raw(args...)               // bare fn-ptr path, no env
}
```

Allocations are always 8-aligned, so the low bit is free. This is the same
trick OCaml uses for unboxed int vs pointer values; safe with malloc.

Cost: one branch + one extra arg per indirect call. The branch is highly
predictable (closure vs fn-ptr distribution is stable per call site) and
should fold to a single predicted path in practice.

### 2.5 Lifetime

`NucClosureEnv` is heap-allocated. A closure value's lifetime equals its
referent's lifetime. To stay aligned with the existing ownership model
(`Vec` and `str` use straightforward refcount-and-move semantics,
`docs/architecture.md:155-157`):

- Phase 1: leak. Closures are heap-allocated and never freed. The s1
  compiler creates a bounded number of closures (`< 200` per the runtime
  comment); the leak is bounded and acceptable for v1.1.1.
- Phase 2 (deferred to a follow-up): teach the ownership checker that
  closure values are heap-owned, so `Drop` runs at scope end. Out of scope
  for this branch.

This matches today's semantics — closures already implicitly leak the
per-literal global slots; we are not introducing a new leak, we are
formalizing one we already had.

### 2.6 Backward compatibility

- Non-capturing closures (zero captures) continue to work: env record is
  `{fn_ptr, cap_count=0}`, body never reads captures.
- Existing tests in `tests/lang/closures.nr` (all non-capturing) keep
  passing unchanged.
- Existing `cap_id`-using sites in user code: the only such code today is
  the s1 compiler's own emitted output for capturing closures; the
  internal codegen change handles both sides at once.
- The legacy `__nucleor_capture_set` / `__nucleor_capture_get` are kept
  as a transitional shim — implemented as no-ops returning their input
  value — so any pre-fix `.ll` that links against a new runtime keeps
  building. Both helpers can be deleted after one release cycle.

## 3. Implementation Order

Each step is independently testable, perf-measurable, and revertible. We do
not merge a later step until the earlier one is green.

### Step A — Lock the failing test surface
- `tests/lang/closure_capture_recursion.nr` (already added) — fails today.
- Add `tests/lang/closure_capture_multi_slot.nr` — single closure with two
  distinct captures, proves the `cap_id` reuse bug.
- Add `tests/lang/closure_capture_nested.nr` — closure inside a closure,
  inner captures outer's binding.
- Add `tests/lang/closure_capture_recursive_call.nr` — capturing closure
  invoked from a function that re-enters its producing function.
- Add `tests/lang/closure_capture_pass_back.nr` — capturing closure passed
  through a higher-order function, called after another capturing closure
  was created from the same literal.
- Wire each into `tools/verify.sh` as a new step under the existing
  `tests/lang` block. **Each test should FAIL** before steps B–E land.

### Step B — Runtime: env record allocator
- Add `__nucleor_closure_env_new(i64 fn_ptr, i64 cap_count) -> i64` in
  `stdlib/runtime/nucleor_llvm_rt.c`. Allocates `8 * (2 + cap_count)`
  bytes, stores `fn_ptr` at `[0]`, `cap_count` at `[1]`, leaves caps
  slots uninitialized.
- Add `__nucleor_closure_env_set_cap(i64 env, i64 idx, i64 val) -> i64`.
- Add `__nucleor_closure_env_get_cap(i64 env, i64 idx) -> i64`.
- Add `__nucleor_closure_box(i64 env) -> i64` — applies the low-bit tag.
- Add `__nucleor_closure_unbox(i64 raw) -> i64` — strips the low-bit tag,
  returns `env`.
- Keep legacy `__nucleor_capture_set`/`__nucleor_capture_get` as no-op
  shims with a one-line deprecation comment.

Acceptance: runtime compiles standalone, no codegen change yet, all existing
tests stay green, baseline cold-compile unchanged.

### Step C — Codegen: closure literal lowering
In `compiler/nucleor_s1_compiler.nr` (search for the closure-literal lowering
path — `__nucleor_capture_set` emission around lines 32602, 33694):

- Replace per-literal id assignment with a per-literal **capture descriptor**
  (an ordered list of captured local names with their resolved registers).
- At literal evaluation site, emit:
  ```
  env = __nucleor_closure_env_new(<fn_addr>, <cap_count>)
  for each captured local i:
      __nucleor_closure_env_set_cap(env, i, <captured_reg>)
  raw = __nucleor_closure_box(env)
  ```
- `raw` is the closure value.

Acceptance: capturing closures route through env_new/set_cap; the
`cap_id`-reuse typo is gone by construction (we now index by the descriptor
slot, not by a register that aliased clo_id).

### Step D — Codegen: closure body lowering
- The body function gains a leading `i64 %env` parameter.
- Every read of a captured binding lowers to
  `__nucleor_closure_env_get_cap(%env, <slot>)`.
- The closure body knows its captures from the descriptor populated in step
  C; the slot indices match.

### Step E — Codegen: indirect call dispatch
In `compiler/nucleor_s1_compiler.nr` (search `ir_indirect_call`,
line 6300, and its emit path):

- Lower an indirect call `f(args...)` as:
  ```
  raw  = <closure_reg>
  tag  = raw & 1
  br tag != 0, %closure_path, %fn_ptr_path
  closure_path:
      env    = __nucleor_closure_unbox(raw)
      fn_ptr = load i64, ptr env, align 8       ; offset 0
      r_clo  = call fn_ptr(env, args...)
      br %join
  fn_ptr_path:
      r_fn   = call raw(args...)                ; legacy fn-ptr ABI
      br %join
  join:
      r = phi [r_clo, %closure_path], [r_fn, %fn_ptr_path]
  ```
- This adds one conditional branch + one phi per indirect call. The
  closure_path is two extra ops (unbox + load) vs the current direct call.

Acceptance: `tests/lang/closures.nr` (existing non-capturing tests) stays
green; new capturing tests turn green; self-host fixed-point check still
holds because we rebuild the seed in step F.

### Step F — Self-host fixed-point reset
- Rebuild stage-1 from the seed.
- Rebuild stage-2 from stage-1.
- Verify stage-1 IR == stage-2 IR (`tools/check_self_host_md5.sh`).
- **If fixed point holds**: regenerate `bootstrap/nucleor_s1_seed.ll` from
  stage-2 and commit the new seed. The seed will change (we emit different
  IR for closures now), so this is expected.
- **If fixed point fails**: investigate before continuing — every closure
  in the compiler itself just changed lowering, so a missed code path
  shows here.

### Step G — Documentation
- Update `docs/language-reference.md` §3 to document closure semantics
  precisely (capture-by-value-snapshot, per-instance environment,
  recursion-safe, **not** thread-safe).
- Add `docs/internals/closures.md` with the env layout, the tag bit, the
  ABI for closure body functions, and the rationale.
- Add a CHANGELOG entry under `### Fixed` for v1.1.1.
- Mark `__nucleor_capture_set`/`__nucleor_capture_get` deprecated in
  `stdlib/runtime/nucleor_llvm_rt.c` with a removal version.

### Step H — Verifier + drift wiring
- Add the new helper symbols to whatever helper manifest the drift checks
  read (`docs/rfcs/helper_manifest.toml` / `tools/gen_helper_manifest.nr`).
- Add a new verify.sh step "closures capture per-instance" that runs the
  new test set.
- Confirm `tools/verify.sh` still hits `PASS=1653 + new` with `FAIL=0`.

## 4. Perf Measurement Protocol

Cold-compile is the gated metric. We measure at three checkpoints: pre-fix
baseline, post-step-E (codegen changed), post-step-F (new seed).

### 4.1 Procedure
Linux, this environment:

```bash
for i in 1 2 3 4 5; do
    rm -rf target/.nuc_cache_v2 target/.nuc_native_cache .nuc_cache target/_perf 2>/dev/null
    sync
    T1=$(date +%s.%N)
    ./bin/nucleor build compiler/nucleor_s1_compiler.nr -o target/_perf --no-cache >/dev/null 2>&1
    T2=$(date +%s.%N)
    awk "BEGIN{printf \"run $i: %.3fs\n\", $T2-$T1}"
done
```

Record median of 5. Linux hosted is noisy, so we also record min.

### 4.2 Targets
- **Hold or beat 5.40s median** on this Linux env (current min).
- **Hold or beat Windows 3.95s cold-compile** on the release workstation.
- If a step regresses by > 5% on Linux median, stop and investigate before
  the next step. Do not paper over with later optimizations.

### 4.3 Sources of regression to watch
- Step C/D: extra runtime calls per closure literal/body. The s1 compiler
  has < 200 closures, so this is dozens of extra IR instructions in the
  emitted compiler — negligible at compile time of the compiler's
  *output*, but the compiler *itself* now emits and runs through more IR
  during its own self-build. Bound: < 5000 added IR instructions in the
  compiler's emitted form, vs `optimized: 2442 instructions` total today
  (so worst case ~3x, but those instructions are short).
- Step E: indirect call grows from 1 op to ~5 ops. The s1 compiler has
  a small number of indirect-call sites; the cost surfaces in user code,
  not compile time. Measure both.
- Heap allocations at closure creation: `__nucleor_closure_env_new` is
  called once per closure literal evaluation. In the s1 compiler self-
  build path, this fires < 200 times — irrelevant to cold-compile.

### 4.4 Compile-time-favorable optimizations we will also apply

We are touching the compiler. While we are there, apply the following only
*after* the correctness change is green and only if measurable:

1. **Inline the runtime call sequence** at codegen time when `cap_count`
   is statically known (always today) — emit raw `getelementptr` + `store`
   instead of a `call __nucleor_closure_env_set_cap` per slot. This is
   strictly faster than the helper-call form and removes call overhead
   from the emitted IR.
2. **Stack-allocate envs** when escape analysis proves the closure does
   not outlive its enclosing scope. **Deferred** — needs escape analysis
   infra that does not exist; out of scope for this branch.

Only #1 lands in this branch. Cold-compile expectation: neutral to
slightly faster, because raw IR is shorter and clang lowers it cleanly.

## 5. Acceptance Criteria (100% production-ready definition)

This branch is mergeable when **all** of the following are true:

1. All five new closure-capture tests pass on Linux and Windows.
2. `tests/lang/closures.nr` (existing) still passes unchanged.
3. `tools/check_self_host_md5.sh` reports fixed-point and seed match.
4. `tools/verify.sh` reports `FAIL=0` with the new steps counted.
5. Linux cold-compile median ≤ 5.40s (current min) over 5 runs.
6. Windows cold-compile remains ≤ 4.25s ceiling and ideally beats 3.95s.
7. Windows verifier reports `FAIL=0` (target ≥ `PASS=1658`).
8. `tests/lang/closure_capture_recursion.nr` prints `OK
   closure_capture_recursion` and returns 0.
9. `__nucleor_capture_set`/`__nucleor_capture_get` are documented as
   deprecated and present as no-op shims.
10. `docs/language-reference.md`, `docs/internals/closures.md`, and
    `CHANGELOG.md` updated.
11. Bootstrap seed regenerated, committed, and reproduced from stage-2.
12. No new `// v0.x.y:` history comments added inside the compiler source
    — write rationale in `docs/internals/closures.md` instead. (We are
    *not* perpetuating the optics anti-pattern flagged in the critique
    analysis, even on our own fix.)

## 6. Risks and Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Self-host fixed-point fails after codegen change | Medium | Step F is gated. We diff stage-1 vs stage-2 IR by hand if it fails; the deltas will be confined to the closure lowering. |
| Cold-compile regresses > 5% | Low | Bound is small (the change is local to a few codegen functions). If it does regress, fall back to the inline-IR form (§4.4 #1) which is faster than the helper-call form. |
| Tag-bit collision with a legitimate fn-ptr address | Negligible | Function addresses are at least 4-byte aligned on x86_64; low bit is reserved. Verified by emitting `align 16` on closure body functions. |
| Heap leak grows | Low | The s1 compiler creates < 200 closures per build. The user-program leak surface matches the current global-table semantics in steady state. Phase 2 ownership integration is a follow-up. |
| Legacy `.ll` files in the wild link-break | Low | Shim functions keep the old symbol names valid until next release. |
| Windows perf hardware unavailable in this environment | Certain | We measure Linux as a relative gate. Windows numbers gathered before final tag. If Windows regresses, hold the tag. |

## 7. Out of Scope (Tracked for Follow-Up Branches)

These are the other Tier-1 / Tier-2 items from
`docs/critique-analysis.md`. They are **deliberately not in this branch**
to keep blast radius small and perf gating sharp:

- Typed scientific wrappers (newtypes for `Matrix`, `QState`, `f64`) — own
  branch.
- Runtime benchmarks vs Julia / FFTW / dgesv — own branch.
- Data-driven `get_rt_name` dispatch — own branch.
- Compiler file split — own branch, only after the above three land.
- Version-stamp comment extraction — own branch, mechanical.
- Tagged verifier breakdown — own branch.
- Linux-emitted bootstrap seed — own branch.

## 8. Execution Order Checklist

- [x] Cut branch off `origin/main`
- [x] Baseline cold-compile measured (5.40–6.42s, median 5.59s, Linux)
- [x] Failing repro committed (`tests/lang/closure_capture_recursion.nr`)
- [ ] Step A — full failing test surface added + wired into verifier
- [ ] Step B — runtime env-record helpers in `nucleor_llvm_rt.c`
- [ ] Step C — codegen: closure literal lowering
- [ ] Step D — codegen: closure body parameter + capture reads
- [ ] Step E — codegen: indirect call dispatch
- [ ] Cold-compile re-measured after step E
- [ ] Step F — self-host fixed-point reset + seed regenerated
- [ ] Cold-compile re-measured after step F
- [ ] Step G — documentation updated
- [ ] Step H — verifier + drift wiring
- [ ] Final acceptance pass against §5
- [ ] Push, request Windows validation
- [ ] Merge
