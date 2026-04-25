// EXPECT: error[RT-001]
// T3.14 (v0.3.23) — locks in the design intent that
// #[allow_fn(CODE)] does NOT suppress error-tier diagnostics.
// Even though the user wrote #[allow_fn(RT-001)] on a fn that
// calls vec_push, RT-001 must still fire as an error and fail
// the build. Errors are intentionally non-suppressible per
// RFC-0001 (the warning ↔ error line is the *only* opt-out
// surface; the error-tier line is hard).

#[no_alloc]
#[allow_fn(RT-001)]
fn try_to_silence_error() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
    return 0;
}

fn main() -> i64 {
    return try_to_silence_error();
}
