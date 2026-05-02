# Track Const Overflow Diagnostic - 2026-05-02

Branch: `spike/v06-const-overflow-diagnostic`
Base: `origin/main` `9306c09` (`v0.6.12`)

## Scope

This closes the E3 diagnostic lane for module-level integer const
expressions that overflow during compile-time evaluation. The branch keeps
ordinary runtime/wrapping `let` behavior unchanged and only halts const
declarations whose initializer is statically evaluable and unsafe to lower as
a wrapped i64 value.

## Changes

- Registers `NUM-021` in the canonical diagnostic surface.
- Extends the cheap const-i64 evaluator to fold simple unary and binary
  integer expressions with checked add/sub/mul/div/rem overflow detection.
- Type-checks module-level `const` declarations before lowering:
  - `NUM-021` for i64 const-expression overflow, e.g.
    `9223372036854775807 + 1`
  - `NUM-002` for compile-time expression results outside the declared
    integer type range, e.g. `const B: i8 = 120 + 10`
- Adds focused negative fixtures and a verify step.

## Validation

- Rebased onto current `origin/main` before final validation.
- Self-host fixed-point under tight memory cap:
  - stage2: `tools/measure_peak_build.ps1 -Source compiler/nucleor_s1_compiler.nr -OutName nuc_const_rebased_stage2 -BudgetMb 770 -WarningMb 650 -SampleMs 100`
    - PASS, peak `609 MB / 770 MB`, wall `6.992s`
  - stage3: `tools/measure_peak_build.ps1 -Source compiler/nucleor_s1_compiler.nr -OutName nuc_const_rebased_stage3 -BudgetMb 770 -WarningMb 650 -SampleMs 100`
    - PASS, peak `689 MB / 770 MB`, wall `8.66s`
    - warning crossed `650 MB` at `6.883s`
  - fixed-point hash: `target/nuc_const_rebased_stage2.ll` and
    `target/nuc_const_rebased_stage3.ll` both
    `E28F1F1BDD4D654806F46F29B3412D34`
- Tools-suite rebuild:
  - `tools/measure_peak_build.ps1 -Source compiler/nucleor_tools_suite.nr -OutName nucleor_tools -BudgetMb 580 -WarningMb 520 -SampleMs 100`
  - PASS, peak `413 MB / 580 MB`, wall `6.584s`
- Focused verify under `tools/run_with_peakmem.ps1` with
  `NUC_VERIFY_AGENT=parallel1`:
  - `--only "v0.6 E3 NUM-021 const integer expression overflow diagnostic"`
    - PASS, step `0.65s`, wrapper peak `34 MB`, wall `92.565s`,
      killed `False`, `LAST_INDEX=175`
  - `--range 85-86`
    - PASS for `T3.23 diag-code drift` and `T3.24 spec-doc drift`,
      wrapper peak `411 MB`, wall `147.869s`, killed `False`
  - `--range 17-17`
    - PASS for `CLI: nuc explain - full spec code set wired`,
      step `22.33s`, wrapper peak `56 MB`, wall `69.985s`,
      killed `False`
- Drift/format checks:
  - `bash tools/check_compiler_drift.sh` PASS
  - `git diff --check` PASS
- Operational note: an initial host timeout interrupted the first
  `--range 17-17` attempt before the wrapper could finish. The orphaned
  `bash tools/verify.sh` process was found and terminated, then the slice
  was rerun successfully with a longer host timeout.
