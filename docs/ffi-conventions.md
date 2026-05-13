# FFI Conventions

This file documents the contract between Nucleor `extern fn` declarations and
the C runtime files under `stdlib/runtime/`.

## Nulls

A Nucleor reference (`&T`, `&mut T`) passed into a C runtime function is never
null. Safe Nucleor code does not manufacture null references.

If a C function accepts a pointer that may be null, expose that parameter on the
Nucleor side as a raw pointer, not as `&T` or `&mut T`.

C runtime functions may return null to signal failure. The Nucleor wrapper must
check the raw return value before exposing it to safe code.

```nr
extern fn vec_alloc_or_null(n: i64) -> *const c_void;

fn vec_with_capacity(n: i64) -> Vec<i64> {
    let raw: *const c_void = vec_alloc_or_null(n);
    if ptr_is_null(raw) {
        panic("alloc failed");
    }
    return vec_from_raw(raw, n);
}
```

## Bounds

Safe Nucleor wrappers perform bounds checks before calling the C runtime. The C
runtime assumes checked indexes are in range and keeps the hot path lean.

Direct custom FFI calls bypass Nucleor's wrapper checks. Treat direct FFI as an
unsafe surface and keep bounds checks on the Nucleor side.

## Lifetimes

A Nucleor reference passed to C is valid only for the duration of the C call.
Runtime functions must not retain the pointer after returning.

## Allocator Pairing

Memory allocated by Nucleor runtime allocators must be freed by the matching
Nucleor runtime deallocator. Do not free Nucleor heap objects with foreign
`free()` calls.

## Threading

Runtime data structures are not generally thread-safe unless the specific rod
documents that they are. Do not pass mutable runtime-owned structures across OS
threads unless the API explicitly supports it.

## Surface Inventory

The C runtime surface is implemented by the `*_rt.c` files under
`stdlib/runtime/`. Safe wrappers live in `stdlib/rods/*.nr`.
