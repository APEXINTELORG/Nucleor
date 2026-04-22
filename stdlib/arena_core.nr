// Nucleor stdlib: arena_core
// Arena-based allocation for compiler data structures.

fn main() -> i32 {
    let ar: Arena = arena_new(4096);
    // Use arena in a scope so refs are dropped before reset
    {
        let p1: &i64 = arena_alloc(ar, 64);
        let p2: &i64 = arena_alloc(ar, 128);
        print_int(*p1);
    };
    arena_reset(ar);
    arena_destroy(ar);
    print("arena: ok");
    0
}
