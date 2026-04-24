// p3_layout/sizeof_primitives.nr — Phase 3a: sizeof_<T>() byte sizes

fn main() -> i32 {
    let mut fail: i64 = 0;

    if sizeof_i8()  != 1 { fail = fail + 1; print("FAIL: sizeof_i8\n"); };
    if sizeof_i16() != 2 { fail = fail + 1; print("FAIL: sizeof_i16\n"); };
    if sizeof_i32() != 4 { fail = fail + 1; print("FAIL: sizeof_i32\n"); };
    if sizeof_i64() != 8 { fail = fail + 1; print("FAIL: sizeof_i64\n"); };
    if sizeof_u8()  != 1 { fail = fail + 1; print("FAIL: sizeof_u8\n"); };
    if sizeof_u16() != 2 { fail = fail + 1; print("FAIL: sizeof_u16\n"); };
    if sizeof_u32() != 4 { fail = fail + 1; print("FAIL: sizeof_u32\n"); };
    if sizeof_u64() != 8 { fail = fail + 1; print("FAIL: sizeof_u64\n"); };
    if sizeof_f32() != 4 { fail = fail + 1; print("FAIL: sizeof_f32\n"); };
    if sizeof_f64() != 8 { fail = fail + 1; print("FAIL: sizeof_f64\n"); };
    if sizeof_f16() != 2 { fail = fail + 1; print("FAIL: sizeof_f16\n"); };
    if sizeof_bf16() != 2 { fail = fail + 1; print("FAIL: sizeof_bf16\n"); };
    if sizeof_bool() != 1 { fail = fail + 1; print("FAIL: sizeof_bool\n"); };
    if sizeof_usize() != 8 { fail = fail + 1; print("FAIL: sizeof_usize\n"); };
    if sizeof_isize() != 8 { fail = fail + 1; print("FAIL: sizeof_isize\n"); };
    if sizeof_ptr() != 8 { fail = fail + 1; print("FAIL: sizeof_ptr\n"); };
    if sizeof_char() != 4 { fail = fail + 1; print("FAIL: sizeof_char\n"); };

    if fail == 0 { print("OK sizeof_primitives\n"); return 0; };
    return 1;
}
