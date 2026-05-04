# RFC-0058 — Post-Quantum Cryptography in `std.security`

**Status:** Draft (frontier — V2.13, mostly rod-level)
**Date:** 2026-05-03

## Motivation

Quantum computers will eventually break RSA / ECC / DH (Shor's algorithm). NIST has standardized three replacement primitives in 2024:
- **ML-KEM** (Kyber) — key encapsulation
- **ML-DSA** (Dilithium) — digital signatures
- **SLH-DSA** (SPHINCS+) — stateless hash-based signatures (backup-class)

Adopters building anything that needs to outlive the next 10–15 years (long-lived signed code, time-stamped attestations, etc.) need PQ from day one. Nucleor's `crypto.nr` rod has classical primitives only.

## Design

Mostly rod-level. One language-level convention: a `crypto-agility` annotation that lets adopters declare they accept the algorithm-of-the-day rather than pinning a specific primitive.

### Rod surface (`std.security` extensions)

```nucleor
// ML-KEM (Key Encapsulation)
fn mlkem_keygen(level: SecurityLevel) -> (PublicKey, SecretKey)
fn mlkem_encap(pk: &PublicKey) -> (Ciphertext, SharedSecret)
fn mlkem_decap(sk: &SecretKey, ct: &Ciphertext) -> SharedSecret

// ML-DSA (Digital Signatures)
fn mldsa_keygen(level: SecurityLevel) -> (PublicKey, SecretKey)
fn mldsa_sign(sk: &SecretKey, msg: &[u8]) -> Signature
fn mldsa_verify(pk: &PublicKey, msg: &[u8], sig: &Signature) -> bool

// SLH-DSA (Stateless Hash-Based, backup)
fn slhdsa_keygen(level: SecurityLevel, hash: HashFn) -> (PublicKey, SecretKey)
fn slhdsa_sign(sk: &SecretKey, msg: &[u8]) -> Signature
fn slhdsa_verify(pk: &PublicKey, msg: &[u8], sig: &Signature) -> bool

enum SecurityLevel { L1, L3, L5 }    // 128, 192, 256-bit security strength
enum HashFn { SHA256, SHA512, SHAKE128, SHAKE256 }
```

### Crypto-agility (language-level convention)

```nucleor
@crypto_agile(prefer=[ML_DSA, SLH_DSA], avoid=[Ed25519, ECDSA])
fn sign_release(payload: &[u8]) -> Signature {
    // body uses an abstract Signer; runtime picks first available preferred algorithm
}
```

The annotation is parsed and emitted as fn metadata; the runtime crypto-config (read from `std.security::config()`) selects from the preferred list.

### Migration path for existing signed-release infrastructure

Nucleor's existing Ed25519 release signing stays for backward compat. New releases dual-sign with ML-DSA. The release-verify pass accepts either (with `@crypto_agile` semantics).

## Implementation

V2.13 ship:
- **Stdlib:** `std.security` adds 9 PQ functions + 2 enums. ~2000 LOC stdlib.
- **Runtime:** link against `liboqs` (Open Quantum Safe — NIST PQ reference impls) OR vendor-impl-equivalent. Today liboqs is the reference; future ships may move to a Nucleor-native impl for self-host independence.
- **Compiler:** `@crypto_agile` attribute parser (~50 LOC). No type-system changes.
- **Release pipeline:** dual-sign Nucleor releases with Ed25519 + ML-DSA going forward. `nuc verify` accepts either.

## Cost

V2.13: ~2000 LOC stdlib + liboqs link wiring + ~50 LOC compiler attribute. ~1 week.

## Hot-path risk

None — crypto ops are not on the hot compile path.

## Frontier connection

Direct frontier writeup §3.2.7 "Post-quantum crypto from day one." Pairs with **RFC-0057 enclave types** (attestation quotes signed with ML-DSA going forward).

## Closure criteria

- All 3 PQ primitive families work end-to-end (keygen / encap-decap or sign-verify).
- Cross-impl interop with liboqs reference test vectors.
- Nucleor v2.13+ releases dual-signed Ed25519 + ML-DSA.
- `nuc verify` accepts either signature.
- Round-2 self-host fixed-point holds.
