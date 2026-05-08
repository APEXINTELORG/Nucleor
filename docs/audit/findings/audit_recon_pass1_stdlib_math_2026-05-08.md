# RECON Pass-1 Audit — Stdlib Math Rods (Layer 9a)

**Date:** 2026-05-08
**Scope:** Linalg / Tensor / FFT / ML / numerical solvers / Bayesian
**Binary:** `bin/nucleor.exe` v1.0 (path: `Nucleor_OSS_integrate_r05_with_row_v0842`)
**Methodology:** Source-level review of rod (.nr) public APIs and runtime (_rt.c) implementations, cross-checked against numpy/sklearn semantics. NO source modifications. NO verify.sh.
**Out of scope:** SI units (Layer 8), robotics/quantum/FFI (Layer 9b), runtime ABI (Layer 7).

## Inventory

Math/ML rods discovered:

| Rod | Type | Runtime | Notes |
|---|---|---|---|
| `stdlib/rods/linalg.nr` (145 lines) | Dense linalg | `linalg_rt.c` (525 LOC) + `tensor_rt.c` | LU/QR/Cholesky/Eig/SVD, ridge |
| `stdlib/rods/fft.nr` (21 lines) | FFT | `fft_rt.c` (231 LOC) | radix-2 Cooley-Tukey, conv, corr, power |
| `stdlib/rods/tensor_decomp.nr` (36 lines) | CP/TT/Kron/KhatriRao | `tensor_decomp_rt.c` (262 LOC) | |
| `stdlib/rods/tensor_nd.nr` (142 lines) | N-D tensors | `tensor3d_rt.c` (540 LOC) | |
| `stdlib/rods/bayesian.nr` (42 lines) | MCMC | `bayesian_rt.c` (185 LOC) | |
| `stdlib/rods/ml/learn_facade.nr` (2980 lines) | Pure-Nucleor ML predict surface | (none — all .nr) | LinReg, LogReg, Ridge, KMeans, PCA, GaussianNB, MultinomialNB, BernoulliNB, kNN, DecisionTree (predict only) |
| `stdlib/rods/ml/probes/pipeline_*.nr` | PROBE-2 fixtures | — | tabular_classification / regression / clustering / text_classification |
| `stdlib/runtime/loss_rt.c` (199 LOC) | Losses | — | Cross-entropy, KL, MSE, Huber, Focal, InfoNCE |

PROBE-2 docs explicitly call out two known wrapper-layer UB bugs not yet closed by structural DFLIP-PATCH:
- `kmeans_f64_predict` "emits garbage labels" (pipeline_03 bypasses it)
- `decision_tree_classifier_predict_i64` "still has a residual flake" (pipeline_01 bypasses it)

These are **acknowledged-but-unclosed** in the rod sources and are surfaced again below.

---

## Findings

### F-MATH-001 — TT-SVD is a stub, not a real decomposition  [CRITICAL]

**Location:** `stdlib/runtime/tensor_decomp_rt.c` lines 142-204 (`nuc_td_tt_svd_3d_max_rank`) and 218-222 (`nuc_td_tt_svd_3d` shim).

**Evidence:**
- Line 161-164: `G1[i][r] = (i == r) ? 1.0 : 0.0` — G1 is initialized as a literal identity matrix and **never updated**. The comment admits "For simplicity: just take first r1 rows as the 'core' (proper impl would use SVD)".
- Line 178-185: G2 is similarly an identity-like indicator (`(i*d2+j == r) ? 1.0 : 0.0`).
- Line 187-189: G3 is "rough approximation" — copies a slice of `remainder` (which is just `G1^T @ unfold`, i.e. essentially the original tensor reshaped because G1 was identity).
- Line 161: comment "Crude SVD approximation: use first r1 left singular vectors via power iteration" — the power iteration is **never implemented**. The code does NOT compute singular vectors.

The function returns three "cores" that are not the actual TT cores of the input. Reconstructing `G1 @ G2 @ G3` will not approximate the input tensor unless the input happens to align with the canonical basis.

**Severity:** CRITICAL — silent miscompute. The function name promises a Tensor-Train SVD; the implementation returns identity-shaped placeholders. Anyone who chains TT-SVD into downstream computation gets garbage with no diagnostic.

**Remediation:**
1. Either ship a real TT-SVD: reshape into matrices at each split, perform actual SVD via `nuc_mat_svd` (already available in `linalg_rt.c`), truncate at rank, and pack the cores correctly.
2. Or, if a real implementation is not v1.0-feasible, mark it as not-implemented: change the rod surface to return a documented "stub" handle and emit an explicit panic/error so adopters fail loudly. Do NOT silently return identity tensors.
3. Add a parity test: reconstruct `G1 ×_3 G2 ×_3 G3`, compare to original tensor. Should pass for max_rank ≥ true_rank; currently fails on every non-trivial input.

---

### F-MATH-002 — CP-ALS uses diagonal-only "solve" instead of full inverse  [HIGH]

**Location:** `stdlib/runtime/tensor_decomp_rt.c` lines 71-75, 96-98, 118-120 (three update steps).

**Evidence:**
Each ALS factor update does:
```
A[i,r] = V[i,r] / gram[r,r]    if |gram[r,r]| > 1e-15 else 0
```
where `gram = (B^T B) ⊙ (C^T C)` (Hadamard). The comment at line 71 explicitly admits: "(simplified: use gram as diagonal approx)".

Real CP-ALS (Kolda & Bader 2009 §3.4) requires solving `A^T = (gram)^{-1} V^T` — the full pseudoinverse of a dense `R×R` matrix. Diagonal-only is correct only when `gram` is diagonal, which never happens for non-orthonormal factors.

**Impact:** Convergence is wrong. Reconstruction error does not decrease monotonically. Documented "ALS — Alternating Least Squares" semantics (line 24) are not delivered. Adopters expecting CP factors that minimize Frobenius error get a heuristic that may oscillate.

**Severity:** HIGH — wrong API semantics, silent. Will produce a result, but it is not the documented CP-ALS minimum. Numerical accuracy beyond reasonable tolerance against `tensorly.decomposition.parafac` reference.

**Remediation:**
1. Use `nuc_mat_inv` on the `R×R` `gram` matrix to compute the pseudoinverse, then full matmul `V * gram^{-1}` for each factor. (R is small — typically 2-50 — so cost is negligible.)
2. Add convergence check on Frobenius residual; break early if delta < tol.
3. Add a parity fixture comparing to `tensorly.decomposition.parafac` on a small known-rank tensor.

---

### F-MATH-003 — `nuc_ridge_predict` silently clips predictions to [0, 1]  [CRITICAL]

**Location:** `stdlib/runtime/tensor_rt.c` lines 366-368.

**Evidence:**
```c
// Clip to [0, 1]
if (sum < 0) sum = 0;
if (sum > 1) sum = 1;
pred->data[i] = sum;
```

Documentation in `linalg.nr` line 7: "ridge regression". The rod ships `linalg_ridge_predict` — generic ridge. Sklearn's `Ridge.predict` does NOT clip. This is appropriate only if the response is bounded probability in [0,1] (logistic-style), but ridge is L2-regularized linear regression — the predicted value ranges over all reals.

**Impact:** Any user of ridge regression for a target with values >1 or <0 (e.g. house prices, temperatures, log-returns) gets silently truncated predictions. Cannot be detected by inspecting the model object.

**Severity:** CRITICAL — silent miscompute that returns values numpy/sklearn would never produce.

**Remediation:**
1. Remove the clip. If a [0,1] clip is desired for a specific use case, expose a separate `linalg_ridge_predict_clipped` or accept clip bounds as args.
2. Add a parity test against sklearn `Ridge` on a synthetic dataset with response range [-10, 10] — current code will fail.

---

### F-MATH-004 — `nuc_mat_rank` leaks SVD result objects on every call  [HIGH]

**Location:** `stdlib/runtime/linalg_rt.c` lines 494-506.

**Evidence:**
```c
long long nuc_mat_rank(long long ah, long long tol_bits) {
    ...
    long long svd_h = nuc_mat_svd(ah);
    SVDResult *svd = (SVDResult *)(void *)svd_h;
    LAMat *S = (LAMat *)(void *)svd->S;
    int rank = 0;
    for (int i = 0; i < S->rows; i++) { if (S->data[i] > tol) rank++; }
    // Don't free SVD results here; caller manages lifetime
    return (long long)rank;
}
```

The comment claims "caller manages lifetime", but `nuc_mat_rank` returns an `int rank`, not the SVD handle. The caller has no way to retrieve and free the SVDResult, the U/S/V matrices, the eigenvalues vector, or the eigenvectors matrix that `nuc_mat_svd` allocated internally. Each call to `linalg_rank` leaks roughly `(m + 2)·(n²)·8 + headers` bytes plus the wrapping structs.

**Severity:** HIGH — every call to `linalg_rank` leaks. In long-running services or repeated rank queries (e.g., per-row), grows monotonically.

**Remediation:**
1. Free `svd->U`, `svd->S`, `svd->V` (their `data` fields and the LAMat structs) and the SVDResult itself before returning.
2. Add a deeper audit: verify the `nuc_mat_svd` cleanup at lines 475-479 matches its own allocations — it frees `ata`, `eigvals`, `Vmat`, `eig` but NOT `U`, `S`, `Vr` (those are returned). Confirm `nuc_mat_rank` would need to free those three.

---

### F-MATH-005 — `nuc_mat_eig` only valid for symmetric matrices but rod surface accepts any square  [HIGH]

**Location:** `stdlib/runtime/linalg_rt.c` lines 349-410. `stdlib/rods/linalg.nr` line 47-49.

**Evidence:**
The implementation uses Jacobi rotation, which is correct **only for symmetric matrices**. The rod docs (`linalg.nr` lines 5-7) say "decompositions: LU, QR, Cholesky, eigen, SVD" with no restriction. There is no symmetry check at runtime.

For a non-symmetric matrix (e.g., rotation matrix, companion matrix, generic real matrix with complex eigenvalues), Jacobi will:
1. Run for 200 iterations because the off-diagonal `off` will not converge below 1e-24.
2. Return the diagonal of the (still asymmetric) modified matrix as "eigenvalues" — but these are wrong; for a non-symmetric matrix, eigenvalues can be complex and there is no real-only decomposition.

**Severity:** HIGH — wrong-result for any non-symmetric input. Caller has no diagnostic (no return code).

**Remediation:**
1. Detect symmetry: compute `max |A[i,j] - A[j,i]|` over the upper triangle; if > tolerance × ‖A‖, either:
   - Return error sentinel (handle 0) and document as symmetric-only, OR
   - Implement a generic eigendecomposition (QR algorithm with shifts, complex eigenvalues).
2. Update rod docs to say "eigen decomposition for symmetric (real) matrices".
3. Also note SVD uses `nuc_mat_eig(A^T A)` internally — `A^T A` is always symmetric so SVD is fine, but the public `linalg_eig` is not.

---

### F-MATH-006 — FFT power spectrum buffer length is wrong for small N  [MEDIUM]

**Location:** `stdlib/runtime/fft_rt.c` line 182: `int half = N2/2 + 1;`

**Evidence:**
The result buffer is sized `half = N2/2 + 1`. For N=1, `next_pow2(1)=1`, `half=1`. The for-loop at 186-187 reads `re[0]` and `im[0]` — fine. But for N=2, `N2=2`, `half=2`, the loop accesses indices 0,1 of result.data[]. OK. For all power-of-2 N≥2 this is the standard "real FFT positive-frequency-only" length.

**However**, the data block returned says `result->len = half`, but the function signature/contract is documented as the rod-surface "Power Spectrum (|FFT(x)|^2)" without saying it returns only the positive-frequency half. Adopters who treat the result as a full N-length vector will read past the end.

**Severity:** MEDIUM — undocumented length contract. Consumers who don't read the C source assume length=N or length=N2.

**Remediation:**
1. Document on `fft_power_spectrum` rod surface: "returns positive-frequency half-spectrum, length floor(N/2)+1 (after rounding N up to power of 2)". Currently `fft.nr` line 14 just says "power spectrum".
2. Or, return the full-length N2 spectrum to match adopter expectations.
3. Add a fixture comparing to `np.abs(np.fft.rfft(x))**2` at multiple N (numpy returns N//2+1 elements — match that).

---

### F-MATH-007 — `nuc_fft_1d` zero-pads silently when N < N2 (next pow2)  [MEDIUM]

**Location:** `stdlib/runtime/fft_rt.c` lines 76-99.

**Evidence:**
The function takes `n` and computes `N2 = next_pow2(N)`. If user passes N=10, N2=16 — and the result is the FFT of `[x[0..10], 0, 0, 0, 0, 0, 0]`. The result is silently a 16-length spectrum, not 10.

The FFT of zero-padded data is **not** the FFT of the original data: it is the DFT evaluated at finer frequency bins. Adopters expect either (a) an error for non-power-of-2, or (b) a Bluestein/chirp-Z transform that handles arbitrary length.

**Severity:** MEDIUM — silent semantic shift. The output length differs from the input length when N is not a power of 2; the spectral interpretation is non-trivially different.

**Remediation:**
1. Either:
   - Reject non-power-of-2 N with an explicit error.
   - Document that input is zero-padded to next power of 2 and the returned length is N2.
   - Or implement Bluestein's algorithm for arbitrary N.
2. Add a parity test: `np.fft.fft([1,2,3])` is length-3, not length-4.

---

### F-MATH-008 — FFT power spectrum and correlate functions misuse `i < data->len`, not `i < N`  [MEDIUM]

**Location:** `stdlib/runtime/fft_rt.c` lines 112, 141-142, 178, 207-208.

**Evidence:**
```c
for (int i = 0; i < N && i < data->len; i++) re[i] = _ff_i2f(data->data[i]);
```
`fft_1d_real`, `fft_power_spectrum`, `fft_convolve`, `fft_correlate` all use this pattern. If `data->len < N`, the function silently zero-pads. If `data->len > N`, extra data is silently dropped.

For `nuc_fft_1d` (line 83) the analogous loop is `i * 2 + 1 < data->len` — this combines a length-mismatch silent fallback with the interleaved [re,im,re,im,...] layout.

**Severity:** MEDIUM — silent input truncation/padding. Especially insidious when `n` is wrong and `data->len` is the true length: caller thinks they're transforming `data->len/2` complex samples but they're transforming `n` instead.

**Remediation:**
1. If `data->len < N` (or `< 2*N` for interleaved) panic with an explicit error.
2. Or document the truncation behavior.
3. Add diagnostics: if `data->len != N` (or `2*N`), log a warning.

---

### F-MATH-009 — Bayesian MCMC `acceptance_rate` overestimates by counting position changes, not proposal acceptances  [MEDIUM]

**Location:** `stdlib/runtime/bayesian_rt.c` lines 178-185.

**Evidence:**
```c
long long nuc_bayes_acceptance_rate(long long chain_h) {
    BYVec *ch = (BYVec *)(void *)chain_h;
    int changes = 0;
    for (int i = 1; i < ch->len; i++) {
        if (ch->data[i] != ch->data[i - 1]) changes++;
    }
    return _by_f2i((double)changes / (ch->len - 1));
}
```

This counts adjacent-sample changes in the post-burnin chain. Two issues:
1. Burnin acceptances are not counted (the chain only stores post-burnin samples).
2. **Even within the post-burnin chain, this is not the acceptance rate.** The true acceptance rate is `(# accepted proposals) / (# proposals)`. The adjacent-change count under-counts because consecutive proposals from the same posterior mass that happen to land at numerically-identical f64 values (rare but possible at a sharply peaked posterior) are incorrectly counted as rejections, AND it does not see the burnin acceptance behavior at all.
3. Bigger issue: when a proposal is REJECTED and the chain stays at the same `x`, that's correctly a non-change. But when a proposal is ACCEPTED to a value bit-equal to the current state (e.g. integer-valued posterior), it is counted as a non-change. For most continuous posteriors this is rare and the metric is approximately right, but the function name promises something it does not deliver.

**Severity:** MEDIUM — diagnostic that is approximately-but-not-exactly the acceptance rate. Accuracy depends on posterior shape.

**Remediation:**
1. Track accepted-proposal counter inside `nuc_bayes_mcmc_scalar` / `nuc_bayes_mcmc_multi` and store on the returned chain object (or return a tuple).
2. Or rename the API to `chain_distinct_step_rate` to reflect what it actually computes.
3. Document the limitation.

---

### F-MATH-010 — Bayesian MCMC scalar return chain does not record initial state when first proposal is rejected  [MEDIUM]

**Location:** `stdlib/runtime/bayesian_rt.c` lines 56-69.

**Evidence:**
```c
double lp_x = _by_i2f(lp(_by_f2i(x)));
for (int i = 0; i < ns + nb; i++) {
    double x_prop = x + sigma * by_normal();
    double lp_prop = _by_i2f(lp(_by_f2i(x_prop)));
    double log_alpha = lp_prop - lp_x;
    if (log_alpha >= 0 || log(by_uniform()) < log_alpha) {
        x = x_prop; lp_x = lp_prop;
    }
    if (i >= nb) chain->data[chain->len++] = _by_f2i(x);
}
```

The loop runs `ns + nb` total times. Each iteration draws ONE proposal. After burnin, ONE sample is recorded per iteration. So `chain->len` ends at `ns`, which matches the rod docs.

**However:** in the case where `ns = 0`, the chain is allocated with size `ns = 0`, then `malloc(0)` behavior is implementation-defined. Subsequent reads of `chain->data` may segfault.

Also: the chain never records the initial `x0` if it is rejected on the first proposal — but the first iteration writes `x` (possibly updated) into `chain->data[0]`. This is conventional behavior, just worth noting.

**Severity:** MEDIUM — `ns=0` edge case → undefined behavior on subsequent operations. Also `malloc(0)` on Windows MSVC returns NULL, and the post-loop `nuc_bayes_chain_mean` would dereference null.

**Remediation:**
1. Validate `ns > 0` and `nb >= 0` at function entry; return error sentinel otherwise.
2. Validate `sigma > 0` (proposal variance).
3. Multivariate version (`nuc_bayes_mcmc_multi`) has same hazard at line 84 (`dim = x0->len` could be 0).

---

### F-MATH-011 — `kmeans_f64_predict` known-broken, documented in PROBE-2 source  [HIGH]

**Location:** `stdlib/rods/ml/learn_facade.nr` lines 2052-2076 (the implementation looks correct on its face), and `stdlib/rods/ml/probes/pipeline_03_clustering.nr` lines 11-16 (explicit bypass).

**Evidence:**
The probe pipeline says verbatim:
> "bypasses kmeans_f64(...) constructor + kmeans_f64_predict wrapper because that path hits a residual wrapper-layer UB on current main that emits garbage labels (same family the structural DFLIP-PATCH didn't fully close on KMeans)."

The .nr surface for `kmeans_f64_predict` looks logically correct. The bug is in a deeper wrapper layer (likely struct-passing, or the `KMeansF64` constructor at line 921). The probe works around it by calling `kmeans_f64_squared_distance_row_center` directly on a manually built `centers: TensorF64`.

**Severity:** HIGH — documented silent miscompute on a public API. Adopters who follow the obvious `kmeans_f64(...) → kmeans_f64_predict(model, x)` flow get garbage.

**Remediation:**
1. Root-cause the structural DFLIP path. Likely candidates: (a) `kmeans_f64` constructor at line 921 (only stores `centers` — verify `KMeansF64` struct layout matches), (b) ABI issue passing `&KMeansF64` to `kmeans_f64_predict`, (c) `tensor_f64_at` against `model.centers` field.
2. Until fixed: add a diagnostic warning when `kmeans_f64_predict` is called, OR remove it from the public surface and force adopters to use the direct-distance path.
3. Same root-cause likely affects `decision_tree_classifier_predict_i64` (also bypassed by pipeline_01).

---

### F-MATH-012 — `decision_tree_classifier_predict_i64` known-broken, documented in PROBE-2 source  [HIGH]

**Location:** `stdlib/rods/ml/learn_facade.nr` lines 1795-… (decision tree predict), pipeline_01_tabular_classification.nr lines 22-23.

**Evidence:** PROBE-2 source comment:
> "`decision_tree_classifier_predict_i64` directly. Both compute the same answer; predict_proba + argmax is the more stable path on current main (the predict_i64 wrapper still has a residual flake the structural DFLIP-PATCH didn't fully close — orthogonal to PROBE-2 scope)."

**Severity:** HIGH — second documented silent flake on a v1.0 public ML API.

**Remediation:** Same as F-MATH-011 — root-cause the wrapper-layer UB.

---

### F-MATH-013 — `bernoulli_nb_joint_log_likelihood_f64` numerically unstable for `pos_log_prob ≈ 0`  [MEDIUM]

**Location:** `stdlib/rods/ml/learn_facade.nr` line 2380.

**Evidence:**
```nucleor
let pos_log_prob: f64 = tensor_f64_at(&model.feature_log_prob, k, c);
let neg_log_prob: f64 = learn_log_f64(1.0 - learn_exp_f64(pos_log_prob));
```

`learn_log_f64(1 - exp(pos_log_prob))` is numerically unstable when `pos_log_prob` is close to 0 (probability close to 1). For `pos_log_prob = -1e-10`, `1 - exp(-1e-10) ≈ 1e-10`, and the subtraction loses precision rapidly. For `pos_log_prob = 0`, `1 - 1 = 0`, then `log(0) = -inf` (best case) or NaN (worst case depending on exp implementation).

Sklearn's `BernoulliNB._joint_log_likelihood` uses `np.log(1 - np.exp(feature_log_prob))` with `np.errstate(...)` and the implementation is robust because sklearn's `_BaseDiscreteNB` smooths via Laplace, ensuring `feature_log_prob` is bounded away from 0. **Nucleor's surface accepts arbitrary `feature_log_prob` from the caller** — including 0 — with no validation.

**Severity:** MEDIUM — numerical accuracy beyond reasonable tolerance; can yield `NaN`/`-inf` joint log-likelihoods which cascade to NaN proba and label collapse.

**Remediation:**
1. Use the numerically-stable form: `neg_log_prob = log1p(-exp(pos_log_prob))` when `pos_log_prob < log(0.5)`, and `log(-expm1(pos_log_prob))` when `pos_log_prob >= log(0.5)`. (Numpy uses this trick under the hood.)
2. Or pre-clamp `pos_log_prob` to `[-LARGE, log(1 - eps)]` at fit time and document the clamp.
3. Add a parity test against sklearn `BernoulliNB` with a synthetic dataset where one class has near-deterministic features.

---

### F-MATH-014 — `standard_scaler_f64_fit` zero-variance handling tests strict equality  [MEDIUM]

**Location:** `stdlib/rods/ml/learn_facade.nr` lines 246-247.

**Evidence:**
```nucleor
let mut scale: f64 = learn_f64_sqrt_newton(tensor_f64_at(&variance, 0, c));
if scale == 0.0 { scale = 1.0; };
```

The `if scale == 0.0` test is brittle. For features with very small but non-zero variance (e.g., 1e-300), the Newton sqrt returns a finite tiny value, and division by it produces overflow `inf` z-scores.

Sklearn's `StandardScaler._handle_zeros_in_scale` uses a tolerance: anything below `np.finfo(scale.dtype).eps * 10` becomes 1.0.

**Severity:** MEDIUM — produces `inf` z-scores for ill-conditioned features instead of cleanly bypassing them.

**Remediation:**
1. Change to `if scale < 1e-10 { scale = 1.0; };` or use a column-relative tolerance.
2. Alternative: also check `tensor_f64_at(&variance, 0, c) <= 0.0` directly (variance should never be < 0 mathematically, but float fmaul can produce -0 or tiny negative).

---

### F-MATH-015 — `learn_f64_sqrt_newton` initial guess leads to slow convergence for tiny x  [LOW]

**Location:** `stdlib/rods/ml/learn_facade.nr` lines 219-228.

**Evidence:**
```nucleor
fn learn_f64_sqrt_newton(x: f64) -> f64 {
    if x <= 0.0 { return 0.0; };
    let mut guess: f64 = x;
    if guess < 1.0 { guess = 1.0; };
    let mut i: i64 = 0;
    while i < 24 { guess = (guess + x / guess) * 0.5; i = i + 1; };
    return guess;
}
```

For `x = 1e-300`, initial guess is 1.0; Newton converges in O(log log) iterations linearly halving — about 50 iterations to reach machine precision. Only 24 iterations are run. Result will be inaccurate by many orders of magnitude.

For `x = 1e16`, initial guess is `x = 1e16`; Newton converges quadratically to 1e8 in ~25 iterations. Borderline.

For `x` near 1, 24 iterations is over-kill.

**Severity:** LOW — accuracy degrades for x that is very small or very large. Reasonable for typical ML feature variances. But `kmeans_f64_transform` (line 2044) uses this for distances, so for extreme-scale features (e.g. raw pixel sums) this is reachable.

**Remediation:**
1. Use the C runtime `sqrt` via FFI (already used in linalg_rt.c).
2. Or use `frexp` / `ldexp`-style scale reduction for the initial guess.
3. Add a fast-path for `x` in [0.25, 4] that converges in ~6 iterations.
4. Or simply increase iteration cap to 50 for safety.

---

### F-MATH-016 — `nuc_loss_label_smooth_ce` divides by `(n-1)` — undefined when n=1  [MEDIUM]

**Location:** `stdlib/runtime/loss_rt.c` line 69.

**Evidence:**
```c
double target_p = (i == t) ? (1.0 - eps) : eps / (n - 1);
```

If `n == 1` (single-class, degenerate but valid edge case), this is `eps / 0` = `inf`. The loss becomes `inf` regardless of input.

**Severity:** MEDIUM — silent NaN/inf propagation on a corner case.

**Remediation:**
1. Guard: `eps / (n > 1 ? n - 1 : 1)`.
2. Or panic on `n <= 1` since label smoothing is meaningless for single-class.

---

### F-MATH-017 — `nuc_loss_kl_divergence` silently zeroes terms when q is small instead of returning +inf  [MEDIUM]

**Location:** `stdlib/runtime/loss_rt.c` lines 80-89.

**Evidence:**
```c
for (int i = 0; i < n; i++) {
    double pi = _ls_i2f(p->data[i]), qi = _ls_i2f(q->data[i]);
    if (pi > 1e-15 && qi > 1e-15) kl += pi * log(pi / qi);
}
```

When `p[i] > 0` and `q[i] = 0` (or very small), KL(P||Q) is mathematically `+inf`. The implementation skips the term, producing a finite (incorrect) result. KL(P||Q) is supposed to be `+inf` in this case to signal Q does not cover the support of P — a property used for Bayesian model selection.

Skipping when `p[i] == 0` is correct (the convention `0 log 0 = 0`).

**Severity:** MEDIUM — wrong result under a well-defined edge case (Q has support holes).

**Remediation:**
1. When `p[i] > 1e-15` and `q[i] <= 1e-15`, return `+inf` immediately.
2. Document the support-coverage requirement.

---

### F-MATH-018 — `nuc_loss_kl_divergence` truncates instead of validating mismatched shapes  [MEDIUM]

**Location:** `stdlib/runtime/loss_rt.c` line 82: `int n = p->len < q->len ? p->len : q->len;`

**Evidence:**
Same issue as the FFT length-truncation pattern. If `p` and `q` have different lengths, the function takes `min(len)` and silently drops the tail of the longer vector. A KL divergence between distributions of different size is undefined.

Same hazard: `nuc_loss_mse` line 97, `nuc_loss_huber` line 113.

**Severity:** MEDIUM — silent acceptance of mis-shaped inputs.

**Remediation:** Validate `p->len == q->len`; return error sentinel or NaN otherwise.

---

### F-MATH-019 — `nuc_mat_inv` returns handle 0 on singularity; caller pattern unclear  [LOW]

**Location:** `stdlib/runtime/linalg_rt.c` line 169 (`return 0`).

**Evidence:**
On singular input, `nuc_mat_inv` returns the long-long `0` (NULL pointer cast). The rod surface `linalg_inv` does no check; callers who do not check `result != 0` will dereference NULL on subsequent ops (`nuc_mat_get(0, ...)`).

Same pattern: `nuc_mat_solve` does NOT return 0 on singular A — it does the back-substitution with `(fabs(diag) > 1e-15) ? sum/diag : 0.0` (line 153) and continues, returning a "solution" with zeros at the singular rows. Inconsistent error contract between `inv` and `solve` for the same underlying degeneracy.

Also: `nuc_mat_det` returns the f64-bits of `0.0` for non-square OR for singular — these two cases are indistinguishable, and `0.0` is also a valid determinant for genuinely singular matrices.

**Severity:** LOW — no silent numerical bug, but inconsistent error semantics and no diagnostic.

**Remediation:**
1. Document that handle 0 is the singular-error sentinel for `inv`, `lu`, `cholesky`, `solve`, `qr`, `svd` (verify each).
2. Make `solve` also return 0 on singular A rather than silently zero-out.
3. Provide a `linalg_is_invertible(h, tol) -> i64` predicate similar to `tensor_can_matmul_2d`.

---

### F-MATH-020 — `tensor_f64_matvec` not visible at this layer; PCA components order is convention-defined  [NOTE]

**Location:** `stdlib/rods/ml/learn_facade.nr` `pca_f64_transform` lines 2102-2133.

**Evidence:**
PCA transform computes `Z[r,k] = Σ_c (X[r,c] - mean[0,c]) * components[k,c]`. This means components are stored as **rows**: `components.shape = [n_components, n_features]`. This matches sklearn's `PCA.components_` (each row is a principal axis). Adopters from a PyTorch/TF background where PCA components are columns may be confused.

**Severity:** NOTE — convention works, but should be documented.

**Remediation:** Add a brief docstring: "components_ is shaped [n_components, n_features], each row a principal axis (sklearn convention)."

---

### F-MATH-021 — KMeans `kmeans_f64_predict` ties broken by first-encountered (not last); doc unclear  [LOW]

**Location:** `stdlib/rods/ml/learn_facade.nr` lines 2058-2076.

**Evidence:**
```nucleor
if sq < best_sq { ... }
```
Strict `<` means ties go to the **first** (lowest-index) center. Sklearn `KMeans.predict` uses `argmin` which also takes the first by index. Equivalent behavior. But the rod docs don't pin this down — adopters rolling their own argmin (as the probe pipeline does at line 70 `if sq1 < best_sq`) could subtly diverge if they used `<=`.

**Severity:** LOW — conventional; just undocumented.

**Remediation:** Document tie-breaking: "ties broken by lowest center index, matching sklearn."

---

### F-MATH-022 — `nuc_t3_reshape` does not validate dtype semantics for int/bool  [LOW]

**Location:** `stdlib/runtime/tensor3d_rt.c` lines 315-330.

**Evidence:**
`nuc_t3_reshape` copies `data` and `dtype` from src to new tensor — fine. But there is no validation that the new shape's product matches the old: line 326 `if (t->total != src->total) { free(t); return 0; }`. Good.

**However**, `t3_compute_strides(t)` is called BEFORE the total check (line 325). For pathological shapes (e.g., one dim = 0), `t->strides[0] = 0` — that's fine. For very large dims that overflow `int`, `t->total` overflows silently.

**Severity:** LOW — depends on shape vec being unvalidated. Recent fix `_check_t3_dims` (line 74) is for `nuc_t3_new`, not for `nuc_t3_reshape`.

**Remediation:** Apply the same overflow-and-negative-dim check in `nuc_t3_reshape` and in `nuc_t3_slice` (line 336, no validation there either).

---

### F-MATH-023 — `bayesian.nr` only declares 1-arg log_post; multivariate cannot pass dim-aware proposals  [MEDIUM]

**Location:** `stdlib/rods/bayesian.nr` lines 19-22.

**Evidence:**
```nucleor
extern fn nuc_bayes_mcmc_multi(log_post: i64, x0: i64, proposal_std: i64,
    n_samples: i64, burnin: i64) -> i64;
```
`proposal_std` is a single `i64` (one f64 sigma). The multivariate MCMC always proposes with **isotropic** Gaussian (same sigma in every dim). Real Bayesian MCMC commonly uses per-dim or full-covariance proposals. The header comment in the rod (lines 12-18) acknowledges past arity drift between rod and C — but does not flag the isotropic-only limitation.

The C runtime at `bayesian_rt.c` line 102 confirms: `for (int d = 0; d < dim; d++) x_prop[d] = x[d] + sigma * by_normal();` — single sigma applied per-dim.

**Severity:** MEDIUM — limits the MCMC to isotropic proposals; this is a documented (and very common) inefficiency, but should be surfaced.

**Remediation:**
1. Either:
   - Document the isotropic-only restriction on the rod-surface.
   - Add a `nuc_bayes_mcmc_multi_diag` overload taking a `Vec<f64>` of per-dim sigmas.
   - Add a `nuc_bayes_mcmc_multi_full` with full proposal covariance (Cholesky).

---

### F-MATH-024 — `nuc_bayes_chain_std` uses biased variance estimator (divide by n, not n-1)  [LOW]

**Location:** `stdlib/runtime/bayesian_rt.c` lines 162-172.

**Evidence:**
```c
double mean = sum / ch->len;
double var = sum2 / ch->len - mean * mean;
return _by_f2i(sqrt(var > 0 ? var : 0));
```

This is the biased (population) variance. For MCMC posterior summaries, both biased and Bessel-corrected (n-1) are defensible — but the rod docs say "Sample mean and standard deviation" (line 153) which implies sample (n-1) variance. Numpy's `np.std` defaults to ddof=0 (biased); pandas defaults to ddof=1. Inconsistency with the rod comment.

**Severity:** LOW — convention-only mismatch with docstring.

**Remediation:** Either update the comment to say "population standard deviation", or switch to `n-1` denominator.

---

### F-MATH-025 — `nuc_mat_qr` produces wrong Q for non-square (rank-deficient) inputs; does not warn  [LOW/MEDIUM]

**Location:** `stdlib/runtime/linalg_rt.c` lines 255-311.

**Evidence:**
The Householder QR loop runs `kmax = min(m, n)` iterations. For a tall matrix (m > n, common in least-squares), Q is `m × m` (full) and R is `m × n` — fine, but R has zero rows below row n. For a wide matrix (m < n), Q is `m × m` and R is `m × n` — also fine.

When the input matrix has linearly-dependent columns and `norm < 1e-15` is hit at some iteration k (line 275), the `continue` skips the Householder reflection for that column — but Q is still accumulated up to the previous iteration. This means R has zero columns where dependence happens, but the V/Q accumulation does not zero out properly. Result: Q*R ≠ A for rank-deficient inputs.

**Severity:** LOW–MEDIUM — affects rank-deficient matrix decompositions which are uncommon but not rare. No diagnostic.

**Remediation:**
1. Detect rank-deficient input (`norm < 1e-15` triggered) and either:
   - Return error.
   - Use rank-revealing QR (with column pivoting).
2. Add fixture: `Q @ R` should equal `A` to ~1e-10 for any input.

---

### F-MATH-026 — `nuc_mat_cholesky` returns 0 on indefinite/PSD-but-singular input; not distinguishable from "not square"  [LOW]

**Location:** `stdlib/runtime/linalg_rt.c` lines 320-341.

**Evidence:**
```c
if (val <= 0) { free(L->data); free(L); return 0; } // not SPD
```

Returns 0 for: (a) non-square input, (b) input with non-positive diagonal val during decomposition. For positive semidefinite (singular but not negative-definite) matrices, sklearn / scipy return a Cholesky-like factor with zero on the diagonal. Nucleor returns 0, indistinguishable from "not square". No log message.

**Severity:** LOW — ambiguous error contract.

**Remediation:** Different sentinels for "not square" vs "not PD"; or log to stderr (the runtime already does this for tensor OOB).

---

### F-MATH-027 — `nuc_t3_slice` accepts `idx` >= shape[dim] without bounds check; reads past end  [HIGH]

**Location:** `stdlib/runtime/tensor3d_rt.c` lines 336-363.

**Evidence:**
```c
long long nuc_t3_slice(long long h, long long dim, long long index) {
    Tensor3D *src = (Tensor3D *)(void *)h;
    int d = (int)dim, idx = (int)index;
    if (d >= src->ndim) return 0;
    ...
    int src_offset = o * src->shape[d] * inner + idx * inner;
    memcpy(t->data + dest, src->data + src_offset, inner * sizeof(double));
```

`idx` is never bounds-checked. If `idx >= src->shape[d]`, `src_offset` reads past the end of `src->data`. This will read stale heap memory or segfault.

The other tensor accessors (`nuc_t3_get`, `nuc_t3_set`) DO have bounds checks (lines 230, 244) gated by `_t3_lenient`. `nuc_t3_slice` is inconsistent.

**Severity:** HIGH — memory-safety violation; undefined behavior.

**Remediation:**
1. Add bounds check: `if (idx < 0 || idx >= src->shape[d]) { ... return 0 / panic; }` mirroring the lenient-mode pattern.
2. Audit `nuc_t3_reshape`, `nuc_t3_sum_axis`, `nuc_t3_permute` for similar gaps. (`nuc_t3_permute` does validate axes — fine. `nuc_t3_sum_axis` has `if (ax >= src->ndim) return 0;` — fine. `nuc_t3_reshape` validates total only.)

---

### F-MATH-028 — `nuc_mat_solve` and `nuc_mat_det` do not validate non-square input; det returns 0.0  [MEDIUM]

**Location:** `stdlib/runtime/linalg_rt.c` lines 109-143 (det), 104-159 in tensor_rt.c (solve).

**Evidence:**
- `nuc_mat_det` line 112: `if (n != a->cols) return _la_f2i(0.0);` — returns 0.0 for non-square. But 0.0 is also a valid determinant for singular square matrices. Indistinguishable.
- `nuc_mat_solve` (in `tensor_rt.c` line 104) does NOT check `A->rows == A->cols`. For non-square A, the loop body uses `int n = A_orig->rows;` and `A->data[i * n + j]` — if `A->cols != n`, this reads at the wrong stride, garbage results.

**Severity:** MEDIUM — silent miscompute on shape error.

**Remediation:**
1. `solve`: validate `A->rows == A->cols` and `b->rows == A->rows`; return 0 / sentinel otherwise.
2. `det`: distinguish "non-square" from "singular" — different sentinels (e.g., NaN vs 0).

---

### F-MATH-029 — `nuc_loss_cross_entropy` has no bounds check on `target`  [MEDIUM]

**Location:** `stdlib/runtime/loss_rt.c` line 23: `int t = (int)target;` then line 28: `_ls_i2f(logits->data[t])`.

**Evidence:**
If `target >= n` (or negative), the read at `logits->data[t]` is out of bounds — heap read.

Same hazard: `nuc_loss_label_smooth_ce` line 59, `nuc_loss_focal` line 130.

**Severity:** MEDIUM — out-of-bounds heap read on bad target index. No diagnostic.

**Remediation:** Validate `0 <= target < n` at function entry; return NaN-bits or panic.

---

### F-MATH-030 — `nuc_bayes_credible_interval` uses O(n²) bubble sort on chain  [LOW]

**Location:** `stdlib/runtime/bayesian_rt.c` lines 132-134.

**Evidence:**
```c
for (int i = 0; i < n - 1; i++)
    for (int j = i + 1; j < n; j++)
        if (sorted[j] < sorted[i]) { ... swap ... }
```

For a chain of 10000 samples, that's 50 million comparisons. For 100k samples, 5 billion. Functional, not a correctness bug, but it makes the function unusable for production-scale MCMC.

**Severity:** LOW (perf only, but for chains > a few thousand it dominates).

**Remediation:** Use `qsort` (libc has it) or implement merge/heap sort.

---

### F-MATH-031 — `nuc_mat_lu_P` returns the permutation MATRIX (not the index vector) but rod-surface implies a permutation handle  [NOTE]

**Location:** `stdlib/runtime/linalg_rt.c` lines 209-211, 247.

**Evidence:**
```c
LAMat *P = la_alloc(n, n);
for (int i = 0; i < n; i++) { L->data[i*n+i] = 1.0; P->data[i*n+i] = 1.0; }
```

P is the n×n permutation matrix (each row a one-hot). Verifying `PA = LU` requires a real matrix-multiply. Most LAPACK/numpy returns a length-n integer permutation vector (indices) — much smaller. Either is fine; the difference should be documented.

**Severity:** NOTE — consumers expecting `numpy.linalg.lu`'s `permutation_matrix` get an n×n matrix that they then need to multiply through. Functional, just different.

**Remediation:** Document `linalg_lu_P` as "n×n permutation matrix (one-hot per row)". Optional: add `linalg_lu_p_indices` returning a Vec<i64>.

---

### F-MATH-032 — `tensor_can_matmul_2d` and `tensor_shape_eq` predicates exist for 2D matmul and elementwise but NOT for `nuc_t3_bmm`  [LOW]

**Location:** `stdlib/rods/tensor_nd.nr` lines 112-138.

**Evidence:**
The rod-surface predicates ship for 2D matmul shape compat and full elementwise shape equality. But there is no predicate for:
- `bmm` (batched 3D matmul) — caller cannot pre-validate.
- `permute` axes validity (other than trying it and getting 0).
- `slice` index-in-range.

Adopters who follow the doc-recommended pattern of "call the predicate before the op" cannot do so for the higher-dim ops.

**Severity:** LOW — incomplete predicate set.

**Remediation:** Add `tensor_can_bmm`, `tensor_can_slice(h, dim, idx)`, `tensor_can_permute(h, axes)`.

---

## Summary

| Severity | Count |
|---|---|
| CRITICAL | 3 |
| HIGH | 7 |
| MEDIUM | 14 |
| LOW | 7 |
| NOTE | 1 |
| **Total** | **32** |

### Critical (silent miscompute or memory safety)
- F-MATH-001 — TT-SVD is a stub returning identity-shaped placeholders.
- F-MATH-003 — `nuc_ridge_predict` clips predictions to [0,1] silently.
- F-MATH-027 — `nuc_t3_slice` reads past end of buffer with no bounds check.

### High (wrong-result, contract violation, leak)
- F-MATH-002 — CP-ALS uses diagonal pseudo-solve; not real ALS.
- F-MATH-004 — `nuc_mat_rank` leaks SVD result every call.
- F-MATH-005 — `nuc_mat_eig` only valid for symmetric input but accepts any.
- F-MATH-011 — `kmeans_f64_predict` documented-broken in PROBE-2 source.
- F-MATH-012 — `decision_tree_classifier_predict_i64` documented-broken.
- F-MATH-025 — QR fails on rank-deficient input without warning.

### Top recommendations for v1.0 hardening
1. **TT-SVD (F-MATH-001):** decide stub-or-ship — silent identity is unacceptable.
2. **Ridge predict clip (F-MATH-003):** remove the [0,1] clip immediately.
3. **Slice bounds (F-MATH-027):** add bounds check; trivial fix, eliminates a memory-safety class.
4. **KMeans/DecisionTree wrapper UB (F-MATH-011, F-MATH-012):** root-cause the structural DFLIP-PATCH residual; two known v1.0 public-API silent miscomputes.
5. **CP-ALS (F-MATH-002):** small fix using `nuc_mat_inv` already in the codebase; converts a heuristic into the documented algorithm.
6. **Numerical-stability cleanup (F-MATH-013, F-MATH-014, F-MATH-015):** standard ML scaler / NB / sqrt fixes; modest effort, prevents NaN cascades.

### Methodology limitations
- No execution of `bin/nucleor.exe` — findings are static-analysis-derived. Some bugs may be benign in practice if the public surface never reaches them; others may be reachable along paths not surveyed.
- Per-rod numerical parity tests against numpy/sklearn were NOT executed (would have required rod compile + execute pipeline). Recommended next step: build a small `audit_scratch_math/` test harness that compiles each finding's MRE and compares against numpy.
- Coverage: read all of linalg_rt.c, fft_rt.c, tensor_decomp_rt.c, tensor3d_rt.c, bayesian_rt.c, loss_rt.c, all 4 PROBE-2 pipeline rods, full bayesian.nr, linalg.nr, fft.nr, tensor_decomp.nr, tensor_nd.nr, and ~600 lines of learn_facade.nr (focused on KMeans, NB, linear, ridge, scalers). Did NOT review every line of learn_facade's 2980 lines (kNN deep paths, multiclass precision/recall, polynomial features expansion not deeply audited).
