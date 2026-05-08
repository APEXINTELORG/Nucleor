# Cloud Agents — Nucleor v1.x Hardening Brief (R1 / R2 / R3)

**Issued:** 2026-05-08
**Issuer:** main integrator (Windows)
**Base:** `origin/main` post-Q5 (commit pushed by integrator after Q5 verify lands GREEN; pull main before starting)
**Pace:** parallel — 3 cloud agents working independently, no inter-agent coordination required (line-range allocation in `is_error_code` prevents conflicts)

This brief defines the v1.x hardening track that follows the Q1-Q5 v1.0-cut work. Three independent units. R4 (G-5 + G-9 + G-7 extern-fn walker) is sequenced after R3 lands and is NOT in this brief.

---

## Why this isn't in v1.0

Q1-Q5 closed the structural memory-safety gates (G-1, G-2, G-4, G-8, G-11) at hard-error severity, plus shipped the audit-pass visibility raise across G-3/G-5/G-6/G-7/G-9. v1.0 cuts on that. The remaining gaps are post-cut hardening work that promotes the audit-pass heuristics to real per-fn analysis. v1.0.0 release notes will document these as "v1.x hardening track" with the warning-level audit-pass diagnostics still firing.

---

## Hard rules (non-negotiable)

- **No time estimates anywhere.** No hours/days/weeks/months in any commit message, doc, handoff, or report. If you need to express scope, say "discrete batch" or "single R-unit".
- **Honesty:** if a tool/build/verify fails, say what failed and why. Don't simulate output. Don't claim a step ran if you didn't run it. If your R-unit reveals it can't close cleanly, post the specific blocker — don't fake soundness.
- **Batch validation:** do all the edits for your R-unit, then run ONE full verify cycle. Don't compile-validate-compile-validate per change.
- **Verify cadence:** `bash tools/verify.sh` (standard) per R-unit before push. `bash tools/verify_strict.sh` is **NOT required per push** — only after seed refresh / bin promotion. Standard verify covers Q1-Q5-style additive analysis passes; strict mode catches cache poisoning which is irrelevant to additive checks.
- **No seed regen, no bin regen, no audit_dup_fns_report.csv regen.** Integrator handles all generated artifacts on cherry-pick to avoid cascade conflicts. Your R-unit commits **only** source files + fixtures + finding doc.
- **Structural fixes only.** No kludges. No `#[manual_drop]` band-aids on adopter code.
- **Don't revert today's parser annotations** (validated NOT redundant under default-flip).
- **Don't touch what other R-units own** (file/line ranges below).

---

## Coordination

- **Branches:** `claude/v1x-cloud-R<N>-<short-tag>`
- **Sync file:** `Cloud_Control1.md` (root of repo, append-only). Post your final entry under a `## R<N>` header with branch SHA + standard verify totals when your unit completes.
- **Findings:** drop iteration reports in `findings/inbox/cloud_R<N>_<topic>_v0846_2026-05-08.md`.
- **Fast-forward authority:** mine. You push to your branch; I cherry-pick onto main.

---

## R1 — RFC-0063 waves 13-16 (parser/tools-suite duplicate retirement)

**Scope:** continue the wave 12 (Q5) work. 131 SIG_MATCH_BODY_DIFFERS + 19 SIG_DIFFERS still open in `tools/audit_dup_fns_report.csv`.

**Files you may touch:**
- `compiler/nucleor_tools_suite.nr` — delete duplicate fn bodies
- `compiler/nucleor_rfc0063_shared_wave1.nr` — add helpers from canonical s1 versions (or create `nucleor_rfc0063_shared_wave2.nr` if you prefer batch isolation)
- `findings/inbox/cloud_R1_rfc0063_waves_v0846_2026-05-08.md`

**Files you must NOT touch:** `compiler/nucleor_s1_compiler.nr` (s1 stays canonical). Anything outside `compiler/` and `findings/inbox/`.

**Approach:**
1. Wave 13: triage 131 SIG_MATCH_BODY_DIFFERS — for each, decide whether tools-suite or s1 has the canonical body (criteria: which is called by more fns, which has more recent meaningful edits, which compiles cleanly). Delete the non-canonical from tools-suite, import the canonical from s1 via the shared file pattern. Avoid duplicate-name import collisions.
2. Wave 14: 19 SIG_DIFFERS — these need per-fn lift/adapter decisions. Some are tools-only surfaces (CLI dispatch helpers); some need a true adapter. Document the disposition per fn in your finding doc.
3. Wave 15: confirm CLI dispatch verification — every `nuc <subcommand>` end-to-end still routes correctly through tools-suite after deletions. Add a smoke test if missing.
4. Wave 16: regenerate `tools/audit_dup_fns_report.csv` (you CAN regen this since R1 is the only unit that affects duplicate-fn counts; integrator skips its own regen for R1).

**Diagnostic code namespace:** none — pure cleanup, no new diagnostics.

**No conflict with R2 / R3** because R1 only touches `tools_suite` + the shared wave file.

**Verify gate:** `bash tools/verify.sh` GREEN. The per-step timings line should not regress.

**Done definition:** every fn in waves 13-14 either deleted (canonical lives elsewhere) or refactored to shared file. Wave 15 CLI-dispatch smoke test added or confirmed existing. Wave 16 audit CSV regenerated. `tools/check_compiler_drift.sh` clean.

---

## R2 — G-3 + G-6 type-walker (real Phase 3 analysis)

**Scope:** promote G-3 (heap aliasing through Vec<&T>/HashMap mutation) and G-6 (Sendable propagation through nested types) from audit-pass-warning (Phase A visibility) to real per-fn analysis.

**Files you may touch:**
- `compiler/nucleor_s1_compiler.nr` — `is_error_code` (your codes only — see line range below), `check_expr` type-walker, new helper fns above `check_expr`
- `tests/features/g3_*.nr`, `tests/err/err_g3_*.nr` (positive + negative fixtures for G-3)
- `tests/features/g6_*.nr`, `tests/err/err_g6_*.nr` (positive + negative fixtures for G-6)
- `findings/inbox/cloud_R2_g3_g6_v0846_2026-05-08.md`

**Files you must NOT touch:** `compiler/nucleor_tools_suite.nr`, `compiler/nucleor_rfc0063_shared_wave1.nr` (R1 owns), `bootstrap/nucleor_s1_seed.ll`, `bin/nucleor.exe`, `tools/audit_dup_fns_report.csv` (integrator regenerates).

**Diagnostic code namespace (your line range in `is_error_code`):**
- Add your `if str_eq(code, "ALIAS-G3-VEC-OF-REFS") == 1 { return 1; };` and `if str_eq(code, "ALIAS-G3-HASHMAP-REHASH") == 1 { return 1; };` IMMEDIATELY AFTER the existing `INIT-G11-READ-BEFORE-INIT` registration (Q4 added it; you append directly below it). Same for `SEND-G6-HASHMAP`, `SEND-G6-CLOSURE-CAPTURE`, `SEND-G6-TUPLE`, `SEND-G6-ENUM` — group them together. Do NOT touch any other code registration.

**Approach (G-3 region-token invalidation):**
- Per-fn `check_fn` extension: when you see `let v: Vec<&T> = vec_new();`, assign a region-token (just an i64 counter) to `v`. When you see `vec_push(v, &x)`, record the region of `&x` against the region of `v`. When two `&x` borrows of the same `T` end up in the same Vec, emit ALIAS-G3-VEC-OF-REFS at error severity.
- HashMap mutation: when you see `hashmap_insert(m, k, v)` / `hashmap_remove(m, k)` / `hashmap_clear(m)`, bump the region-token on `m`. Any outstanding borrow `let r = hashmap_get(m, k);` with a stale region-token → emit ALIAS-G3-HASHMAP-REHASH.

**Approach (G-6 Sendable closure):**
- 4 cases per the plan: HashMap (Sendable iff K, V Sendable AND hasher Sendable), explicit-capture closures (Sendable iff every captured var Sendable), tuples (componentwise), mixed-variant enums (every variant Sendable).
- Hook into existing spawn-call check (find by grep — `__send_check_at_spawn` or similar).
- Emit `SEND-G6-<case>` at error severity.

**No conflict with R1 / R3** because R1 stays in tools_suite + shared file, R3's diagnostic codes (`EFFECT-G10-*`) are namespaced differently and registered in a different line range.

**Verify gate:** `bash tools/verify.sh` GREEN. Both new fixture pairs (G-3 + G-6) fire correctly. No regression on existing fixtures.

**Done definition:** Phase 3 real analysis shipped for G-3 and G-6. ALIAS-G3-* and SEND-G6-* codes registered. New fixtures lock in behavior.

---

## R3 — G-10 effect annotations framework

**Scope:** add `#[effect(...)]` attribute parsing, type-checker integration, and the effect-row checker. Lays the framework for Unit 1 (R4, sequenced after) which will use effects to express G-5 / G-9 / G-7 contracts.

**Files you may touch:**
- `compiler/nucleor_s1_compiler.nr` — parser hooks for `#[effect(...)]`, effect-row check entry point, `is_error_code` (your codes only — see line range below), new helpers
- `tests/features/g10_effect_*.nr`, `tests/err/err_g10_effect_*.nr` (positive + negative fixtures)
- `docs/rfcs/RFC-0062-effects-extension.md` (NEW — short doc on effect grammar + semantics, ~50-100 lines)
- `findings/inbox/cloud_R3_g10_effects_v0846_2026-05-08.md`

**Files you must NOT touch:** `compiler/nucleor_tools_suite.nr`, `compiler/nucleor_rfc0063_shared_wave1.nr` (R1 owns), `bootstrap/nucleor_s1_seed.ll`, `bin/nucleor.exe`, `tools/audit_dup_fns_report.csv` (integrator regenerates).

**Diagnostic code namespace (your line range in `is_error_code`):**
- Register codes IMMEDIATELY AFTER R2's last code (or after `INIT-G11-READ-BEFORE-INIT` if you ship before R2 — flag in your commit message). Your codes: `EFFECT-G10-UNDECLARED`, `EFFECT-G10-MISSING-ALLOW`, `EFFECT-G10-WRONG-ROW`. Group them together with a leading comment block referencing G-10.

**Approach:**
- Parser: extend the attribute parser to accept `#[effect(<name>)]` and `#[effect(<name>, <name>, ...)]`. Store the effect set on the fn AST node.
- Initial effect vocabulary (start narrow, can grow): `frees`, `borrows_mut`, `may_return_null`, `direct_ffi`. Reserve the namespace; R4 will populate semantics for the FFI ones.
- Checker: when a fn declares an effect, callers must either (a) declare the same effect, or (b) carry `#[allow(<effect>)]` on the calling fn. Fail with `EFFECT-G10-UNDECLARED` if neither.
- For now, the effect SET is just enforced as a contract — the actual checks for what `frees` / `borrows_mut` mean live in G-4 (already shipped) and G-2 (already shipped). R3 just adds the declarative framework.
- `EFFECT-G10-MISSING-ALLOW`: `#[allow(<eff>)]` referenced without the effect being declared anywhere upstream → error.
- `EFFECT-G10-WRONG-ROW`: effect set declared on caller doesn't include effect declared on callee → error.

**No conflict with R1 / R2** because R1 stays in tools_suite + shared file, R2's diagnostic codes (`ALIAS-G3-*`, `SEND-G6-*`) are namespaced differently and registered above R3's codes.

**Verify gate:** `bash tools/verify.sh` GREEN. Effect-parsing fixtures parse + type-check; missing-allow fixtures fire as designed.

**Done definition:** `#[effect(...)]` syntax parses, effect set propagates through type-checker, all 3 EFFECT-G10-* codes registered + fired by fixtures. Short RFC doc shipped explaining grammar + semantics.

---

## Per-agent verify cadence

For all 3 R-units:

1. **Per-edit:** none — edit the whole batch.
2. **End of batch:** `bash tools/verify.sh` (standard, no strict). New fixtures must pass. Existing fixtures must not regress.
3. **Skip:** `bash tools/verify_strict.sh`, `tools/check_self_host_md5.sh`, `tools/audit_dup_fns.nr` regen, seed refresh, bin refresh — all integrator-side.
4. **Push and post:** branch up, append final entry to `Cloud_Control1.md` with SHA + verify totals.

If your standard verify shows a regression in an EXISTING fixture (not your new ones), STOP and post the specific failure in `Cloud_Control1.md` rather than proceeding.

---

## Done definition for the v1.x hardening batch

When all 3 R-units land + I integrate + Windows verify GREEN:

- G-3 hard error (Phase 3 real analysis) ✓
- G-6 hard error (Phase 3 real analysis) ✓
- G-10 effect framework shipped (parser + checker + 3 codes) ✓
- RFC-0063 SIG_MATCH_BODY_DIFFERS + SIG_DIFFERS closed ✓
- v1.x changelog entry written
- R4 (G-5 + G-9 + G-7) brief written and ready to spawn

R4 is sequenced after this batch lands, since R4 builds on R3's effects framework.
