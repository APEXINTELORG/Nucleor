// R05-D5 v0841 transitive restricts ship — positive smoke.
// A restricts block calls an un-rowed same-file user helper whose
// body is pure arithmetic plus a chain of un-rowed pure helpers.
// Nothing reachable within depth=3 hops touches a builtin in the
// effect map or a fn declared with a `requires [...]` row, so the
// transitive check returns clean and the build succeeds + the
// program exits 0. Sister to `restricts_block_clean_smoke.nr`,
// which exercises the no-call form. This fixture pins the
// "clean transitive chain" path the v0841 ship newly introduces.

fn add_one(x: i32) -> i32 { x + 1 }
fn double_then_add(x: i32) -> i32 { add_one(x + x) }
fn helper() -> i32 { double_then_add(0) }

fn main() -> i32 {
    restricts [io] {
        let r: i32 = helper();
        if r == 1 { 0 } else { 1 }
    }
}
