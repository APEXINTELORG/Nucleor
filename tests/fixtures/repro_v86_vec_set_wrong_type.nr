// repro_v86_vec_set_wrong_type.nr — v0.4.86 TYP-008 ext.
// Pre-fix `v.set(0, "hello")` for `Vec<i64>` silently bit-cast
// the str pointer into the i64 cell. v0.4.86 extends the v0.4.85
// push narrow-RHS check to .insert and .set (element arg at
// position 1 instead of 0).
//
// EXPECT: build fails (msg contains "Vec<i64>.set").

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(42);
    v.set(0, "hello");
    println!("{}", v[0]);
    return 0;
}
