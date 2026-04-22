// fs_extras — RFC-0017 / RFC-0022 stdlib enrichment.
//
//   fs_temp_dir()        -> str   OS temp directory (no trailing sep)
//   fs_current_dir()     -> str   working directory
//   fs_remove_dir(p)     -> i64   1 on success, 0 on failure (empty dirs only)
//   fs_copy_file(a, b)   -> i64   1 on success
//   fs_canonicalize(p)   -> str   absolute, resolved path

fn main() -> i64 {
    let mut fail: i64 = 0;

    // fs_temp_dir: should be non-empty
    let tmp: str = fs_temp_dir();
    if str_len(tmp) == 0 { fail = fail + 1; print("FAIL fs_temp_dir empty"); };

    // fs_current_dir: should be non-empty
    let cwd: str = fs_current_dir();
    if str_len(cwd) == 0 { fail = fail + 1; print("FAIL fs_current_dir empty"); };

    // fs_canonicalize: feeding "." should resolve to a non-empty absolute path
    let canon: str = fs_canonicalize(".");
    if str_len(canon) == 0 { fail = fail + 1; print("FAIL fs_canonicalize empty"); };

    // fs_copy_file: write a tiny source, copy it, verify both exist
    let src: str = fs_join(tmp, "nuc_fs_extras_src.txt");
    let dst: str = fs_join(tmp, "nuc_fs_extras_dst.txt");
    fs_remove_file(src);
    fs_remove_file(dst);
    file_write_string(src, "hello fs_extras");
    if fs_copy_file(src, dst) != 1 { fail = fail + 1; print("FAIL fs_copy_file"); };
    if fs_exists(dst) != 1 { fail = fail + 1; print("FAIL fs_copy_file dst missing"); };
    let copied: str = file_read_string(dst);
    if !str_eq(copied, "hello fs_extras") { fail = fail + 1; print("FAIL fs_copy_file content"); };
    fs_remove_file(src);
    fs_remove_file(dst);

    // fs_remove_dir: create + remove a fresh dir
    let dir: str = fs_join(tmp, "nuc_fs_extras_dir");
    fs_remove_dir(dir);
    // fs_create_dir is a thin wrapper over mkdir(2): 0 = ok, nonzero = err.
    if fs_create_dir(dir) != 0 { fail = fail + 1; print("FAIL fs_create_dir"); };
    if fs_remove_dir(dir) != 1 { fail = fail + 1; print("FAIL fs_remove_dir"); };
    if fs_exists(dir) != 0 { fail = fail + 1; print("FAIL fs_remove_dir leftover"); };

    if fail == 0 { print("OK fs_extras"); return 0; };
    return 1;
}
