// EXPECT: error[EFF-001]
// R05-D4 Phase 2b: pure functions cannot call same-file functions
// whose `requires [...]` row declares an effect.
fn read_data() -> i32 requires [io.read] {
    42
}

pure fn compute(x: i32) -> i32 {
    // This must be a compile error — pure can't use io.read
    let val: i32 = read_data();
    val + x
}

fn main() -> i32 {
    compute(5)
}
