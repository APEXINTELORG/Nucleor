# Nucleor — Tensor / ML / Autodiff Stack Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS`.

---

# Part I — Definition

## 1.1. The ML pillar

Tensor + autodiff + GNN + attention + SSM + transformer + KV cache + quantize + diffusion + RL form Nucleor's domain stdlib for machine learning. The MLV/MGN/Aurora projects in adjacent work demonstrate Nucleor can support real ML; this audit asks whether the stdlib backing them is correct and complete.

**Headline finding 1: ABI mismatch in `attention2.nr` flash attention is a silent miscompute.** Rod extern declares 6 args, C runtime takes 7 (seq_q and seq_k split). Tests are build-only smokes that don't call the function. **Production calls would silently pass `block_size` as `d` and leave `block_size` uninitialized.**

**Headline finding 2: All ML rod tests are link-and-return tests, not convergence tests.** No test trains a model and verifies loss decreases or accuracy rises. Correctness of backprop, Adam, gradient zeroing, forward-backward interleaving — all assumed.

**Headline finding 3: No GPU dispatch in the core ML path.** `gpu.nr` is a sequential CPU stub. CUDA exists only in `quantum_rt.c`. The entire ML stack is CPU-only despite GPU-shaped APIs.

---

# Part II — Gap Inventory

## ML-1 — ABI mismatch on `nuc_attn_flash` is silent miscompute — **CRITICAL**
Rod declares 6 params (Q, K, V, seq_len, d_k, block_size). C function takes 7 (Q, K, V, seq_q, seq_k, d, block_size). Rod collapses seq_q/seq_k into seq_len. **Caller passes `block_size` as `d`; C `block_size` slot uninitialized.** No linker error because all params are `long long`. Test (`attention2_smoke.nr`) doesn't call the function at all.

## ML-2 — `tensor_nd` missing 2D matmul — **HIGH**
Exports `tensor_bmm` (rank-3 batched) but no `tensor_matmul` for standard A×B. Classic MLP, attention QKV projection, feedforward forward all require it. Callers must use `linalg.nr`, breaking abstraction.

Update 2026-05-06 helper1 v0856: `tensor_new_2d` and `tensor_matmul` are now shipped for rank-2 tensors with incompatible-shape return `0` behavior locked by `tests/features/tensor_nd_matmul_transpose_smoke.nr`.

## ML-3 — `tensor_nd` missing transpose — **HIGH**
No `tensor_transpose` or `tensor_permute`. K^T in attention, weight transpose in backprop, CP factor permutation all require it. Combined with ML-2, tensor_nd structurally incomplete for matmul-heavy workloads.

Update 2026-05-06 helper1 v0856/v0857: `tensor_transpose` is now shipped for rank-2 tensors and covered by `tests/features/tensor_nd_matmul_transpose_smoke.nr`; `tensor_permute` is now shipped for arbitrary-rank tensor axes and covered by `tests/features/tensor_nd_permute_smoke.nr`.

## ML-4 — Attention2 flash: seq_q vs seq_k unification — **HIGH**
Even when ML-1 ABI is fixed, rod surface has no way for callers to specify rectangular attention (seq_q ≠ seq_k). Cross-attention (decoder over encoder) unsupported.

## ML-5 — SSM rods: no backward / gradient paths — **HIGH**
`ssm.nr` exposes forward kernels only. Training Mamba/RWKV/xLSTM requires backward through selective scan and WKV recurrences. None exist in `ssm_rt.c`. Training loop using `autodiff.nr` cannot differentiate through these kernels (opaque C functions not on autodiff tape).

## ML-6 — Quantize: no FP8 gemv / no grouped quantization — **HIGH**
`nuc_quant_fp8_encode` exists but no `nuc_quant_fp8_gemv` or `_dot`. **FP8 path is encode-only; no inference possible with FP8 weights.** No grouped (per-group-of-N) quantization surface — standard format for GPTQ-style 4-bit inference (which the MLV project uses).

## ML-7 — Quantize: no dequant for int8 and ternary — **MEDIUM**
`nuc_quant_int8_encode` and `nuc_quant_ternary_encode` have no decode. Only inference path is `_gemv`. No way to inspect quantized weights or re-dequantize for mixed-precision.

## ML-8 — `nn.nr` no convolutional layers — **MEDIUM**
Dense layers only. No Conv1d/Conv2d/depthwise-separable. Separate `conv.nr` is image-processing convolution, not learnable layer with weight gradients.

## ML-9 — `nn.nr` no batch norm / no learnable layer norm — **MEDIUM**
No `batch_norm`/`layer_norm` forward+backward in nn.nr. `gnn_layer_norm` and `tf_layer_norm` exist but forward-only (no gradient). **No training-capable norm layer anywhere.**

## ML-10 — Transformer: no causal mask / no encoder-decoder — **HIGH**
`tf_attention` computes full bidirectional only. Building GPT-style decoder requires manual masking outside kernel, not composable with attention2.

## ML-11 — IR `attention()` → `flash_attention` rewrite confirmed absent — **MEDIUM**
V2/Copy claim not ported to OSS. `source_call_graph` exists for analysis only. **No pass walks call graph looking for `nuc_tf_attention` and substitutes `attn_flash`.** Cross-references graph remediation Tier 4 decision.

## ML-12 — GPU: CPU-fallback stub, no CUDA dispatch for ML — **HIGH**
`gpu.nr` sequential CPU. `quantum_rt.c` has CUDA but no `nn_cuda_rt.cu`/`attn_cuda_rt.cu`. **Entire ML stack runs on CPU.** Expected as v1 boundary but needs clear documentation.

## ML-13 — No end-to-end convergence test — **HIGH**
Every ML rod smoke test is "compile + non-null handle + print OK." Example `12_autodiff.nr` computes gradient at single point but no tolerance. **No test trains model on data and asserts loss decreases or accuracy passes threshold.** Correctness of backprop, Adam, gradient zeroing untested at functional level.

## ML-14 — Autodiff not composable with rod kernels — **HIGH**
`autodiff.nr` uses flat global tape with handle-based nodes. `nn_rt.c` implements own internal gradient accumulation. **Two systems entirely separate** — no bridge that registers `nuc_nn_dense_forward` as differentiable op on the autodiff tape. User cannot build `loss = cross_entropy(nn_forward(x), target); ad_grad(loss, x)` because dense layer is not a tape node.

## ML-15 — `tensor_nd` no dtype: all values are f64 bitcast i64 — **MEDIUM**
`static double _i2f(long long x)` everywhere. No int tensor, bool mask tensor, mixed-precision path. Token ID tensors for embedding lookup are f64-cast i64, not native i32/i64.

## Cross-cutting risks
- **Correctness vs shape-checking.** Every ML rod test is build-smoke or null-handle check. Functional correctness assumed rather than verified across `gnn`/`ssm`/`moe`/`attention2`/`kv_cache`/`quantize`/`diffusion`/`rl`. RFC-0061 fixture wraps calls in `if 0 == 1` — bodies are dead code.
- **ABI mismatch as silent miscompute.** ML-1 will not produce linker error because all params are `long long`. Test passes all current CI.
- **GPU absent in core ML path.** Throughput claim CPU-only. `gpu.nr` falls back silently.
- **Autodiff isolation** (ML-14) creates conceptual cliff for users expecting PyTorch-style composition.
- **No convergence oracle** (ML-13) means regressions in Adam, gradient accumulation, or Xavier seeding would be invisible until adopter builds real model and observes divergence.

---

# Part III — RFC

## 3.1. Goals
1. Fix ML-1 ABI mismatch IMMEDIATELY — silent miscompute is the worst class of bug.
2. Add real convergence tests for the ML rods.
3. Bridge `autodiff` and `nn` so they compose.
4. Add the missing kernels (matmul, transpose, FP8 gemv, BN, causal mask).
5. Real GPU dispatch for ML, or honest disclosure of CPU-only.

## 3.2. Closure plan

**Phase 1 (emergency, ABI + audit):**
- ML-1: fix `attention2.nr` extern declaration to match C signature (7 params with seq_q/seq_k split). Add fixture test that actually CALLS the function with known input and asserts output. Audit every other extern in the rod stack for arity mismatches.
- ML-13 P1: add convergence test for `nn.nr`: 2-layer MLP on XOR, 1000 Adam steps, assert loss < 0.01. If this fails, the entire training surface is broken and we don't know it.
- ML-15 P1: document the f64-bitcast-i64 limitation in `tensor_nd` doc header.

**Phase 2 (short-term, missing kernels):**
- ML-2: add `tensor_matmul(A, B) -> C` for 2D case. **Shipped helper1 v0856 for rank-2 tensors.**
- ML-3: add `tensor_transpose(A) -> A^T` and `tensor_permute(A, axes)`. **2D transpose shipped helper1 v0856; general permute shipped helper1 v0857.**
- ML-4: add seq_q/seq_k separate parameters to `attention2.nr` for cross-attention.
- ML-6 P2: add `nuc_quant_fp8_gemv` and `nuc_quant_fp8_dot`. Add grouped quantization with per-group scales (matches GPTQ format used in MLV).
- ML-7: add decode for int8 and ternary.
- ML-9: add `batch_norm` and `layer_norm` with backward in `nn.nr`.
- ML-10: add causal mask parameter to `tf_attention`. Add encoder-decoder transformer block.
- ML-13 P2: add convergence tests for GNN (small node-classification task), SSM (sequence prediction), transformer (small LM training).

**Phase 3 (medium-term, integration):**
- ML-5: add backward passes for SSM kernels (Mamba, RWKV, xLSTM). Wire into autodiff tape.
- ML-8: add Conv1d and Conv2d learnable layers in `nn.nr`.
- ML-14: implement bridge between `autodiff` tape and `nn` rod. Each NN layer becomes a registered op on the autodiff graph. `loss = cross_entropy(nn_forward(x), y); ad_grad(loss, x)` works.
- ML-15 P2: add int tensor and bool mask tensor types to `tensor_nd`. Mixed-precision path.

**Phase 4 (v1.0 gate):**
- ML-11: graph-aware optimizer pass for `attention()` → `flash_attention` rewrite. Cross-references graph remediation Tier 4.
- ML-12: real CUDA dispatch for ML kernels. `tensor_matmul`, `attention`, `nn_dense_forward` all get GPU implementations behind `gpu.nr` API. Or, explicit "CPU-only in v1.0; CUDA in v1.x" disclosure in README.

## 3.3. v1.0 release gate
Phase 1 IMMEDIATELY (silent miscompute is the worst class). Phase 2 minimum for v1.0. Phase 3 strongly preferred. Phase 4 acceptable as v1.x with CPU-only disclosure.

## 3.4. Open questions
1. Should ML-14 bridge use registered ops (each layer = one tape node) or per-op (each operation inside the layer = tape node)? Recommendation: registered ops — fewer tape entries, better performance.
2. ML-11 graph rewrite — wait for the graph remediation Tier 4 decision, or proceed? Recommendation: wait. The decision affects how the rewrite is structured.
3. ML-12 CPU-only disclosure vs CUDA push — depends on adoption priority. Quick win is disclosure; long term is real GPU.

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
