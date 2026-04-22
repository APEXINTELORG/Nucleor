// =====================================================
// rods/multi_core — N-Core Quantum Noise Ensemble
// =====================================================
// Extends twin_core from 2 cores to N cores.
// Core 0 = clean (ideal), Cores 1..N-1 = noisy with spread error rates.
// Extracts ensemble features + phase-sensitive features + divergence dynamics.
//
// Import: import "stdlib/rods/multi_core.nr"
// Depends: twin_core.nr -> quantum.nr -> complex.nr + bitwise.nr
// =====================================================

import "twin_core.nr"

// --- Multi-Core State Layout (Vec) ---
//   [0] = n_cores
//   [1] = n_qubits
//   [2] = Vec of N statevector handles
//   [3] = Vec of N p_1q noise rates (f64), core 0 = 0
//   [4] = Vec of N p_2q noise rates (f64), core 0 = 0
//   [5] = step counter
//   [6] = Vec of N Vecs: per-core per-step mean entropy
//   [7] = Vec of N Vecs: per-core per-step TV vs clean
//   [8] = Vec of per-step phase coherence (clean vs mean noisy)
//   [9] = Vec of per-step ensemble agreement (mean pairwise TV among noisy cores)

fn mc_init(nq: i64, n_cores: i64, p1q_base: i64, p2q_base: i64) -> i64 {
    let mc: i64 = vec_new();
    vec_push(mc, n_cores);     // [0]
    vec_push(mc, nq);          // [1]

    // Create N statevectors
    let svs: i64 = vec_new();
    let p1qs: i64 = vec_new();
    let p2qs: i64 = vec_new();
    let mut c: i64 = 0;
    while c < n_cores {
        vec_push(svs, qsim_init(nq));
        if c == 0 {
            // Core 0: clean (no noise)
            vec_push(p1qs, f64_from_int(0));
            vec_push(p2qs, f64_from_int(0));
        } else {
            // Cores 1..N-1: spread noise levels
            // p = p_base * (0.5 + 0.5 * c) for c=1..N-1
            // This gives range [1.0x, 0.5*(N-1)+0.5 x] of base rate
            let scale: i64 = f64_add(
                f64_div(f64_from_int(1), f64_from_int(2)),
                f64_div(f64_from_int(c), f64_from_int(2))
            );
            vec_push(p1qs, f64_mul(p1q_base, scale));
            vec_push(p2qs, f64_mul(p2q_base, scale));
        };
        c = c + 1;
    };
    vec_push(mc, svs);   // [2]
    vec_push(mc, p1qs);  // [3]
    vec_push(mc, p2qs);  // [4]
    vec_push(mc, 0);     // [5] step counter

    // Per-core per-step entropy tracking
    let ent_vecs: i64 = vec_new();
    c = 0;
    while c < n_cores {
        vec_push(ent_vecs, vec_new());
        c = c + 1;
    };
    vec_push(mc, ent_vecs);  // [6]

    // Per-core per-step TV vs clean
    let tv_vecs: i64 = vec_new();
    c = 0;
    while c < n_cores {
        vec_push(tv_vecs, vec_new());
        c = c + 1;
    };
    vec_push(mc, tv_vecs);   // [7]

    // Per-step phase coherence
    vec_push(mc, vec_new()); // [8]

    // Per-step ensemble agreement
    vec_push(mc, vec_new()); // [9]

    return mc;
}

fn mc_ncores(mc: i64) -> i64 { return vec_get(mc, 0); }
fn mc_nq(mc: i64) -> i64 { return vec_get(mc, 1); }
fn mc_svs(mc: i64) -> i64 { return vec_get(mc, 2); }
fn mc_sv(mc: i64, core: i64) -> i64 { return vec_get(vec_get(mc, 2), core); }
fn mc_p1q(mc: i64, core: i64) -> i64 { return vec_get(vec_get(mc, 3), core); }
fn mc_p2q(mc: i64, core: i64) -> i64 { return vec_get(vec_get(mc, 4), core); }
fn mc_step_count(mc: i64) -> i64 { return vec_get(mc, 5); }

// --- Per-Step Data Recording ---

fn mc_compute_tv(sv_a: i64, sv_b: i64) -> i64 {
    let pa: i64 = qsim_prob_all(sv_a);
    let pb: i64 = qsim_prob_all(sv_b);
    let n: i64 = vec_len(pa);
    let mut tv: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < n {
        tv = f64_add(tv, f64_abs(f64_sub(vec_get(pa, i), vec_get(pb, i))));
        i = i + 1;
    };
    return f64_mul(tv, f64_div(f64_from_int(1), f64_from_int(2)));
}

fn mc_compute_phase_coherence(sv_clean: i64, sv_noisy: i64) -> i64 {
    let n: i64 = vec_len(sv_clean);
    let eps: i64 = f64_div(f64_from_int(1), f64_from_int(1000000));
    let mut sum_cos: i64 = f64_from_int(0);
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let ac: i64 = vec_get(sv_clean, i);
        let an: i64 = vec_get(sv_noisy, i);
        if f64_gt(cx_abs_sq(ac), eps) == 1 {
            let pc: i64 = cx_phase(ac);
            let pn: i64 = cx_phase(an);
            sum_cos = f64_add(sum_cos, f64_cos(f64_sub(pc, pn)));
            count = count + 1;
        };
        i = i + 1;
    };
    if count > 0 { return f64_div(sum_cos, f64_from_int(count)); };
    return f64_from_int(1);
}

fn mc_record_step(mc: i64) {
    let nc: i64 = mc_ncores(mc);
    let nq: i64 = mc_nq(mc);
    let sv_clean: i64 = mc_sv(mc, 0);
    let ent_vecs: i64 = vec_get(mc, 6);
    let tv_vecs: i64 = vec_get(mc, 7);

    // Per-core entropy and TV
    let mut c: i64 = 0;
    while c < nc {
        let sv: i64 = mc_sv(mc, c);
        let ents: i64 = compute_entropies(sv, nq);
        let mean_ent: i64 = vec_get(ents, 0);
        vec_push(vec_get(ent_vecs, c), mean_ent);

        if c > 0 {
            let tv: i64 = mc_compute_tv(sv_clean, sv);
            vec_push(vec_get(tv_vecs, c), tv);
        } else {
            vec_push(vec_get(tv_vecs, 0), f64_from_int(0));
        };
        c = c + 1;
    };

    // Phase coherence: mean across all noisy cores vs clean
    let mut phase_sum: i64 = f64_from_int(0);
    c = 1;
    while c < nc {
        phase_sum = f64_add(phase_sum, mc_compute_phase_coherence(sv_clean, mc_sv(mc, c)));
        c = c + 1;
    };
    let phase_coh: i64 = f64_div(phase_sum, f64_from_int(nc - 1));
    vec_push(vec_get(mc, 8), phase_coh);

    // Ensemble agreement: mean pairwise TV among noisy cores
    let mut pair_tv_sum: i64 = f64_from_int(0);
    let mut n_pairs: i64 = 0;
    let mut ci: i64 = 1;
    while ci < nc {
        let mut cj: i64 = ci + 1;
        while cj < nc {
            pair_tv_sum = f64_add(pair_tv_sum, mc_compute_tv(mc_sv(mc, ci), mc_sv(mc, cj)));
            n_pairs = n_pairs + 1;
            cj = cj + 1;
        };
        ci = ci + 1;
    };
    let mut agreement: i64 = f64_from_int(0);
    if n_pairs > 0 { agreement = f64_div(pair_tv_sum, f64_from_int(n_pairs)); };
    vec_push(vec_get(mc, 9), agreement);

    // Increment step
    vec_set(mc, 5, vec_get(mc, 5) + 1);
}

// --- Gate Wrappers (apply to all N cores + noise + record) ---

fn mc_apply_1q(mc: i64, gate_fn: i64, q: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        let sv: i64 = mc_sv(mc, c);
        let gf: i64 = gate_fn;
        gf(sv, q);
        if c > 0 { noisy_mix(sv, mc_p1q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_apply_2q(mc: i64, gate_fn: i64, q0: i64, q1: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        let sv: i64 = mc_sv(mc, c);
        let gf: i64 = gate_fn;
        gf(sv, q0, q1);
        if c > 0 { noisy_mix(sv, mc_p2q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

// Direct gate wrappers (avoids function pointer issues)
fn mc_h(mc: i64, q: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_h(mc_sv(mc, c), q);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p1q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_x(mc: i64, q: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_x(mc_sv(mc, c), q);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p1q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_z(mc: i64, q: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_z(mc_sv(mc, c), q);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p1q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_rx(mc: i64, q: i64, theta: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_rx(mc_sv(mc, c), q, theta);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p1q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_ry(mc: i64, q: i64, theta: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_ry(mc_sv(mc, c), q, theta);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p1q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_rz(mc: i64, q: i64, theta: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_rz(mc_sv(mc, c), q, theta);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p1q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_cnot(mc: i64, ctrl: i64, tgt: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_cnot(mc_sv(mc, c), ctrl, tgt);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p2q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_cz(mc: i64, ctrl: i64, tgt: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_cz(mc_sv(mc, c), ctrl, tgt);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p2q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_crk(mc: i64, ctrl: i64, tgt: i64, k: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_crk(mc_sv(mc, c), ctrl, tgt, k);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p2q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_ccx(mc: i64, c1: i64, c2: i64, tgt: i64) {
    let nc: i64 = mc_ncores(mc);
    let mut c: i64 = 0;
    while c < nc {
        qsim_ccx(mc_sv(mc, c), c1, c2, tgt);
        if c > 0 { noisy_mix(mc_sv(mc, c), mc_p2q(mc, c)); };
        c = c + 1;
    };
    mc_record_step(mc);
}

fn mc_swap(mc: i64, q1: i64, q2: i64) {
    // SWAP = 3 CNOTs
    mc_cnot(mc, q1, q2);
    mc_cnot(mc, q2, q1);
    mc_cnot(mc, q1, q2);
}

// =====================================================
// Feature Extraction — Ensemble + Phase + Dynamics
// =====================================================

fn mc_extract(mc: i64) -> i64 {
    let nc: i64 = mc_ncores(mc);
    let nq: i64 = mc_nq(mc);
    let n_steps: i64 = mc_step_count(mc);
    let sv_clean: i64 = mc_sv(mc, 0);
    let probs_clean: i64 = qsim_prob_all(sv_clean);
    let n_amps: i64 = vec_len(sv_clean);
    let eps: i64 = f64_div(f64_from_int(1), f64_from_int(1000000000));
    let features: i64 = vec_new();

    // --- Ensemble TV statistics ---
    let tvs: i64 = vec_new();
    let kls: i64 = vec_new();
    let fids: i64 = vec_new();
    let mut c: i64 = 1;
    while c < nc {
        let probs_noisy: i64 = qsim_prob_all(mc_sv(mc, c));
        // TV distance
        let mut tv: i64 = f64_from_int(0);
        let mut kl: i64 = f64_from_int(0);
        let mut fid: i64 = f64_from_int(0);
        let mut i: i64 = 0;
        while i < n_amps {
            let pa: i64 = vec_get(probs_clean, i);
            let pb: i64 = vec_get(probs_noisy, i);
            tv = f64_add(tv, f64_abs(f64_sub(pa, pb)));
            // KL
            let pa_s: i64 = f64_add(pa, eps);
            let pb_s: i64 = f64_add(pb, eps);
            kl = f64_add(kl, f64_mul(pa_s, f64_log(f64_div(pa_s, pb_s))));
            // Fidelity
            fid = f64_add(fid, f64_sqrt(f64_add(f64_mul(pa, pb), eps)));
            i = i + 1;
        };
        vec_push(tvs, f64_mul(tv, f64_div(f64_from_int(1), f64_from_int(2))));
        vec_push(kls, kl);
        vec_push(fids, fid);
        c = c + 1;
    };

    // Feature 0: mean_tv
    let mut tv_sum: i64 = f64_from_int(0);
    let mut tv_min: i64 = f64_from_int(999);
    let mut tv_max: i64 = f64_from_int(0);
    c = 0;
    while c < nc - 1 {
        let tv: i64 = vec_get(tvs, c);
        tv_sum = f64_add(tv_sum, tv);
        if f64_lt(tv, tv_min) == 1 { tv_min = tv; };
        if f64_gt(tv, tv_max) == 1 { tv_max = tv; };
        c = c + 1;
    };
    let mean_tv: i64 = f64_div(tv_sum, f64_from_int(nc - 1));
    vec_push(features, mean_tv);          // [0] mean_tv

    // Feature 1: std_tv
    let mut tv_var: i64 = f64_from_int(0);
    c = 0;
    while c < nc - 1 {
        let d: i64 = f64_sub(vec_get(tvs, c), mean_tv);
        tv_var = f64_add(tv_var, f64_mul(d, d));
        c = c + 1;
    };
    vec_push(features, f64_sqrt(f64_div(tv_var, f64_from_int(nc - 1)))); // [1] std_tv

    vec_push(features, tv_min);           // [2] min_tv
    vec_push(features, tv_max);           // [3] max_tv

    // Feature 4: mean_fidelity
    let mut fid_sum: i64 = f64_from_int(0);
    c = 0;
    while c < nc - 1 {
        fid_sum = f64_add(fid_sum, vec_get(fids, c));
        c = c + 1;
    };
    vec_push(features, f64_div(fid_sum, f64_from_int(nc - 1))); // [4] mean_fidelity

    // Feature 5: mean_kl
    let mut kl_sum: i64 = f64_from_int(0);
    let mut kl_max: i64 = f64_from_int(0);
    c = 0;
    while c < nc - 1 {
        let k: i64 = vec_get(kls, c);
        kl_sum = f64_add(kl_sum, k);
        if f64_gt(k, kl_max) == 1 { kl_max = k; };
        c = c + 1;
    };
    vec_push(features, f64_div(kl_sum, f64_from_int(nc - 1))); // [5] mean_kl
    vec_push(features, kl_max);           // [6] max_kl

    // Feature 7: ensemble_agreement (mean pairwise TV among noisy cores)
    let mut pair_sum: i64 = f64_from_int(0);
    let mut n_pairs: i64 = 0;
    let mut ci: i64 = 1;
    while ci < nc {
        let pi: i64 = qsim_prob_all(mc_sv(mc, ci));
        let mut cj: i64 = ci + 1;
        while cj < nc {
            let pj: i64 = qsim_prob_all(mc_sv(mc, cj));
            let mut ptv: i64 = f64_from_int(0);
            let mut k: i64 = 0;
            while k < n_amps {
                ptv = f64_add(ptv, f64_abs(f64_sub(vec_get(pi, k), vec_get(pj, k))));
                k = k + 1;
            };
            pair_sum = f64_add(pair_sum, f64_mul(ptv, f64_div(f64_from_int(1), f64_from_int(2))));
            n_pairs = n_pairs + 1;
            cj = cj + 1;
        };
        ci = ci + 1;
    };
    let mut agreement: i64 = f64_from_int(0);
    if n_pairs > 0 { agreement = f64_div(pair_sum, f64_from_int(n_pairs)); };
    vec_push(features, agreement);        // [7] ensemble_agreement

    // --- Divergence Dynamics ---
    // Feature 8: divergence_onset (first step where mean TV > 0.01)
    let tv_vecs: i64 = vec_get(mc, 7);
    let mut onset: i64 = n_steps;
    let threshold: i64 = f64_div(f64_from_int(1), f64_from_int(100));
    let mut s: i64 = 0;
    while s < n_steps {
        let mut step_tv: i64 = f64_from_int(0);
        c = 1;
        while c < nc {
            step_tv = f64_add(step_tv, vec_get(vec_get(tv_vecs, c), s));
            c = c + 1;
        };
        step_tv = f64_div(step_tv, f64_from_int(nc - 1));
        if f64_gt(step_tv, threshold) == 1 {
            onset = s;
            s = n_steps; // break
        };
        s = s + 1;
    };
    vec_push(features, f64_from_int(onset)); // [8] divergence_onset

    // Feature 9: divergence_slope (linear fit of mean TV over steps)
    let mut slope: i64 = f64_from_int(0);
    if n_steps > 1 {
        let step_mean: i64 = f64_div(f64_from_int(n_steps - 1), f64_from_int(2));
        // Compute mean TV per step
        let step_tvs: i64 = vec_new();
        s = 0;
        while s < n_steps {
            let mut stv: i64 = f64_from_int(0);
            c = 1;
            while c < nc {
                stv = f64_add(stv, vec_get(vec_get(tv_vecs, c), s));
                c = c + 1;
            };
            vec_push(step_tvs, f64_div(stv, f64_from_int(nc - 1)));
            s = s + 1;
        };
        let mut tv_mean: i64 = f64_from_int(0);
        s = 0;
        while s < n_steps { tv_mean = f64_add(tv_mean, vec_get(step_tvs, s)); s = s + 1; };
        tv_mean = f64_div(tv_mean, f64_from_int(n_steps));

        let mut num: i64 = f64_from_int(0);
        let mut den: i64 = f64_from_int(0);
        s = 0;
        while s < n_steps {
            let si: i64 = f64_sub(f64_from_int(s), step_mean);
            let di: i64 = f64_sub(vec_get(step_tvs, s), tv_mean);
            num = f64_add(num, f64_mul(si, di));
            den = f64_add(den, f64_mul(si, si));
            s = s + 1;
        };
        if f64_gt(f64_abs(den), eps) == 1 { slope = f64_div(num, den); };
    };
    vec_push(features, slope);            // [9] divergence_slope

    // Feature 10: core_rank_stability
    // Compare which core has highest TV at step N/2 vs final
    let mut rank_corr: i64 = f64_from_int(0);
    if n_steps > 2 && nc > 2 {
        let mid: i64 = n_steps / 2;
        let mid_tvs: i64 = vec_new();
        let fin_tvs: i64 = vec_new();
        c = 1;
        while c < nc {
            vec_push(mid_tvs, vec_get(vec_get(tv_vecs, c), mid));
            vec_push(fin_tvs, vec_get(vec_get(tv_vecs, c), n_steps - 1));
            c = c + 1;
        };
        // Simple correlation: sum of sign agreements
        let mut agree: i64 = 0;
        let mut total: i64 = 0;
        let mut i: i64 = 0;
        while i < nc - 2 {
            let mut j: i64 = i + 1;
            while j < nc - 1 {
                let mid_order: i64 = f64_gt(vec_get(mid_tvs, i), vec_get(mid_tvs, j));
                let fin_order: i64 = f64_gt(vec_get(fin_tvs, i), vec_get(fin_tvs, j));
                if mid_order == fin_order { agree = agree + 1; };
                total = total + 1;
                j = j + 1;
            };
            i = i + 1;
        };
        if total > 0 { rank_corr = f64_div(f64_from_int(agree), f64_from_int(total)); };
    };
    vec_push(features, rank_corr);        // [10] core_rank_stability

    // --- Phase Features ---
    // Feature 11: final phase coherence (from recorded per-step data)
    let phase_vec: i64 = vec_get(mc, 8);
    let mut final_phase: i64 = f64_from_int(1);
    if n_steps > 0 { final_phase = vec_get(phase_vec, n_steps - 1); };
    vec_push(features, final_phase);      // [11] phase_coherence_final

    // Feature 12: phase drift rate (slope of phase coherence over steps)
    let mut phase_slope: i64 = f64_from_int(0);
    if n_steps > 1 {
        let ps_mean: i64 = f64_div(f64_from_int(n_steps - 1), f64_from_int(2));
        let mut pmean: i64 = f64_from_int(0);
        s = 0;
        while s < n_steps { pmean = f64_add(pmean, vec_get(phase_vec, s)); s = s + 1; };
        pmean = f64_div(pmean, f64_from_int(n_steps));
        let mut pnum: i64 = f64_from_int(0);
        let mut pden: i64 = f64_from_int(0);
        s = 0;
        while s < n_steps {
            let si: i64 = f64_sub(f64_from_int(s), ps_mean);
            let di: i64 = f64_sub(vec_get(phase_vec, s), pmean);
            pnum = f64_add(pnum, f64_mul(si, di));
            pden = f64_add(pden, f64_mul(si, si));
            s = s + 1;
        };
        if f64_gt(f64_abs(pden), eps) == 1 { phase_slope = f64_div(pnum, pden); };
    };
    vec_push(features, phase_slope);      // [12] phase_drift_rate

    // --- Clean Core Features ---
    // Feature 13: sparsity (nonzero amplitudes)
    let mut nonzero: i64 = 0;
    let mut i: i64 = 0;
    while i < n_amps {
        if f64_gt(vec_get(probs_clean, i), eps) == 1 { nonzero = nonzero + 1; };
        i = i + 1;
    };
    vec_push(features, f64_div(f64_from_int(nonzero), f64_from_int(n_amps))); // [13] sparsity

    // Feature 14-15: metadata
    vec_push(features, f64_from_int(nq));       // [14] n_qubits
    vec_push(features, f64_from_int(n_steps));  // [15] n_steps

    return features;
}

// =====================================================
// JSON Output
// =====================================================

fn mc_write_json(mc: i64, features: i64, circuit_name: str, filename: str) {
    let nc: i64 = mc_ncores(mc);
    let nq: i64 = mc_nq(mc);
    let n_steps: i64 = mc_step_count(mc);
    let n_feats: i64 = vec_len(features);

    let sb: i64 = sb_new();
    sb_append(sb, "{\"circuit\":\""); sb_append(sb, circuit_name);
    sb_append(sb, "\",\"n_cores\":"); sb_append(sb, int_to_str(nc));
    sb_append(sb, ",\"n_qubits\":"); sb_append(sb, int_to_str(nq));
    sb_append(sb, ",\"n_steps\":"); sb_append(sb, int_to_str(n_steps));

    let feat_names: i64 = vec_new();
    vec_push(feat_names, "mean_tv"); vec_push(feat_names, "std_tv");
    vec_push(feat_names, "min_tv"); vec_push(feat_names, "max_tv");
    vec_push(feat_names, "mean_fidelity"); vec_push(feat_names, "mean_kl");
    vec_push(feat_names, "max_kl"); vec_push(feat_names, "ensemble_agreement");
    vec_push(feat_names, "divergence_onset"); vec_push(feat_names, "divergence_slope");
    vec_push(feat_names, "core_rank_stability"); vec_push(feat_names, "phase_coherence_final");
    vec_push(feat_names, "phase_drift_rate"); vec_push(feat_names, "sparsity");
    vec_push(feat_names, "n_qubits_f"); vec_push(feat_names, "n_steps_f");

    sb_append(sb, ",\"features\":{");
    let mut i: i64 = 0;
    while i < n_feats {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "\"");
        if i < vec_len(feat_names) { sb_append(sb, vec_get(feat_names, i)); }
        else { sb_append(sb, "f"); sb_append(sb, int_to_str(i)); };
        sb_append(sb, "\":");
        sb_append(sb, f64_to_str_6(vec_get(features, i)));
        i = i + 1;
    };
    sb_append(sb, "}}");

    file_write_string(filename, sb_to_str(sb));
}
