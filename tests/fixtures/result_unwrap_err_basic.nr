// result_unwrap_err_basic.nr — v0.6.34 regression fixture (positive).
//
// Closes gap 3 of probe finding 2026-05-02-result-option-unwrap-
// diag-and-correctness-gaps. Pre-fix `Result::unwrap_err()` was
// not implemented — calls failed at clang link with TYP-005.
// v0.6.34 adds the runtime helper + compiler dispatch; on Err(x)
// returns the err payload, on Ok(_) panics with the canonical
// Rust message.
//
// Build + run; expect exit 0 with output "oops".

fn main() -> i32 {
    let r: Result<i64, str> = Err("oops");
    let e: str = r.unwrap_err();
    print(e);
    0
}
