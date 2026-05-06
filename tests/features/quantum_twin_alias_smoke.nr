// helper1 ROBO-11 -- quantum_twin alias smoke.
//
// Locks the honest import path for the existing twin_core quantum
// noise model. Expected: rc=0.

import "stdlib/rods/quantum_twin.nr"

fn main() -> i64 {
    let tc: i64 = tc_init(2, f64_to_bits(0.001), f64_to_bits(0.005));
    if tc == 0 { return 1; };
    if tc_nq(tc) != 2 { return 2; };
    if tc_sv_a(tc) == 0 { return 4; };
    if tc_sv_b(tc) == 0 { return 8; };
    if tc_sv_a(tc) == tc_sv_b(tc) { return 16; };
    return 0;
}
