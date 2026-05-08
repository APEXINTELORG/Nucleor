// Lane 6 / S3 (audit 2026-05-08): proc_run1 must reject args
// containing un-escapable shell-quote characters (`"` on Windows,
// `'` on POSIX) with PROC-QUOTE-001 instead of silently producing
// a malformed shell line that admits injection. Pre-fix the
// helper produced `"<cmd>" "<arg>"` without escaping, so an arg of
// `evil"; rm -rf /` produced injectable shell.
import "stdlib/rods/process.nr"

fn main() -> i64 {
    // Smoke: rejection path must surface as rc == -1 with no shell
    // execution. We do not assert stderr text (verify.sh swallows
    // mid-step stderr) — exit code is the audit's contract.
    let rc: i64 = proc_run1("anything", "evil\"injection");
    if rc != 0 - 1 {
        print("FAIL proc_run1 unquotable arg should return -1");
        return 1;
    };
    print("OK lane6_proc_run1_quote");
    return 0;
}
