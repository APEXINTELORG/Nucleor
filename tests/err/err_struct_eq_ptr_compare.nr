// EXPECT: error[TYP-011] `P == P` does pointer comparison
// v0.4.147: struct == / != / ord silently did pointer compare.
// Pre-fix `a == b` for two struct values at different heap
// addresses returned FALSE even when every field matched.
// Sister to v0.4.52 (str ==) and v0.4.61 (Vec ==). Rust would
// derive PartialEq for field-wise comparison; Nucleor doesn't
// auto-derive. Detect at kind-4 type-check when both sides
// resolve to the same user-defined struct type. Mirrored to
// nucleor_tools_suite.nr.

struct P { x: i64 }

fn main() -> i32 {
    let a: P = P { x: 1 };
    let b: P = P { x: 1 };
    if a == b { print_int(1); } else { print_int(0); };
    0
}
