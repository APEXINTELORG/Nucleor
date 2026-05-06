# Helper1 Assignment v0823 - NN/GNN Void Return ABI Repair

Date: 2026-05-05
Owner: helper1
Base: fetch current `origin/main`; expected base is `1a9628937921353ef7958a015bc7544b4e6223b3` or newer
Branch: `fix/helper1-nn-gnn-void-abi-repair-v0823`
Mode: focused implementation lane

## Objective

Fix the confirmed void-return ABI mismatches from your v0822 extern ABI
evidence sweep.

Prior report now on main:

`findings/inbox/helper1_extern_abi_evidence_sweep_v0822_2026-05-05.md`

Default repair direction: keep the C runtime definitions unchanged and change
the Nucleor rod extern declarations plus public wrappers for command/free
functions to return `void`. Do not add fake integer status returns unless a
real caller contract requires one. If you believe a status return is required,
file that as a finding and stop before widening the patch.

## Confirmed Symbols To Repair

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

## Allowed Write Scope

Allowed:

- `stdlib/rods/gnn.nr`
- `stdlib/rods/nn.nr`
- targeted smoke fixtures under `tests/rods/` or `tests/features/` if they are
  small and actually execute the repaired public surface
- `findings/inbox/helper1_nn_gnn_void_abi_repair_v0823_2026-05-05.md`

Do not edit:

- `compiler/`
- `stdlib/runtime/`
- `bin/`
- `bootstrap/`
- `tools/check_perf_regression.sh`
- `tools/verify.sh`
- `tools/perf_baseline.json`
- `CHANGELOG.md`
- `RELEASES.md`

If a required caller update is outside the allowed scope, stop with a finding
that names the exact caller and smallest safe patch.

## Guardrails

- No Python helpers.
- Do not repair by hiding the mismatch in docs only.
- Do not remove or skip public wrappers unless they are proven unused and
  redundant.
- Keep the public API honest: if the C function is `void`, a Nucleor wrapper
  must not return an undefined integer register.
- Avoid broad rod refactors. This is an ABI repair, not an NN/GNN redesign.

## Suggested Commands

```powershell
git fetch origin
git checkout -b fix/helper1-nn-gnn-void-abi-repair-v0823 origin/main
git merge-base HEAD origin/main
git status --short
```

Useful source checks:

```powershell
rg -n "nuc_gnn_graph_free|nuc_gnn_gatv2_adam_step|nuc_gnn_gatv2_zero_grad" stdlib\rods\gnn.nr stdlib\runtime\gnn_rt.c
rg -n "nuc_nn_reset_rng|nuc_nn_dense_zero_grad|nuc_nn_dense_set_cache|nuc_nn_adam_step_dense|nuc_nn_adam_step_logits|nuc_nn_adam_tick|nuc_nn_adam_step_logits_no_tick|nuc_nn_lbfgs_step_dense" stdlib\rods\nn.nr stdlib\runtime\nn_rt.c
rg -n "return nuc_gnn_|return nuc_nn_" stdlib\rods\gnn.nr stdlib\rods\nn.nr
```

## Required Report Sections

- Summary
- Base and branch
- Files changed
- Symbols repaired
- Public wrapper behavior before/after
- Smoke fixtures added, or explicit reason none were safe in this slice
- Commands run
- Validation
- Follow-up for ABI parity gate, if any

## Validation

Required before pushing:

```powershell
git diff --check
bash tools/check_compiler_drift.sh
```

If you add smoke fixtures, run the focused build/run commands for them. Prefer
real execution over build-only proof. Also run any existing focused rod tests
that already cover the touched wrappers.

Push:

```powershell
git push -u origin fix/helper1-nn-gnn-void-abi-repair-v0823
```
