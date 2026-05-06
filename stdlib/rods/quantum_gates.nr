// rods/quantum_gates - shared quantum gate type constants.
//
// QM-12 closure surface: MPS and diff_sim share the common H/CNOT/X/Z
// gate IDs. Rotation IDs are intentionally rod-specific because the
// current native dispatch tables diverge: MPS uses RZ=4/RX=5 while
// diff_sim uses RZ=6.

fn qgate_h() -> i64 { return 0; }
fn qgate_cnot() -> i64 { return 1; }
fn qgate_x() -> i64 { return 2; }
fn qgate_z() -> i64 { return 3; }

fn qgate_mps_rz() -> i64 { return 4; }
fn qgate_mps_rx() -> i64 { return 5; }
fn qgate_diff_rz() -> i64 { return 6; }

fn qgate_common_supported(code: i64) -> i64 {
    if code == qgate_h() { return 1; };
    if code == qgate_cnot() { return 1; };
    if code == qgate_x() { return 1; };
    if code == qgate_z() { return 1; };
    return 0;
}

fn qgate_limitations() -> str {
    return "quantum_gates constants (QM-12, v0830): shared common gate IDs are H=0, CNOT=1, X=2, Z=3 and are consumed by mps.nr and diff_sim.nr. Rotation IDs are rod-specific today: MPS RZ=4/RX=5, diff_sim RZ=6. Do not treat rotation IDs as cross-rod until the native dispatch tables are unified.";
}
