// repro_v85_vec_push_wrong_type.nr — v0.4.85 TYP-008 ext.
// Pre-fix `v.push("hello")` for `Vec<i64>` silently i64-stored
// the str pointer; reads of v[0] then produced garbage like
// 140700340798576. Adopters writing canonical Rust got E0308
// mismatched types.
//
// v0.4.85 catches the literal-RHS case at type-check (kind 1 / 2
// / 71 — int/str/float lit). Mirrors the v0.4.84 struct-field
// pattern. Variable-RHS cases would need full type_expr recursion
// which has crashed compiler self-build in prior attempts (see
// v0.4.71/v0.4.61 history); kept narrow to literal RHS only.
//
// EXPECT: build fails (msg contains "Vec<i64>.push").

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push("hello");
    println!("{}", v[0]);
    return 0;
}
