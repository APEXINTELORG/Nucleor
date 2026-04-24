// p8_vec/vec_f32_basic.nr — Phase 8: Vec<f32>

fn main() -> i32 {
    let mut v: Vec<f32> = Vec::with_capacity(4);
    v.push(1.0);
    v.push(2.5);
    v.push(3.14);
    if v[1] != 2.5f32 {
        print("FAIL: Vec<f32> indexing\n");
        return 1;
    };
    print("OK vec_f32_basic\n");
    return 0;
}
