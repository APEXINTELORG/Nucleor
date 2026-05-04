/* pq_crypto_rt.c — RFC-0058 Phase A: PQ-crypto handle registry.
 * STUB IMPLEMENTATION — every primitive returns deterministic
 * test vectors derived from a per-keypair counter, NOT secure
 * crypto. Adopters get the API surface today; Phase B brings
 * in NIST FIPS 203/204/205 reference implementations. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_PQ_KEYPAIR_MAX 256
#define NUC_PQ_SIGNATURE_MAX 1024

typedef struct {
    long long algo_id;
    long long level;
    long long counter;
    int in_use;
} NucKeypair;

typedef struct {
    long long keypair_h;
    long long msg_digest;
    int in_use;
} NucSignature;

static NucKeypair _nuc_keypairs[NUC_PQ_KEYPAIR_MAX];
static int _nuc_keypair_count = 0;
static NucSignature _nuc_signatures[NUC_PQ_SIGNATURE_MAX];
static int _nuc_signature_count = 0;

long long nuc_pq_keygen(long long algo_id, long long level) {
    if (_nuc_keypair_count >= NUC_PQ_KEYPAIR_MAX) return -1;
    NucKeypair *k = &_nuc_keypairs[_nuc_keypair_count];
    k->algo_id = algo_id;
    k->level = level;
    k->counter = 0;
    k->in_use = 1;
    _nuc_keypair_count++;
    return (long long)(_nuc_keypair_count - 1);
}

long long nuc_pq_keypair_algo(long long handle) {
    if (handle < 0 || handle >= _nuc_keypair_count) return 0;
    return _nuc_keypairs[handle].algo_id;
}

long long nuc_pq_keypair_level(long long handle) {
    if (handle < 0 || handle >= _nuc_keypair_count) return 0;
    return _nuc_keypairs[handle].level;
}

long long nuc_pq_keypair_count(void) { return (long long)_nuc_keypair_count; }

/* Deterministic encap stub: returns a ciphertext = hash(handle, counter)
 * via a simple xorshift mix. The decap returns the same value, so the
 * encap/decap round-trip yields a stable shared secret. */
static long long _nuc_pq_mix(long long h, long long c) {
    long long x = (h * 6364136223846793005LL) ^ (c + 1442695040888963407LL);
    x ^= (x << 13);
    x ^= ((unsigned long long)x >> 7);
    x ^= (x << 17);
    return x;
}

long long nuc_pq_encap(long long keypair_h) {
    if (keypair_h < 0 || keypair_h >= _nuc_keypair_count) return 0;
    NucKeypair *k = &_nuc_keypairs[keypair_h];
    if (!k->in_use) return 0;
    long long ct = _nuc_pq_mix(keypair_h, k->counter);
    k->counter++;
    return ct;
}

long long nuc_pq_decap(long long keypair_h, long long ciphertext) {
    if (keypair_h < 0 || keypair_h >= _nuc_keypair_count) return 0;
    if (!_nuc_keypairs[keypair_h].in_use) return 0;
    /* Phase A: shared secret = ciphertext. Phase B: real
     * lattice-based decapsulation. */
    return ciphertext;
}

long long nuc_pq_sign(long long keypair_h, long long msg_digest) {
    if (keypair_h < 0 || keypair_h >= _nuc_keypair_count) return -1;
    if (!_nuc_keypairs[keypair_h].in_use) return -1;
    if (_nuc_signature_count >= NUC_PQ_SIGNATURE_MAX) return -1;
    NucSignature *s = &_nuc_signatures[_nuc_signature_count];
    s->keypair_h = keypair_h;
    s->msg_digest = msg_digest;
    s->in_use = 1;
    _nuc_signature_count++;
    return (long long)(_nuc_signature_count - 1);
}

long long nuc_pq_verify(long long keypair_h, long long msg_digest, long long sig_h) {
    if (sig_h < 0 || sig_h >= _nuc_signature_count) return 0;
    NucSignature *s = &_nuc_signatures[sig_h];
    if (!s->in_use) return 0;
    if (s->keypair_h != keypair_h) return 0;
    if (s->msg_digest != msg_digest) return 0;
    return 1;
}

long long nuc_pq_clear(void) {
    for (int i = 0; i < _nuc_keypair_count; i++) {
        memset(&_nuc_keypairs[i], 0, sizeof(NucKeypair));
    }
    _nuc_keypair_count = 0;
    for (int i = 0; i < _nuc_signature_count; i++) {
        memset(&_nuc_signatures[i], 0, sizeof(NucSignature));
    }
    _nuc_signature_count = 0;
    return 0;
}
