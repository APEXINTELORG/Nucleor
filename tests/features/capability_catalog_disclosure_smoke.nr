// v0.8.290 R05-D3 Phase 1 — capability catalog disclosure.
//
// Per audit `BUILD_PLAN_R05_effect_capability.md` §1 R05-D3 (HIGH):
// the s1 compiler recognizes ONLY `RandomCap` as a capability
// type today; FsCap / NetCap / TimeCap / EnvCap / SchedCap are
// NOT recognized despite RFC claims.
//
// Phase 1 ships `stdlib/rods/capabilities.nr` with
// `capability_supported(name)`, `capability_only_supported()`,
// and `capabilities_limitations()`. Adopters can query before
// designing around an unsupported capability.
//
// Phase 1 acceptance:
//   - RandomCap reports supported = 1;
//   - five Phase 2 capabilities report supported = 0;
//   - `capability_only_supported()` returns "RandomCap";
//   - limitations text names "RandomCap" + "FsCap".
//
// Locks 8 invariants:
//   1. RandomCap supported — supported = 1.
//   2. FsCap NOT supported — supported = 0.
//   3. NetCap NOT supported — supported = 0.
//   4. TimeCap NOT supported — supported = 0.
//   5. EnvCap NOT supported — supported = 0.
//   6. SchedCap NOT supported — supported = 0.
//   7. `capability_only_supported()` == `"RandomCap"`.
//   8. Limitations text names RandomCap + FsCap.
//
// Expected: rc=0.

import "stdlib/rods/capabilities.nr"

fn check_random_supported() -> i64 {
    if capability_supported("RandomCap") != 1 { return 1; };
    return 0;
}

fn check_fs_not_supported() -> i64 {
    if capability_supported("FsCap") != 0 { return 2; };
    return 0;
}

fn check_net_not_supported() -> i64 {
    if capability_supported("NetCap") != 0 { return 4; };
    return 0;
}

fn check_time_not_supported() -> i64 {
    if capability_supported("TimeCap") != 0 { return 8; };
    return 0;
}

fn check_env_not_supported() -> i64 {
    if capability_supported("EnvCap") != 0 { return 16; };
    return 0;
}

fn check_sched_not_supported() -> i64 {
    if capability_supported("SchedCap") != 0 { return 32; };
    return 0;
}

fn check_only_supported() -> i64 {
    if str_eq(capability_only_supported(), "RandomCap") != 1 { return 64; };
    return 0;
}

fn check_limitations_names_caps() -> i64 {
    let s: str = capabilities_limitations();
    if str_len(s) == 0 { return 128; };
    if str_index_of(s, "RandomCap") < 0 { return 256; };
    if str_index_of(s, "FsCap") < 0 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_random_supported();
    fails = fails + check_fs_not_supported();
    fails = fails + check_net_not_supported();
    fails = fails + check_time_not_supported();
    fails = fails + check_env_not_supported();
    fails = fails + check_sched_not_supported();
    fails = fails + check_only_supported();
    fails = fails + check_limitations_names_caps();
    return fails;
}
