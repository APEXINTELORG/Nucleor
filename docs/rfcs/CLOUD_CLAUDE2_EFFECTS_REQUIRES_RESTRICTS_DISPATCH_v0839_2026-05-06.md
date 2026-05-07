# Cloud Claude2 Dispatch v0839: Effects, Requires, Restricts Closure

Date: 2026-05-06
Owner: cloud Claude lane 2
Base: current `origin/main` at or after `35028273`
Branch: `fix/cloud-claude2-effects-requires-restricts-v0839`

## Goal

Advance the remaining RFC-0033 effect/capability gap without overlapping the
local helper lanes:

- Helper1 owns ROBO-7 `FRAME-001` diagnostic broadening.
- Helper2 owns RFC-0063 tools-suite duplicate Wave 2.
- Cloud Claude lane 1 owns PKG-1/R06 native Linux proof.

This lane owns a bounded compiler slice for standalone `requires [...]` row
enforcement and real block-form `restricts [...]` enforcement. If a full slice
is not clean, ship the largest focused fail-closed slice and document the exact
remaining blocker.

## Start Commands

```bash
git fetch origin
git checkout -B fix/cloud-claude2-effects-requires-restricts-v0839 origin/main
git status --short --branch
git log --oneline --decorate -5
```

## Current Punchlist Facts

The current punchlist says:

- RFC-0033 `with [no_alloc]` / `with [no_panic]` has bounded same-file/direct
  wrapper coverage.
- `pure fn` direct builtin I/O now emits `EFF-001`.
- Several archived restricts/effect fixtures are fail-closed companions.
- Still open: full standalone `requires [...]` row enforcement, real block-form
  `restricts [...]` enforcement, deeper transitive row propagation,
  cross-module propagation, methods, closures, higher-order effects, and
  broader effect-row subtyping.

## Scope A: Source Survey

Inspect before editing:

```text
compiler/nucleor_s1_compiler.nr
compiler/nucleor_tools_suite.nr
docs/rfcs/v1_PUNCHLIST.md
docs/spec/Nucleor_Error_Codes.md
tests/err/err_restricts_builtin_io.nr
tests/err/err_restricts_violation.nr
tests/err/err_restricts_channel_effect.nr
tests/err/err_effect_inference.nr
tests/err/err_effect_transitive.nr
tests/err/err_effect_deep_chain.nr
```

Answer in the report:

- where `requires [...]`, `restricts [...]`, `with [...]`, and `pure fn` are
  parsed or source-scanned today;
- which diagnostics already exist and which are reserved;
- which paths are active enforcement versus archive/fail-closed guard.

## Scope B: Implement One Bounded Enforcement Slice

Preferred implementation target:

- standalone function-level `requires [...]` row enforcement for direct call
  sites where the callee row and caller context are visible; and
- block-form `restricts [...]` direct builtin-I/O enforcement, if it is a clean
  source/AST-local slice.

Rules:

- Preserve existing clean fixtures and diagnostics.
- Fail closed for unsupported forms instead of silently accepting trust gaps.
- Do not touch ROBO-7 or RFC-0063 parser dedup files unless required by a
  compiler compile fix.
- Keep the first slice bounded. Do not attempt whole-program effect inference,
  closure/higher-order propagation, or cross-module propagation in this queue.
- Keep both compiler copies synchronized if the affected diagnostic or checker
  path exists in both `nucleor_s1_compiler.nr` and `nucleor_tools_suite.nr`.

Expected new fixtures, adjusted to the actual syntax discovered in Scope A:

```text
tests/err/err_requires_row_direct_call.nr
tests/features/requires_row_clean_smoke.nr
tests/err/err_restricts_block_builtin_io.nr
tests/features/restricts_block_clean_smoke.nr
```

Use fewer fixtures if a surface is not genuinely implemented. Do not create
placeholder fixtures that do not prove behavior.

## Scope C: Documentation and Report

Update, only for proven work:

```text
docs/rfcs/v1_PUNCHLIST.md
docs/spec/Nucleor_Error_Codes.md
```

Create:

```text
findings/inbox/cloud_claude2_effects_requires_restricts_v0839_2026-05-06.md
```

Include:

- branch, HEAD, base, merge-base;
- completed enforcement slice;
- skipped surfaces and exact blockers;
- changed files;
- focused command outputs;
- residual RFC-0033 gap table;
- whether main needs drift, perf, self-host, or full verify.

## Required Validation

Focused compiler build:

```bash
./bin/nucleor build compiler/nucleor_s1_compiler.nr -o _cloud_claude2_effects_s1_v0839 --no-cache
```

Run focused fixtures with the new compiler executable if available:

```bash
./target/_cloud_claude2_effects_s1_v0839 build tests/err/err_requires_row_direct_call.nr -o _requires_row_bad --no-cache
./target/_cloud_claude2_effects_s1_v0839 build tests/features/requires_row_clean_smoke.nr -o _requires_row_clean --no-cache
./target/_requires_row_clean
./target/_cloud_claude2_effects_s1_v0839 build tests/err/err_restricts_block_builtin_io.nr -o _restricts_block_bad --no-cache
./target/_cloud_claude2_effects_s1_v0839 build tests/features/restricts_block_clean_smoke.nr -o _restricts_block_clean --no-cache
./target/_restricts_block_clean
```

Adjust names if the final fixture names differ. Confirm the negative fixtures
emit the intended `EFF-*` / capability diagnostic and that one existing
non-effect type error still emits its original `TYP-*` code.

Required gates:

```bash
bash tools/check_compiler_drift.sh
git diff --check
```

Run perf if the check is in a broad hot compiler path:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Do not run full verify by default.

