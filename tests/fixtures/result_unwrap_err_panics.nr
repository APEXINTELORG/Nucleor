// result_unwrap_err_panics.nr — v0.6.33 regression fixture.
//
// Closes gap 2 (CRITICAL) of probe finding 2026-05-02-result-
// option-unwrap-diag-and-correctness-gaps. Pre-fix
// `Result::Err(x).unwrap()` SILENTLY returned the err payload as
// if it were the ok payload — no panic, no diagnostic. Adopters
// got garbage data and the program continued. v0.6.33 added a
// discriminant check to `__nucleor_result_unwrap` and panics
// with the canonical Rust message.
//
// Build + run; expect exit 1 with clean message.

fn main() -> i32 {
    let r: Result<i64, str> = Err("oops");
    let v: i64 = r.unwrap();
    print_int(v as i32);
    0
}
