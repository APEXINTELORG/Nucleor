// v0.8.2 RFC-0058 Phase A smoke fixture — post-quantum crypto
// surface. Validates:
//   - Algorithm tags + name + kind dispatch
//   - SecurityLevel tags + bit-strength + name lookup
//   - HashFn tags + name lookup
//   - ML-KEM keygen / encap / decap round-trip (shared secret
//     matches across the encap/decap pair)
//   - ML-DSA keygen / sign / verify (correct verify = 1,
//     wrong digest = 0, wrong keypair = 0)
//   - SLH-DSA keygen / sign / verify
//   - Crypto-agility default picks
//   - Keypair count + clear-to-zero
import "stdlib/rods/pq_crypto.nr"

fn main() -> i64 {
    pq_clear();

    // Algorithm tags.
    if pq_algo_mlkem() != 1 { return 1; };
    if pq_algo_mldsa() != 2 { return 2; };
    if pq_algo_slhdsa() != 3 { return 3; };
    if str_eq(pq_algo_name(1), "ML-KEM") == 0 { return 4; };
    if str_eq(pq_algo_name(99), "Unknown") == 0 { return 5; };

    if pq_algo_kind(pq_algo_mlkem()) != pq_algo_kind_kem() { return 6; };
    if pq_algo_kind(pq_algo_mldsa()) != pq_algo_kind_sig() { return 7; };
    if pq_algo_kind(pq_algo_slhdsa()) != pq_algo_kind_sig() { return 8; };

    // SecurityLevel tags.
    if security_level_1() != 1 { return 9; };
    if security_level_3() != 3 { return 10; };
    if security_level_5() != 5 { return 11; };
    if security_level_bits(security_level_1()) != 128 { return 12; };
    if security_level_bits(security_level_3()) != 192 { return 13; };
    if security_level_bits(security_level_5()) != 256 { return 14; };
    if str_eq(security_level_name(3), "L3") == 0 { return 15; };

    // HashFn tags.
    if hash_fn_sha256() != 1 { return 16; };
    if str_eq(hash_fn_name(hash_fn_shake256()), "SHAKE-256") == 0 { return 17; };

    // ML-KEM round-trip.
    let kp_kem: KeypairHandle = mlkem_keygen(security_level_3());
    if pq_keypair_algo(kp_kem) != pq_algo_mlkem() { return 18; };
    if pq_keypair_level(kp_kem) != security_level_3() { return 19; };

    let ct: i64 = mlkem_encap(kp_kem);
    let secret: i64 = mlkem_decap(kp_kem, ct);
    // Phase A stub: secret == ciphertext. Real Phase B will be
    // a lattice-based shared-secret derivation but the round-
    // trip still verifies sender + receiver share identical
    // bits.
    if secret != ct { return 20; };

    // ML-DSA sign/verify.
    let kp_dsa: KeypairHandle = mldsa_keygen(security_level_5());
    let msg: i64 = 0xCAFEBABE;
    let sig: SignatureHandle = mldsa_sign(kp_dsa, msg);
    if mldsa_verify(kp_dsa, msg, sig) != 1 { return 21; };

    // Wrong digest -> reject.
    if mldsa_verify(kp_dsa, 0xDEADBEEF, sig) != 0 { return 22; };

    // Wrong keypair -> reject.
    let kp_other: KeypairHandle = mldsa_keygen(security_level_5());
    if mldsa_verify(kp_other, msg, sig) != 0 { return 23; };

    // SLH-DSA sign/verify.
    let kp_slh: KeypairHandle = slhdsa_keygen(security_level_3(), hash_fn_shake128());
    if pq_keypair_algo(kp_slh) != pq_algo_slhdsa() { return 24; };
    let sig2: SignatureHandle = slhdsa_sign(kp_slh, msg);
    if slhdsa_verify(kp_slh, msg, sig2) != 1 { return 25; };
    if slhdsa_verify(kp_slh, 0, sig2) != 0 { return 26; };

    // Crypto-agility defaults.
    if crypto_agile_pick_kem() != pq_algo_mlkem() { return 27; };
    if crypto_agile_pick_sig() != pq_algo_mldsa() { return 28; };
    if crypto_agile_pick_sig_backup() != pq_algo_slhdsa() { return 29; };

    // Keypair count + clear.
    if pq_keypair_count() != 4 { return 30; };
    pq_clear();
    if pq_keypair_count() != 0 { return 31; };

    return 0;
}
