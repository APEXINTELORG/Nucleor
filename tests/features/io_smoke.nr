// v0.8.228 stdlib/rods/io.nr first test coverage.
//
// I/O operations — read_line, print, file read/write/append,
// raw byte read (LSP-framed protocol), subprocess capture.
// Pre-v0.8.228: zero coverage on the standalone rod.
//
// Locks four file-IO invariants (interactive surfaces — read_line,
// run_capture, print/eprint — are not exercised; they side-effect
// the test process or require user input):
//
//   1. **Write + read round-trip** — io_write_file then
//      io_read_file returns the same bytes.
//   2. **Append extends content** — write "A" then append "B"
//      → read returns "AB".
//   3. **Empty content round-trip** — writing "" yields a
//      readable empty string.
//   4. **Reading missing file returns empty** — io_read_file on
//      a never-created path returns "" (not crash).
//
// Expected: rc=0.

import "stdlib/rods/io.nr"

fn check_write_read_round_trip() -> i64 {
    let path: str = "target/io_smoke_rt.txt";
    let payload: str = "hello-rods-io-smoke";
    io_write_file(path, payload);
    let r: str = io_read_file(path);
    if str_eq(r, payload) != 1 { return 1; };
    return 0;
}

fn check_append_extends() -> i64 {
    let path: str = "target/io_smoke_append.txt";
    io_write_file(path, "A");
    io_append_file(path, "B");
    let r: str = io_read_file(path);
    if str_eq(r, "AB") != 1 { return 2; };
    return 0;
}

fn check_empty_content() -> i64 {
    let path: str = "target/io_smoke_empty.txt";
    io_write_file(path, "");
    let r: str = io_read_file(path);
    if str_len(r) != 0 { return 4; };
    return 0;
}

fn check_missing_file_empty() -> i64 {
    let r: str = io_read_file("target/io_smoke_DOES_NOT_EXIST_xyzzy_4242.txt");
    if str_len(r) != 0 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_write_read_round_trip();
    fails = fails + check_append_extends();
    fails = fails + check_empty_content();
    fails = fails + check_missing_file_empty();
    return fails;
}
