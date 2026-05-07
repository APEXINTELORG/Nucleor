# ML Suite build-plan + spec inventory — Queue ML-2

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: probe/ml-2-build-plan-spec-inventory-v0845
Base: origin/main @ 46e4fa5 + 2 commits (auto-fast-forwarded)
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`
Predecessor: `findings/inbox/ml_agent_lane1_inventory_v0845_2026-05-07.md` (Queue ML-1)

## 1. Documents read (sources)

Read end-to-end (master tree at `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite\`):

| Doc | Bytes | Status |
|---|---:|---|
| `SPEC.md` (v0.1 draft, 2026-04-25) | 27,205 | committed |
| `docs/IMPLEMENTATION_PLAN.md` | 76,xxx | committed |
| `docs/PYTHON_PARITY_MAP.md` | 28,xxx | committed |
| `docs/NUCLEOR_LANGUAGE_FEEDBACK.md` | 30,xxx | committed |
| `docs/NUCLEOR_LANGUAGE_FEEDBACK_RESPONSE.md` | — | dirty (modified, unstaged) — read both states |
| `docs/STRATEGIC_REVIEW_2026-04-25.md` (Opus pressure-test) | — | untracked on disk |
| `docs/NUCLEOR_TRANSLATE_SPEC2_TASK2_RESPONSE.md` | — | untracked on disk |
| `examples/python_parity/README.md` | — | committed |
| `README.md` | 2,548 | committed |

Also sampled mainline tree (`Nucleor_ML_Suite_ParallelAgent_Mainline\docs\`):
- `EXPERIMENT_TUNING_RUNTIME_SPEC.md`
- `ONNX_GGUF_RUNTIME_SPEC.md`
- `NUCLEOR_WORLD_CLASS_LANGUAGE_ROADMAP_2026-04-27.md`

`rods/README.md` was not read because `rods/` is empty in all three trees (the directory exists, the README is the only file). The `.nr` library content lives entirely under `src/` (facades + cores) and `examples/<area>_mvp/` (parity rods + smoke fixtures). This is a structural observation worth carrying forward when ML-3/ML-4 talks about "rods to integrate."

## 2. Suite product thesis (one-paragraph distillation)

Native, rod-powered replacement path for the Python scientific/ML stack. v1 wedge is **native inference + reproducible capsules + a `nuc lab/serve/port/bench/ship/capsule/cert` user-facing CLI surface**. NumPy/pandas/scikit-learn/PyTorch parity is migration evidence and compatibility coverage, not the product. Capsule format `.ncap` is the reproducibility envelope (manifest + source/data/model/compiler/rod-graph hashes + tolerance + audit log + signing). Honest performance posture: numeric parity proven, speed claims gated on backend dispatch (BLAS/oneDNN/cuBLAS/cuDNN/GGML Tier A) + benchmark surface (`nuc bench`). Cert profile (deterministic, locked dependency graph, audit/provenance manifest) is a long-term wedge into regulated industries.

## 3. Phase status matrix (master IMPLEMENTATION_PLAN.md, plus mainline-only additions)

| Phase | Status | Key evidence on disk | Outstanding work in this phase | Ship-ready surface today |
|---|---|---|---|---|
| **Phase 0 — Repo seed** | started | SPEC.md, plan, parity map, README, fixture layout | none for the OSS integration scope | n/a (meta-phase) |
| **Phase 1 — Tensor core facade** | **substantially shipped** | TensorF64/F32/I64 with shape+dtype+accumulator+policy metadata; matmul, broadcast, reductions, slicing, transpose, reshape, mean, variance, argmax all NumPy-parity-passing; CSV ingest f64 (decimal) and i64; matvec parity | output hashes once stable; native typed Vec<f32> revisit (workaround currently uses Vec<i64> bit-pattern); batched matmul; dynamic-tensor loader | **YES — `src/tensor_facade.nr`, `src/dtype_core.nr`, `src/shape_core.nr`, `src/parity_manifest.nr`, `tests/tensor_core_smoke.nr`** |
| **Phase 1.5 — Kernel backend / benchmark** | started | parity manifests carry `claim_scope=numeric_parity_only`, backend label, external-backend count, generated-exe size, stdout size; volatile wall-time path | actual BLAS/oneDNN/cuBLAS dispatch wiring; speed-claim gate | partial (manifest infrastructure, not dispatch) — defer wiring to integrator |
| **Phase 1.6 — Type-level shapes** | runtime-only | `nuc_shape_dtype_contract_smoke` JSONL evidence with `compile_time_shape_assertion_count = 0`; `SHAPE_DTYPE_CONTRACT_SPEC.md` pins boundary | compile-time `Tensor<T, [B, T, C]>` syntax (Nucleor-language work) | runtime contract **YES**; compile-time **DEFER** (language work) |
| **Phase 2 — DataFrame core** | started | `FrameI64F64` + nullable variant, typed CSV ingest, groupby sum/mean, inner-join, filter+project, dropna/fillna/mean — pandas-parity-passing on those slices | generalize beyond i64/f64; left/right/outer joins; multi-column tensor convert; ParallelAgent tree adds 75+ pandas parity rods that should fold in here | **YES — narrow i64/f64 surface today. Broader pandas parity from ParallelAgent tree extends this in subsequent batches.** |
| **Phase 3 — Classical ML** | started, very deep | 60+ parity rods: StandardScaler, MinMaxScaler, MaxAbsScaler, Normalizer, Binarizer, SimpleImputer, OneHot, Ordinal, Label, ColumnTransformer, PolynomialFeatures (deg2, deg3), Linear/Ridge/Lasso/ElasticNet, Logistic (binary + multiclass), LinearSVC, RBF SVC, GaussianNB/MultinomialNB/BernoulliNB, KNN (1nn, 3nn uniform + distance-weighted, predict_proba), KMeans, PCA, DecisionTreeClassifier, KFold/StratifiedKFold/GroupKFold/LeaveOneOut indices, accuracy_score, log_loss, precision/recall/F1/ROC AUC, multiclass precision_recall_fscore_support, train_test_split | shuffled stratification, repeated CV, configurable polynomial degrees, in-place SVM/tree fitting (currently fitted-state-only), tree export helpers | **YES — sklearn parity is the largest ship-ready surface in the suite (~50 rods)** |
| **Phase 4 — Neural network MVP** | started, deep | ~44 PyTorch parity rods: linear forward+backward, ReLU/GELU(tanh)/SiLU forward+backward, LayerNorm fwd/bwd with affine, RMSNorm, MSE/L1/NLL/CrossEntropy/BCE-with-logits forward+backward, log_softmax, sigmoid; SGD, SGD+momentum, AdamW state; full single-step + multi-step training-loop parity for 2-layer ReLU + cross-entropy | richer module API (`nn::Module`); checkpoint format; reverse-mode autograd vs hand-rolled backward; dataloader | **YES — PyTorch parity rods (~40 rods) are ship-ready** |
| **Phase 5 — LLM inference MVP** | started, deep | 60+ AI/transformer rods: scaled dot-product attention (causal+non-causal), multi-head attention, KV-cache append + cached attention, RoPE pairs, RMSNorm, SwiGLU FFN, LayerNorm/MLP transformer block, **complete pre-LN decoder layer**, embedding+lm_head greedy step, **2-step autoregressive generate loop**, temperature softmax, top-k, top-p (nucleus), categorical sample, append/last-token; Hugging Face manifest, char-level tokenizer + stdlib BPE wrapper; serve manifest | safetensors loader, GGUF loader, ONNX loader, quantized matmul wired to runtime, streaming generation hooked to `nuc serve` | **YES — transformer/decode rods are ship-ready as a parity-flavored LLM kernel library**; loaders + serve runtime are mainline-tier (gguf/onnx/vllm facades) and ship as **MANIFEST-only contracts** for now |
| **Phase 6 — Capsule runtime** | started, very deep | CapsuleManifest + `capsule_manifest_smoke` (JSONL records, deterministic outputs, Python-side SHA-256 verifier); ncap_facade + `ncap_package_manifest_smoke`; `tools\build_ncap_manifest.py` builds `tiny_decoder_fixture.ncap.json` end-to-end; `ncap_diff.py`/`ncap_verify.py` working; `agent_trace.py` deterministic trace records; `tools\python_to_nucleor_port.py` migration planner; `tools\build_claim_ledger.py` evidence-bound claims | move SHA-256/artifact-hashing from Python verifier into Nucleor runtime; real signing/verification; weight-payload diff; native trace capture from real tool events | **YES — capsule manifest .nr surface is ship-ready; .py harness stays as REFERENCE per project rule (no Python in product/toolchain).** |
| **Phase 7 — NucleorLab Workbench** | manifest-tier | lab_facade + `nuc_lab_manifest_smoke` (cell graph, viewer counts, agent mount count, port, no-Python-bridge accounting); cli_facade (`nuc new/add/lab/bench/port/capsule/serve/ship`); cert_facade (unsigned cert profile); rod_registry_facade (lockfile, transitive deps, offline replay); model_io_facade (.ncap/GGUF/safetensors/ONNX/tokenizer formats); ship_facade (packaging contract); ml_health_facade (preflight); bench_facade (telemetry, `speed_claim_enabled=0`); sbom_facade (supply chain inventory); port_facade (`nuc port` planner); contract_facade (shape/dtype boundary); hf_facade (Hugging Face local-first); tabular_facade (Arrow/Polars/DuckDB) | actual TUI/GUI implementation; deterministic cell graph runtime; agent panel; plot viewer | **YES — all 14 facades are ship-ready as MANIFEST + CONTRACT surfaces**; runtime/GUI deferred |
| **Phase 8 (mainline-only) — Backend integration manifests** | not in master plan | Mainline adds 5 facades + 5 smokes for backend-integration tier: `experiment_facade.nr` (experiment tracking), `gguf_facade.nr` (GGUF loader contract), `onnx_facade.nr` (ONNX loader contract), `tune_facade.nr` (hyperparameter tuning), `vllm_facade.nr` (vLLM serving contract). All five are MANIFEST-only at this stage | actual loader/runtime impl | **YES (mainline-tier) — 5 manifest facades + 5 smokes integrate alongside Phase 7 facades** |

Total identified ship-ready library item count across phases (intersection of "exists in source" + "API stable per spec docs" + "build-clean expected"): **~150-180 rods** (subject to ML-3 build-clean confirmation).

## 4. Python parity coverage matrix (from PYTHON_PARITY_MAP.md)

| Python library family | Parity rods on disk (master + mainline) | Ship-readiness assessment |
|---|---:|---|
| **NumPy** (`np.array/zeros/ones/full`, broadcasting, slicing, matmul, reductions, linalg, random) | 13 passing parity cases | **HIGH** — foundation surface; covers Phase 1 wedge |
| **SciPy / statsmodels** (`stats.describe`, `cov`, `pearsonr`, `zscore`, `quantile/median/iqr`, `min/max/argmin/argmax`, `rankdata`, `histogram`, normal PDF/CDF, `ttest_1samp`, Welch t) | 6 passing parity cases | **HIGH** — `scipy_stats_*_f64` rods are clean wrappers around stats_facade.nr |
| **pandas** (`read_csv`, `groupby`, `merge`, filter/project, nullable) | 4 master + 75+ ParallelAgent extensions | **HIGH for narrow i64/f64; broader cumsum/cumprod/cummax/cummin/diff/abs/clip/expanding/groupby variants from PA tree fold in Round 2+** |
| **Arrow / Polars / DuckDB** (schema, lazy frame, pushdown, SQL, CSV/Parquet/IPC) | 1 manifest case (`nuc_tabular_manifest_smoke`) | **MEDIUM** — manifest-only contract today; runtime impl deferred |
| **scikit-learn** (estimator API, Pipeline, preprocessing, model selection, metrics, models, KMeans, PCA, NB, KNN, trees, SVM, polynomial features, encoders) | **42 passing parity cases** | **HIGH** — largest ship-ready surface in the suite |
| **XGBoost / LightGBM / CatBoost** (stump ensemble, multi-depth tree traversal, missing-value routing, multiclass softmax, categorical splits, sparse CSR, leaf-index, decision-path, contributions) | 8 passing parity cases | **HIGH** — fitted-state inference path complete; model-file loaders deferred |
| **PyTorch** (`torch.Tensor`, autograd, `nn.Module`, optimizers, dataloader) | 22 passing parity cases | **HIGH** — covers full forward/backward + 2 optimizer steps incl. AdamW state |
| **Capsule / Reproducibility** (run metadata, artifact hashes, model registry, env lock, repro build) | 2 passing parity cases (jsonl + capsule manifest) + 5+ ncap workflow tools | **HIGH (manifest tier)** — Python tools are REFERENCE only per project rule |
| **Transformers / Hugging Face** (tokenizer, `from_pretrained`, safetensors, generate, KV cache, quantization) | 27 passing parity cases (incl. complete decoder layer + 2-step autoregressive generate) | **HIGH** — modeled as manifest contract + parity rod cluster |
| **MLflow / W&B / DVC / Nix** (run metadata, artifact store, model registry, data versioning, env lock, repro build) | manifest-tier (capsule + ncap) | **MEDIUM** — folded into capsule subsystem |

## 5. Ship-ready short list (preliminary, pending ML-3 build confirmation)

This list is the recommended **first integration pass** after ML-3 triage. It prioritizes (i) cross-cutting cores that the rest of the suite depends on, (ii) parity-rod families with the deepest implementation evidence, and (iii) manifest-tier facades that ship as production-grade contracts even though their runtime impls land later.

### Tier S (ship FIRST — cross-cutting cores; everything else imports from these)

1. `src/dtype_core.nr` — dtype tags, accumulator policy, numeric policy (strict/fast/mixed/quantized/cert).
2. `src/shape_core.nr` — `Shape2 { rows, cols }` runtime shape model.
3. `src/parity_manifest.nr` — parity-claim metadata (suite/case/surface/dtype/shape/policy/seed/input/output, `claim_scope=numeric_parity_only`, backend label).
4. `src/tensor_facade.nr` — `TensorF64 / TensorF32 / TensorI64` with matmul/broadcast/reductions/slicing/transpose/reshape/argmax/mean/variance + CSV ingest.
5. `src/math_facade.nr` — typed `f64` elementary math bridge to `stdlib/rods/math_typed.nr` (sqrt/exp/log/tanh/sin/cos/pow). **Verification needed: NUC-FEEDBACK-011's "import-only-emits-unresolved-special-fn-symbols" must be re-tested on canonical compiler 0.8.323; if fixed upstream, the facade can import math_typed directly.**

### Tier A (ship NEXT — deepest parity rod families)

6. `src/learn_facade.nr` + 30+ sklearn parity rods under `examples/learn_mvp/sklearn_*.nr` — preprocessing (StandardScaler/MinMax/MaxAbs/Normalizer/Binarizer/SimpleImputer/OneHot/Ordinal/Label/ColumnTransformer/PolynomialFeatures), classifiers (Logistic binary+multiclass, LinearSVC, RBF SVC, GaussianNB/MultinomialNB/BernoulliNB, KNN 1/3/weighted, DecisionTreeClassifier), regression (Linear/Ridge/Lasso/ElasticNet), clustering (KMeans, PCA), model selection (KFold/StratifiedKFold/GroupKFold/LeaveOneOut, train_test_split), metrics (accuracy/log_loss/precision/recall/F1/ROC AUC/multiclass precision_recall_fscore_support).
7. `src/nn_facade.nr` + 22 PyTorch parity rods under `examples/nn_mvp/torch_*.nr` — `linear`, `relu`, `gelu(tanh)`, `silu`, `layer_norm`, `rms_norm`, `mse_loss`, `l1_loss`, `nll_loss`, `cross_entropy`, `bce_with_logits` (forward + backward where applicable), `sgd_step`, `sgd_momentum`, `adamw_step` (with full state), single-step + multi-step training-loop parity.
8. `src/ai_facade.nr` + 27 AI/transformer parity rods under `examples/ai_mvp/torch_*.nr` — scaled-dot-product attention (causal+non-causal, single + multi-head), KV-cache append + cached attention, RoPE pairs, embedding + lm_head greedy + sample step, temperature softmax + top-k + top-p + categorical sample, complete decoder layer (LayerNorm + MultiHeadAttn + LayerNorm + FFN + residual), 2-step autoregressive generation loop.
9. `src/stats_facade.nr` + 6 SciPy parity rods under `examples/stats_mvp/scipy_*.nr` — describe/quantile/rank-extrema/histogram/normal-distribution/ttest.
10. `src/boost_facade.nr` + 8 boosting parity rods under `examples/boost_mvp/{xgboost,lightgbm,catboost}_*.nr` — stump ensemble, multi-depth tree traversal w/ missing-value routing, multiclass softmax, categorical splits, sparse CSR, leaf-index, decision-path, contributions.
11. `src/data_facade.nr` + 4 pandas parity rods under master `examples/data_mvp/pandas_*.nr` (groupby/inner-join/filter-project/nullable). **Round 2** picks up the 75+ extended PA-tree pandas rods (cumsum/cumprod/cummax/cummin/diff/abs/clip/expanding/groupby variants).
12. `src/text_facade.nr` + `src/tokenizer_facade.nr` + 2 parity rods (`python_char_tokenizer_i64`, `stdlib_tokenizer_i64`) — char-level tokenizer + stdlib BPE wrapper.

### Tier B (ship as MANIFEST-tier contracts — runtime/GUI deferred)

13. `src/capsule_facade.nr` + `src/ncap_facade.nr` + `capsule_manifest_smoke` + `ncap_package_manifest_smoke` — capsule + .ncap package contracts.
14. `src/lab_facade.nr` + `nuc_lab_manifest_smoke` — `nuc lab` workbench contract.
15. `src/cli_facade.nr` + `nuc_cli_manifest_smoke` — unified `nuc` front-door.
16. `src/cert_facade.nr` + `nuc_cert_profile_smoke` — unsigned certification profile.
17. `src/rod_registry_facade.nr` + `nuc_rod_registry_manifest_smoke` — `nuc add` lockfile.
18. `src/model_io_facade.nr` + `nuc_model_io_manifest_smoke` — `nuc serve` model loader contract (.ncap/GGUF/safetensors/ONNX/tokenizer formats).
19. `src/ship_facade.nr` + `nuc_ship_manifest_smoke` — `nuc ship` packaging contract.
20. `src/ml_health_facade.nr` + `nuc_ml_health_manifest_smoke` — preflight/health-check contract.
21. `src/bench_facade.nr` + `nuc_bench_manifest_smoke` — telemetry contract (speed_claim_enabled=0).
22. `src/sbom_facade.nr` + `nuc_sbom_manifest_smoke` — supply-chain inventory.
23. `src/port_facade.nr` + `nuc_port_manifest_smoke` — `nuc port` migration planner contract.
24. `src/contract_facade.nr` + `nuc_shape_dtype_contract_smoke` — runtime shape/dtype contract.
25. `src/hf_facade.nr` + `nuc_hf_manifest_smoke` — Hugging Face local-first frontend.
26. `src/tabular_facade.nr` + `nuc_tabular_manifest_smoke` — Arrow/Polars/DuckDB engine contract.
27. `src/serve_facade.nr` + `nuc_serve_manifest_smoke` — `nuc serve` package contract.
28. `src/backend_facade.nr` + `nuc_backend_manifest_smoke` — backend dispatch accounting contract.
29. **Mainline-only (5 additional facades + 5 smokes):** `experiment_facade.nr`, `gguf_facade.nr`, `onnx_facade.nr`, `tune_facade.nr`, `vllm_facade.nr` + their `nuc_*_manifest_smoke.nr` smokes.

### Tier C (defer — Round 2+ batches)

- 75+ ParallelAgent-tree pandas rods (`pandas_cumsum_i64_f64`, etc.) — fold into Tier A item #11 once base data_facade is integrated.
- 30+ master-tree sklearn extensions that build on the Tier A item #6 base (specific encoders, fold-index variants).
- 10 capsule_mvp manifest variants from PA tree (`capsule_artifact_manifest_smoke`, `capsule_device_manifest_smoke`, etc.) — extend Tier B item #13.

## 6. Language-feedback log status (relevance to integration)

The 11 language-feedback findings + 7 improvements were filed against compiler versions **v0.2.0-v2 → v0.3.191** (the ML Suite was originally built on those). Current canonical compiler on `Nucleor_OSS @ origin/main` is **`nucleor 0.8.323 (self-hosted, llvm backend)`** — far past every closure point. Re-validation status (informational — full re-test is ML-3 work):

| Finding | Original status | Closure point | Re-validation likely needed during ML-3 |
|---|---|---|---|
| NUC-FEEDBACK-001: `nuc test` harness divergence | open at filing | not closed in log | **YES — confirm `nuc test tests/tensor_core_smoke.nr` matches `nuc run` on 0.8.323** |
| NUC-FEEDBACK-002: `Vec<f32>` returns zeros | open (workaround active: `Vec<i64>` bit patterns) | partial fix v0.3.119 (diagnostic only); deeper type-prop still queued | **YES — try direct `Vec<f32>` matmul on 0.8.323; if fixed, the `TensorF32` workaround simplifies** |
| NUC-FEEDBACK-003: clang PATH detection | closed v0.3.119 | closed | likely fine on 0.8.323; sandbox builds confirm |
| NUC-FEEDBACK-004: `stdlib/rods/jsonl.nr` external-import resolution | closed v0.3.122 (fixture t399) | closed | confirmed clean from sandbox build of `tensor_core_smoke.nr` (which imports parity_manifest, which uses jsonl indirectly) |
| NUC-FEEDBACK-005/006: high-precision f64 decimal literals lower to zero | closed v0.3.130 | closed | likely fine on 0.8.323 |
| NUC-FEEDBACK-007: source cache stale-hit on literal-only edits | open (workaround: `--no-cache`) | not stated | suite verifier already uses `--no-cache` paths; not blocking integration |
| NUC-FEEDBACK-008: dynamically-assembled-string print termination | open (workaround: print tensors only) | not stated | not critical for integration; rod content avoids this pattern |
| NUC-FEEDBACK-009: post-emit/no-compiled transient on long verifier runs | open (workaround: 3-retry policy) | not stated | not blocking integration; integration uses focused `bin/nucleor build` per fixture |
| NUC-FEEDBACK-010: unresolved struct-field type errors emit invalid LLVM (`%r.-1`) | open (workaround: rename `static_*` → `ct_*`) | not stated | low risk for integration; rod code already uses workaround naming |
| NUC-FEEDBACK-011: `stdlib/rods/math_typed.nr` import emits unresolved `f64_betainc`/etc. when wrappers are unused | open (workaround: `math_facade.nr` doesn't import math_typed; wraps primitives directly) | not stated | **YES — confirm whether 0.8.323's `math_typed.nr` has all wrappers backed; if so, `math_facade.nr` can be simplified to use math_typed directly. This affects Tier S item #5.** |
| NUC-IMPROVE-001/002/003 (JSONL schema, typed tensor, JSONL spec) | accepted/proposed | mostly closed via stdlib jsonl rod | n/a |
| NUC-IMPROVE-004: `f64_from_bits` reinterpret helper | closed v0.3.125 | closed | available on 0.8.323; rod code already adopted it |
| NUC-IMPROVE-005: typed elementary math (sqrt/exp/log/tanh/sin/cos/pow) | closed v0.3.127 | closed | available via stdlib/rods/math_typed.nr; pending NUC-FEEDBACK-011 retest |
| NUC-IMPROVE-006: tokenizer rod opaque token-vector access | accepted; suite-local char tokenizer in place | partial closure — current canonical `stdlib/rods/tokenizer.nr` has been overhauled per RFC; ML-3 must check API match | **YES — `stdlib_tokenizer_i64.nr` must build clean against current canonical tokenizer rod** |
| NUC-IMPROVE-007: typed special functions for exact stats p-values (erf/lgamma/incomplete-beta/Student-t SF) | proposed | partial in canonical (`stdlib/rods/math_typed_special.nr` exists per smoke probe) | **YES — confirm `scipy_stats_ttest_f64` builds against canonical math_typed_special** |

**One additional language-side issue surfaced during ML-1's smoke probe of `examples/learn_mvp/sklearn_kmeans_predict_f64.nr`** that needs separate calling out:

- The compiler's parser interprets `&raw` (where `raw` is a local variable name) as the start of raw-pointer syntax `&raw const` / `&raw mut`, which is V1-removed. Two occurrences in `src/learn_facade.nr` (lines 1395 and 1452) where a local `let raw: TensorF64 = …; while i < tensor_f64_len(&raw) { … }` pattern triggers the "raw-ref syntax not in V1" panic. **This is a Nucleor-language parser ambiguity, not removed user-side syntax** — `raw` is being treated as a contextual keyword. Mitigation is mechanical: rename the local from `raw` to `r` or `tmp` (≤5 LOC per occurrence). Bucket B in ML-3 terms. Also look for the same pattern across the union (`fn .*\(.*raw[,):]` returns 4 hits in master src/data_facade.nr and src/tensor_facade.nr — those are parameter names, not `&raw` references, so they likely don't trigger; ML-3 will confirm per-file).

## 7. Strategic-review reconciliation (from STRATEGIC_REVIEW_2026-04-25.md)

The strategic review identifies 7 SPEC-vs-code gaps. None of them block library integration; they shape **product framing and Round-2+ priorities**. Summary:

| Strategic-review concern | Affects ML-2 ship list? | How |
|---|---|---|
| Dtype list is aspirational (19 enum values, 1 real) | No | We ship `dtype_core.nr` AS-IS — it documents the future surface and provides V1-priority dtype helpers (f64/f32/i64/bf16/i4/qint8) that are actually exercised. The "future" enum integers stay. |
| Performance claims missing Tier A backend dispatch | No | `parity_manifest.nr` already records `claim_scope=numeric_parity_only`. Backend wiring is integrator-tier work (compiler-adjacent). |
| Static shape system underbuilt (`Shape2` 2D-only) | No | Ship the runtime `Shape2` + parity rods, since the SPEC's compile-time `Tensor<T, [B, T, C]>` is Nucleor-language work for V1+. |
| No tensor views/strides | No | Ships AS-IS as a parity-flavored library. Future view/stride support is a Nucleor-stdlib concern (`stdlib/rods/tensor_nd.nr` already exists at the canonical layer). |
| Hand-rolled `nn_*_backward_f64` per op (not autograd) | No | The parity rods are useful AS-IS as PyTorch-equivalence evidence; canonical autograd is a separate roadmap. |
| Notebook/Workbench/GUI doesn't exist | No | Manifest-tier contracts ship; runtime/GUI are deferred. |
| Honest speed claims | No | Same as backend-dispatch row. |

## 8. Folder choice (carried forward from ML-1)

**Confirmed: option (a)** — `stdlib/rods/ml/<canonical_name>.nr` (nested under existing `stdlib/rods/`). Reasoning unchanged from ML-1 §6. ML-2 reading reinforces this: the suite's namespace is consistently `nuc::tensor / nuc::data / nuc::learn / nuc::nn / nuc::ai / nuc::lab / nuc::math / nuc::viz / nuc::capsule / nuc::interop` — a clean fit under `stdlib/rods/ml/` with the existing flat-file convention.

## 9. Counts summary for ML-3

| Quantity | Value |
|---|---:|
| Phases on disk (master) | 7 (+1 mainline-only Phase 8) |
| Phase status: substantially shipped | Phase 1, partially Phase 2/3/4/5/6/7 (manifest tier) |
| NumPy passing parity cases | 13 |
| SciPy passing parity cases | 6 |
| pandas passing parity cases (master) | 4 |
| pandas extensions (PA tree, Round 2+) | ~75 |
| sklearn passing parity cases | 42 |
| XGBoost/LightGBM/CatBoost cases | 8 |
| PyTorch passing parity cases | 22 |
| Transformers/HF passing parity cases | 27 |
| Capsule/reproducibility cases | 2 (+ harness tools) |
| Tier S ship-ready cores | 5 |
| Tier A ship-ready parity rod families | 7 |
| Tier B manifest-tier facades (master + mainline) | 17 + 5 = 22 |
| **First-pass ML-4 candidate count (Tier S + small Tier A subset)** | 10 (per ML_Control1 ML-4 contract) |

## 10. ML-3 triage prep (to scope before launching individual builds)

Before ML-3 starts pairwise build-clean checks, the following pre-work will sharpen the triage:

1. **Pre-grep for `&raw` references (where `raw` is a local).** Already done: 2 occurrences in `src/learn_facade.nr`. Bucket B at the file level (the file is otherwise clean, but cannot build without the rename).
2. **Pre-grep for `import "stdlib/rods/math_typed.nr"`.** 21 master-tree files. Bucket dependencies on NUC-FEEDBACK-011 retest.
3. **Pre-build `tests/tensor_core_smoke.nr` (already done in ML-1) — bucket A confirmed.** This is the canonical "core import path works" smoke; if it fails on a future canonical-compiler bump, the entire integration is blocked.
4. **Confirm `stdlib/rods/jsonl.nr`, `stdlib/rods/math_typed.nr`, `stdlib/rods/strings.nr`, `stdlib/rods/tokenizer.nr` all exist on canonical** — done in ML-1 sandbox; all four present.
5. **Determine ML-4 first-batch composition.** Recommended: ship the 5 Tier-S cores + 5 Tier-A entry rods = 10 items. The 5 entry rods should be the simplest member of each Tier-A family (one each from learn/nn/ai/stats/boost), to validate the integration shape without overcommitting.

### Recommended ML-4 batch composition (10 items)

**Tier S (5):**
1. `stdlib/rods/ml/dtype_core.nr` ← `src/dtype_core.nr`
2. `stdlib/rods/ml/shape_core.nr` ← `src/shape_core.nr`
3. `stdlib/rods/ml/parity_manifest.nr` ← `src/parity_manifest.nr`
4. `stdlib/rods/ml/tensor_facade.nr` ← `src/tensor_facade.nr`
5. `stdlib/rods/ml/math_facade.nr` ← `src/math_facade.nr`

**Tier A (5 entry rods, simplest member of each family):**
6. `stdlib/rods/ml/learn_facade.nr` (with `&raw`-rename fix already applied) ← `src/learn_facade.nr`
7. `stdlib/rods/ml/stats_facade.nr` ← `src/stats_facade.nr`
8. `stdlib/rods/ml/nn_facade.nr` ← `src/nn_facade.nr`
9. `stdlib/rods/ml/ai_facade.nr` ← `src/ai_facade.nr`
10. `stdlib/rods/ml/boost_facade.nr` ← `src/boost_facade.nr`

Smoke fixtures (one per item, under `tests/features/`):
- `tests/features/ml_tensor_facade_smoke.nr` ← derived from `tests/tensor_core_smoke.nr` (already build-clean)
- (and one each for the 9 others; minimal `main()` that exercises the canonical entry point)

`rod_manifest.toml` regen via `bin/nucleor build tools/gen_rod_manifest.nr -o gen_rod_manifest && ./target/gen_rod_manifest`.

## Residuals / blockers

- **None for ML-3 startup.** All preparatory data is in this finding plus ML-1.
- **For ML-4:** the `&raw`/local-variable parser ambiguity in `src/learn_facade.nr` lines 1395 + 1452 is a known mechanical fix (rename local `raw` to `r` or `tmp`). Two LOC per occurrence. Documenting it here so ML-4 doesn't re-discover it.
- **For ML-5+:** the 75 PA-tree pandas extensions and the 30+ sklearn extensions (all bucket A or B) form Round-2 batches once the Tier-S cores are integrated.
- **Manifest-tier facades (Tier B, 22 items):** these can ship in a single bulk batch since they have no cross-dependencies beyond `parity_manifest.nr` and `dtype_core.nr` (Tier S). Probably ML-5 or ML-6.

End of finding.
