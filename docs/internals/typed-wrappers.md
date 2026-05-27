# Typed Newtype Wrappers Over Handle-Style Rods

Most numerical/scientific rods in `stdlib/rods/` expose their API as
opaque `i64` handles for FFI simplicity. This works, but at the call
site every value reads as "an integer," which hides domain intent
and admits accidental cross-type passing.

This doc establishes the pattern for typing those handles via
zero-cost newtype struct wrappers, and lays out the roadmap to a
fully typed scientific surface.

## The pattern

```nr
struct Matrix {
    handle: i64,
}

fn mat_new(rows: i64, cols: i64) -> Matrix {
    return Matrix { handle: linalg_new(rows, cols) };
}

fn mat_get(m: &Matrix, r: i64, c: i64) -> i64 {
    return linalg_get(m.handle, r, c);
}
```

- The struct is a single-field record over the raw handle.
- All operations take `&Matrix` (Nucleor's reference borrow), so a
  value can be used through multiple calls without triggering
  OWN-001 use-after-move.
- The wrapper compiles to the same i64 the rod's raw API uses; the
  effect is purely at the type-check layer.

Working example: `examples/30_typed_matrix.nr`.

## What it buys

- **Intent at the call site.** `let m: Matrix` reads as a matrix;
  `let m: i64` reads as an integer.
- **Cross-type rejection.** Passing an `i64` (e.g. a vector
  length) where a `Matrix` was expected becomes a type error
  instead of a silent integer-into-handle bug.
- **Surface for trait methods.** A future `impl Matrix` block could
  attach methods (`m.trace()`, `m.det()`) — currently those are
  free-functions `mat_trace(&m)` etc.

## What it doesn't buy (yet)

- **No dimensional checking.** `mat_mul(&A, &B)` doesn't enforce
  that `A.cols == B.rows`. A future `Matrix<R, C>` parametrized
  over compile-time row/column counts would close this gap; it
  needs const-generic support which is RFC-0034 territory.
- **No automatic ownership.** The `handle: i64` field is not auto-
  freed when the `Matrix` value drops, because the language doesn't
  yet track Vec/HashMap-style ownership for arbitrary user structs
  with handle fields. Adopters call `linalg_free(m.handle)`
  explicitly today, same as with the raw API.

## Roadmap (deferred work)

These belong on their own branches after the v1.1.1 line settles:

1. **`Matrix<R, C>` const-generic dimensions.** Requires RFC-0034
   compile-time parameters. Enables shape-checking at the type
   level (multiplying a 3×4 by a 5×6 becomes `TYP-???`).
2. **`QState<N>` for `stdlib/rods/qsim_*.nr`.** Same const-generic
   structure for quantum-state handles. Catches accidental
   mixing of states from different system sizes.
3. **`f64<Unit>` units-bearing scalars.** Per the architecture
   doc's discussion of "every value is i64." `Velocity = f64<m/s>`,
   `Acceleration = f64<m/s^2>`, etc. Requires units-as-types
   inference. Substantial language work — out of scope until the
   const-generic foundation lands.
4. **Auto-`Drop` for handle-holding structs.** Generalize the
   auto_drop framework's recognition of owned types beyond `Vec`
   and `HashMap` so that a `Matrix { handle: i64 }` value
   participating in auto_drop calls a registered free fn at scope
   end. Needs a `#[handle_drop = "fn"]` annotation on the struct
   declaration, processed by the auto_drop framework.

## Why we ship the wrapper pattern now

Even without const-generics, units, or auto-drop, the simple
newtype already:

- Documents intent in signatures (this is the biggest reviewer-
  friendliness win).
- Makes the API explorable in editor type-info.
- Compiles cleanly with the current type checker.
- Costs zero runtime — same emitted LLVM IR as the raw API.

Adopters can start using `Matrix` today (via the pattern in the
example), and migrate to richer types incrementally as RFC-0034
and the units work land.

## Existing rod authors

If you're maintaining a rod that exposes `i64` handles:

1. **Don't break the existing API.** Adopters that already use the
   raw `i64` form keep working unchanged.
2. **Add a parallel typed surface.** A new function
   `mat_new() -> Matrix` alongside the existing
   `linalg_new() -> i64`. Internally, `mat_new` calls `linalg_new`
   and wraps.
3. **Use `&Type` for read access** to avoid OWN-001 on multi-call
   usage patterns.

Or follow the `examples/30_typed_matrix.nr` recipe at the user
level without modifying the rod — for many use cases the wrapper
lives in the user's project rather than the rod.
