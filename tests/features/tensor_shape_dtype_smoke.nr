// v0.8.288 R08-D1 Phase 1 — tensor shape/dtype metadata.
//
// Per audit `BUILD_PLAN_R08_tensor_ml_autodiff.md` §1 R08-D1 (HIGH):
// tensor handles are untyped i64 slots; adopters get late or no
// errors when shapes / dtypes don't line up. Phase 1 ships
// `tensor_dtype()`, `tensor_can_matmul_2d()`, `tensor_shape_eq()`,
// and `tensor_limitations()`.
//
// Phase 1 acceptance:
//   - dtype query distinguishes valid vs invalid handle;
//   - matmul-compat predicate rejects 3D handles (ndim != 2)
//     and rejects null handles;
//   - shape-equality predicate distinguishes equal vs different
//     and rejects null handles;
//   - limitations names "DTYPE" and "SHAPE".
//
// Note: the only tensor constructor on the rod surface today is
// `tensor_new_3d(d1, d2, d3)` (always rank 3) plus
// `tensor_new_nd(shape_handle)` which requires a Vec runtime
// constructor not exposed at the .nr level. We therefore validate
// the predicates against the surface adopters can actually call.
//
// Locks 6 invariants:
//   1. Real (3D) tensor reports dtype `"i64"`.
//   2. Invalid handle (0) reports dtype `"invalid"`.
//   3. `tensor_can_matmul_2d` rejects two 3D tensors (both ndim=3, not 2).
//   4. `tensor_can_matmul_2d` rejects null handle.
//   5. **`tensor_shape_eq` accepts two same-shape 3D tensors and
//      rejects two different-shape 3D tensors**.
//   6. `tensor_limitations` names DTYPE + SHAPE.
//
// Expected: rc=0.

import "stdlib/rods/tensor_nd.nr"

fn check_dtype_real() -> i64 {
    let t: i64 = tensor_new_3d(2, 3, 4);
    if str_eq(tensor_dtype(t), "i64") != 1 { tensor_free(t); return 1; };
    tensor_free(t);
    return 0;
}

fn check_dtype_invalid() -> i64 {
    if str_eq(tensor_dtype(0), "invalid") != 1 { return 2; };
    return 0;
}

fn check_matmul_compat_rejects_3d() -> i64 {
    let a: i64 = tensor_new_3d(2, 3, 4);
    let b: i64 = tensor_new_3d(2, 4, 5);
    let bad: i64 = tensor_can_matmul_2d(a, b);
    tensor_free(a);
    tensor_free(b);
    if bad != 0 { return 4; };
    return 0;
}

fn check_matmul_compat_rejects_null() -> i64 {
    if tensor_can_matmul_2d(0, 0) != 0 { return 8; };
    return 0;
}

fn check_shape_eq() -> i64 {
    let a: i64 = tensor_new_3d(2, 3, 4);
    let b: i64 = tensor_new_3d(2, 3, 4);
    let c: i64 = tensor_new_3d(2, 3, 5);
    let eq_same: i64 = tensor_shape_eq(a, b);
    let eq_diff: i64 = tensor_shape_eq(a, c);
    let eq_null: i64 = tensor_shape_eq(0, a);
    tensor_free(a);
    tensor_free(b);
    tensor_free(c);
    if eq_same != 1 { return 16; };
    if eq_diff != 0 { return 32; };
    if eq_null != 0 { return 64; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = tensor_limitations();
    if str_len(s) == 0 { return 128; };
    if str_index_of(s, "DTYPE") < 0 { return 256; };
    if str_index_of(s, "SHAPE") < 0 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_dtype_real();
    fails = fails + check_dtype_invalid();
    fails = fails + check_matmul_compat_rejects_3d();
    fails = fails + check_matmul_compat_rejects_null();
    fails = fails + check_shape_eq();
    fails = fails + check_limitations();
    return fails;
}
