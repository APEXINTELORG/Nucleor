// EXPECT: EFFECT-G10-UNKNOWN-NAME banana
// Lane 2 audit fix (G10-A-1, 2026-05-08): unknown effect names
// in #[effect(...)] / #[allow_effect(...)] silently dropped
// pre-fix. Typos like `may_retrun_null` lost the intended
// constraint. Now: emit error per unknown name with the closed
// list in the help text.
#[effect(frees, banana)]
fn weird(v: Vec<i64>) -> i32 {
    vec_free(v);
    0
}

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    weird(v)
}
