# Local Claude Dispatch v0840: R05 Effects Compiler Slice

Audience: local Claude on the Windows machine.

Branch:

```text
fix/local-claude-r05-effects-compiler-v0840
```

Start:

```powershell
git fetch origin
git checkout -B fix/local-claude-r05-effects-compiler-v0840 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

## Goal

Implement a real, bounded compiler behavior slice for R05/RFC-0033 effects.
This is not a report-only or coverage-only lane. New fixtures must prove changed
compiler behavior.

Cloud Claude is reserved for native Linux work. Do not take Linux package,
POSIX bridge, Linux bootstrap, or Linux perf tasks in this branch.

## Required Survey

Inspect before editing:

```text
compiler/nucleor_s1_compiler.nr
compiler/nucleor_tools_suite.nr
docs/spec/Nucleor_Error_Codes.md
docs/rfcs/v1_PUNCHLIST.md
tests/err/err_restricts_builtin_io.nr
tests/err/err_restricts_violation.nr
tests/err/err_effect_requires_direct.nr
tests/features/effect_requires_direct_ok.nr
tests/err/err_requires_row_direct_call.nr
tests/features/requires_row_clean_smoke.nr
```

Write the survey result into your report before the implementation summary:

- where `requires [...]`, `restricts [...]`, `with [...]`, and `pure fn` are
  parsed or scanned;
- where current enforcement is parser fail-closed versus semantic;
- which surface you implemented and which surfaces you deliberately left open.

## Implementation Scope

Pick one bounded compiler-enforced slice and complete it end to end.

Preferred slice:

- block-form `restricts [...] { ... }` handling that allows a clean block and
  rejects a direct builtin I/O violation with `EFF-003`.

Acceptable smaller slice if the parser change is too broad:

- same-file direct `requires [...]` propagation that is not already covered by
  `32ece3d6`, with a real negative and real positive fixture.

Boundaries:

- No whole-program effect inference.
- No cross-module propagation.
- No methods, closures, higher-order effects, or trait dispatch propagation.
- No parser unification or RFC-0063 duplicate deletion.
- No ROBO-7 frame diagnostics.
- No Python helpers.

If block-form `restricts [...]` cannot be safely changed without a broad parser
rewrite, stop with a precise blocker report and do not add more coverage-only
fixtures.

## Expected Fixtures

Only add fixtures for behavior you actually implement. Candidate names:

```text
tests/err/err_restricts_block_builtin_io.nr
tests/features/restricts_block_clean_smoke.nr
tests/err/err_requires_row_transitive_direct_chain.nr
tests/features/requires_row_transitive_clean_smoke.nr
```

Do not create placeholder fixtures.

## Validation

Run focused validation with the checked-in Windows compiler:

```powershell
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_effects_s1_v0840 --no-cache --no-link
```

Run every new negative fixture and confirm the expected `EFF-*` code appears.
Run every new positive fixture and confirm it builds and exits 0 when runnable.

Then run:

```powershell
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

If the compiler hot path changes materially, include the perf numbers in the
report. Keep cold compile under 4 seconds and process-tree RSS under the
current gate.

## Deliverable

Push the branch and write:

```text
findings/inbox/local_claude_r05_effects_compiler_v0840_2026-05-06.md
```

The report must include branch, HEAD, merge-base, implemented slice, skipped
surfaces, exact files changed, focused validation output, drift/ABI/diff/perf
results, and remaining R05/RFC-0033 gaps.
