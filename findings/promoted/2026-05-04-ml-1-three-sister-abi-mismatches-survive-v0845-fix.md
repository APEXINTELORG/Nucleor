---
title: ML-1 sister findings — three more attention2 rod externs still ABI-mismatched after v0.8.45 fix (gqa, mla_compress, mla_decompress)
severity: silent-miscompute
probe_file: probes/ml/ml_1_attn_audit.txt (table; rods/attention2.nr is uncallable from .nr without C-side helpers)
diagnostic_actual: build success; ABI parity check absent; silent miscompute on every gqa / mla_compress / mla_decompress call.
diagnostic_expected: arity-mismatch compile error OR runtime ABI parity gate firing per RFC ML-1 Phase 2b
discovered_against: v0.4.180 binary against origin/main source v0.8.45 (24f1770c)
commit: 53af3b53 (probe), 24f1770c (origin/main)
status: NEW (ML-1 main case is closed v0.8.45; THREE sister cases still live on main)
---

## Summary

`v0.8.45` (commit `24f1770c`) closed ML-1 for `nuc_attn_flash` only. The same audit applied to the rest of `stdlib/rods/attention2.nr` shows **three more silent ABI mismatches** between rod externs and the C runtime: `nuc_attn_gqa`, `nuc_attn_mla_compress`, `nuc_attn_mla_decompress`. Each is the same failure class — caller passes N args, callee reads M args, the disagreement is silent at the LLVM level because every parameter is `long long`. No linker error; no diagnostic; runtime miscomputes.

## Audit table — current `origin/main` source

| Function | Rod extern arity (`stdlib/rods/attention2.nr`) | C arity (`stdlib/runtime/attention2_rt.c`) | Match |
|---|---|---|---|
| `nuc_attn_flash`           | 7 — Q,K,V,seq_q,seq_k,d_k,block_size  | 7 — Q,K,V,seq_q,seq_k,d,block_size | ✅ (fixed v0.8.45) |
| `nuc_attn_gqa`             | 7 — Q,K,V,**seq_len**,d_model,n_q,n_kv | 8 — Q,K,V,**seq_q,seq_k**,head_dim,n_q,n_kv | ❌ MISMATCH |
| `nuc_attn_mla_compress`    | 5 — h,W_down,**seq_len**,d_model,d_latent | 4 — h,W_down,d_model,d_latent | ❌ MISMATCH |
| `nuc_attn_mla_decompress`  | 5 — lat,W_up,**seq_len**,d_latent,d_model | 4 — lat,W_up,d_latent,d_out | ❌ MISMATCH |
| `nuc_attn_sliding_window`  | 6 — Q,K,V,seq_len,d_k,window | 6 — Q,K,V,seq_len,d,window_size | ✅ |
| `nuc_attn_differential`    | 6 — Q,K,V,seq_len,d_k,lambda_bits | 6 — Q,K,V,seq_len,d,lambda_bits | ✅ |

## Per-mismatch hazard

### `nuc_attn_gqa`

Rod call: `nuc_attn_gqa(Q, K, V, seq_len, d_model, n_q, n_kv)` — 7 args.
C function reads: `(Q, K, V, seq_q=seq_len, seq_k=d_model, head_dim=n_q, n_q_heads=n_kv, n_kv_heads=UNINIT)`.

Result: `seq_k`, `head_dim`, `n_q_heads` all silently misassigned; `n_kv_heads` reads whatever the calling stack frame left in the next argument register / slot. The function loops up to `nq * sk * sq` and dereferences into `Q/K/V` with the wrong dimensions — almost certainly heap OOB, intermittent crash, or wrong tensor shape.

Detection by adopter: only via comparison against a reference implementation. There is no test in `tests/rods/` that calls `nuc_attn_gqa` (build-only smoke pattern), so silent in CI.

### `nuc_attn_mla_compress`

Rod call: `nuc_attn_mla_compress(h, W_down, seq_len, d_model, d_latent)` — 5 args.
C function reads: `(h, W_down, d_model=seq_len, d_latent=d_model)` and the rod's `d_latent` is dropped on the floor.

Result: C uses `seq_len` as the `d_model` dimension and `d_model` as `d_latent`. The compressed-latent allocation `a2vec_new(seq * dl)` ends up sized as `seq_len * d_model` instead of `seq_len * d_latent` — wrong shape, wrong write count, almost certainly heap OOB on subsequent decompress.

### `nuc_attn_mla_decompress`

Same shape: rod has 5 args, C has 4. Rod's `seq_len` passed as the C `d_latent`; C `d_out` reads what the rod intended as `d_model` — meaning the dimensions are scrambled and the produced tensor has wrong shape.

## Repro design (cannot live-exec without C glue)

The `attention2` rod surface is callable only from `.nr` via the wrapper functions (`attn_flash`, `attn_gqa`, etc.) and the C-side `A2Vec *` handles. There is no `.nr`-level constructor for `A2Vec`; the type is purely C-internal. **This means a probe cannot build a Q/K/V handle from `.nr` alone.** Every existing rod test (`tests/rods/attention2_smoke.nr`) is a build-and-print-OK smoke that never invokes the function. RFC's note "All ML rod tests are link-and-return tests" applies.

So the repro here is structural (source-side audit), not runtime-trace. The arity mismatch is mechanically demonstrable from the .nr declaration vs the C function definition. `objdump -d` of any program that calls these would show 7 `mov`s into argument registers when the C function reads 8 — proof at the assembly level.

To make this live-testable in CI:

1. Add `.nr`-level helpers `a2vec_new`, `a2vec_push`, `a2vec_get` as `extern fn` declarations in `attention2.nr` (forward to existing static C symbols, made non-static).
2. Write a fixture that builds a known Q/K/V, calls each variant, and asserts a known-output property (e.g., self-attention with identity Q=K=V returns its V input within softmax tolerance).
3. ABI parity gate at compile time: emit warning when an `extern fn` declaration's parameter count differs from the C function's parameter count in any `#cfile`-included translation unit. (RFC ML-1 Phase 2b "helper-manifest ABI parity gate.")

## Severity

**silent-miscompute** — same class as the original ML-1, same root cause, same risk profile (every adopter-call returns wrong tensor shape with no signal). The original ML-1 fix did not generalize because the v0.8.45 patch was a hand-edit to the single `nuc_attn_flash` line. RFC's Phase 2b "helper-manifest ABI parity gate" is precisely what would have caught all four at once — none of these would survive a mechanical name-and-arity match between externs and C definitions.

For an adopter wiring up an LLM (DeepSeek MLA, LLaMA GQA), three of the four production-attention shapes silently miscompute. Strict launch-blocker.

## Suggested fix

**Phase 1 (immediate, by-hand):** Patch the three remaining extern decls to match the C runtime:

```nr
extern fn nuc_attn_gqa(Q_h: i64, K_h: i64, V_h: i64, seq_q: i64, seq_k: i64, head_dim: i64, n_q_heads: i64, n_kv_heads: i64) -> i64;
extern fn nuc_attn_mla_compress(hidden_h: i64, W_down_h: i64, d_model: i64, d_latent: i64) -> i64;
extern fn nuc_attn_mla_decompress(latent_h: i64, W_up_h: i64, d_latent: i64, d_out: i64) -> i64;
```

Update wrapper functions (`attn_gqa`, `attn_mla_compress`, `attn_mla_decompress`) to forward correct arguments. Mirror the v0.8.45 ship template (split self-attention vs cross-attention helpers if needed).

**Phase 2 (the actual ML-1 closure):** Implement RFC ML-1 Phase 2b helper-manifest ABI parity gate. The compiler already has `#cfile` ingestion; add a parser pass that extracts C function signatures and compares with `extern fn` declarations from the same rod. Emit `ML-G1` diagnostic on any mismatch. This eliminates the entire bug class.

**Phase 3 (test discipline):** Replace every "build-only" rod smoke test with an actual end-to-end fixture that calls the rod with known input and asserts a property. RFC ML-13.

## Cross-ref

- v0.8.45 ML-1 fix: commit `24f1770c`
- RFC: `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md` ML-1 (Phase 2b ABI parity gate)
- Related cross-cutting ML-13 (no convergence test) — same diagnostic blind spot is what made all 4 mismatches CI-invisible
- Source: `stdlib/rods/attention2.nr:21-23`, `stdlib/runtime/attention2_rt.c:128/178/197`

## Notes

Recommend extending the audit to ALL `extern fn` declarations across the rod stack. Likely-affected priority files (each exposes 5+ externs to C runtimes):

- `stdlib/rods/ssm.nr` ↔ `stdlib/runtime/ssm_rt.c` (Mamba/RWKV — RFC ML-5 already calls out missing backward, but ABI parity not audited)
- `stdlib/rods/moe.nr` ↔ `stdlib/runtime/moe_rt.c`
- `stdlib/rods/quantize.nr` ↔ `stdlib/runtime/quantize_rt.c`
- `stdlib/rods/kv_cache.nr` ↔ `stdlib/runtime/kv_cache_rt.c`
- `stdlib/rods/diffusion.nr` ↔ `stdlib/runtime/diffusion_rt.c`
- `stdlib/rods/rl.nr` ↔ `stdlib/runtime/rl_rt.c`

If main agent prioritizes Phase 1 hand-edits per-mismatch, the hand-audit cost grows linearly with rod count. Phase 2b helper-manifest ABI parity gate is the high-leverage single-fix that closes them all.
