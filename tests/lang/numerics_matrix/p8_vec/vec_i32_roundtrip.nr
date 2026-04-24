// p8_vec/vec_i32_roundtrip.nr — Phase 8: Vec stores i32 round-trip.
// Uses the generic vec_* API (i64-slot storage). True byte-packed
// Vec<i32> with 4-byte slots is a future monomorphization phase
// step; what matters here is that i32 values round-trip correctly.

fn main() -> i32 {
    let v: i64 = vec_new();
    let max32: i32 = 2147483647;
    let _ = vec_push(v, max32);
    let _ = vec_push(v, 0 - 1);
    let _ = vec_push(v, 0);
    if vec_get(v, 0) != max32 {
        print("FAIL: Vec i32 max\n");
        return 1;
    };
    if vec_get(v, 1) != (0 - 1) {
        print("FAIL: Vec i32 -1\n");
        return 1;
    };
    print("OK vec_i32_roundtrip\n");
    return 0;
}
