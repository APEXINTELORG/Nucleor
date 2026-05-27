// 05_quantum.nr — Bell-state preparation on the built-in quantum simulator.
// Build: nuc build examples/05_quantum.nr -o bell
// Run:   ./bell.exe
//
// Demonstrates: H + CNOT entangle two qubits into (|00> + |11>)/sqrt(2).
// After 1024 measurements, ~512 outcomes should be |00> and ~512 should be |11>.
// |01> and |10> outcomes should be exactly 0.

// `use std::quantum;` would be the shorter form, but the use-std-* path
// has a known cfile-collection bug that drops rod-side C files from the
// clang link line. The explicit import syntax composes the correct
// link set; tracked separately as a compiler issue.
import "stdlib/rods/quantum.nr"

fn str_from_int(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = "";
    let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 {
        let d: i64 = v - (v / 10) * 10;
        s = str_concat(str_substring("0123456789", d, d + 1), s);
        v = v / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

fn main() -> i64 {
    rng_seed(42);
    let mut count_00: i64 = 0;
    let mut count_01: i64 = 0;
    let mut count_10: i64 = 0;
    let mut count_11: i64 = 0;

    let shots: i64 = 1024;
    let mut s: i64 = 0;
    while s < shots {
        let sv: i64 = qsim_init(2);
        qsim_h(sv, 0);
        qsim_cnot(sv, 0, 1);
        let q0: i64 = qsim_measure(sv, 0);
        let q1: i64 = qsim_measure(sv, 1);
        if q0 == 0 && q1 == 0 { count_00 = count_00 + 1; };
        if q0 == 0 && q1 == 1 { count_01 = count_01 + 1; };
        if q0 == 1 && q1 == 0 { count_10 = count_10 + 1; };
        if q0 == 1 && q1 == 1 { count_11 = count_11 + 1; };
        s = s + 1;
    };

    print(str_concat("Bell state, ", str_concat(str_from_int(shots), " shots:")));
    print(str_concat("  |00> = ", str_from_int(count_00)));
    print(str_concat("  |01> = ", str_from_int(count_01)));
    print(str_concat("  |10> = ", str_from_int(count_10)));
    print(str_concat("  |11> = ", str_from_int(count_11)));
    print("expected: |01> and |10> are 0; |00> and |11> are ~512 each");
    return 0;
}
