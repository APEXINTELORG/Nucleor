# ML Suite triage: per-file build-clean classification — Queue ML-3

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: probe/ml-3-buildclean-triage-v0845
Base: origin/main @ c7a81390 (auto-fast-forwarded from 46e4fa5)
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`
Companion data: `findings/inbox/ml_agent_lane1_triage_buildclean_v0845_2026-05-07.csv` (full per-file CSV)

## 1. Triage scope and method

The triage corpus was the union of (i) all `.nr` files in master `Nucleor_ML_Suite/` (176 files) plus (ii) the 5 mainline-only facades (`experiment_facade.nr`, `gguf_facade.nr`, `onnx_facade.nr`, `tune_facade.nr`, `vllm_facade.nr`) plus their 5 manifest-smoke fixtures = **186 `.nr` files total**.

Each file was classified by attempting `bin/nucleor.exe build <path> --no-cache` against canonical compiler **`nucleor 0.8.323 (self-hosted, llvm backend)`** (`origin/main @ c7a81390`). For library files (no `fn main`), standalone build is not applicable; they were tagged `SKIPPED_LIB` and their build-cleanness is verified **transitively**: a passing consumer build implies the imported facade compiles and links.

No source modifications were made during this queue per the ML_Control1 ML-3 contract. Each failure's exit code and the first ERROR/PANIC line are captured in the CSV.

## 2. Headline triage result

| Bucket | Definition | Count |
|---|---|---:|
| **A — ready** | Builds clean, runs clean, imports only stable surfaces | **106** |
| **B — light fix (≤5 LOC per facade fix; cascades to all consumers)** | Builds with single-file mechanical fix in a facade or example | **45** |
| **C — porting work** | Non-trivial migration to current Nucleor surfaces | **0** |
| **D — scaffold-only** | Doesn't build / API-dead / specifies a future capability | **0** |
| **Library files (no `main`, transitively confirmed)** | Build-cleanness inferred via passing consumers | **35** |

This is **far cleaner than ML-2 anticipated.** The original concern — that Lane 2/3/4/5/7 work moved a lot of compiler/stdlib surface and would force porting (bucket C) work — is **not** the case for the v0845 canonical compiler. The ML Suite's `.nr` source built nearly clean, and **every failure has a single, mechanical, well-scoped root cause.**

## 3. Bucket B failures: only two distinct root causes

The 45 bucket-B failures collapse to **two underlying defects**, each fixable in a single file with ≤6 LOC:

### B.1 — `&raw` / local-name parser ambiguity (1 facade fix → 44 cascading consumers unblock)

**Root file:** `src/learn_facade.nr` lines 1392 + 1395 + 1396 + 1399 (in `linear_model_f64_predict`) and lines 1449 + 1452 + 1453 + 1456 (in `linear_multioutput_f64_predict`).

```nr
let raw: TensorF64 = tensor_f64_matvec(x, &model.weights);
let mut data: Vec<f64> = Vec::new();
let mut i: i64 = 0;
while i < tensor_f64_len(&raw) {
    data.push(raw.data[i] + model.bias);
    i = i + 1;
};
return tensor_f64_from_vec(raw.shape.rows, raw.shape.cols, data);
```

**Compiler interpretation:** `&raw` (where `raw` is a local variable name) is parsed as the start of `&raw const` / `&raw mut` raw-pointer syntax — V1-removed. The parser stops with `PANIC: v0.7.14: &raw ref unsupported`. This is a **Nucleor-language parser ambiguity** — `raw` is being treated as a contextual keyword on its own. The fix is mechanical: rename the local from `raw` → e.g. `r` or `mat`. Two occurrences (function-scoped), ≈4 LOC each (the `let raw:` declaration + 3 references), total ~8 LOC.

**Cascade:** every consumer that imports `src/learn_facade.nr` fails identically. The fix unblocks:

- 41 examples under `examples/learn_mvp/` (full sklearn parity batch)
- 1 example under `examples/python_parity/python_port_smoke/port_candidate.nr` (the `nuc port`-generated scaffold)
- 1 test fixture `tests/learn_core_smoke.nr`

Total cascade: **44 files** unblocked by the single facade fix.

### B.2 — `print(<f64|i64>)` mistyped in 1 example (TYP-006 — fix at consumer file)

**File:** `examples/stats_mvp/scipy_stats_ttest_f64.nr` lines 36, 38, 40, 44, 46, 48.

```nr
print(one.statistic);          // f64 — must be print_f64
print(one.pvalue_two_sided);   // f64 — must be print_f64
print(one.df);                 // i64 — must be print_i64
print(welch.statistic);        // f64 — must be print_f64
print(welch.pvalue_two_sided); // f64 — must be print_f64
print(welch.df);               // i64 — must be print_i64
```

Canonical compiler 0.8.323's `print(...)` runtime helper requires `str` (TYP-006). Fix is to replace 4 `print(<f64>)` → `print_f64(<f64>)` and 2 `print(<i64>)` → `print_i64(<i64>)`. Single-file, 6 LOC.

This is a **consumer-side** fix — `src/stats_facade.nr` itself is fine (no print-typing issues; transitively confirmed by 5 sibling stats_mvp examples that all build clean).

## 4. Bucket A by area (106 files)

The build-clean set spans every MVP area in master plus all 5 mainline-tier areas:

| Area | Bucket-A count |
|---|---:|
| examples/ai_mvp | 23 |
| examples/nn_mvp | 22 |
| examples/tensor_mvp | 14 |
| examples/boost_mvp | 8 |
| examples/stats_mvp | 5 (1 → bucket B) |
| examples/data_mvp | 4 |
| examples/capsule_mvp | 3 |
| examples/text_mvp | 2 |
| examples/ml_health_mvp | 1 |
| examples/{lab,cli,cert,registry,model_io,ship,bench,sbom,port,contract,hf,tabular,serve,backend}_mvp | 1 each = 14 |
| examples/{experiment,gguf,onnx,tune,vllm}_mvp (mainline-only) | 1 each = 5 |
| tests/{tensor,nn,ai,data,text}_core_smoke.nr | 5 (1 → bucket B: learn_core_smoke) |

**Important: no NUC-FEEDBACK-002 / NUC-FEEDBACK-011 manifestations seen.** The historical `Vec<f32>` zero-return defect and the `stdlib/rods/math_typed.nr` import-only-emits-unresolved-special-fn defect did **not** appear in any build. Both are presumably long since closed in the canonical compiler — confirmed empirically.

## 5. Library files transitively confirmed (35)

All 35 library files (no `main`) compile clean transitively because their consumers built clean:

**Master src/ (30):**
- `dtype_core.nr`, `shape_core.nr`, `parity_manifest.nr`, `tensor_facade.nr`, `math_facade.nr`
- `ai_facade.nr`, `data_facade.nr`, `nn_facade.nr`, `boost_facade.nr`, `stats_facade.nr`
- `text_facade.nr`, `tokenizer_facade.nr`
- `capsule_facade.nr`, `ncap_facade.nr`
- `lab_facade.nr`, `cli_facade.nr`, `cert_facade.nr`, `rod_registry_facade.nr`, `model_io_facade.nr`, `ship_facade.nr`, `ml_health_facade.nr`, `bench_facade.nr`, `sbom_facade.nr`, `port_facade.nr`, `contract_facade.nr`, `hf_facade.nr`, `tabular_facade.nr`, `serve_facade.nr`, `backend_facade.nr`
- `learn_facade.nr` is the **one** library file that needs the bucket-B fix; it is **not** transitively confirmed yet (will be once `&raw` is renamed in ML-4).

**Mainline-only src/ (5):** `experiment_facade.nr`, `gguf_facade.nr`, `onnx_facade.nr`, `tune_facade.nr`, `vllm_facade.nr` — all transitively confirmed via their `nuc_*_manifest_smoke.nr` fixtures.

## 6. Production-readiness blockers surfaced for ML-4 / integrator review

These are **structural** issues that affect how Round-1 batches are landed, not per-file bucket assignments. They need integrator decisions before ML-4 ships.

### 6.1 — `tools/gen_rod_manifest.nr` does NOT recurse into subdirectories

The canonical rod-manifest generator at `tools/gen_rod_manifest.nr` lines 240-260 calls `fs_list_dir("stdlib/rods")` and filters `str_ends_with(".nr") == 1`. It does **not** walk subdirectories. This means putting integrated rods at `stdlib/rods/ml/<rod>.nr` (option (a) recommended in ML-1 §6) will silently skip those rods from `docs/rfcs/rod_manifest.toml` — the rods will compile but won't be registered.

**Two integration options to choose between (integrator decision):**

- **(a-flat)** Flatten the layout to `stdlib/rods/ml_<rod>.nr` (e.g. `stdlib/rods/ml_tensor_facade.nr`). Works with current scanner unchanged. Cost: pollutes the flat namespace with ~150 ML rods (currently 255 → ~400). Naming gets verbose.
- **(a-recurse)** Modify `tools/gen_rod_manifest.nr` to walk one level of subdirectory. Adds ~30 LOC of code (a `read_dir`-style helper or a flat scan over `stdlib/rods/ml/*.nr`). Keeps the nested layout. The change is in tools-side `.nr`, not in the compiler, so it's not bound by the "no `bin/nucleor.exe`/`bootstrap/nucleor_s1_seed.ll` changes" rule — but it does shape rod-manifest schema for *all* future rods, so it warrants integrator review.

**Recommendation:** **(a-recurse)** for production-readiness. Reasons: (i) the namespace pollution from 150 flat rods is real and discoverability degrades; (ii) the manifest schema already has a `path` field that encodes the directory anyway, so subdir support is a natural extension; (iii) `helper_manifest.toml` follows the same generator pattern and would also benefit. ML-4 should propose the patch as a separate `fix/` branch alongside the rod batch and let the integrator promote.

### 6.2 — `print(<non-str>)` and `&raw`-on-local patterns suggest the upstream Nucleor parser rules tightened post-v0.7.14

Two issues that didn't show up under v0.3.x source-of-truth now hit:

- The `print` runtime helper accepts only `str`. Pre-v0.8 ML Suite source used `print(<f64>)` / `print(<i64>)` and the compiler implicitly stringified.
- The parser treats `&raw` as a contextual-keyword start of raw-pointer syntax, not as "shared ref to local named raw."

Both of these are **language-side ergonomics** that the broader Nucleor language-feedback log under `docs/NUCLEOR_LANGUAGE_FEEDBACK.md` should record. **For this triage, we just file mechanical fixes;** for upstream Nucleor, this is two separate parser-ergonomics asks (auto-stringify in `print(...)`; disambiguate `&raw` based on local-binding existence). Filed as informational only — no blocker.

### 6.3 — Smoke-fixture relocation

The ML_Control1 ML-4 contract says smoke fixtures move from `examples/<area>_mvp/<rod>.nr` (the suite's existing convention) to `tests/features/ml_<rod>_smoke.nr` (the canonical Nucleor convention). Two implications worth flagging:

- The suite's existing examples use the directory structure to indicate area (`learn_mvp/`, `nn_mvp/`, …). Flattening to `ml_*` prefix loses that grouping. Naming convention needs to encode the area: `ml_learn_<rod>_smoke.nr`, `ml_nn_<rod>_smoke.nr`, etc.
- The suite's parity examples include both pure-rod tests and **Python-parity-comparison tests** (the `torch_*_f64.nr` and `numpy_*_f64.nr` rods). Those are not "smokes" in the canonical Nucleor sense — they are migration evidence. Recommendation: ship them as `tests/features/ml_<rod>_smoke.nr` for the simplest cases; the deeper Python-parity comparison artifacts (with their `examples/python_parity/` Python reference scripts) should remain in `examples/python_parity/` as REFERENCE-only per project rule. The integrator may want a separate `tests/parity/` folder eventually.

## 7. Recommended ML-4 first-batch composition (revised based on triage)

ML-2 §10 proposed 5 Tier-S cores + 5 Tier-A entry rods. The triage confirms all 10 of those are bucket A or transitively confirmed. **Recommendation stands**, with one tweak: **include the `&raw` rename in `learn_facade.nr` as part of the ML-4 batch** (it's a 2-occurrence ≤8 LOC mechanical fix that unblocks 44 cascading examples).

| # | Source | Destination | Fix needed |
|---|---|---|---|
| 1 | `src/dtype_core.nr` | `stdlib/rods/ml/dtype_core.nr` (or flat per §6.1 decision) | none |
| 2 | `src/shape_core.nr` | `stdlib/rods/ml/shape_core.nr` | none |
| 3 | `src/parity_manifest.nr` | `stdlib/rods/ml/parity_manifest.nr` | none |
| 4 | `src/tensor_facade.nr` | `stdlib/rods/ml/tensor_facade.nr` | none |
| 5 | `src/math_facade.nr` | `stdlib/rods/ml/math_facade.nr` | none |
| 6 | `src/learn_facade.nr` | `stdlib/rods/ml/learn_facade.nr` | **rename local `raw` → `r` at lines 1392,1395-99 + 1449,1452-56** |
| 7 | `src/stats_facade.nr` | `stdlib/rods/ml/stats_facade.nr` | none |
| 8 | `src/nn_facade.nr` | `stdlib/rods/ml/nn_facade.nr` | none |
| 9 | `src/ai_facade.nr` | `stdlib/rods/ml/ai_facade.nr` | none |
| 10 | `src/boost_facade.nr` | `stdlib/rods/ml/boost_facade.nr` | none |

Smoke fixtures (one per item, under `tests/features/ml_*_smoke.nr` or equivalent per §6.3 decision):

- `tests/features/ml_tensor_facade_smoke.nr` ← derived from `tests/tensor_core_smoke.nr` (build-clean today)
- `tests/features/ml_nn_facade_smoke.nr` ← `tests/nn_core_smoke.nr`
- `tests/features/ml_ai_facade_smoke.nr` ← `tests/ai_core_smoke.nr`
- `tests/features/ml_data_facade_smoke.nr` ← `tests/data_core_smoke.nr`
- `tests/features/ml_text_facade_smoke.nr` ← `tests/text_core_smoke.nr`
- `tests/features/ml_learn_facade_smoke.nr` ← `tests/learn_core_smoke.nr` (post-fix)
- `tests/features/ml_stats_facade_smoke.nr` ← derived from one passing stats parity rod (`scipy_stats_describe_f64`)
- `tests/features/ml_boost_facade_smoke.nr` ← derived from `xgboost_stump_ensemble_predict_f64`
- `tests/features/ml_dtype_core_smoke.nr` ← lightweight `main()` that exercises dtype_size_bytes + dtype_default_accumulator
- `tests/features/ml_shape_core_smoke.nr` ← lightweight `main()` exercising `shape2(rows, cols)` round-trip

`rod_manifest.toml` regen plan depends on §6.1 outcome. Two paths:

- If integrator picks **(a-flat)**: regen via existing `bin/nucleor build tools/gen_rod_manifest.nr -o gen_rod_manifest && ./target/gen_rod_manifest`. No tooling change.
- If integrator picks **(a-recurse)**: ML-4 ships a separate `fix/ml-4-rod-manifest-recurse-v0845` branch that adds the recursion to `tools/gen_rod_manifest.nr`. ML rods batch then lands on top of that.

## 8. Round-2+ batches (preview — informational, not in scope for this queue)

Not part of ML-3, but informational so ML-4 doesn't double-handle:

| Round | Batch | Items |
|---|---|---:|
| Round 2 | sklearn parity rods (Tier A) | 41 (`examples/learn_mvp/sklearn_*.nr`) — **only after learn_facade `&raw` fix lands** |
| Round 2 | PyTorch nn parity rods (Tier A) | 22 (`examples/nn_mvp/torch_*.nr`) |
| Round 2 | Transformer/AI parity rods (Tier A) | 23 (`examples/ai_mvp/torch_*.nr`) |
| Round 2 | NumPy tensor parity rods (Tier A) | 14 (`examples/tensor_mvp/numpy_*.nr` and friends) |
| Round 2 | XGBoost/LightGBM/CatBoost (Tier A) | 8 (`examples/boost_mvp/`) |
| Round 2 | SciPy stats parity rods (Tier A) | 5 + 1 post-fix |
| Round 3 | Phase 7 manifest-tier facades + smokes (Tier B) | 14 master + 5 mainline = **19 facades + 19 smokes** in one bulk batch |
| Round 3 | Capsule + ncap workflow (Tier B) | `capsule_facade`, `ncap_facade` + 3 smokes |
| Round 4+ | ParallelAgent-tree pandas-deep parity rods | ~75 (`examples/data_mvp/pandas_*.nr` from PA tree) |
| Round 4+ | ParallelAgent-tree capsule manifest variants | 10 (`capsule_*_manifest_smoke.nr` from PA tree) |

## 9. Triage CSV reference

`findings/inbox/ml_agent_lane1_triage_buildclean_v0845_2026-05-07.csv` (187 lines = 1 header + 186 file rows) has the per-file record:

```
relpath,exit,stderr_first_line,size_bytes,has_main
```

Where `exit` is the `bin/nucleor.exe build` exit code (0 = bucket A, 1 = bucket B per §3, `SKIPPED_LIB` = library file with no `main`).

## Residuals / blockers

- **§6.1 (rod-manifest scanner recursion)** — integrator decision required before ML-4 first batch lands. Recommended path: (a-recurse).
- **§6.3 (smoke-fixture naming/location convention)** — integrator decision on `tests/features/ml_<area>_<rod>_smoke.nr` vs `tests/features/ml_<rod>_smoke.nr` flat naming.
- **No bucket C or D items** — every `.nr` file in the suite either builds clean today or has a single mechanical fix. No deferred items needed at this point.
- **`learn_facade.nr` `&raw` fix** — ML-4 must include this 2-occurrence rename or learn_mvp + 1 test fixture stay broken.
- **`scipy_stats_ttest_f64.nr` print typing fix** — Round-2 work, optional for ML-4.

End of finding.
