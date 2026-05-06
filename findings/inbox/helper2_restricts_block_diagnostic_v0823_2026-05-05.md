# Helper2 Restricts Block Diagnostic v0823

Date: 2026-05-05
Owner: helper2
Branch: `fix/helper2-restricts-block-diagnostic-v0823`
Base: `origin/main` at `3c7b18e82f201e51052a3fdac7cd7fd58a6fb98d`

## Summary

This branch closes the block-form `restricts [...] { ... }` no-silent-trust
gap for Phase 1 behavior. It does not implement real restricts-block effect
enforcement. Instead, adopter code using the block form now fails loudly during
`nuc build` with `error[EFF-003]`, stating that the construct is not yet
enforced by s1 and must not be relied on as a compile-time guarantee.

The branch was explicitly rebased against current `origin/main` after the user
request. The rebase was a no-op because `HEAD`, `origin/main`, and merge-base
were already equal at `3c7b18e82f201e51052a3fdac7cd7fd58a6fb98d`; WIP changes
were stashed and reapplied without conflict.

## Base and Branch

- Worktree:
  `C:\Users\JoeWe\Nucleor_OSS_helper2_restricts_block_diag_v0823`
- Branch:
  `fix/helper2-restricts-block-diagnostic-v0823`
- Base and merge-base:
  `3c7b18e82f201e51052a3fdac7cd7fd58a6fb98d`
- Assignment:
  `findings/_helper2_assignment_v0823_restricts_block_diagnostic_2026-05-05.md`

## Files Changed

- `compiler/nucleor_s1_compiler.nr`
  - Adds a parse-primary guard for `restricts [` at expression start.
  - Emits `error[EFF-003]` and halts before the block can be misparsed.
  - Updates the effect/capability audit-info text so it says block-form
    `restricts` now fails closed while real enforcement remains open.
- `bin/nucleor.exe`
  - Rebuilt/promoted from the updated self-host compiler.
- `bootstrap/nucleor_s1_seed.ll`
  - Rebuilt/promoted from the updated self-host compiler.
- `tests/err/err_restricts_builtin_io.nr`
  - Promoted negative fixture.
- `tests/err/_unimplemented/err_restricts_builtin_io.nr`
  - Removed from the unimplemented holding area.
- `tests/err/_unimplemented/README.md`
  - Count and restricts row updated.
- `docs/rfcs/v1_PUNCHLIST.md`
  - Marks block-form `restricts` Phase 1 no-silent-trust-gap behavior as done
    while keeping real enforcement open.
- `findings/inbox/helper2_restricts_block_diagnostic_v0823_2026-05-05.md`
  - This report.

## Diagnostic Behavior Before/After

Before this change, the smallest restricts-block fixture did not emit the
intended effect diagnostic. The current base misparsed the block and eventually
failed with:

```text
error[TYP-005]: undefined function `io()`.
```

After this change:

```text
error[EFF-003]: block-form `restricts [...] { ... }` is not yet enforced by s1 and must not be relied on as a compile-time guarantee. Remove the block or rewrite the code without depending on `restricts` until full effect-row enforcement lands.
PANIC: nucleor: block-form `restricts [...]` not yet enforced by s1 (see error[EFF-003] above)
```

This is intentionally a fail-closed diagnostic, not real capability-row
semantics.

## Fixture Promoted

Promoted:

`tests/err/err_restricts_builtin_io.nr`

The fixture is intentionally small:

```nucleor
fn main() -> i32 {
    restricts [io] {
        print_int(1);
        0
    }
}
```

It now locks the parse/build-path diagnostic through the normal negative test
surface.

## Commands Run

```powershell
git fetch origin
git rebase origin/main
```

Result: current branch was already up to date after stashing WIP; WIP reapplied
without conflict.

```powershell
.\nuc.bat build compiler\nucleor_s1_compiler.nr -o nucleor_seed
Copy-Item target\nucleor_seed.exe bin\nucleor.exe -Force
Copy-Item target\nucleor_seed.ll bootstrap\nucleor_s1_seed.ll -Force
```

Result: PASS; compiler and seed promoted.

```powershell
.\bin\nucleor.exe build tests\err\err_restricts_builtin_io.nr -o _restricts_probe --no-cache
```

Result: expected failure with `error[EFF-003]`.

```powershell
bash tools\verify.sh --only "negative err_restricts_builtin_io"
```

Result: PASS: 1, SKIP: 277.

```powershell
git diff --check
```

Result: PASS.

```powershell
bash tools/check_compiler_drift.sh
```

Result: PASS.

```powershell
bash tools/check_self_host_md5.sh
```

Result: PASS.

```text
OK: self-host compiler IR fixed point holds md5=cf6024bdb24bcf6ddc657ddc099f8edd
OK: bootstrap seed matches current self-host IR md5=cf6024bdb24bcf6ddc657ddc099f8edd
```

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Result: PASS.

```text
OK perf: cold=3.59s (max 4s) | hot=0.25s (max 1s) | mem cold_tree=307/400MB cold_compiler=293/350MB hot_tree=31/128MB hot_compiler=17/64MB
```

## Validation

Required validation passed on the rebased/current base:

- `git diff --check`
- `bash tools/check_self_host_md5.sh`
- `bash tools/check_compiler_drift.sh`
- `pwsh -NoProfile -File tools\check_perf_regression.ps1`
- Focused build probe for `tests\err\err_restricts_builtin_io.nr`
- Focused verify probe for `negative err_restricts_builtin_io`

## Remaining Effect-Row Gaps

Still open:

- standalone `requires [...]` row enforcement,
- real block-form `restricts [...]` effect enforcement,
- transitive user-call effect inference,
- cross-module effect propagation.

This branch only prevents users from treating an unenforced `restricts` block
as a working compile-time guarantee.
