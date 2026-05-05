# T-4 strict inference gate

Status: ready for integration
Worktree: `C:\Users\JoeWe\Nucleor_OSS_pe_fix`
Branch: `probe/perf-hotpath-followup`
Base: `origin/main` `56637ac9` / `v0.8.166`

## What changed

- Added default-off `NUC_STRICT_INFERENCE=1` handling in `compiler/nucleor_s1_compiler.nr` and `compiler/nucleor_tools_suite.nr`.
- Explicit let bindings now emit `TYP-027` when the RHS type remains empty under strict mode.
- Perf follow-up keeps the recursive `types_compatible` empty-type path on the prior fast behavior; strict-mode handling is intentionally at the explicit-let diagnostic site to avoid per-compat env/helper overhead in the type hot path.
- Default-mode env reads are skipped unless `init_t` is empty, so normal typed lets do not pay for `NUC_STRICT_INFERENCE`.
- Wired `TYP-027` through `is_known_diag_code`, `nuc explain`, `docs/spec/Nucleor_Error_Codes.md`, and the verify smoke lists.
- Added `tests/err/err_t4_strict_inference.nr` as the focused strict-mode sister fixture for the default-off `t4_empty_type_audit_lock` canary.
- Fixed existing NUM-G2 runtime-panic fixtures so the generic compile-time negative sweep skips them and a focused runtime guard validates them.
- Kept E4 self-host fixed-point gate intact and added the `target/` creation guard in `tools/check_self_host_md5.sh`.

## Validation

- `git diff --check` passed.
- `bash -n tools/check_self_host_md5.sh` passed.
- `bash -n tools/verify_fast.sh` passed.
- `bash -n tools/verify.sh` passed.
- `powershell -NoProfile -Command '$null = [scriptblock]::Create((Get-Content -Raw "tools\verify.ps1"))'` passed.
- `bash tools/verify_fast.sh --only "v0.8 E3 T-4 strict inference rejects empty type"` passed: `PASS: 1`, `SKIP: 245`.
- `bash tools/verify_fast.sh --only "v0.8 NUM-G2 math runtime panic guards"` passed: `PASS: 1`, `SKIP: 245`.
- `bash tools/check_self_host_md5.sh` passed with md5 `3090ac29f2df3c8eb4747f30cb6b64fb`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check_perf_regression.ps1` passed: cold `3.68s`, hot `0.43s`, peak `315MB`.
- Direct single cold compile after clearing `.nuc_cache,target` measured `3.447s` on the v0.8.166 branch.

## Caveat

This is the first E3 ship, not full strict self-host closure. Running the whole compiler with `NUC_STRICT_INFERENCE=1` exposes many pre-existing empty-type sentinel paths. The first follow-up should add return-type knowledge for core helpers:

- `str_len`
- `str_char_at`
- `str_substring`
- `str_trim`
- `args_get`
- `file_read_string`
- `vec_get` element types

After that, rerun strict self-host and drain the next diagnostic wave.
