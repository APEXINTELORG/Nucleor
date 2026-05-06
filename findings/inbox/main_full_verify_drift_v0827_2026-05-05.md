# Main full verify drift snapshot - 2026-05-05

## Scope

- Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_qm7_surface_v0827`
- HEAD tested: `b3951872b1968b8a4675b109ef60c66e0cf50775`
- Command: `bash tools/verify.sh --sequential-fixtures`
- Result: `PASS: 1087`, `SKIP: 2`, `FAIL: 34`
- Local timing CSV: `tools/verify_timings.csv` (ignored by git)

## Attribution

This is not attributed to the v0827 release-metadata patch. That patch touched
only `CHANGELOG.md`, `RELEASES.md`, and `tools/check_compiler_drift.sh`.

The patched drift gate itself passed from the linked worktree and now reports:

```text
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
OK: CHANGELOG.md covers every git tag
```

## Failed Steps

```text
RFC-0042 auto_drop emits owned-local cleanup once
CLI: --json variants emit machine-readable JSON
CLI: nuc check + abi inspect
CLI: nuc summary/audit/query/impact (inspectors)
CLI: nuc policy/certify/translate/evidence/graph/perf/bench (diagnostics)
CLI: nuc test runs #[test] functions
example 13_test_framework
example 25_patterns_tour
test lang/hash_attributes
test features/concurrency_disclosure_smoke
test features/import_dedupe_lib
test features/rfc0023_slice_patterns
test features/rust_bridge_hash_deterministic
test features/rust_bridge_string_free_smoke
T1.5a mod block-form inline
T1.5b pub introspection (summary surfaces visibility)
T1.5c privatization (cross-module call surfaces succeed)
T2.6 println!/print!/format! macros expand correctly
T2.1 range patterns in match (1..=9 / 1..10)
T2.2 Vec iterator methods (.map/.filter/.fold/.sum/.min/.max)
T2.3 closure literals |args| body (no-capture)
T2.4 trait objects (Box<dyn Trait> 2-cell handle helpers)
T2.5 lifetime parameters parse cleanly (advisory metadata)
T2.8 async (threads-only): async fn / async_spawn / .await
T3.2 #[no_panic] passes when body has no panic-prone calls
T3.3 static WCET v1 estimator emits warning[RT-004]
T3.6 #[no_dyn] passes when body has no dynamic dispatch
T3.7 RT body checks strip strings and line comments
T3.23 diag-code drift (s1 is_known_diag_code vs smoke list)
T3.57 tuple-destructure let safety net (pre-v0.3.81 segfault -> clean diagnostic)
T3.83 v0.4.33a let tuple-destructure no longer silent-drops bindings
T3.147 v0.4.119 rich match patterns - enum or, @, struct, slice, tuple, MATCH-008/009/010
T3.11 bare arena_* builtins link + run end-to-end
v0.3.0 #[deadline=N] runtime check passes within budget
```

## Triage Clusters

1. CLI/tool-suite drift:
   - JSON variants return non-JSON or empty output.
   - `nuc check`, `abi inspect`, inspectors, and diagnostics smoke steps fail.

2. `nuc test` / `#[test]` contract drift:
   - The active gate expects `nuc test` to run `#[test]` functions.
   - The compiler currently emits the known unsupported `#[test]` diagnostic in at least `examples/13_test_framework.nr`.
   - Many T2/T3 smoke steps call `$BIN test tests/smoke/*.nr`, so one runner contract issue likely fans out into multiple failures.

3. Fixture expectation drift:
   - RFC-0042 auto-drop expects exactly four emitted `__nucleor_vec_free` calls; current output has one.
   - Several pattern/module/tuple/rich-match fixtures now disagree with current parser/diagnostic behavior.

4. Environment or external artifact drift:
   - Rust bridge deterministic/free smokes failed; next pass should check whether the Rust bridge static library artifact exists and is compatible with the current Windows/WSL execution path.

## Suggested Next Slice

Start with the `nuc test` / `#[test]` cluster because it likely collapses the
largest number of full-gate failures. Keep the release-metadata fix separate
from this full-gate recovery work.
