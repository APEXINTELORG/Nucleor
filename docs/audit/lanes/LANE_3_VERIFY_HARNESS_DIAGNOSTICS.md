# Lane 3 — Verify Harness Hardening + Diagnostic Plumbing

**Branch:** `fix/audit-lane-3-verify-harness-2026-05-08`
**Theme:** Fix the gate before fixing the code. Eliminates the structural blind spots that let the v1.0 verify pass cleanly while ~244 findings sat below the surface.

**Priority:** highest. Other lanes' fixes need this lane's verify hardening to actually validate them.

## In-scope findings

### Critical (1)
- **Layer 3 / F-DIAG-003** — `OWN-001` use-after-move emitted at "warning" severity at `compiler/nucleor_s1_compiler.nr:20545`. **One-word literal change `"warning"` → `"error"`.** Verified against `err_use_after_move.nr`, `err_borrow_after_move.nr`, `err_box_use_after_move.nr` — all currently RC=0.

### High (8)
- **Layer 3 / F-DIAG-001** — Parser panics with no source location (18 sites)
- **Layer 3 / F-DIAG-004** — RACE-001/005/008 emit with line=0 → no caret
- **Layer 3 / F-DIAG-005** — 23 `diag_add_ex` sites pass `0,0` for line/col
- **Layer 3 / F-DIAG-006** — 17 emitted codes have NO test in `tests/err/`
- **Layer 3 / F-DIAG-010** — TNT-001 has suggestion entry but no actual emit path
- **Layer 3 / F-DIAG-014** — **Negative-test runner uses regex-only check, ignores exit code.** Root cause of how F-DIAG-003 slipped through.
- **Layer 5 / F-CONC-016** — Verify suite has no contention tests, no UAF tests, no platform-divergence tests
- **Layer 6 / C-008** — Fixed-point self-host doesn't catch buggy stage1 fixed-pointing into stage2; need a differential reference

### Medium (6)
- **Layer 3 / F-DIAG-002** — `type_diag(...,fn_name,fn_name,...)` always carets fn header instead of error site (TYP-002, OWN-008, OWN-004, EFF-001 affected)
- **Layer 3 / F-DIAG-007** — EFF-001 fires at both error AND warning severity from different paths
- **Layer 3 / F-DIAG-009** — OWN-G4 message truncated mid-sentence
- **Layer 3 / F-DIAG-011** — TYP-005 falsely claims "type-checker emitted earlier"
- **Layer 3 / F-DIAG-012** — Parser halts at first error, no recovery
- **Layer 3 / F-DIAG-016** — Type-checker has no "undefined variable" diagnostic (defers to clang link)

### Low (4)
- **Layer 3 / F-DIAG-013** — Code reuse (NR020/TYP-005)
- **Layer 3 / F-DIAG-015** — Duplicate `diag_add_ex` in s1_compiler.nr and rfc0063_shared_wave2.nr
- **Layer 3 / F-DIAG-017** — Suggestions: `.clone()` for non-Clone structs
- **Layer 3 cross-cutting** — ~167 `print("ERROR:")` halts have no diagnostic code (pattern affecting Layers 1, 2, 3 — this lane addresses the systemic anti-pattern)

## Source-of-truth findings docs
- `docs/audit/findings/audit_recon_pass1_diagnostics_2026-05-08.md`
- `docs/audit/findings/audit_recon_pass1_concurrency_2026-05-08.md` (F-CONC-016 only)
- `docs/audit/findings/audit_recon_pass1_codegen_2026-05-08.md` (C-008 only)

## Strategy

### Phase 3a — Verify harness hardening (do first, atomically)

1. **Negative-test runner: exit-code aware.** Each `tests/err/*.nr` test now requires both:
   - The expected diagnostic regex matches stderr
   - Build exits non-zero
   Either failing = test failure. Update `tools/verify.sh` (or wherever the negative-test loop lives) to enforce.
2. **Differential reference for codegen.** Add a verify step that compiles a corpus of differential-test programs through Nucleor AND through clang (or Python ref where appropriate) and bit-compares numeric output. Catches Layer 6 i64-everywhere class.
3. **Contention / UAF / platform tests.** Add at least:
   - Mutex contention: 4 threads × 10K acquire/release
   - Channel contention: 4 producers × 4 consumers × 10K msgs
   - UAF probe: forge handle → expect `unsafe handle` diagnostic post-Lane 2
   - Platform divergence: any test marked `# platform: any` runs on both OSes if cloud baseline supports it
4. **Negative coverage gate.** Lint that every diagnostic code emitted by the compiler has at least one negative test in `tests/err/`. New step in verify: gate fails if any code is uncovered.

### Phase 3b — Diagnostic plumbing (after harness lands)

1. F-DIAG-003 one-word fix.
2. Parser panic sites: replace with `diag_add_ex` carrying real line/col.
3. RACE/diag_add_ex(0,0) sites: thread real line/col through.
4. Add the missing 17 negative tests (Phase 3a's lint will tell you which they are).
5. TNT-001 emit path or remove the suggestion.
6. type_diag carets at error site, not fn header.
7. EFF-001 single severity.
8. OWN-G4 message restoration.
9. Parser error recovery (basic: continue past first parse error).
10. `undefined variable` diagnostic in type-checker.
11. Replace ~167 `print("ERROR:")` halts with proper coded diagnostics. Mass refactor — group by category and assign codes.
12. Remove duplicate `diag_add_ex` definition.
13. Suggestion sanity check: don't suggest `.clone()` for non-Clone types.

## Test mandate

- Phase 3a: the harness changes are themselves tests — running the new gate on the existing corpus must produce sensible new failures (which Lane 2/3/etc. then close). Initial run will show the gate finding the very issues this audit found.
- Phase 3b: add the 17 missing negative tests; each has expected exit code 1 + expected regex.

## Verify policy

Run `bash tools/verify.sh` at end of Phase 3a (will likely show new failures from the corpus — those are EXPECTED, NOT THIS LANE's PROBLEM, document in report and proceed). Then run again at end of Phase 3b (target FAIL=0 for THIS lane's added tests). Other lanes' findings still failing is acceptable for this lane's verify since the harness is now correctly detecting them.

## Hard constraints

- Lane 3 explicitly may break verify in the sense of newly-failing tests for OTHER lanes' issues. That's the point of this lane.
- Document any newly-failing tests as expected; they are remediated by other lanes.
- Critical: do NOT silently fix other lanes' findings — restrict to Lane 3 scope.

## Output

- Branch + final report `docs/audit/lanes/LANE_3_REPORT.md`.
