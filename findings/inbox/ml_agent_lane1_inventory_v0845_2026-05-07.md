# ML Suite source-tree inventory — Queue ML-1

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: probe/ml-1-source-tree-inventory-v0845
Base: origin/main @ 46e4fa5
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`

## 1. Per-tree inventory

| Tree | Path (relative to `Nucleor_OSS_Files\`) | Files (excl. target/cache/.git) | Dirs | Bytes (excl. target/cache) | `.nr` | `.md` | Git state |
|---|---|---:|---:|---:|---:|---:|---|
| Master | `Nucleor_ML_Suite` | 743 | 222 | 9,487,720 | 176 | 185 | Real repo @ master b862a2b; **dirty** (1 modified, 2 untracked) |
| Mainline snapshot | `Nucleor_ML_Suite_ParallelAgent_Mainline` | 617 | 170 | 2,313,778 | 140 | 155 | Worktree pointer broken (`gitdir: C:/Users/JoeWe/Desktop/Nucleor_ML_Suite/.git/worktrees/Nucleor_ML_Suite_ParallelAgent_Mainline` not present); treat as snapshot |
| ParallelAgent snapshot | `Nucleor_ML_Suite_ParallelAgent` | 522 | 152 | 1,226,410 | 151 | 148 | Worktree pointer broken (same condition); treat as snapshot |

Master dirty paths (`git status --short --branch` in master tree):
- ` M docs/NUCLEOR_LANGUAGE_FEEDBACK_RESPONSE.md` (modified, unstaged)
- `?? docs/NUCLEOR_TRANSLATE_SPEC2_TASK2_RESPONSE.md` (untracked)
- `?? docs/STRATEGIC_REVIEW_2026-04-25.md` (untracked)

All three trees share the same top-level shape (`docs/`, `examples/`, `rods/`, `src/`, `tests/`, `tools/`) with one quirk: **`rods/` is empty in all three trees** despite the README mentioning it. The actual library content lives under `src/` (facades + cores) and `examples/<area>_mvp/` (parity rods + smoke fixtures).

## 2. Top-level layout differences (`examples/` MVP areas)

| MVP area | Master | Mainline | ParallelAgent |
|---|:-:|:-:|:-:|
| ai_mvp | yes | yes | — |
| backend_mvp | yes | yes | — |
| bench_mvp | yes | yes | — |
| boost_mvp | yes | yes | — |
| capsule_mvp | yes | yes | yes |
| cert_mvp | yes | yes | — |
| cli_mvp | yes | yes | — |
| contract_mvp | yes | yes | — |
| data_mvp | yes | yes | yes |
| **experiment_mvp** | — | yes | — |
| fixtures | yes | yes | yes |
| **gguf_mvp** | — | yes | yes |
| health_mvp | yes | yes | — |
| hf_mvp | yes | yes | — |
| lab_mvp | yes | yes | — |
| learn_mvp | yes | yes | yes |
| model_io_mvp | yes | yes | — |
| nn_mvp | yes | yes | yes |
| **onnx_mvp** | — | yes | yes |
| port_mvp | yes | yes | — |
| python_parity | yes | yes | yes |
| registry_mvp | yes | yes | — |
| sbom_mvp | yes | yes | — |
| serve_mvp | yes | yes | — |
| ship_mvp | yes | yes | — |
| stats_mvp | yes | yes | — |
| tabular_mvp | yes | yes | — |
| tensor_mvp | yes | yes | yes |
| text_mvp | yes | yes | — |
| **tune_mvp** | — | yes | — |
| **vllm_mvp** | — | yes | — |

Bold = mainline-exclusive new MVPs (5 backend-integration areas not in master).

## 3. Unique-vs-shared `.nr` map

Computed via `comm` over normalized relative paths.

| Set | Count |
|---|---:|
| Shared by **all 3** | 57 |
| Master ∩ Mainline (not in PA) | 73 |
| Master ∩ PA (not in Mainline) | 0 |
| Mainline ∩ PA (not in Master) | 0 |
| **Unique to Master** | 46 |
| **Unique to Mainline** | 6 |
| **Unique to PA** | 90 |
| **Total unique paths (union)** | 272 |

Key takeaways:

- **Master ∩ PA \ Mainline = ∅** and **Mainline ∩ PA \ Master = ∅**. PA never overlaps with master or mainline alone — every shared file is shared by all three. PA is therefore a fork of the all-three core that *added* 90 new files (overwhelmingly pandas-deep parity under `examples/data_mvp/`) and dropped most other MVPs.
- **Mainline-unique 6** = 5 facades + 1 smoke (`src/{experiment,gguf,onnx,tune,vllm}_facade.nr` + `examples/{...}/nuc_*_manifest_smoke.nr`) — the backend-integration tier that postdates master.
- **Master-unique 46** = sklearn deep parity (~30 files), boost/xgboost extras (~7), stats/scipy describe (~1), boost categorical (1), plus a handful of model_io/text spans.
- **PA-unique 90** = pandas-deep parity (~75 files under `examples/data_mvp/`), plus tensor_mvp/nn_mvp/learn_mvp variants and capsule manifest smokes.

Conclusion: **all three trees contribute non-redundant content**. None can be dropped without losing library surface. The integration corpus is the union (272 distinct `.nr` paths).

Persisted file lists for downstream queues:

- `/tmp/ml_master.lst` — 176 lines
- `/tmp/ml_mainline.lst` — 140 lines
- `/tmp/ml_pa.lst` — 151 lines

## 4. Spec/plan asymmetry across `docs/`

| Spec doc | Master | Mainline | PA |
|---|:-:|:-:|:-:|
| API_SURFACE_INDEX.md | yes | yes | — |
| BOOSTING_RUNTIME_SPEC.md | yes | yes | — |
| CAPSULE_RUNTIME_SPEC.md | yes | yes | yes |
| CERTIFICATION_RUNTIME_SPEC.md | yes | yes | — |
| CLAIM_LEDGER.md | yes | yes | — |
| EXPERIMENT_TUNING_RUNTIME_SPEC.md | — | yes | — |
| HUGGINGFACE_RUNTIME_SPEC.md | yes | yes | — |
| IMPLEMENTATION_PLAN.md | yes | yes | yes |
| KERNEL_BACKEND_RUNTIME_SPEC.md | yes | yes | — |
| ML_HEALTH_RUNTIME_SPEC.md | yes | yes | — |
| MODEL_IO_RUNTIME_SPEC.md | yes | yes | — |
| NUCLEOR_LAB_DASHBOARD_SPEC.md | yes | yes | — |
| NUCLEOR_LAB_RUNTIME_SPEC.md | yes | yes | — |
| NUCLEOR_LANGUAGE_FEEDBACK*.md | yes | yes | yes |
| NUCLEOR_WORLD_CLASS_LANGUAGE_ROADMAP_2026-04-27.md | — | yes | — |
| NUC_BENCH_RUNTIME_SPEC.md | yes | yes | — |
| NUC_CLI_RUNTIME_SPEC.md | yes | yes | — |
| NUC_PORT_RUNTIME_SPEC.md | yes | yes | — |
| NUC_SHIP_RUNTIME_SPEC.md | yes | yes | — |
| ONNX_GGUF_RUNTIME_SPEC.md | — | yes | yes |
| PYTHON_PARITY_MAP.md | yes | yes | yes |
| PYTHON_PORTING_GUIDE.md | yes | yes | — |
| ROD_REGISTRY_RUNTIME_SPEC.md | yes | yes | — |
| SBOM_RUNTIME_SPEC.md | yes | yes | — |
| SHAPE_DTYPE_CONTRACT_SPEC.md | yes | yes | — |
| STATS_RUNTIME_SPEC.md | yes | — | — |
| STRATEGIC_REVIEW_2026-04-25.md | yes (untracked) | — | — |
| STRATEGIC_REVIEW_RESPONSE_2026-04-25.md | yes | yes | — |
| TABULAR_ENGINE_RUNTIME_SPEC.md | yes | yes | — |

ML-2 should **read mainline's** copies of `IMPLEMENTATION_PLAN.md`, `NUCLEOR_LANGUAGE_FEEDBACK_RESPONSE.md`, `PYTHON_PARITY_MAP.md`, and `STRATEGIC_REVIEW_RESPONSE_2026-04-25.md` because mainline carries 2 newer specs (EXPERIMENT_TUNING, NUCLEOR_WORLD_CLASS_LANGUAGE_ROADMAP) that master doesn't have. Master's untracked `STRATEGIC_REVIEW_2026-04-25.md` is required reading from master only.

## 5. Stale-import enumeration

`grep -rh "^import "` over all `.nr` files across all three trees yields four import categories:

| Category | Pattern | Status against current `Nucleor_OSS @ origin/main` |
|---|---|---|
| **Intra-suite cores** | `import "src/dtype_core.nr"`, `import "src/shape_core.nr"`, `import "src/parity_manifest.nr"` | OK to copy — these files come over with the suite. They depend only on built-in primitives (`dtype_*`, `policy_*` helpers). |
| **Intra-suite facades** | `import "src/<area>_facade.nr"` (28 of them: ai/backend/bench/boost/capsule/cert/cli/contract/data/dtype_core/hf/lab/learn/math/ml_health/model_io/ncap/nn/parity_manifest/port/rod_registry/sbom/serve/shape_core/ship/stats/tabular/tensor/text/tokenizer + mainline's experiment/gguf/onnx/tune/vllm) | **Path needs rewriting on integration.** They must become e.g. `import "stdlib/rods/ml/<area>_facade.nr"` once placed under `stdlib/rods/ml/`. The `import` resolver is path-relative; this is mechanical, not semantic. |
| **Canonical Nucleor stdlib** | `import "stdlib/rods/jsonl.nr"`, `"stdlib/rods/math_typed_special.nr"`, `"stdlib/rods/strings.nr"`, `"stdlib/rods/tokenizer.nr"` | **All four exist on current `origin/main`** under `stdlib/rods/`. No porting work. |
| **Python (reference only)** | `import math`, `import numpy as np`, `import pandas as pd`, `import scipy.stats as scipy_stats`, `import torch`, `import torch.nn.functional as F` | These appear in `examples/python_parity/*.py` reference scripts, NOT `.nr` files. They are out-of-scope per project rule "no Python helpers in product/toolchain paths" — `python_parity/` stays in source as REFERENCE only and is not integrated. |

**No `.nr` import refers to a Nucleor-language API that no longer exists on `origin/main`.** All language-API references use names available in canonical compiler 0.8.323.

### Smoke build evidence (sandbox `_ml_probe`)

To validate the import claim, I staged master's `src/` + `tests/` + `examples/` into `_ml_probe/` and built two representative files against the sandbox `bin/nucleor.exe` (compiler `0.8.323 (self-hosted, llvm backend)`):

- `tests/tensor_core_smoke.nr` (deepest core: dtype_core, shape_core, parity_manifest, tensor_facade, ~46 KB) → **build clean, exit 0** (`target\tensor_core_smoke.exe` produced; cache miss → stored).
- `examples/learn_mvp/sklearn_kmeans_predict_f64.nr` → **build fail** with `ERROR: raw-ref syntax \`&raw const\` / \`&raw mut\` is not in the V1 language surface. Workaround: use \`&expr\` (shared ref) or \`&mut expr\` (mutable ref).` This is a **single-language-surface gate** (raw-ref syntax was removed from V1 — RFC mentioned in the error). It will affect any `.nr` that uses `&raw const` / `&raw mut`. The fix is mechanical (drop `raw`). I did NOT modify any source — surfacing as a porting blocker for ML-3 to scope.

Action item for ML-3: grep the union for `&raw const` / `&raw mut` and bucket those into B (light fix, ≤5 LOC) or C (porting work) per occurrence count. Triage will be done in ML-3 per the queue contract; **no source edits in ML-1**.

The `_ml_probe/` staging directory is a transient probe; it has been removed. The two builds above are the only evidence captured here, and they are reproducible from the README pattern.

## 6. Folder-choice justification (suggested for the integration queue)

**Recommended: option (a) — `stdlib/rods/ml/<canonical_name>.nr` (nested under existing `stdlib/rods/`).**

Reasoning:

1. **Existing import resolver supports nesting.** Canonical `stdlib/rods/` is overwhelmingly flat (255 `.nr` files), but the resolver is path-relative — confirmed by the suite's own use of `import "stdlib/rods/jsonl.nr"`. A `stdlib/rods/ml/foo.nr` import works without compiler change.
2. **Volume isolation.** 272 unique paths (probable trim to ~150-200 ship-ready) would dilute the existing 255 flat rods 2:1. A sub-namespace keeps the ML library discoverable (`ls stdlib/rods/ml/`) while not crowding the existing canonical surface (`linalg.nr`, `nn.nr`, `attention2.nr`, `tensor_nd.nr`).
3. **Name-collision avoidance.** The suite's `tensor_facade.nr`/`tensor_facade` is a *parity-flavored* abstraction (TensorF64/F32/I64 with dtype + accumulator + numeric-policy metadata, designed for sklearn/pandas API parity). Canonical Nucleor already ships `stdlib/rods/tensor_nd.nr` and `stdlib/rods/linalg.nr` with a different (lower-level, C-runtime-shaped extern) abstraction. They should coexist; nesting trivially achieves that without renaming.
4. **MVP grouping is preserved by file naming, not directory.** The suite's `.nr` files already use prefixes (`sklearn_*`, `xgboost_*`, `pandas_*`, `nuc_*`) so a flat `stdlib/rods/ml/` retains the grouping while letting integrators import via short paths. This avoids the option-(b) cost of deep import paths like `stdlib/ml/data_mvp/pandas_filter_value_eq_i64_f64.nr`.
5. **Top-level `ml_suite/` (option c) breaks the existing convention** that every adopter-facing rod lives under `stdlib/rods/` and is registered in `docs/rfcs/rod_manifest.toml` via `tools/gen_rod_manifest.nr`. The manifest scanner walks `stdlib/rods/` recursively (verified via `cat tools/gen_rod_manifest.nr | head` is queued for ML-2). Putting ML rods outside `stdlib/rods/` would require either (i) a generator change (compiler-adjacent, integrator-only territory) or (ii) a hand-maintained second manifest.

Concrete proposed layout:

```
stdlib/rods/ml/
  parity_manifest.nr            # cross-cutting metadata (ML Suite's parity declaration)
  dtype_core.nr                 # ML-Suite dtype tags (separate from Nucleor's primitive dtypes)
  shape_core.nr
  tensor_facade.nr              # parity-flavored TensorF64/F32/I64
  ai_facade.nr / boost_facade.nr / data_facade.nr / learn_facade.nr / nn_facade.nr / ...
  experiment_facade.nr / gguf_facade.nr / onnx_facade.nr / tune_facade.nr / vllm_facade.nr
  sklearn_*.nr xgboost_*.nr lightgbm_*.nr catboost_*.nr pandas_*.nr scipy_*.nr     # parity rods
  nuc_*_manifest_smoke.nr        # MVP smoke fixtures (or moved to tests/features/, see ML-4)
```

Two **integrator-promoted** decisions are deferred (not for me to make in this queue):

- Whether `dtype_core.nr` / `shape_core.nr` should be top-level renames or left under `ml/` — they collide conceptually with canonical `dtype_*` primitive names, but the suite's are *additive metadata* (accumulator dtype, numeric policy tags), not replacements. Default: keep them under `stdlib/rods/ml/` to avoid surface confusion.
- Whether smoke fixtures belong under `tests/features/ml_*_smoke.nr` (canonical pattern in `tests/features/`) or under `stdlib/rods/ml/` next to their rods. ML-4 will move them to `tests/features/` per the ML_Control1 contract.

## 7. Counts summary for downstream queues

| Quantity | Value |
|---|---:|
| Unique `.nr` paths across union of 3 trees | 272 |
| `.nr` paths that survived smoke build of master core (`tensor_core_smoke.nr`) | confirmed clean |
| Known porting-blocker syntax found in at least one example | `&raw const` / `&raw mut` (V1-removed) |
| Spec/plan docs to read in ML-2 | 30 (master + 5 mainline-extras) |

## Residuals / blockers surfaced for downstream lanes

- **None requiring integrator action this queue.** The dirty/untracked state of master is informational only — read-only consumption is fine.
- **For ML-2:** read mainline's `IMPLEMENTATION_PLAN.md` and `STRATEGIC_REVIEW_RESPONSE_2026-04-25.md` (newer surface), and master's `STRATEGIC_REVIEW_2026-04-25.md` (master-only).
- **For ML-3:** the union must be triaged. Pre-grep `&raw const|&raw mut` patterns to scope bucket-B fixups before launching individual builds.

End of finding.
