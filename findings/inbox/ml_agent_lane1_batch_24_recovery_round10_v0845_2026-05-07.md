# ML Suite recovery smokes round 10 — Queue ML-27

Branch: fix/ml-27-batch-24-recovery-round10-v0845
Date: 2026-05-07

## Headline

**4/4 stable**. Targeting tensor clone, column extract, raw KNN search, and LayerNorm backward — all stable across 30 runs.

| | Count |
|---|---:|
| Candidates | 4 |
| Build clean | 4/4 |
| 30-run stable | **4/4** |

## Ship-ready (4)

| Smoke | Surface |
|---|---|
| `ml_recover_clone_token_ids_i64` | `ai_clone_token_ids_i64` — single-pass tensor copy preserves shape + values |
| `ml_recover_threshold_column_f64` | `ai_threshold_column_f64` — extract a single column from a 2D thresholds tensor |
| `ml_recover_knn_train_k_indices_i64` | `knn_train_k_indices_i64` — raw k-nearest-neighbor index search (no class prediction); query (0.5, 0.0) over 4 train rows returns nearest two: indices {0, 1} |
| `ml_recover_layer_norm_backward_f64` | `nn_layer_norm_backward_f64` — returns LayerNormBackwardF64 (input + weight + bias gradients); validates shapes + bias gradient = grad_output for single-row batch |

## Cumulative recovery surface (after ML-18..27): 37 capabilities

The recovery rule continues to hold cleanly: tensor clones, column extracts, raw search returning indices, and structured-result backward kernels all recover when each is a single-pass operation without mutated min/max trackers.

## Build / drift

- 4/4 build clean.
- 4/4 stable across 30 consecutive runs.
- Drift gate clean.

End of finding.
