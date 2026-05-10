// manifest_validate.nr — RFC-0019: nuc.toml manifest validation
// Test the validator against well-formed and malformed manifests.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // Well-formed manifest
    let good: str = "[package]\nname = \"good_app\"\nversion = \"1.0.0\"\nedition = \"2026\"\nlicense = \"Apache-2.0\"\n";
    let g: i64 = toml_parse_string(good);
    let g_issues: i64 = manifest_validate(g);
    if g_issues != 0 { fail = fail + 1; print("FAIL: good manifest reported issues\n"); };

    // Missing version
    let bad1: str = "[package]\nname = \"app\"\nedition = \"2026\"\nlicense = \"Apache-2.0\"\n";
    let b1: i64 = toml_parse_string(bad1);
    let b1_issues: i64 = manifest_validate(b1);
    if b1_issues == 0 { fail = fail + 1; print("FAIL: missing version not detected\n"); };
    // Bit 0x02 set
    if b1_issues / 2 == (b1_issues / 4) * 2 { fail = fail + 1; print("FAIL: missing version bit 0x02 not set\n"); };

    // Bad version (no dots)
    let bad2: str = "[package]\nname = \"app\"\nversion = \"abc\"\nedition = \"2026\"\nlicense = \"MIT\"\n";
    let b2: i64 = toml_parse_string(bad2);
    let b2_issues: i64 = manifest_validate(b2);
    if b2_issues == 0 { fail = fail + 1; print("FAIL: bad version not detected\n"); };

    // Bad edition
    let bad3: str = "[package]\nname = \"app\"\nversion = \"1.0.0\"\nedition = \"1999\"\nlicense = \"MIT\"\n";
    let b3: i64 = toml_parse_string(bad3);
    let b3_issues: i64 = manifest_validate(b3);
    if b3_issues == 0 { fail = fail + 1; print("FAIL: bad edition not detected\n"); };

    // Empty
    let empty: i64 = toml_parse_string("");
    let e_issues: i64 = manifest_validate(empty);
    if e_issues == 0 { fail = fail + 1; print("FAIL: empty manifest reported OK\n"); };

    // Validate the canonical OSS nuc.toml
    let ours: i64 = toml_parse_file("nuc.toml");
    let ours_issues: i64 = manifest_validate(ours);
    if ours_issues != 0 { fail = fail + 1; print("FAIL: shipped nuc.toml has issues\n"); };

    if fail == 0 { print("OK manifest_validate\n"); return 0; };
    return 1;
}
