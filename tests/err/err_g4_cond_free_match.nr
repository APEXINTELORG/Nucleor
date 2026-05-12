// EXPECT: OWN-G4-USE-AFTER-DROP
// Regression gate G-4 CFG join: match arms must merge manual-free
// facts. If any arm frees a binding and another arm preserves it,
// a post-match read is conditionally use-after-drop.
enum Choice { FreeIt, KeepIt }

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    let choice: Choice = Choice::FreeIt;
    match choice {
        Choice::FreeIt => { vec_free(v); },
        Choice::KeepIt => { let _keep: i64 = 0; },
    };
    let n: i64 = vec_get(v, 0);
    return n as i32;
}
