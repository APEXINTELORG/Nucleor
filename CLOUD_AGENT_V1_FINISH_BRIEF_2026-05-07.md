# Cloud Agent — Nucleor_OSS v1.0 Finish Brief

**Issued:** 2026-05-07
**Issuer:** main integrator (Windows)
**Bar:** v1.0 ships tonight. All G-1..G-11 Phase 2b → Phase 3 → Phase 4 promoted. RFC-0063 parser unification closed. No reclassification, no deferral.

---

## Where we are right now

- Repo: `Nucleor_OSS_integrate_r05_with_row_v0842`
- HEAD: `194f3c84` (DFLIP-PATCH shipped, both modes GREEN, both hosts)
- Self-host fixed-point: `bootstrap/nucleor_s1_seed.ll` md5 = `86b491ca2d056f6006f4545e0e29d706`
- Verify state: `PASS=1488 / SKIP=1 / FAIL=0` strict + fast, both Linux + Windows
- Zero unsafe blocks in OSS

**Shipped today (don't redo):**
- `f69234d8` — Phase 2b-3 default-flip (auto-drop ON unless `#[manual_drop]`)
- `08eba3c4` — kind-7 fn-call extension to `auto_drop_mark_constructor_handoffs`
- `8cdee78d` — DFLIP-PATCH report + both verify modes GREEN
- `194f3c84` — Cloud_Control1 ack

**G-status snapshot before tonight:**
- G-1: Phase 1, 2a, 2b-1..2b-3 DONE today (structural fix). Needs Phase 4 promotion only.
- G-2: Phase 1 DONE (BR-7 warn). 2b/3/4 OPEN.
- G-3: Phase 1, 2a DONE. 2b/3/4 OPEN.
- G-4: Phase 1, 2a DONE (v0.8.24). 2b/3/4 OPEN.
- G-5: Phase 1 DONE. 2a/2b/3/4 OPEN.
- G-6: Phase 1 DONE. 2b/3/4 OPEN.
- G-7: Phase 1 DONE (zero unsafe). 2b/3/4 OPEN.
- G-8: Phase 1, 2a DONE (v0.8.29). 2b/3/4 OPEN. Today's transitive-handoff fix is partial 2b.
- G-9: Phase 1, 2a DONE. 2b/3/4 OPEN.
- G-10: tracked via G-2.
- G-11: Phase 1, 2a (TYP-008) DONE. 2b/3/4 OPEN.

---

## Your queue (Linux side — heavier IR-pass items)

Each item = write Phase 2b pass + Phase 3 promotion (info → warning) + Phase 4 promotion (warning → error). Ship through fixed-point and full verify after each batch.

### Q1. G-2 Phase 2b — single-input lifetime check
- Add IR pass: for `fn foo(x: &T) -> &T` (single ref input, ref output), verify the returned borrow's region == input's region. Diagnostic code `BORROW-G2-LIFETIME`.
- Phase 3: promote info → warning.
- Phase 4: promote warning → error.
- Plan ref: `docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md` G-2 row.

### Q2. G-4 Phase 2b — IR-level use-after-drop
- Walk IR per-fn. After every `drop` or auto-drop insertion point, mark the value's slot as dead. Any subsequent use of that slot in the same CFG path → diagnostic `OWN-G4-USE-AFTER-DROP`.
- Cooperate with G-1's auto-drop insertion (already structural).
- Phase 3 + 4 promotion as above.

### Q3. G-8 Phase 2b — move-state join at branch merge
- Today's transitive-handoff fix recognizes wrapper-fn moves but doesn't reconcile divergent move state across `if/else` branches. Extend the cond-divergence pass (already DONE through Wave A in v0.8.29) to compute the join lattice at merge points: any value moved on one arm but not the other → "conditionally moved", subsequent use → diagnostic `OWN-G8-COND-MOVE`.
- Phase 3 + 4 promotion.

### Q4. G-11 Phase 2b — definite-assignment flow analysis
- CFG walk per-fn. Track each local's init state per BB. Any read of a slot whose init-state is not "definitely assigned" → diagnostic `INIT-G11-READ-BEFORE-INIT`.
- Phase 3 + 4 promotion.

### Q5. RFC-0063 waves 12-16 — parser/tools-suite unification (after Q1-Q4)
- 30 IDENTICAL: safe-delete in one batched commit (mechanical).
- 131 SIG_MATCH_BODY_DIFFERS: triage and unify. For divergences that are real (one impl is correct, the other stale), keep correct + delete stale. For genuine fork (both used, different callers), refactor to shared helper.
- 19 SIG_DIFFERS: case-by-case — these are signature mismatches between the two parser surfaces; reconcile.
- Goal: one parser surface, no duplicates, all callers redirected.

---

## My queue (Windows side — running in parallel; do not touch)

- G-1 Phase 4 promotion (mechanical)
- G-3 Phase 2b region-token invalidation through Vec/HashMap mutation + 3/4
- G-5 Phase 2b per-fn FFI null-check inference + 3/4
- G-6 Phase 2b Sendable closure for HashMap/closure/tuple/enum + 3/4
- G-7 Phase 2b property tests (runtime)
- G-9 Phase 2b FFI bounds-check lint + 3/4
- G-10 Phase 2b effect annotations parse + propagate + 3/4
- Doc closure: PUNCHLIST + RFC-0062 + RFC-0063 + CHANGELOG + v1.0.0 version bump
- Release machinery: README claim audit (PROBE-3), license verify, CONTRIBUTING, semver policy, GitHub release notes
- Final verify_strict.sh on cumulative batch

If you hit one of these in your work, **stop and post in Cloud_Control1.md** before touching it.

---

## Coordination

- **Append-only sync file:** `Cloud_Control1.md` (root of repo). Append your entries with timestamp + commit SHA after each Q-batch completes. Read it before starting each Q so you see anything I dropped.
- **Findings:** drop iteration reports in `findings/inbox/cloud_<topic>_v<vX>_<date>.md`.
- **Branches:** use `claude/v1-finish-cloud-Q<N>-<short-tag>` per Q. Push when fixed-point holds + verify GREEN.
- **Fast-forward authority:** mine. You push to your branches; I fast-forward to main after verifying your push doesn't conflict with my parallel work.

---

## Verify gates (run after every Q batch — not per-edit)

1. Build s1 from current sources.
2. Build s2 from s1.
3. md5 IR check: stage1 == stage2 == `bootstrap/nucleor_s1_seed.ll`.
4. `tools/verify_strict.sh` (NUC_VERIFY_STRICT=1 + cache wipe).
5. `tools/verify.sh` standard.
6. Per-step timings recorded to `tools/verify_timings.csv`. Compare against baseline `325s/450 steps`. Any step > 1.3× its baseline → investigate before push.
7. Spot-check user source: `target/nucleor_s1.exe build tests/features/<small>.nr` should not hang or miscompile.

If fixed-point breaks: rebuild seed (`cp target/release/nucleor_s1.ll bootstrap/nucleor_s1_seed.ll` after both stages converge), commit seed update with the change.

---

## Hard rules (non-negotiable)

- **No time estimates anywhere.** No hours/days/weeks/months in any commit message, doc, handoff, or report. If you need to express scope, say "discrete batch" or "single Q".
- **Honesty:** if a tool/build/verify fails, say what failed and why. Don't simulate output. Don't claim a step ran if you didn't run it.
- **Batch validation:** do all the edits for a Q, then run one full verify cycle. Don't compile-validate-compile-validate per change. (User explicit.)
- **No reclassification of work as post-v1.0.** Everything in Q1-Q5 ships tonight. If a Q reveals genuine multi-batch scope (e.g. Q3 join lattice needs new IR primitive), post in Cloud_Control1.md with the specific blocker, don't silently defer.
- **No kludges, no `#[manual_drop]` band-aids.** Structural fixes only. If you reach for `manual_drop`, post the case first.
- **Don't touch v1.0 release machinery** (README, CHANGELOG, version bump, GitHub release) — that's my track and we'll collide.
- **Don't revert today's parser annotations.** Validated NOT redundant under default-flip (see `findings/inbox/main_parser_revert_under_default_flip_v0846_2026-05-07.md`).

---

## Done definition for tonight

- All Q1-Q5 shipped through Phase 4 (hard error) on Linux, fixed-point holds, both verify modes GREEN.
- Cloud_Control1.md has your final ACK with HEAD SHA.
- I fast-forward, run combined verify on Windows, run combined verify on cumulative state, ship v1.0.0 tag.

Get going. Post first ACK in Cloud_Control1.md when you've read this and started Q1.
