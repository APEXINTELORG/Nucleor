// EXPECT: error[EFF-001]
// R05-D3 Phase 1: direct same-file calls must preserve a callee's
// `requires [...]` row on the caller. Transitive propagation stays
// queued for Phase 2b; this fixture locks the one-hop build-path check.

fn read_sensor() -> i32 requires [io.read] {
    42
}

fn middle() -> i32 {
    read_sensor()
}

fn main() -> i32 {
    middle()
}
