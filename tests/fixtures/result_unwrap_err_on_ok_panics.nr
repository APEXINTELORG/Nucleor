// result_unwrap_err_on_ok_panics.nr — v0.6.34 regression fixture
// (negative). Mirror of result_unwrap_err_basic — calling
// `unwrap_err()` on Ok must panic with the canonical Rust
// message: "called `Result::unwrap_err()` on an `Ok` value".
//
// Build + run; expect exit 1 with the canonical message.

fn main() -> i32 {
    let r: Result<i64, str> = Ok(7);
    let v: str = r.unwrap_err();
    print(v);
    0
}
