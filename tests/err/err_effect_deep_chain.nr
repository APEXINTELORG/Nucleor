// EXPECT: error[EFF-003]
// R05-D5 v0841 transitive restricts ship: the bounded same-file
// transitive check now walks `restricts [net] { ... }` →
// `level4 → level3 → level2 → leaf` (depth-3 budget covers the
// four-fn chain) and reaches `leaf` (requires [net.connect]) —
// `net.connect` overlaps `net`, so EFF-003 fires on the restricts
// surface. `enforce_requires_direct_calls` still independently
// surfaces EFF-001 on `level2` for calling `leaf()` without
// declaring net.connect; both diagnostics are expected. Pre-v0841
// this fixture only emitted EFF-001 (v0840 confined the restricts-
// block check to direct builtin/declared-row violations); the
// EXPECT moved back to EFF-003 with the arrival of the transitive
// summary.

fn leaf() -> i32 requires [net.connect] { 1 }
fn level2() -> i32 { leaf() + 1 }
fn level3() -> i32 { level2() + 1 }
fn level4() -> i32 { level3() + 1 }

fn main() -> i32 {
    restricts [net] {
        level4()
    }
}
