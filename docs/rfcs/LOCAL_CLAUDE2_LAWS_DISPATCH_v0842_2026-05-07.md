# Local Claude2 dispatch v0842 - Algebraic laws / proof gates

Audience: local Claude2
Base: fetch current `origin/main` before each queue
Mode: implementation, focused validation, push branch, write report

Do not edit R05, ROBO-7, RFC-0063, Linux package/R06, or Helper3 type/units
lanes. No Python helpers.

## Queue 1 - Algebraic Laws Phase 3b Broad Property Pack

Branch:

```text
fix/local-claude2-law-phase3b-property-pack-v0842
```

Start:

```powershell
git fetch origin
git checkout -B fix/local-claude2-law-phase3b-property-pack-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Goal:

- Expand `nuc test --check-laws` beyond the current bounded integer low-risk
  laws.
- Prefer one implemented law family with hard fixtures over broad claims.

Primary files:

```text
compiler/nucleor_s1_compiler.nr
tests/features/*law*.nr
tests/err/err_law_*.nr
docs/rfcs/v1_PUNCHLIST.md
docs/spec/Nucleor_Error_Codes.md
```

Preferred implementation:

1. Add bounded checks for `inverse` if the syntax is already captured.
2. If `inverse` needs too much syntax work, add the next supported
   `distributive_over` shape or a fail-closed diagnostic for unsupported
   forms that currently pass silently.
3. Keep float `eps` / approximate semantics out unless implemented with a
   concrete tolerance contract and fixtures.

Candidate fixtures:

```text
tests/features/law_inverse_bounded_smoke.nr
tests/err/err_law_unsupported_float_approx.nr
tests/err/err_law_malformed_inverse.nr
```

Validation:

```powershell
.\bin\nucleor.exe test tests\features\law_inverse_bounded_smoke.nr --check-laws --no-cache
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _claude2_law_s1_v0842 --no-link --no-cache
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Deliverable:

```text
findings/inbox/local_claude2_law_phase3b_property_pack_v0842_2026-05-07.md
```

## Queue 2 - Algebraic Law Optimizer Rewrite Gate

Start this only after Queue 1 is pushed or explicitly blocked. Fetch current
`origin/main` and start a fresh branch.

Branch:

```text
fix/local-claude2-law-optimizer-gate-v0842
```

Start:

```powershell
git fetch origin
git checkout -B fix/local-claude2-law-optimizer-gate-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Goal:

- Move algebraic laws from metadata/checking toward safe optimizer use.
- Implement a gated, proof-backed rewrite for one low-risk law class only.

Preferred implementation:

- Add an explicit opt-in gate that allows a rewrite only after
  `--check-laws` has validated the relevant law metadata in the same test/build
  flow.
- Start with one low-risk identity such as additive identity or multiplicative
  identity on integers.
- Emit a report/audit line proving whether a rewrite was eligible and applied.

Boundaries:

- Do not enable broad optimizer rewrites by default.
- No floating-point rewrites.
- No unbounded property generation.
- No R05/ROBO-7/RFC-0063/package/R06 work.
- No Python helpers.

Candidate fixtures:

```text
tests/features/law_optimizer_identity_gate_smoke.nr
tests/err/err_law_optimizer_without_check.nr
```

Validation:

```powershell
.\bin\nucleor.exe test tests\features\law_optimizer_identity_gate_smoke.nr --check-laws --no-cache
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _claude2_law_opt_s1_v0842 --no-link --no-cache
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Deliverable:

```text
findings/inbox/local_claude2_law_optimizer_gate_v0842_2026-05-07.md
```

Include branch, HEAD, base, merge-base, implemented law behavior, fixtures,
validation, perf numbers, and remaining law Phase 3/4 work.
