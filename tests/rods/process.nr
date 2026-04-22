// rods/process — verify cross-platform process spawn primitives.
//
// Uses platform-portable commands that work on both Windows cmd.exe and
// POSIX /bin/sh. `echo` is universal; exit codes work identically; quoting
// of the argument relies on platform shell behavior.
import "stdlib/rods/process.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // proc_run: a known-success command must yield exit 0.
    let rc_ok: i64 = proc_run("echo proc_smoke_ok");
    if rc_ok != 0 { fail = fail + 1; print("FAIL proc_run echo"); };

    // proc_capture_stdout: capture echo output, expect non-empty.
    let captured: str = proc_capture_stdout("echo capture_ok");
    if str_len(captured) == 0 { fail = fail + 1; print("FAIL capture empty"); };

    // proc_capture_status: must read 0 after a successful capture.
    if proc_capture_status() != 0 { fail = fail + 1; print("FAIL capture status 0"); };

    // proc_capture_with_status: leading "<exit>\n" then body. The "0\n"
    // prefix should be present.
    let combined: str = proc_capture_with_status("echo combined_ok");
    if str_len(combined) < 2 { fail = fail + 1; print("FAIL combined short"); };

    if fail == 0 { print("OK process"); return 0; };
    return 1;
}
