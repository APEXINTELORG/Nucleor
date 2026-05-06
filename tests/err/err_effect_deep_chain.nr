// EXPECT: error[EFF-003]
// R05-D4 Phase 2b fail-closed coverage: this archived deep-chain
// restricts case must not compile silently while real restricts-block
// enforcement remains open.

fn leaf() -> i32 requires [net.connect] { 1 }
fn level2() -> i32 { leaf() + 1 }
fn level3() -> i32 { level2() + 1 }
fn level4() -> i32 { level3() + 1 }

fn main() -> i32 {
    restricts [net] {
        level4()
    }
}
