// v0.8.312 R11 / QM-7 disclosure — clifford_limitations() helper.
//
// Locks 3 invariants:
//   1. clifford_limitations() non-empty
//   2. names "ZERO TEST COVERAGE"
//   3. names "QASM"
//
// Expected: rc=0.

import "stdlib/rods/clifford.nr"

fn check_limits() -> i64 {
    let s: str = clifford_limitations();
    if str_len(s) == 0 { return 1; };
    if str_index_of(s, "ZERO TEST COVERAGE") < 0 { return 2; };
    if str_index_of(s, "QASM") < 0 { return 4; };
    return 0;
}

fn main() -> i64 {
    return check_limits();
}
