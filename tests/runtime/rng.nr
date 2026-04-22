// rng — RFC-0017 stdlib enrichment: deterministic xoshiro-backed PRNG.
//
// Public surface:
//   rng_seed(seed, _reserved)    seed the global state
//   rng_int(lo, hi)              uniform int in [lo, hi]
//   rng_uniform()                f64 cell in [0, 1)
//   rng_normal()                 f64 cell ~ N(0, 1)
//   rng_bernoulli(p_bits)        0 / 1 (p as f64 cell)
//   rng_exponential(lambda_bits) f64 cell, exponential dist
//
// random_uniform / random_normal are legacy aliases (each takes a
// reserved arg); they previously had no runtime backing — v0.2.15
// closes that latent linker gap.

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Seeded determinism: same seed → same first value.
    rng_seed(42, 0);
    let n1: i64 = rng_int(1, 100);
    rng_seed(42, 0);
    let n2: i64 = rng_int(1, 100);
    if n1 != n2 { fail = fail + 1; print("FAIL rng_int determinism"); };

    // Range membership.
    rng_seed(7, 0);
    let mut i: i64 = 0;
    while i < 50 {
        let r: i64 = rng_int(10, 20);
        if r < 10 { fail = fail + 1; print("FAIL rng_int < lo"); };
        if r > 20 { fail = fail + 1; print("FAIL rng_int > hi"); };
        i = i + 1;
    };

    // Bernoulli edge cases via f64 0.0 / 1.0 bit patterns.
    let zero: i64 = i32_to_f64(0);
    if rng_bernoulli(zero) != 0 { fail = fail + 1; print("FAIL bernoulli p=0"); };

    if fail == 0 { print("OK rng"); return 0; };
    return 1;
}
