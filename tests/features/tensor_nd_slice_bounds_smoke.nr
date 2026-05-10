// Audit F-MATH-027: tensor_slice must reject out-of-range indices instead
// of reading past the backing buffer.

import "stdlib/rods/tensor_nd.nr"

fn main() -> i64 {
    let t: i64 = tensor_new_3d(2, 3, 4);
    tensor_fill(t, f64_to_bits(7.0));

    let s: i64 = tensor_slice(t, 1, 2);
    if s == 0 { tensor_free(t); return 1; };
    if tensor_ndim(s) != 2 { tensor_free(t); tensor_free(s); return 2; };
    if tensor_shape(s, 0) != 2 { tensor_free(t); tensor_free(s); return 4; };
    if tensor_shape(s, 1) != 4 { tensor_free(t); tensor_free(s); return 8; };

    let bad_hi: i64 = tensor_slice(t, 1, 3);
    if bad_hi != 0 { tensor_free(t); tensor_free(s); tensor_free(bad_hi); return 16; };
    let bad_neg: i64 = tensor_slice(t, 1, 0 - 1);
    if bad_neg != 0 { tensor_free(t); tensor_free(s); tensor_free(bad_neg); return 32; };

    tensor_free(t);
    tensor_free(s);
    return 0;
}
