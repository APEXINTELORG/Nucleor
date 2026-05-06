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
extern fn nuc_t3_new_2d(rows: i64, cols: i64) -> i64;
extern fn nuc_t3_new_int_2d(rows: i64, cols: i64) -> i64;
extern fn nuc_t3_new_bool_2d(rows: i64, cols: i64) -> i64;
extern fn nuc_t3_new_nd(shape: i64) -> i64;
extern fn nuc_t3_new_int_nd(shape: i64) -> i64;
extern fn nuc_t3_new_bool_nd(shape: i64) -> i64;
extern fn nuc_t3_ndim(h: i64) -> i64;
extern fn nuc_t3_shape(h: i64, dim: i64) -> i64;
extern fn nuc_t3_total(h: i64) -> i64;
extern fn nuc_t3_dtype_code(h: i64) -> i64;
extern fn nuc_t3_get(h: i64, i: i64, j: i64, k: i64) -> i64;
extern fn nuc_t3_set(h: i64, i: i64, j: i64, k: i64, val: i64);
extern fn nuc_t3_get_flat(h: i64, idx: i64) -> i64;
extern fn nuc_t3_set_flat(h: i64, idx: i64, val: i64);
extern fn nuc_t3_get_int_flat(h: i64, idx: i64) -> i64;
extern fn nuc_t3_set_int_flat(h: i64, idx: i64, val: i64);
extern fn nuc_t3_get_bool_flat(h: i64, idx: i64) -> i64;
extern fn nuc_t3_set_bool_flat(h: i64, idx: i64, val: i64);
extern fn nuc_t3_fill(h: i64, val: i64);
extern fn nuc_t3_reshape(h: i64, shape: i64) -> i64;
extern fn nuc_t3_slice(h: i64, dim: i64, index: i64) -> i64;
extern fn nuc_t3_add(a: i64, b: i64) -> i64;
extern fn nuc_t3_mul(a: i64, b: i64) -> i64;
extern fn nuc_t3_scale(h: i64, s: i64) -> i64;
extern fn nuc_t3_sum_axis(h: i64, axis: i64) -> i64;
extern fn nuc_t3_bmm(a: i64, b: i64) -> i64;
extern fn nuc_t3_matmul(a: i64, b: i64) -> i64;
extern fn nuc_t3_transpose(h: i64) -> i64;
extern fn nuc_t3_permute(h: i64, axes: Vec<i64>) -> i64;
extern fn nuc_t3_free(h: i64);

fn tensor_new_3d(d1: i64, d2: i64, d3: i64) -> i64 { return nuc_t3_new(d1, d2, d3); }
fn tensor_new_2d(rows: i64, cols: i64) -> i64 { return nuc_t3_new_2d(rows, cols); }
fn tensor_new_int_2d(rows: i64, cols: i64) -> i64 { return nuc_t3_new_int_2d(rows, cols); }
fn tensor_new_bool_2d(rows: i64, cols: i64) -> i64 { return nuc_t3_new_bool_2d(rows, cols); }
fn tensor_new_nd(shape: i64) -> i64 { return nuc_t3_new_nd(shape); }
fn tensor_new_int_nd(shape: i64) -> i64 { return nuc_t3_new_int_nd(shape); }
fn tensor_new_bool_nd(shape: i64) -> i64 { return nuc_t3_new_bool_nd(shape); }
fn tensor_ndim(h: i64) -> i64 { return nuc_t3_ndim(h); }
fn tensor_shape(h: i64, dim: i64) -> i64 { return nuc_t3_shape(h, dim); }
fn tensor_total(h: i64) -> i64 { return nuc_t3_total(h); }
fn tensor_get_3d(h: i64, i: i64, j: i64, k: i64) -> i64 { return nuc_t3_get(h, i, j, k); }
fn tensor_set_3d(h: i64, i: i64, j: i64, k: i64, v: i64) { nuc_t3_set(h, i, j, k, v); }
fn tensor_get_flat(h: i64, idx: i64) -> i64 { return nuc_t3_get_flat(h, idx); }
fn tensor_set_flat(h: i64, idx: i64, v: i64) { nuc_t3_set_flat(h, idx, v); }
fn tensor_get_int_flat(h: i64, idx: i64) -> i64 { return nuc_t3_get_int_flat(h, idx); }
fn tensor_set_int_flat(h: i64, idx: i64, v: i64) { nuc_t3_set_int_flat(h, idx, v); }
fn tensor_get_bool_flat(h: i64, idx: i64) -> i64 { return nuc_t3_get_bool_flat(h, idx); }
fn tensor_set_bool_flat(h: i64, idx: i64, v: i64) { nuc_t3_set_bool_flat(h, idx, v); }
fn tensor_fill(h: i64, v: i64) { nuc_t3_fill(h, v); }
fn tensor_reshape(h: i64, shape: i64) -> i64 { return nuc_t3_reshape(h, shape); }
fn tensor_slice(h: i64, dim: i64, index: i64) -> i64 { return nuc_t3_slice(h, dim, index); }
fn tensor_add(a: i64, b: i64) -> i64 { return nuc_t3_add(a, b); }
fn tensor_mul(a: i64, b: i64) -> i64 { return nuc_t3_mul(a, b); }
fn tensor_scale(h: i64, s: i64) -> i64 { return nuc_t3_scale(h, s); }
fn tensor_sum_axis(h: i64, axis: i64) -> i64 { return nuc_t3_sum_axis(h, axis); }
fn tensor_bmm(a: i64, b: i64) -> i64 { return nuc_t3_bmm(a, b); }
fn tensor_matmul(a: i64, b: i64) -> i64 { return nuc_t3_matmul(a, b); }
fn tensor_transpose(h: i64) -> i64 { return nuc_t3_transpose(h); }
fn tensor_permute(h: i64, axes: Vec<i64>) -> i64 { return nuc_t3_permute(h, axes); }
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

fn tensor_dtype_code(h: i64) -> i64 { return nuc_t3_dtype_code(h); }
fn tensor_dtype_legacy_i64() -> i64 { return 1; }
fn tensor_dtype_int() -> i64 { return 2; }
fn tensor_dtype_bool() -> i64 { return 3; }

fn tensor_dtype(h: i64) -> str {
    if h == 0 { return "invalid"; };
    let code: i64 = nuc_t3_dtype_code(h);
    if code == 2 { return "int"; };
    if code == 3 { return "bool"; };
    return "i64";
}

fn tensor_is_int(h: i64) -> i64 {
    if nuc_t3_dtype_code(h) == 2 { return 1; };
    return 0;
}

fn tensor_is_bool(h: i64) -> i64 {
    if nuc_t3_dtype_code(h) == 3 { return 1; };
    return 0;
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
    return "Tensor rod limitations (ML-1/ML-2/ML-3/ML-15, audit R08-D1 v0.8.288 + helper1 v0856/v0857/v0866): (1) DTYPE: legacy tensors still expose i64/f64-bit payloads for compatibility, but explicit int and bool tensor constructors are shipped with tensor_new_int_2d / tensor_new_bool_2d and typed flat accessors. No f32/f64 named dtype surface yet. (2) SHAPE CHECKS: tensor_matmul returns 0 on non-2D or incompatible shapes; tensor_permute returns 0 for invalid axes; elementwise / bmm runtime ops may still trap or return an invalid handle on shape mismatch. Use tensor_can_matmul_2d() / tensor_shape_eq() to validate BEFORE the op call. (3) OPS: tensor_new_2d, tensor_matmul, tensor_transpose, tensor_permute, typed int tensors, and bool mask tensors are shipped. Phase 2 still needs compiler-visible TensorShape<N,M,...> types and broader mixed-precision kernel dispatch.";
}
