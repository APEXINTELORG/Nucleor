// v0852 QM-4 - MPS non-adjacent CNOT SWAP-overhead accounting.
//
// Locks both the preflight estimate and observed runtime counters for
// non-adjacent CNOT routing. A distance-3 CNOT uses two SWAPs to move
// the target next to the control and two SWAPs to restore the original
// order, so the reported overhead is 4.

import "stdlib/rods/mps.nr"

fn check_preflight() -> i64 {
    if mps_cnot_swap_overhead(4, 0, 1) != 0 { return 1; };
    if mps_cnot_swap_overhead(4, 0, 3) != 4 { return 2; };
    if mps_cnot_swap_overhead(4, 3, 0) != 4 { return 4; };
    if mps_cnot_swap_overhead(4, 1, 1) != 0 - 1 { return 8; };
    if mps_cnot_swap_overhead(4, 0, 4) != 0 - 1 { return 16; };
    if mps_cnot_swap_overhead(0, 0, 1) != 0 - 1 { return 32; };
    return 0;
}

fn check_runtime_counters() -> i64 {
    let h: i64 = mps_init(4, 16);
    if mps_last_swap_overhead(h) != 0 { mps_free(h); return 64; };
    if mps_total_swap_overhead(h) != 0 { mps_free(h); return 128; };

    mps_cnot(h, 0, 1);
    if mps_last_swap_overhead(h) != 0 { mps_free(h); return 256; };
    if mps_total_swap_overhead(h) != 0 { mps_free(h); return 512; };

    mps_cnot(h, 0, 3);
    if mps_last_swap_overhead(h) != 4 { mps_free(h); return 1024; };
    if mps_total_swap_overhead(h) != 4 { mps_free(h); return 2048; };

    mps_cnot(h, 3, 0);
    if mps_last_swap_overhead(h) != 4 { mps_free(h); return 4096; };
    if mps_total_swap_overhead(h) != 8 { mps_free(h); return 8192; };

    mps_h(h, 0);
    if mps_last_swap_overhead(h) != 0 { mps_free(h); return 16384; };
    if mps_total_swap_overhead(h) != 8 { mps_free(h); return 32768; };

    mps_free(h);
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = mps_limitations();
    if str_index_of(s, "QM-4") < 0 { return 65536; };
    if str_index_of(s, "mps_cnot_swap_overhead") < 0 { return 131072; };
    if str_index_of(s, "mps_total_swap_overhead") < 0 { return 262144; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_preflight();
    fails = fails + check_runtime_counters();
    fails = fails + check_limitations();
    return fails;
}
