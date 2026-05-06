// v0.8.312 R11 / QM-7 disclosure - clifford_limitations() helper.
//
// Locks 3 invariants:
//   1. clifford_limitations() non-empty
//   2. names the landed reset/rebuild round-trip coverage
//   3. names the remaining QASM and external citation gap
//
// Expected: rc=0.

import "stdlib/rods/clifford.nr"

fn check_limits() -> i64 {
    let s: str = clifford_limitations();
    if str_len(s) == 0 { return 1; };
    if str_index_of(s, "reset/rebuild round-trip coverage") < 0 { return 2; };
    if str_index_of(s, "NO QASM") < 0 { return 3; };
    if str_index_of(s, "rotated Surface-17 d=3") < 0 { return 4; };
    if str_index_of(s, "bounded stabilizer/logical weight-enumerator helpers") < 0 { return 5; };
    if str_index_of(s, "Published external weight-enumerator parity values") < 0 { return 6; };
    return 0;
}

fn main() -> i64 {
    return check_limits();
}
