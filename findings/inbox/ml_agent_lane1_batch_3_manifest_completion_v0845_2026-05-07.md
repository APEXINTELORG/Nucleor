# ML Suite manifest-tier completion — Queue ML-6

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: fix/ml-6-batch-3-manifest-tier-completion-v0845 (stacks on fix/ml-5-batch-2-manifest-tier-facades-v0845 @ 0753ad88)
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`
Predecessor: `findings/inbox/ml_agent_lane1_batch_2_manifest_facades_v0845_2026-05-07.md` (Queue ML-5)

## 1. Headline

Lands the **remaining 12 manifest-tier (Tier-B) facades** identified in ML-2: 7 master-tree contract surfaces (bench / sbom / port / hf / tabular / ml_health / rod_registry) plus 5 mainline-only backend-integration contracts (experiment / gguf / onnx / tune / vllm). Combined with ML-5's 10, this completes the **22-facade Phase-6/7 contract surface** for the v1 product wedge.

| | Count | Detail |
|---|---:|---|
| Rods integrated | 12 | under `stdlib/rods/ml/` |
| Smokes added | 12 | under `tests/features/ml_*_smoke.nr` |
| Manifest delta | 275 → 287 rods | +12, +48 fns, +1,298 LOC |
| Drift gate | clean | all `OK:` lines pass |
| Smoke pass rate | 12/12 across 5 runs | deterministic, zero PANICs |

## 2. Per-rod summary

| Source path | Destination | LOC | fn count | Smoke fixture | Build | Run (5) |
|---|---|---:|---:|---|---:|---:|
| `master/src/bench_facade.nr` | `stdlib/rods/ml/bench_facade.nr` | 110 | 2 | `tests/features/ml_bench_facade_smoke.nr` | 0 | 5/5 |
| `master/src/sbom_facade.nr` | `stdlib/rods/ml/sbom_facade.nr` | 102 | 2 | `tests/features/ml_sbom_facade_smoke.nr` | 0 | 5/5 |
| `master/src/port_facade.nr` | `stdlib/rods/ml/port_facade.nr` | 96 | 2 | `tests/features/ml_port_facade_smoke.nr` | 0 | 5/5 |
| `master/src/hf_facade.nr` | `stdlib/rods/ml/hf_facade.nr` | 102 | 2 | `tests/features/ml_hf_facade_smoke.nr` | 0 | 5/5 |
| `master/src/tabular_facade.nr` | `stdlib/rods/ml/tabular_facade.nr` | 100 | 2 | `tests/features/ml_tabular_facade_smoke.nr` | 0 | 5/5 |
| `master/src/ml_health_facade.nr` | `stdlib/rods/ml/ml_health_facade.nr` | 95 | 2 | `tests/features/ml_health_facade_smoke.nr` | 0 | 5/5 |
| `master/src/rod_registry_facade.nr` | `stdlib/rods/ml/rod_registry_facade.nr` | 96 | 2 | `tests/features/ml_rod_registry_facade_smoke.nr` | 0 | 5/5 |
| `mainline/src/experiment_facade.nr` | `stdlib/rods/ml/experiment_facade.nr` | ~100 | ~2 | `tests/features/ml_experiment_facade_smoke.nr` | 0 | 5/5 |
| `mainline/src/gguf_facade.nr` | `stdlib/rods/ml/gguf_facade.nr` | ~110 | ~2 | `tests/features/ml_gguf_facade_smoke.nr` | 0 | 5/5 |
| `mainline/src/onnx_facade.nr` | `stdlib/rods/ml/onnx_facade.nr` | ~110 | ~2 | `tests/features/ml_onnx_facade_smoke.nr` | 0 | 5/5 |
| `mainline/src/tune_facade.nr` | `stdlib/rods/ml/tune_facade.nr` | ~100 | ~2 | `tests/features/ml_tune_facade_smoke.nr` | 0 | 5/5 |
| `mainline/src/vllm_facade.nr` | `stdlib/rods/ml/vllm_facade.nr` | ~120 | ~2 | `tests/features/ml_vllm_facade_smoke.nr` | 0 | 5/5 |

All 12 smokes were copied from their respective trees with `import "src/..."` rewritten. Manifest-only smokes are inline-literal and self-contained — no fixture relocation needed. Canonical `// rods/ml/<name> — <description>` headers prepended for clean rod-manifest population.

## 3. Cumulative ML rod surface (after ML-4 + ML-5 + ML-6)

| Tier | Rods | Source |
|---|---:|---|
| Tier-S cross-cutting cores | 5 | dtype_core, shape_core, parity_manifest, tensor_facade, math_facade |
| Tier-A entry facades | 5 | learn, stats, nn, ai, boost |
| Tier-B Phase-6/7 contracts | 22 | capsule, ncap, backend, cli, lab, cert, contract, model_io, serve, ship, bench, sbom, port, hf, tabular, ml_health, rod_registry, experiment, gguf, onnx, tune, vllm |
| **Total ML rods at canonical** | **32** | (255 prior + 32 ML = 287 manifest total) |

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

```
$ ./target/gen_rod_manifest.exe
Wrote docs/rfcs/rod_manifest.toml
Total rods: 287       (was 275 after ML-5)
Total fn: 3688
Total LOC: 22900
Without description: 0
```

12/12 builds clean. 12/12 smokes run deterministic across 5 consecutive runs each (all final lines `{"kind":"status","passed":true}`).

## 5. Round-4+ guidance (revised after ML-6 closes Tier-B)

| Round | Branch | Items | Notes |
|---|---|---:|---|
| **ML-7** | `fix/ml-7-batch-4-data-facade-v0845` | `data_facade.nr` + 1 hand-authored smoke | Round-up Tier-S core that depended on fixture relocation. |
| **ML-8** | `fix/ml-8-batch-5-fixture-relocation-v0845` | Copy `examples/fixtures/` → `tests/features/ml_fixtures/`; no rod changes | Prerequisite for ML-9..ML-14 parity-rod batches. ~95KB of CSV/binary fixture files. |
| ML-9 | `fix/ml-9-batch-6-sklearn-parity-rods-v0845` | 41 sklearn parity rods | After ML-7+ML-8. |
| ML-10 | `fix/ml-10-batch-7-pytorch-parity-rods-v0845` | 22 PyTorch nn parity rods | After ML-8. |
| ML-11 | `fix/ml-11-batch-8-transformer-parity-rods-v0845` | 23 transformer/AI parity rods | After ML-8. |
| ML-12 | `fix/ml-12-batch-9-numpy-parity-rods-v0845` | 14 NumPy tensor parity rods | After ML-8. |
| ML-13 | `fix/ml-13-batch-10-boosting-parity-rods-v0845` | 8 XGBoost/LightGBM/CatBoost parity rods | After ML-8. |
| ML-14 | `fix/ml-14-batch-11-scipy-stats-parity-rods-v0845` | 5 SciPy parity rods + 1 print-typing fix | After ML-8 + 6-LOC `print(<f64\|i64>)` rename in `scipy_stats_ttest_f64.nr`. |
| ML-15+ | `fix/ml-N-batch-K-parallelagent-pandas-v0845` | ~75 ParallelAgent-tree pandas-deep parity rods | After ML-7 + ML-8. |

## 6. Residuals / blockers

- **None blocking ML-6 promotion.** All 12 build clean, all run deterministically across 5 consecutive runs, drift gate clean, manifest regenerated successfully with 0 missing descriptions.
- **Tools change from ML-4 still required for promotion.** The `tools/gen_rod_manifest.nr` subdir-recursion update is load-bearing for all ML-5/ML-6 manifest entries.
- **Mainline-tree facades absorbed cleanly.** No additional porting work was needed for the 5 backend-integration contracts (experiment/gguf/onnx/tune/vllm) beyond the standard import rewrite. They build and run identically to their master counterparts.

## 7. Files changed (delta from ML-5)

```
M  docs/rfcs/rod_manifest.toml      # regenerated (12 new ml/ rods registered)
A  stdlib/rods/ml/bench_facade.nr
A  stdlib/rods/ml/sbom_facade.nr
A  stdlib/rods/ml/port_facade.nr
A  stdlib/rods/ml/hf_facade.nr
A  stdlib/rods/ml/tabular_facade.nr
A  stdlib/rods/ml/ml_health_facade.nr
A  stdlib/rods/ml/rod_registry_facade.nr
A  stdlib/rods/ml/experiment_facade.nr
A  stdlib/rods/ml/gguf_facade.nr
A  stdlib/rods/ml/onnx_facade.nr
A  stdlib/rods/ml/tune_facade.nr
A  stdlib/rods/ml/vllm_facade.nr
A  tests/features/ml_bench_facade_smoke.nr
A  tests/features/ml_sbom_facade_smoke.nr
A  tests/features/ml_port_facade_smoke.nr
A  tests/features/ml_hf_facade_smoke.nr
A  tests/features/ml_tabular_facade_smoke.nr
A  tests/features/ml_health_facade_smoke.nr
A  tests/features/ml_rod_registry_facade_smoke.nr
A  tests/features/ml_experiment_facade_smoke.nr
A  tests/features/ml_gguf_facade_smoke.nr
A  tests/features/ml_onnx_facade_smoke.nr
A  tests/features/ml_tune_facade_smoke.nr
A  tests/features/ml_vllm_facade_smoke.nr
A  findings/inbox/ml_agent_lane1_batch_3_manifest_completion_v0845_2026-05-07.md
```

End of finding.
