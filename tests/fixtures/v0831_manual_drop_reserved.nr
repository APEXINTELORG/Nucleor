// v0.8.31 RFC-0062 G-1 Phase 2b-1 signal fixture — exercises
// `#[manual_drop]` reserved attribute. Build emits
// `info[MANUAL-DROP-RESERVED]: ... markers in build: 1` to
// surface the heads-up about the future default-flip semantics.
//
// Today the attribute is a NO-OP — adopter still must
// explicitly `vec_free` to release. Fixture rc=7.

#[manual_drop]
fn pure_manual() -> i64 {
    let v: Vec<i64> = Vec::new();
    vec_free(v);  // explicit free; auto-drop is opt-in via
                  // #[auto_drop] (separate attribute) in v0.x
    return 7;
}

fn main() -> i64 {
    return pure_manual();
}
