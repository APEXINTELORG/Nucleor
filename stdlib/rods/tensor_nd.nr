// =====================================================
// rods/tensor_nd — N-Dimensional Tensors
// =====================================================
// Import: import "stdlib/rods/tensor_nd.nr"
// Provides: arbitrary-rank tensor construction, get/set
//   (multi-index and flat), reshape, slice, element-wise add/mul,
//   scale, sum-along-axis, batched matmul.
// =====================================================

#cfile "../runtime/tensor3d_rt.c"

extern fn nuc_t3_new(d1: i64, d2: i64, d3: i64) -> i64;
extern fn nuc_t3_new_nd(shape: i64) -> i64;
extern fn nuc_t3_ndim(h: i64) -> i64;
extern fn nuc_t3_shape(h: i64, dim: i64) -> i64;
extern fn nuc_t3_total(h: i64) -> i64;
extern fn nuc_t3_get(h: i64, i: i64, j: i64, k: i64) -> i64;
extern fn nuc_t3_set(h: i64, i: i64, j: i64, k: i64, val: i64);
extern fn nuc_t3_get_flat(h: i64, idx: i64) -> i64;
extern fn nuc_t3_set_flat(h: i64, idx: i64, val: i64);
extern fn nuc_t3_fill(h: i64, val: i64);
extern fn nuc_t3_reshape(h: i64, shape: i64) -> i64;
extern fn nuc_t3_slice(h: i64, dim: i64, index: i64) -> i64;
extern fn nuc_t3_add(a: i64, b: i64) -> i64;
extern fn nuc_t3_mul(a: i64, b: i64) -> i64;
extern fn nuc_t3_scale(h: i64, s: i64) -> i64;
extern fn nuc_t3_sum_axis(h: i64, axis: i64) -> i64;
extern fn nuc_t3_bmm(a: i64, b: i64) -> i64;
extern fn nuc_t3_free(h: i64);

fn tensor_new_3d(d1: i64, d2: i64, d3: i64) -> i64 { return nuc_t3_new(d1, d2, d3); }
fn tensor_new_nd(shape: i64) -> i64 { return nuc_t3_new_nd(shape); }
fn tensor_ndim(h: i64) -> i64 { return nuc_t3_ndim(h); }
fn tensor_shape(h: i64, dim: i64) -> i64 { return nuc_t3_shape(h, dim); }
fn tensor_total(h: i64) -> i64 { return nuc_t3_total(h); }
fn tensor_get_3d(h: i64, i: i64, j: i64, k: i64) -> i64 { return nuc_t3_get(h, i, j, k); }
fn tensor_set_3d(h: i64, i: i64, j: i64, k: i64, v: i64) { nuc_t3_set(h, i, j, k, v); }
fn tensor_get_flat(h: i64, idx: i64) -> i64 { return nuc_t3_get_flat(h, idx); }
fn tensor_set_flat(h: i64, idx: i64, v: i64) { nuc_t3_set_flat(h, idx, v); }
fn tensor_fill(h: i64, v: i64) { nuc_t3_fill(h, v); }
fn tensor_reshape(h: i64, shape: i64) -> i64 { return nuc_t3_reshape(h, shape); }
fn tensor_slice(h: i64, dim: i64, index: i64) -> i64 { return nuc_t3_slice(h, dim, index); }
fn tensor_add(a: i64, b: i64) -> i64 { return nuc_t3_add(a, b); }
fn tensor_mul(a: i64, b: i64) -> i64 { return nuc_t3_mul(a, b); }
fn tensor_scale(h: i64, s: i64) -> i64 { return nuc_t3_scale(h, s); }
fn tensor_sum_axis(h: i64, axis: i64) -> i64 { return nuc_t3_sum_axis(h, axis); }
fn tensor_bmm(a: i64, b: i64) -> i64 { return nuc_t3_bmm(a, b); }
fn tensor_free(h: i64) { nuc_t3_free(h); }

// === R08-D1 Phase 1 (v0.8.288) — tensor shape/dtype metadata ===
//
// Per audit `BUILD_PLAN_R08_tensor_ml_autodiff.md` §1 R08-D1 (HIGH):
// tensor handles are untyped i64 slots. Adopters who confuse a 3D
// shape order or assume an unsupported dtype get late or no error.
// Phase 1 ships dtype + shape-compat predicates adopters can call
// before invoking ops. Phase 2 wires runtime shape-mismatch
// diagnostics into matmul / transpose call paths and adds
// compiler-visible TensorShape types.

// All currently-shipped tensors are i64-element. Phase 2 wires
// f32/f64/i32 dtypes; today this is a single-value enum.
fn tensor_dtype(h: i64) -> str {
    if h == 0 { return "invalid"; };
    return "i64";
}

// Shape-compat predicate: can A @ B run as a 2D matmul?
// Returns 1 if A is 2D, B is 2D, and A.shape[1] == B.shape[0].
// Returns 0 otherwise (including when h is 0 / invalid).
// Adopters call this BEFORE invoking matmul to avoid runtime trap.
fn tensor_can_matmul_2d(a: i64, b: i64) -> i64 {
    if a == 0 { return 0; };
    if b == 0 { return 0; };
    let nda: i64 = nuc_t3_ndim(a);
    let ndb: i64 = nuc_t3_ndim(b);
    if nda != 2 { return 0; };
    if ndb != 2 { return 0; };
    let a_cols: i64 = nuc_t3_shape(a, 1);
    let b_rows: i64 = nuc_t3_shape(b, 0);
    if a_cols != b_rows { return 0; };
    return 1;
}

// Shape-equality predicate (rank + per-dim) for elementwise ops.
fn tensor_shape_eq(a: i64, b: i64) -> i64 {
    if a == 0 { return 0; };
    if b == 0 { return 0; };
    let nda: i64 = nuc_t3_ndim(a);
    let ndb: i64 = nuc_t3_ndim(b);
    if nda != ndb { return 0; };
    let mut i: i64 = 0;
    while i < nda {
        if nuc_t3_shape(a, i) != nuc_t3_shape(b, i) { return 0; };
        i = i + 1;
    };
    return 1;
}

fn tensor_limitations() -> str {
    return "Tensor rod limitations (ML-1, audit R08-D1 v0.8.288): (1) DTYPE: only i64 elements are shipped; tensor_dtype() always returns 'i64'. No f32/f64/i32 surfaces yet — adopters needing float tensors must encode bits into i64 manually or use the f64-bits helpers in numerics rod. (2) SHAPE CHECKS: matmul / elementwise / bmm runtime ops do NOT emit a stable diagnostic on shape mismatch — they may trap or return an invalid handle. Use tensor_can_matmul_2d() / tensor_shape_eq() to validate BEFORE the op call. (3) NO 2D MATMUL ALIAS: tensor_bmm is 3D-batched; there is no dedicated 2D matmul wrapper today (use bmm with batch=1 or a manual loop). Phase 2 wires per-op shape-mismatch diagnostics + compiler-visible TensorShape<N,M,...> types per RFC + multiple dtypes.";
}
