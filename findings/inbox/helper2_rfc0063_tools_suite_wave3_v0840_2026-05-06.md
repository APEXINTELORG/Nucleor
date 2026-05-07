# Helper2 RFC-0063 Tools-Suite Wave 3 v0840

Date: 2026-05-06
Branch: fix/helper2-rfc0063-tools-suite-wave3-v0840
Worktree: C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_cloud_pkg_v0839
Base: d5b8d611f34a68e55e830bb32a9a5ddc3e66fa38

## Starting Counts

Starting duplicate audit from fetched current `origin/main`:

```text
s1 fns: 825
tools fns: 663
Duplicate fns by name: 384
  IDENTICAL: 205
  SIG_MATCH_BODY_DIFFERS: 163
  SIG_DIFFERS: 16
```

## Selected Candidate List

Wave 3 selects the remaining IDENTICAL `ir_*` accessor/constructor cluster. This is a compact non-parser cluster, not CLI dispatch, not tools-only diagnostics, and it is directly covered by the required `build-strict` and ABI smokes.

Selected 25 functions:

- ir_op
- ir_dest
- ir_op1
- ir_op2
- ir_extra
- ir_const_int
- ir_binop
- ir_cmpop
- ir_alloca
- ir_load
- ir_store
- ir_ret
- ir_br
- ir_br_cond
- ir_param_ref
- ir_const_str
- ir_block_label
- ir_block_add
- ir_block_inst_count
- ir_block_get_inst
- ir_fn_name
- ir_fn_param_count
- ir_fn_add_block
- ir_fn_block_count
- ir_fn_get_block

Skipped candidate families:

- `smap_grow` and surrounding growth helpers: deferred because the queue explicitly preferred `smap_*` helpers that are not growth-internal or behavior-sensitive.
- cache/path/host helpers: still good Wave 4 candidates, but this wave keeps one coherent IR cluster.
- parser functions and all `SIG_MATCH_BODY_DIFFERS` / `SIG_DIFFERS` rows: out of scope.

## Implementation

Moved the selected `ir_*` function definitions into `compiler/nucleor_rfc0063_shared_wave1.nr` and removed the local copies from `compiler/nucleor_tools_suite.nr`. This keeps the existing tools-suite-only shared-module import path and does not import all of `compiler/nucleor_s1_compiler.nr`.

## Updated Counts

Updated duplicate audit after Wave 3:

```text
s1 fns: 825
tools fns: 638
Wrote tools/audit_dup_fns_report.csv
Duplicate fns by name: 359
  IDENTICAL: 180
  SIG_MATCH_BODY_DIFFERS: 163
  SIG_DIFFERS: 16
```

Net effect: 25 additional duplicate names retired; all retired names came from the IDENTICAL class.

## Validation

Tools-suite dispatch proof matrix:

```powershell
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
.\bin\nucleor.exe check examples\01_hello.nr --no-cache
.\bin\nucleor.exe build-strict examples\01_hello.nr -o _rfc0063_wave3_build_strict --no-cache
.\bin\nucleor.exe abi examples\01_hello.nr
.\bin\nucleor.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry "$env:TEMP\nucleor-rfc0063-wave3-registry" --dry-run
```

Results:

- tools-suite build: exit 0; compiled `target\nucleor_tools.exe`.
- check: exit 0; `OK - no diagnostics`.
- build-strict: exit 0; compiled `target\_rfc0063_wave3_build_strict.exe`.
- abi: exit 0; `ABI version: c-v1-imports-only`, `extern imports: none`.
- publish dry-run: exit 0; no files copied, no registry metadata/checksums/signatures written.

Drift and ABI gates:

```bash
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
```

Results:

- `bash tools/check_compiler_drift.sh`: exit 0. Existing RFC-0063 parser drift warnings remain for `parse_match_stmt`, `parse_stmt`, and `parse_expr`; hard checks passed, including `audit_dup_fns_report.csv is up to date`.
- `bash tools/check_rod_void_abi.sh`: exit 0, `OK: rod void ABI clean (355 C void nuc_* definitions, 1272 non-void rod externs checked)`.
- `git diff --check`: exit 0. Git warned that `tools/audit_dup_fns_report.csv` may be CRLF-normalized the next time Git touches it; no whitespace errors were reported.

Perf gate:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

First sample missed the strict hot compiler RSS ceiling by 2 MB:

```text
HOT COMPILER MEMORY: 66MB vs baseline 17MB (3.9x larger, max 64MB)
```

Per assignment, reran once. Tie-break sample passed:

```text
OK perf: cold=3.34s (max 4s) | hot=0.4s (max 1s) | mem cold_tree=340/400MB cold_compiler=325/350MB hot_tree=69/128MB hot_compiler=55/64MB
```

Self-host md5 was not run because this branch did not change `bin/` or `bootstrap/` compiler artifacts.

## Recommended Wave 4

Continue with remaining non-parser IDENTICAL helper clusters before touching body-diff or signature-diff categories. Good next candidates:

- cache/path helpers: `cache_v2_*`, `host_*`, `target_root_name`, and `write_ll_artifact_if_needed`.
- small map helpers excluding growth-sensitive internals first; if `smap_grow` is selected, keep it in a dedicated batch.
- small atomic-ordering helpers if the Wave 4 proof matrix keeps build-strict and ABI coverage.

Do not target `SIG_MATCH_BODY_DIFFERS`, `SIG_DIFFERS`, parser functions, or CLI dispatch until the remaining IDENTICAL clusters are exhausted or a specific adapter plan is written.
