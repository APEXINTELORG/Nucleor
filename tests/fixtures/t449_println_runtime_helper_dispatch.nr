// t449_println_runtime_helper_dispatch.nr -- v0.3.183 regression
// fixture.
//
// Sister fix to v0.3.178 (print() runtime-helper return-type
// fallback). The println! `{}` heuristic only knew about USER-
// declared fns (via infer_fn_return_type_from_source) and lacked
// a fallback for RUNTIME helpers like str_concat / str_to_lower /
// vec_len / etc.
//
// `println!("{}", str_concat(a, b))` printed the str pointer as
// int (silent miscompute on a canonical adopter pattern).
//
// Same hazard class as v0.3.178 -- a real adopter expression
// produces nonsense output with no diagnostic.
//
// Fix (v0.3.183): add a hardcoded fallback list of well-known
// runtime helpers in the println! `{}` fn-call dispatch.
//   - str returns: str_concat / str_substring / str_to_lower /
//     str_to_upper / str_trim variants / str_replace / str_repeat /
//     str_reverse / str_pad_*/center / str_intern / str_arena_* /
//     tok_decode / f64_to_str / f32_to_str / int_to_str /
//     bool_to_str / getenv -> identity (default)
//   - i64 returns: str_len / str_to_int / str_to_i64 /
//     str_index_of / str_count / vec_len / hashmap_len ->
--     int_to_str
--   - bool returns: str_eq / str_contains / str_starts_with /
--     str_ends_with / str_is_empty / vec_is_empty /
--     hashmap_contains / hashmap_is_empty -> bool_to_str

fn main() -> i64 {
    let s1: str = "hello, ";
    let s2: str = "world";
    println!("{}", str_concat(s1, s2));    // "hello, world"
    println!("{}", str_len("abc"));         // "3"
    println!("{}", str_eq("a", "a"));       // "true"
    return 42;
}
