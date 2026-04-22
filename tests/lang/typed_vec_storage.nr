// typed_vec_storage.nr — RFC-0015 phase 5b: honest narrow-storage Vecs
// Vec<u8> at 1 byte/elem instead of 8.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let buf: i64 = vec_u8_new();
    vec_u8_push(buf, 0xAB);
    vec_u8_push(buf, 0xCD);
    vec_u8_push(buf, 0xEF);
    if vec_u8_len(buf) != 3 { fail = fail + 1; print("FAIL: vec_u8 len\n"); };
    if vec_u8_get(buf, 0) != 0xAB { fail = fail + 1; print("FAIL: vec_u8 get 0\n"); };
    if vec_u8_get(buf, 2) != 0xEF { fail = fail + 1; print("FAIL: vec_u8 get 2\n"); };

    // Push value > 255 — should truncate to byte
    vec_u8_push(buf, 300);
    if vec_u8_get(buf, 3) != 44 { fail = fail + 1; print("FAIL: vec_u8 truncate\n"); };

    // Mutate
    vec_u8_set(buf, 1, 0x42);
    if vec_u8_get(buf, 1) != 0x42 { fail = fail + 1; print("FAIL: vec_u8 set\n"); };

    vec_u8_free(buf);

    if fail == 0 { print("OK typed_vec_storage\n"); return 0; };
    return 1;
}
