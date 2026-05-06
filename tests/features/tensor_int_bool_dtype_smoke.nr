// Helper1 v0866: ML-15 P2a explicit int/bool tensor dtype surfaces.
//
// Expected: rc=0.

import "stdlib/rods/tensor_nd.nr"

fn check_int_tensor() -> i64 {
    let t: i64 = tensor_new_int_2d(2, 3);
    if t == 0 { return 1; };
    if str_eq(tensor_dtype(t), "int") != 1 { tensor_free(t); return 2; };
    if tensor_dtype_code(t) != tensor_dtype_int() { tensor_free(t); return 4; };
    if tensor_is_int(t) != 1 { tensor_free(t); return 8; };
    if tensor_is_bool(t) != 0 { tensor_free(t); return 16; };
    if tensor_ndim(t) != 2 { tensor_free(t); return 32; };
    if tensor_shape(t, 0) != 2 { tensor_free(t); return 64; };
    if tensor_shape(t, 1) != 3 { tensor_free(t); return 128; };
    tensor_set_int_flat(t, 0, 42);
    tensor_set_int_flat(t, 5, -7);
    if tensor_get_int_flat(t, 0) != 42 { tensor_free(t); return 256; };
    if tensor_get_int_flat(t, 5) != -7 { tensor_free(t); return 512; };
    tensor_free(t);
    return 0;
}

fn check_bool_tensor() -> i64 {
    let t: i64 = tensor_new_bool_2d(2, 2);
    if t == 0 { return 1024; };
    if str_eq(tensor_dtype(t), "bool") != 1 { tensor_free(t); return 2048; };
    if tensor_dtype_code(t) != tensor_dtype_bool() { tensor_free(t); return 4096; };
    if tensor_is_bool(t) != 1 { tensor_free(t); return 8192; };
    if tensor_is_int(t) != 0 { tensor_free(t); return 16384; };
    tensor_set_bool_flat(t, 0, 0);
    tensor_set_bool_flat(t, 1, 1);
    tensor_set_bool_flat(t, 2, 99);
    if tensor_get_bool_flat(t, 0) != 0 { tensor_free(t); return 32768; };
    if tensor_get_bool_flat(t, 1) != 1 { tensor_free(t); return 65536; };
    if tensor_get_bool_flat(t, 2) != 1 { tensor_free(t); return 131072; };
    tensor_free(t);
    return 0;
}

fn check_legacy_dtype_still_works() -> i64 {
    let t: i64 = tensor_new_2d(1, 1);
    if str_eq(tensor_dtype(t), "i64") != 1 { tensor_free(t); return 262144; };
    if tensor_dtype_code(t) != tensor_dtype_legacy_i64() { tensor_free(t); return 524288; };
    if tensor_is_int(t) != 0 { tensor_free(t); return 1048576; };
    if tensor_is_bool(t) != 0 { tensor_free(t); return 2097152; };
    tensor_free(t);
    return 0;
}

fn check_limitations_names_new_surface() -> i64 {
    let s: str = tensor_limitations();
    if str_index_of(s, "tensor_new_int_2d") < 0 { return 4194304; };
    if str_index_of(s, "bool mask") < 0 { return 8388608; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_int_tensor();
    fails = fails + check_bool_tensor();
    fails = fails + check_legacy_dtype_still_works();
    fails = fails + check_limitations_names_new_surface();
    return fails;
}
