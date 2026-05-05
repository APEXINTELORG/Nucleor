// v0.8.180 stdlib/rods/target_caps.nr first test coverage.
//
// RFC-0048 Phase A hardware capability queries. Sister to
// v0.8.147 RFC-0048 Phase B step-1 audit (which surfaces
// `target.has(...)` syntax usage at compile time). This rod is
// the runtime API.
//
// Pre-v0.8.180: zero coverage.
//
// Locks four invariants:
//   1. **Stable cap IDs**: documented IDs (fp4=1, fp8=2, etc.)
//      match the rod's helper fns.
//   2. **Phase A device caps return 0**: every device-class
//      feature (fp4 / fp8 / avx2 / cuda / etc.) returns 0
//      because Nucleor v0.7+ has no accelerator dispatch yet.
//   3. **OS family via os_info**: exactly one of
//      windows/linux/macos returns 1 (we're on Windows here).
//   4. **target_caps_has_id**: round-trip — has_id(1) matches
//      has_fp4() (both 0); has_id(99) (unknown) returns 0.
//
// Expected: rc=0.

import "stdlib/rods/target_caps.nr"

fn check_cap_ids() -> i64 {
    if target_cap_id_fp4() != 1 { return 1; };
    if target_cap_id_fp8() != 2 { return 2; };
    if target_cap_id_bf16() != 3 { return 4; };
    if target_cap_id_avx2() != 10 { return 8; };
    if target_cap_id_cuda() != 21 { return 16; };
    return 0;
}

fn check_phase_a_device_caps_zero() -> i64 {
    if target_caps_has_fp4() != 0 { return 32; };
    if target_caps_has_avx512() != 0 { return 64; };
    if target_caps_has_cuda() != 0 { return 128; };
    if target_caps_has_metal() != 0 { return 256; };
    return 0;
}

fn check_os_family_one_hot() -> i64 {
    let win: i64 = target_caps_os_windows();
    let lin: i64 = target_caps_os_linux();
    let mac: i64 = target_caps_os_macos();
    let total: i64 = win + lin + mac;
    if total != 1 { return 512; };
    return 0;
}

fn check_has_id_round_trip() -> i64 {
    if target_caps_has_id(1) != target_caps_has_fp4() { return 1024; };
    if target_caps_has_id(11) != target_caps_has_avx512() { return 2048; };
    // Unknown id → 0
    if target_caps_has_id(99) != 0 { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_cap_ids();
    fails = fails + check_phase_a_device_caps_zero();
    fails = fails + check_os_family_one_hot();
    fails = fails + check_has_id_round_trip();
    return fails;
}
