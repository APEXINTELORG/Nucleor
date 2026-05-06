# Helper1 Finding - ML-13 GNN Node Convergence (v0868)

## Summary

ML-13 P2a now has a real GNN convergence fixture:

- Added `tests/features/gnn_node_convergence_smoke.nr`.
- Trains a one-channel GATv2 layer on a two-node self-loop graph.
- Uses sigmoid loss, `gnn_gatv2_backward`, `gnn_gatv2_zero_grad`, and Adam updates.
- Asserts learned node scores separate the two node classes and that the final score gap improves materially over the initial gap.

This is a functional train/update oracle, not a non-null handle smoke.

## Evidence

Focused fixture:

- `tests/features/gnn_node_convergence_smoke.nr`

Validated commands:

```powershell
git diff --check -- tests/features/gnn_node_convergence_smoke.nr
.\bin\nucleor.exe build tests\features\gnn_node_convergence_smoke.nr -o helper1_gnn_node_convergence --no-cache
.\target\helper1_gnn_node_convergence.exe
bash tools/verify.sh --only "test features/gnn_node_convergence_smoke"
```

The fixture checks:

- The GATv2 forward/backward/update path runs end-to-end.
- Prediction for feature `0.0` falls below `0.25`.
- Prediction for feature `1.0` rises above `0.75`.
- The trained prediction gap exceeds the initial gap by at least `0.40`.

## Files Changed

- `tests/features/gnn_node_convergence_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Residual

This closes the GNN portion of ML-13 P2 for a small deterministic node-classification task. SSM sequence-prediction convergence and transformer small-LM convergence remain open ML-13 P2 work. The GNN fixture intentionally stays tiny to avoid increasing full-gate wall time.
