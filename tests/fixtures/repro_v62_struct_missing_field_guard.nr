// repro_v62_struct_missing_field_guard.nr
//
// v0.4.62 NUC-FEEDBACK silent-default-zero close.
// Pre-fix `Point { x: 1, y: 2 }` for a struct with 3 fields
// silently defaulted the missing field (z) to 0. Adopters writing
// the canonical Rust idiom (which errors with E0063 — missing
// field) got a quiet wrong value.
//
// v0.4.62 emits TYP-012 in check_expr's kind-34 (STRUCT_INIT) handler
// when the init-list size is less than the struct's declared field
// count, with a workaround hint pointing at explicit listing or a
// constructor fn.

struct Point {
    x: i64,
    y: i64,
    z: i64,
}

fn main() -> i64 {
    let p: Point = Point { x: 1, y: 2 };   // TYP-012 expected (missing z)
    println!("{}", p.x);
    return 0;
}
