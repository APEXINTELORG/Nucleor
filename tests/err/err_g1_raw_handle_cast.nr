// EXPECT: OWN-G1-RAW-HANDLE-CAST raw handle cast
// RFC-0062 G-1/G-4: casting a collection handle to i64 strips
// ownership identity and lets aliases escape auto-drop / double-free
// tracking. This must be an explicit compiler error.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    let alias: i64 = v as i64;
    print_int(alias as i32);
    0
}
