// toml_basic.nr — RFC-0019 phase 1: minimal TOML parser
// Tests the subset spec'd for nuc.toml manifests:
//   - [section] headers, dotted keys
//   - key = "string" / int / true / false
//   - # line comments

fn main() -> i32 {
    let mut fail: i64 = 0;

    let src: str = "# Comment line
name = \"my_robot\"
version = \"0.3.1\"
release = true
debug = false
threads = 8

[deps]
nucleor-ros2 = \"1.2\"
nucleor-mujoco = \"1.0\"

[profile.release]
opt_level = 3
lto = true
";

    let m: i64 = toml_parse_string(src);

    // Top-level string
    let name: i64 = toml_get_str(m, "name");
    if name == 0 { fail = fail + 1; print("FAIL: name missing\n"); };

    // Top-level int
    if toml_get_int(m, "threads") != 8 { fail = fail + 1; print("FAIL: threads != 8\n"); };

    // Bool true
    if toml_get_int(m, "release") != 1 { fail = fail + 1; print("FAIL: release != true\n"); };

    // Bool false
    if toml_get_int(m, "debug") != 0 { fail = fail + 1; print("FAIL: debug != false\n"); };

    // Section key
    if toml_has(m, "deps.nucleor-ros2") != 1 { fail = fail + 1; print("FAIL: deps.nucleor-ros2 missing\n"); };

    // Dotted section
    if toml_get_int(m, "profile.release.opt_level") != 3 { fail = fail + 1; print("FAIL: opt_level\n"); };
    if toml_get_int(m, "profile.release.lto") != 1 { fail = fail + 1; print("FAIL: lto\n"); };

    // Missing key returns 0
    if toml_has(m, "missing") != 0 { fail = fail + 1; print("FAIL: missing key reported\n"); };

    if fail == 0 { print("OK toml_basic\n"); return 0; };
    return 1;
}
