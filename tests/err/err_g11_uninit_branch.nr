// EXPECT: TYP-008 binding declared without initializer
// RFC-0062 G-11 Phase 1 — declare-without-init is rejected even
// when every if/else arm assigns. Phase 1 design choice: TYP-008
// fires unconditionally because Nucleor lacks flow-sensitive
// definite-assignment analysis. Adopters must initialize at the
// declaration point. Phase 2 may relax this if/when the
// definite-assignment pass lands; until then this fixture locks
// the v0.x behavior.

fn main() -> i64 {
    let mut cls: i64;       // ERROR: declared without initializer
    if true {
        cls = 1;
    } else {
        cls = 2;
    }
    return cls;
}
