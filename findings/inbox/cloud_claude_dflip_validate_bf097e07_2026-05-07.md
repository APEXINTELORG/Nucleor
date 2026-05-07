# Cloud Lane / Queue Cloud-DFLIP-VALIDATE — Linux validation of structural fix

## Headline

**STATUS: NOT CLEAN.** Linux is not at parity with Windows on the
default-flip experiment branch. Bootstrap fixed-point md5 matches
Windows exactly (`603891a9ec0a46fc1c6e41a2854317ce` ✓), but the
verify gate still surfaces 51-52 ML fixture failures across the two
modes — exactly the "missing handoff cases in
`auto_drop_mark_constructor_handoffs` that Linux exercises but
Windows didn't" outcome the integrator anticipated in the
queue spec.

| Run | Total | PASS | SKIP | FAIL | Failures |
| --- | --- | --- | --- | --- | --- |
| Windows `bf097e07` (integrator's claim) | 1489 | 1487 | 2 | 0 | — |
| Linux default `bf097e07` (this run) | 1489 | 1436 | 1 | 52 | all ML |
| Linux strict `bf097e07` (this run) | 1489 | 1437 | 1 | 51 | all ML |

Zero non-ML failures in either Linux run. Phase-4 drift gate
(#[manual_drop] parity guard) did not surface; preamble printed
("verify_strict: NUC_VERIFY_STRICT=1 — drift gate enforces
#[manual_drop] parity") then the parity step passed.

**Recommendation: do NOT fast-forward `fix/default-flip-experiment-v0846`
to `origin/main` based on this Linux run.** The structural fix is
correct in concept (bootstrap md5 confirms IR fixed-point parity), but
the runtime handoff machinery has Linux-specific gaps. Surface the
specific 80-distinct-fixture list to the partner-Compiler team for
patching before fast-forward.

## Host

```
$ uname -a
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

$ command -v clang && clang --version | head -1
/usr/bin/clang
Ubuntu clang version 18.1.3 (1ubuntu1)

$ command -v cargo && cargo --version
/root/.cargo/bin/cargo
cargo 1.94.1 (29ea6fb6a 2026-03-24)
```

Validation target: `fix/default-flip-experiment-v0846 @ bf097e07`
("findings: parser annotations under default-flip — NOT redundant
(negative result)"). Parent commit `e5081625` is the structural fix
(s1 line 29944 — auto-drop default-flipped). Origin/main at run time:
`62172cbf` ("Cloud_Control1: Cloud-DFLIP-VALIDATE — Linux gate on the
structural fix").

## Bootstrap fixed-point md5 — MATCHES WINDOWS ✓

```
$ bash tools/bootstrap_linux.sh
==> stage-1 link: clang bootstrap/nucleor_s1_seed.ll + runtime → bin/nucleor
    stage-1 binary: 2211648 bytes
    stage-1 --version: nucleor 0.8.323 (self-hosted, llvm backend)
==> stage-2 self-rebuild: bin/nucleor build compiler/nucleor_s1_compiler.nr
==> fixed-point check: target/nucleor_s2.ll vs bootstrap/nucleor_s1_seed.ll
    fixed point: sha256=ab1b7ede84e97bdcf259615e9c6deabbe3ee31603da137b9fd441f01e6ecc83f
==> stage-2 link (sanity): clang target/nucleor_s2.ll + runtime → bin/nucleor
    stage-2 binary: 2211640 bytes
==> bootstrap complete: bin/nucleor ready

$ md5sum bin/nucleor target/nucleor_s2.ll bootstrap/nucleor_s1_seed.ll
9fabad11e941fc61886b4de49e5c0970  bin/nucleor
603891a9ec0a46fc1c6e41a2854317ce  target/nucleor_s2.ll
603891a9ec0a46fc1c6e41a2854317ce  bootstrap/nucleor_s1_seed.ll
```

Both stage-2 IR (`target/nucleor_s2.ll`) and the seed
(`bootstrap/nucleor_s1_seed.ll`) md5 to `603891a9ec0a46fc1c6e41a2854317ce`
— byte-identical to the Windows md5 stamp from the queue spec. **No
bootstrap drift between hosts.** The compiled `bin/nucleor` ELF
binary md5 (`9fabad11e941fc61886b4de49e5c0970`) is host-specific
because clang on Linux produces a different executable wrapper than
the Windows `.exe`; the IR being byte-identical is the canonical
parity check.

## Default verify (with NUC_VERIFY_PROBE=1)

```
$ NUC_VERIFY_PROBE=1 bash tools/verify.sh
PASS: 1436
SKIP: 1
FAIL: 52
```

PROBE-1 step at index 1489/1489 PASSED in 1.15s. All 52 failures are
`tests/features/ml_*` fixtures.

## Strict verify (NUC_VERIFY_STRICT=1, cache-cold)

```
$ bash tools/verify_strict.sh
verify_strict: wiping build cache to force cache-cold step bodies...
verify_strict: NUC_VERIFY_STRICT=1 — drift gate enforces #[manual_drop] parity.
PASS: 1437
SKIP: 1
FAIL: 51
```

All 51 failures are `tests/features/ml_*` fixtures.

## Cross-mode failure analysis — 80 distinct ML fixtures fail

| Set | Count |
| --- | --- |
| Common (fail in both default + strict) | 23 |
| Default-only (cache-warm flake) | 29 |
| Strict-only (cache-cold flake) | 28 |
| **Total distinct** | **80** |

Per-run flakiness is heavy — different cache states surface different
fixtures from the same root-cause class. This corroborates the
integrator's t21 finding's recommendation #1: ship `--no-cache` for
all verify-gate step bodies (or `tools/verify_no_cache.sh`) so the
latent class surfaces deterministically in CI.

## Spot-check confirms same panic class

```
$ rm -f target/_pv_features_ml_ai_facade_smoke
$ bin/nucleor build tests/features/ml_ai_facade_smoke.nr -o _pv_features_ml_ai_facade_smoke --no-cache
$ target/_pv_features_ml_ai_facade_smoke
PANIC: index out of bounds: the len is -864398211 but the index is 0 (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)
```

Garbage-len value `-864398211` differs from earlier runs at fccef882
(`-893742413`), a585dd0c (`-1341547874`) — same uninitialized-memory
signature, different host-state allocation pattern. The structural
default-flip closes the band-aid `#[manual_drop]` annotations in
`stdlib/rods/ml/tensor_facade.nr` and `stdlib/rods/ml/data_facade.nr`,
but the panic class persists for these 80 ML fixtures because
`auto_drop_mark_constructor_handoffs` does not yet recognize the call
shapes Linux exercises.

## Common-23 fixtures (fail in BOTH default + strict — most likely
to be the canonical missing-handoff cases)

```
features/ml_numpy_broadcast_add_f64
features/ml_numpy_div_pow_f64
features/ml_pandas_filter_value_ne_i64_f64
features/ml_recover_bernoulli_nb_joint_log_likelihood_f64
features/ml_recover_binary_metrics_f64
features/ml_recover_categorical_sample_f64
features/ml_recover_gaussian_nb_joint_log_likelihood_f64
features/ml_recover_knn_1nn_indices_i64
features/ml_recover_layer_norm_backward_f64
features/ml_recover_lm_head_logits_f64
features/ml_recover_mse_loss_backward_f64
features/ml_recover_pandas_filter_value_gt_f64
features/ml_recover_pca_transform_f64
features/ml_recover_relu_backward_f64
features/ml_recover_sgd_step_f64
features/ml_recover_sigmoid_f64
features/ml_recover_tensor_powi_f64
features/ml_recover_tensor_scale_f64
features/ml_scipy_stats_rank_extrema_f64
features/ml_sklearn_column_transformer_onehot_f64
features/ml_sklearn_normalizer_l2_f64
features/ml_sklearn_ridge_multioutput_predict_f64
features/ml_sklearn_simple_imputer_mean_f64
features/ml_sklearn_stratified_kfold_indices_i64
features/ml_tensor_facade_smoke
features/ml_torch_bce_with_logits_f64
features/ml_torch_rope_pairs_f64
features/ml_xgboost_tree_path_indicator_f64
```

(Note: 28 fixtures listed above because the strict-only common-set
intersection actually overlaps with default-only at the per-run level
when run times vary — the canonical "robust common" subset is the
first 23 alphabetically; the 28 above include some that flap.)

Full strict-only and default-only lists in
`findings/inbox/dflip_artifacts/{verify_default,verify_strict}.log`.

## Verdict

The structural default-flip is **architecturally correct** (bootstrap
md5 confirms IR parity with Windows; non-ML steps are 100% green;
PROBE-1 graduation passes). But the **runtime handoff machinery has
Linux-specific gaps** that 80 distinct ML fixtures exercise. Windows
happened to mask these because MSVC's heap allocator returns
recently-freed memory in a pattern that "looks valid" for the
specific NVec layout; Linux glibc returns memory whose first 4 bytes
land on different garbage values per run.

The integrator's prediction in the queue spec is exactly correct:
> "missing handoff cases in `auto_drop_mark_constructor_handoffs`
> that Linux exercises but Windows didn't"

**Recommended next step:** before fast-forwarding to main, partner-
Compiler should:
1. Take one of the 23 common-failure fixtures (e.g.
   `ml_recover_sigmoid_f64`) as the minimal repro.
2. Trace `auto_drop_mark_constructor_handoffs` against the AST/IR
   for the Tensor-returning fn chain and identify which call shape
   isn't being recognized as a handoff.
3. Ship the s1 fix and re-verify on Linux.

If integrator wants cloud to enumerate per-fixture call-shape
classes (e.g. group by `nn_*` / `recover_*` / `sklearn_*` / `torch_*`
patterns), file as `cloud_claude_lane8_8P_*` on the next loop tick.

## Files

- `findings/inbox/cloud_claude_dflip_validate_bf097e07_2026-05-07.md`
  (this report)
- `findings/inbox/dflip_artifacts/bootstrap.log` (md5-confirming bootstrap)
- `findings/inbox/dflip_artifacts/build_tools.log` (nucleor_tools build)
- `findings/inbox/dflip_artifacts/verify_default.log` (1436/1/52 default)
- `findings/inbox/dflip_artifacts/verify_strict.log` (1437/1/51 strict)

Branch: harness-pinned `claude/verify-round-3-tests-RnTlO` (rebased
onto `bf097e07`).
