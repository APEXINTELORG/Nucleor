// EXPECT: OWN-G4-USE-AFTER-DROP
// Lane 2 audit fix (G4-FN-2, 2026-05-08): method-form free
// (`v.free()`) must mark the receiver as freed, mirroring the
// kind-7 `vec_free(v)` detection. Without this, if the rod
// stdlib ever exposes `Vec::free()` as a method, G-4 collapses
// to no-op for the method form.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    v.free();
    let n: i32 = vec_get(v, 0) as i32;
    n
}
