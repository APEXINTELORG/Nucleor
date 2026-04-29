// EXPECT: error[NR024] `continue` outside any loop
// v0.4.112: sister to err_break_outside_loop. Same hazard class
// — codegen silently no-op'd misplaced control-flow stmts.

fn main() -> i32 {
    continue;
    0
}
