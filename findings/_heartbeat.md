last_main_ship: 2026-05-01T07:50:00Z (v0.5.4)
last_probe_rebase: 2026-05-01T01:55:00Z (probe/exploration tip e27ee0a) — STALE; main has shipped v0.4.282 → v0.5.4 since.
main_commit: 26159e4 (v0.5.4)
main_branch: main (sandbox-v0.5.0-int merged in v0.5.0; sandbox-v0.5.4-atomic-swap-bool merged in v0.5.4)
inbox_state_observed_at_main: empty (only `.gitkeep` + `_questions.md`)
staged_state: empty
promoted_count: 27 (unchanged since v0.4.281; no new findings integrated this arc — the v0.5.x line shipped via consultant tracks G/H/I/L + main-agent doc/closure work)

# v0.5.4 SHIPPED — RFC-0007 closure: atomic_swap_bool + typed atomic_swap.
# The deferred swap helper from v0.4.281 is now CLOSED.
# 688/688 PASS env-off + env-on. Drift gate clean.

# === This arc's main-agent ships (v0.4.282 → v0.5.4) ===
#
# The v0.4.282 → v0.5.0 → v0.5.4 line is a mix of consultant-track
# integrations, atomic v0.5.0 cut, and small follow-up patches. No
# new probe findings arrived from probe/exploration since v0.4.281.
#
# 1. v0.4.282..v0.4.287 — sequencing + ML expansion crosswalk
#    integration (6 doc-mostly ships)
# 2. v0.5.0 — atomic Track I (RFC-0014 max_depth) + Track L
#    (content-addressed cache v2) integration cut
#    - SHA 4372053900a713937651918dc392dd35a184f0a0ef430b6f24f9bfd920eaf84e
#    - sandbox-v0.5.0-int branch ff-merged
# 3. v0.5.1 — UPGRADE_v0.5.0.md placeholders fully populated
# 4. v0.5.2 — drift fix (v0.5.1 retroactive CHANGELOG entry +
#    helper_manifest.toml regen)
# 5. v0.5.3 — v0.7.0 + v0.8.0 milestone trackers enriched with
#    ML expansion Lane H substrate items
# 6. v0.5.4 — atomic_swap_bool + typed atomic_swap shipped.
#    Real compiler/runtime work (5 new ordered intrinsics +
#    rod wrapper). Round-1 == round-2 IR fixed-point holds.
#    Bootstrap seed refreshed.

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

# === Compiler IR fixed-point progression (continuing from v0.4.281) ===
# v0.4.282..v0.4.287: doc-only; SHA unchanged from v0.4.281
# v0.5.0:  4372053900a713937651918dc392dd35a184f0a0ef430b6f24f9bfd920eaf84e
# v0.5.1..v0.5.3: doc-only; SHA unchanged from v0.5.0
# v0.5.4:  8b77f1f1e9ef3ef7d3389387e5d4e023aea8dd2a410eea58705d2bcfc885b1ee
#          (bootstrap seed updated; reflects new atomic_i64_swap_<order>
#          intrinsic dispatch in is_atomic_ordered_builtin +
#          atomic_rmw_op_llvm; otherwise IR unchanged.)

# === New diag codes shipped this arc (0 new) ===
# v0.5.4 added 5 ordered atomic intrinsics but no new diag codes.
# Existing ATOMIC-001..006 family covers the mode + memory-order
# violations.

# === Closed deferred items this arc ===
#   atomic_swap_bool (deferred in v0.4.281) — CLOSED in v0.5.4.
#   AtomicBool surface is now load/store/CAS/swap complete for
#   all five orderings.

# === Still deferred (post-v0.5.0) ===
# 1. generic-T propagation on Option<T> match-arm bindings drops
#    T=str when popping SpscQueue<str>. Slug
#    `2026-05-01-generic-T-propagation-spsc-option-str` — no
#    finding doc yet, just the workaround note in
#    docs/UPGRADE_v0.5.0.md and a CHANGELOG cross-reference.
#    Substantial compiler change (touches generic instantiation
#    + pattern binding); deferred to a focused ship cycle.
# 2. ATOMIC-006 closure+atomic — temporary halt remains; real
#    fix needs closure sym-table inheritance (multi-cycle).
# 3. CONTRACT-007 cert-profile static-proof — research-grade
#    SAT/SMT predicate analysis; deferred to v0.7+ cert profile.
# 4. dbc-undefined-ident-in-contract-expr full token-walk —
#    CONTRACT-011 ships a partial; full ident-resolution sweep
#    is multi-cycle.

memory_health: ALL clean across all 6 ships in this arc
  - v0.5.0 cut: 687/687 PASS env-off + env-on
  - v0.5.4: 688/688 PASS env-off + env-on (one new fixture added)
  - cumulative compiler self-build under cap on every cycle
  - no Run-Capped fires this arc
  - bootstrap seed verified byte-identical between
    target/nucleor_seed.ll and bootstrap/nucleor_s1_seed.ll on
    v0.5.4 (sha256 8b77f1f1...)

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
