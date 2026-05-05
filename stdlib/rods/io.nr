// =====================================================
// rods/io — Input/Output operations
// =====================================================
// Import: import "stdlib/rods/io.nr"
// Provides: io_read_line, io_print, io_println, io_eprint,
//   io_read_file, io_write_file, io_append_file
// =====================================================

#cfile "io_rt.c"

extern fn rods_io_read_line() -> str;
// v0.8.152 V1.16 Phase A1 dependency — raw N-byte stdin read.
// LSP base protocol needs faithful body-reading because JSON
// strings can contain \n.
extern fn rods_io_read_n_bytes(n: i64) -> str;
extern fn rods_io_print_no_newline(s: str);
extern fn rods_io_eprint(s: str);

fn io_read_line() -> str {
    return rods_io_read_line();
}

// Read exactly `n` bytes from stdin into a string. Returns
// shorter on EOF. Use for protocol-framed input (LSP body
// after Content-Length).
fn io_read_bytes(n: i64) -> str {
    return rods_io_read_n_bytes(n);
}

fn io_print(s: str) {
    rods_io_print_no_newline(s);
}

fn io_println(s: str) {
    print(s);
}

fn io_eprint(s: str) {
    rods_io_eprint(s);
}

fn io_read_file(path: str) -> str {
    return file_read_string(path);
}

fn io_write_file(path: str, data: str) {
    file_write_string(path, data);
}

fn io_append_file(path: str, data: str) {
    file_append_string(path, data);
}
