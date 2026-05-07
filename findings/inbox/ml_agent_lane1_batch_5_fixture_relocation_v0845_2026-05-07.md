# ML Suite fixture relocation — Queue ML-8

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: fix/ml-8-batch-5-fixture-relocation-v0845 (from origin/main HEAD)
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`

## Headline

Stages the **27 union of `examples/fixtures/` files** from all three ML Suite source trees into `tests/features/ml_fixtures/`. Pure data-staging branch (no `.nr` source changes, no rod-manifest changes, no compiler changes). This is the prerequisite for ML-9..ML-14 parity-rod batches that read CSV/JSON fixtures.

| | Detail |
|---|---|
| Files added | 27 (CSV + JSON + SQL fixtures) |
| Bytes added | ~44 KB |
| `.nr` source changed | 0 |
| `bin/nucleor.exe` / `bootstrap/` | unchanged |
| `docs/rfcs/rod_manifest.toml` | unchanged |
| Drift gate | clean |

## Source

Union of fixture files from:
- `Nucleor_OSS_Files\Nucleor_ML_Suite\examples\fixtures\` (15 files, ~19 KB)
- `Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent_Mainline\examples\fixtures\` (18 files, includes 4 mainline-only: `gguf_tiny_decoder_manifest.json`, `onnx_tiny_encoder_manifest.json`, `vllm_tiny_scheduler_manifest.json`, plus shared)
- `Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent\examples\fixtures\` (17 files, includes 8 PA-only: `category_*.csv`, `drop_duplicates_i64_f64.csv`, `multi_feature_i64_f64.csv`, `multi_sort_describe_i64_f64.csv`, `rank_ties_i64_f64.csv`, `sort_describe_i64_f64.csv`, `string_join_*.csv`)

Where the same filename appeared in multiple trees, the bytes were verified identical (cp overwrite was a no-op for identical content; deliberate for matching paths).

## Layout

```
tests/features/ml_fixtures/
  category_nullable_f64.csv          (PA-tree)
  category_value_f64.csv             (PA-tree)
  drop_duplicates_i64_f64.csv        (PA-tree)
  gguf_tiny_decoder_manifest.json    (mainline)
  group_value_i64.csv                (shared)
  hf_tiny_adapter_config.json        (shared)
  hf_tiny_config.json                (shared)
  hf_tiny_dataset_info.json          (shared)
  hf_tiny_generation_config.json     (shared)
  hf_tiny_model.safetensors.index.json (shared)
  hf_tiny_tokenizer_config.json      (shared)
  join_left_i64.csv                  (shared)
  join_right_i64.csv                 (shared)
  multi_feature_i64_f64.csv          (PA-tree)
  multi_sort_describe_i64_f64.csv    (PA-tree)
  nullable_value_i64.csv             (shared)
  onnx_tiny_encoder_manifest.json    (mainline)
  rank_ties_i64_f64.csv              (PA-tree)
  sort_describe_i64_f64.csv          (PA-tree)
  string_join_left_f64.csv           (PA-tree)
  string_join_right_f64.csv          (PA-tree)
  tabular_arrow_schema.json          (shared)
  tabular_duckdb_query.sql           (shared)
  tabular_polars_lazy_plan.json      (shared)
  tensor_2x3_f64.csv                 (shared)
  tensor_2x3_i64.csv                 (shared)
  vllm_tiny_scheduler_manifest.json  (mainline)
```

## Round-3+ implication

ML-9..ML-14 parity-rod batches will need to rewrite paths in their imported `.nr` files. The mechanical transform is:

```
"examples/fixtures/<file>"   →   "tests/features/ml_fixtures/<file>"
```

This will be done per-batch in their respective branches. The integrator should NOT collapse these into one giant batch — keep per-domain (sklearn / PyTorch / transformer / NumPy / boosting / SciPy) for reviewability.

## Residuals

- None blocking ML-8 promotion. This is data-only.
- The `hf_tiny_model.safetensors.index.json` is a JSON descriptor, not the actual safetensors binary. The HF tiny model fixture is a manifest-only contract (matching the `nuc_hf_manifest_smoke` rod's claim scope: zero-Python-runtime, hub-download accounting, no native execution claim).

End of finding.
