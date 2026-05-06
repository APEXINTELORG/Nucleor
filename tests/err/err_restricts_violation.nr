// EXPECT: error[EFF-003]
// R05-D4 Phase 2b fail-closed coverage: restricts [io] with an
// effectful same-file call must fail loudly until real restricts
// effect checking replaces the current fail-closed diagnostic.

fn read_data() -> i32 requires [io.read] {
    42
}

fn main() -> i32 {
    restricts [io] {
        let x: i32 = read_data();
        x
    }
}
