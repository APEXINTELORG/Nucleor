# ML Suite recovery smokes round 21 — Queue ML-38

Branch: fix/ml-38-batch-35-recovery-round21-v0845
Date: 2026-05-07

## Headline

**2/2 stable** (after dropping 2 unstable NB log_proba candidates): pandas filter ≤ + drop_duplicates_by_key.

| | Count |
|---|---:|
| Final candidates | 2 |
| Build clean | 2/2 |
| 30-run stable | **2/2** |

## Ship-ready (2)

| Smoke | Surface |
|---|---|
| `ml_recover_pandas_filter_value_le_f64` | `frame_i64_f64_filter_value_le(30)` over [10,20,30,40,50] → 3 rows (≤ 30) |
| `ml_recover_pandas_drop_duplicates_f64` | `frame_i64_f64_drop_duplicates_by_key_keep_first` on duplicated keys returns first occurrence per key |

## Initially attempted, unstable (2)

| Smoke | Why |
|---|---|
| `ml_recover_multinomial_nb_predict_log_proba_f64` | Same multi-step UB as `predict_proba`, even though Gaussian variant recovered (ML-37) |
| `ml_recover_bernoulli_nb_predict_log_proba_f64` | Same as above |

The Multinomial/Bernoulli vs Gaussian split is a useful diagnostic: Gaussian computes per-sample independently (single matmul-like pass), while Multinomial+Bernoulli compute via dot product over log-prob tables which apparently has more state mutation than the canonical compiler tolerates.

## Cumulative recovery surface (after ML-18..38): 68 capabilities

End of finding.
