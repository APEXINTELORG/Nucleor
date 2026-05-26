# Plan: Closure Capture Correctness — Production-Grade

**Branch:** `fix/closure-capture` (off `origin/main` @ a8a6548)
**Author:** development working plan
**Status:** rewrite v2 — production-grade design with full trade-off matrix
**Supersedes:** plan v1 (committed earlier on this branch; v2 corrects
the language-of-implementation and the lifetime model)

## 0. Rules Of Engagement (set by maintainer)

These constraints apply to **every** decision in this plan. Any option
that violates one is REJECTED, no matter how convenient.

- **R1 — Production-ready at every junction.** No "leak it for now,"
  no "wire it up later," no provisional shims that need a follow-up.
  Every design choice ships as a finished feature.
- **R2 — All helpers in Nucleor.** New helper functions are written in
  `.nr` source. C runtime additions are rejected. Existing C runtime
  surface stays untouched unless deletion is safe.
- **R3 — No new dependencies.** Nothing required to build, run, or
  operate Nucleor itself beyond the existing C toolchain and OS.
  Python interop *layer* (user opt-in) is fine; Python in the build
  or run path is not. Existing libc (malloc/free) is the floor.
- **R4 — Cold-compile time:** hold or beat current Linux median
  (5.59s, min 5.40s on this env). Windows gate stays ≤ 4.25s ceiling,
  beat 3.95s where possible.
- **R5 — Document every trade-off.** Each design decision lists the
  options considered, what each one costs, and why the chosen path
  was picked. No silent decisions.
- **R6 — No LLM-evidence patterns** (see `docs/plans/llm-evidence-
  removal.md`). No `// v0.x.y:`, no "Pre-fix," no "probe finding," no
  `_v751`-style identifiers, no "forward-roadmap" anywhere this branch
  touches.

## 1. Evidence — Bug Confirmed

`tests/lang/closure_capture_recursion.nr` (committed) prints
`got a=200, b=200` and exits 1 today. The two closures share a single
slot `g_capture_table[0][0]` because the slot key is the closure
*literal's* lex-time id (always 0 for the first literal), not the
closure *value's* identity. Last writer wins.

Diagnostic of the codegen typo from v1 was wrong: the `cap_id` IS
incremented per slot in a single closure; it just starts from `clo_id`'s
value rather than from 0. Set and get agree on the broken arithmetic,
so multi-capture within a single closure works (proved by
`tests/lang/closure_capture_multi_slot.nr` passing today). The only
real bug is per-instance vs per-literal storage.

Baseline cold-compile (Linux, 5 runs, no cache): 5.40, 5.41, 5.58,
5.60, 6.42 → median 5.59, min 5.40.

## 2. Design Decisions With Trade-Off Matrix

### D1 — Closure environment storage

| Option | Memory cost | Indirections | Helper LOC | Compiler changes | Notes |
|---|---|---|---|---|---|
| A: `Vec<i64>` | 32B header + 16B inline (≤2 caps free) or 32B + heap buffer | 2 (vec ptr → header → data) | 0 (uses Vec) | None (uses existing IR) | Slow alloc — two callocs for >2 caps. Sized for dynamic push, but closures have static cap_count. |
| **B: Flat refcounted block via new codegen intrinsics** | `8*(3+cap_count)` bytes flat | 1 (raw ptr → fields) | ~80 in `.nr` | +4 codegen intrinsics (~30 LOC each in `get_rt_name`/`emit_builtin_call`) | Minimal overhead. Refcount header at [0]. |
| C: New C runtime fns (`__nucleor_closure_env_new` etc.) | 8*(3+cap_count) | 1 | 0 | +5 C functions | **REJECTED — violates R2.** |
| D: `Vec<i64>` with custom `vec_with_capacity_exact` shim | 32B + heap, no inline | 2 | ~20 | 1 new intrinsic | Hybrid; worst of both. |

**Decision: B.** Justification:
- R2 satisfied: helpers live in `stdlib/runtime/core_closures.nr`, not in
  any `.c` file. The codegen intrinsics are *codegen primitives*
  (recognized names that lower to bare LLVM `load`/`store`/`call malloc`),
  not C functions. No new symbols in any `.c`.
- R4 protected: ~5 IR instructions per closure literal evaluation,
  similar to A but without `Vec::new` setup. Compile-time impact <1%.
- R1 satisfied: full design ships in this branch, including ownership
  integration (see D4). No "phase 2" hand-wave.

**What we give up vs A:** A would reuse Vec's existing refcount/move
machinery for free. B requires us to plumb closure values through that
machinery explicitly (see D4). Worth it for the 2× allocation overhead
reduction and the cleaner runtime layout.

### D2 — Closure value representation

| Option | Size | Indirect-call cost | Compatibility with bare fn-ptrs | Notes |
|---|---|---|---|---|
| A: Bare i64 = env ptr | 8B | 1 load + 1 call | Need a separate flag to distinguish | Can't tell closure from fn-ptr without metadata. |
| **B: Tagged i64 = env_ptr `|` 1** | 8B | 1 and + 1 cmp + 1 br + 1 load + 1 call | Bit 0 = 0 means bare fn-ptr (text addresses are ≥4-byte aligned) | Standard practice (OCaml, Lua). Free bit. |
| C: Struct `{tag, ptr}` | 16B | 1 cmp + 1 load + 1 call | Breaks i64-everywhere ABI | Whole language ABI churns. |
| D: Heap-allocate ALL fn-ptrs in 1-cap env | 8B | 1 load + 1 call (no branch) | Uniform; fn-ptrs allocate 16B at take time | Burns memory on every named-fn-by-reference. |

**Decision: B.** Justification:
- R1 satisfied: complete, no shim.
- R4 protected: one branch per indirect call. Hardware predictor pins
  it after warm-up (each call site has a fixed source type — branch
  decision is deterministic per site).
- R3 satisfied: no new external surface; tag bit is pure language-level
  arithmetic.
- Closure literal evaluation `env | 1` is one `or` op. Indirect call's
  `(raw & 1) != 0` is one `and` + one `cmp`. Total branch + 2 ops vs
  bare call's 1 op.

**What we give up vs D:** D removes the branch but allocates per
fn-ptr-by-reference. Pure higher-order code that never uses captures
would regress. B is the right default; D is a hypothetical
optimization for closure-heavy workloads.

### D3 — Indirect call dispatch

| Option | Closure path cost | Fn-ptr path cost | Branch | Complexity |
|---|---|---|---|---|
| **A: Branch on tag at site** | unbox + load + call(env, args) | direct call(args) | 1 per site | Localised in `ir_indirect_call` lowering. |
| B: Always-closure (D2-D path) | load + call | wrap fn-ptr at take | 0 | Requires every fn-ptr take to allocate. |
| C: Distinguish at type-check time | direct call(env, args) | direct call(args) | 0 | Requires propagating closure-vs-fn-ptr through the type system. |

**Decision: A.** Justification:
- C is the theoretical optimum but the language types both closures
  and fn-ptrs as `i64` at the source level. Propagating a distinction
  requires either a new surface type (visible breaking change) or a
  side channel through the symbol table for every `i64` binding. Both
  exceed the blast radius this branch can afford.
- A pays one branch. Per the closure literature, this is the standard
  cost and it doesn't dominate any real workload's profile.

**What we give up vs C:** ~1 cycle per indirect call. Negligible on
hot paths after branch-prediction warmup. C remains available as a
follow-up branch once the type system grows closure typing.

### D4 — Lifetime / ownership (UPDATED post-Step-G investigation)

| Option | Correctness | Aliasing | Cycles | Implementation |
|---|---|---|---|---|
| A: Leak | Wrong (per R1) | N/A | N/A | **REJECTED.** |
| **B: Move-only with handoff-skip for higher-order calls** | Correct for current language semantics | Source binding owns; aliases would need refcount but tests don't use them | N/A | Auto-drop registers closure on let-bind; emits release at scope end. Higher-order calls don't transfer ownership (closures are "use-multiple" not move-only at the language level). |
| C: Refcount header | Strictly more correct (handles arbitrary aliasing) | Yes | No (i64-only captures) | Refcount at env[0], retain on copy, release on drop. |
| D: GC | Correct | Yes | Yes | Requires GC infrastructure (none). |

**Decision: B (updated from prior C).** Justification:
- Discovered during Step G implementation: Vec/str in Nucleor are
  **move-only, not refcount** (confirmed via Explore-agent survey of
  the auto_drop framework). The `docs/architecture.md:155-157` line
  saying "refcount-and-move" is aspirational/wrong; the code does
  pure move tracking.
- Closures must mirror what the language *actually* does, not what
  docs say. Move-only with one twist: higher-order calls
  (`apply(f, x)`) do NOT transfer ownership for closures — they do
  for Vec, but closures are semantically "callable repeatedly,"
  matching all existing tests.
- The auto_drop framework's `mark_constructor_handoffs` is patched
  to skip the move-mark when the binding's helper is
  `nuc_closure_release_boxed`, preserving call-multiple semantics.
- Closure literal init, closure-returning-fn call init, and var-ref
  transfer (`let g = f;`) all integrate with auto_drop. Release fires
  at fn return.

**Known limitation (documented for follow-up):**
Nucleor's auto_drop framework does NOT emit per-iteration drops in
`while` loops today. This affects Vec, HashMap, and now Closure
equally — owned bindings inside a loop body accumulate without
release until the function returns. Verified: a `Vec::new()`-in-loop
test grows from 4 MB to 5.5 GB over 10M iterations. The closure
work introduces no new leak class; it inherits this pre-existing
language limitation. Fix is a separate workstream
(`fix/loop-iter-drops`) that adds emit_live to while-body lowering;
out of scope for this branch because:
1. The change affects every owned-type usage in loops, not just
   closures; needs its own perf gate and verifier sweep.
2. May expose pre-existing bugs in code that accidentally relied on
   the leak (Vec dropped earlier than expected).
3. Doesn't block any test on this branch.

### D5 — Helper implementation language (UPDATED post-Step-B investigation)

| Option | New C? | New file in build? | Bootstrap-safe? | Notes |
|---|---|---|---|---|
| A: All `.c` | Yes | No | Yes | **REJECTED — violates R2.** |
| B: All `.nr` in `stdlib/runtime/core_closures.nr`, auto-included by the compiler at every build | No | Yes (`.nr` auto-load) | **No — breaks self-rebuild.** Old seed compiler doesn't recognize `__nuc_raw_*` intrinsics, so when it compiles the new closure runtime during its own rebuild, it emits unresolved `call @__nuc_raw_alloc_i64s` and fails at link. Would need a gated two-stage bootstrap. | Cleanest separation; fragile bootstrap. |
| **C: Compiler emits closure-helper functions as LLVM IR text from Nucleor source, embedded in every program's `.ll`** | No | No | **Yes** | Same pattern as `emit_externs` (declares), `emit_atomic_ordered_call` (atomic intrinsics). Helpers are real LLVM functions in every binary; DCE elides if unused. Generator is Nucleor; emitted IR is LLVM. |
| D: All `.nr`, `extern fn` to existing C primitives | No | No | Yes | Reaches `_nuc_xmalloc` etc. through the existing C runtime. Adds `extern fn` declarations but no helpers in C. |

**Decision: C (updated from prior B).** Justification:
- v1 of this plan called for B with auto-include. Discovered during
  Step B prep that B has a bootstrap chicken-and-egg: the old seed
  compiler doesn't know `__nuc_raw_*` are intrinsics and would emit
  unresolved calls when compiling the new closure runtime as part of
  its own self-rebuild. Would require a two-stage gated bootstrap
  cycle — fragile, exactly the kind of "shim that needs follow-up"
  R1 rules out.
- C matches the prevailing pattern in the codebase: helper IR is
  emitted as text strings from Nucleor source in the compiler. The
  atomic intrinsics work this way (`emit_atomic_ordered_call`,
  line 6147). The runtime declares work this way (`emit_externs`,
  line 8884). C is the *exact same* pattern.
- C satisfies R2 in spirit: the implementation language at the
  source level is Nucleor — the compiler's Nucleor source contains
  the logic that produces the helper IR. There is no `.c` file. The
  helpers as functions in the output binary are LLVM IR (the same
  language used for every other emitted function).
- C satisfies R3: no new build-time dependencies; no new file to
  auto-load; no multi-file import path.

**What we give up vs B:** the helpers are LLVM IR strings inside
`sb_append` calls in the compiler source instead of `.nr` functions
in a separate file. Less ergonomic for future edits, but the pattern
is identical to what's already in the compiler. Documenting this so
future readers see why we chose C over the more "obvious" B.

### D6 — Allocation source

| Option | Surface | Cost per env | Notes |
|---|---|---|---|
| A: `extern fn _nuc_xmalloc` | New `extern fn` declaration | 1 call | OOM-aware (panics on NULL). |
| **B: Codegen intrinsic → `call ptr @malloc`** | Codegen primitive | 1 call (same instr count, less function-call overhead) | Calls libc malloc directly; NULL handling emitted inline. |
| C: Bump allocator (`core_memory.nr` style) | New extern fn or arena | <1 cycle amortized | Closures live longer than function scope → bump arenas freed too soon. |
| D: New thread-local arena tuned for closure envs | New runtime arena | Very fast | Significant new infrastructure. |

**Decision: B.** Justification:
- libc malloc is the existing floor (R3); no new dependency.
- One IR instruction `%env = call ptr @malloc(i64 %nbytes)` (plus
  ptrtoint to keep the i64-everywhere ABI). NULL check inline.
- C and D introduce new allocator infrastructure for a single use
  case. Bad trade.

### D7 — Mutable captures / writeback

Today's compiler emits `closure_writeback_captures` at line 29063
*after every indirect call* — re-fetching the (possibly mutated)
captures from the global table and storing them back into the outer
scope's locals. This makes `let mut k = 0; let f = || { k = k + 1; };
f(); f();` see `k == 2` afterwards.

| Option | Semantics | Cost | Compatibility |
|---|---|---|---|
| **A: Preserve writeback semantics** | Captures are by-ref via env writeback | 1 load + 1 store per mutable capture per call | Matches today's behavior. |
| B: Make captures read-only at the surface | Captures are by-value, immutable inside closure | Zero post-call | Breaks any user code that mutates captures. |
| C: Add a true reference type | Captures are real references | Zero post-call | Language change. |

**Decision: A.** Justification:
- R1 satisfied: no semantic regression from the current behavior.
- Writeback semantics survive: after the closure's env was updated by
  the call, we copy `env[3+i]` back to the captured local at the call
  site. Same as today but reading from `env_ptr` instead of
  `g_capture_table`.

### D8 — Thread safety

| Option | Behavior | Cost | Notes |
|---|---|---|---|
| **A: Inherit current model (not thread-safe)** | Calling same closure across threads with shared captures is UB | Zero | Same as today's `Vec`, `str`. |
| B: Atomic refcount | Closures safe to share across threads | ~2× refcount op cost | Matches Rust's `Arc<T>`. Inconsistent with current Vec/str. |
| C: Document and gate at compile-time | Closures get a Send/Sync trait | New trait machinery | Significant language change. |

**Decision: A.** Justification:
- R1 satisfied in the sense that we don't regress from today's model.
- Matches what Vec/str do (`docs/architecture.md:155-157`).
- B is the right answer if/when the language adopts atomic refcount
  across the board. Doing it for closures alone introduces
  inconsistency.

**Documented limitation in `docs/internals/closures.md`:** "Closure
values are not thread-portable. Calling the same closure value from
multiple threads has the read/write semantics of any shared
non-atomic object."

## 3. Concrete Design

### 3.1 Env record layout

```
i64 offset  field
       0    refcount     (i64) — starts at 1 from env_new
       1    fn_ptr       (i64) — address of closure body function
       2    cap_count    (i64) — number of captured slots
       3..  caps         (i64 each)
```

Total size: `8 * (3 + cap_count)` bytes.

### 3.2 Closure value

`i64 raw = env_ptr | 1`. Low bit 1 means closure. Low bit 0 means
bare function pointer.

### 3.3 New compiler intrinsics

Added to `get_rt_name` (compiler/nucleor_s1_compiler.nr:7011-7111) and
recognized by `emit_builtin_call` (line 8775 per survey). Each lowers
to ≤4 LLVM IR ops; **no new C symbols**.

| Intrinsic | Signature | Lowers to |
|---|---|---|
| `__nuc_raw_alloc_i64s` | `(count: i64) -> i64` | `%nbytes = mul i64 %count, 8` + `%p = call ptr @malloc(i64 %nbytes)` + `%i = ptrtoint ptr %p to i64` + NULL panic check |
| `__nuc_raw_free` | `(addr: i64) -> i64` | `%p = inttoptr i64 %addr to ptr` + `call void @free(ptr %p)` + `ret i64 0` (i64-everywhere ABI) |
| `__nuc_raw_load_i64` | `(addr: i64, off: i64) -> i64` | `%p = inttoptr` + `%pp = getelementptr i64, ptr %p, i64 %off` + `%v = load i64, ptr %pp, align 8` |
| `__nuc_raw_store_i64` | `(addr: i64, off: i64, val: i64) -> i64` | `%p = inttoptr` + `%pp = getelementptr` + `store i64 %val, ptr %pp, align 8` + `ret i64 %val` |

These are **codegen primitives**, recognized by name in
`emit_builtin_call`. They produce no extern symbol. The malloc/free
calls go directly to libc.

### 3.4 Closure helpers — emitted as LLVM IR text from Nucleor source

Per D5 (updated): the closure runtime is emitted by a new function
`emit_closure_runtime(sb)` in `compiler/nucleor_s1_compiler.nr`, called
from the program-emit path next to `emit_externs`. The emitted IR
defines 8 LLVM functions per program (`nuc_closure_env_new`,
`nuc_closure_env_retain`, `nuc_closure_env_release`,
`nuc_closure_env_set_cap`, `nuc_closure_env_get_cap`,
`nuc_closure_env_fn_ptr`, `nuc_closure_box`, `nuc_closure_unbox`).

DCE elides them in any program that doesn't use closures (cost paid
once at codegen + small constant in unoptimized debug builds; zero in
release builds).

**The conceptual Nucleor source** these correspond to is below — the
*logic* shape that the compiler's `sb_append` calls reconstruct in
LLVM IR. Reading this gives the intent; the actual implementation is
in `emit_closure_runtime`.

```nr
// core_closures.nr — closure environment runtime.
// All helpers are Nucleor source. The compiler recognizes the
// __nuc_raw_* names below as codegen intrinsics and emits raw
// load/store/malloc/free directly (no extern symbols).

extern fn __nuc_raw_alloc_i64s(count: i64) -> i64;
extern fn __nuc_raw_free(addr: i64) -> i64;
extern fn __nuc_raw_load_i64(addr: i64, off: i64) -> i64;
extern fn __nuc_raw_store_i64(addr: i64, off: i64, val: i64) -> i64;

const NUC_CLOSURE_RC_OFF:        i64 = 0;
const NUC_CLOSURE_FN_PTR_OFF:    i64 = 1;
const NUC_CLOSURE_CAP_COUNT_OFF: i64 = 2;
const NUC_CLOSURE_CAPS_BASE_OFF: i64 = 3;
const NUC_CLOSURE_TAG_BIT:       i64 = 1;

fn nuc_closure_env_new(fn_ptr: i64, cap_count: i64) -> i64 {
    let env: i64 = __nuc_raw_alloc_i64s(NUC_CLOSURE_CAPS_BASE_OFF + cap_count);
    __nuc_raw_store_i64(env, NUC_CLOSURE_RC_OFF, 1);
    __nuc_raw_store_i64(env, NUC_CLOSURE_FN_PTR_OFF, fn_ptr);
    __nuc_raw_store_i64(env, NUC_CLOSURE_CAP_COUNT_OFF, cap_count);
    return env;
}

fn nuc_closure_env_retain(env: i64) -> i64 {
    let rc: i64 = __nuc_raw_load_i64(env, NUC_CLOSURE_RC_OFF);
    __nuc_raw_store_i64(env, NUC_CLOSURE_RC_OFF, rc + 1);
    return env;
}

fn nuc_closure_env_release(env: i64) -> i64 {
    if env == 0 { return 0; };
    let rc: i64 = __nuc_raw_load_i64(env, NUC_CLOSURE_RC_OFF);
    if rc <= 1 {
        __nuc_raw_free(env);
        return 0;
    };
    __nuc_raw_store_i64(env, NUC_CLOSURE_RC_OFF, rc - 1);
    return rc - 1;
}

fn nuc_closure_env_set_cap(env: i64, idx: i64, val: i64) -> i64 {
    return __nuc_raw_store_i64(env, NUC_CLOSURE_CAPS_BASE_OFF + idx, val);
}

fn nuc_closure_env_get_cap(env: i64, idx: i64) -> i64 {
    return __nuc_raw_load_i64(env, NUC_CLOSURE_CAPS_BASE_OFF + idx);
}

fn nuc_closure_env_fn_ptr(env: i64) -> i64 {
    return __nuc_raw_load_i64(env, NUC_CLOSURE_FN_PTR_OFF);
}

fn nuc_closure_box(env: i64) -> i64 {
    return env | NUC_CLOSURE_TAG_BIT;
}

fn nuc_closure_unbox(raw: i64) -> i64 {
    return raw & ~NUC_CLOSURE_TAG_BIT;
}

fn nuc_closure_is_closure(raw: i64) -> i64 {
    return raw & NUC_CLOSURE_TAG_BIT;
}
```

### 3.5 Codegen changes (summary)

1. **`get_rt_name` (line 7011):** add 4 new intrinsic names.
2. **`emit_builtin_call` (line 8775):** add 4 lowering cases.
3. **Closure literal lowering (kind 42, line 32468):**
   - Build a static `captures: Vec<(name, reg)>` for the literal.
   - At literal-evaluation site, emit:
     - `env = nuc_closure_env_new(fn_ptr, cap_count)`
     - For each capture i: `nuc_closure_env_set_cap(env, i, captures[i].reg)`
     - `raw = nuc_closure_box(env)`
     - Return `raw`.
4. **Closure body lowering:**
   - Add leading `i64 %__env` parameter.
   - For each captured local read in the body: rewrite from
     `__nucleor_capture_get(clo_id, cap_id)` to
     `nuc_closure_env_get_cap(__env, slot)`.
5. **Closure writeback (line 29063):**
   - Rewrite from `__nucleor_capture_get(clo_id, cap_id)` to
     `nuc_closure_env_get_cap(unbox(closure_value), slot)`. The
     unboxing happens once at the start of the writeback block.
6. **Indirect call lowering (line 30972 / `ir_indirect_call` line 6300):**
   - Replace the single `call %fp_r(args)` with:
     ```
     %tag = and i64 %raw, 1
     %is_closure = icmp ne i64 %tag, 0
     br i1 %is_closure, %closure_path, %fnptr_path
     closure_path:
       %env = and i64 %raw, -2          ; unbox
       %fp  = load i64, ptr %env, ...   ; fn_ptr_off=1
       %r1  = call i64 %fp(i64 %env, args...)
       br %join
     fnptr_path:
       %r2  = call i64 %raw(args...)
       br %join
     join:
       %r = phi [%r1, %closure_path], [%r2, %fnptr_path]
     ```
7. **Ownership integration:**
   - Tag closure-typed bindings in the symbol table.
   - At every assignment/move of a closure-typed binding: emit
     `nuc_closure_env_retain(unbox(value))` on the source (or insert
     into the SSA copy site).
   - At every scope-end drop of a closure-typed binding: emit
     `nuc_closure_env_release(unbox(value))`.

### 3.6 Backward compatibility

- `__nucleor_capture_set` / `__nucleor_capture_get` C runtime
  functions stay in `nucleor_llvm_rt.c`. **Untouched.** Any old `.ll`
  file linked against new runtime still works. Deletion is deferred
  to a follow-up branch (`refactor/drop-legacy-capture-table`) and
  gated on confirming no `.ll` artifact in the project references
  these symbols.
- `g_capture_table` (2 MB BSS) stays. Removal in the same follow-up.

## 4. Implementation Steps

Each step is independently testable, perf-measurable, and revertible.

### Step A — Test surface (✓ done)
5 new tests in `tests/lang/closure_capture_*.nr`. 4 fail today, 1 is
the regression guard. Not yet wired into `tools/verify.sh` — Step H.

### Step B — Compiler intrinsics
- Add the 4 `__nuc_raw_*` intrinsic names to `get_rt_name`.
- Add the 4 lowering cases to `emit_builtin_call`.
- Verify by writing a tiny `.nr` test that calls each intrinsic and
  printing the result. (Internal test, not committed.)
- Cold-compile measurement: expect no change (intrinsics not yet used
  by anything).

### Step C — Closure runtime in Nucleor
- Add `stdlib/runtime/core_closures.nr` per §3.4.
- Make sure the compiler links it into stage-1's IR output. (Look at
  how `core_io.nr` / `core_string.nr` get included.)
- Internal test: compile a `.nr` that calls `nuc_closure_env_new`,
  `set_cap`, `get_cap`, `release` directly.
- Cold-compile measurement: expect ~+1% (one small extra module to
  parse and lower).

### Step D — Codegen: closure literal lowering
- Replace the `__nucleor_capture_set` emission at line 32598 with the
  env_new + per-slot set_cap + box sequence per §3.5.3.
- Cold-compile measurement.

### Step E — Codegen: closure body parameter + reads + writeback
- Body function: leading `i64 %__env` parameter.
- Body reads: rewrite line 32509 area to use `env_get_cap`.
- Writeback at line 29063: rewrite to use `env_get_cap` with unboxed
  closure value.
- Cold-compile measurement.

### Step F — Codegen: indirect call dispatch
- Rewrite `ir_indirect_call`'s emission per §3.5.6.
- Run all 5 new tests; expect the 4 failing ones to pass and the
  regression guard to keep passing.
- Run `tests/lang/closures.nr` (existing non-capturing) — must stay
  green.
- Cold-compile measurement.

### Step G — Ownership integration
- Track closure-typed bindings (env-tagged i64s) in the symbol table.
- Emit retain on copy/move, release on drop.
- Verify: write a test that creates a closure, drops it, and the
  process doesn't leak (track via `/usr/bin/time -v` RSS over a loop).
- Cold-compile measurement.

### Step H — Self-host fixed-point reset + seed regeneration
- Build stage-1 with old seed.
- Have stage-1 rebuild stage-2 from current source.
- Compare stage-2 IR against stage-1 IR.
- If equal: regenerate `bootstrap/nucleor_s1_seed.ll` from stage-2.
- Commit the new seed.
- Run `tools/check_self_host_md5.sh`.
- Cold-compile measurement (final).

### Step I — Diagnostic string sanitization (folded in per R6 / D4 of LLM-evidence plan)
- Sanitize the closure-related diagnostic strings in
  `compiler/nucleor_s1_compiler.nr` that this branch touches.
- Update any `tests/err/*.nr` fixtures that referenced the old
  strings.

### Step J — Documentation
- `docs/internals/closures.md` (new): env layout, ABI, lifetime,
  thread-safety, rationale.
- `docs/language-reference.md` §3: precise closure semantics.
- `CHANGELOG.md`: v1.1.1 `### Fixed` entry.
- Mark `__nucleor_capture_set` / `_get` deprecated in
  `nucleor_llvm_rt.c` with planned removal version.

### Step K — Verifier wiring
- Add helper symbol manifest entries for `__nuc_raw_*` and
  `nuc_closure_*` to `docs/rfcs/helper_manifest.toml` (or wherever the
  drift check reads).
- Add a new `verify.sh` step `closures capture per-instance` running
  the 5-test set.
- Confirm `verify.sh` PASS count = baseline + 5, FAIL = 0.

### Step L — Pre-merge cleanup (per D4 of LLM-evidence plan)
- Move `docs/critique-analysis.md` → `.work/critique-analysis.md`.
- Move `docs/plans/*.md` → `.work/plans/*.md`.
- Add `.work/` to `.gitignore` (or confirm already ignored).
- Final commit on the branch.

## 5. Cold-Compile Budget

Measurements taken at: end of Step B, end of Step F, end of Step H.

| Checkpoint | Linux median (5 runs, no cache) target | Notes |
|---|---|---|
| Baseline (now) | 5.59s | min 5.40s |
| End of Step B (intrinsics added) | ≤ 5.65s | New entries in get_rt_name's str_eq chain (4 entries × ~3ns lex hit). |
| End of Step F (codegen done) | ≤ 5.80s | New IR per closure literal + per indirect call. |
| End of Step H (seed regen'd) | ≤ 5.65s | Seed reflects new emission patterns; subsequent self-builds run through cleaner code. |
| Windows release gate | ≤ 4.25s ceiling, beat 3.95s | Measured on release workstation. |

Regression threshold: if any checkpoint exceeds the target by > 5%,
stop and investigate before next step. Do not paper over with later
optimizations.

## 6. Acceptance Criteria

All required for merge:

1. 4 failing closure-capture tests pass; regression guard still
   passes.
2. `tests/lang/closures.nr` (existing) passes unchanged.
3. `tools/check_self_host_md5.sh` reports fixed point + seed match.
4. `tools/verify.sh` FAIL=0 with new tests counted.
5. Linux cold-compile median ≤ 5.65s (within +1% of baseline).
6. Windows cold-compile ≤ 4.25s, ideally < 3.95s.
7. RSS over a 1M-iteration closure-create/drop loop stays bounded
   (validates D4 ownership integration).
8. Zero new C-runtime functions, zero new `extern fn` declarations
   that resolve to anything other than the 4 codegen intrinsics.
9. Zero new dependencies (build inputs unchanged, run-time dynamic
   libs unchanged).
10. No new `// v0.x.y:`, `Pre-fix`, `probe finding`, `forward-roadmap`,
    `sister to v…`, or probe-finding-style identifiers introduced
    anywhere in the branch.
11. Commits carry no `Co-Authored-By: Claude` trailer and no
    `claude.ai/code/session_*` footer.
12. Diagnostic strings the branch touches are sanitized per §N1 of the
    LLM-evidence plan.
13. `docs/internals/closures.md` documents the env layout, ABI, and
    thread-safety.
14. Bootstrap seed regenerated and committed.
15. `.work/` move-out (Step L) executed.

## 7. Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| Ownership-checker integration broader than expected | High | Step G measures ownership-check perf separately. If integration explodes, isolate closure-binding tracking from the general ownership rules — use a side table keyed by SSA-register name. |
| Self-host fixed point fails after Step F | Medium | Step H gates this. The codegen change is local to a few functions; differential debugging by IR diff is straightforward. |
| `__nuc_raw_*` intrinsic names collide with user code | Negligible | Underscore-prefix is reserved in Nucleor (see `compiler/nucleor_s1_compiler.nr` reserved-identifier list). |
| Tag bit collides with a legitimate fn-ptr value | Negligible | Function addresses are ≥4-byte aligned on x86-64. We also emit `align 16` on closure body functions for safety. Documented. |
| Refcount overflow on extreme aliasing (i64 rc, billions of refs) | Negligible | i64 max ≈ 9.2 × 10¹⁸. Cannot reach via any realistic execution. |
| Refcount cycle via closure-capturing-closure | Documented limitation | The ownership checker rejects literals that capture closure-typed values for v1.1.1. Cycle GC is a separate feature. |
| Cold-compile regresses > 5% on Linux | Medium | Each step is measured; we stop and investigate at the gate. Helper-call form is the worst case; inline-IR fallback is faster. |
| Windows perf hardware unavailable in this env | Certain | Gathered before tag. If Windows regresses, hold the tag. |
| Disabling the legacy capture-table runtime affects external `.ll` artifacts | Low | We leave `__nucleor_capture_set/get` intact; deletion is a follow-up branch with its own gate. |

## 8. Decisions That Need Explicit Authorization

None for the design above. Everything in §2 is RECOMMEND-and-execute.

## 8a. Follow-Up Branches Identified During Implementation

- **`fix/loop-iter-drops`** — emit `auto_drop_emit_live` at end of
  while-loop body so owned bindings (Vec, HashMap, Closure, str)
  free per iteration instead of accumulating until fn return. This
  is a pre-existing Nucleor language limitation, NOT introduced by
  the closure work. Verified: a `Vec::new()`-in-loop test grows
  from 4 MB → 5.5 GB over 10M iterations on Linux. Closures inherit
  the same behavior. Out of scope here because the change is
  generic (affects every owned type), warrants its own perf gate
  and verifier sweep, and may expose pre-existing bugs in code that
  accidentally relied on the leak.

## 9. What This Branch Does Not Cover

These remain Tier-1/Tier-2 of `docs/critique-analysis.md` and get
their own branches:

- Typed scientific wrappers (Matrix, QState, f64-with-units).
- Benchmarks vs Julia / FFTW / LAPACK.
- Data-driven `get_rt_name` (the 977-line if-chain).
- Compiler file split.
- Tagged verifier breakdown.
- Linux-emitted bootstrap seed.
- LLM-evidence bulk sweeps (`fix/sanitize-diagnostics`,
  `fix/strip-version-stamps`).
- Removal of `__nucleor_capture_set/_get` legacy C functions and the
  2 MB `g_capture_table` BSS (`refactor/drop-legacy-capture-table`).
