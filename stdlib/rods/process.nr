// =====================================================
// rods/process — child-process primitives (RFC-0021 phase 2)
// =====================================================
// Import: import "stdlib/rods/process.nr"
// Provides:
//   proc_run(cmdline)             -> exit code (i64)
//   proc_capture_stdout(cmdline)  -> stdout body (str)
//   proc_capture_status()         -> exit code from the most recent
//                                    proc_capture_stdout (i64)
//   proc_capture_with_status(cmdline)
//                                 -> "<exit>\n<body>" packed string
//   proc_run1(cmd, arg)           -> proc_run with one-arg quoting
// =====================================================

#cfile "../runtime/process_rt.c"

extern fn __nucleor_proc_run(cmdline: str) -> i64;
extern fn __nucleor_proc_capture_stdout(cmdline: str) -> str;
extern fn __nucleor_proc_capture_status() -> i64;
extern fn __nucleor_proc_capture_with_status(cmdline: str) -> str;
extern fn __nucleor_proc_run1(cmd: str, arg: str) -> i64;

fn proc_run(cmdline: str) -> i64 {
    return __nucleor_proc_run(cmdline);
}

fn proc_capture_stdout(cmdline: str) -> str {
    return __nucleor_proc_capture_stdout(cmdline);
}

fn proc_capture_status() -> i64 {
    return __nucleor_proc_capture_status();
}

fn proc_capture_with_status(cmdline: str) -> str {
    return __nucleor_proc_capture_with_status(cmdline);
}

fn proc_run1(cmd: str, arg: str) -> i64 {
    return __nucleor_proc_run1(cmd, arg);
}
