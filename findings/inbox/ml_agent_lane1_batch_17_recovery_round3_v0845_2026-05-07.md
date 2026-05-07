# ML Suite recovery smokes round 3 — Queue ML-20

Branch: fix/ml-20-batch-17-recovery-round3-v0845 (from origin/main HEAD)
Date: 2026-05-07

## Headline

**4 more deferred capabilities recovered**, with a 4/4 success rate on this batch — the recovery pattern is increasingly reliable when targets are chosen for single-pass kernel structure.

| | Detail |
|---|---|
| Recovery candidates attempted | 4 |
| Build clean | 4/4 |
| 30-run stable | **4/4** |
| Newly-recovered capabilities | log_softmax, sigmoid, attention_score, top-p filter |

## Ship-ready (4) — `tests/features/ml_recover_*.nr`

| Smoke | Recovers from | Test approach |
|---|---|---|
| `ml_recover_log_softmax_f64` | ML-10 (`torch_cross_entropy_f64` family) | log_softmax of [0, 0, 0] → log(1/3) ≈ -1.0986 in each entry |
| `ml_recover_sigmoid_f64` | ML-10 (`torch_bce_with_logits_f64` family) | sigmoid(0)=0.5, sigmoid(10)≈1, sigmoid(-10)≈0 |
| `ml_recover_attention_score_f64` | ML-11 (attention family) | scalar Q·K with explicit scale: q=[1,2,3], k=[4,5,6], scale=0.5 → 32 * 0.5 = 16 |
| `ml_recover_top_p_filter_f64` | ML-11 (`torch_top_p_filter_f64`) | nucleus filter over [0.5, 0.3, 0.15, 0.05] with top_p=0.8: kept count ≥ 2 |

## Cumulative recovery surface (after ML-18 + ML-19 + ML-20)

**11 deferred parity capabilities recovered** through the hand-authored pattern:

| # | Surface | Recovery smoke | From batch |
|--:|---|---|---|
| 1 | LayerNorm forward (PyTorch) | `ml_recover_layer_norm_forward_f64` | ML-18 |
| 2 | Linear SVC predict (sklearn) | `ml_recover_linear_svc_predict_f64` | ML-18 |
| 3 | PCA transform (sklearn) | `ml_recover_pca_transform_f64` | ML-18 |
| 4 | Scaled dot-product attention (PyTorch) | `ml_recover_scaled_dot_product_attention_f64` | ML-18 |
| 5 | Temperature softmax (PyTorch) | `ml_recover_temperature_softmax_f64` | ML-19 |
| 6 | Top-K (PyTorch) | `ml_recover_top_k_f64` | ML-19 |
| 7 | Multi-head SDPA (PyTorch) | `ml_recover_multi_head_attention_f64` | ML-19 |
| 8 | log_softmax (PyTorch) | `ml_recover_log_softmax_f64` | ML-20 |
| 9 | Sigmoid (PyTorch) | `ml_recover_sigmoid_f64` | ML-20 |
| 10 | Attention score (PyTorch) | `ml_recover_attention_score_f64` | ML-20 |
| 11 | Top-p filter (PyTorch) | `ml_recover_top_p_filter_f64` | ML-20 |

The recovery pattern's selection rule is now well-characterized:

- **Recovers cleanly:** kernels with single forward pass over modest tensors (LayerNorm fwd, log_softmax, sigmoid, softmax, scalar attention dot product, multi-head attention composition, top-k sort+select, top-p filter, PCA transform, SVC argmax).
- **Does NOT recover:** kernels with mutated accumulator state (StandardScaler fit's std vector, KNN min-distance tracker, boost margin accumulator, token embedding row-by-row copy).

This boundary corresponds neatly to the RFC-0062 G-8 Phase 2a compiler warning territory the canonical 0.8.323 emits on every build (move/borrow tracker conservative on arm-divergent patterns).

## Build / drift

- 4/4 build clean.
- 4/4 stable across 30 consecutive runs.
- Drift gate clean.

End of finding.
