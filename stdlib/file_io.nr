// Nucleor stdlib: file_io
// File I/O abstractions for bootstrap compiler.
// Models file reading/writing operations needed by the compiler.
// Actual I/O happens through runtime builtins; this models the interface.

// File open modes
const MODE_READ: i32 = 0;
const MODE_WRITE: i32 = 1;
const MODE_APPEND: i32 = 2;

// File operation results
const IO_OK: i32 = 0;
const IO_NOT_FOUND: i32 = 1;
const IO_PERMISSION: i32 = 2;
const IO_ERROR: i32 = 3;

struct FileResult {
    status: i32,
    bytes_read: i32,
}

fn file_ok(bytes: i32) -> FileResult {
    FileResult { status: IO_OK, bytes_read: bytes }
}

fn file_error(code: i32) -> FileResult {
    FileResult { status: code, bytes_read: 0 }
}

fn is_ok(r: FileResult) -> bool {
    r.status == IO_OK
}

// Path utilities
fn has_extension(path_len: i32, ext_len: i32) -> bool {
    path_len > ext_len + 1
}

fn is_nucleor_source(ext_c0: i32, ext_c1: i32) -> bool {
    // ".nr" = 110, 114
    ext_c0 == 110 && ext_c1 == 114
}

fn is_toml_file(ext_c0: i32, ext_c1: i32, ext_c2: i32, ext_c3: i32) -> bool {
    // "toml" = 116, 111, 109, 108
    ext_c0 == 116 && ext_c1 == 111 && ext_c2 == 109 && ext_c3 == 108
}

fn main() -> i32 {
    let ok: FileResult = file_ok(1024);
    let ok_bytes: i32 = ok.bytes_read;
    print_bool(is_ok(ok));
    print_int(ok_bytes);

    let err: FileResult = file_error(IO_NOT_FOUND);
    print_bool(is_ok(err));

    print_bool(is_nucleor_source(110, 114));
    print_bool(is_nucleor_source(114, 115));
    print_bool(is_toml_file(116, 111, 109, 108));
    0
}
