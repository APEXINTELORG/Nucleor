// p8_vec/vec_u8_size.nr — Phase 8: Vec<u8> = 1 byte/elem

fn main() -> i32 {
    let mut v: Vec<u8> = Vec::with_capacity(1000);
    for i in 0..1000 {
        v.push((i % 256) as u8);
    };
    if v.len() != 1000 {
        print("FAIL: Vec<u8> push count\n");
        return 1;
    };
    if v[100] != 100u8 {
        print("FAIL: Vec<u8> indexing\n");
        return 1;
    };
    print("OK vec_u8_size\n");
    return 0;
}
