// p8_vec/vec_i32_roundtrip.nr — Phase 8: Vec<i32> width round-trip

fn main() -> i32 {
    let mut v: Vec<i32> = Vec::with_capacity(10);
    let max32: i32 = 2147483647;
    v.push(max32);
    v.push(0 - 1);
    v.push(0);
    if v[0] != max32 {
        print("FAIL: Vec<i32> max\n");
        return 1;
    };
    if v[1] != (0 - 1) {
        print("FAIL: Vec<i32> -1\n");
        return 1;
    };
    print("OK vec_i32_roundtrip\n");
    return 0;
}
