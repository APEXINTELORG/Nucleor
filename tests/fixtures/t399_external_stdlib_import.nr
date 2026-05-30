// t399_external_stdlib_import.nr — v0.3.122 NUC-FEEDBACK-004 fixture.
//
// Pins stdlib import resolution from outside the OSS repo. Pre-
// v0.3.122, `import "stdlib/rods/jsonl.nr"` (or any other stdlib
// rod) silently failed to resolve when the source file was outside
// the source tree — the import-path search walked from the
// source's base_dir UP to filesystem root then tried CWD; since
// adopters using nucleor.exe as an external tool typically have
// neither, the import injected zero source and every imported
// symbol failed at clang link with `@<name> undefined`.
//
// Adopter symptom (from ML suite's NUC-FEEDBACK-004):
//   error: use of undefined value '@emit_json_array_f64'
//   error: use of undefined value '@emit_json_metric_i64'
//
// Fix in `resolve_import_path` adds three new search candidates:
//   1. `$NUCLEOR_STDLIB/<raw_path>` (env override)
//   2. `<exe_dir>/<raw_path>` (compiler binary's own dir)
//   3. `<exe_dir>/../<raw_path>` (OSS-root sibling of bin/)
//
// All checks fail-soft via `file_read_string > 0` so users with
// custom layouts still get their relative-to-source resolution
// from the prior loop.
//
// This fixture is in-tree so the verify gate will resolve via the
// existing source-relative walk; the new external-path branches
// are exercised by adopter usage and the response doc test.
// Returns 0 when the JSONL rod's `emit_json_status` is reachable.

import "stdlib/rods/jsonl.nr"

fn main() -> i64 {
    emit_json_status(1);
    return 0;
}
