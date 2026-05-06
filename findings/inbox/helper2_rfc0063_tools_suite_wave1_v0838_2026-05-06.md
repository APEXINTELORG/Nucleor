# Helper2 RFC-0063 Tools-Suite Wave 1 v0838

Date: 2026-05-06
Branch: fix/helper2-rfc0063-tools-suite-wave1-v0838
Worktree: C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828
Initial base: 15bff516417e18be2dd028d5850ffdbe5c5fb114

## Completed Scope

RFC-0063 Wave 1 partial deletion/import landed as a bounded tools-suite shared-module extraction. The branch adds `compiler/nucleor_rfc0063_shared_wave1.nr`, imports it from `compiler/nucleor_tools_suite.nr`, and removes the matching local definitions from the raw tools-suite file. `compiler/nucleor_s1_compiler.nr` remains unchanged and canonical for this batch.

Functions moved/imported:

- smap_new
- is_cmp_or_logic
- find_column_in_source
- own_new
- own_set_s_raw
- own_mut_borrowed
- sig_new
- tenv_new
- cache_v2_meta_path
- module_graph_manifest_path
- module_graph_source_path
- expand_async_syntax

Excluded from this wave: parser functions, CLI dispatch, tools-only diagnostics, `parse_*` drift warnings, `SIG_MATCH_BODY_DIFFERS`, and `SIG_DIFFERS` candidates.

## Audit Counts

Starting audit:

- s1 fns: 817
- tools fns: 714
- duplicate fn names: 436
- IDENTICAL: 257
- SIG_MATCH_BODY_DIFFERS: 163
- SIG_DIFFERS: 16

Updated audit after Wave 1:

```text
s1 fns: 817
tools fns: 702
Wrote tools/audit_dup_fns_report.csv
Duplicate fns by name: 424
  IDENTICAL: 245
  SIG_MATCH_BODY_DIFFERS: 163
  SIG_DIFFERS: 16
```

Net effect: 12 duplicate names retired; all retired names came from the IDENTICAL class.

## Validation

Compiler/tooling smokes:

```powershell
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o target\_rfc0063_tools_suite --no-cache
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o target\_rfc0063_s1_compiler --no-cache
```

Both completed with exit code 0. After the perf gate showed that importing the shared module from s1 pushed hot compiler RSS over the strict ceiling, s1 was restored unchanged and the final branch keeps the import on the tools-suite side only; the same s1 build command was rerun successfully after that narrowing.

Focused tools-suite proofs:

```powershell
.\bin\nucleor.exe check examples\01_hello.nr --no-cache
```

Result:

```text
parsed: 1 top-level items
checkers: ownership,type,source,taint,effect
OK - no diagnostics
elapsed: 0ms
```

```powershell
.\bin\nucleor.exe build-strict examples\01_hello.nr -o target\_rfc0063_build_strict --no-cache
```

Result: exit code 0, emitted `target/_rfc0063_build_strict.ll`, compiled `target\_rfc0063_build_strict.exe`.

The assignment spelling was also tested:

```powershell
.\bin\nucleor.exe abi inspect examples\01_hello.nr
```

Current CLI result:

```text
ERROR: cannot read inspect
```

Equivalent current CLI form:

```powershell
.\bin\nucleor.exe abi examples\01_hello.nr
```

Result:

```text
ABI imports for examples\01_hello.nr
ABI version: c-v1-imports-only
exports supported: no
extern imports: none
```

Drift and ABI gates:

```bash
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
```

Results:

- `bash tools/check_compiler_drift.sh`: exit code 0. Existing RFC-0063 parser drift warnings remain for `parse_match_stmt`, `parse_stmt`, and `parse_expr`; all hard checks, manifests, audit CSV, version labels, and opt-in privatization marker checks passed.
- `bash tools/check_rod_void_abi.sh`: exit code 0, `OK: rod void ABI clean (355 C void nuc_* definitions, 1272 non-void rod externs checked)`.
- `git diff --check`: exit code 0. Git warned that `tools/audit_dup_fns_report.csv` may be CRLF-normalized the next time Git touches it; no whitespace errors were reported.

Perf gate:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Initial result before final narrowing:

```text
OK perf: cold=3.3s (max 4s) | hot=0.39s (max 1s) | mem cold_tree=340/400MB cold_compiler=326/350MB hot_tree=69/128MB hot_compiler=54/64MB
```

Final rebased/narrowed reruns failed the strict hot compiler RSS ceiling by 1 MB:

```text
HOT COMPILER MEMORY: 65MB vs baseline 17MB (3.8x larger, max 64MB)
```

This repeated after the branch was narrowed so that `compiler/nucleor_s1_compiler.nr`, `bin/nucleor.exe`, and `tools/perf_baseline.json` have no diff against `origin/main`. The remaining tracked diff is tools-suite/source-report only. Treat perf as the only residual gate blocker for integration; it needs a final main-side rerun or threshold/noise decision.

Self-host md5 was not run because this branch did not change `bin/` or `bootstrap/` compiler artifacts.

## Remaining Work

The remaining RFC-0063 duplicate surface is:

- 245 IDENTICAL
- 163 SIG_MATCH_BODY_DIFFERS
- 16 SIG_DIFFERS

The direct full s1 import remains blocked as a bounded Wave 1 technique because all remaining duplicate names would collide. Recommended Wave 2 is another small shared extraction or a deliberate `_tools_legacy` rename/import prep batch, followed by focused deletion of imported helpers.
