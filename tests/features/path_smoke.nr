// v0.8.216 stdlib/rods/path.nr first test coverage.
//
// Path manipulation utilities (join, ext, stem, parent, filename,
// is_absolute, normalize). Pure Nucleor over stdlib/strings.
// Pre-v0.8.216: zero coverage on the standalone rod.
//
// Locks four invariants spanning the core surface:
//
//   1. path_join inserts separator — join("a", "b") == "a/b"
//      but join("a/", "b") == "a/b" (no double-slash).
//   2. path_ext, path_stem, path_filename agree —
//      "src/foo.nr" → ext=".nr", stem="foo", filename="foo.nr",
//      parent="src".
//   3. path_is_absolute — "/abs"=1, "rel"=0, "C:/abs"=1
//      (drive-letter Windows form).
//   4. path_normalize collapses + flips slashes —
//      "a\\b//c" → "a/b/c" (no double, no trailing).
//
// Expected: rc=0.

import "stdlib/rods/path.nr"

fn check_path_join() -> i64 {
    if str_eq(path_join("a", "b"), "a/b") != 1 { return 1; };
    if str_eq(path_join("a/", "b"), "a/b") != 1 { return 2; };
    if str_eq(path_join("", "b"), "b") != 1 { return 4; };
    if str_eq(path_join("a", ""), "a") != 1 { return 8; };
    return 0;
}

fn check_decompose() -> i64 {
    if str_eq(path_ext("src/foo.nr"), ".nr") != 1 { return 16; };
    if str_eq(path_stem("src/foo.nr"), "foo") != 1 { return 32; };
    if str_eq(path_filename("src/foo.nr"), "foo.nr") != 1 { return 64; };
    if str_eq(path_parent("src/foo.nr"), "src") != 1 { return 128; };
    return 0;
}

fn check_is_absolute() -> i64 {
    if path_is_absolute("/abs") != 1 { return 256; };
    if path_is_absolute("rel") != 0 { return 512; };
    if path_is_absolute("C:/abs") != 1 { return 1024; };
    if path_is_absolute("") != 0 { return 2048; };
    return 0;
}

fn check_normalize() -> i64 {
    if str_eq(path_normalize("a\\b//c"), "a/b/c") != 1 { return 4096; };
    if str_eq(path_normalize("a/"), "a") != 1 { return 8192; };
    if str_eq(path_normalize("/"), "/") != 1 { return 16384; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_path_join();
    fails = fails + check_decompose();
    fails = fails + check_is_absolute();
    fails = fails + check_normalize();
    return fails;
}
