// v0.7.88 RFC-0048 Phase A smoke fixture — hardware capability
// query surface. Validates:
//   - 12 capability IDs (fp4..metal) return stable values
//   - Per-cap `target_caps_has_*` fns all return 0 in Phase A
//     (no device-class dispatch yet)
//   - OS family queries call into the existing os_info rod
//   - target_caps_has_id() table-driven dispatch matches the
//     individual fns
//   - target_caps_id_name() returns the canonical name
import "stdlib/rods/target_caps.nr"

fn main() -> i64 {
    if target_cap_id_fp4() != 1 { return 1; };
    if target_cap_id_fp8() != 2 { return 2; };
    if target_cap_id_avx512() != 11 { return 3; };
    if target_cap_id_tensor_cores() != 20 { return 4; };
    if target_cap_id_cuda() != 21 { return 5; };

    if target_caps_has_fp4() != 0 { return 6; };
    if target_caps_has_avx512() != 0 { return 7; };
    if target_caps_has_cuda() != 0 { return 8; };

    let os_count: i64 = target_caps_os_windows() + target_caps_os_linux() + target_caps_os_macos() + target_caps_os_bsd();
    if os_count != 1 { return 9; };

    if target_caps_has_id(1) != target_caps_has_fp4() { return 10; };
    if target_caps_has_id(11) != target_caps_has_avx512() { return 11; };
    if target_caps_has_id(20) != target_caps_has_tensor_cores() { return 12; };

    if target_caps_has_id(999) != 0 { return 13; };

    let n: str = target_caps_id_name(11);
    if str_eq(n, "avx512") == 0 { return 14; };

    let n2: str = target_caps_id_name(999);
    if str_eq(n2, "unknown") == 0 { return 15; };

    if target_caps_is_64bit() != 1 { return 16; };

    return 0;
}
