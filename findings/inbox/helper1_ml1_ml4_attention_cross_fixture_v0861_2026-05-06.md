# Helper1 ML-1 / ML-4 Attention Cross-Attention Fixture v0861

## Summary

Confirmed and fixture-backed the corrected attention2 split-length ABI:

- `nuc_attn_flash(Q,K,V,seq_q,seq_k,d,block)` uses separate query/key lengths.
- `attn_flash_cross(...)` exposes rectangular flash attention publicly.
- `attn_gqa_cross(...)` exposes rectangular GQA publicly.

This removes the old ML-1/ML-4 launch-blocker shape for the current helper
branch: the rod no longer has the 6-arg/7-arg flash-attention arity drift, and
callers have a direct cross-attention wrapper.

## Evidence

Focused fixture:

- `tests/features/attention2_cross_attention_smoke.nr`

The fixture calls live attention kernels and checks numeric outputs:

- Flash cross-attention with `seq_q=1`, `seq_k=3`, `d=1`, zero Q/K, and
  V values `[3,6,9]` returns the uniform mean `6`.
- GQA cross-attention with `seq_q=1`, `seq_k=2`, `head_dim=1`, two Q heads,
  one KV head, zero Q/K, and V values `[3,5]` returns `4` for both Q heads.

## Residual Gaps

- This does not address ML convergence tests, autodiff/NN bridge, or GPU
  dispatch. Those remain separate ML stack depth items.
- The fixture covers deterministic tiny tensors, not large tiled numerical
  stress cases.

## Files Changed

- `tests/features/attention2_cross_attention_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
