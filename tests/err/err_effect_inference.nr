// EXPECT: error[EFF-001]
// R05-D4 Phase 2b first slice (local-claude v0840): block-form
// restricts now parses cleanly and the source pre-pass enforces
// direct builtin/declared-row violations only. The transitive
// inference shape here (un-rowed `middle()` calls effectful
// `read_sensor()`) is not in the restricts-block direct check, but
// the existing `enforce_requires_direct_calls` independently traps
// `middle()` calling `read_sensor()` (requires [io.read]) without
// declaring io.read, so the build still halts loudly. Whole-program
// effect inference stays queued for Phase 2b — when it lands this
// fixture moves back to EFF-003 with restricts-block transitive
// coverage.

fn read_sensor() -> i32 requires [io.read] { 42 }

fn middle() -> i32 {
    read_sensor()
}

fn main() -> i32 {
    restricts [io] {
        middle()
    }
}
