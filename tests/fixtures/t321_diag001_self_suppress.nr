// T3.21 (v0.3.37) — proves the v0.3.36 design intent that
// DIAG-001 itself is suppressible via #[allow(DIAG-001)],
// matching the file-wide-allow semantics of every other
// warning code.
//
// Without #[allow(DIAG-001)] this file would fire one
// DIAG-001 (for the unknown-prefix #[allow(WAT-001)] below).
// With #[allow(DIAG-001)] in scope file-wide, that warning
// is dropped by the suppression pass that runs AFTER
// emit_diag001_unknown_codes -- so the build is silent.
//
// Verify gate (T3.21) asserts:
//   * No DIAG-001 warning surfaces (suppression worked)
//   * Build exits 0 (no other diagnostics from this fixture)

#[allow(DIAG-001)]
#[allow(WAT-001)]
fn main() -> i64 {
    return 0;
}
