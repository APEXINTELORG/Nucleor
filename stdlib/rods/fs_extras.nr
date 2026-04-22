// =====================================================
// rods/fs_extras — Extended file-system operations (RFC-0018/0019)
// =====================================================
// Import: import "stdlib/rods/fs_extras.nr"
//
// Augments the existing rods/fs.nr (which uses fs_rt.c) with the
// v0.1.32 nucleor_llvm_rt.c built-ins that ship with the compiler:
//   - mkdir + recursive mkdir
//   - directory listing
//   - mtime
//   - rename
//
// The existing fs.nr exposes basic existence/size/read/write through
// fs_rt.c. This rod intentionally uses unique fnames (`fsx_*`) to
// avoid collision with the existing fs.nr surface. Both can be
// imported in the same program.
// =====================================================

// ---- Existence + classification (re-exposed for completeness) ----
fn fsx_exists(p: str) -> i64 { return fs_exists(p); }
fn fsx_is_file(p: str) -> i64 { return fs_is_file(p); }
fn fsx_is_dir(p: str) -> i64 { return fs_is_dir(p); }

// ---- Metadata ----
fn fsx_size(p: str) -> i64 { return fs_size(p); }
fn fsx_mtime(p: str) -> i64 { return fs_mtime(p); }

// ---- Mutation ----
fn fsx_mkdir(p: str) -> i64 { return fs_create_dir(p); }
fn fsx_mkdir_p(p: str) -> i64 { return fs_create_dir_all(p); }
fn fsx_rm_file(p: str) -> i64 { return fs_remove_file(p); }
fn fsx_rename(from: str, to: str) -> i64 { return fs_rename(from, to); }

// ---- Enumeration ----
// Returns Vec<i32> of entry names (as str pointers). Empty vec if
// path missing or not a directory.
fn fsx_ls(p: str) -> Vec<i32> { return fs_list_dir(p); }

// ---- Path manipulation (returns owned C-strings) ----
fn fsx_join(a: str, b: str) -> str { return fs_join(a, b); }
fn fsx_basename(p: str) -> str { return fs_basename(p); }
fn fsx_dirname(p: str) -> str { return fs_dirname(p); }
fn fsx_extension(p: str) -> str { return fs_extension(p); }

// ---- Convenience predicates ----
fn fsx_has_extension(p: str, ext: str) -> i64 {
    return str_eq(fs_extension(p), ext);
}
