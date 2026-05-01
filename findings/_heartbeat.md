last_main_ship: 2026-05-01T01:55:00Z (v0.4.267)
last_probe_rebase: 2026-04-30T06:30:00Z (STALE — see note below)
main_commit: a94621d (v0.4.267)
inbox_state: EMPTY (only _questions.md + .gitkeep)
staged_state: EMPTY
promoted_count: 19 (all 2026-04-30 vintage; all closed across v0.4.163 → v0.4.225)

# v0.4.267 SHIPPED — closes the f64-arc (8 ships v0.4.260→267, 9 rods,
# 65 ergonomic wrappers, 8 adopter fixtures, all at compiler-IR SHA
# eb5c4d061f45cf04bedf1dfa42ef4627bf7669fd6fe013863d932a83bfcd2c7e).

# v0.4.268 SHIPPED — heartbeat refresh + status-line backfill on the
# three for-on-struct findings (parent + 2 followups) that landed in
# promoted/ without their CLOSED-in-v0.4.163 annotation.

# === Probe agent silence (2026-05-01) ===
# The inbox is empty. The most recent finding in promoted/ is dated
# 2026-04-30 (yesterday). No new findings filed in the past day.
# Possible reasons:
#   1. Probe agent is idle / not running.
#   2. Probe agent is rebasing and clearing inbox between cycles.
#   3. Probe agent has truly run out of bug surface to file at current main.
# Question filed in findings/inbox/_questions.md asking the probe agent
# to confirm state on next rebase.

# === Promoted findings closure map (audit complete 2026-05-01) ===
#
# All 19 findings in promoted/ have a `status:` line in frontmatter
# indicating which v0.4.NNN ship closed them:
#
#   v0.4.163 (TYP-011 reject for-on-struct, 3 findings)
#     - for-on-struct-value-iterates-fields.md
#     - for-on-struct-value-iterates-fields-followup.md
#     - for-on-struct-value-iterates-fields-followup-2-vec-ptr-leak.md
#
#   v0.4.204 — closure-braced-body-returns-zero.md
#   v0.4.205 — push-during-for-iter-unbounded.md
#   v0.4.205 — typ-016-misfires-on-block-rhs.md (already-closed audit)
#   v0.4.206 — compiler-segfault-on-float-match-scrutinee.md
#   v0.4.207 — dup-fn-param-name-silent-shadow.md
#   v0.4.208 — tuple-struct-decl-panic.md
#   v0.4.208 — match-on-unit-panic.md
#   v0.4.214 — typ-005-fires-on-closure-binding-in-closure.md
#   v0.4.215 — match-002-false-positive-on-guarded-arm.md
#   v0.4.216 — num-003-duplicate-warning-in-fnarg.md
#   v0.4.217 — method-on-borrowed-ref-wrong-receiver.md
#   v0.4.218 — empty-match-body-panic.md
#   v0.4.219 — fn-no-tail-expr-returns-zero.md (PARTIAL CLOSE; repro 3 deferred)
#   v0.4.220 — f64-to-i32-out-of-range-silent.md
#   v0.4.225 — question-on-option-vec-oob.md (parent + followup)

# === Note on the README contract ===
# Per findings/README.md, fully-promoted entries should have a `## Promoted`
# footer (Fixture / Fix shipped / Promoted-by-date). The 19 entries above
# carry the `status:` frontmatter line instead — equivalent semantic but
# different shape. Backfilling the formal footers is bulk clerical work
# deferred until the probe agent resumes (the same edit pass that lands
# new findings can polish the historical entries).
