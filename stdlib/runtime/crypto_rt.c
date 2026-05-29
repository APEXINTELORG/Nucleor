// crypto_rt.c — Cryptographic Primitives for Nucleor
// SHA-256, HMAC-SHA256, base64, cryptographically-secure random.
// All from scratch, no external libraries.
// SEC-2: no symmetric cipher (AES) is implemented here. Do not
// advertise one until a real, test-vector-verified AEAD construction
// (e.g. AES-GCM / ChaCha20-Poly1305) lands — never ECB as a headline.
//
// Compile: clang -c stdlib/runtime/crypto_rt.c -o target/crypto_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <wincrypt.h>
#else
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#if defined(__linux__)
#include <sys/random.h>
#endif
#endif

// ================================================================
//  SHA-256
// ================================================================

static const unsigned int K256[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

#define RR(x,n) (((x)>>(n))|((x)<<(32-(n))))
#define CH(e,f,g) (((e)&(f))^((~(e))&(g)))
#define MAJ(a,b,c) (((a)&(b))^((a)&(c))^((b)&(c)))
#define S0(x) (RR(x,2)^RR(x,13)^RR(x,22))
#define S1(x) (RR(x,6)^RR(x,11)^RR(x,25))
#define s0(x) (RR(x,7)^RR(x,18)^((x)>>3))
#define s1(x) (RR(x,17)^RR(x,19)^((x)>>10))

static void sha256_block(unsigned int H[8], const unsigned char *data) {
    unsigned int W[64], a, b, c, d, e, f, g, h;
    for (int i = 0; i < 16; i++)
        W[i] = (data[i*4]<<24)|(data[i*4+1]<<16)|(data[i*4+2]<<8)|data[i*4+3];
    for (int i = 16; i < 64; i++)
        W[i] = s1(W[i-2]) + W[i-7] + s0(W[i-15]) + W[i-16];

    a=H[0]; b=H[1]; c=H[2]; d=H[3]; e=H[4]; f=H[5]; g=H[6]; h=H[7];
    for (int i = 0; i < 64; i++) {
        unsigned int t1 = h + S1(e) + CH(e,f,g) + K256[i] + W[i];
        unsigned int t2 = S0(a) + MAJ(a,b,c);
        h=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
    }
    H[0]+=a; H[1]+=b; H[2]+=c; H[3]+=d; H[4]+=e; H[5]+=f; H[6]+=g; H[7]+=h;
}

// Returns 32-byte hash as hex string
const char *nuc_sha256(const char *data, long long len) {
    unsigned int H[8] = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };
    // SEC-4: do not truncate the 64-bit length to int. A negative length
    // is treated as empty; size_t arithmetic keeps the padding math and
    // block loop correct for inputs above INT_MAX.
    if (len < 0) len = 0;
    size_t n = (size_t)len;

    // Padding
    size_t padded_len = ((n + 9 + 63) / 64) * 64;
    unsigned char *msg = (unsigned char *)calloc(padded_len, 1);
    memcpy(msg, data, n);
    msg[n] = 0x80;
    unsigned long long bits = (unsigned long long)n * 8;
    for (int i = 0; i < 8; i++) msg[padded_len - 1 - i] = (unsigned char)(bits >> (i * 8));

    for (size_t i = 0; i < padded_len; i += 64) sha256_block(H, msg + i);
    free(msg);

    char *hex = (char *)malloc(65);
    for (int i = 0; i < 8; i++) sprintf(hex + i * 8, "%08x", H[i]);
    hex[64] = 0;
    return hex;
}

// ================================================================
//  HMAC-SHA256
// ================================================================

const char *nuc_hmac_sha256(const char *key, long long key_len,
                             const char *data, long long data_len) {
    // SEC-4: reject negative lengths before any (size_t) cast — a
    // negative→unsigned conversion would request an astronomically
    // large copy/allocation.
    if (key_len < 0) key_len = 0;
    if (data_len < 0) data_len = 0;

    unsigned char k_pad[64] = {0};
    if (key_len > 64) {
        // Hash the key first
        const char *hk = nuc_sha256(key, key_len);
        for (int i = 0; i < 32; i++) {
            unsigned int byte;
            sscanf(hk + i * 2, "%02x", &byte);
            k_pad[i] = (unsigned char)byte;
        }
    } else {
        memcpy(k_pad, key, (size_t)key_len);
    }

    // Inner: SHA256(k_ipad || data)
    unsigned char *inner_msg = (unsigned char *)malloc(64 + (size_t)data_len);
    for (int i = 0; i < 64; i++) inner_msg[i] = k_pad[i] ^ 0x36;
    memcpy(inner_msg + 64, data, (size_t)data_len);
    const char *inner_hash = nuc_sha256((const char *)inner_msg, 64 + data_len);
    free(inner_msg);

    // Convert inner hash hex to bytes
    unsigned char inner_bytes[32];
    for (int i = 0; i < 32; i++) {
        unsigned int byte;
        sscanf(inner_hash + i * 2, "%02x", &byte);
        inner_bytes[i] = (unsigned char)byte;
    }

    // Outer: SHA256(k_opad || inner_hash)
    unsigned char outer_msg[96];
    for (int i = 0; i < 64; i++) outer_msg[i] = k_pad[i] ^ 0x5c;
    memcpy(outer_msg + 64, inner_bytes, 32);
    return nuc_sha256((const char *)outer_msg, 96);
}

// ================================================================
//  Base64 Encode/Decode
// ================================================================

static const char b64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

const char *nuc_base64_encode(const char *data, long long len) {
    if (len < 0) len = 0;                       // SEC-4: no int truncation
    size_t n = (size_t)len;
    size_t out_len = 4 * ((n + 2) / 3);
    char *out = (char *)malloc(out_len + 1);
    size_t j = 0;
    for (size_t i = 0; i < n; i += 3) {
        unsigned int val = ((unsigned char)data[i]) << 16;
        if (i + 1 < n) val |= ((unsigned char)data[i + 1]) << 8;
        if (i + 2 < n) val |= (unsigned char)data[i + 2];
        out[j++] = b64_table[(val >> 18) & 0x3F];
        out[j++] = b64_table[(val >> 12) & 0x3F];
        out[j++] = (i + 1 < n) ? b64_table[(val >> 6) & 0x3F] : '=';
        out[j++] = (i + 2 < n) ? b64_table[val & 0x3F] : '=';
    }
    out[j] = 0;
    return out;
}

const char *nuc_base64_decode(const char *data, long long len) {
    // SEC-3: well-formed base64 is a non-empty multiple of 4 chars. The
    // previous loop stepped i by 4 but indexed data[i+2]/data[i+3]
    // unconditionally, reading (and deriving writes) past the buffer for
    // any truncated input. Reject malformed lengths up front and return a
    // valid empty C-string, so callers never see a NULL or a short buffer.
    // SEC-4: size_t throughout, negative length treated as empty.
    if (len < 0) len = 0;
    if (len == 0 || (len % 4) != 0) {
        char *empty = (char *)malloc(1);
        empty[0] = 0;
        return empty;
    }
    size_t n = (size_t)len;
    size_t out_cap = (n / 4) * 3;               // safe upper bound
    unsigned char *out = (unsigned char *)malloc(out_cap + 1);
    size_t j = 0;
    for (size_t i = 0; i < n; i += 4) {
        // i + 3 < n is guaranteed here (n % 4 == 0), so every read below
        // is in bounds.
        unsigned int vals[4] = {0};
        for (int k = 0; k < 4; k++) {
            char c = data[i + (size_t)k];
            if (c >= 'A' && c <= 'Z') vals[k] = c - 'A';
            else if (c >= 'a' && c <= 'z') vals[k] = c - 'a' + 26;
            else if (c >= '0' && c <= '9') vals[k] = c - '0' + 52;
            else if (c == '+') vals[k] = 62;
            else if (c == '/') vals[k] = 63;
            // '=' padding or any stray char decodes to 0
        }
        unsigned int triple = (vals[0] << 18) | (vals[1] << 12) | (vals[2] << 6) | vals[3];
        out[j++] = (triple >> 16) & 0xFF;
        if (data[i + 2] != '=') out[j++] = (triple >> 8) & 0xFF;
        if (data[i + 3] != '=') out[j++] = triple & 0xFF;
    }
    out[j] = 0;
    return (const char *)out;
}

// ================================================================
//  Cryptographic Random Bytes
// ================================================================

// SEC-1: a CSPRNG must never silently return non-random or partial
// bytes. The previous implementation truncated the length to int,
// ignored the result of CryptGenRandom / read(), and — on any failure
// (provider acquire fails, /dev/urandom missing, short read) — returned
// leaving the caller's buffer untouched (uninitialised stack/heap, i.e.
// predictable). Every failure path now aborts loudly, the buffer is
// always filled to completion, and the length is no longer truncated.
void nuc_random_bytes(long long buf_h, long long len) {
    unsigned char *buf = (unsigned char *)(void *)buf_h;

    if (len < 0) {
        fprintf(stderr, "PANIC: nuc_random_bytes: negative length %lld\n", len);
        fflush(stderr);
        exit(1);
    }
    if (len == 0) return;
    size_t want = (size_t)len;

#ifdef _WIN32
    // CryptGenRandom fills the whole buffer or fails outright; check both
    // calls and abort rather than leave the buffer uninitialised.
    HCRYPTPROV prov;
    if (!CryptAcquireContextA(&prov, NULL, NULL, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT)) {
        fprintf(stderr, "PANIC: nuc_random_bytes: CryptAcquireContext failed (err=%lu)\n",
                (unsigned long)GetLastError());
        fflush(stderr);
        exit(1);
    }
    BOOL ok = CryptGenRandom(prov, (DWORD)want, (BYTE *)buf);
    CryptReleaseContext(prov, 0);
    if (!ok) {
        fprintf(stderr, "PANIC: nuc_random_bytes: CryptGenRandom failed (err=%lu)\n",
                (unsigned long)GetLastError());
        fflush(stderr);
        exit(1);
    }
#else
    size_t total = 0;

#if defined(__linux__)
    // Fast path: getrandom(2). Loop over short reads / EINTR; on a hard
    // error (e.g. ENOSYS on an old kernel) fall through to /dev/urandom
    // for the remaining bytes (any prefix already written is preserved).
    while (total < want) {
        ssize_t r = getrandom(buf + total, want - total, 0);
        if (r < 0) {
            if (errno == EINTR) continue;
            break;
        }
        total += (size_t)r;
    }
    if (total == want) return;
#endif

    // Portable path: read /dev/urandom to completion. A partial read or
    // any error is a hard failure for a CSPRNG — never return weak bytes.
    int fd = open("/dev/urandom", O_RDONLY
#ifdef O_CLOEXEC
                  | O_CLOEXEC
#endif
                  );
    if (fd < 0) {
        fprintf(stderr, "PANIC: nuc_random_bytes: cannot open /dev/urandom (errno=%d)\n", errno);
        fflush(stderr);
        exit(1);
    }
    while (total < want) {
        ssize_t r = read(fd, buf + total, want - total);
        if (r < 0) {
            if (errno == EINTR) continue;
            close(fd);
            fprintf(stderr, "PANIC: nuc_random_bytes: read(/dev/urandom) failed (errno=%d)\n", errno);
            fflush(stderr);
            exit(1);
        }
        if (r == 0) {
            close(fd);
            fprintf(stderr, "PANIC: nuc_random_bytes: unexpected EOF on /dev/urandom\n");
            fflush(stderr);
            exit(1);
        }
        total += (size_t)r;
    }
    close(fd);
#endif
}

#undef RR
#undef CH
#undef MAJ
#undef S0
#undef S1
#undef s0
#undef s1
