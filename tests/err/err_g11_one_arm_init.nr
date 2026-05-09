// EXPECT: INIT-G11-READ-BEFORE-INIT
// Lane 2 audit fix (G11-B-1, 2026-05-08): the textbook G-11
// case (one-arm assignment, no else) was silent pre-fix because
// the cast wrapper at `return x as i32` hid the IDENT read from
// check_expr. The kind-99 cast walk now recurses into the
// operand so INIT-G11 fires.
fn main() -> i32 {
    let mut x: i64;
    let cond: i64 = 1;
    if cond == 1 {
        x = 7;
    };
    return x as i32;
}
