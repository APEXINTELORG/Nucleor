// rods/toml — verify the rod-level wrapper around the TOML parser builtin
import "stdlib/rods/toml.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let src: str = "[package]
name = \"my_robot\"
version = \"0.1.0\"

[deps]
ros2 = \"1.2\"
threads = 4
release_mode = true
debug_mode = false
";

    let t: i64 = toml(src);

    if toml_contains(t, "package.name") != 1 { fail = fail + 1; print("FAIL package.name"); };
    if toml_contains(t, "deps.ros2") != 1 { fail = fail + 1; print("FAIL deps.ros2"); };
    if toml_int(t, "deps.threads") != 4 { fail = fail + 1; print("FAIL deps.threads"); };
    if toml_bool(t, "deps.release_mode") != 1 { fail = fail + 1; print("FAIL release_mode"); };
    if toml_bool(t, "deps.debug_mode") != 0 { fail = fail + 1; print("FAIL debug_mode"); };
    if toml_contains(t, "missing.key") != 0 { fail = fail + 1; print("FAIL missing key"); };

    // Defaults
    if toml_int_or(t, "deps.threads", 99) != 4 { fail = fail + 1; print("FAIL int_or present"); };
    if toml_int_or(t, "missing.x", 99) != 99 { fail = fail + 1; print("FAIL int_or default"); };

    toml_free(t);

    if fail == 0 { print("OK toml"); return 0; };
    return 1;
}
