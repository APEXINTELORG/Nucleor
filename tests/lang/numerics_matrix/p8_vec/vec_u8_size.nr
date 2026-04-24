// p8_vec/vec_u8_size.nr — Phase 8: Vec<u8> packs 1 byte per element.
// Uses the direct vec_u8_* API which already provides byte-packed
// storage (see runtime nucleor_llvm_rt.c:2663+). Generic
// `Vec<T>::with_capacity` syntax sugar lands later in the
// monomorphization phase.

fn main() -> i32 {
    let v: i64 = vec_u8_with_capacity(1000);
    let mut i: i64 = 0;
    while i < 1000 {
        let _ = vec_u8_push(v, i & 0xFF);
        i = i + 1;
    };
    if vec_u8_len(v) != 1000 {
        print("FAIL: Vec<u8> push count\n");
        let _ = vec_u8_free(v);
        return 1;
    };
    if vec_u8_get(v, 100) != 100 {
        print("FAIL: Vec<u8> indexing\n");
        let _ = vec_u8_free(v);
        return 1;
    };
    let _ = vec_u8_free(v);
    print("OK vec_u8_size\n");
    return 0;
}
