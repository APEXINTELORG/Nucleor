// EXPECT: error[EFF-003]
// R05-D5 v0841 transitive restricts ship: a restricts block reaches
// a rowed effectful function across three un-rowed intermediate
// hops. The bounded same-file transitive check walks up to
// depth=3 (four bodies total: block + three hops), so a chain
// `restricts [net] { l4() }` → `l4 → l3 → l2 → leaf
// requires [net.connect]` reports EFF-003 on the restricts surface.
// Distinct from `err_effect_deep_chain.nr`, which uses the
// `level2/3/4` naming and serves as the canonical regression for
// the prior fail-closed parser-level halt that this slice
// supersedes.

fn leaf() -> i32 requires [net.connect] { 1 }
fn l2() -> i32 { leaf() + 1 }
fn l3() -> i32 { l2() + 1 }
fn l4() -> i32 { l3() + 1 }

fn main() -> i32 {
    restricts [net] {
        l4()
    }
}
