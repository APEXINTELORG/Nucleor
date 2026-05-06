// EXPECT: error[EFF-003]
// R05-D4 Phase 2b fail-closed coverage: restricts [sync] with
// channel creation must not compile silently while block-form
// restricts enforcement remains open.

fn main() -> i32 {
    restricts [sync] {
        let _ch: i64 = channel(2);
        0
    }
}
