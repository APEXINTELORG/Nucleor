# ML Suite PA-tree capsule manifest variants — Queue ML-17

Branch: fix/ml-17-batch-14-pa-capsule-variants-v0845 (stacks on ML-16)
Date: 2026-05-07

## Headline

Lands the **PA-tree capsule_facade upgrade** (a strict superset: 36 fns vs master's 6, 0 removed) plus **all 10 PA-tree capsule sub-aspect manifest variants** at 30-run stability. **10/10 ship-ready** — these are pure contract surfaces, no UB risk.

## What changed

| Item | Detail |
|---|---|
| `stdlib/rods/ml/capsule_facade.nr` | upgraded to PA superset (6 → 36 fns; +30 added, 0 removed) |
| New parity rods at `tests/features/ml_pa_capsule_*.nr` | 10 |
| Manifest delta | 288 rods (capsule_facade upgrade adds 30 fns; +921 LOC) |
| Drift gate | clean |

## Ship-ready (10) — all stable across 30 runs

| Rod | Surface |
|---|---|
| `ml_pa_capsule_artifact_manifest_smoke` | artifact-level capsule manifest (path/hash/size/format) |
| `ml_pa_capsule_device_manifest_smoke` | device profile (CPU/GPU/CUDA capability/topology) |
| `ml_pa_capsule_input_manifest_smoke` | input data manifest (path/dtype/shape/policy/element-count) |
| `ml_pa_capsule_output_manifest_smoke` | output data manifest |
| `ml_pa_capsule_rod_graph_manifest_smoke` | rod-graph hash + transitive imports |
| `ml_pa_capsule_source_manifest_smoke` | source-file hashes + LOC + fn count |
| `ml_pa_capsule_suite_manifest_smoke` | parity suite metadata (case count, claim scope) |
| `ml_pa_capsule_tolerance_manifest_smoke` | tolerance contract per output (abs/rel) |
| `ml_pa_capsule_toolchain_manifest_smoke` | compiler hash + LLVM version + linker |
| `ml_pa_capsule_verifier_manifest_smoke` | verifier-side manifest (replay command, signature state) |

These cover the per-aspect manifest schema for the canonical `.ncap` reproducibility envelope. Together with `ml_capsule_facade_smoke` (ML-5), `ml_ncap_facade_smoke` (ML-5), and `ml_jsonl_evidence_smoke` (ML-15), the capsule subsystem now has **13 stable contract surfaces** at canonical.

## Build / drift

- 10/10 build clean.
- 10/10 stable across 30 consecutive runs.
- Drift gate clean.
- Stacks on ML-16. Branch rebased on `fix/ml-16-batch-13-pandas-pa-tree-v0845`.

End of finding.
