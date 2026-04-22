// fs_basics.nr — RFC-0018/0019: file system primitives

fn main() -> i32 {
    let mut fail: i64 = 0;

    // Existence
    if fs_exists("README.md") != 1 { fail = fail + 1; print("FAIL: README.md should exist\n"); };
    if fs_exists("does_not_exist_xyz_12345") != 0 { fail = fail + 1; print("FAIL: nonexistent path\n"); };

    // is_file vs is_dir
    if fs_is_file("README.md") != 1 { fail = fail + 1; print("FAIL: README.md is_file\n"); };
    if fs_is_dir("README.md") != 0 { fail = fail + 1; print("FAIL: README.md not dir\n"); };
    if fs_is_dir("docs") != 1 { fail = fail + 1; print("FAIL: docs is dir\n"); };
    if fs_is_file("docs") != 0 { fail = fail + 1; print("FAIL: docs not file\n"); };

    // size
    let sz: i64 = fs_size("README.md");
    if sz <= 0 { fail = fail + 1; print("FAIL: README.md size positive\n"); };
    if fs_size("does_not_exist_xyz") != (0 - 1) { fail = fail + 1; print("FAIL: missing size != -1\n"); };

    // mtime non-zero
    if fs_mtime("README.md") <= 0 { fail = fail + 1; print("FAIL: README.md mtime\n"); };

    // Path manipulation
    let joined: str = fs_join("docs", "rfcs");
    if str_eq(joined, "docs/rfcs") != 1 { fail = fail + 1; print("FAIL: fs_join\n"); };

    let bn: str = fs_basename("docs/rfcs/RFC-0001.md");
    if str_eq(bn, "RFC-0001.md") != 1 { fail = fail + 1; print("FAIL: basename\n"); };

    let dn: str = fs_dirname("docs/rfcs/RFC-0001.md");
    if str_eq(dn, "docs/rfcs") != 1 { fail = fail + 1; print("FAIL: dirname\n"); };

    let ext: str = fs_extension("docs/rfcs/RFC-0001.md");
    if str_eq(ext, "md") != 1 { fail = fail + 1; print("FAIL: extension\n"); };

    let no_ext: str = fs_extension("README");
    if str_eq(no_ext, "") != 1 { fail = fail + 1; print("FAIL: no extension\n"); };

    // create_dir + remove
    let tmp: str = "target/_fs_test_dir";
    fs_create_dir_all(tmp);
    if fs_is_dir(tmp) != 1 { fail = fail + 1; print("FAIL: created dir\n"); };

    // list_dir non-empty for repo root
    let entries: i64 = fs_list_dir(".");
    if vec_len(entries) <= 0 { fail = fail + 1; print("FAIL: list_dir empty\n"); };

    if fail == 0 { print("OK fs_basics\n"); return 0; };
    return 1;
}
