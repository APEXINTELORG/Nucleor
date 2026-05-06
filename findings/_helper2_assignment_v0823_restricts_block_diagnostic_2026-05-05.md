# Helper2 Assignment v0823 - Restricts Block Diagnostic

Date: 2026-05-05
Owner: helper2
Base: fetch current `origin/main`; expected base is `1a9628937921353ef7958a015bc7544b4e6223b3` or newer
Branch: `fix/helper2-restricts-block-diagnostic-v0823`
Mode: focused compiler diagnostic lane

## Objective

Close one more Effect/Capability trust-gap edge without pretending full
effect-row enforcement exists.

Current state after v0.8.320:

- direct `pure fn` side effects emit `EFF-001`
- `pure fn ... requires [...]` emits `EFF-002`
- `with [no_alloc]` calling `with [Alloc]` can emit `EFF-003`
- standalone `requires [...]`, block-form `restricts [...]`, transitive user-call
  inference, and cross-module propagation remain open

Your target is block-form `restricts [...] { ... }`: when adopter source uses
that syntax, `nuc build` must emit a clear diagnostic instead of accepting,
misparsing, or pretending enforcement exists.

Default diagnostic direction: emit `error[EFF-003]` for block-form
`restricts [...]` until full restricts-block enforcement lands. The message
must say block-form `restricts [...]` is not yet enforced by s1 and should not
be relied on as a compile-time guarantee.

## Allowed Write Scope

Allowed:

- `compiler/nucleor_s1_compiler.nr`
- promoted generated artifacts if and only if the compiler source changes:
  - `bin/nucleor.exe`
  - `bootstrap/nucleor_s1_seed.ll`
- one promoted negative fixture from `tests/err/_unimplemented/` to
  `tests/err/`, preferably the smallest restricts-block fixture
- `tests/err/_unimplemented/README.md`
- `docs/rfcs/v1_PUNCHLIST.md`
- `findings/inbox/helper2_restricts_block_diagnostic_v0823_2026-05-05.md`

Do not edit:

- `stdlib/runtime/`
- `stdlib/rods/`
- `tools/check_perf_regression.sh`
- `tools/verify.sh`
- `tools/perf_baseline.json`
- `CHANGELOG.md`
- `RELEASES.md`

If the implementation requires a broad parser rewrite, stop with a finding
instead of forcing it.

## Guardrails

- No Python helpers.
- Keep cold compile overhead minimal. Prefer a cheap source-level scanner
  folded into an existing diagnostic pass over a new full-file pass.
- Do not claim `restricts [...]` enforcement is complete. This lane is a clear
  diagnostic / no-silent-trust-gap closure.
- Do not touch helper1's NN/GNN ABI repair files.
- Rebuild/promote the compiler and seed if `compiler/nucleor_s1_compiler.nr`
  changes.

## Suggested Commands

```powershell
git fetch origin
git checkout -b fix/helper2-restricts-block-diagnostic-v0823 origin/main
git merge-base HEAD origin/main
git status --short
```

Useful searches:

```powershell
rg -n "restricts \\[" compiler tests docs
Get-Content tests\err\_unimplemented\err_restricts_violation.nr
Get-Content tests\err\_unimplemented\err_restricts_builtin_io.nr
```

Rebuild pattern if compiler source changes:

```powershell
.\nuc.bat build compiler\nucleor_s1_compiler.nr -o nucleor_seed
Copy-Item target\nucleor_seed.exe bin\nucleor.exe -Force
Copy-Item target\nucleor_seed.ll bootstrap\nucleor_s1_seed.ll -Force
```

## Required Report Sections

- Summary
- Base and branch
- Files changed
- Diagnostic behavior before/after
- Fixture promoted
- Commands run
- Validation
- Remaining effect-row gaps

## Validation

Required before pushing if compiler source changes:

```powershell
git diff --check
bash tools/check_self_host_md5.sh
bash tools/check_compiler_drift.sh
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Also run focused probes:

```powershell
.\bin\nucleor.exe build tests\err\<promoted_restricts_fixture>.nr -o _restricts_probe --no-cache
bash tools/verify.sh --only "negative <promoted_restricts_fixture_without_ext>"
```

Push:

```powershell
git push -u origin fix/helper2-restricts-block-diagnostic-v0823
```

