# FFI Conventions — Null, Bounds, Lifetimes (RFC-0062 G-5 / G-9 Phase 1)

This file documents the conventions every C-side `*_rt.c` runtime
function adheres to when called from a Nucleor `extern fn` decl.
RFC-0062 §3.3 G-5 (FFI null convention) and G-9 (FFI bounds-check
trust) require these to be written down at every boundary; this
doc is the single canonical source. Per-rod runtime files
reference this file in their header comments rather than repeating
the rules.

## 1. Null convention

A Nucleor reference (`&T`, `&mut T`) crossing the FFI boundary into
a C-side function is **never null**. The Nucleor compiler does not
emit null pointers from safe code; every reference originates from
a `let` binding, a struct field, or a function arg, all of which
are validated at construction.

The C-side function may therefore assume:

- `*T` parameters are non-null when the corresponding Nucleor
  declaration is `&T` or `&mut T`.
- A C-runtime function that explicitly accepts a maybe-null
  pointer must declare it as `*const c_void` (raw pointer) on the
  Nucleor side, NOT `&T`. Today this convention is followed in
  every `extern fn` decl in `stdlib/rods/*.nr`.

**Exception — return values:** A C-runtime function CAN return
NULL to signal failure (e.g., `fopen`, `malloc` exhaustion). The
Nucleor wrapper (the `extern fn` declaration's caller in the rod)
is responsible for null-checking before exposing the value to safe
code. The conventional pattern is:

```nucleor
extern fn vec_alloc_or_null(n: i64) -> *const c_void;

fn vec_with_capacity(n: i64) -> Vec<i64> {
    let raw: *const c_void = vec_alloc_or_null(n);
    if ptr_is_null(raw) {
        panic("alloc failed");
    }
    return vec_from_raw(raw, n);
}
```

The `*const c_void` → `Vec<i64>` translation only happens after
the null check, so safe Nucleor code only ever sees non-null.

## 2. Bounds-check trust

Per RFC-0062 §3.3 G-9: **the Nucleor compiler emits bounds checks
inside Nucleor-callable wrappers; the C runtime trusts the index
arguments to be in-range and does NOT re-check.**

This trust is the entire reason `vec_get(v, i)` is fast: the
inner `*_rt.c` function does pointer-arithmetic only.

The trust contract:

- If the Nucleor caller is safe code, the `i64` index parameter
  has been bounds-checked by the `vec_get_*` lowering rule before
  the C call.
- If the Nucleor caller is `unsafe { vec_get_unchecked(v, i) }`
  (when v1.0 ships that opt-out), the bounds check is skipped at
  the caller's risk.
- The C runtime is **never** responsible for bounds checking. It
  is responsible for honoring the trust contract — i.e., being
  correct given in-range inputs.

Adopters writing direct FFI calls (e.g., custom `extern fn` decls)
must understand they bypass the safe-code bounds-check insertion.
Direct FFI calls are documented as an unsafe surface even when no
`unsafe { }` block is required syntactically. Phase 4 (v1.0) may
require explicit `#[allow(direct_ffi)]` to silence a lint warning.

## 3. Lifetimes across FFI

A Nucleor reference passed to a C-runtime function is valid for
the duration of the C call only. The C-runtime function MUST NOT
retain the pointer past return.

Today this is honored by convention; Phase 4 will add a `@policy
(no_ffi_retain)` enforcement that audits `*_rt.c` source for any
function whose body stores a parameter pointer in a static or
heap-reachable location.

## 4. Allocator pairing

Memory allocated by C-side `*_rt.c` allocators is freed by C-side
deallocators only. Nucleor's drop semantics route to the matching
deallocator via the type's drop glue. Adopters CANNOT free Nucleor
heap with `free()` from foreign C code; the deallocator is
type-specific (Vec uses `nuc_vec_free`, String uses `nuc_str_free`,
etc.) and the type's tag determines which one runs.

Mixing allocators (allocate with `malloc`, free with `nuc_vec_free`)
is undefined behavior at the C level. The conventional pattern is
to keep all allocations of a given type within a single allocator.

## 5. Threading

Per RFC-0062 §3.3 G-6 Phase 1: today the runtime assumes a single
mutator thread. C-runtime data structures (Vec, HashMap, the
governance registry, the energy-budget registry, etc.) are NOT
thread-safe. Adopters who spawn OS threads and pass references
across threads invoke undefined behavior.

`@policy(sendable)` and the Sendable marker trait will gain
enforcement in Phase 2; until then, single-thread mutator is the
contract.

## 6. C-runtime surface inventory

See `docs/unsafe-audit.md` §3 for the complete list of `*_rt.c`
files implementing the FFI surface.
