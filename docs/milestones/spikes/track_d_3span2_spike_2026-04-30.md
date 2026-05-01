# Track D 3span.2 Implementation Spike

Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_d`

Branch: `v05-spike-3span2`

Base: `a75bb22` (`v0.4.227`)

Status: green spike. Full `verify.sh` env-off passed, fixed-point passed, and the nested-match wrong-caret fixture now points at the inner `match`.

## Implementation

- Added token/source-position accessors: `tok_pos`, `tok_pos_at`.
- Added AST span storage helpers: `node_set_span`, `node_get_span`.
- Threaded spans through `parse_let` and both `parse_match_stmt` entry points.
- Added diagnostic siblings:
  - `diag_add_at_or_scan`
  - `type_diag_at`
  - `match_diag_at`
- Migrated the high-impact match diagnostics:
  - match expression non-exhaustive int/str and enum paths
  - bool literal match arm diagnostic
  - match statement bad range, unreachable-after-wildcard, non-exhaustive int/str, and enum paths
  - match-related `type_diag` calls for `MATCH-011`, `MATCH-013`, and `TYP-010`
- Migrated let-binding type diagnostics to use the parse-time binding span, including `TYP-008`, `NUM-002`, and `NUM-005`.

To make the `a75bb22` worktree fully gateable, the spike also carries minimal baseline-green support already identified on the probe branch: missing err-test EXPECT headers, `25_patterns_tour` list/readme wiring, stale parse-error fixtures, diag-code/spec/tools-suite sync for `TYP-026` and `MATCH-011..013`, MINGW `verify.sh` selection of `bin/nucleor.exe`, and the narrow fixes needed for T3.46/T3.132/T3.133.

## Validation

Final full gate:

```text
Command: Git Bash, env-off
NUCLEOR_MEM_CAP_KB=1048576 NUC_VERIFY_CSV=/tmp/verify_track_d_final.csv ./tools/verify.sh --no-color

Result: rc=0
PASS: 612
SKIP: 1
```

Memory checkpoints from the final gate:

```text
self-host memory budget: OK, compiler/nucleor_s1_compiler.nr peak 480 MB / 550 MB budget, wall 3.577s
tools-suite memory budget: OK, compiler/nucleor_tools_suite.nr peak 386 MB / 500 MB budget, wall 3.264s
```

Two-stage fixed point:

```text
stage1 build: OK, peak 517 MB / 1024 MB budget, wall 3.334s
stage2 build: OK, peak 544 MB / 1024 MB budget, wall 3.778s
stage1 sha256: C33560DAD3458570B02988604EB5722072FB4FE5F249D9E96DE549FBE8665236
stage2 sha256: C33560DAD3458570B02988604EB5722072FB4FE5F249D9E96DE549FBE8665236
fixed_point: PASS
```

Capped compiler rebuilds:

```text
compiler rebuild after implementation: OK, peak 453 MB / 1024 MB budget, wall 3.512s
bootstrap seed rebuild: OK, peak 444 MB / 1024 MB budget, wall 3.456s
```

Drift and formatting:

```text
tools/check_compiler_drift.sh: rc=0
git diff --check: rc=0
bash -n tools/verify.sh: rc=0
```

## Caret Proof

Fixture: `target/track_d_nested_match_wrong_caret.nr`

Old `a75bb22` binary:

```text
error[MATCH-001]: non-exhaustive integer match
  --> fn main@line 3:5
  |
3 |     match outer {
  |     ^
```

Track D binary:

```text
error[MATCH-001]: non-exhaustive integer match
  --> fn main@line 6:13
  |
6 |             match inner {
  |             ^
```

Let-binding span smoke:

```text
error[NUM-002]: numeric literal 200 out of range for declared type i8
  --> fn main@line 3:9
  |
3 |     let bad: i8 = 200;
  |         ^
```

## Notes

- The final verify run was launched with `NUCLEOR_MEM_CAP_KB=1048576` and an external PowerShell watchdog. The watchdog did not trip; the reliable compile peak numbers above are from the repo's process-tree sampler in `tools/measure_peak_build.ps1`.
- Temporary proof fixtures and old-binary extraction live under `target/` and are intentionally not part of the tracked spike.
