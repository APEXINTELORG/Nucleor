// t446_link_failure_diagnostic.nr -- v0.3.179 regression fixture
// (positive smoke).
//
// NUC-FEEDBACK-009 (ML suite, 2026-04-26): intermittent
// nonzero `nuc run` exit after LLVM emit during long verifier
// pass. Adopters saw "emitted: target/X.ll (...)" then a nonzero
// exit with no clear signal whether clang errored, never started
// (file lock / antivirus / process-spawn), or something else.
//
// Same hazard class as the v0.3.156-160 sweep -- adopter sees
// failure with insufficient evidence to triage.
//
// Fix (v0.3.179): always print the link command on rc != 0, and
// when the captured clang_link.log is EMPTY, explicitly note
// that clang likely never started (with file-lock / antivirus /
// orphan-process triage hint). The on-disk log capture (added
// pre-v0.3.179) was already in place; this fix surfaces it.
//
// This fixture pins a successful build so the diagnostic addition
// doesn't regress the happy path.

fn main() -> i64 {
    return 42;
}
