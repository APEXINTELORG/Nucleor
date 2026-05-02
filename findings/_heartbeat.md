last_main_ship: 2026-05-01T16:30:00Z (v0.5.14)
last_probe_rebase: 2026-05-01T10:43:00Z (probe/exploration tip e6d47b0) — main has integrated everything actionable from this rebase (max-depth follow-up + numeric/format sweep). 8 inbox findings remain open: 7 from 2026-04-30 (older, never integrated; see deferred list below) + 1 new generic-T-trait-bound-method-dispatch (sister of v0.5.13).
main_commit: 126980f (v0.5.14) — memory budget tighten
main_branch: main (sandbox-v0.5.13/14 merged in)
inbox_state_observed_at_main: empty (only `.gitkeep` + `_questions.md`)
staged_state: empty
promoted_count: 33 (was 29 at v0.5.8; +1 max-depth-self-assoc-fn (v0.5.9), +1 i32-min-div-neg-one (v0.5.10), +1 format-extra-args (v0.5.11), +1 str-to-int-silent-zero (v0.5.12), +1 generic-T-propagation (v0.5.13))
footer_uniformity: ALL 33 entries carry both the `status:` frontmatter line AND the `## Promoted` footer
memory_budget_state: TIGHTENED in v0.5.14 from 1024 MB → 770 MB self-host / 580 MB tools-suite. Real-time e-stop unchanged (kills process tree on sample > budget). See docs/milestones/MEMORY_DRIFT_2026-05-01.md.

# v0.5.14 SHIPPED — memory budget tightened (1024 → 770 / 580 MB).
# Real-time e-stop unchanged. Drift gate clean.
# 696/696 PASS env-off + env-on at the new tight caps.

# === Full arc this session (v0.4.282 → v0.5.14) ===
#
# 23 ships across 4 phases:
#
# 1. v0.4.282..v0.4.287 — doc/sequencing/ML expansion crosswalk (6 ships)
# 2. v0.5.0 — atomic cut: Track I + Track L (sandbox merge)
#    SHA 4372053900a713937651918dc392dd35a184f0a0ef430b6f24f9bfd920eaf84e
# 3. v0.5.1..v0.5.6 — doc/drift cleanup (6 ships)
# 4. v0.5.7..v0.5.14 — main-agent compiler/runtime work (8 ships):
#    - v0.5.7 — RFC-0014 max_depth on impl methods (kind-8 method dispatch)
#    - v0.5.8 — `## Promoted` footer backfill (probe Q3 close)
#    - v0.5.9 — RFC-0014 max_depth on assoc-fn form (kind-12 dispatch)
#    - v0.5.10 — i32::MIN/-1 panic at narrow widths (was Windows STATUS_INTEGER_OVERFLOW)
#    - v0.5.11 — FMT-003 format!() extra-args silent-drop close
#    - v0.5.12 — str_to_int_strict opt-in strict variant
#    - v0.5.13 — generic-T propagation through call-site rtype inference
#    - v0.5.14 — memory budget tighten + drift report

# === Probe integrations this arc (0 new) ===
# No new findings arrived on probe/exploration since
# 2026-05-01-atomic-bool-stdlib-incomplete.md (closed in v0.4.281,
# swap deferred CLOSED in v0.5.4 — see footer update on that file).

# === Probe-agent open questions (from _questions.md 2026-05-01) ===
# Q1: Are you actively probing? — probe to answer in next rebase.
# Q2: If idle, note in heartbeat. — probe to update.
# Q3: status: footer vs ## Promoted footer shape. — main agent
#     position: BOTH SHAPES ACCEPTED. The 19 originals carry the
#     `status:` frontmatter; the 8 from this session carry the
#     `## Promoted` footer per README. We can backfill formal
#     footers across all 27 in a future ship if probe prefers
#     uniformity, but the README should be the canonical contract;
#     either accept both or backfill all. Either's fine — main
#     agent will follow whatever probe prefers.

# === Compiler IR fixed-point progression (full session) ===
# v0.4.282..v0.4.287: doc-only; SHA unchanged from v0.4.281
# v0.5.0:  4372053900a713937651918dc392dd35a184f0a0ef430b6f24f9bfd920eaf84e
# v0.5.1..v0.5.3: doc-only; SHA unchanged from v0.5.0
# v0.5.4:  8b77f1f1e9ef3ef7d3389387e5d4e023aea8dd2a410eea58705d2bcfc885b1ee (atomic_i64_swap intrinsics)
# v0.5.5..v0.5.6: doc-only
# v0.5.7:  743475d091736941a5f43f7c7d38ce0a83da623f2872f959d36f7b7419429c08 (max_depth Layer-1+2)
# v0.5.8:  doc-only (footer backfill)
# v0.5.9:  fa4ab1ebc489396f7571ec637d7127b9662c618d62465d696710b1ce9a609bed (max_depth assoc-fn helper)
# v0.5.10: 3f79d0e0c7b74f27ebcb52a88b706f78787a418cb9fede73977b6d2efd0dc3c4 (panic_div_iN narrow helpers)
# v0.5.11: 0f7ca127642c12c4fd45ddac0384bbf8cbd92eb87fab1ec636d351eb14eec878 (FMT-003 check)
# v0.5.12: 10f3ce210be0b317643915feb921ef611c00c94856ae5aca964ffc62ff344437 (str_to_int_strict)
# v0.5.13: 6530fdca087d96201bc456c8597c03a9e053643ad70a4a6497837e5f5971515e (generic-T propagation)
# v0.5.14: doc-only (memory budget tighten)

# === New diag codes shipped this session (1 new) ===
#   FMT-003 — format!() extra-args silent-drop (v0.5.11)
# Existing v0.4.x families covered the rest of the closures.

# === Closed deferred items this session ===
#   atomic_swap_bool (v0.4.281 deferred) — CLOSED in v0.5.4.
#   max_depth on impl methods (sister gap) — CLOSED in v0.5.7.
#   max_depth on assoc-fn form (v0.5.7 sister-gap callout) — CLOSED in v0.5.9.
#   generic-T propagation (the v0.4.281 deferred big lane) — CLOSED in v0.5.13.

# === Still deferred (post-v0.5.14) ===
# 1. generic-T-trait-bound-method-dispatch — sister of v0.5.13 but
#    in lower-time (kind-8 method dispatch), not type-check-time.
#    Different code path; not a 1-tick fix.
# 2. vec-pop-void-coerce-to-zero — attempted v0.5.15 fix had hidden
#    interaction (builtin_rtype edit returned "void" but TYP-008
#    didn't fire; let-stmt code path investigation needed). Reverted.
# 3. closure-cant-call-sibling-closure — closure scope resolution gap.
# 4. vec-allocation-without-drop-leaks — auto-Drop infrastructure (RFC-scale).
# 5. str-concat-loop-rebind-leak — MEM-001 family extension.
# 6. i32-binop-no-narrow-in-expression-context — non-let-binding narrow path.
# 7. needs-str-arg0-linear-or-chain-length — compile-time perf optimization.
# 8. str-substring-default-no-end-bounds-check — `str_substring_strict`
#    already exists (v0.3.220); finding wants behavior FLIP. Discoverability
#    work, no code fix needed.
# 9. ATOMIC-006 closure+atomic — temporary halt remains; real fix needs
#    closure sym-table inheritance (multi-cycle).
# 10. CONTRACT-007 cert-profile static-proof — research-grade SAT/SMT.
# 11. dbc-undefined-ident-in-contract-expr full token-walk — multi-cycle.
# 12. Memory drift profile (post-v0.5.14): identify worst per-ship offenders
#    against tagged commits to tighten back toward 400 MB era ceiling.

memory_health: ALL clean across the 8 v0.5.7→v0.5.14 ships
  - 696/696 PASS env-off + env-on at the new tight 770/580 MB caps
  - cumulative compiler self-build under cap on every cycle
  - no Run-Capped fires this arc
  - bootstrap seed verified byte-identical at each ship

# === Open work for probe-agent next rebase ===
# 1. Pull current main (commit 26159e4, tag v0.5.4).
# 2. Inbox is empty at main's view; staged is empty; promoted is
#    27 entries (8 with ## Promoted footers, 19 with status:
#    frontmatter — see Q3 above).
# 3. Confirm probe-agent activity status in this file on next
#    rebase so main agent can stop wondering about the empty
#    inbox.
# 4. The deferred-but-substantial items above (generic-T
#    propagation, closure sym-table inheritance, full
#    CONTRACT-011 token-walk) are good candidates for the next
#    probe sweep if probe wants to file formal repros that main
#    agent can promote into ship cycles.

# === Parallel-agent state (lanes the main agent is NOT working) ===
# 1. Parallel-1 (consultant lane, RFC-0033..0035 etc.): tracks
#    in worktrees Nucleor_OSS_track_*. Most are at last-known
#    spike commits from v0.5.0 cut prep. track_effects_types is
#    on v06-track-effects-types at d92378f (RFC-0033 effects type
#    substrate first pass).
# 2. Parallel-2 (research/audit, no work-tree work): outputs in
#    `Desktop\Nucleor_Parallel2_Outputs_2026-05-01\`. Two
#    deliverables landed: TRACK_L_READONLY_AUDIT and
#    ML_LANES_EFG_FIXTURE_SKETCHES. Both are advisory; main
#    agent will fold into future ships when relevant.

# ============================================================
# === APPEND 2026-05-02 — main agent v0.5.15 → v0.5.33 arc ===
# ============================================================
# Append-only block. Header above is preserved as the v0.5.14
# snapshot. Future appends go at the bottom of this file with
# their own `=== APPEND <date> ===` banner.

last_main_ship_2026-05-02: 2026-05-02 (v0.5.33)
main_commit_2026-05-02: 6678735 (v0.5.33 CHANGELOG backfill)
main_branch: main (no sandbox)
inbox_state_observed_at_main: empty (only `.gitkeep` + `_questions.md`)
staged_state: empty
promoted_count: 45 (was 33 at v0.5.14; +12 across the v0.5.15 → v0.5.33 arc — probe-agent-driven closures + STALE-marked withdrawals)
footer_uniformity: ALL 45 entries carry both the `status:` frontmatter line AND the `## Promoted` footer
memory_budget_state: same per-process caps (770 / 580 MB) — v0.5.32 NVec SBO + per-fn IR free dropped self-host peak from ~700 MB env-on / ~600 MB env-off baseline to ~580-620 MB observed across stage1/2/3. SYSTEM-LEVEL concurrent peak under `tools/run_with_peakmem.ps1` MEASUREMENT IN FLIGHT at write time of this append; result will land in the next refresh.

# === v0.5.15 → v0.5.33 ship arc (19 ships) ===
#
# Full ledger: see Desktop/Nucleor_Build_Spine/BUILD_PATH_v0.4_to_v1.3.md §8.2.
# One-liners by ship:
#
# v0.5.15 — findings/_heartbeat.md refreshed (v0.5.7 → v0.5.14)
# v0.5.16 — memory drift profile: current bin vs historical s1 sources
# v0.5.17 — CSV agent-namespacing (3 concurrent agents, no race)
# v0.5.18 — MATCH-001 dedup (no longer dual-emits TYP-001+MATCH-001)
# v0.5.19 — ASYNC-001 async-keyword silent-strip warn + per-agent CSV gitignore
# v0.5.20 — string escape closure (\0 → NUL, \r → CR)
# v0.5.21 — memory drift per-ship attribution (Track I biggest contributor)
# v0.5.22 — eprintln!/eprint! macros recognized
# v0.5.23 — hex literal u64::MAX no longer wrongly NUM-002
# v0.5.24 — lexer: 1e20 (no fractional dot) lexes as f64
# v0.5.25 — async_await crash fixes (handle validation registry)
# v0.5.26 — bisect-narrow protocol modes (--rerun-failed + --only)
# v0.5.27 — CRITICAL: f64-cmp-as-i32-cast silent-zero (probe finding)
# v0.5.28 — accept canonical Rust unit-struct syntax `struct U;`
# v0.5.29 — full bisect-narrow protocol (run-to-run delta + 1 GB e-stop)
# v0.5.30 — wrapper robustness (summary row on every exit path)
# v0.5.31 — Track Y merge (generic T:Trait dispatch) + perf fix (explain 95s→16s, EXPECT 23s→0.08s) + Track Z (RFC-0042 opt-in auto-drop)
# v0.5.32 — NVec inline-buffer SBO + vec_insert_at fix + per-fn IR free during emit
# v0.5.33 — RELEASES.md drift fix + CHANGELOG backfill

# === Probe-agent state (open question at write time) ===
#
# Probe agent has not rebased into main since the v0.5.14 snapshot
# above per inbox observability (still empty). Last known probe
# branch tip per that snapshot was probe/exploration @ e6d47b0.
# Probe-agent: please rebase + report your current focus on next
# cycle so this file reflects probe state too.
#
# Standing position on Q3 (footer shape) is unchanged: BOTH SHAPES
# ACCEPTED; backfill or README-update either way. Main agent has
# carried both shapes through the v0.5.15 → v0.5.33 arc.

# === Parallel-agent state at write time ===
#
# Parallel-1: working on Track X spike (branch + commit TBD by
# parallel-1's report). Main agent staying off compiler/runtime/
# binary changes during the spike to avoid merge collision. Update
# this row when parallel-1 reports the branch.
#
# Track Y, Track Z: BOTH SHIPPED via v0.5.31. See spine §8.3 for
# the spike-ledger append.
#
# Parallel-2: no new outputs since the v0.5.14 snapshot above.

# === APPEND 2026-05-02 PM (later) — Track X round-3 lane A integrated ===
last_main_ship_2026-05-02_pm3: dfa1d48 → v0.6.9 (pending gate)
integrated_branch: origin/spike/v06-rfc0008-isr at a2c682e
self_host_md5_at_v0.6.9: ab936966dcf419636dacd5109e185771 (stage1=stage2)
self_host_peak_at_v0.6.9: 661 MB / 5.38s wall (stage1), 672 MB / 6.37s wall (stage2)
isr_smoke_at_v0.6.9: rfc0008_isr_minimal builds + runs OK; err_isr_001 fires canonical ISR-001 diag
parallel_1_lane_A_state: SHIPPED via dfa1d48 / v0.6.9 (this ship)
parallel_1_lane_B_state: still in flight (vec inline-data audit not pushed yet)
verify_gate_v0.6.9: 733/733 PASS / 0 FAIL / 0 SKIP / 853s wall.

# === APPEND 2026-05-02 PM (v0.6.11) — probe finding closure ===
last_main_ship_2026-05-02_pm4: v0.6.11 (pending gate)
closes_probe_finding: 2026-05-01-generic-T-trait-bound-where-clause-and-ref-still-broken (where-clause shape only; reference-receiver and nested-generic shapes still open per finding's "known still-open" section)
self_host_md5_at_v0.6.11: e5653940a02ec2befcd0f9eb5589a527 (stage1=stage2)
self_host_peak_at_v0.6.11: 650 MB / 4.91s wall (stage1), 599 MB / 5.36s wall (stage2)
tools_suite_clean_at_v0.6.11: yes — no parse-side regression on ~30k LOC
parse_where_clause_into_gparams: NEW helper at compiler/nucleor_s1_compiler.nr; replaces skip_where_clause at parse_fn_decl only (other call sites unchanged)
fixture_added: tests/features/rfc0024_generic_trait_bound_where_clause.nr
parallel_1_lane_B_state: still in flight (vec inline-data audit not pushed yet)

# ============================================================
# === APPEND 2026-05-02 (correction) — 1 GB is E-STOP, NOT BASELINE
# ============================================================
# The earlier `memory_budget_state_2026-05-02` line and the
# spine §8.4 item #1 wording both treated 1 GB as a *baseline*
# the system-level concurrent verify peak should be measured
# against. THAT FRAMING IS WRONG and was corrected by the user
# on 2026-05-02. The canonical framing — already correct in the
# auto-memory files (project_nucleor_probe_v0529_protocol.md,
# feedback_perf_regression_pattern.md, project_nucleor_oss_dual_
# agent_split.md) — is:
#
#   - Self-host per-process budget = 770 MB (hard cap)
#   - Tools-suite per-process budget = 580 MB (hard cap)
#   - Real-time e-stop ceiling = 1 GB / 1024 MB (safety kill;
#     never raised; comfort-blanket bumps rejected)
#
# There is no tracked system-level "concurrent baseline." The
# wrapper measurement run that was in flight when the earlier
# block was written has been stopped; no conclusion derived
# from its partial CSV.
#
# Spine-side correction: see §8.8 of
# Desktop/Nucleor_Build_Spine/BUILD_PATH_v0.4_to_v1.3.md.

# === APPEND 2026-05-02 — v0.6.0-pre integration shipped ===
last_main_ship_2026-05-02_pm: 751a095 (v0.6.0-pre)
integrated: max-depth-extensions (3495cb0) + effects-types-mem-tightened (b9ea012)
self_host_fixed_point_md5: b399b7502aafc7c566954c37eb511d5f
verify_gate: 721/721 PASS / 0 FAIL / 0 SKIP / 710s wall
self_host_peak: 597 MB / 4.665s wall
tools_suite_peak: 397 MB / 3.839s wall
inbox_state: empty (only _questions.md)
flaky_observed: stage1 hit OWN-008 once on priv_mangle_private_fns; stage2/3
  always pass — heap-corruption path beyond v0.5.32 vec_insert_at fix.
  See _questions.md. Handed off to parallel-1 lane B in
  Desktop/Nucleor_PARALLEL_1_BRIEF_2026-05-01.md §APPEND-2026-05-02-EVENING.

# === APPEND 2026-05-02 PM — v0.6.1 + v0.6.2 ===
last_main_ship_2026-05-02_pm2: 220de5a (v0.6.2)
ships_since_v0.6.0_pre: v0.6.0 (5088981) cut bookkeeping;
  v0.6.1 (983daa4) typ-026 expr-stmt-with-semi closure;
  v0.6.2 (220de5a) docs/UPGRADE_v0.6.0.md migration story.
verify_gate_at_v0.6.1: 722/722 PASS / 0 FAIL / 0 SKIP / 700s wall
self_host_md5_at_v0.6.1: 98112a7676bf1f748ddc3e473c339dedcb (stage1=stage2)
self_host_peak: 568 / 589 MB / 5.40s + 4.67s wall (stage1+2)
v0.6.0_milestone_open_criteria: 12 of 13 unchecked; v0.5→v0.6 migration story closed v0.6.2.
parallel_1_round_3_lanes:
  A (HARD): RFC-0008 #[isr] interrupt service routine attribute on spike/v06-rfc0008-isr
  B (EASY-ish): runtime audit for second inline_data dangling site causing flaky stage1 OWN-008
main_round_3_lanes:
  HARD: RFC-0005 typed dimensional units — DEFERRED (1530 LOC arc, not single-ship)
  EASY: spine §8.9 historical handoff doc reconciliation — DONE (added to BUILD_PATH spine)
  PIVOT: docs/UPGRADE_v0.6.0.md v0.5→v0.6 migration story — DONE v0.6.2

# === APPEND 2026-05-02 PM — parallel-1 RFC-0008 ISR spike ===
last_parallel1_focus_lane_a: spike/v06-rfc0008-isr (SHIPPED v0.6.9)
parallel1_lane_a_base: origin/main v0.6.4 (c3e9a59)
parallel1_lane_a_scope: RFC-0008 first-pass #[isr] attribute substrate, fixtures, and focused verify hook

# === APPEND 2026-05-02 PM — parallel-1 vec inline-data audit ===
last_parallel1_focus_lane_b: spike/v06-vec-inline-data-audit (SHIPPED v0.6.13)
parallel1_lane_b_base: origin/main v0.6.8 (f6231c9) after final rebase
parallel1_lane_b_scope: NVec inline-data audit; vec_extend self-alias fix; mem_rt inline free guard
parallel1_lane_b_validation: focused NVec runtime ownership smoke PASS after rebase; stage1 self-host 10/10 PASS
parallel1_lane_b_peak: focused wrapper 180 MB after rebase; post-loop max 678 MB / 770 MB tight gate
parallel1_lane_b_note: original OWN-008 did not reproduce in 10 pre-patch stage1 runs

# === APPEND 2026-05-02 PM — parallel-1 MATCH-014 diagnostic ===
last_parallel1_focus_lane_c: spike/v06-match-range-negative-bound-diagnostic (SHIPPED v0.6.14)
parallel1_lane_c_base: origin/main v0.6.10 (cc8311f)
parallel1_lane_c_scope: E2 clean diagnostic for negative literal bounds in match range patterns
parallel1_lane_c_validation: fixed-point PASS; MATCH-014 focused PASS; diag/spec/explain/drift PASS
parallel1_lane_c_peak: self-host max 671 MB / 770 MB; tools-suite 424 MB / 580 MB; focused wrapper max 56 MB

# === APPEND 2026-05-02 PM — parallel-1 str_substring_strict migration ===
last_parallel1_focus_lane_d: spike/v06-str-substring-strict-migration (integrating now)
parallel1_lane_d_base: origin/main v0.6.10 (cc8311f) after final rebase
parallel1_lane_d_scope: E1 doc/fixture discoverability lane for str_substring_strict
parallel1_lane_d_validation: focused migration fixture PASS after rebase; peak 174 MB under 1 GB e-stop

# === APPEND 2026-05-02 evening — round-3 ALL LANES SHIPPED ===
session_total_ships_2026-05-02: 17 (v0.6.0 → v0.6.16)
parallel1_lane_a: SHIPPED v0.6.9 (270ef86) — RFC-0008 #[isr]
parallel1_lane_b: SHIPPED v0.6.13 (98c13f4) — NVec inline-data audit
parallel1_lane_c: SHIPPED v0.6.14 (3853a48) — MATCH-014
parallel1_lane_d: SHIPPED v0.6.15 (1224b2f) — str_substring_strict discoverability
main_v0.6.11: SHIPPED (2749cb5) — generic `where T: Trait` closure
main_v0.6.12: SHIPPED (9306c09) — `(expr)(args)` direct-call halt
main_v0.6.16: SHIPPED (f9a8208) — findings drain (2 closures from v0.6.14/15)
verify_gate_v0.6.15: 744/744 PASS / 0 FAIL / 0 SKIP
parallel1_round_4_in_flight: spike/v06-compile-time-params-parser + spike/v06-const-overflow-diagnostic (NOT yet integrated; consultant mid-cycle per user direction)
probe_state: rebased to v0.6.13 (1f77eac) — closure capture broken inside while/loop bodies (existing 2026-05-01 finding, re-verified open)
