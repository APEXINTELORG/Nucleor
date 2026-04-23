// EXPECT: OWN-012 cannot destroy arena with live references
// Arena destruction while a borrow is still live. RFC-0001 ownership.
// Phase REGION-P1: Arena invalidation must not outlive live references

fn main() -> i32 {
    let ar: Arena = arena_new(4096);
    let ptr: &i64 = arena_alloc(ar, 64);
    arena_destroy(ar);
    0
}
