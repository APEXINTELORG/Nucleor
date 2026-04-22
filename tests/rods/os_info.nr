// rods/os_info — verify OS family + pointer-width rod wrappers
import "stdlib/rods/os_info.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // OS family is one of the known values
    let f: i64 = os_family_tag();
    if f == 0 { fail = fail + 1; print("FAIL: unknown OS family"); };

    // Exactly one of is_windows / is_linux / is_macos / is_bsd is true
    let w: i64 = os_is_windows();
    let l: i64 = os_is_linux();
    let m: i64 = os_is_macos();
    let b: i64 = os_is_bsd();
    if (w + l + m + b) != 1 { fail = fail + 1; print("FAIL: exactly one OS check should be true"); };

    // Pointer width sane
    if os_pointer_bits() != 64 { fail = fail + 1; print("FAIL: pointer width != 64"); };
    if os_is_64bit() != 1 { fail = fail + 1; print("FAIL: not 64-bit"); };

    // Env: set + unset round-trip
    os_env_set("NUCLEOR_OS_TEST", "value123");
    os_env_unset("NUCLEOR_OS_TEST");

    if fail == 0 { print("OK os_info"); return 0; };
    return 1;
}
