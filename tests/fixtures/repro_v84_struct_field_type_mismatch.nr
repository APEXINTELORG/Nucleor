// repro_v84_struct_field_type_mismatch.nr — v0.4.84 TYP-008 ext.
// Pre-fix `Point { x: "hello", y: 2 }` for `x: i64` silently
// i64-stored the str pointer; reads of p.x then produced garbage
// like 140700202648688. Adopters writing canonical Rust got E0308
// mismatched types.
//
// v0.4.84 catches the literal-RHS case at struct-init type-check
// (kind 1 / 2 / 71 — int / str / float lit). Variable-RHS cases
// would need full type_expr recursion which has crashed compiler
// self-build in prior attempts (see v0.4.71/v0.4.61 history); kept
// narrow to literal RHS only.
//
// EXPECT: build fails (msg contains "struct-field type mismatch").

struct Point { x: i64, y: i64, }

fn main() -> i64 {
    let p: Point = Point { x: "hello", y: 2 };
    println!("{}", p.x);
    return 0;
}
