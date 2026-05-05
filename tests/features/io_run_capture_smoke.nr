// v0.8.155 V1.16 LSP Phase A2.5 dep — io_run_capture smoke fixture.
//
// Adds `io_run_capture(cmd)` rod fn + `rods_io_run_capture(cmd)`
// runtime helper. popen-style: runs `cmd` via the platform
// shell and captures stdout as a string.
//
// Required by Phase A2.5 of the LSP server: the daemon needs to
// spawn `nucleor.exe --emit-diagnostics-json <file>` per
// textDocument/didChange and forward the captured JSON back as
// `textDocument/publishDiagnostics` notifications.
//
// Locks two invariants:
//   1. `io_run_capture("echo hello")` returns a non-empty string
//      containing "hello".
//   2. Returns "" on empty cmd (defensive).
//
// Expected: rc=0.

import "stdlib/rods/io.nr"

fn check_basic_capture() -> i64 {
    let out: str = io_run_capture("echo hello");
    if str_len(out) == 0 { return 1; };
    // Look for the substring "hello"
    let h_pos: i64 = str_index_of(out, "hello");
    if h_pos < 0 { return 2; };
    return 0;
}

fn check_empty_cmd() -> i64 {
    let out: str = io_run_capture("");
    if str_len(out) != 0 { return 4; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_basic_capture();
    fails = fails + check_empty_cmd();
    return fails;
}
