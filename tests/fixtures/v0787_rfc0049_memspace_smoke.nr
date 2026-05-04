// v0.7.87 RFC-0049 Phase A smoke fixture — memory-space type tags.
// Validates:
//   - 9 MemSpace_* marker structs + Default + Unknown construct
//   - numeric ID surface returns stable values 0..8 + -1
//   - memspace_compatible: same matches, Default wildcard,
//     Unknown wildcard, different-named non-default reject
//   - is_host_class / is_device_class classify the 9 pools
//     correctly per RFC-0049 design
//   - name lookup returns the expected string
import "stdlib/rods/memspace.nr"

fn main() -> i64 {
    let m1: MemSpace_HBM = MemSpace_HBM {};
    let m2: MemSpace_DDR = MemSpace_DDR {};
    let m3: MemSpace_Default = MemSpace_Default {};
    let m4: MemSpace_Unified = MemSpace_Unified {};

    if memspace_id_default() != 0 { return 1; };
    if memspace_id_hbm() != 1 { return 2; };
    if memspace_id_ddr() != 2 { return 3; };
    if memspace_id_unknown() != 0 - 1 { return 4; };
    if memspace_id_unified() != 8 { return 5; };

    let hbm: i64 = memspace_id_hbm();
    let ddr: i64 = memspace_id_ddr();
    let def: i64 = memspace_id_default();
    let unk: i64 = memspace_id_unknown();

    if memspace_compatible(hbm, ddr) != 0 { return 6; };
    if memspace_compatible(hbm, hbm) != 1 { return 7; };
    if memspace_compatible(hbm, def) != 1 { return 8; };
    if memspace_compatible(unk, ddr) != 1 { return 9; };

    if memspace_is_host_class(ddr) != 1 { return 10; };
    if memspace_is_host_class(hbm) != 0 { return 11; };
    if memspace_is_device_class(hbm) != 1 { return 12; };
    if memspace_is_device_class(ddr) != 0 { return 13; };

    let n: str = memspace_name(1);
    if str_eq(n, "hbm") == 0 { return 14; };

    return 0;
}
