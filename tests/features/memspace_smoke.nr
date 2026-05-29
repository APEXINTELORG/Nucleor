// v0.8.204 stdlib/rods/memspace.nr first test coverage.
//
// RFC-0049 Phase A: memory-space type tags. Pre-v0.8.204:
// regression gate token-presence gate exists (v0.8.181) but no
// behavioral fixture.
//
// Locks four invariants that real Phase B compiler enforcement
// must NOT regress:
//
//   1. Stable IDs — hbm=1, ddr=2, default=0, unknown=-1.
//   2. Compatibility: same==1, default==1 (either side),
//      unknown==1 (either side), hbm vs ddr == 0 (cross-pool
//      hard fail).
//   3. Host class membership: ddr / pinned / unified /
//      default → host; hbm → not host.
//   4. Device class membership: hbm / cxl / scratchpad /
//      npu_sram / gpu_shared → device; ddr → not device.
//
// Expected: rc=0.

import "stdlib/rods/memspace.nr"

fn check_stable_ids() -> i64 {
    if memspace_id_default() != 0 { return 1; };
    if memspace_id_hbm() != 1 { return 2; };
    if memspace_id_ddr() != 2 { return 4; };
    if memspace_id_cxl() != 3 { return 8; };
    if memspace_id_scratchpad() != 4 { return 16; };
    if memspace_id_npu_sram() != 5 { return 32; };
    if memspace_id_gpu_shared() != 6 { return 64; };
    if memspace_id_pinned() != 7 { return 128; };
    if memspace_id_unified() != 8 { return 256; };
    if memspace_id_unknown() != (0 - 1) { return 512; };
    return 0;
}

fn check_compatibility() -> i64 {
    if memspace_compatible(memspace_id_hbm(), memspace_id_hbm()) != 1 { return 1024; };
    if memspace_compatible(memspace_id_default(), memspace_id_hbm()) != 1 { return 2048; };
    if memspace_compatible(memspace_id_hbm(), memspace_id_default()) != 1 { return 4096; };
    if memspace_compatible(memspace_id_hbm(), memspace_id_unknown()) != 1 { return 8192; };
    if memspace_compatible(memspace_id_hbm(), memspace_id_ddr()) != 0 { return 16384; };
    return 0;
}

fn check_host_class() -> i64 {
    if memspace_is_host_class(memspace_id_ddr()) != 1 { return 32768; };
    if memspace_is_host_class(memspace_id_pinned()) != 1 { return 65536; };
    if memspace_is_host_class(memspace_id_unified()) != 1 { return 131072; };
    if memspace_is_host_class(memspace_id_default()) != 1 { return 262144; };
    if memspace_is_host_class(memspace_id_hbm()) != 0 { return 524288; };
    return 0;
}

fn check_device_class() -> i64 {
    if memspace_is_device_class(memspace_id_hbm()) != 1 { return 1048576; };
    if memspace_is_device_class(memspace_id_cxl()) != 1 { return 2097152; };
    if memspace_is_device_class(memspace_id_scratchpad()) != 1 { return 4194304; };
    if memspace_is_device_class(memspace_id_npu_sram()) != 1 { return 8388608; };
    if memspace_is_device_class(memspace_id_gpu_shared()) != 1 { return 16777216; };
    if memspace_is_device_class(memspace_id_ddr()) != 0 { return 33554432; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_stable_ids();
    fails = fails + check_compatibility();
    fails = fails + check_host_class();
    fails = fails + check_device_class();
    return fails;
}
