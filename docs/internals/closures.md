# Closure Internals

How closure values are represented, captured, called, and released in
Nucleor v1.1.1+.

## Surface

A closure literal `|args| body` produces an `i64` value (Nucleor's
i64-everywhere ABI). The value is **not** a raw function pointer —
it's a tagged pointer to a heap-allocated environment record. The
language hides the boxing; from the user's perspective:

```nr
let f: i64 = |x| x * 2;
print_int(f(21));              // prints 42
let g: i64 = make_doubler(10); // make_doubler returns a closure
print_int(g(7));               // prints 70
```

Captures are by value-snapshot at literal-evaluation time:

```nr
let mut k: i64 = 3;
let f: i64 = |x| x * k;        // captures k = 3
k = 999;                       // does NOT affect f
print_int(f(7));               // prints 21
```

## Environment record layout

Each closure value points to a refcount-tracked block of i64 slots:

```
i64 offset  field
       0    refcount      (1 at construction; this branch always 1)
       1    fn_ptr        (address of the closure body function)
       2    cap_count     (number of captured slots)
       3..  caps          (i64 each, one per captured local)
```

Total bytes per closure: `8 * (3 + cap_count)`.

Allocated via libc `malloc` (the only OS dependency). The compiler
emits the allocation inline via the `__nuc_raw_alloc_i64s` codegen
intrinsic — no Nucleor-specific allocator C runtime is involved.

## Closure value (tag bit)

A closure value at the surface is `env_ptr | 1`. The low bit
distinguishes a closure from a bare function pointer:

- **Bare fn-ptr** (e.g., `let f = some_named_fn;`): low bit 0; bits
  1-63 are the function's text address. Text addresses are at
  least 4-byte-aligned on x86-64, so the low bit is reserved.
- **Closure**: low bit 1; clearing it (`raw & -2`) gives the env
  pointer.

This means closure-typed values and bare fn-ptr values share the same
i64-everywhere ABI. The same indirect-call site can receive either,
and the runtime branch handles dispatch.

## Closure body signature

The body function gains a leading `i64` parameter that carries the
unboxed env pointer at runtime:

```
define i64 @__closure_N(i64 %__env, i64 %p.1, i64 %p.2, ...) {
  ; reads each captured slot at body entry:
  ;   %v = call i64 @nuc_closure_env_get_cap(i64 %__env, i64 <slot>)
  ;   store i64 %v, ptr %cap_alloca
  ; body executes, then ret
}
```

User parameters shift by +1 (`%p.0` is `__env`; user's first arg is
`%p.1`).

## Indirect call dispatch

Every indirect call at the source level (`f(args...)`) lowers to a
runtime branch on the tag bit:

```
%tag       = and i64 %raw, 1
%is_clo    = icmp ne i64 %tag, 0
br i1 %is_clo, label %closure_path, label %fnptr_path

closure_path:
  %env     = and i64 %raw, -2                       ; unbox
  %envp    = inttoptr i64 %env to ptr
  %fnoff   = getelementptr i64, ptr %envp, i64 1    ; fn_ptr at offset 1
  %fpi     = load i64, ptr %fnoff, align 8
  %fp_clo  = inttoptr i64 %fpi to ptr
  %cres    = call i64 %fp_clo(i64 %env, args...)    ; env prepended
  br %join

fnptr_path:
  %fp_bare = inttoptr i64 %raw to ptr
  %fres    = call i64 %fp_bare(args...)              ; legacy ABI
  br %join

join:
  %r       = phi i64 [%cres, %closure_path], [%fres, %fnptr_path]
```

Cost: one `and` + one `icmp` + one `br` + one extra load per indirect
call site, plus passing one extra arg in the closure path. Hardware
branch prediction pins per call site (each source site has a fixed
type — bare fn-ptr or closure — after one warmup).

## Lifetime / ownership

Closure values are owned. They integrate with the auto-drop framework
the same way `Vec<T>` does, with a closure-specific helper:

- A `let` binding initialized with a closure literal, a call to a
  closure-returning fn, or a transfer from another closure-typed
  binding is registered under the internal `"Closure"` type tag.
- The auto-drop framework emits a call to `nuc_closure_release_boxed`
  for each live closure binding at scope end (fn return and end of
  each loop iteration).
- Closure-typed values are **not** move-only at the language level.
  Passing a closure to a higher-order fn (`apply(f, x)`) is a
  by-value pointer copy; the source binding retains ownership of the
  env, and the callee does not free it.
- `let g = f;` transfers ownership: source is marked freed, `g` is
  registered as the new owner.

This matches "use the closure repeatedly from its declaring scope" —
the common case for higher-order programming.

### Lifetime helper functions

All emitted as LLVM IR text by `emit_closure_runtime` in
`compiler/nucleor_s1_compiler.nr`. Same pattern as the atomic
intrinsics: the *generator* is Nucleor source; the *emitted helper*
is LLVM IR linked into every program.

| Function | Behavior |
|---|---|
| `nuc_closure_env_new(fn_ptr, cap_count)` | Allocate + init env. |
| `nuc_closure_env_retain(env)` | refcount++ (for future refcount mode). |
| `nuc_closure_env_release(env)` | refcount--, free at zero. |
| `nuc_closure_env_set_cap(env, idx, val)` | Store capture slot. |
| `nuc_closure_env_get_cap(env, idx)` | Load capture slot. |
| `nuc_closure_env_fn_ptr(env)` | Load fn_ptr at offset 1. |
| `nuc_closure_box(env)` | Tag: `env | 1`. |
| `nuc_closure_unbox(raw)` | Untag: `raw & -2`. |
| `nuc_closure_release_boxed(raw)` | Tag-checked release; calls env_release if low bit is 1, no-op otherwise. Used as the auto-drop helper. |

## Mutable captures

Today's behavior is preserved: a closure body that assigns to a
captured local mirrors the write into the env record via
`nuc_closure_env_set_cap`. A `closure_writeback_captures` step at the
call site reads each capture back from the env into the outer scope's
local slot — the let-and-call shadowing pattern continues to
propagate mutations.

```nr
let mut k: i64 = 0;
let f: i64 = || { k = k + 1; };
f();
print_int(k); // 1
```

This works for the immediate let-and-call form. Mutations across
indirection (storing the closure in a Vec, returning it from a fn,
etc.) do **not** propagate to the original scope — same as Vec/str
mutation semantics for owned values that escape their declaring
scope.

## Thread safety

Closure values are **not** thread-portable.

- Distinct closure values have distinct env pointers; allocating two
  closures from different threads is safe.
- Calling the *same* closure value from multiple threads
  simultaneously, where the body mutates captures, has the read/write
  semantics of any shared mutable object — undefined without external
  synchronization.
- The current refcount field is not atomic. The branch ships with
  refcount as a single-owner counter; threading-safe refcount is a
  future enhancement and matches the Vec/str status (also non-atomic
  refcount today).

Documentation policy: anything in `docs/language-reference.md` that
implies closures are thread-portable should be tightened. This is a
v1.1 limitation, not a permanent design.

## Runtime helpers that take fn-ptr args

Existing C runtime helpers that take `long long fn_ptr` arguments
were updated to dispatch through tag-aware inline helpers
(`_nuc_call_clo_0/1/2` in `stdlib/runtime/nucleor_llvm_rt.c`). The
helpers accept both bare fn-ptrs and boxed closure values; the
dispatch matches what the codegen emits at op==30.

Functions updated:
- `__nucleor_vec_map_i64`, `vec_filter_i64`, `vec_fold_i64`,
  `vec_each_i64`, `vec_position_i64`, `vec_reduce_i64`,
  `vec_any_i64`, `vec_all_i64`
- `__nucleor_option_map`, `option_and_then`, `option_unwrap_or_else`
- `__nucleor_result_map`, `result_and_then`,
  `result_unwrap_or_else`, `result_or_else`
- `__nucleor_thread_spawn`, `__nucleor_async_spawn` (both POSIX and
  Win32)

If you add a new C runtime helper that takes a fn-ptr arg, route it
through `_nuc_call_clo_N` for the appropriate arity. Calling
`(fn_ptr)(args...)` directly will segfault on closure values.

## Legacy (deprecated)

The pre-v1.1.1 global capture table — `g_capture_table` in the C
runtime, with `__nucleor_capture_set` / `__nucleor_capture_get` — is
unused by the new codegen but retained as compatibility shims for any
externally-built `.ll` artifacts that still link against the old
symbols. Slated for removal in a follow-up branch
(`refactor/drop-legacy-capture-table`) once we're confident no
pre-fix `.ll` is in circulation.

## Files

- `compiler/nucleor_s1_compiler.nr`
  - `is_nuc_raw_intrinsic` / `emit_nuc_raw_call` (around line 6195) —
    raw-memory codegen intrinsics.
  - `emit_closure_runtime` (around line 10325) — the 9 LLVM function
    definitions emitted into every program.
  - Closure literal lowering (kind 42, around line 32700) — env_new
    + per-slot set_cap + box.
  - Body parameter shift + capture reads (also kind 42).
  - Assign-to-capture inside body (kind 21, around line 33800) —
    mirrors write into env via set_cap.
  - Indirect call dispatch (op==30 in emit_inst, around line 8840) —
    tag-bit branch.
  - `closure_writeback_captures` (around line 29260) — post-call
    sync from env back to outer local.
  - `auto_drop_helper_for_type` (around line 33525) — `"Closure"`
    routes to `nuc_closure_release_boxed`.
  - `detect_returns_closure` / `fn_return_map_new` (around line
    33010) — closure-returning fn detection.
  - `auto_drop_emit_live_above` (around line 33660) — scoped drop
    emission for loop bodies.
  - while-loop / for-loop lowering (around line 34370) — per-iter
    drop emission.
- `stdlib/runtime/nucleor_llvm_rt.c`
  - `_nuc_call_clo_0/1/2` (around line 3045) — tag-aware dispatch
    helpers.
  - All fn-ptr-taking helpers updated to route through them.
  - `g_capture_table` and `__nucleor_capture_set/_get` retained as
    deprecated shims.

## Tests

`tests/lang/closure_capture_*.nr`:
- `closure_capture_recursion` — two closures from the same literal
  don't share captures.
- `closure_capture_multi_slot` — multiple captures within one
  closure read distinct values (regression guard).
- `closure_capture_nested` — inner closure captures from outer
  closure's scope.
- `closure_capture_recursive_call` — re-entering a closure-producing
  fn doesn't stomp earlier closures.
- `closure_capture_pass_back` — passing a closure to a higher-order
  fn multiple times works (use-multiple semantics).

`tests/lang/closures.nr` — non-capturing closures (pre-existing
regression guard).
