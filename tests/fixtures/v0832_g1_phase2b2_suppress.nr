// v0.8.32 RFC-0062 G-1 Phase 2b-2 — `#[manual_drop]` suppress
// mechanism. When BOTH `#[auto_drop]` AND `#[manual_drop]` are
// on a fn, manual_drop wins (auto-drop is suppressed). Without
// the suppress, the explicit vec_free below + the generated
// auto-drop would double-free and likely segfault. With the
// suppress, only the explicit free runs and rc=7 cleanly.
//
// This test exercises Phase 2b-3 default-flip semantics in
// advance: every fn (after the flip) auto-drops unless
// `#[manual_drop]` opts out. Today the test is run with both
// attributes present to verify the suppress wiring.

#[auto_drop]
#[manual_drop]
fn dual_attrs() -> i64 {
    let v: Vec<i64> = Vec::new();
    vec_free(v);  // explicit; manual_drop suppresses generated drop
    return 7;
}

fn main() -> i64 {
    return dual_attrs();
}
