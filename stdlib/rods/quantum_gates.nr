// rods/quantum_gates - shared quantum gate type constants and logical kinds.
//
// QM-12 closure surface: common native IDs are shared for H/CNOT/X/Z.
// Rotation native IDs still diverge across backends, so callers should use
// the logical gate-kind constants plus qgate_kind_to_* mappers when a gate
// can target more than one quantum rod.

fn qgate_h() -> i64 { return 0; }
fn qgate_cnot() -> i64 { return 1; }
fn qgate_x() -> i64 { return 2; }
fn qgate_z() -> i64 { return 3; }

fn qgate_mps_rz() -> i64 { return 4; }
fn qgate_mps_rx() -> i64 { return 5; }
fn qgate_diff_rz() -> i64 { return 6; }
fn qgate_unsupported() -> i64 { return 0 - 1; }

fn qgate_kind_h() -> i64 { return 0; }
fn qgate_kind_cnot() -> i64 { return 1; }
fn qgate_kind_x() -> i64 { return 2; }
fn qgate_kind_z() -> i64 { return 3; }
fn qgate_kind_rz() -> i64 { return 4; }
fn qgate_kind_rx() -> i64 { return 5; }

fn qgate_common_supported(code: i64) -> i64 {
    if code == qgate_h() { return 1; };
    if code == qgate_cnot() { return 1; };
    if code == qgate_x() { return 1; };
    if code == qgate_z() { return 1; };
    return 0;
}

fn qgate_kind_supported(kind: i64) -> i64 {
    if kind == qgate_kind_h() { return 1; };
    if kind == qgate_kind_cnot() { return 1; };
    if kind == qgate_kind_x() { return 1; };
    if kind == qgate_kind_z() { return 1; };
    if kind == qgate_kind_rz() { return 1; };
    if kind == qgate_kind_rx() { return 1; };
    return 0;
}

fn qgate_kind_is_rotation(kind: i64) -> i64 {
    if kind == qgate_kind_rz() { return 1; };
    if kind == qgate_kind_rx() { return 1; };
    return 0;
}

fn qgate_kind_to_mps(kind: i64) -> i64 {
    if kind == qgate_kind_h() { return qgate_h(); };
    if kind == qgate_kind_cnot() { return qgate_cnot(); };
    if kind == qgate_kind_x() { return qgate_x(); };
    if kind == qgate_kind_z() { return qgate_z(); };
    if kind == qgate_kind_rz() { return qgate_mps_rz(); };
    if kind == qgate_kind_rx() { return qgate_mps_rx(); };
    return qgate_unsupported();
}

fn qgate_kind_to_diff(kind: i64) -> i64 {
    if kind == qgate_kind_h() { return qgate_h(); };
    if kind == qgate_kind_cnot() { return qgate_cnot(); };
    if kind == qgate_kind_x() { return qgate_x(); };
    if kind == qgate_kind_z() { return qgate_z(); };
    if kind == qgate_kind_rz() { return qgate_diff_rz(); };
    return qgate_unsupported();
}

fn qgate_kind_supported_by_mps(kind: i64) -> i64 {
    if qgate_kind_to_mps(kind) == qgate_unsupported() { return 0; };
    return 1;
}

fn qgate_kind_supported_by_diff(kind: i64) -> i64 {
    if qgate_kind_to_diff(kind) == qgate_unsupported() { return 0; };
    return 1;
}

fn qgate_limitations() -> str {
    return "quantum_gates constants (QM-12, v0834): shared common native gate IDs are H=0, CNOT=1, X=2, Z=3. Cross-rod callers should use logical gate kinds qgate_kind_* and explicit qgate_kind_to_mps/qgate_kind_to_diff mapping. RZ maps to MPS native 4 and diff_sim native 6; RX maps to MPS native 5 and is unsupported by diff_sim, returning qgate_unsupported(). This avoids silent cross-rod rotation-ID reuse while native dispatch tables remain different.";
}
