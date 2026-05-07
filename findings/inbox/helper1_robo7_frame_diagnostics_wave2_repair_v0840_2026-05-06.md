# Helper1 ROBO-7 FRAME-001 Diagnostics Wave 2 Repair v0840

Branch: `fix/helper1-robo7-frame-diagnostics-wave2-repair-v0840`

Original base / merge-base: `0dd3bbacec675e9c5256abb80ec3229af7b08c95` (`origin/main`, `docs: append helper2 RFC-0063 wave 5`)

Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_helper1_robo7_frame_repair_v0840`

Assignment: `C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_cloud_pkg_v0839\findings\_helper1_assignment_v0828_r11_qsim_auto_entangle_2026-05-06.md`

## Integration Review

Codex reviewed this branch after `origin/main` had advanced to
`218117d6` with the R05 block-form restricts slice. The ROBO-7 source,
fixtures, docs, heartbeat, and cache-hit memory optimization were
cherry-picked onto that current main. The older promoted
`bin\nucleor.exe` and `bootstrap\nucleor_s1_seed.ll` from the helper
branch were intentionally not taken as-is; they were regenerated from
the combined R05+ROBO-7 compiler source.

Final integration validation passed: ten ROBO-7 negatives emit
`FRAME-001`, the positive frame smoke builds/runs, non-frame control
stays `TYP-024`, R05 restricts control still emits `EFF-003`, self-host
fixed point holds with md5 `f2a16ad726a690bc64fee4f6c4323a3f`, drift
and rod ABI pass, and perf passes at `cold=3.39s`, `hot=0.38s`,
`cold_tree=361MB`, `cold_compiler=347MB`, `hot_tree=69MB`,
`hot_compiler=55MB`. Cold compiler RSS is under the gate but close to
the 350MB ceiling, so keep watching it on subsequent compiler slices.

## Root Cause

Main had source-side ROBO-7 let-binding enforcement, but the promoted `bin\nucleor.exe` and `bootstrap\nucleor_s1_seed.ll` were stale relative to that source. Direct validation through `.\bin\nucleor.exe` therefore let `tests\err\err_robo7_frame_mismatch.nr` compile successfully.

The prior wave-2 helper branch also carried the non-let FRAME-001 diagnostic broadening, but it was stale and included unrelated package/helper changes. This repair branch ports only the ROBO-7 payload and regenerates the compiler artifacts from the repaired source.

## Changes

- Promoted regenerated `bin\nucleor.exe`.
- Refreshed `bootstrap\nucleor_s1_seed.ll`; final integrated self-host fixed-point md5 is `f2a16ad726a690bc64fee4f6c4323a3f`.
- Added shared `frame_mismatch_diag_message(action, expected, actual)`.
- Preserved the canonical let-binding FRAME-001 message through the shared helper.
- Added narrow FRAME-001 branches for confirmed frame-tag mismatches at:
  - function-call arguments
  - named struct initialization fields
  - tuple-struct positional fields
  - plain assignments
  - indexed assignments
  - struct-field assignments
  - explicit returns
  - tail-expression returns
  - binary/operator operands
- Added cache-hit memory optimization: cached LLVM IR is copied/linked by file path instead of loading the full cached `.ll` into compiler heap memory. This recovered hot compiler RSS from 66 MB to 55 MB.
- Regenerated `tools/audit_dup_fns_report.csv` for compiler line/function count changes.

## Coverage Added

- `tests/err/err_robo7_frame_call_arg_mismatch.nr`
- `tests/err/err_robo7_frame_struct_init_mismatch.nr`
- `tests/err/err_robo7_frame_tuple_struct_mismatch.nr`
- `tests/err/err_robo7_frame_assignment_mismatch.nr`
- `tests/err/err_robo7_frame_index_assignment_mismatch.nr`
- `tests/err/err_robo7_frame_field_assignment_mismatch.nr`
- `tests/err/err_robo7_frame_return_mismatch.nr`
- `tests/err/err_robo7_frame_tail_return_mismatch.nr`
- `tests/err/err_robo7_frame_binop_mismatch.nr`

Existing coverage retained:

- `tests/err/err_robo7_frame_mismatch.nr`
- `tests/features/robo7_frame_positive_smoke.nr`

## Validation

- `.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _helper1_robo7_repair_s1_v0840 --no-cache --no-link`: PASS.
- Ten ROBO-7 negatives: PASS, each exits nonzero and emits `error[FRAME-001]`.
- `.\bin\nucleor.exe build tests\features\robo7_frame_positive_smoke.nr -o _robo7_frame_positive_final --no-cache`: PASS.
- `.\target\_robo7_frame_positive_final.exe`: PASS, rc=0.
- Non-frame control `tests\err\err_if_branches_diff_types.nr`: PASS, emits `error[TYP-024]` and no `FRAME-001`.
- `bash tools/check_self_host_md5.sh`: PASS, fixed-point and seed md5 `f2a16ad726a690bc64fee4f6c4323a3f`.
- `bash tools/check_compiler_drift.sh`: PASS after regenerating `tools/audit_dup_fns_report.csv`; existing RFC-0063 parser-divergence warnings only.
- `bash tools/check_rod_void_abi.sh`: PASS.
- `bash -n tools/verify.sh`: PASS.
- `bash -n tools/verify_fast.sh`: PASS.
- `git diff --check`: PASS.
- `pwsh -NoProfile -File tools\check_perf_regression.ps1`: PASS, cold=3.39s, hot=0.38s, cold_tree=361MB, cold_compiler=347MB, hot_tree=69MB, hot_compiler=55MB.
