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
