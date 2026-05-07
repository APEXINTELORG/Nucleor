# ML Suite recovery smokes round 11 — Queue ML-28

Branch: fix/ml-28-batch-25-recovery-round11-v0845
Date: 2026-05-07

## Headline

**3/3 stable**. Stats scalar quantile/median/IQR, stats min/max, and the `LmHeadWeightsF64`-struct-interface variant of LM head logits.

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **3/3** |

## Ship-ready (3)

| Smoke | Surface |
|---|---|
| `ml_recover_stats_quantile_f64` | `stats_median_f64` (=5), `stats_iqr_f64` (=4), `stats_quantile_f64(0.5)` (=5) over [1..9] |
| `ml_recover_stats_min_max_f64` | `stats_min_f64` (=1), `stats_max_f64` (=9) over [3,1,4,1,5,9,2] |
| `ml_recover_lm_head_logits_from_weights_f64` | LmHeadWeightsF64 struct-literal initialization → `ai_lm_head_logits_from_weights_f64`; same numerics as `ml_recover_lm_head_logits_f64` from ML-22 |

## Cumulative recovery surface (after ML-18..28): 40 capabilities

End of finding.
