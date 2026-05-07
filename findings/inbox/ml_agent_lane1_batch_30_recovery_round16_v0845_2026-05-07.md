# ML Suite recovery smokes round 16 — Queue ML-33

Branch: fix/ml-33-batch-30-recovery-round16-v0845
Date: 2026-05-07

## Headline

**1/3 stable**: KMeans inertia. The two NB predict_proba candidates failed — refines the diagnostic that **normalization steps over multi-class log-likelihood vectors** trip the UB even though raw joint-log-likelihood works.

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **1/3** |

## Ship-ready (1)

| Smoke | Surface |
|---|---|
| `ml_recover_kmeans_inertia_f64` | scalar inertia (sum of squared distances to nearest center) — 0 for on-center points; 25 for (3,4) vs centers at origin |

## Failed (2)

| Smoke | Why |
|---|---|
| `ml_recover_multinomial_nb_predict_proba_f64` | normalization (max-subtract / exp / sum / divide) over the joint log-likelihood vector — same multi-step state UB pattern as Gaussian NB predict |
| `ml_recover_gaussian_nb_predict_proba_f64` | same as above; even though `gaussian_nb_joint_log_likelihood_f64` recovered (ML-22), the predict_proba normalization step does not |

This refines the recovery rule: **NB joint log-likelihood recovers, but the post-normalization step (log-sum-exp + exp) does not** — that's a separate kernel inside the rod that has the multi-step state UB.

## Cumulative recovery surface (after ML-18..33): 54 capabilities

End of finding.
