// EXPECT: error[EFF-001]
// R05-D4 Phase 2b: pure functions cannot call builtin print-family
// I/O helpers such as print_int().

pure fn bad() -> i32 {
    print_int(1);
    0
}

fn main() -> i32 {
    bad()
}
