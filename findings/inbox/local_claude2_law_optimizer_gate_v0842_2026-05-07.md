# Queue 2 finding — Algebraic Law Optimizer Rewrite Gate (local-claude2 v0842)

- **Branch:** `fix/local-claude2-law-optimizer-gate-v0842`
- **HEAD:** `35694571ec3b00b28b37faf8b42a47a63f31e0f1`
- **Base / merge-base:** `f3bcf10407bac742fc29bf8e8155c30de1b21e49` (origin/main, `docs(findings): cloud Linux PKG-1 signed publish v0842 proof`)
- **Commit:** `35694571 compiler: algebraic law optimizer rewrite eligibility gate (Phase 2-prep)`
- **Pushed:** yes (`origin fix/local-claude2-law-optimizer-gate-v0842`)

Codex integration base: `origin/main` at
`1fd9aae9 laws: add bounded inverse check smokes`.

## Implemented behavior

`opt_law_rewrite_block` (the IR pass added at v0.8.265) remains a
no-op. **No actual rewrite fires today.** What this branch ships is
the *eligibility gate* that the Phase 2 rewrite must consult before
acting on any `@law(...)` metadata, plus the LAW-003 fail-closed
contract for declarations that demand the gate without proof.

The gate keys on two `@audit(...)` attributes at the source level:

- `@audit(law_opt_required)`     — file declares it requires the
  law-rewrite eligibility audit.
- `@audit(check_laws_passed)`    — user declares they have run
  `nuc test --check-laws` and observed `test result: PASS`.

s1 evaluates the gate inside the existing `info[LAW-G123]` audit
block in `compiler/nucleor_s1_compiler.nr`:

| `law_opt_required` | `check_laws_passed` | result |
|---|---|---|
| absent | (any) | no-op (preserves pre-Phase-2-prep behaviour for every existing source) |
| present | present | `info[LAW-AUDIT-GATE]` eligibility report (count of `@law(...)` annotations) |
| present | absent | `error[LAW-003]` halt before any IR is emitted |

LAW-003 was already reserved in the diagnostic registry; this is
its first emission site. Float laws, unbounded property generation,
fusion / seed / cases modifiers, and broad rewrites are out of
scope for this Phase 2-prep slice and remain hard-blocked.

## Files

### Compiler (1 file, +49 lines)

- `compiler/nucleor_s1_compiler.nr`
  - Inserted after the existing `v0858_has_law` / `info[LAW-G123]`
    block (~line 31810): a textual pre-pass that detects
    `@audit(law_opt_required)` and `@audit(check_laws_passed)`
    presence using `str_index_of` / `simple_attribute_audit_count`
    (same shape as the v0838 / v0848 / v0857 audit blocks above).
  - Self-host safe: needles built via `str_concat("@audit(",
    "law_opt_required")` / `str_concat("@audit(",
    "check_laws_passed")` so a self-host build of this file does
    not trip its own gate when scanning its own source.

### Test fixtures (2 files)

- `tests/features/law_optimizer_identity_gate_smoke.nr` — **NEW**
  positive smoke. Pairs `@audit(law_opt_required)` and
  `@audit(check_laws_passed)` with `@law(commutative, associative,
  identity = N)` annotations on `add_law_gated` (binary integer)
  and `mul_law_gated`. Plain `nuc build` is expected to emit
  `info[LAW-AUDIT-GATE]`; runtime semantics are unchanged because
  `opt_law_rewrite_block` remains a no-op.
- `tests/err/err_law_optimizer_without_check.nr` — **NEW** LAW-003
  fail-closed fixture with EXPECT header. Declares
  `@audit(law_opt_required)` with `@law(commutative, associative,
  identity = 0)` but omits `@audit(check_laws_passed)`; expected to
  halt the build with `error[LAW-003]: source declares
  \`@audit(law_opt_required)\` but is missing
  \`@audit(check_laws_passed)\`...`.

## Validation (commands + results)

```
$ ./bin/nucleor.exe test tests/features/law_optimizer_identity_gate_smoke.nr --check-laws --no-cache
info[CHECK-LAWS]: generated bounded integer law checks
  discovered tests: 2
    __nucleor_law_check_0
    __nucleor_law_check_1
  PASS: __nucleor_law_check_0
  PASS: __nucleor_law_check_1
test result: PASS (2 tests)
```

The gate-fixture's law metadata passes the bounded integer
property tests, satisfying the proof predicate that the user is
declaring with `@audit(check_laws_passed)`.

```
$ ./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o _claude2_law_opt_s1_v0842 --no-link --no-cache
  source: compiler/nucleor_s1_compiler.nr (2200183 bytes)
  functions: 834
  optimized: 2117 instructions
  emitted: target/_claude2_law_opt_s1_v0842.ll (11648724 bytes)
  (build OK, --no-link path)
```

s1 self-host smoke is clean with the new gate code present. Note:
the deployed `bin/nucleor.exe` predates this branch, so the
runtime `info[LAW-AUDIT-GATE]` / `error[LAW-003]` strings only
appear when a fresh `nucleor.exe` built from this branch is used
to compile the fixtures — out of scope for Phase 2-prep validation,
which only requires the gate code to compile, type-check, and
self-host. Phase 2 (the next ship) deploys the new s1 and then
exercises the runtime fixtures end-to-end.

```
$ bash tools/check_compiler_drift.sh
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: promoted compiler version matches source (0.8.323)
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
(parser-divergence WARN is the same pre-existing RFC-0063 Phase 2.0 line as Q1; not introduced here)
(audit_dup_fns_report.csv stale-marker is also pre-existing in this worktree, not caused by Q2)
```

```
$ bash tools/check_rod_void_abi.sh
OK: rod void ABI clean (355 C void nuc_* definitions, 1272 non-void rod externs checked)

$ git diff --check
(no output — no whitespace/merge markers introduced)
```

```
$ pwsh -NoProfile -File tools/check_perf_regression.ps1
OK perf: cold=3.74s (max 4s) | hot=0.43s (max 1s) | mem cold_tree=362/400MB cold_compiler=348/350MB hot_tree=70/128MB hot_compiler=55/64MB
```

`tools/verify_timings.csv` is not present in this worktree (only
populated by full `verify.sh` runs); the perf-regression script
ran cleanly within all four cold/hot budgets, slightly faster than
Q1 (3.88s → 3.74s cold, 0.44s → 0.43s hot).

## Worktree note

Same shared-worktree caveat as the Q1 finding applies. The
`Nucleor_OSS_integrate_helper2_wave5_v0840` worktree flipped its
checkout HEAD between several non-claude2 branches during this
run (`fix/local-claude3-qm6-mps-streaming-range-v0842`,
`fix/local-claude-r05-transitive-effects-v0841`, etc.), so the
Q2 commit was preserved by pushing to origin immediately after
local commit. The pushed remote branch is the source of truth.

## Boundaries respected

Per dispatch:

- ✓ **Single low-risk law class only.** The fixture declares
  `identity = 0` and `identity = 1` on integer fns. No other law
  family is touched by the gate path.
- ✓ **No broad optimizer rewrites enabled by default.**
  `opt_law_rewrite_block` is unchanged; no new rewrites fire.
- ✓ **No floating-point rewrites.** The gate path emits
  `info[LAW-AUDIT-GATE]` only for sources that already pass the
  integer-only `--check-laws` (float fns fail closed upstream
  with `LAW-004`).
- ✓ **No unbounded property generation.** The gate consumes the
  existing bounded integer checks; `seed` / `cases` / `fusion`
  remain unsupported.
- ✓ **No R05 / ROBO-7 / RFC-0063 / package / R06 / Helper3 lanes
  touched.** Only `compiler/nucleor_s1_compiler.nr` (LAW-G123
  audit block) and the two new test fixtures.
- ✓ **No Python helpers.** Only `.nr` source.

## Remaining law Phase 2 / 3 / 4 work

## Codex Integration Validation

Additional commands run from
`C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_law_optimizer_v0842`:

```text
PASS .\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
PASS .\bin\nucleor.exe test tests\features\law_optimizer_identity_gate_smoke.nr --check-laws --no-cache
PASS .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _lawopt_s1_v0842_integration --no-cache
PASS .\target\_lawopt_s1_v0842_integration.exe build tests\features\law_optimizer_identity_gate_smoke.nr -o _law_optimizer_identity_gate_v0842_integration --no-cache emits LAW-AUDIT-GATE and target exe rc=0
PASS .\target\_lawopt_s1_v0842_integration.exe build tests\err\err_law_optimizer_without_check.nr -o _law_optimizer_without_check_v0842_integration --no-cache fails with LAW-003
PASS bash tools/check_self_host_md5.sh md5=582b8b8596fe820a55ea99c5de95ceec
PASS bash tools/check_compiler_drift.sh (known RFC-0063 parser warnings only)
PASS bash tools/check_rod_void_abi.sh
PASS git diff --check
PASS pwsh -NoProfile -File tools\check_perf_regression.ps1
     cold=3.45s hot=0.40s cold_tree=360MB cold_compiler=345MB hot_tree=70MB hot_compiler=55MB
```

Codex integration fixed one issue found during validation: the initial gate
scanned raw source text, so the negative fixture's explanatory line comment
containing ``@audit(check_laws_passed)`` satisfied the audit predicate. The
integrated gate now scans `strip_strings_and_line_comments(after_async)`, so
comments and string literals cannot opt a file into the optimizer proof gate.

The regenerated `bin/nucleor.exe`, `bootstrap/nucleor_s1_seed.ll`, and
`tools/audit_dup_fns_report.csv` are included in the integration commit.

After this delivery, the explicit Phase 2 ship is unchanged:

- **Phase 2:** wire the gate's eligibility report into
  `opt_law_rewrite_block` so that, when the gate fires for a fn,
  the IR pass actually performs the first concrete rewrite
  (`f(a, identity) → a` and `f(identity, a) → a` for integer fns
  with `@law(identity = N)`). Today the IR pass still returns 0.
- **Phase 3:** broaden the eligibility-driven rewrites to the
  remaining low-risk classes (`absorbing`, `idempotent`,
  `involution`) using the same gate predicate.
- **Phase 3a:** Arbitrary-driven broad property tests (`seed`,
  `cases`) so the gate has a richer proof source than the four
  bounded integer points.
- **Phase 4:** cert-profile SMT/proof obligations (`LAW-002`) and
  float-law safeguards (`LAW-004` cert hardening); only after
  these does float / `eps=` / `approximate` become accepted in the
  gate.
