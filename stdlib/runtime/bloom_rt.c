// bloom_rt.c — Probabilistic Data Structures for Nucleor
// Bloom filter (set membership), HyperLogLog (cardinality estimation).
//
// Compile: clang -c stdlib/runtime/bloom_rt.c -o target/bloom_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// ================================================================
//  Hash functions (multiple independent hashes via double-hashing)
// ================================================================

static unsigned long long bloom_hash1(const char *key) {
    unsigned long long h = 14695981039346656037ULL;
    for (const char *p = key; *p; p++) { h ^= (unsigned char)*p; h *= 1099511628211ULL; }
    return h;
}

static unsigned long long bloom_hash2(const char *key) {
    unsigned long long h = 0xCBF29CE484222325ULL;
    for (const char *p = key; *p; p++) { h = (h * 31) + (unsigned char)*p; }
    return h | 1; // ensure odd for double-hashing
}

// ================================================================
//  Bloom Filter
// ================================================================

typedef struct {
    unsigned char *bits;
    int n_bits;
    int n_hashes;
    int n_items;
} BloomFilter;

long long nuc_bloom_new(long long expected_items, long long fp_rate_bits) {
    double fp = 0.01;
    memcpy(&fp, &fp_rate_bits, 8);
    int n = (int)expected_items;
    if (n < 1) n = 1;
    if (fp <= 0) fp = 0.01;

    // Optimal parameters
    int m = (int)(-n * log(fp) / (log(2) * log(2)));
    int k = (int)(m * log(2) / n);
    if (m < 64) m = 64;
    if (k < 1) k = 1;
    if (k > 20) k = 20;

    BloomFilter *bf = (BloomFilter *)malloc(sizeof(BloomFilter));
    bf->n_bits = m;
    bf->n_hashes = k;
    bf->n_items = 0;
    bf->bits = (unsigned char *)calloc((m + 7) / 8, 1);
    return (long long)bf;
}

void nuc_bloom_add(long long h, const char *key) {
    BloomFilter *bf = (BloomFilter *)(void *)h;
    if (!bf || !key) return;
    unsigned long long h1 = bloom_hash1(key), h2 = bloom_hash2(key);
    for (int i = 0; i < bf->n_hashes; i++) {
        int idx = (int)((h1 + i * h2) % bf->n_bits);
        bf->bits[idx / 8] |= (1 << (idx % 8));
    }
    bf->n_items++;
}

long long nuc_bloom_contains(long long h, const char *key) {
    BloomFilter *bf = (BloomFilter *)(void *)h;
    if (!bf || !key) return 0;
    unsigned long long h1 = bloom_hash1(key), h2 = bloom_hash2(key);
    for (int i = 0; i < bf->n_hashes; i++) {
        int idx = (int)((h1 + i * h2) % bf->n_bits);
        if (!(bf->bits[idx / 8] & (1 << (idx % 8)))) return 0;
    }
    return 1;
}

long long nuc_bloom_count(long long h) {
    return ((BloomFilter *)(void *)h)->n_items;
}

// Estimated false positive rate given current fill
long long nuc_bloom_fp_rate(long long h) {
    BloomFilter *bf = (BloomFilter *)(void *)h;
    double rate = pow(1 - exp(-(double)bf->n_hashes * bf->n_items / bf->n_bits), bf->n_hashes);
    long long r; memcpy(&r, &rate, 8); return r;
}

void nuc_bloom_free(long long h) {
    BloomFilter *bf = (BloomFilter *)(void *)h;
    if (bf) { free(bf->bits); free(bf); }
}

// ================================================================
//  HyperLogLog (cardinality estimation)
// ================================================================

typedef struct {
    int precision;   // p: number of bits for bucket index
    int n_buckets;   // 2^p
    unsigned char *buckets; // max leading zeros per bucket
} HyperLogLog;

static int hll_leading_zeros(unsigned long long x) {
    if (x == 0) return 64;
    int n = 0;
    while (!(x & (1ULL << 63))) { n++; x <<= 1; }
    return n;
}

long long nuc_hll_new(long long precision) {
    int p = (int)precision;
    if (p < 4) p = 4;
    if (p > 16) p = 16;
    HyperLogLog *hll = (HyperLogLog *)malloc(sizeof(HyperLogLog));
    hll->precision = p;
    hll->n_buckets = 1 << p;
    hll->buckets = (unsigned char *)calloc(hll->n_buckets, 1);
    return (long long)hll;
}

void nuc_hll_add(long long h, const char *key) {
    HyperLogLog *hll = (HyperLogLog *)(void *)h;
    if (!hll || !key) return;
    unsigned long long hash = bloom_hash1(key); // reuse FNV-1a
    int bucket = (int)(hash & (hll->n_buckets - 1));
    unsigned long long remaining = hash >> hll->precision;
    int lz = hll_leading_zeros(remaining) + 1;
    if ((unsigned char)lz > hll->buckets[bucket]) hll->buckets[bucket] = (unsigned char)lz;
}

long long nuc_hll_count(long long h) {
    HyperLogLog *hll = (HyperLogLog *)(void *)h;
    int m = hll->n_buckets;
    double alpha;
    if (m == 16) alpha = 0.673;
    else if (m == 32) alpha = 0.697;
    else if (m == 64) alpha = 0.709;
    else alpha = 0.7213 / (1 + 1.079 / m);

    double sum = 0;
    int zeros = 0;
    for (int i = 0; i < m; i++) {
        sum += 1.0 / (1ULL << hll->buckets[i]);
        if (hll->buckets[i] == 0) zeros++;
    }

    double estimate = alpha * m * m / sum;

    // Small range correction
    if (estimate <= 2.5 * m && zeros > 0)
        estimate = m * log((double)m / zeros);

    long long result; double d = estimate;
    memcpy(&result, &d, 8);
    return result;
}

void nuc_hll_free(long long h) {
    HyperLogLog *hll = (HyperLogLog *)(void *)h;
    if (hll) { free(hll->buckets); free(hll); }
}
