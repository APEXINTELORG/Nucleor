# Helper2 ML-EXT + TRANS Current-State Audit v0835

Date: 2026-05-06

Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`

Assignment: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\findings\_helper2_assignment_v0828_r06_rust_bridge_ownership_harness_2026-05-06.md`

Scope: Queue 9 Scope AR. This is a read-only map of external ML and Translate state. No external source was copied into `Nucleor_OSS`, and no `nuc port` integration was added.

## Executive Status

`Nucleor_ML_Suite` is the strongest current external ML evidence source. It is a real git repo, but it is dirty, so I did not mutate it or run its full verify gate. Its current evidence bundle records 120/120 Python parity cases, 61/61 proven claim-ledger entries, and zero external backend dispatch for the parity lane.

The two copied ML parallel-agent folders are useful snapshots but not canonical git worktrees on this machine. Their `.git` files point at stale worktree metadata under `C:\Users\JoeWe\Desktop\Nucleor_ML_Suite\.git\worktrees\...`, so `git -C` fails there.

`MLV_Kernel` is CUDA/quantization R&D, not a git repo here. It should not be imported into `Nucleor_OSS` as-is. It is evidence for an external kernel/backend lane and product direction, not for a closed compiler/runtime integration.

`Nucleor_Translate` is a real git repo with active dirty Go work. Its progress table records SPEC-1 through SPEC-11 complete and a 368 PASS verify gate at the last recorded checkpoint, but the local wrapper now reports Nucleor 0.4.11 while `docs/PROGRESS.md` still says the pinned snapshot is 0.4.5. It is not complete enough to justify adding `nuc port` in `Nucleor_OSS`.

## External Workspace Matrix

| Path | Git state | HEAD | Verify command inferred | Ran verify? | Integration action in `Nucleor_OSS` now |
| --- | --- | --- | --- | --- | --- |
| `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite` | Git repo, branch `master`, dirty docs | `b862a2b8dc95b6b710ca1d49c4b2d729517188e5` | `.\tools\verify.ps1` per README | No. Dirty working tree has modified and untracked docs. | Do not import source. Use as external ML evidence map only. |
| `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent` | Broken copied worktree; `.git` file points to stale `C:\Users\JoeWe\Desktop\Nucleor_ML_Suite\.git\worktrees\Nucleor_ML_Suite_ParallelAgent` | unavailable | likely `.\tools\verify.ps1` if gitdir repaired | No. Git metadata broken. | Snapshot only. Repair gitdir before treating as source of truth. |
| `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent_Mainline` | Broken copied worktree; `.git` file points to stale `C:\Users\JoeWe\Desktop\Nucleor_ML_Suite\.git\worktrees\Nucleor_ML_Suite_ParallelAgent_Mainline` | unavailable | likely `.\tools\verify.ps1` if gitdir repaired | No. Git metadata broken. | Snapshot only. It has fewer current parity cases than `Nucleor_ML_Suite`. |
| `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\MLV_Kernel` | Not a git repo in this folder | unavailable | README CUDA/Python commands, not a Nucleor gate | No. Not a git repo and CUDA workload is outside this scope. | External R&D only. Do not import into compiler/package tree now. |
| `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate` | Git repo, branch `main`, dirty code/tests | `a7d3ddace31b56c35c598506d235568e82512e35` | `./tools/verify.sh` per `docs/PROGRESS.md` | No. Dirty active Go and generated fixture state. | No `nuc port`. File status/gap report only. |

## ML Lane Map A-K

| Lane | Current external support | Evidence observed | `Nucleor_OSS` action now |
| --- | --- | --- | --- |
| A: claims, evidence, backend dispatch | Strong in `Nucleor_ML_Suite` | `docs/CLAIM_LEDGER.md` has 61 claim headings and 61 `proven` status lines. `examples/python_parity/summary.json` has `case_count=120`, `passed_count=120`, `external_backend_count=0`, backend `scalar_nucleor_facade`. | No code import. Reuse the claim/evidence discipline only if a docs integration lane opens. |
| B: ML frontend/API surface | Partial external | Claim ledger includes `CLAIM-API-SURFACE`, `CLAIM-PYTHON-MIGRATION-PLANNER`, and `CLAIM-ML-HEALTH-PREFLIGHT`. | No compiler/runtime change. |
| C: kernel, serve, package implementation | External and split | `MLV_Kernel` has CUDA kernels and adaptive dispatch notes; ML Suite carries package/NCAP evidence. | Keep out of `Nucleor_OSS` unless a bounded backend/package substrate task is opened. |
| D: dtype/shape rule | External contract evidence | ML Suite has `CLAIM-SHAPE-DTYPE-CONTRACT`. | Do not overclaim compile-time shape safety in `Nucleor_OSS` from this evidence. |
| E: Hugging Face frontend | External claim evidence | ML Suite has `CLAIM-HUGGINGFACE-FRONTEND`. | No import now. Treat as ML Suite feature until revalidated against Nucleor package/runtime surfaces. |
| F: ONNX/GGUF/model IO | Not closed by this audit | No current closed execution proof was found in this read-only pass. | Keep as future integration/spec work. |
| G: vLLM/serving | Not closed by this audit | No current closed vLLM serving proof was found. | Keep open. |
| H: Arrow/DLPack/tabular | Partial external | ML Suite has `CLAIM-TABULAR-ENGINE-FRONTEND`; Nucleor RFCs discuss DLPack separately. | No runtime import now. |
| I: boosting/tree inference | External claim evidence | Mainline snapshot has `CLAIM-BOOSTING-INFERENCE` and `CLAIM-BOOSTING-TREE-INFERENCE`; canonical ML Suite has broader sklearn parity claims. | No import now. |
| J: backend manifest/accounting | Strong external evidence | ML Suite reports zero external backend dispatch and max Nucleor binary size in parity summary. | Keep as evidence accounting model. Do not claim native accelerator execution. |
| K: package/lockfile/NCAP/conformance | Partial external evidence | ML Suite has `CLAIM-NCAP-VERIFY`, `CLAIM-SBOM-INVENTORY`, and package/manifest claims. | Separate from `Nucleor_OSS` PKG-1. Do not conflate ML Suite NCAP proof with native Linux signed publish proof. |

## ML Suite Details

Canonical path: `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite`

Current status:

```text
## master
 M docs/NUCLEOR_LANGUAGE_FEEDBACK_RESPONSE.md
?? docs/NUCLEOR_TRANSLATE_SPEC2_TASK2_RESPONSE.md
?? docs/STRATEGIC_REVIEW_2026-04-25.md
HEAD=b862a2b8dc95b6b710ca1d49c4b2d729517188e5
```

Recent commits observed:

```text
b862a2b Add sklearn BernoulliNB parity
7c3fdd9 Add sklearn MultinomialNB parity
deb5818 Add sklearn MaxAbsScaler parity
```

Parity summary observed in `examples/python_parity/summary.json`:

```text
python_version=3.11.9
numpy_version=2.2.6
pandas_version=2.3.3
scipy_version=1.17.1
sklearn_version=1.8.0
torch_version=2.11.0+cu128
nucleor_compiler=C:\Users\JoeWe\Desktop\Nucleor_OSS\bin\nucleor.exe
case_count=120
passed_count=120
claim_scope=numeric_parity_only
nucleor_backends=scalar_nucleor_facade
external_backend_count=0
max_nucleor_binary_size_bytes=564736
```

Claim ledger headings/proven status count:

```text
CLAIM_HEADINGS=61
PROVEN_STATUS_LINES=61
```

Representative proven claims observed include:

```text
CLAIM-NUMERIC-PARITY
CLAIM-ZERO-EXTERNAL-BACKEND
CLAIM-NCAP-VERIFY
CLAIM-ZERO-PYTHON-PRODUCT-RUNTIME
CLAIM-API-SURFACE
CLAIM-PYTHON-MIGRATION-PLANNER
CLAIM-ML-HEALTH-PREFLIGHT
CLAIM-BENCH-TELEMETRY
CLAIM-SBOM-INVENTORY
CLAIM-SHAPE-DTYPE-CONTRACT
CLAIM-HUGGINGFACE-FRONTEND
CLAIM-TABULAR-ENGINE-FRONTEND
```

## Parallel ML Snapshots

`C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent` has a stale gitdir pointer:

```text
gitdir: C:/Users/JoeWe/Desktop/Nucleor_ML_Suite/.git/worktrees/Nucleor_ML_Suite_ParallelAgent
fatal: not a git repository: C:/Users/JoeWe/Desktop/Nucleor_ML_Suite/.git/worktrees/Nucleor_ML_Suite_ParallelAgent
```

It still has `examples/python_parity/summary.json` with `case_count=121` and `passed_count=121`, but without a working gitdir it should be treated as a copied snapshot.

`C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent_Mainline` has a stale gitdir pointer:

```text
gitdir: C:/Users/JoeWe/Desktop/Nucleor_ML_Suite/.git/worktrees/Nucleor_ML_Suite_ParallelAgent_Mainline
fatal: not a git repository: C:/Users/JoeWe/Desktop/Nucleor_ML_Suite/.git/worktrees/Nucleor_ML_Suite_ParallelAgent_Mainline
```

It has `examples/python_parity/summary.json` with `case_count=75`, `passed_count=75`, `external_backend_count=0`, plus 18 proven claim ledger headings. It is useful historical evidence, but it is weaker than the current canonical ML Suite repo.

## MLV Kernel Details

Path: `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\MLV_Kernel`

Git state: not a git repo in this copied folder.

Observed README direction:

```text
MLV Kernel - Multi-Level Voltage Inference Engine
CUDA v13.1 NVCC compile commands for SM120 kernels
Batch=1 large layers: 2.4-3.0x vs cuBLAS FP16
Batch=8 attention: 1.18-2.20x vs cuBLAS FP16
Batch=32 attention: 1.17x vs cuBLAS FP16
Batch=8 end-to-end Qwen3-4B: 1.79x, 198.7 tok/s
```

Observed punchlist direction:

```text
Qwen3-4B MLV-32 5-bit group-128 GPTQ no rescue: 70.20% MMLU n=2000 vs FP16 70.15%
KV-cache quant: 1.33x KV, Qwen3/Qwen2.5/OPT plus CPU path validated
Weight kernel v4 batch=1 per-row absmax: 1.83x gen speedup, 5.3x nominal
Best current weight-quant stack is not shippable: group-128 plus 15% act_l1 rescue at 65.0% MMLU n=200 and 2.6x real compression
```

Interpretation: this is valuable external R&D. It does not currently create a `Nucleor_OSS` compiler, packaging, or release action.

## Translate Current State

Path: `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate`

Current git status:

```text
## main
 M cli/main.nr
 M tools/verify.sh
?? targetdiag3_out.txt
?? targetdiag_out.json
?? tests/c/fixtures/*.nr
?? tests/go/fixtures/*.go
?? tests/go/fixtures/*.golden.nr
?? tests/go/fixtures/*.nr
?? tests/go/go_e2e.ps1
?? tests/go/go_e2e.sh
?? tests/python/fixtures/*.nr
?? tests/rust/fixtures/*.nr
?? tests/typescript/fixtures/*.nr
HEAD=a7d3ddace31b56c35c598506d235568e82512e35
```

Recorded recent commits show SPEC-12 Go work has started:

```text
a7d3dda spec-12 task 12: pipeline_run dispatches on .go extension
b6d03f4 spec-12 task 11: GoGapReport for unsupported Go constructs
cb734d7 spec-12 task 10: lower Go fmt.Println/fmt.Printf -> IrExpr::Call("print", ...)
40242ed spec-12 task 9: lower Go if/for -> IrStmt sentinel form
de3d1c9 spec-12 task 8: lower Go function definitions + return -> IrFn + IrStmt::Return
```

Frontends present:

```text
c
go
javascript
python
rust
typescript
```

Test directories present:

```text
c
exe
fixtures
go
javascript
mcp
nrsource
provenance
python
rod
rust
typescript
```

Current test file count probe:

```text
Get-ChildItem tests -Recurse -Filter '*_test.nr' => 29
```

Progress document state in `docs/PROGRESS.md`:

```text
Pinned snapshot: Nucleor 0.4.5
Current state: 2026-04-27
SPEC-1 through SPEC-11: DONE
PHASE A COMPLETE
Test footprint: 368 PASS
Verify gate: ./tools/verify.sh -> === ALL CHECKS PASSED ===
Next: SPEC-12 Go front-end
```

Local wrapper version probe:

```text
pwsh -NoProfile -File C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate\tools\nuc.ps1 --version
nucleor 0.4.11 (self-hosted, llvm backend)
```

Translate gaps that matter before any `Nucleor_OSS` integration:

| Area | Status |
| --- | --- |
| Version/progress docs | Stale. `docs/PROGRESS.md` says pinned Nucleor 0.4.5, wrapper reports 0.4.11. |
| Dirty working tree | Active edits and generated fixtures mean no clean verification baseline. |
| Go | In progress beyond the recorded SPEC-11 table; not yet reflected as a clean completed spec in `docs/PROGRESS.md`. |
| Control flow | Several language frontends lower if/while/for through sentinel IR or gap reporting rather than full structured IR. |
| Float literals | SPEC-10/11 notes still mention float magnitude sentinel behavior. |
| Full language coverage | Java, C#, C++, Swift, Kotlin, Mojo, Zig, and others are not present as frontends in this folder. |
| `nuc port` | Not justified. Translate is active and dirty, not a complete revalidated integration target. |

## Validation Log

Commands run from `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`:

```text
git fetch origin --prune
git status --short --branch
git rev-parse HEAD
git rev-parse origin/fix/main-qm7-surface-code-v0827
git merge-base HEAD origin/fix/main-qm7-surface-code-v0827
git -C <external-path> status --short --branch
git -C <external-path> rev-parse HEAD
Select-String docs\CLAIM_LEDGER.md for CLAIM headings and proven status lines
Get-Content examples\python_parity\summary.json
pwsh -NoProfile -File C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate\tools\nuc.ps1 --version
Get-ChildItem frontends
Get-ChildItem tests -Directory
Get-ChildItem tests -Recurse -Filter '*_test.nr'
```

Verification deliberately not run:

- `Nucleor_ML_Suite`: dirty external repo.
- copied ML parallel-agent folders: broken/stale gitdir metadata.
- `MLV_Kernel`: non-git CUDA/Python R&D folder outside this task.
- `Nucleor_Translate`: dirty active Go/code/test state.

## Current Recommendation

Do not pull external source into `Nucleor_OSS` now. Treat ML Suite as an external evidence package, Translate as an active external product not ready for `nuc port`, and MLV Kernel as a separate CUDA R&D lane. The only immediate `Nucleor_OSS` work from this audit is documentation/handoff accounting, already captured here.
