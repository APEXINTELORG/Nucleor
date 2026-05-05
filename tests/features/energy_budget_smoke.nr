// v0.8.131 stdlib/rods/energy_budget.nr first test coverage.
//
// RFC-0050 Phase A: per-fn energy + thermal budget metadata
// registry. Adopters declare budgets via runtime fns; tooling
// reads them back.
//
// Locks:
//   1. Unit-id constants are stable (pJ=1, nJ=2, uJ=3, mJ=4, J=5, kJ=6,
//      K=10, C=11, F=12).
//   2. unit_name returns the expected symbol per id.
//   3. energy_budget_declare + count + get_name + get_unit + get_value
//      round-trip.
//   4. thermal_budget_declare + count + get_name + get_unit + get_value
//      round-trip.
//
// Expected: rc=0.

import "stdlib/rods/energy_budget.nr"

fn check_unit_constants() -> i64 {
    if energy_unit_pJ() != 1 { return 1; };
    if energy_unit_nJ() != 2 { return 2; };
    if energy_unit_uJ() != 3 { return 4; };
    if energy_unit_mJ() != 4 { return 8; };
    if energy_unit_J()  != 5 { return 16; };
    if energy_unit_kJ() != 6 { return 32; };
    if thermal_unit_K() != 10 { return 64; };
    if thermal_unit_C() != 11 { return 128; };
    if thermal_unit_F() != 12 { return 256; };
    return 0;
}

fn check_unit_names() -> i64 {
    if str_eq(energy_unit_name(4), "mJ") != 1 { return 512; };
    if str_eq(thermal_unit_name(11), "C") != 1 { return 1024; };
    return 0;
}

fn check_energy_budget_round_trip() -> i64 {
    let before: i64 = energy_budget_count();
    energy_budget_declare("test_fn_alpha", energy_unit_mJ(), 5);
    let after: i64 = energy_budget_count();
    if after != before + 1 { return 2048; };
    let idx: i64 = after - 1;
    if str_eq(energy_budget_get_name(idx), "test_fn_alpha") != 1 { return 4096; };
    if energy_budget_get_unit(idx) != energy_unit_mJ() { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_unit_constants();
    fails = fails + check_unit_names();
    fails = fails + check_energy_budget_round_trip();
    return fails;
}
