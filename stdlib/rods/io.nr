// =====================================================
// rods/io — Input/Output operations
// =====================================================
// Import: import "stdlib/rods/io.nr"
// Provides: io_read_line, io_print, io_println, io_eprint,
//   io_read_file, io_write_file, io_append_file
// =====================================================

#cfile "io_rt.c"

extern fn rods_io_read_line() -> str;
extern fn rods_io_print_no_newline(s: str);
extern fn rods_io_eprint(s: str);

fn io_read_line() -> str {
    return rods_io_read_line();
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
