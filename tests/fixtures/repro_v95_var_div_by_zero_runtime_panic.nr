// repro_v95_var_div_by_zero_runtime_panic.nr — v0.4.95.
// Pre-fix `let z = 0; let q = 10 / z;` (variable divisor zero)
// emitted raw `sdiv i64 10, 0` → SIGFPE → exit 127 with no error
// message. Adopters got a confusing crash. v0.4.74 NUM-009 only
// caught the literal-zero case.
//
// v0.4.95 makes div/mod always route through panic_div_i64 /
// panic_rem_i64 helpers (which already existed for opt-in
// strict mode via NUCLEOR_INT_STRICT_ARITH=1 — see v0.3.220).
// Div is rare enough in hot loops that the function-call
// overhead is negligible (perf revert in v0.3.220 was for
// + - * which dominate tight numeric loops).
//
// EXPECT: build succeeds, runtime panics with clean message
// "PANIC: i64 division by zero: 10 / 0", exit code != 0.

fn main() -> i64 {
    let z: i64 = 0;
    let q: i64 = 10 / z;
    println!("{}", q);
    return 0;
}
