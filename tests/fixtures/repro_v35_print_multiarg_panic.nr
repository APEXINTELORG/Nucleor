// v0.4.35 silent miscompute closure: bare `print(a, b)` (multi-arg)
// used to print only the FIRST arg silently — extras dropped from
// the binary with no diagnostic. Now panics. Adopters wanting
// multi-arg formatting should use `print!` / `println!` macros.
// EXPECT: panic
fn main() -> i64 {
    let x: i64 = 42;
    print("x is", x);   // pre-fix printed "x is" only; x silently dropped
    return 0;
}
