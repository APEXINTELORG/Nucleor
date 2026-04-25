// t360_match_arm_assign.nr — v0.3.84 regression fixture.
//
// Pins parser support for assignment in match-arm body: `pat => x = v,`.
// Pre-v0.3.84, parse_expr stopped at `=` and the `= RHS` was silently
// dropped, wrapping the LHS as a no-op expression-stmt. This produced
// programs that compiled and ran but mis-computed (assignments
// weren't actually performed).
//
// Returns 0 on success.

enum Stream { More(i64), Done }

fn main() -> i64 {
    // Test 1: assignment to outer var in arm body
    let mut total: i64 = 0;
    let s: Stream = Stream::More(42);
    match s {
        Stream::More(v) => total = v,
        Stream::Done => total = 0,
    };
    if total != 42 { return 91; };

    // Test 2: pure-expression arm bodies still work (regression check)
    let r: i64 = match Stream::More(7) {
        Stream::More(v) => v * 10,
        Stream::Done => 0,
    };
    if r != 70 { return 92; };

    // Test 3: mixed arms — assign + return + expr
    let mut x: i64 = 100;
    match Stream::Done {
        Stream::More(v) => x = v,
        Stream::Done => x = 999,
    };
    if x != 999 { return 93; };

    return 0;
}
