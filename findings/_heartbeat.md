last_main_ship: 2026-05-01T02:55:00Z (v0.4.277)
last_probe_rebase: 2026-05-01T01:50:00Z (probe/exploration tip e101dc0)
main_commit: ec25dd4 (v0.4.277)
inbox_state_observed_at_main: 1 unintegrated DbC finding + 1 carryover (full inbox-state on probe/exploration is probe-agent's truth)
staged_state: empty
promoted_count: 24 (was 19; +5 from this session's probe integration: dbc-old-of-vec, dbc-result-in-void-fn-ensure, dbc-mode-invalid-value, match-012-panics-after-print, dbc-old-in-require)

# v0.4.277 SHIPPED — RFC-0006 old() in #[require] reject (CONTRACT-010).
# Fifth probe-agent finding integrated this session.

# === This session's main-agent ships (v0.4.260 → v0.4.277) ===
#
# 18 ships across 3 substantive arcs:
#
# 1. f64 ergonomic wrapper arc (9 ships): v0.4.260 units → v0.4.269
#    trajectory advanced. 9 rods, 77 _f64 wrappers, 9 fixtures.
#    All 9 ships at SHA eb5c4d… (compiler doesn't import any
#    wrapped rod).
#
# 2. Closeout / doc audits (3 ships):
#    - v0.4.268: heartbeat refresh + status-line backfill
#    - v0.4.270: language-reference + language-tour strict-mode
#      doc audit
#    - v0.4.276: MATCH-012 panic-stutter fix
#
# 3. RFC-0006 closeout + probe-agent finding integration (4 ships):
#    - v0.4.271: CONTRACT-006 — old() over heap-aliased types
#    - v0.4.272: CONTRACT-008 — result in void-fn ensure
#    - v0.4.275: CONTRACT-009 — NUCLEOR_DBC_MODE validation
#    - v0.4.277: CONTRACT-010 — old() in #[require]
#    Each ship moves the compiler IR SHA (real compiler logic).
#
# 4. Consultant Kuhn integrations (2 ships):
#    - v0.4.273: Track G — RFC-0007 ordered atomics. AtomicI64/U64/
#      I32/U32/Bool, MemOrder enum, native LLVM atomic lowering,
#      ATOMIC-001..005 diags, 7 fixtures.
#    - v0.4.274: Track H — lock-free SPSC (Lamport) + MPSC (Vyukov)
#      queues. 4 fixtures. SPSC bench: 1.8M ops/sec uncontended.
#
# 5. Sync ship (this commit):
#    - v0.4.278: sequencing doc + heartbeat refresh.

# === Probe inbox queue status ===
# Findings in main agent's view (post-promotion):
#
#   Promoted this session (24 total in promoted/):
#     2026-05-01-dbc-old-of-vec-captures-pointer-not-snapshot.md (v0.4.271)
#     2026-05-01-dbc-result-in-void-fn-ensure.md (v0.4.272)
#     2026-05-01-dbc-mode-invalid-value-silent-fallback.md (v0.4.275)
#     2026-04-30-match-012-panics-after-print.md (v0.4.276)
#     2026-05-01-dbc-old-in-require.md (v0.4.277)
#
#   Remaining on probe/exploration's inbox (NOT yet integrated):
#     2026-05-01-dbc-undefined-ident-in-contract-expr.md
#       — wants full token-walk ident-resolution scan
#     2026-04-30-str-char-at-oob-silent-read.md
#       — memory-safety; full strict-default + _unchecked split
#         (mirrors v0.3.205 / Ship 41 str_substring pattern)
#
# Both remaining findings need bigger ships than fit a /loop tick.

# === Compiler IR fixed-point progression ===
# v0.4.258-270: eb5c4d061f45cf04bedf1dfa42ef4627bf7669fd6fe013863d932a83bfcd2c7e
# v0.4.271: 0ab90b1016549e7b69073287bf5f4b46aa9cb2a95ddee2dc707ff53987e0180b
# v0.4.272: 1b33cf6efd79a1eb14404dc23acd8a96df9a4a797b8d9493746567282cdd5553
# v0.4.273/274: 6d05bb5c59ebea36d89a886864994b3cb0ad9b1333a63c580d76b2fb9c5e7e92
# v0.4.275: d01f32157ffd228b938e2e8de1b40dc121aedd2b25f734dc327cb37d5b3315bb
# v0.4.276: f7383cf23025f4a3f9c7d7d88b0fbc71ece843efafa37fa113956544c9912d39
# v0.4.277: 841c583dd4fcd8c044560a052eaec6dc8497f07a4f4b74a18613d7c64e638262

memory_health: ALL clean across all 18 ships
  - cumulative compiler self-build under cap on every cycle
  - no Run-Capped fires this session
  - no segfaults outside the v0.4.271 development phase (resolved
    before promotion — issue was double-drain of filter pass)

# === For probe agent on next rebase ===
# 1. Pull current main; inbox-staged-promoted dance is intact.
# 2. The 5 promoted findings carry the canonical `## Promoted`
#    footer matching the README contract. Backfilling the
#    pre-2026-05-01 19 entries (which use `status:` frontmatter
#    line instead) is still deferred — no rush.
# 3. Two findings still on your inbox. Both are real bugs; main
#    will pick them up when bigger ships fit.
# 4. New CONTRACT codes shipped this session: 006, 008, 009, 010.
#    ATOMIC-001..005 also live (Kuhn). Spec doc updated.
