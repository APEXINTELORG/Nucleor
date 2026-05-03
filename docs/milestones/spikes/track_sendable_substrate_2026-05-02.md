# Track RFC-0035 Sendable + Actor First-Pass Spike - 2026-05-02

Branch: `spike/v06-sendable-substrate`

Base: `origin/main` v0.6.17 (`0b361f4`)

## Scope

First-pass RFC-0035 substrate:

- `trait Sendable {}` and empty `impl Sendable for T {}` use the existing
  trait parser/type-checker path.
- `actor Name { fields }` is recovered as contextual source syntax and
  rewritten to the existing field-only struct path before lexing.
- `async_spawn`, `thread_spawn`, and `conc_spawn` reject bare local values
  whose declared type is not Sendable.
- `#[not_sendable]` wins over explicit marker impls and emits `RACE-008`
  at spawn boundaries.
- `&mut T` crossing a spawn/thread boundary emits `RACE-005`.
- Direct external field access on a variable typed as a field-only actor
  emits `RACE-003`.
- The source scanners include comment/string-aware fast paths so ordinary
  compiler files containing RFC-0035 words in docs do not pay the heavy
  transform/check cost.

## Deferred

The full v0.9 actor runtime, actor method `await` enforcement, structural
field-by-field Sendable derivation, borrowed-lifetime proofs, and reentrant
actor lock analysis remain follow-on work. Reserved codes `RACE-002`,
`RACE-004`, `RACE-006`, `RACE-007`, `RACE-009`, and `RACE-010` are documented
and explain-wired but not emitted by this first pass.

## Fixtures

Positive:

- `tests/features/rfc0035_sendable_marker.nr`
- `tests/features/rfc0035_actor_decl_parser.nr`

Negative:

- `tests/err/err_rfc0035_not_sendable_spawn.nr` -> `RACE-008`
- `tests/err/err_rfc0035_non_sendable_spawn.nr` -> `RACE-001`
- `tests/err/err_rfc0035_actor_field_escape.nr` -> `RACE-003`
- `tests/err/err_rfc0035_mut_ref_spawn.nr` -> `RACE-005`

## Validation

All validation below used `NUC_VERIFY_AGENT=parallel1`, `NUCLEOR_MEM_CAP_KB=0`,
and the repo peak-RSS e-stop wrapper where applicable. `1 GB` remains the
emergency stop only; the tighter ship budgets remain the real operating guard.

Focused gate:

```bash
pwsh tools/run_with_peakmem.ps1 -VerifyArgs '--only "RFC-0035 Sendable + actor first-pass substrate"' -EstopMb 1024 -PollMs 100
```

- PASS: final v0.6.17 RFC-0035 focused gate, step time 3.06s,
  wrapper peak 224 MB.
- PASS: rebased stage2/stage3 fixed-point;
  `target/nuc_s1_stage2_sendable_rebased.ll` and
  `target/nuc_s1_stage3_sendable_rebased.ll` have identical SHA-256
  `BEFEF8CEF2D034DF41961CC761E3C143BC1427B950F909391C3771E63137C383`.
- PASS: compiler self-build under 770 MB budget:
  - stage1 rebased: 657 MB, 7.358s
  - stage2 rebased: 705 MB, 66.913s
  - stage3 rebased: 706 MB, 62.173s
- PASS: tools-suite build under 580 MB budget: 495 MB, 27.501s.
- PASS: `bash tools/check_compiler_drift.sh`.
- PASS: `tools/verify.sh --range 19-19` for full explain registry wiring.
- PASS: `tools/verify.sh --range 87-88` for diag-code and spec-doc drift.
- PASS: `git diff --check` with only the pre-existing LF/CRLF warning on
  `tools/verify.ps1`.

The first unoptimized fixed-point attempt peaked at 768 MB. The fast-path guard
kept the final rebased stage peak at 706 MB after the v0.6.15 rebase.
