last_rebase: 2026-04-30T06:30:00Z
commit: <to-be-filled-on-next-rebase>
version: 0.4.163 (just shipped)
rebuild_wall_sec: 3.07
rebuild_peak_mb: 131
drift_check_exit: 0
perf_gate_exit: 0  (3/3 PASS after baseline -Update)

# v0.4.163 SHIPPED — TYP-011 reject for-on-struct silent-miscompute
# Closes 3 findings (parent + 2 followups). All gates green.

# Baseline rebaselined this ship per user authorization:
#   old (stale, slower-compiler-era): cold 6.54s / hot 0.78s / peak 502MB
#   new (current hardware reality):   cold 3.06s / hot 0.85s / peak 131MB
#   new ceilings (baseline +10%):     cold 3.37s / hot 0.94s / mem 144MB
# Defend tightly going forward — previous slack let real regressions hide.

inbox_state: 15 findings remaining after v0.4.163 promote
  ship-priority queue (severity-ordered, mandate strict):
    compiler-meltdown (1):
      compiler-segfault-on-float-match-scrutinee.md   <- TOP
    silent-miscompute (5):
      closure-braced-body-returns-zero.md
      push-during-for-iter-unbounded.md
      f64-to-i32-out-of-range-silent.md
      fn-no-tail-expr-returns-zero.md
    crash (1):
      question-on-option-vec-oob.md (+ followup narrowing to Option-only)
    wrong-error (7):
      tuple-struct-decl-panic + match-on-unit-panic + empty-match-body-panic
        (NR020 trio — single token-name-table fix closes all three)
      typ-016-misfires-on-block-rhs.md (likely closes 2 baseline verify FAILs)
      method-on-borrowed-ref-wrong-receiver.md
      typ-005-fires-on-closure-binding-in-closure.md
      match-002-false-positive-on-guarded-arm.md
      num-003-duplicate-warning-in-fnarg.md
    missing-error (1):
      dup-fn-param-name-silent-shadow.md

memory_health: ALL clean
  - rebuild: 3.07s wall / 131MB peak (under all caps)
  - Run-Capped fired ONCE this session on the push-during-iter probe (337MB > 256MB cap I
    set for probe runs). E-stop policy is paying for itself; that finding documents the
    iterator-invalidation hazard and recommends prioritizing it.
