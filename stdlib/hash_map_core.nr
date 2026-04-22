// Nucleor stdlib: hash_map_core
// HashMap operations for bootstrap compiler.
// Resource types use borrow semantics through builtins.

fn main() -> i32 {
    let m: StableHashMap = hashmap_new();
    hashmap_insert(m, 1, 3.14);
    hashmap_insert(m, 2, 2.71);
    let has_one: bool = hashmap_contains(m, 1);
    let has_three: bool = hashmap_contains(m, 3);
    let size: i32 = hashmap_len(m);
    print_bool(has_one);
    print_bool(has_three);
    print_int(size);
    hashmap_free(m);
    0
}
