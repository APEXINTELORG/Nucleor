# RFC-0034 Compile-Time Parameter Parser Spike - 2026-05-02

Branch: `spike/v06-compile-time-params-parser`
Base after rebase: `origin/main` `98c13f4` (`v0.6.13`)

## Scope

This spike adds the first parser substrate for RFC-0034 compile-time parameter lists:

```nucleor
fn f<T>[N: usize, TILE: usize = 16](x: i64) -> i64
extern fn host[N: usize](x: i64) -> i64
```

The implementation intentionally erases the `[]` parameter list after syntax validation. It does not implement compile-time parameter environments, call-site specialization, monomorphization keys, or value semantics.

## Changes

- Added `skip_compile_time_params` and default-value skipping in `compiler/nucleor_s1_compiler.nr`.
- Mirrored the same parser substrate in `compiler/nucleor_tools_suite.nr`.
- Wired the syntax after optional `<T>` generic params for normal fns, extern fns, trait methods, and impl methods.
- Added positive fixture `tests/features/rfc0034_compile_time_params_parser.nr`.
- Added negative fixture `tests/err/err_rfc0034_compile_time_param_missing_colon.nr`.
- Added focused verify hook: `RFC-0034 compile-time [] parameter parser first pass`.
- Hardened `tools/check_compiler_drift.sh` so generated-manifest freshness checks normalize CRLF/LF differences and restore snapshots on success. This keeps Git Bash/Python newline behavior from creating false drift or dirty generated docs.

## Validation

All command runs used `NUC_VERIFY_AGENT=parallel1`.

- Fixed-point self-host:
  - stage2 peak `687 MB / 770 MB`, wall `5.126s`
  - stage3 peak `687 MB / 770 MB`, wall `5.267s`
  - `target/nuc_ctparams_stage2.ll` MD5 `8D2EF9D99B81A1D83E7FB7DB6D774102`
  - `target/nuc_ctparams_stage3.ll` MD5 `8D2EF9D99B81A1D83E7FB7DB6D774102`
- Tools-suite rebuild:
  - peak `449 MB / 580 MB`, wall `3.723s`
- Monitored verify slices:
  - `--range 2-6`: PASS, wrapper peak `676 MB`, wall `66.296s`
  - `--only "RFC-0034 compile-time [] parameter parser first pass"`: PASS, wrapper peak `241 MB`, wall `51.316s`
  - `--range 734-741`: PASS with 0 selected steps; this range falls inside the parallel fixture accounting and did not add coverage.
- `git diff --check`: PASS before the first local commit; rerun after docs/binary amend before push.

## Memory Note

No run hit the 1 GB emergency stop. The self-host peak is above the 650 MB warning threshold and below the 770 MB tight cap; this should be watched, but this parser-only spike did not change type-check ownership or heap-heavy lowering paths.
