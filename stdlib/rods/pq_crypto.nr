// rods/pq_crypto — RFC-0058 Phase A: post-quantum crypto
// surface (rod-only).
//
// The full RFC-0058 ship adds NIST-standardized PQ primitives
// to std.security (ML-KEM / ML-DSA / SLH-DSA) plus a
// `@crypto_agile` annotation for crypto-of-the-day algorithm
// selection (~400 LOC compiler + ~2000 LOC stdlib + per-
// algorithm reference implementations). Phase A (this rod +
// runtime) lands the canonical algorithm tags + opaque
// keypair handles + a placeholder generate/encap/sign surface
// adopters can wire today. The runtime is a STUB — every
// primitive returns deterministic test vectors, NOT secure
// crypto. Phase B brings in the reference implementations.
//
// Sister to RFC-0052 / 53 / 54 / 55 / 56 / 57 Phase A — closes
// the V2 frontier Tier-B lane (RFC-0052 through RFC-0058) at
// Phase A scope.
//
// Workflow today:
//
//   import "stdlib/rods/pq_crypto.nr"
//
//   let kp: KeypairHandle = mlkem_keygen(security_level_3());
//   let ct: i64 = mlkem_encap(kp);
//   let secret: i64 = mlkem_decap(kp, ct);
//
//   let sig: SignatureHandle = mldsa_sign(kp, 0xDEAD);
//   if mldsa_verify(kp, 0xDEAD, sig) == 1 { ... };

#cfile "../runtime/pq_crypto_rt.c"

extern fn nuc_pq_keygen(algo_id: i64, level: i64) -> i64;
extern fn nuc_pq_encap(keypair_h: i64) -> i64;
extern fn nuc_pq_decap(keypair_h: i64, ciphertext: i64) -> i64;
extern fn nuc_pq_sign(keypair_h: i64, msg_digest: i64) -> i64;
extern fn nuc_pq_verify(keypair_h: i64, msg_digest: i64, sig_h: i64) -> i64;
extern fn nuc_pq_keypair_algo(keypair_h: i64) -> i64;
extern fn nuc_pq_keypair_level(keypair_h: i64) -> i64;
extern fn nuc_pq_keypair_count() -> i64;
extern fn nuc_pq_clear() -> i64;

// =====================================================
// Algorithm tags (stable IDs).
// =====================================================
fn pq_algo_mlkem()  -> i64 { return 1; }   // Kyber / ML-KEM (NIST FIPS 203)
fn pq_algo_mldsa()  -> i64 { return 2; }   // Dilithium / ML-DSA (NIST FIPS 204)
fn pq_algo_slhdsa() -> i64 { return 3; }   // SPHINCS+ / SLH-DSA (NIST FIPS 205)
fn pq_algo_unknown() -> i64 { return 0; }

fn pq_algo_name(id: i64) -> str {
    if id == 1 { return "ML-KEM"; };
    if id == 2 { return "ML-DSA"; };
    if id == 3 { return "SLH-DSA"; };
    return "Unknown";
}

fn pq_algo_kind_kem() -> i64 { return 1; }    // key encapsulation
fn pq_algo_kind_sig() -> i64 { return 2; }    // signature

fn pq_algo_kind(id: i64) -> i64 {
    if id == 1 { return pq_algo_kind_kem(); };
    if id == 2 { return pq_algo_kind_sig(); };
    if id == 3 { return pq_algo_kind_sig(); };
    return 0;
}

// =====================================================
// SecurityLevel tags (NIST Levels 1 / 3 / 5 = 128 / 192 / 256-
// bit classical-equivalent strength).
// =====================================================
fn security_level_1() -> i64 { return 1; }   // ~AES-128
fn security_level_3() -> i64 { return 3; }   // ~AES-192
fn security_level_5() -> i64 { return 5; }   // ~AES-256

fn security_level_bits(level: i64) -> i64 {
    if level == 1 { return 128; };
    if level == 3 { return 192; };
    if level == 5 { return 256; };
    return 0;
}

fn security_level_name(level: i64) -> str {
    if level == 1 { return "L1"; };
    if level == 3 { return "L3"; };
    if level == 5 { return "L5"; };
    return "L?";
}

// =====================================================
// HashFn tags (SLH-DSA per-instance choice).
// =====================================================
fn hash_fn_sha256()    -> i64 { return 1; }
fn hash_fn_sha512()    -> i64 { return 2; }
fn hash_fn_shake128()  -> i64 { return 3; }
fn hash_fn_shake256()  -> i64 { return 4; }

fn hash_fn_name(id: i64) -> str {
    if id == 1 { return "SHA-256"; };
    if id == 2 { return "SHA-512"; };
    if id == 3 { return "SHAKE-128"; };
    if id == 4 { return "SHAKE-256"; };
    return "Unknown";
}

// =====================================================
// Keypair / Signature handles. Phase A: opaque i64s into the
// runtime registry; Phase B promotes to phantom-typed
// PublicKey<Algo> / SecretKey<Algo> / Signature<Algo>.
// =====================================================
struct KeypairHandle { handle: i64, algo: i64, level: i64 }
struct SignatureHandle { handle: i64, algo: i64 }

// =====================================================
// ML-KEM (Kyber) — key encapsulation.
// =====================================================
fn mlkem_keygen(level: i64) -> KeypairHandle {
    let h: i64 = nuc_pq_keygen(pq_algo_mlkem(), level);
    return KeypairHandle { handle: h, algo: pq_algo_mlkem(), level: level };
}

fn mlkem_encap(kp: KeypairHandle) -> i64 {
    return nuc_pq_encap(kp.handle);
}

fn mlkem_decap(kp: KeypairHandle, ciphertext: i64) -> i64 {
    return nuc_pq_decap(kp.handle, ciphertext);
}

// =====================================================
// ML-DSA (Dilithium) — digital signatures.
// =====================================================
fn mldsa_keygen(level: i64) -> KeypairHandle {
    let h: i64 = nuc_pq_keygen(pq_algo_mldsa(), level);
    return KeypairHandle { handle: h, algo: pq_algo_mldsa(), level: level };
}

fn mldsa_sign(kp: &KeypairHandle, msg_digest: i64) -> SignatureHandle {
    let s: i64 = nuc_pq_sign(kp.handle, msg_digest);
    return SignatureHandle { handle: s, algo: pq_algo_mldsa() };
}

fn mldsa_verify(kp: &KeypairHandle, msg_digest: i64, sig: &SignatureHandle) -> i64 {
    return nuc_pq_verify(kp.handle, msg_digest, sig.handle);
}

// =====================================================
// SLH-DSA (SPHINCS+) — stateless hash-based, backup-class.
// hash_fn_id selects the inner hash family per SPHINCS+
// instance.
// =====================================================
fn slhdsa_keygen(level: i64, hash_fn_id: i64) -> KeypairHandle {
    // Phase A: hash_fn_id is recorded but the stub doesn't
    // distinguish per-hash vectors. Phase B per-hash impls.
    let h: i64 = nuc_pq_keygen(pq_algo_slhdsa(), level);
    return KeypairHandle { handle: h, algo: pq_algo_slhdsa(), level: level };
}

fn slhdsa_sign(kp: KeypairHandle, msg_digest: i64) -> SignatureHandle {
    let s: i64 = nuc_pq_sign(kp.handle, msg_digest);
    return SignatureHandle { handle: s, algo: pq_algo_slhdsa() };
}

fn slhdsa_verify(kp: KeypairHandle, msg_digest: i64, sig: SignatureHandle) -> i64 {
    return nuc_pq_verify(kp.handle, msg_digest, sig.handle);
}

// =====================================================
// Introspection.
// =====================================================
fn pq_keypair_algo(kp: KeypairHandle) -> i64 { return kp.algo; }
fn pq_keypair_level(kp: KeypairHandle) -> i64 { return kp.level; }
fn pq_keypair_count() -> i64 { return nuc_pq_keypair_count(); }
fn pq_clear() -> i64 { return nuc_pq_clear(); }

// =====================================================
// Crypto-agility: Phase A returns the canonical preferred
// algorithm for a given workload. Phase B reads the runtime
// crypto-config and gates by the @crypto_agile annotation.
// =====================================================
fn crypto_agile_pick_kem() -> i64 { return pq_algo_mlkem(); }
fn crypto_agile_pick_sig() -> i64 { return pq_algo_mldsa(); }
fn crypto_agile_pick_sig_backup() -> i64 { return pq_algo_slhdsa(); }
