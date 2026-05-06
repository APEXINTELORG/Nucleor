// =====================================================
// rods/twin_core — Dual-Core Differentiable Noise Model
// =====================================================
// Runs two statevector cores in parallel:
//   Core A (clean): ideal noiseless execution
//   Core B (noisy): depolarizing noise after each gate
//
// Extracts 12 differential features for ML noise prediction.
// Import: import "twin_core.nr"  (from stdlib/rods/)
//
// Naming note: this is a quantum noise twin, not a robotics
// digital-twin / sim-to-real surface. New code may import the
// compatibility alias `quantum_twin.nr` for clearer intent.
// =====================================================

import "quantum.nr"

// --- Twin Core State ---
// We store per-step entropy data in Vecs for both cores.
// tc_state layout (Vec):
//   [0] = sv_a (clean statevector)
//   [1] = sv_b (noisy statevector)
//   [2] = n_qubits (as f64 handle)
//   [3] = p_1q noise rate (f64)
//   [4] = p_2q noise rate (f64)
//   [5] = ent_a Vec (per-step mean entropy, Core A)
//   [6] = ent_b Vec (per-step mean entropy, Core B)
//   [7] = max_ent_a Vec (per-step max entropy, Core A)
//   [8] = max_ent_b Vec (per-step max entropy, Core B)
//   [9] = step counter

fn tc_init(nq: i64, p_1q: i64, p_2q: i64) -> i64 {
    let tc: i64 = vec_new();
    let sv_a: i64 = qsim_init(nq);
    let sv_b: i64 = qsim_init(nq);
    vec_push(tc, sv_a);       // [0]
    vec_push(tc, sv_b);       // [1]
    vec_push(tc, nq);         // [2] n_qubits as i64
    vec_push(tc, p_1q);       // [3]
    vec_push(tc, p_2q);       // [4]
    vec_push(tc, vec_new());  // [5] ent_a
    vec_push(tc, vec_new());  // [6] ent_b
    vec_push(tc, vec_new());  // [7] max_ent_a
    vec_push(tc, vec_new());  // [8] max_ent_b
    vec_push(tc, 0);          // [9] step counter
    return tc;
}

fn tc_sv_a(tc: i64) -> i64 { return vec_get(tc, 0); }
fn tc_sv_b(tc: i64) -> i64 { return vec_get(tc, 1); }
fn tc_nq(tc: i64) -> i64 { return vec_get(tc, 2); }
fn tc_p1q(tc: i64) -> i64 { return vec_get(tc, 3); }
fn tc_p2q(tc: i64) -> i64 { return vec_get(tc, 4); }

// --- Depolarizing Noise ---
// |ψ'⟩ = (1 - p)|ψ⟩ + p * (1/√N) * |+⟩
fn noisy_mix(sv: i64, p: i64) {
    let n: i64 = vec_len(sv);
    let one_minus_p: i64 = f64_sub(f64_from_int(1), p);
    let uniform_amp: i64 = f64_div(p, f64_sqrt(f64_from_int(n)));
    let uniform_cx: i64 = cx_from_real(uniform_amp);
    let mut i: i64 = 0;
    while i < n {
        let old: i64 = vec_get(sv, i);
        let scaled: i64 = cx_scale(old, one_minus_p);
        vec_set(sv, i, cx_add(scaled, uniform_cx));
        i = i + 1;
    };
}

// --- Per-Qubit Entanglement Entropy ---
// Computes the von Neumann entropy of the reduced density matrix for qubit q.
// Returns f64 handle (entropy in bits, base 2).
fn qubit_entropy(sv: i64, q: i64) -> i64 {
    let n: i64 = vec_len(sv);
    // Build reduced density matrix ρ_q (2×2 Hermitian)
    let mut rho00: i64 = f64_from_int(0);
    let mut rho11: i64 = f64_from_int(0);
    let mut rho01: i64 = cx_zero(); // complex accumulator
    let mut i: i64 = 0;
    while i < n {
        if bit_test(i, q) == 0 {
            let j: i64 = bit_or(i, bit_shift_left(1, q));
            let ai: i64 = vec_get(sv, i);
            let aj: i64 = vec_get(sv, j);
            rho00 = f64_add(rho00, cx_abs_sq(ai));
            rho11 = f64_add(rho11, cx_abs_sq(aj));
            // ρ01 += α_i * conj(α_j)
            rho01 = cx_add(rho01, cx_mul(ai, cx_conj(aj)));
        };
        i = i + 1;
    };
    // Eigenvalues of 2×2 Hermitian: λ± = (tr ± √(tr² - 4·det)) / 2
    // tr = rho00 + rho11 = 1, det = rho00·rho11 - |rho01|²
    let det: i64 = f64_sub(f64_mul(rho00, rho11), cx_abs_sq(rho01));
    let disc: i64 = f64_sub(f64_from_int(1), f64_mul(f64_from_int(4), det));
    // Clamp discriminant >= 0
    let mut disc_safe: i64 = disc;
    if f64_lt(disc, f64_from_int(0)) == 1 { disc_safe = f64_from_int(0); };
    let sqrt_d: i64 = f64_sqrt(disc_safe);
    let lp: i64 = f64_div(f64_add(f64_from_int(1), sqrt_d), f64_from_int(2));
    let lm: i64 = f64_div(f64_sub(f64_from_int(1), sqrt_d), f64_from_int(2));
    // S = -λ+ log₂(λ+) - λ- log₂(λ-)
    let ln2: i64 = f64_log(f64_from_int(2));
    let eps: i64 = f64_div(f64_from_int(1), f64_from_int(1000000000)); // 1e-9
    let mut entropy: i64 = f64_from_int(0);
    if f64_gt(lp, eps) == 1 {
        entropy = f64_sub(entropy, f64_mul(lp, f64_div(f64_log(lp), ln2)));
    };
    if f64_gt(lm, eps) == 1 {
        entropy = f64_sub(entropy, f64_mul(lm, f64_div(f64_log(lm), ln2)));
    };
    return entropy;
}

// Compute mean and max entropy across all qubits. Returns [mean, max] as Vec.
fn compute_entropies(sv: i64, nq: i64) -> i64 {
    let result: i64 = vec_new();
    let mut sum: i64 = f64_from_int(0);
    let mut mx: i64 = f64_from_int(0);
    let mut q: i64 = 0;
    while q < nq {
        let e: i64 = qubit_entropy(sv, q);
        sum = f64_add(sum, e);
        if f64_gt(e, mx) == 1 { mx = e; };
        q = q + 1;
    };
    let mean: i64 = f64_div(sum, f64_from_int(nq));
    vec_push(result, mean);
    vec_push(result, mx);
    return result;
}

// Record entropy snapshot for both cores
fn tc_record_entropy(tc: i64) {
    let nq: i64 = tc_nq(tc);
    let ea: i64 = compute_entropies(tc_sv_a(tc), nq);
    let eb: i64 = compute_entropies(tc_sv_b(tc), nq);
    vec_push(vec_get(tc, 5), vec_get(ea, 0)); // ent_a mean
    vec_push(vec_get(tc, 6), vec_get(eb, 0)); // ent_b mean
    vec_push(vec_get(tc, 7), vec_get(ea, 1)); // max_ent_a
    vec_push(vec_get(tc, 8), vec_get(eb, 1)); // max_ent_b
}

// Increment step and record entropy
fn tc_step(tc: i64) {
    let step: i64 = vec_get(tc, 9) + 1;
    vec_set(tc, 9, step);
    tc_record_entropy(tc);
}

// =====================================================
// Twin Core Gate Wrappers
// Each applies gate to both cores, noise to Core B,
// records entropy snapshot.
// =====================================================

fn tc_h(tc: i64, q: i64) {
    qsim_h(tc_sv_a(tc), q);
    qsim_h(tc_sv_b(tc), q);
    noisy_mix(tc_sv_b(tc), tc_p1q(tc));
    tc_step(tc);
}

fn tc_x(tc: i64, q: i64) {
    qsim_x(tc_sv_a(tc), q);
    qsim_x(tc_sv_b(tc), q);
    noisy_mix(tc_sv_b(tc), tc_p1q(tc));
    tc_step(tc);
}

fn tc_y(tc: i64, q: i64) {
    qsim_y(tc_sv_a(tc), q);
    qsim_y(tc_sv_b(tc), q);
    noisy_mix(tc_sv_b(tc), tc_p1q(tc));
    tc_step(tc);
}

fn tc_z(tc: i64, q: i64) {
    qsim_z(tc_sv_a(tc), q);
    qsim_z(tc_sv_b(tc), q);
    noisy_mix(tc_sv_b(tc), tc_p1q(tc));
    tc_step(tc);
}

fn tc_rx(tc: i64, q: i64, theta: i64) {
    qsim_rx(tc_sv_a(tc), q, theta);
    qsim_rx(tc_sv_b(tc), q, theta);
    noisy_mix(tc_sv_b(tc), tc_p1q(tc));
    tc_step(tc);
}

fn tc_ry(tc: i64, q: i64, theta: i64) {
    qsim_ry(tc_sv_a(tc), q, theta);
    qsim_ry(tc_sv_b(tc), q, theta);
    noisy_mix(tc_sv_b(tc), tc_p1q(tc));
    tc_step(tc);
}

fn tc_rz(tc: i64, q: i64, theta: i64) {
    qsim_rz(tc_sv_a(tc), q, theta);
    qsim_rz(tc_sv_b(tc), q, theta);
    noisy_mix(tc_sv_b(tc), tc_p1q(tc));
    tc_step(tc);
}

fn tc_cnot(tc: i64, ctrl: i64, tgt: i64) {
    qsim_cnot(tc_sv_a(tc), ctrl, tgt);
    qsim_cnot(tc_sv_b(tc), ctrl, tgt);
    noisy_mix(tc_sv_b(tc), tc_p2q(tc));
    tc_step(tc);
}

fn tc_cz(tc: i64, ctrl: i64, tgt: i64) {
    qsim_cz(tc_sv_a(tc), ctrl, tgt);
    qsim_cz(tc_sv_b(tc), ctrl, tgt);
    noisy_mix(tc_sv_b(tc), tc_p2q(tc));
    tc_step(tc);
}

fn tc_ccx(tc: i64, c1: i64, c2: i64, tgt: i64) {
    qsim_ccx(tc_sv_a(tc), c1, c2, tgt);
    qsim_ccx(tc_sv_b(tc), c1, c2, tgt);
    noisy_mix(tc_sv_b(tc), tc_p2q(tc));
    tc_step(tc);
}

fn tc_crk(tc: i64, ctrl: i64, tgt: i64, k: i64) {
    qsim_crk(tc_sv_a(tc), ctrl, tgt, k);
    qsim_crk(tc_sv_b(tc), ctrl, tgt, k);
    noisy_mix(tc_sv_b(tc), tc_p2q(tc));
    tc_step(tc);
}

fn tc_swap(tc: i64, q1: i64, q2: i64) {
    // SWAP = 3 CNOTs, each with noise
    tc_cnot(tc, q1, q2);
    tc_cnot(tc, q2, q1);
    tc_cnot(tc, q1, q2);
}

// =====================================================
// Feature Extraction (12 differential features)
// =====================================================

fn tc_extract(tc: i64) -> i64 {
    let sv_a: i64 = tc_sv_a(tc);
    let sv_b: i64 = tc_sv_b(tc);
    let nq: i64 = tc_nq(tc);
    let n: i64 = vec_len(sv_a);
    let eps: i64 = f64_div(f64_from_int(1), f64_from_int(1000000000)); // 1e-9

    // Get probability distributions
    let probs_a: i64 = qsim_prob_all(sv_a);
    let probs_b: i64 = qsim_prob_all(sv_b);

    // Feature 1: TV Distance = 0.5 * Σ|p_a - p_b|
    let mut tv: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < n {
        tv = f64_add(tv, f64_abs(f64_sub(vec_get(probs_a, i), vec_get(probs_b, i))));
        i = i + 1;
    };
    tv = f64_mul(tv, f64_div(f64_from_int(1), f64_from_int(2)));

    // Feature 2: KL Divergence = Σ p_a * log((p_a+ε)/(p_b+ε))
    let mut kl: i64 = f64_from_int(0);
    i = 0;
    while i < n {
        let pa: i64 = f64_add(vec_get(probs_a, i), eps);
        let pb: i64 = f64_add(vec_get(probs_b, i), eps);
        kl = f64_add(kl, f64_mul(pa, f64_log(f64_div(pa, pb))));
        i = i + 1;
    };

    // Feature 3: Fidelity = Σ √(p_a * p_b)
    let mut fidelity: i64 = f64_from_int(0);
    i = 0;
    while i < n {
        fidelity = f64_add(fidelity, f64_sqrt(f64_add(f64_mul(vec_get(probs_a, i), vec_get(probs_b, i)), eps)));
        i = i + 1;
    };

    // Features 4-6: Entropy divergence (mean, max, final)
    let ent_a: i64 = vec_get(tc, 5);
    let ent_b: i64 = vec_get(tc, 6);
    let n_steps: i64 = vec_len(ent_a);
    let mut mean_div: i64 = f64_from_int(0);
    let mut max_div: i64 = f64_from_int(0);
    let mut final_div: i64 = f64_from_int(0);

    // Build divergence vector
    let divs: i64 = vec_new();
    i = 0;
    while i < n_steps {
        let d: i64 = f64_sub(vec_get(ent_b, i), vec_get(ent_a, i));
        vec_push(divs, d);
        mean_div = f64_add(mean_div, d);
        if f64_gt(d, max_div) == 1 { max_div = d; };
        i = i + 1;
    };
    if n_steps > 0 {
        mean_div = f64_div(mean_div, f64_from_int(n_steps));
        final_div = vec_get(divs, n_steps - 1);
    };

    // Feature 7: Divergence slope (linear regression)
    let mut slope: i64 = f64_from_int(0);
    if n_steps > 1 {
        let step_mean: i64 = f64_div(f64_from_int(n_steps - 1), f64_from_int(2));
        let mut num: i64 = f64_from_int(0);
        let mut den: i64 = f64_from_int(0);
        i = 0;
        while i < n_steps {
            let si: i64 = f64_sub(f64_from_int(i), step_mean);
            let di: i64 = f64_sub(vec_get(divs, i), mean_div);
            num = f64_add(num, f64_mul(si, di));
            den = f64_add(den, f64_mul(si, si));
            i = i + 1;
        };
        if f64_gt(f64_abs(den), eps) == 1 { slope = f64_div(num, den); };
    };

    // Features 8-9: Clean core final entropy
    let max_ent_a: i64 = vec_get(tc, 7);
    let mut mean_ent_clean: i64 = f64_from_int(0);
    let mut max_ent_clean: i64 = f64_from_int(0);
    if n_steps > 0 {
        mean_ent_clean = vec_get(ent_a, n_steps - 1);
        max_ent_clean = vec_get(max_ent_a, n_steps - 1);
    };

    // Feature 10: Sparsity (fraction of nonzero amplitudes)
    let mut nonzero: i64 = 0;
    i = 0;
    while i < n {
        if f64_gt(vec_get(probs_a, i), eps) == 1 { nonzero = nonzero + 1; };
        i = i + 1;
    };
    let sparsity: i64 = f64_div(f64_from_int(nonzero), f64_from_int(n));

    // Pack all 12 features into result Vec
    let features: i64 = vec_new();
    vec_push(features, tv);             // [0] tv_dist
    vec_push(features, kl);             // [1] kl_div
    vec_push(features, fidelity);       // [2] fidelity
    vec_push(features, mean_div);       // [3] mean_ent_div
    vec_push(features, max_div);        // [4] max_ent_div
    vec_push(features, final_div);      // [5] final_ent_div
    vec_push(features, slope);          // [6] div_slope
    vec_push(features, mean_ent_clean); // [7] mean_ent_clean
    vec_push(features, max_ent_clean);  // [8] max_ent_clean
    vec_push(features, sparsity);       // [9] sparsity
    vec_push(features, f64_from_int(nq));       // [10] n_qubits
    vec_push(features, f64_from_int(n_steps));  // [11] n_steps
    return features;
}

// =====================================================
// JSON Output
// =====================================================

fn f64_to_str_6(val: i64) -> str {
    // Convert f64 to string with ~6 decimal places
    // Using string formatting via multiplication trick
    let is_neg: i64 = f64_lt(val, f64_from_int(0));
    let abs_val: i64 = f64_abs(val);
    let int_part: i64 = f64_to_int(f64_floor(abs_val));
    let frac: i64 = f64_sub(abs_val, f64_from_int(int_part));
    let frac_scaled: i64 = f64_to_int(f64_floor(f64_mul(frac, f64_from_int(1000000))));
    let mut frac_str: str = int_to_str(frac_scaled);
    // Pad to 6 digits
    while str_len(frac_str) < 6 { frac_str = str_concat("0", frac_str); };
    let mut result: str = str_concat(int_to_str(int_part), str_concat(".", frac_str));
    if is_neg == 1 { result = str_concat("-", result); };
    return result;
}

fn tc_write_json(tc: i64, features: i64, circuit_name: str, filename: str) {
    let nq: i64 = tc_nq(tc);
    let n_steps: i64 = vec_len(vec_get(tc, 5));

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"circuit\":\""); sb_append(sb, circuit_name);
    sb_append(sb, "\",\"n_qubits\":"); sb_append(sb, int_to_str(nq));
    sb_append(sb, ",\"n_steps\":"); sb_append(sb, int_to_str(n_steps));
    sb_append(sb, ",\"p_1q\":"); sb_append(sb, f64_to_str_6(tc_p1q(tc)));
    sb_append(sb, ",\"p_2q\":"); sb_append(sb, f64_to_str_6(tc_p2q(tc)));

    // 12 features
    let names: i64 = vec_new();
    vec_push(names, "tv_dist"); vec_push(names, "kl_div"); vec_push(names, "fidelity");
    vec_push(names, "mean_ent_div"); vec_push(names, "max_ent_div"); vec_push(names, "final_ent_div");
    vec_push(names, "div_slope"); vec_push(names, "mean_ent_clean"); vec_push(names, "max_ent_clean");
    vec_push(names, "sparsity"); vec_push(names, "n_qubits_f"); vec_push(names, "n_steps_f");

    sb_append(sb, ",\"features\":{");
    let mut i: i64 = 0;
    while i < 12 {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "\""); sb_append(sb, vec_get(names, i)); sb_append(sb, "\":");
        sb_append(sb, f64_to_str_6(vec_get(features, i)));
        i = i + 1;
    };
    sb_append(sb, "}");

    // Per-step entropy trace (compact arrays)
    let ent_a: i64 = vec_get(tc, 5);
    let ent_b: i64 = vec_get(tc, 6);
    sb_append(sb, ",\"entropy_clean\":[");
    i = 0;
    while i < n_steps {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, f64_to_str_6(vec_get(ent_a, i)));
        i = i + 1;
    };
    sb_append(sb, "],\"entropy_noisy\":[");
    i = 0;
    while i < n_steps {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, f64_to_str_6(vec_get(ent_b, i)));
        i = i + 1;
    };
    sb_append(sb, "]}");

    file_write_string(filename, str_concat(sb_to_str(sb), "\n"));
}
