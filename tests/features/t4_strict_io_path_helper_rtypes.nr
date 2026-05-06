// T-4 strict inference positive lock for direct IO/env/path helper returns.
// These runtime helpers are callable without rod imports, so strict mode must
// know their scalar/string return types instead of using the empty sentinel.

fn main() -> i64 {
    let argc: i64 = args_count();
    let fallback: str = env_get_or("NUCLEOR_T4_STRICT_MISSING_XYZZY", "fallback");
    let missing: str = env_get("NUCLEOR_T4_STRICT_MISSING_XYZZY");
    let path_env: str = getenv("PATH");
    let cwd: str = getcwd();
    let pid: i64 = process_id();
    let family: i64 = os_family();
    let width: i64 = os_pointer_width();
    let sep: str = path_separator();
    let normalized: str = path_normalize("a\\b//c");
    let with_ext: str = path_with_extension("alpha.txt", ".nr");
    let stripped: str = path_strip_extension("alpha.txt");
    let joined: str = fs_join("tests", "features");
    let base: str = fs_basename("tests/features/t4_strict_io_path_helper_rtypes.nr");
    let parent: str = fs_dirname("tests/features/t4_strict_io_path_helper_rtypes.nr");
    let ext: str = fs_extension("tests/features/t4_strict_io_path_helper_rtypes.nr");
    let tmp: str = fs_temp_dir();
    let cur: str = fs_current_dir();
    let canon: str = fs_canonicalize("tests");
    let exists: i64 = fs_exists("tests/features/t4_strict_io_path_helper_rtypes.nr");
    let is_file: i64 = fs_is_file("tests/features/t4_strict_io_path_helper_rtypes.nr");
    let is_dir: i64 = fs_is_dir("tests");
    let size: i64 = fs_size("tests/features/t4_strict_io_path_helper_rtypes.nr");
    let absolute: i64 = path_is_absolute(cwd);
    let same: i64 = file_bytes_equal("tests/features/t4_strict_io_path_helper_rtypes.nr", "tests/features/t4_strict_io_path_helper_rtypes.nr");
    let bang: str = chr(33);

    if argc < 0 { return 1; };
    if str_eq(fallback, "fallback") != 1 { return 2; };
    if str_len(missing) != 0 { return 4; };
    if str_len(path_env) <= 0 { return 8; };
    if str_len(cwd) <= 0 { return 16; };
    if pid <= 0 { return 32; };
    if family <= 0 { return 64; };
    if width != 32 && width != 64 { return 128; };
    if str_len(sep) <= 0 { return 256; };
    if str_len(normalized) <= 0 { return 512; };
    if str_len(with_ext) <= 0 { return 1024; };
    if str_len(stripped) <= 0 { return 2048; };
    if str_len(joined) <= 0 { return 4096; };
    if str_len(base) <= 0 { return 8192; };
    if str_len(parent) <= 0 { return 16384; };
    if str_len(ext) <= 0 { return 32768; };
    if str_len(tmp) <= 0 { return 65536; };
    if str_len(cur) <= 0 { return 131072; };
    if str_len(canon) <= 0 { return 262144; };
    if exists != 1 || is_file != 1 || is_dir != 1 { return 524288; };
    if size <= 0 { return 1048576; };
    if absolute != 0 && absolute != 1 { return 2097152; };
    if same != 1 { return 4194304; };
    if str_eq(bang, "!") != 1 { return 8388608; };
    return 0;
}
