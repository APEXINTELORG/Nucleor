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
