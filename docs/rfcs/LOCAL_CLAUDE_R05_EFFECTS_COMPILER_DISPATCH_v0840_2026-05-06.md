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

## Continuation v0841 - R05 Same-File Transitive Effect Slice

Status before this queue: the first block-form `restricts [...] { ... }` slice
landed on main as `218117d6`; Helper1 ROBO-7 repair landed as `74303c3d`;
Helper2 Wave 5 landed as `34d12338`. Fetch first and start fresh from current
`origin/main`.

Branch:

```text
fix/local-claude-r05-transitive-effects-v0841
```

Start:

```powershell
git fetch origin
git checkout -B fix/local-claude-r05-transitive-effects-v0841 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Goal:

- Implement the next real compiler-enforced R05/RFC-0033 slice.
- Preferred target: bounded same-file transitive effect summaries for direct
  user-function calls reached from a `restricts [...] { ... }` block.
- The compiler should be able to reject a cleanly reachable shape where a
  restricts block calls an unrowed same-file helper, and that helper directly
  or transitively calls a rowed effectful function or known effectful builtin.

Concrete target behavior:

```text
fn read_sensor() -> i64 requires [io.read] { return 1; }
fn helper() -> i64 { return read_sensor(); }
fn main() -> i64 {
    restricts [io] {
        return helper();
    }
}
```

The build should fail with `error[EFF-003]` on the restricts surface once the
transitive summary is implemented. Today, related fixtures may still fail via
`EFF-001` from the direct requires-row guard. That is acceptable as an interim
guard but not the end-state for this queue.

Required survey:

- `enforce_restricts_block_effects`
- `collect_requires_effect_rows`
- `enforce_requires_direct_calls`
- direct builtin effect mapping used by pure/restricts diagnostics
- existing fixtures:

```text
tests/err/err_effect_inference.nr
tests/err/err_effect_deep_chain.nr
tests/err/err_restricts_block_builtin_io.nr
tests/features/restricts_block_clean_smoke.nr
tests/features/requires_row_clean_smoke.nr
```

Implementation boundaries:

- Same file only.
- Direct calls and bounded transitive user-function calls only.
- No cross-module propagation.
- No methods, closures, trait dispatch, higher-order functions, or async task
  propagation.
- No parser unification or tools-suite duplicate deletion.
- No ROBO-7 or Linux package/R06 work.
- No Python helpers.

Fixtures:

Add focused fixtures only for behavior actually implemented. Candidate names:

```text
tests/err/err_restricts_block_transitive_unrowed_io.nr
tests/err/err_restricts_block_transitive_deep_chain.nr
tests/features/restricts_block_transitive_clean_smoke.nr
```

If you update existing `err_effect_inference.nr` or
`err_effect_deep_chain.nr` expectations, document exactly why the primary
diagnostic moved from `EFF-001` to `EFF-003`.

Validation:

```powershell
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_r05_transitive_s1_v0841 --no-cache --no-link
```

Then build every new negative fixture and confirm the expected `EFF-*` code.
Build every new positive fixture and run it when it emits an executable.

Required gates:

```bash
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
```

Required because this is compiler hot-path work:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Watch cold compiler RSS carefully: after the ROBO-7 repair it was close to the
350MB ceiling. Prefer one source walk or a small memoized table over repeated
full-source scans.

Deliverable:

Create:

```text
findings/inbox/local_claude_r05_transitive_effects_v0841_2026-05-06.md
```

Include branch, HEAD, base, merge-base, implemented behavior, skipped surfaces,
changed files, focused validation output, drift/ABI/diff/perf results, and
remaining R05/RFC-0033 gaps.

## Continuation v0842 - R05 RFC-0033 Row Subtyping / `with` Bridge

Start this only after the v0841 transitive-effects queue is pushed or explicitly
blocked. Fetch first and start fresh from current `origin/main`.

Branch:

```text
fix/local-claude-r05-with-row-subtyping-v0842
```

Start:

```powershell
git fetch origin
git checkout -B fix/local-claude-r05-with-row-subtyping-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Goal:

- Connect the existing RFC-0033 `with [...]` enforcement subset to the same
  row-family overlap semantics used by `requires [...]` and block-form
  `restricts [...]`.
- Prefer one or two real compiler-enforced cases with fixtures over broad
  theory.

Preferred target behavior:

```text
fn allocs() -> i32 with [Alloc] {
    let v: Vec<i64> = Vec::new();
    0
}

fn main() -> i32 with [no_alloc] {
    allocs()
}
```

This should continue to fail, but the row-family handling should also catch
sub-effect/family variants where the syntax allows them. If the current syntax
does not support a richer row, document that precisely and instead add the
smallest valid bridge from `with [no_alloc]` to the shared row-overlap helper.

Primary files:

```text
compiler/nucleor_s1_compiler.nr
tests/err/err_effects_with_alloc_call.nr
tests/features/requires_row_clean_smoke.nr
docs/rfcs/v1_PUNCHLIST.md
docs/spec/Nucleor_Error_Codes.md
```

Candidate fixtures:

```text
tests/err/err_effects_with_alloc_family_call.nr
tests/features/effects_with_clean_smoke.nr
```

Boundaries:

- Same-file direct calls only unless the v0841 transitive implementation is
  already on main and can be reused safely.
- No cross-module effects.
- No methods, closures, traits, async propagation, or parser unification.
- No ROBO-7, RT, RFC-0063, package/R06, Linux-only, or quantum work.
- No Python helpers.

Validation:

```powershell
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_r05_with_s1_v0842 --no-link --no-cache
```

Run every new negative fixture and confirm the expected `EFF-*` code. Build and
run every new positive fixture.

Required gates:

```bash
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
```

Required because this is compiler hot-path work:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Deliverable:

Create:

```text
findings/inbox/local_claude_r05_with_row_subtyping_v0842_2026-05-07.md
```

Include branch, HEAD, base, merge-base, implemented behavior, exact skipped
syntax/surfaces, changed files, validation, perf numbers, and remaining R05
hardening plan.
