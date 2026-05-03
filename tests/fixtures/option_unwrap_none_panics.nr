// option_unwrap_none_panics.nr — v0.6.33 regression fixture.
//
// Closes gap 1 of probe finding 2026-05-02-result-option-unwrap-
// diag-and-correctness-gaps. Pre-fix `Option::None.unwrap()`
// panicked with `vec_get OOB: index 1, len 1` (later "index out
// of bounds: the len is 1 but the index is 1" after v0.6.30) —
// both leaked the internal Vec representation. v0.6.33 added a
// discriminant check to `__nucleor_option_unwrap` and panics with
// the canonical Rust message.
//
// Build + run; expect exit 1 with clean message.

fn main() -> i32 {
    let o: Option<i64> = None;
    let v: i64 = o.unwrap();
    print_int(v as i32);
    0
}
