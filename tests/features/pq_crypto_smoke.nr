// v0.8.225 stdlib/rods/pq_crypto.nr first test coverage.
//
// RFC-0058 Phase A: post-quantum crypto surface (rod-only).
// **Runtime is a STUB** — every primitive returns deterministic
// test vectors, NOT secure crypto. Phase B (~400 LOC compiler +
// ~2000 LOC stdlib + per-algorithm reference implementations)
// is deferred. Pre-v0.8.225: zero coverage on the standalone
// rod.
//
// Locks four invariants Phase B compiler enforcement of
// `@crypto_agile` and phantom-typed `PublicKey<Algo>` /
// `SecretKey<Algo>` / `Signature<Algo>` must NOT regress:
//
//   1. **Stable algorithm IDs + kind** — ML-KEM=1 (kem),
//      ML-DSA=2 (sig), SLH-DSA=3 (sig).
//   2. **Security levels map to bits** — L1 = 128, L3 = 192,
//      L5 = 256 (NIST AES-equivalent classical strength).
//   3. **mldsa sign + verify round-trip** — sign then verify
//      same digest returns 1; pq_clear isolates between calls.
//   4. **crypto-agile defaults** — pick_kem == ML-KEM,
//      pick_sig == ML-DSA, pick_sig_backup == SLH-DSA.
//
// Expected: rc=0.

import "stdlib/rods/pq_crypto.nr"

fn check_algo_ids() -> i64 {
    if pq_algo_mlkem() != 1 { return 1; };
    if pq_algo_mldsa() != 2 { return 2; };
    if pq_algo_slhdsa() != 3 { return 4; };
    if pq_algo_kind(pq_algo_mlkem()) != pq_algo_kind_kem() { return 8; };
    if pq_algo_kind(pq_algo_mldsa()) != pq_algo_kind_sig() { return 16; };
    if pq_algo_kind(pq_algo_slhdsa()) != pq_algo_kind_sig() { return 32; };
    return 0;
}

fn check_security_levels() -> i64 {
    if security_level_bits(security_level_1()) != 128 { return 64; };
    if security_level_bits(security_level_3()) != 192 { return 128; };
    if security_level_bits(security_level_5()) != 256 { return 256; };
    return 0;
}

fn check_sign_verify_round_trip() -> i64 {
    pq_clear();
    let kp: KeypairHandle = mldsa_keygen(security_level_3());
    let sig: SignatureHandle = mldsa_sign(kp, 305419896);  // 0x12345678
    if mldsa_verify(kp, 305419896, sig) != 1 { return 512; };
    return 0;
}

fn check_crypto_agile_defaults() -> i64 {
    if crypto_agile_pick_kem() != pq_algo_mlkem() { return 1024; };
    if crypto_agile_pick_sig() != pq_algo_mldsa() { return 2048; };
    if crypto_agile_pick_sig_backup() != pq_algo_slhdsa() { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_algo_ids();
    fails = fails + check_security_levels();
    fails = fails + check_sign_verify_round_trip();
    fails = fails + check_crypto_agile_defaults();
    return fails;
}
