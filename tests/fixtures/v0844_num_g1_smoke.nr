// v0.8.44 NUM-G1 Phase 1 smoke — exercises the long-float
// regression gate info diagnostic. Adopter source contains 3 float
// literals with >6 fractional digits; build emits info[NUM-G1]
// flagging the silent lex truncation risk.
//
// rc=0 — runtime semantics are wrong (truncated values used) but
// the program runs; the regression gate only WARNS at compile time.

fn main() -> i64 {
    let pi: f64 = 3.1415926535897932;  // truncates to 3.141592
    let e: f64 = 2.7182818284590452;   // truncates to 2.718281
    let phi: f64 = 1.6180339887498948; // truncates to 1.618033
    return 0;
}
