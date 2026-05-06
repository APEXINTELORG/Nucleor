# Helper1 ML-10 Transformer Causal + Encoder-Decoder Attention v0863

## Summary

Closed the stdlib/runtime/test/doc portion of ML-10:

- `tf_attention_causal(Q,K,V,seq_len,d_k)` exposes GPT-style causal
  self-attention.
- `tf_attention_split_masked(..., causal)` and
  `tf_multihead_split_masked(..., causal)` expose a mask flag while preserving
  the existing non-breaking `tf_attention` / `tf_attention_split` APIs.
- `tf_encoder_decoder_block(...)` composes causal decoder self-attention with
  cross-attention over encoder memory.

This gives the classic transformer rod a direct decoder/cross-attention path
instead of requiring adopters to hand-roll masks outside the kernel.

## Evidence

Focused fixture:

- `tests/features/transformer_causal_encoder_decoder_smoke.nr`

The fixture checks callable behavior:

- Causal self-attention with zero Q/K and V `[3,6,9]` returns prefix means
  `[3,4.5,6]`.
- Mask flag `0` returns full bidirectional attention mean `[6,6,6]` for the
  same zero-score input.
- Encoder-decoder block with one target token and two encoder-memory values
  `[2,4]` returns the memory mean `3`.

## Residual Gaps

- This is an attention block, not a full trainable encoder-decoder layer with
  projections, residuals, feed-forward, and optimizer-owned parameters.
- Large-shape numerical stress and convergence tests remain ML-13 work.

## Files Changed

- `stdlib/runtime/transformer_rt.c`
- `stdlib/rods/transformer.nr`
- `tests/features/transformer_causal_encoder_decoder_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
