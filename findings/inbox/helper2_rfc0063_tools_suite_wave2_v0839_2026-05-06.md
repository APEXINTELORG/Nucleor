# Helper2 RFC-0063 Tools-Suite Wave 2 v0839

Date: 2026-05-06
Branch: fix/helper2-rfc0063-tools-suite-wave2-v0839
Worktree: C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_v0838
Base: b49fb2bc5f869c8f9556add8ba943ffcf15ba9e8

## Starting Counts

Starting duplicate audit from fetched current `origin/main`:

```text
s1 fns: 825
tools fns: 703
Duplicate fns by name: 424
  IDENTICAL: 245
  SIG_MATCH_BODY_DIFFERS: 163
  SIG_DIFFERS: 16
```

## Selected Candidate List

Wave 2 selects the remaining IDENTICAL `own_*` ownership-helper cluster. The cluster is non-parser, not CLI dispatch, not a tools-only diagnostic surface, and directly exercises `nuc check` / `build-strict` ownership paths.

Selected 40 functions:

- own_set
- own_get
- own_set_type
- own_get_type
- own_set_i_raw
- own_get_i_raw
- own_set_i
- own_get_i
- own_get_s_raw
- own_set_s
- own_get_s
- own_diags
- own_source
- own_shared_keys_vec
- own_mut_keys_vec
- own_scope_keys_vec
- own_set_mutable
- own_track_key
- own_set_scope
- own_get_scope
- own_set_param
- own_get_param
- own_set_ref_target
- own_get_ref_target
- own_set_ref_kind
- own_get_ref_kind
- own_shared_borrows
- own_inc_shared
- own_dec_shared
- own_set_mut_borrow
- own_has_shared_overlap
- own_has_mut_overlap
- own_release_ref
- own_release_scope
- own_binding_move_type
- own_diag_ex
- own_diag
- own_box_hint
- own_copy_ref_binding
- own_register_borrow_expr

Skipped from this cluster:

- `own_get_mutable`: not in the IDENTICAL class.
- `own_revents_vec`: not in the IDENTICAL class.
- `own_snapshot` / `own_restore`: not selected because they are mutable-state snapshot helpers and are not in the requested 20-40 clean helper batch.

## Implementation

Moved the selected function definitions into `compiler/nucleor_rfc0063_shared_wave1.nr` and removed the local copies from `compiler/nucleor_tools_suite.nr`. This keeps the existing tools-suite-only shared-module import path and does not import all of `compiler/nucleor_s1_compiler.nr`.

## Updated Counts

Updated duplicate audit after Wave 2:

```text
s1 fns: 825
tools fns: 663
Wrote tools/audit_dup_fns_report.csv
Duplicate fns by name: 384
  IDENTICAL: 205
  SIG_MATCH_BODY_DIFFERS: 163
  SIG_DIFFERS: 16
```

Net effect: 40 additional duplicate names retired; all retired names came from the IDENTICAL class.

## Validation

Tools-suite dispatch proof matrix:

```powershell
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
.\bin\nucleor.exe check examples\01_hello.nr --no-cache
.\bin\nucleor.exe build-strict examples\01_hello.nr -o _rfc0063_wave2_build_strict --no-cache
.\bin\nucleor.exe abi examples\01_hello.nr
.\bin\nucleor.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry "$env:TEMP\nucleor-rfc0063-registry" --dry-run
```

Results:

- tools-suite build: exit 0; compiled `target\nucleor_tools.exe`.
- check: exit 0; `OK - no diagnostics`.
- build-strict: exit 0; compiled `target\_rfc0063_wave2_build_strict.exe`.
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
OK perf: cold=3.34s (max 4s) | hot=0.42s (max 1s) | mem cold_tree=341/400MB cold_compiler=326/350MB hot_tree=74/128MB hot_compiler=59/64MB
```

Self-host md5 was not run because this branch did not change `bin/` or `bootstrap/` compiler artifacts.

## Recommended Wave 3

Continue with remaining non-parser IDENTICAL helper clusters before touching body-diff or signature-diff categories. Good next candidates are small, coherent map/string/cache helpers that already have focused command coverage:

- `smap_*` helpers except functions already moved or tied to growth internals that need extra review.
- cache/path helpers such as `cache_v2_*`, `host_*`, `target_root_name`, and `write_ll_artifact_if_needed`.
- small IR accessor/constructor helpers if the Wave 3 proof matrix includes build-strict and ABI coverage.

Do not target `SIG_MATCH_BODY_DIFFERS`, `SIG_DIFFERS`, parser functions, or CLI dispatch until the remaining IDENTICAL clusters are exhausted or a specific adapter plan is written.
