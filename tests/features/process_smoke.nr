// v0.8.195 stdlib/rods/process.nr first test coverage.
//
// Child-process primitives — proc_run, proc_capture_stdout,
// proc_capture_status. Pre-v0.8.195: zero coverage.
//
// Locks four invariants using Windows-builtin commands:
//   1. proc_run on echo: cmd.exe `/c echo hi` returns 0
//      (success exit code).
//   2. proc_capture_stdout of `echo hello` contains "hello".
//   3. proc_capture_status matches the most recent capture's rc.
//   4. Non-existent command returns non-zero rc.
//
// Expected: rc=0.

import "stdlib/rods/process.nr"
import "stdlib/rods/strings.nr"

fn check_proc_run_echo() -> i64 {
    let r: i64 = proc_run("cmd.exe /c echo hi");
    if r != 0 { return 1; };
    return 0;
}

fn check_capture_stdout() -> i64 {
    let out: str = proc_capture_stdout("cmd.exe /c echo hello");
    if strings_index_of(out, "hello") < 0 { return 2; };
    return 0;
}

fn check_capture_status_round_trip() -> i64 {
    proc_capture_stdout("cmd.exe /c echo ok");
    let s: i64 = proc_capture_status();
    // Echo always succeeds → 0
    if s != 0 { return 4; };
    return 0;
}

fn check_nonexistent_command_nonzero() -> i64 {
    let r: i64 = proc_run("cmd.exe /c nonexistent_cmd_xyz12345");
    if r == 0 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_proc_run_echo();
    fails = fails + check_capture_stdout();
    fails = fails + check_capture_status_round_trip();
    fails = fails + check_nonexistent_command_nonzero();
    return fails;
}
