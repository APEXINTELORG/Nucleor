---
title: `const B: i64 = i64::MAX + 1` builds clean; overflow caught at RUNTIME via PANIC, not at compile-time const evaluation
severity: silent-miscompute (compile-time-vs-runtime gap)
probe_file: probes/numeric/const_overflow.nr (probe-branch)
diagnostic_actual: pre-fix — runtime PANIC at startup
diagnostic_expected: compile-time NUM-021
discovered_against: main v0.5.17 (probe afbd8be)
commit: probe afbd8be + main 736d88a
status: CLOSED — already addressed by v0.6.18 (NUM-021 const-decl detection at type_check_global_consts) and v0.6.50 (gap 4 — NUM-021 at let-binding const-expr overflow).
---

## Closure (already addressed in v0.6.18 + v0.6.50)

The probe finding's exact case (`const B: i64 = i64::MAX + 1;`)
is caught by the v0.6.18 NUM-021 const-decl detection at line
~17859. v0.6.50 extended NUM-021 to also fire on let-binding
const-expr overflow (gap 4 of the broader NUM-021 coverage
finding). Together these close the compile-time-vs-runtime gap
the probe identified.

The remaining gaps (sister finding
`2026-05-02-num-021-coverage-gaps-u64-imin-shift-divzero` gaps
1 + 3) are u64 const overflow (gap 1) and const div/mod/shift
fall-through (gap 3). Those are tracked separately on that
finding.

## Verify

- Existing regression-lock: `tests/err/err_num021_const_overflow.nr`
  (v0.6.18) catches `const B: i64 = MAX + 1` shape.
- New v0.6.50 lock: `tests/err/err_num021_let_overflow.nr` for
  the let-binding shape.

## Promoted

- Closed by v0.6.18 + v0.6.50 (no additional code change).
- Promoted: 2026-05-03 by main agent.
