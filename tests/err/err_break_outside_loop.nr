// EXPECT: error[NR024] `break` outside any loop
// v0.4.112: misplaced break/continue silently no-op'd before this
// release because the kind==26/27 codegen path guarded the
// emission with `if lx >= 0` / `if lh >= 0`. Outside any loop
// lx/lh are -1 (or never set), so the stmt was DROPPED with no
// diagnostic — `fn main() { break; 0 }` compiled to
// `fn main() { 0 }` and exited cleanly. Now panics from codegen
// when the loop-context labels aren't valid.

fn main() -> i32 {
    break;
    0
}
