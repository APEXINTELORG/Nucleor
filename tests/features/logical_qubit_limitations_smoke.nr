// v0.8.285 R11-D5 Phase 1 — logical_qubit limitation diagnostic.
//
// Per audit `BUILD_PLAN_R11_quantum_subsystem.md` §1 R11-D5 (MEDIUM):
// pre-v0.8.285 the rod surface presented convention-level support
// for surface-code QEC, OpenQASM import/export, QIR export, and
// mid-circuit feedback — but the actual primitives are absent.
// Phase 1 ships `logical_qubit_limitations()` so adopters can
// query what's NOT supported.
//
// Phase 2 (per audit ship plan): surface-code invariant first,
// then OpenQASM round-trip, then mid-circuit feedback. Each
// new surface lands with a deterministic small fixture.
//
// Phase 1 acceptance:
//   - limitation helper returns non-empty string with key terms
//     (surface-code, OpenQASM, mid-circuit);
//   - cold compile <= 4s.
//
// Locks 4 invariants:
//   1. **Non-empty** — the helper returns a string with content.
//   2. **Names surface-code** — `"SURFACE-CODE"` substring present.
//   3. **Names OpenQASM** — `"OPENQASM"` substring present.
//   4. **Names mid-circuit feedback** — `"MID-CIRCUIT"` substring present.
//
// Expected: rc=0.

import "stdlib/rods/logical_qubit.nr"

fn check_non_empty() -> i64 {
    let s: str = logical_qubit_limitations();
    if str_len(s) == 0 { return 1; };
    return 0;
}

fn check_surface_code() -> i64 {
    let s: str = logical_qubit_limitations();
    if str_index_of(s, "SURFACE-CODE") < 0 { return 2; };
    return 0;
}

fn check_openqasm() -> i64 {
    let s: str = logical_qubit_limitations();
    if str_index_of(s, "OPENQASM") < 0 { return 4; };
    return 0;
}

fn check_mid_circuit() -> i64 {
    let s: str = logical_qubit_limitations();
    if str_index_of(s, "MID-CIRCUIT") < 0 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_non_empty();
    fails = fails + check_surface_code();
    fails = fails + check_openqasm();
    fails = fails + check_mid_circuit();
    return fails;
}
