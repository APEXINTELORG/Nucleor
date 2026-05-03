// v0.6.97 (defensive halt): canonical Rust struct-update syntax
// `Point { x: 10, ..rest }` (functional record update) pre-fix
// surfaced as wrong-class `error[NR020]: parse error: expected
// ':', got identifier` after the parser saw `..` (token 58) and
// tried to read it as a field name. Now halts cleanly with a
// per-field workaround pointer. Negative fixture (compile rejects).
struct Point { x: i64, y: i64, z: i64 }

fn main() -> i32 {
    let a: Point = Point { x: 1, y: 2, z: 3 };
    let b: Point = Point { x: 10, ..a };    // ← halts: struct-update unsupported
    print_int(b.x as i32);
    return 0;
}
