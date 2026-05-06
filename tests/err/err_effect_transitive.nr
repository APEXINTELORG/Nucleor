// EXPECT: error[EFF-003]
// R05-D4 Phase 2b fail-closed coverage: this archived transitive
// restricts case must not imply an enforced effect guarantee.

fn read_sensor() -> i32 requires [io.read] {
    42
}

fn middle() -> i32 requires [io.read] {
    read_sensor()
}

fn main() -> i32 {
    restricts [io] {
        middle()
    }
}
