// simd_basic.nr — RFC-0033 (preview): SIMD vector types
// f32x4 / i32x4 / packed compute. Software-emulated for now;
// hardware vectorization arrives in v0.4 with LLVM intrinsic emit.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // f32x4 lane construction + read
    let v: i64 = f32x4_new(f32_from_int(1), f32_from_int(2), f32_from_int(3), f32_from_int(4));
    if f32_to_int(f32x4_get(v, 0)) != 1 { fail = fail + 1; print("FAIL: f32x4 lane 0\n"); };
    if f32_to_int(f32x4_get(v, 3)) != 4 { fail = fail + 1; print("FAIL: f32x4 lane 3\n"); };

    // splat
    let s: i64 = f32x4_splat(f32_from_int(7));
    if f32_to_int(f32x4_get(s, 0)) != 7 { fail = fail + 1; print("FAIL: splat 0\n"); };
    if f32_to_int(f32x4_get(s, 2)) != 7 { fail = fail + 1; print("FAIL: splat 2\n"); };

    // packed add
    let w: i64 = f32x4_new(f32_from_int(10), f32_from_int(20), f32_from_int(30), f32_from_int(40));
    let sum_v: i64 = f32x4_add(v, w);
    if f32_to_int(f32x4_get(sum_v, 0)) != 11 { fail = fail + 1; print("FAIL: packed add 0\n"); };
    if f32_to_int(f32x4_get(sum_v, 3)) != 44 { fail = fail + 1; print("FAIL: packed add 3\n"); };

    // dot product
    let dp: i64 = f32x4_dot(v, w);  // 1*10 + 2*20 + 3*30 + 4*40 = 10+40+90+160 = 300
    if f32_to_int(dp) != 300 { fail = fail + 1; print("FAIL: f32x4 dot\n"); };

    // sum / max / min
    if f32_to_int(f32x4_sum(v)) != 10 { fail = fail + 1; print("FAIL: f32x4 sum\n"); };
    if f32_to_int(f32x4_max(v)) != 4 { fail = fail + 1; print("FAIL: f32x4 max\n"); };
    if f32_to_int(f32x4_min(v)) != 1 { fail = fail + 1; print("FAIL: f32x4 min\n"); };

    // i32x4
    let iv: i64 = i32x4_new(100, 200, 300, 400);
    if i32x4_get(iv, 0) != 100 { fail = fail + 1; print("FAIL: i32x4 lane 0\n"); };
    if i32x4_sum(iv) != 1000 { fail = fail + 1; print("FAIL: i32x4 sum\n"); };

    let iw: i64 = i32x4_splat(5);
    let iprod: i64 = i32x4_mul(iv, iw);
    if i32x4_get(iprod, 0) != 500 { fail = fail + 1; print("FAIL: i32x4 mul 0\n"); };

    f32x4_free(v); f32x4_free(s); f32x4_free(w); f32x4_free(sum_v);
    i32x4_free(iv); i32x4_free(iw); i32x4_free(iprod);

    if fail == 0 { print("OK simd_basic\n"); return 0; };
    return 1;
}
