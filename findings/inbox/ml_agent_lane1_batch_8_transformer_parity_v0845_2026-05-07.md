# ML Suite transformer parity rod batch — Queue ML-11

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: fix/ml-11-batch-8-transformer-parity-rods-v0845 (from origin/main HEAD)

## Headline

Lands **4 of 23 transformer/AI parity rods** at the 30-run stability bar. **19 deferred** — every multi-head attention, transformer-block, and decoder-generation rod exhibits the latent runtime UB documented in ML-9 / ML-10. The deeper kernel paths (scaled dot-product attention, KV cache, generation loops, top-p sampling) are extremely sensitive to the canonical-0.8.323 issue.

| | Count |
|---|---:|
| Candidates | 23 (`examples/ai_mvp/torch_*.nr` from master) |
| Build clean | 23/23 |
| 30-run stable | **4/23** |
| Deferred | 19/23 |

## Ship-ready (4)

| Rod | Surface |
|---|---|
| `ml_torch_append_next_token_i64` | `torch.cat([token_ids, next_tokens], dim=1)` parity |
| `ml_torch_last_token_i64` | `token_ids[:, -1:]` slicing parity |
| `ml_torch_rope_pairs_f64` | pairwise RoPE rotation w/ cos/sin tables |
| `ml_torch_token_position_embedding_f64` | token-embedding + position-embedding sum |

Note these are 3 i64 / 1 simple-f64 ops — the simplest of the AI tier. They don't trigger the multi-step state UB.

## Deferred (19) — full attention / generation / decoder paths

| Category | Rods deferred |
|---|---|
| Attention | scaled_dot_product_attention, multi_head_attention, kv_cache_append_attention |
| Activation/MLP | swiglu_feed_forward, rmsnorm_swiglu_feed_forward_block |
| Transformer blocks | transformer_self_attention_block, transformer_multi_head_block, transformer_feed_forward_block, transformer_decoder_layer |
| LM head + sampling | last_hidden_lm_head, embedding_lm_head_greedy, temperature_softmax_topk, top_p_filter, categorical_sample |
| Decode/generate steps | embedding_lm_head_sample_step, embedding_lm_head_decode_step, embedding_lm_head_generate, embedding_decoder_lm_head_greedy_step, embedding_decoder_lm_head_generate_greedy |

The deferred set covers PyTorch parity for the entire LLM inference wedge. Restoration here would be the highest-leverage Nucleor-language fix; ML Suite's Phase 5 (LLM inference MVP) is the v1 product wedge per SPEC §1.

## Build / drift

- 23/23 build clean (`bin/nucleor.exe build --no-cache`).
- 4/4 stable across 30 consecutive runs.
- Drift gate clean.

## Files

```
A  tests/features/ml_torch_append_next_token_i64.nr
A  tests/features/ml_torch_last_token_i64.nr
A  tests/features/ml_torch_rope_pairs_f64.nr
A  tests/features/ml_torch_token_position_embedding_f64.nr
A  findings/inbox/ml_agent_lane1_batch_8_transformer_parity_v0845_2026-05-07.md
```

End of finding.
