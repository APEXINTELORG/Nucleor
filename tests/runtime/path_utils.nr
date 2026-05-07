// path_utils — RFC-0017 / RFC-0022 stdlib enrichment.
//
//   path_separator()           -> str   "/" or "\\"
//   path_is_absolute(p)        -> i64
//   path_normalize(p)          -> str
//   path_with_extension(p, e)  -> str
//   path_strip_extension(p)    -> str
//   path_components(p)         -> Vec<str>

fn main() -> i64 {
    let mut fail: i64 = 0;

    // path_separator: should be a single character
    let sep: str = path_separator();
    if str_len(sep) != 1 { fail = fail + 1; print("FAIL path_separator len"); };

    // path_is_absolute
    if path_is_absolute("foo/bar") != 0  { fail = fail + 1; print("FAIL is_abs rel"); };
    if path_is_absolute("/foo/bar") != 1 { fail = fail + 1; print("FAIL is_abs root"); };
    // Drive-letter roots (C:/foo) are only absolute on Windows. POSIX
    // hosts treat C:/foo as a relative path whose first component is
    // the literal directory "C:". Gate on path_separator() == "\\".
    let on_windows: i64 = if str_eq(sep, "\\") == 1 { 1 } else { 0 };
    if on_windows == 1 {
        if path_is_absolute("C:/foo") != 1 { fail = fail + 1; print("FAIL is_abs drive (windows)"); };
    } else {
        if path_is_absolute("C:/foo") != 0 { fail = fail + 1; print("FAIL is_abs drive (posix)"); };
    };
    if path_is_absolute("") != 0          { fail = fail + 1; print("FAIL is_abs empty"); };

    // path_normalize: collapse . and ..
    let n1: str = path_normalize("a/b/../c");
    let n2: str = path_normalize("a/./b");
    let n3: str = path_normalize(".");
    if !str_eq(n1, "a\\c") && !str_eq(n1, "a/c") {
        fail = fail + 1; print("FAIL normalize ..");
    };
    if !str_eq(n2, "a\\b") && !str_eq(n2, "a/b") {
        fail = fail + 1; print("FAIL normalize .");
    };
    if !str_eq(n3, ".") { fail = fail + 1; print("FAIL normalize dot"); };

    // path_with_extension: replace existing
    let e1: str = path_with_extension("foo.txt", "md");
    if !str_eq(e1, "foo.md") { fail = fail + 1; print("FAIL ext replace"); };
    // path_with_extension: add when missing
    let e2: str = path_with_extension("README", "md");
    if !str_eq(e2, "README.md") { fail = fail + 1; print("FAIL ext add"); };
    // path_with_extension: leading dot tolerated
    let e3: str = path_with_extension("foo.txt", ".log");
    if !str_eq(e3, "foo.log") { fail = fail + 1; print("FAIL ext dot prefix"); };

    // path_strip_extension
    if !str_eq(path_strip_extension("foo.txt"), "foo") {
        fail = fail + 1; print("FAIL strip_ext");
    };
    if !str_eq(path_strip_extension("foo"), "foo") {
        fail = fail + 1; print("FAIL strip_ext none");
    };

    // path_components: returns Vec<str>
    let comps: Vec<str> = path_components("a/b/c.txt");
    if vec_len(comps) != 3 { fail = fail + 1; print("FAIL components count"); };

    if fail == 0 { print("OK path_utils"); return 0; };
    return 1;
}
