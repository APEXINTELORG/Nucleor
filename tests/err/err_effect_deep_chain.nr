// EXPECT: error[EFF-001]
// R05-D4 Phase 2b first slice (local-claude v0840): block-form
// restricts is now really enforced for direct builtin/declared-row
// violations only. The deep transitive chain here (level4→level3→
// level2→leaf where leaf declares `requires [net.connect]` and the
// intermediates omit the row) is not in the restricts-block direct
// check, but `enforce_requires_direct_calls` traps `level2()`
// calling `leaf()` without declaring net.connect, so the build still
// halts loudly. Whole-program effect inference stays queued for
// Phase 2b — when it lands this fixture moves back to EFF-003 with
// restricts-block deep-chain coverage.

fn leaf() -> i32 requires [net.connect] { 1 }
fn level2() -> i32 { leaf() + 1 }
fn level3() -> i32 { level2() + 1 }
fn level4() -> i32 { level3() + 1 }

fn main() -> i32 {
    restricts [net] {
        level4()
    }
}
