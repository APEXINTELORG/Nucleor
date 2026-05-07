# Lane 4 / Queue 4A — Law optimizer rewrite gate

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Branch:** `fix/laws-optimizer-rewrite-gate-v0845`
- **Base:** `origin/main` @ `21135f09`
- **Scope:** Audit + small lock-in. The substantive gate landed pre-v0845.

## Headline

The optimizer rewrite gate is already implemented and locked by
fixtures (local-claude2 v0842 ship). The gate uses a source-text
predicate pair:

- `@audit(law_opt_required)` — file-level opt-in declaring the source
  asks the optimizer to use its `@law(...)` metadata for low-risk
  rewrites.
- `@audit(check_laws_passed)` — adopter declares they ran
  `nuc test --check-laws` and observed PASS.

When `law_opt_required` is present **without** `check_laws_passed`,
the compiler halts before any IR is emitted with `error[LAW-003]: …`
(panic at `compiler/nucleor_s1_compiler.nr:32327`). When both are
present, the compiler emits `info[LAW-AUDIT-GATE]: …` and proceeds.
The IR-level pass `opt_law_rewrite_block` (line 6236) remains a Phase
1 no-op (`return 0`), so semantics are unchanged today regardless of
the gate state. Phase 2 will populate that pass with the first
concrete rewrite (`f(a, identity) → a`) gated on this exact
predicate.

Per Queue 4A handoff goal:

> Make any optimizer rewrite gated by successful law validation
> metadata. If rewrite execution is not currently active, add a
> fail-closed guard and fixture proving unvalidated laws do not
> enable rewrites.

Both deliverables are met:
- The gate is the `@audit` predicate pair, enforced at source-text
  pre-pass.
- LAW-003 is the fail-closed guard (panic before IR).
- `tests/features/law_optimizer_identity_gate_smoke.nr` locks the
  positive (gate eligible → eligibility info fires, IR no-op,
  runtime semantics unchanged).
- `tests/err/err_law_optimizer_without_check.nr` locks the negative
  (gate opt-in without proof → LAW-003 hard error).

Empirical confirmation on current main (`21135f09`):

```
$ ./bin/nucleor.exe build tests/features/law_optimizer_identity_gate_smoke.nr -o lg1
info[LAW-AUDIT-GATE]: optimizer rewrite gate opted in
  (`@audit(law_opt_required)`) and proof-audit attribute present
  (`@audit(check_laws_passed)`); eligible @law annotations: 2
  emitted: target/lg1.ll (42382 bytes)
$ ./target/lg1.exe; echo $?
0

$ ./bin/nucleor.exe build tests/err/err_law_optimizer_without_check.nr -o lg2
error[LAW-003]: source declares `@audit(law_opt_required)` but is
  missing `@audit(check_laws_passed)`; run `nuc test --check-laws`,
  observe PASS, then add the audit attribute before enabling the
  optimizer gate
PANIC: nucleor: LAW-003 optimizer rewrite gate without check-laws audit
```

Both fixtures fire as expected.

## v0845 lane 4 / queue 4A delta

The substantive gate is shipped. The remaining gap is a tighter
**IR-level** trip wire so that future Phase 2 work cannot
accidentally enable a rewrite without the full proof contract. This
is one helper function:

```nr
// v0845 Lane 4 / Queue 4A: explicit Phase-2 proof sentinel.
// Future rewrite logic in opt_law_rewrite_block MUST consult this
// before applying any law metadata. Phase 1 returns 0 unconditionally
// so the no-op contract is locked at the IR level too. Phase 2 wires
// this to consult per-fn law-validation metadata produced by
// nuc test --check-laws.
#[manual_drop]
fn law_opt_phase2_proof_validated(fn_law_id: i64) -> i64 {
    return 0;
}
```

`opt_law_rewrite_block` would early-return 0 if this gate is closed.
Today the body is empty so no behavior change; tomorrow if Phase 2
adds rewrite logic without consulting this, the gate stays closed
and rewrites silently no-op. (Better: future Phase 2 caller assigns
`law_opt_phase2_proof_validated → 1` only when proof is verified.)

This branch ships:
- The helper above (~10 LOC).
- An explicit early-return guard in `opt_law_rewrite_block` calling
  the helper.
- A comment block in `opt_law_rewrite_block` pointing future Phase 2
  contributors at the helper.
- This finding doc.

No new fixtures (existing two already cover both directions). The
positive smoke is unchanged behavior; the negative smoke is unchanged
fail-closed behavior.

## Phase 2 design contract (for whoever ships next)

When Phase 2 enables the first concrete rewrite (`f(a, identity) → a`):

1. Update `law_opt_phase2_proof_validated(fn_law_id)` to consult a
   side-table populated at lex/parse time from
   `nuc test --check-laws` validation results.
2. Pass the validated `fn_law_id` from the fn-attr collector into
   `opt_law_rewrite_block` (currently the IR-level pass has no fn
   identity; this is the plumbing required).
3. Add a positive fixture that builds with the audit pair, captures
   the IR (or uses `--time-passes`), and asserts `f(a, 0)` was
   rewritten to `a`.
4. Add a negative fixture: same source structure but with a FALSE
   `@law(identity = 5)`. Phase 2 must NOT rewrite — the
   `--check-laws` pass should have already caught the false law via
   bounded property generation, so the audit pair would never have
   been acquired. If the adopter forced both audits anyway, the
   IR-level proof gate refuses (extra layer).

Estimated Phase 2 size: 50-100 LOC plus 3-4 fixtures.

## Stop reason

The gate is shipped. The handoff's "smallest hook" guidance applies:
the existing implementation meets both stated goals. This branch's
delta is the IR-level sentinel + comment + finding doc — no
behavior change, just future-proofing for Phase 2.

## Honest residuals

1. **Gate proof is adopter discipline, not compiler-verified.** A
   user who adds `@audit(check_laws_passed)` without actually
   running `--check-laws` bypasses the gate. The audit pair is the
   contract; the compiler trusts the adopter. This is documented in
   the LAW-AUDIT-GATE info banner. Phase 2 / cert mode should
   require an actual signed proof artifact.
2. **No false-law negative fixture yet.** Adding one requires Phase
   2 rewrite logic to be present (so a false-law-rewrite would
   produce observable wrong output). Today Phase 1 is a no-op so
   the false-law case is trivially safe.
3. **`nuc test --check-laws` honesty.** The check pass currently
   covers `commutative`, `associative`, `identity`, `absorbing`,
   `idempotent`, `involution`, `distributive_over` for low-risk
   bounded integer cases. `inverse` and `fusion` are Queue 4B; float
   `eps` / approximate semantics are Queue 4C.
