// EXPECT: error[EFF-003]
// R05-D4 Phase 2b fail-closed coverage: this archived inference case
// contains block-form restricts, which must fail loudly until real
// restricts-block effect enforcement lands.

fn read_sensor() -> i32 requires [io.read] { 42 }

fn middle() -> i32 {
    read_sensor()
}

fn main() -> i32 {
    restricts [io] {
        middle()
    }
}
