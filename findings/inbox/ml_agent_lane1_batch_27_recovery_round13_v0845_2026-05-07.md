# ML Suite recovery smokes round 13 — Queue ML-30

Branch: fix/ml-30-batch-27-recovery-round13-v0845
Date: 2026-05-07

## Headline

**4/4 stable**. Multinomial NB joint log likelihood, Bernoulli NB joint log likelihood, KNN 1nn distances-only, KNN 1nn indices-only. Confirms the recovery rule for both NB families and the raw KNN search primitives.

| | Count |
|---|---:|
| Candidates | 4 |
| Build clean | 4/4 |
| 30-run stable | **4/4** |

## Ship-ready (4)

| Smoke | Surface |
|---|---|
| `ml_recover_multinomial_nb_joint_log_likelihood_f64` | 2-class multinomial NB on count vectors; class 0 dominant for [10, 0, 0] |
| `ml_recover_bernoulli_nb_joint_log_likelihood_f64` | 2-class Bernoulli NB on binary features; class 0 dominant for [1, 0] |
| `ml_recover_knn_1nn_distances_f64` | distances-only path: query at training point → distance 0 |
| `ml_recover_knn_1nn_indices_i64` | nearest-index-only path: query at row 1 → index 1 |

The Naive Bayes joint log likelihood functions all recover (gaussian/multinomial/bernoulli per ML-22, ML-30) — the failure mode for NB *predict* (ML-22) was specifically the argmax-over-classes step, not the joint-likelihood computation. Same pattern for KNN: distances and indices recover; *predict* (label lookup with majority vote across k neighbors) did not.

## Cumulative recovery surface (after ML-18..30): 47 capabilities

End of finding.
