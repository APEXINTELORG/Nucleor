// =====================================================
// rods/fs — Filesystem operations
// =====================================================
// Import: import "stdlib/rods/fs.nr"
// Depends: import "stdlib/rods/strings.nr" (for strings_last_index_of)
// Provides: fs_exists, fs_is_file, fs_is_dir, fs_size, fs_remove, fs_rename,
//   fs_read, fs_write, fs_append, fs_path_join, fs_path_ext, fs_path_stem,
//   fs_path_parent, fs_path_filename
// =====================================================

#cfile "fs_rt.c"

extern fn rods_fs_exists(path: str) -> i64;
extern fn rods_fs_is_file(path: str) -> i64;
extern fn rods_fs_is_dir(path: str) -> i64;
extern fn rods_fs_size(path: str) -> i64;
extern fn rods_fs_remove(path: str) -> i64;
extern fn rods_fs_rename(old_path: str, new_path: str) -> i64;

fn fs_exists(path: str) -> i64 {
    return rods_fs_exists(path);
}

fn fs_is_file(path: str) -> i64 {
    return rods_fs_is_file(path);
}

fn fs_is_dir(path: str) -> i64 {
    return rods_fs_is_dir(path);
}

fn fs_size(path: str) -> i64 {
    return rods_fs_size(path);
}

fn fs_remove(path: str) -> i64 {
    return rods_fs_remove(path);
}

fn fs_rename(old_path: str, new_path: str) -> i64 {
    return rods_fs_rename(old_path, new_path);
}

fn fs_read(path: str) -> str {
    return file_read_string(path);
}

fn fs_write(path: str, data: str) {
    file_write_string(path, data);
}

fn fs_append(path: str, data: str) {
    file_append_string(path, data);
}

fn fs_path_join(a: str, b: str) -> str {
    let alen: i64 = str_len(a);
    if alen == 0 { return b; };
    let last: i64 = str_char_at(a, alen - 1);
    if last == 47 || last == 92 { return str_concat(a, b); };
    return str_concat(a, str_concat("/", b));
}

fn fs_path_ext(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_dot: i64 = 0 - 1;
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 46 { last_dot = i; };
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_dot > last_sep + 1 { return str_substring(path, last_dot, slen); };
    return "";
}

fn fs_path_stem(path: str) -> str {
    let fname: str = fs_path_filename(path);
    let flen: i64 = str_len(fname);
    let mut last_dot: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < flen {
        if str_char_at(fname, i) == 46 { last_dot = i; };
        i = i + 1;
    };
    if last_dot > 0 { return str_substring(fname, 0, last_dot); };
    return fname;
}

fn fs_path_parent(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_sep >= 0 { return str_substring(path, 0, last_sep); };
    return "";
}

fn fs_path_filename(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_sep >= 0 { return str_substring(path, last_sep + 1, slen); };
    return path;
}
