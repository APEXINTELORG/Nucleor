# Helper1 v0823 - NN/GNN Void ABI Repair

Date: 2026-05-05
Owner: helper1
Branch: `fix/helper1-nn-gnn-void-abi-repair-v0823`
Base: `3c7b18e82f201e51052a3fdac7cd7fd58a6fb98d` (`origin/main`)
Mode: focused implementation lane

## Summary

Repaired the 11 confirmed NN/GNN void-return ABI mismatches from the v0822
extern ABI evidence sweep. The C runtime definitions already returned `void`;
this patch makes the Nucleor rod declarations and GNN public command wrappers
match that contract instead of exposing undefined integer return values.

No C runtime, compiler, bootstrap, bin, perf baseline, changelog, or release
files were edited.

## Base and branch

Commands:

```powershell
git fetch origin
git switch -c fix/helper1-nn-gnn-void-abi-repair-v0823 origin/main
git merge-base HEAD origin/main
```

After `origin/main` moved during validation, the branch was refreshed onto the
new current base:

```powershell
git stash push -u -m helper1-v0823-void-abi-before-origin-main-ff
git merge --ff-only origin/main
git stash pop
git merge-base HEAD origin/main
```

Final merge-base:

```text
3c7b18e82f201e51052a3fdac7cd7fd58a6fb98d
```

## Files changed

- `stdlib/rods/gnn.nr`
- `stdlib/rods/nn.nr`
- `tests/fixtures/v0778_rfc0061_gnn_wrappers_smoke.nr`

The existing `tests/fixtures/v0778_rfc0061_gnn_wrappers_smoke.nr` fixture was
updated because it still used two repaired GNN command wrappers as integer
expressions. Leaving it stale would preserve the old public API lie.

## Symbols repaired

GNN:

- `nuc_gnn_graph_free`
- `nuc_gnn_gatv2_adam_step`
- `nuc_gnn_gatv2_zero_grad`

NN:

- `nuc_nn_reset_rng`
- `nuc_nn_dense_zero_grad`
- `nuc_nn_dense_set_cache`
- `nuc_nn_adam_step_dense`
- `nuc_nn_adam_step_logits`
- `nuc_nn_adam_tick`
- `nuc_nn_adam_step_logits_no_tick`
- `nuc_nn_lbfgs_step_dense`

## Public wrapper behavior before/after

Before:

- GNN public wrappers `gnn_graph_free`, `gnn_gatv2_adam_step`, and
  `gnn_gatv2_zero_grad` returned `i64` by returning the result of C `void`
  functions.
- NN extern declarations advertised `i64` returns for command-style helpers
  that the C runtime implements as `void`.

After:

- GNN public command/free wrappers return `void` and call the matching externs
  as statements.
- NN command-style externs return `void`.
- Existing NN rod call sites already used the affected externs as statements,
  so no NN caller rewrite was required.
- The compile-only GNN wrapper surface fixture now references command wrappers
  as statements instead of integer expressions.

## Smoke fixtures added

No new smoke fixture was added. The existing GNN wrapper fixture already covered
the public wrapper surface and was the focused place to preserve compile-time
coverage. It was updated to reflect the repaired void-return contract.

Focused validation also built and ran the existing
`tests/features/gnn_circuit_to_graph_smoke.nr` fixture, which exercises
`gnn_graph_free` on a real graph handle.

## Commands run

Source inventory:

```powershell
rg -n "nuc_gnn_graph_free|nuc_gnn_gatv2_adam_step|nuc_gnn_gatv2_zero_grad|return nuc_gnn_" stdlib\rods\gnn.nr stdlib\runtime\gnn_rt.c
rg -n "nuc_nn_reset_rng|nuc_nn_dense_zero_grad|nuc_nn_dense_set_cache|nuc_nn_adam_step_dense|nuc_nn_adam_step_logits|nuc_nn_adam_tick|nuc_nn_adam_step_logits_no_tick|nuc_nn_lbfgs_step_dense" stdlib\rods\nn.nr stdlib\runtime\nn_rt.c
rg -n "(gnn_graph_free|gnn_gatv2_adam_step|gnn_gatv2_zero_grad|nuc_gnn_graph_free|nuc_gnn_gatv2_adam_step|nuc_gnn_gatv2_zero_grad)\(" . -g "*.nr"
rg -n "(nuc_nn_reset_rng|nuc_nn_dense_zero_grad|nuc_nn_dense_set_cache|nuc_nn_adam_step_dense|nuc_nn_adam_step_logits|nuc_nn_adam_tick|nuc_nn_adam_step_logits_no_tick|nuc_nn_lbfgs_step_dense)\(" . -g "*.nr"
```

Focused smoke:

```powershell
$bin = Join-Path (Get-Location) 'bin\nucleor.exe'
& $bin build tests/fixtures/v0778_rfc0061_gnn_wrappers_smoke.nr -o target\helper1_v0823_gnn_wrappers --no-cache
& $bin build tests/features/gnn_circuit_to_graph_smoke.nr -o target\helper1_v0823_gnn_circuit --no-cache
& .\target\helper1_v0823_gnn_circuit.exe
```

Required validation:

```powershell
git diff --check
bash tools/check_compiler_drift.sh
```

## Validation

Focused smoke:

```text
tests/fixtures/v0778_rfc0061_gnn_wrappers_smoke.nr build: PASS
tests/features/gnn_circuit_to_graph_smoke.nr build: PASS
target/helper1_v0823_gnn_circuit.exe run: PASS
```

Required checks:

```text
git diff --check: PASS
```

`git diff --check` exited 0. Git emitted a pre-existing line-ending warning for
`docs/rfcs/rod_manifest.toml`; that file is not modified by this branch and is
not in `git status --short`.

```text
bash tools/check_compiler_drift.sh: FAIL
```

Failure:

```text
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
FAIL: git tags exist with no CHANGELOG entry:
  - v0.8.319
  - v0.8.320
Add a per-version block to CHANGELOG.md or remove the stray tag.
```

This drift failure is outside the v0823 write scope because the assignment
explicitly forbids editing `CHANGELOG.md` and releases. The ABI repair itself
does not touch changelog, release, manifest, compiler, runtime, bootstrap, bin,
or perf baseline files.

## Follow-up for ABI parity gate

Add an extern return-type parity check to the ABI sweep/gate so C `void`
definitions cannot be exposed as integer-returning Nucleor externs. The v0822
manual sweep found that simple arity screens can produce comment/split-line
false positives; the durable gate should parse C signatures robustly enough to
distinguish:

- true arity mismatch,
- return-type mismatch,
- pointer-return declarations with no whitespace before the function name,
- inline comments inside argument lists.

