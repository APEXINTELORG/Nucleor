# PROBE-2 design ROOT CAUSE — Nucleor has no sklearn-compatible fit APIs

- **Date:** 2026-05-08
- **Agent:** ML
- **Branch:** `ml-probe-2-pipeline-parity-v0846`
- **Base:** `origin/main @ 194f3c84` (post-DFLIP-PATCH)

## Headline

The PROBE-2 spec (ML_Control1.md 18:50 EDT entry, reaffirmed 00:30 EDT) describes 4 multi-stage pipelines with the shape "CSV ingest → train/test split → fit → predict → emit JSON." The Python references shipped at `e348e67f`/`5a7882c9`/`42e189b6`/`c2378b3e` follow that shape exactly using sklearn DecisionTreeClassifier / LinearRegression / KMeans / BernoulliNB.

**The Nucleor side cannot replicate "fit" byte-equal.** Inspection of `stdlib/rods/ml/learn_facade.nr` on `origin/main @ 194f3c84` shows:

- `decision_tree_classifier_f64(...)` is a **constructor** taking pre-fitted tree parameters (node_left_indices, node_right_indices, node_feature_indices, node_thresholds, node_values, classes). No `decision_tree_classifier_fit_*`.
- `linear_model_f64(weights, bias)` — same shape. No `linear_regression_fit`.
- `kmeans_f64(centers)` — same shape. No `kmeans_f64_fit`.
- `bernoulli_nb_f64(feature_log_prob, class_log_prior, classes)` — same. No `bernoulli_nb_fit`.

`grep -nE "^fn (decision_tree_classifier_fit|linear_regression_fit|kmeans_f64_fit|bernoulli_nb_fit|linear_model_fit)" stdlib/rods/ml/learn_facade.nr` returns 0 lines.

Nucleor's existing `learn_facade` contract is **inference-only on pre-fitted parameters**, not end-to-end fit-from-data.

## Why byte-equal-fit isn't achievable even if fit APIs existed

Two independent reasons:

1. **RNG divergence:** sklearn `train_test_split(..., random_state=42)` uses numpy's `MT19937` permutation-shuffle. Nucleor's `train_test_split_indices_seeded(n, k, seed)` uses an internal LCG (linear congruential generator). Different RNG → different train/test partition → different fitted parameters → different predictions.

2. **Algorithm divergence:** sklearn's DecisionTreeClassifier fit uses Gini-impurity split selection with sklearn-specific tie-breaking, MIN_SAMPLES_LEAF defaults, and sub-feature-sampling order. Replicating bit-exactly in Nucleor would require re-implementing sklearn internals — unrealistic and out-of-scope.

## Design correction (executed in this branch)

The PROBE-2 spec's "byte-equal to Python reference" intent is preserved by **shifting the parity boundary to inference**:

1. **Python reference** does the full pipeline (ingest, split, fit, predict, dump JSON). The JSON now ALSO emits the fitted parameters (tree structure / weights / centers / log-priors) so Nucleor can consume them.
2. **Nucleor probe** ingests the SAME holdout data (inline) AND the fitted parameters (hardcoded inline from running the Python reference). It does **predict-only** using existing Nucleor inference APIs (`decision_tree_classifier_predict_i64`, `linear_model_f64_predict`, `kmeans_f64_predict`, `bernoulli_nb_predict_i64`).
3. **Byte-equal acceptance** is on the PREDICT-related JSON fields (y_pred, accuracy, r2_score, labels, etc.) — not on the fit. The reference's parameter section serves as the "truth" the Nucleor probe consumes.

This:
- Keeps the spec's parity-rigor intent (Nucleor and Python emit byte-equal predict outputs on the same data + same fitted params).
- Aligns with Nucleor's actual inference-only contract.
- Is honestly achievable on current main without any compiler / API extensions.
- Documents the fit boundary as a known scope deferral (a future Nucleor `*_fit_*` API tier could close it).

## Action plan (executing in this branch)

1. Update each reference `<NN>_<task>.py` to ALSO dump fitted parameters under a `"params"` JSON key (or per-case keys: `"tree_left_indices"`, `"tree_right_indices"`, etc.).
2. Re-generate each `<NN>_<task>.json` to include the `params` section.
3. Add `stdlib/rods/ml/probes/pipeline_<NN>_<task>.nr` consuming the inline data + hardcoded params + emitting predict-only JSON.
4. Verify hook (`NUC_VERIFY_ML_PROBE=1`) compares Nucleor probe output vs the reference's predict-related fields, byte-equal within parity-manifest tolerance.
5. The `params` section in the reference JSON serves as both:
   - The source-of-truth for the Nucleor probe's hardcoded parameters (re-run the reference + paste params into the .nr if sklearn version ever rolls forward).
   - Documentation of the fit step that Nucleor doesn't do.

## Out of scope (not blocking PROBE-2 closure)

- Future `*_fit_*` API tier for Nucleor: tracked separately as a Nucleor-language enhancement RFC. PROBE-2 ships before that lands.
- Bit-exact RNG parity with numpy MT19937: tracked separately if/when fit APIs land.

## Honest residual

If a future spec author intended PROBE-2 to require Nucleor-side fit, this finding flags that the goal is currently impossible and proposes the design correction. If they intended inference-only parity all along, this finding documents the path I'm executing. Either way, the divergence between "spec text" and "current Nucleor capability" is surfaced rather than papered over.

End of finding.
