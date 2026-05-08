# Lane 5 — Stdlib Correctness (math + robotics + quantum + FFI)

**Branch:** `fix/audit-lane-5-stdlib-correctness-2026-05-08`
**Theme:** Close stubs, fix wrong-result computations, encapsulate FFI leaks. The "stdlib silently miscomputes" cluster.

## In-scope findings

### Critical (5)
- **Layer 9a / F-MATH-001** — TT-SVD is a stub; `nuc_td_tt_svd_3d_max_rank` returns identity matrices. C comment admits "proper impl would use SVD" but never does.
- **Layer 9a / F-MATH-003** — `nuc_ridge_predict` silently clips outputs to [0,1]. Wrong for unbounded targets.
- **Layer 9a / F-MATH-027** — `nuc_t3_slice` reads past buffer end (no bounds check).
- **Layer 9b / CRIT-9B-001** — URDF default joint axis is `(0,0,1)` but URDF spec mandates `(1,0,0)`. `stdlib/runtime/urdf_rt.c:264`. Every URDF lacking explicit `<axis>` produces wrong FK end-effector poses.
- **Layer 9b / CRIT-9B-002** — `tests/rods/rust_interop.nr` leaks Rust-side `CString` allocations (test never calls `rust_free_str`).

### High (12)
- **Layer 9a / F-MATH-002** — CP-ALS uses diagonal-only solve, not pseudoinverse
- **Layer 9a / F-MATH-004** — `nuc_mat_rank` leaks SVD U/S/V/EigResult on every call
- **Layer 9a / F-MATH-005** — `nuc_mat_eig` Jacobi only (symmetric); accepts non-symmetric → wrong eigenvalues
- **Layer 9a / F-MATH-011 / F-MATH-012** — `kmeans_f64_predict` and `decision_tree_classifier_predict_i64` known-broken; PROBE-2 pipelines bypass them
- **Layer 9a / F-MATH-025** — QR Householder skips iterations on `norm < 1e-15` but doesn't zero Q → Q*R ≠ A on rank-deficient input
- **Layer 9b / qsim qubit-cap inconsistency** — qsim 24, qsim_graph 1024, trace 32
- **Layer 9b / qsim_swap** — triple-counts entanglement via 3-CNOT decomposition
- **Layer 9b / CNOT** — registers false entanglement when control is |0⟩
- **Layer 9b / URDF parser** — silently absorbs siblings on missing `</joint>` close tag
- **Layer 9b / sparsity threshold** — mixes `|amp|²` with `|amp|` (units mismatch)

### Medium (10+)
- **Layer 9a** — Bernoulli NB log(1-exp(pos_log_prob)) blows up near 1; standard_scaler equality test for zero variance; learn_f64_sqrt_newton convergence; shape-mismatch silent truncation in FFT/loss; target-index bounds checks missing in cross_entropy/focal/label_smooth
- **Layer 9b** — IK `_quat_log_map` lacks qw<0 short-arc canonicalization; IK joint-limit global table leaks across freed FK chain handles; MPS Jacobi SVD 100-sweep cap with silent non-convergence; `qsim_measure` divides by `sqrt(0)` without guard; SE(3) distance mixes meters+radians without weight; TF time-stamped lookup refuses out-of-range stamps with no extrapolation

## Source-of-truth findings docs
- `docs/audit/findings/audit_recon_pass1_stdlib_math_2026-05-08.md`
- `docs/audit/findings/audit_recon_pass1_stdlib_robo_quantum_ffi_2026-05-08.md`

## Strategy

### Math rods
1. **TT-SVD real implementation.** Use the existing `nuc_mat_svd` helper (or add one); two unfoldings + two SVDs to get G1, G2. Test against known TT decomposition.
2. **Ridge predict unbounded.** Remove the `[0,1]` clip; ridge regression should return the linear prediction unmodified. If the consumer wants clipping, that's a downstream choice.
3. **t3_slice bounds.** Add `idx < len` guard like sibling accessors.
4. **CP-ALS pseudoinverse.** Replace diagonal "solve" with full pseudoinverse via SVD or normal equations + lstsq.
5. **mat_rank leak.** Free U, S, V, EigResult before returning.
6. **mat_eig non-symmetric.** Either: (a) error out with `MAT-EIG-NOT-SYMMETRIC` for non-symmetric, OR (b) implement Schur decomposition / QR iteration. (a) is cheaper and correct.
7. **kmeans / dt_predict reanimation.** Per the PROBE-2 comment, the structural DFLIP-PATCH didn't fully close. Investigate the residual UB, fix, re-enable. Coordinate with Lane 2 since this overlaps with memory safety.
8. **QR rank-deficient.** When `norm < 1e-15` (rank-deficient column), zero out the corresponding Q column.

### Robotics
9. **URDF default axis.** Change default to `(1,0,0)` per spec. Add a regression test with a real URDF (or a synthetic one) that doesn't specify `<axis>`.
10. **URDF parser robustness.** On unclosed `<joint>`, emit `URDF-PARSE-001: unclosed <joint> tag at line N` rather than silently absorbing siblings.
11. **IK quat short-arc.** Canonicalize `qw < 0` → `q = -q` before log map.
12. **IK joint-limit table lifecycle.** Tie joint-limit storage to the FK chain handle's lifetime; free on chain free.
13. **SE(3) distance weight.** Document the weight semantics OR add a default that's reasonable for typical robotics use; never just sum meters and radians.
14. **TF extrapolation.** When time stamp is out-of-range, pick: linear extrapolation, last-known, or explicit error. Document and stick.

### Quantum
15. **Qubit-cap consistency.** Pick a single cap (likely 24 for state-vector, with documented MPS upper bounds for sparse). Make qsim/qsim_graph/trace agree.
16. **qsim_swap correct entanglement accounting.** Don't triple-count via 3-CNOT decomposition. Implement SWAP as primitive.
17. **CNOT control |0⟩ no entanglement.** When control is |0⟩, no entanglement should be registered. Fix entanglement tracking logic.
18. **Sparsity threshold |amp|².** Standardize on `|amp|²` (probability) or `|amp|` (amplitude); fix the mixed comparison. Probability is conventional.
19. **MPS Jacobi 100-sweep.** Increase cap or add convergence-failure diagnostic. Silent non-convergence is unacceptable.
20. **qsim_measure /sqrt(0) guard.** When norm is zero, error out with `QSIM-MEASURE-001: zero-norm state`.

### FFI
21. **rust_interop test fix.** Add `rust_free_str(ptr)` calls for every CString returned. Add a comment documenting the contract.
22. **rust_bridge regex pin.** Change Cargo.toml `regex = "1"` to `regex = "1.10"` (or current stable minor) for supply-chain hygiene.
23. **direct_ffi enforcement upgrade.** v1.0 has it as info-warning per compiler comments. Coordinate with Lane 6 for the post-v1.0 hardening — Lane 5 just adds the `#[may_return_null]` annotations to the Rust bridge externs as preparation.

## Test mandate

- Math: differential against numpy/scipy for SVD, FFT, eigen, linear regression; sklearn for kmeans/dt; pass tolerance documented per op
- Robotics: URDF with no `<axis>` should produce correct FK; joint-limit lifecycle test (alloc, free, alloc again — no leak); IK convergence test
- Quantum: Bell state amplitude; GHZ for 3 qubits; entanglement-detection cases
- FFI: rust_bridge round-trip without leaks (use a memory-pressure smoke test that calls 100K times — should not OOM)

## Verify policy

Run `bash tools/verify.sh` ONCE at end. Re-bootstrap not expected (this lane is mostly stdlib + runtime helpers, not compiler).

## Hard constraints

- Same as other lanes.
- For each math fix, document the numerical tolerance achieved against the reference.

## Output

- Branch + report `docs/audit/lanes/LANE_5_REPORT.md`.
