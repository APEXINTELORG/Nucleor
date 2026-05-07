# ML Suite first integration batch — Queue ML-4

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: fix/ml-4-batch-1-bucket-a-rods-v0845
Base: origin/main @ c7a81390
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`
Predecessor: `findings/inbox/ml_agent_lane1_triage_buildclean_v0845_2026-05-07.md` (Queue ML-3)

## 1. Headline

Landed **5 Tier-S cross-cutting cores + 5 Tier-A entry facades** at `stdlib/rods/ml/`, plus **10 self-contained smoke fixtures** at `tests/features/ml_*_smoke.nr`, plus **the rod-manifest scanner update needed to register subdirectory rods**, plus the **`&raw`-on-local rename in `learn_facade.nr`** that unblocks the Round-2 sklearn parity batch.

| | Count | Detail |
|---|---:|---|
| Rods integrated | 10 | under `stdlib/rods/ml/` |
| Smokes added | 10 | under `tests/features/ml_*_smoke.nr` |
| Tools changed | 1 | `tools/gen_rod_manifest.nr` (subdir recursion) |
| Source `.nr` lines added (rods + tools) | ~7,400 | mostly the 10 facade copies |
| Source `.nr` lines added (smokes) | ~570 | hand-authored, self-contained |
| Manifest delta | 255 → 265 rods | +10, +373 fns, +6,639 LOC |
| Drift gate | clean | all `OK:` lines pass; pre-existing RFC-0063 Phase 2.0 parser-divergence WARNs unchanged |
| Smoke pass rate | 10/10 across 3 runs | deterministic, zero PANICs after fixture-dependency removal (see §6) |

## 2. Per-rod summary

Each rod was copied from `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite\src\<rod>.nr` with `import "src/..."` rewritten to `import "stdlib/rods/ml/..."`. A canonical `// rods/ml/<name> — <description>` header was prepended to the 7 facades that didn't carry one in the source so the rod-manifest description column populates cleanly.

| Source path | Destination | LOC | fn count | Smoke fixture | Per-build exit | Per-run exit (3 runs) |
|---|---|---:|---:|---|---:|---:|
| `src/dtype_core.nr` | `stdlib/rods/ml/dtype_core.nr` | 126 | 14 | `tests/features/ml_dtype_core_smoke.nr` | 0 | 0,0,0 |
| `src/shape_core.nr` | `stdlib/rods/ml/shape_core.nr` | 44 | 1 | `tests/features/ml_shape_core_smoke.nr` | 0 | 0,0,0 |
| `src/parity_manifest.nr` | `stdlib/rods/ml/parity_manifest.nr` | 62 | 2 | `tests/features/ml_parity_manifest_smoke.nr` | 0 | 0,0,0 |
| `src/tensor_facade.nr` | `stdlib/rods/ml/tensor_facade.nr` | 795 | 60 | `tests/features/ml_tensor_facade_smoke.nr` | 0 | 0,0,0 |
| `src/math_facade.nr` | `stdlib/rods/ml/math_facade.nr` | 23 | 4 | `tests/features/ml_math_facade_smoke.nr` | 0 | 0,0,0 |
| `src/learn_facade.nr` (+ `&raw` rename) | `stdlib/rods/ml/learn_facade.nr` | 2980 | 127 | `tests/features/ml_learn_facade_smoke.nr` | 0 | 0,0,0 |
| `src/stats_facade.nr` | `stdlib/rods/ml/stats_facade.nr` | 522 | 29 | `tests/features/ml_stats_facade_smoke.nr` | 0 | 0,0,0 |
| `src/nn_facade.nr` | `stdlib/rods/ml/nn_facade.nr` | 778 | 31 | `tests/features/ml_nn_facade_smoke.nr` | 0 | 0,0,0 |
| `src/ai_facade.nr` | `stdlib/rods/ml/ai_facade.nr` | 853 | 37 | `tests/features/ml_ai_facade_smoke.nr` | 0 | 0,0,0 |
| `src/boost_facade.nr` | `stdlib/rods/ml/boost_facade.nr` | 1169 | 45 | `tests/features/ml_boost_facade_smoke.nr` | 0 | 0,0,0 |

All builds done with `bin/nucleor.exe build <fixture> -o <out> --no-cache`. All runs done from a clean target/ directory.

## 3. Tools change: `tools/gen_rod_manifest.nr` subdir recursion

The original scanner at `tools/gen_rod_manifest.nr` lines 240-260 walked only top-level `stdlib/rods/*.nr`, so rods placed under `stdlib/rods/ml/` would not have appeared in `docs/rfcs/rod_manifest.toml`. The change:

- Factored the per-directory scan into a helper `fn scan_rods_dir(...)` that takes a directory prefix and the parallel arrays.
- The top-level scan calls the helper with `"stdlib/rods"`. If `fs_is_dir("stdlib/rods/ml")` is true, the helper is called again with `"stdlib/rods/ml"`. The second call appends to the same parallel arrays, then the existing TOML emit code consumes the merged set unchanged.
- New subdirs are added explicitly (one named conditional check per subdir) rather than via blind recursion. This keeps the scanner's behavior auditable and prevents accidentally picking up unrelated subdirectories under `stdlib/rods/`.

Compatibility:

- Round-trip on the canonical 255-rod top-level set produces a byte-identical `rod_manifest.toml` (verified: `diff /tmp/rod_manifest.before.toml docs/rfcs/rod_manifest.toml` → empty diff before adding ml/ rods).
- After ml/ rods land: 265 rods, 3597 fns, 20654 LOC, **0 missing descriptions**.

The scanner change is in `.nr` tool source, not in `bin/nucleor.exe` or `bootstrap/nucleor_s1_seed.ll`. It does not require a self-host re-bootstrap. It is integrator-promoted in the same branch as the rod batch since they're load-bearing together.

## 4. Source-side `&raw`-on-local rename in `stdlib/rods/ml/learn_facade.nr`

ML-3 §3 B.1 surfaced this as the single fix that unblocks 44 cascading consumer files. Two function-scoped changes (`linear_model_f64_predict` lines 1392-1399 and `logistic_binary_f64_decision_function` lines 1449-1456):

```diff
-    let raw: TensorF64 = tensor_f64_matvec(x, &model.weights);
+    let mv: TensorF64 = tensor_f64_matvec(x, &model.weights);
     let mut data: Vec<f64> = Vec::new();
     let mut i: i64 = 0;
-    while i < tensor_f64_len(&raw) {
-        data.push(raw.data[i] + model.bias);
+    while i < tensor_f64_len(&mv) {
+        data.push(mv.data[i] + model.bias);
         i = i + 1;
     };
-    return tensor_f64_from_vec(raw.shape.rows, raw.shape.cols, data);
+    return tensor_f64_from_vec(mv.shape.rows, mv.shape.cols, data);
```

Identical pattern in both functions. Total: 8 lines changed (4 lines × 2 occurrences). Renamed `raw` → `mv` ("matvec result"). Function semantics identical.

This rename is what makes `ml_learn_facade_smoke` build and run clean in this batch (transitively confirming `learn_facade.nr` itself), and what unblocks Round-2 integration of all 41 `examples/learn_mvp/sklearn_*.nr` parity rods.

## 5. Smoke fixture design (production-readiness)

Initial attempt: copy the existing `tests/<area>_core_smoke.nr` files from the master suite and rewrite imports. This **failed runtime validation** for 6 of 10 derived smokes — a critical surface that warrants explicit documentation.

### 5.1 — Why the derived approach failed

The derived smokes panicked at runtime with index-out-of-bounds on Vecs of length 0 (or non-deterministic negative lengths indicating uninitialized memory). Root cause: the existing master-suite tests were written assuming **the ML Suite's `examples/fixtures/` directory was on disk**. For example, `tests/tensor_core_smoke.nr` line 270 calls:

```nr
let t: TensorF64 = tensor_f64_from_csv_f64("examples/fixtures/tensor_2x3_f64.csv", 2, 3, 1);
```

When that path does not exist (which it doesn't in `Nucleor_OSS`), the function returns a zero-shape tensor, and subsequent indexing immediately PANICs. The non-determinism in the PANIC's reported `len` value (e.g. `len -1507524962` then `len 0` then `len 2` across runs) was misleading — it pointed at memory uninitialization, but the actual cause was just an empty-result-handle being indexed.

This was investigated by:
- Running the original `xgboost_stump_ensemble_predict_f64.nr` from the master tree against the same canonical compiler 0.8.323. It panicked with the same shape — confirming this is fixture-dependency, not a regression caused by our integration.
- Comparing IR md5 (identical: `3603eb09...`) and .exe md5 (identical: `9b5b3edd...`) between the master-tree run and our smoke. Same compiled binary, same panic surface.

### 5.2 — Production-ready replacement: hand-authored, fixture-free

The 10 smokes shipped in this batch are all hand-authored, self-contained:

- `ml_dtype_core_smoke.nr` — exercises 5 dtype size assertions, 3 accumulator-policy assertions, 1 policy-distinctness check.
- `ml_shape_core_smoke.nr` — 6 `shape2(rows, cols)` field round-trips (zero, small, large).
- `ml_parity_manifest_smoke.nr` — 5 manifest field round-trips + emit.
- `ml_math_facade_smoke.nr` — sqrt(0)/sqrt(4), exp(0), log(1), log/exp round-trip.
- `ml_tensor_facade_smoke.nr` — 2x2 matmul (matches NumPy [[19,22],[43,50]]), row broadcast add, axis-0 reduction, transpose 2x3→3x2, reshape 2x3→3x2.
- `ml_learn_facade_smoke.nr` — linear-model predict (`y = X @ w + b` matches expected [[2.0],[3.5]]), Lasso/ElasticNet alias the linear path. **This smoke specifically exercises the formerly-blocking `&raw`-on-local code path** (now `mv`).
- `ml_nn_facade_smoke.nr` — `nn_linear_f64` (PyTorch `y = x @ W^T + b` convention with hand-computed expected [-1.4, -2.55]), `nn_relu_f64` (negative→0, positive pass-through).
- `ml_ai_facade_smoke.nr` — `ai_greedy_next_token_i64` (argmax), batched 2-row argmax, `ai_last_token_i64` (`tokens[:, -1:]`), `ai_append_next_token_i64` (concat new column).
- `ml_stats_facade_smoke.nr` — mean=3, variance ddof=0 = 2.0, ddof=1 = 2.5, std² = var, Pearson r = +1 for y=2x+1, r = -1 for y=-x.
- `ml_boost_facade_smoke.nr` — fitted 3-stump ensemble predict_margin and predict_proba; output shape + monotonicity (probabilities in (0, 1)).

Smokes all run deterministically across 3 consecutive runs (rc=0, expected `OK <name>` line).

### 5.3 — Fixture-availability blocker for Round-2

Round-2 integration of the 41 sklearn parity examples + 22 PyTorch parity examples + 23 transformer parity examples + 14 NumPy parity examples + 8 boosting parity examples (105 total) **will require fixture relocation** because most of those examples read from `examples/fixtures/<file>.csv`. Three options:

- **(a)** Copy the entire `examples/fixtures/` directory from master into `tests/features/ml_fixtures/` and rewrite the in-source paths.
- **(b)** Refactor each parity rod to use inline literal Vec initialization instead of CSV ingestion.
- **(c)** Add a `tests/features/ml_fixtures/` symlink to a single canonical location, mirroring how the master tree organizes fixtures.

**Recommendation:** **(a)** — fixture copying. It preserves the parity rods unmodified (they remain truthful migration evidence), keeps file sizes manageable (`examples/fixtures/` in master is ~95KB), and gives downstream Round-2 work a single mechanical step rather than per-rod refactoring.

This is integrator-decision-required for ML-5 onward; not a blocker for this ML-4 batch since the smokes here are fixture-free.

## 6. Build / drift validation

```
$ bash tools/check_compiler_drift.sh
…
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: promoted compiler version matches source (0.8.323)
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
OK: audit_dup_fns_report.csv is up to date
OK: CHANGELOG.md covers every git tag
OK: s1 compiler_version_label() matches CHANGELOG.md (0.8.323)
OK: tools_suite compiler_version_label() matches CHANGELOG.md (0.8.323)
OK: no opt-in privatization markers (pub fn) in compiler source
exit=0
```

Pre-existing RFC-0063 Phase 2.0 `parse_expr` divergence WARNs are unchanged from origin/main and not introduced by this batch.

```
$ bin/nucleor build tools/gen_rod_manifest.nr -o gen_rod_manifest --no-cache
… compiled: target\gen_rod_manifest.exe
$ ./target/gen_rod_manifest.exe
Wrote docs/rfcs/rod_manifest.toml
Total rods: 265
Total fn: 3597
Total LOC: 20654
Without description: 0
```

Per-fixture builds (10 of 10 succeeded; full output captured in agent local logs):

```
OK build ml_dtype_core_smoke
OK build ml_shape_core_smoke
OK build ml_parity_manifest_smoke
OK build ml_math_facade_smoke
OK build ml_tensor_facade_smoke
OK build ml_learn_facade_smoke
OK build ml_nn_facade_smoke
OK build ml_ai_facade_smoke
OK build ml_stats_facade_smoke
OK build ml_boost_facade_smoke
```

Per-fixture runs (10 of 10 succeeded across 3 consecutive runs each, deterministic `rc=0` and expected `OK <name>` final line):

```
$ for r in 1 2 3; do for f in ml_*_smoke; do ./target/$f.exe | tail -1; done; done
…
ml_dtype_core_smoke      OK ml_dtype_core_smoke    (×3 runs)
ml_shape_core_smoke      OK ml_shape_core_smoke    (×3 runs)
ml_parity_manifest_smoke OK ml_parity_manifest_smoke (×3 runs)
ml_math_facade_smoke     OK ml_math_facade_smoke   (×3 runs)
ml_tensor_facade_smoke   OK ml_tensor_facade_smoke (×3 runs)
ml_learn_facade_smoke    OK ml_learn_facade_smoke  (×3 runs)
ml_nn_facade_smoke       OK ml_nn_facade_smoke     (×3 runs)
ml_ai_facade_smoke       OK ml_ai_facade_smoke     (×3 runs)
ml_stats_facade_smoke    OK ml_stats_facade_smoke  (×3 runs)
ml_boost_facade_smoke    OK ml_boost_facade_smoke  (×3 runs)
```

## 7. Round-2+ guidance for next agent

Subsequent batches (ML-5 onward) should build on this foundation:

| Round | Branch | Items | Prerequisite |
|---|---|---:|---|
| ML-5 | `fix/ml-5-batch-2-sklearn-parity-rods-v0845` | 41 sklearn parity rods | This batch (`learn_facade.nr` rename) + fixture relocation per §5.3 |
| ML-6 | `fix/ml-6-batch-3-pytorch-parity-rods-v0845` | 22 PyTorch nn parity rods | This batch (`nn_facade.nr` + `tensor_facade.nr` cores) + fixture relocation |
| ML-7 | `fix/ml-7-batch-4-transformer-parity-rods-v0845` | 23 transformer/AI parity rods | This batch (`ai_facade.nr` core) + fixture relocation |
| ML-8 | `fix/ml-8-batch-5-numpy-parity-rods-v0845` | 14 NumPy tensor parity rods | This batch (`tensor_facade.nr`) + fixture relocation |
| ML-9 | `fix/ml-9-batch-6-boosting-parity-rods-v0845` | 8 XGBoost/LightGBM/CatBoost parity rods | This batch (`boost_facade.nr`) + fixture relocation |
| ML-10 | `fix/ml-10-batch-7-scipy-stats-parity-rods-v0845` | 5 SciPy parity rods + 1 print-typing fix | This batch + fixture relocation + the ML-3 §3 B.2 6-LOC `print(<f64\|i64>)` rename |
| ML-11 | `fix/ml-11-batch-8-manifest-tier-facades-v0845` | 14 master + 5 mainline = 19 manifest-tier facades + 19 smokes (Phase 7 Workbench tier) | This batch (Tier-S cores) |
| ML-12 | `fix/ml-12-batch-9-capsule-ncap-v0845` | `capsule_facade.nr`, `ncap_facade.nr` + 3 smokes | This batch + ML-11 |
| ML-13+ | `fix/ml-N-batch-K-parallelagent-pandas-v0845` | ~75 ParallelAgent-tree pandas-deep parity rods | This batch (`tensor_facade.nr` + `data_facade.nr` once integrated) + fixture relocation |

`data_facade.nr` is **deliberately not in this batch** even though it's a Tier-S candidate, because its 9 parity examples in master tests/data_core_smoke.nr also depend on the same fixture-relocation that Round 2+ needs. Defer to ML-11 alongside the manifest-tier batch.

## 8. Residuals / blockers

- **None blocking ML-4 promotion.** All builds clean, all runs deterministic, drift gate clean, manifest regenerated successfully with 0 missing descriptions.
- **For ML-5+:** fixture relocation per §5.3.
- **For ML-10:** the 6-LOC `print(<f64|i64>)` → `print_f64`/`print_i64` rename in `examples/stats_mvp/scipy_stats_ttest_f64.nr` (ML-3 §3 B.2). Single-file change.
- **For Nucleor language team (informational, not blocker):** the `&raw`-on-local-name parser ambiguity flagged in ML-3 §6.2 still exists in 0.8.323. The mechanical fix here is per-occurrence rename. A parser ergonomic improvement (disambiguate `&raw` based on whether `raw` is a binding in scope) would prevent future cases. Not filed as a separate finding — recorded here and in the ML-3 finding for traceability.

## 9. Files changed

```
M  docs/rfcs/rod_manifest.toml      # regenerated by gen_rod_manifest after ml/ subdir scan
M  tools/gen_rod_manifest.nr        # subdir recursion (~110 LOC added, factor + conditional named-subdir scan)
A  stdlib/rods/ml/dtype_core.nr     # 126 LOC, 14 fns
A  stdlib/rods/ml/shape_core.nr     # 44 LOC, 1 fn
A  stdlib/rods/ml/parity_manifest.nr # 62 LOC, 2 fns
A  stdlib/rods/ml/tensor_facade.nr  # 795 LOC, 60 fns
A  stdlib/rods/ml/math_facade.nr    # 23 LOC, 4 fns
A  stdlib/rods/ml/learn_facade.nr   # 2980 LOC, 127 fns (incl. &raw → mv rename)
A  stdlib/rods/ml/stats_facade.nr   # 522 LOC, 29 fns
A  stdlib/rods/ml/nn_facade.nr      # 778 LOC, 31 fns
A  stdlib/rods/ml/ai_facade.nr      # 853 LOC, 37 fns
A  stdlib/rods/ml/boost_facade.nr   # 1169 LOC, 45 fns
A  tests/features/ml_dtype_core_smoke.nr      # 27 LOC
A  tests/features/ml_shape_core_smoke.nr      # 27 LOC
A  tests/features/ml_parity_manifest_smoke.nr # 36 LOC
A  tests/features/ml_math_facade_smoke.nr     # 29 LOC
A  tests/features/ml_tensor_facade_smoke.nr   # 87 LOC
A  tests/features/ml_learn_facade_smoke.nr    # 67 LOC
A  tests/features/ml_nn_facade_smoke.nr       # 72 LOC
A  tests/features/ml_ai_facade_smoke.nr       # 68 LOC
A  tests/features/ml_stats_facade_smoke.nr    # 66 LOC
A  tests/features/ml_boost_facade_smoke.nr    # 90 LOC
A  findings/inbox/ml_agent_lane1_batch_1_integration_v0845_2026-05-07.md  # this finding
```

End of finding.
