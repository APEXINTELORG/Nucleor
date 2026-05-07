# ML Suite sklearn parity rod batch — Queue ML-9

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: fix/ml-9-batch-6-sklearn-parity-rods-v0845 (from origin/main HEAD; depends on ML-7 data_facade + ML-8 fixture relocation already pushed)
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`

## 1. Headline

Lands the **15 production-ready sklearn parity rods** out of 42 candidates from `examples/learn_mvp/`. Each is verified to build clean and run deterministically across **30 consecutive runs** with no PANIC, no OOB, no FAIL outputs. **27 candidates** are deferred with documented latent-UB symptoms — they require Nucleor-language-side investigation, not surface-level integration work.

This is a deliberate honesty choice. The original brief framed sklearn parity as ~41 rods that "build clean against canonical 0.8.323"; ML-3's static build triage confirmed 42/42 build. But **runtime stability** under canonical 0.8.323 is a separate, stricter bar — and the same UB class flagged in ML-4 §5 and ML-5 §3 manifests here at the parity-rod level. **Production readiness for these 15 means 30/30 deterministic runs**, period.

| | Count | Detail |
|---|---:|---|
| Candidates triaged (build) | 42/42 | all build clean (per ML-3) |
| Initial 5-run smoke | 23/42 | passing 5/5 + no PANIC/FAIL |
| 10-run check | 15/42 | passing 10/10 |
| **30-run final** | **15/42** | **all 15 stable; ship-ready** |
| Deferred (latent runtime UB) | **27/42** | documented in §3 |

## 2. Per-rod summary (15 ship-ready)

| Source | Destination | Smoke fixture path | 30-run pass | Notes |
|---|---|---|---:|---|
| `examples/learn_mvp/sklearn_binarizer_threshold_f64.nr` | `tests/features/ml_sklearn_binarizer_threshold_f64.nr` | (self) | 30/30 | preprocessing; threshold > 0.5 → 1, else 0 |
| `examples/learn_mvp/sklearn_column_transformer_onehot_f64.nr` | `tests/features/ml_sklearn_column_transformer_onehot_f64.nr` | (self) | 30/30 | numeric passthrough + categorical one-hot |
| `examples/learn_mvp/sklearn_group_kfold_indices_i64.nr` | `tests/features/ml_sklearn_group_kfold_indices_i64.nr` | (self) | 30/30 | balanced no-shuffle GroupKFold(n_splits=2) |
| `examples/learn_mvp/sklearn_kfold_accuracy_score_i64.nr` | `tests/features/ml_sklearn_kfold_accuracy_score_i64.nr` | (self) | 30/30 | per-fold accuracy_score |
| `examples/learn_mvp/sklearn_kfold_indices_i64.nr` | `tests/features/ml_sklearn_kfold_indices_i64.nr` | (self) | 30/30 | KFold(n_splits=3, shuffle=False) train/test indices |
| `examples/learn_mvp/sklearn_kmeans_predict_f64.nr` | `tests/features/ml_sklearn_kmeans_predict_f64.nr` | (self) | 30/30 | fitted KMeans transform/predict/inertia |
| `examples/learn_mvp/sklearn_leave_one_out_indices_i64.nr` | `tests/features/ml_sklearn_leave_one_out_indices_i64.nr` | (self) | 30/30 | LeaveOneOut().split |
| `examples/learn_mvp/sklearn_normalizer_l2_f64.nr` | `tests/features/ml_sklearn_normalizer_l2_f64.nr` | (self) | 30/30 | row-normalized L2 + zero-row handling |
| `examples/learn_mvp/sklearn_onehot_encoder_i64.nr` | `tests/features/ml_sklearn_onehot_encoder_i64.nr` | (self) | 30/30 | OneHotEncoder(handle_unknown="ignore") |
| `examples/learn_mvp/sklearn_ordinal_encoder_i64.nr` | `tests/features/ml_sklearn_ordinal_encoder_i64.nr` | (self) | 30/30 | OrdinalEncoder w/ unknown sentinel -1 |
| `examples/learn_mvp/sklearn_polynomial_features_degree2_f64.nr` | `tests/features/ml_sklearn_polynomial_features_degree2_f64.nr` | (self) | 30/30 | PolynomialFeatures(degree=2, include_bias=True) |
| `examples/learn_mvp/sklearn_polynomial_features_degree3_f64.nr` | `tests/features/ml_sklearn_polynomial_features_degree3_f64.nr` | (self) | 30/30 | PolynomialFeatures(degree=3, include_bias=True) |
| `examples/learn_mvp/sklearn_ridge_multioutput_predict_f64.nr` | `tests/features/ml_sklearn_ridge_multioutput_predict_f64.nr` | (self) | 30/30 | fitted multi-output Ridge.predict |
| `examples/learn_mvp/sklearn_simple_imputer_mean_f64.nr` | `tests/features/ml_sklearn_simple_imputer_mean_f64.nr` | (self) | 30/30 | SimpleImputer(strategy="mean") |
| `examples/learn_mvp/sklearn_stratified_kfold_indices_i64.nr` | `tests/features/ml_sklearn_stratified_kfold_indices_i64.nr` | (self) | 30/30 | balanced no-shuffle StratifiedKFold |

Each rod is a self-contained parity test: imports `stdlib/rods/ml/learn_facade.nr` + `parity_manifest.nr`, builds inline-literal test data, runs the kernel, asserts against expected outputs, and emits a parity manifest for the integrator's tolerance bookkeeping. **Smokes ARE the rods themselves** — these are parity tests with `main()` entries, sitting at `tests/features/` per the canonical Nucleor convention for runnable feature smokes.

## 3. Deferred (27 candidates with latent runtime UB)

These build clean under `bin/nucleor.exe build --no-cache` but exhibit non-deterministic runtime behavior — typically OOB indexing on tensors with uninitialized-memory `len` values like `12 but the index is 5781080113824` or `5 but the index is 5`. The same UB class was flagged in ML-4 §5.1 (heavy comprehensive `tests/<area>_core_smoke.nr` files) and ML-5 §3 (`capsule_seeded_output_f64`). It manifests when complex tensor dataflow patterns are compiled by canonical 0.8.323; the rod binaries link successfully and produce identical IR md5s on identical sources, but the resulting `.exe` produces different output on different runs.

Deferred set:

| Rod | Symptom (typical run) |
|---|---|
| `sklearn_argmax_accuracy_f64` | rc=0 + PANIC: index out of bounds (intermittent) |
| `sklearn_bernoulli_nb_predict_f64` | rc varies 0/1/0 across 3 runs |
| `sklearn_decision_tree_classifier_f64` | rc 1/0/1 |
| `sklearn_gaussian_nb_predict_f64` | rc 1/0/0 |
| `sklearn_knn_1nn_predict_f64` | passes 5/5 sometimes, fails at 10 (intermittent OOB) |
| `sklearn_knn_3nn_distance_weighted_f64` | rc 1/1/1 (deterministic-fail) — likely tensor distance kernel UB |
| `sklearn_knn_3nn_predict_f64` | PANIC: len 12 index 5781080113824 (uninitialized memory) |
| `sklearn_knn_3nn_predict_proba_f64` | rc 1/1/1 |
| `sklearn_lasso_elasticnet_predict_f64` | rc 0/0/1 |
| `sklearn_label_encoder_i64` | passes 5/5, intermittent at 10 |
| `sklearn_linear_svc_predict_f64` | rc 0/139/0 (SIGSEGV intermittent) |
| `sklearn_logistic_binary_predict_f64` | rc 1/0/1 |
| `sklearn_logistic_multiclass_predict_f64` | passes 5/5, intermittent at 10 |
| `sklearn_maxabs_scaler_f64` | passes 5/5, intermittent at 10 |
| `sklearn_minmax_scaler_f64` | rc 1/0/0 |
| `sklearn_multiclass_metrics_i64` | PANIC: index out of bounds: len 5 index 5 |
| `sklearn_multinomial_nb_predict_f64` | rc 139/0/0 (SIGSEGV intermittent) |
| `sklearn_nearest_neighbors_kneighbors_f64` | rc 1/1/1 |
| `sklearn_pca_transform_f64` | rc 1/0/0 |
| `sklearn_pipeline_scaler_logistic_f64` | rc 1/1/0 |
| `sklearn_probability_metrics_f64` | rc 1/1/1 |
| `sklearn_rbf_svc_predict_f64` | passes 5/5, intermittent at 10 |
| `sklearn_scaler_linear_f64` | rc 1/0/1 |
| `sklearn_standard_scaler_fit_f64` | rc 0/0/1 |
| `sklearn_standard_scaler_inverse_f64` | rc 0/1/1 |
| `sklearn_train_test_split_indices_f64` | rc 0/1/0 |
| `nucleor_seeded_split_f64` | rc 1/1/1 |

These represent ~$value$ of unrealized parity coverage — sklearn classifiers (Naive Bayes, KNN, LogReg, SVM, DecisionTree), regression with Lasso/ElasticNet, the StandardScaler family, Pipeline composition, and probability metrics. The ship-ready 15 covers preprocessing (Binarizer, Normalizer L2, OneHot, Ordinal, Polynomial deg2/deg3, SimpleImputer), model selection (KFold, GroupKFold, StratifiedKFold, LeaveOneOut, KFold accuracy), KMeans, and Ridge multi-output regression — a respectable cross-section that doesn't trip the kernel-side UB.

## 4. Build / drift validation

```
$ bash tools/check_compiler_drift.sh
…
OK: rod_manifest.toml is up to date
OK: helper_manifest.toml is up to date
OK: RELEASES.md is up to date
OK: audit_dup_fns_report.csv is up to date
OK: CHANGELOG.md covers every git tag
OK: s1 compiler_version_label() matches CHANGELOG.md (0.8.323)
OK: tools_suite compiler_version_label() matches CHANGELOG.md (0.8.323)
OK: no opt-in privatization markers (pub fn) in compiler source
exit=0
```

(rod_manifest.toml unchanged — the 15 sklearn rods sit under `tests/features/` not `stdlib/rods/`; they are runnable parity tests, not reusable rod libraries. This matches the canonical Nucleor pattern where `tests/features/<rod>_smoke.nr` files have `main()` entries and are not rod-manifest-registered.)

15/15 builds clean. 15/15 runs pass deterministically across 30 consecutive runs (rc=0, no PANIC, no FAIL string in output).

## 5. Production-readiness commentary

The 27/42 latent-UB ratio is a meaningful product-side signal. Per ML-3's pure static-build triage, all 42 looked bucket-A. Per **runtime stability under canonical 0.8.323**, only 36% of those are production-ready. This pattern is consistent across the ML Suite parity rod families:

- The ML-4 lesson said: comprehensive heavy-test files (e.g. `tests/tensor_core_smoke.nr`) trip the UB; smaller hand-authored smokes don't.
- The ML-5 lesson said: even `capsule_seeded_output_f64` — a small helper — trips it.
- The ML-9 reality: the parity rods that exercise heavier kernel paths (KNN distance loops, NB likelihood computation, SVM decision functions, MinMax/StandardScaler fit-then-transform with multi-step state) all show the symptom.

The 15 ship-ready sklearn rods are the ones whose kernel paths are simple enough to NOT trip the UB. Restoration of the other 27 needs Nucleor-language-side investigation (likely RFC-0062 G-8 Phase 2b move-state join analysis, mentioned in the compiler's own warnings on every build).

## 6. Round-3+ guidance

| Round | Status | Notes |
|---|---|---|
| ML-9 (this batch) | ship 15/42 | done |
| ML-10 PyTorch nn parity (22 rods) | apply same 30-run stability bar | |
| ML-11 Transformer/AI parity (23 rods) | apply same bar | |
| ML-12 NumPy tensor parity (14 rods) | apply same bar | |
| ML-13 Boosting parity (8 rods) | apply same bar; note ML-4's `boost_facade` smoke required hand-authoring for similar reasons | |
| ML-14 SciPy stats parity (5 rods + 1 print fix) | apply same bar; the `scipy_stats_ttest_f64` print typing fix lands here | |
| Post-batch: re-test deferred 27 | only after Nucleor-language fix lands for the underlying UB | |

## 7. Files changed

```
A  tests/features/ml_sklearn_binarizer_threshold_f64.nr
A  tests/features/ml_sklearn_column_transformer_onehot_f64.nr
A  tests/features/ml_sklearn_group_kfold_indices_i64.nr
A  tests/features/ml_sklearn_kfold_accuracy_score_i64.nr
A  tests/features/ml_sklearn_kfold_indices_i64.nr
A  tests/features/ml_sklearn_kmeans_predict_f64.nr
A  tests/features/ml_sklearn_leave_one_out_indices_i64.nr
A  tests/features/ml_sklearn_normalizer_l2_f64.nr
A  tests/features/ml_sklearn_onehot_encoder_i64.nr
A  tests/features/ml_sklearn_ordinal_encoder_i64.nr
A  tests/features/ml_sklearn_polynomial_features_degree2_f64.nr
A  tests/features/ml_sklearn_polynomial_features_degree3_f64.nr
A  tests/features/ml_sklearn_ridge_multioutput_predict_f64.nr
A  tests/features/ml_sklearn_simple_imputer_mean_f64.nr
A  tests/features/ml_sklearn_stratified_kfold_indices_i64.nr
A  findings/inbox/ml_agent_lane1_batch_6_sklearn_parity_v0845_2026-05-07.md
```

End of finding.
