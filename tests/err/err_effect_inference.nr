// EXPECT: error[EFF-003]
// R05-D5 v0841 transitive restricts ship: the bounded same-file
// transitive check now walks one hop from `restricts [io] { ... }`
// through the un-rowed `middle()` and reaches `read_sensor()`
// (requires [io.read]) — `io.read` overlaps `io`, so EFF-003 fires
// on the restricts surface. `enforce_requires_direct_calls` still
// independently surfaces EFF-001 on `middle()` because the
// requires-row direct guard is unchanged; both diagnostics are
// expected. Pre-v0841 this fixture only emitted EFF-001 (v0840
// confined the restricts-block check to direct builtin/declared-
// row violations); the EXPECT moved back to EFF-003 with the
// arrival of the transitive summary.

fn read_sensor() -> i32 requires [io.read] { 42 }

fn middle() -> i32 {
    read_sensor()
}

fn main() -> i32 {
    restricts [io] {
        middle()
    }
}
