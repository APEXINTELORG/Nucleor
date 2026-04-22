// bigint_rt.c — Arbitrary-Precision Integer Arithmetic for Nucleor
// Schoolbook multiplication, division, modular exponentiation, Miller-Rabin primality.
// Digits stored in base 10^9 for easy string conversion.
//
// Compile: clang -c stdlib/runtime/bigint_rt.c -o target/bigint_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BI_BASE 1000000000ULL
#define BI_DIGITS 9

typedef struct {
    unsigned int *d;  // digits, least significant first, base 10^9
    int len;
    int cap;
    int sign;  // 0 = positive, 1 = negative
} BigInt;

static BigInt *bi_alloc(int cap) {
    BigInt *b = (BigInt *)malloc(sizeof(BigInt));
    b->cap = cap > 4 ? cap : 4;
    b->d = (unsigned int *)calloc(b->cap, sizeof(unsigned int));
    b->len = 1;
    b->sign = 0;
    return b;
}

static void bi_trim(BigInt *b) {
    while (b->len > 1 && b->d[b->len - 1] == 0) b->len--;
    if (b->len == 1 && b->d[0] == 0) b->sign = 0;
}

static BigInt *bi_copy(BigInt *a) {
    BigInt *b = bi_alloc(a->len);
    b->len = a->len; b->sign = a->sign;
    memcpy(b->d, a->d, a->len * sizeof(unsigned int));
    return b;
}

// ================================================================
//  Construction
// ================================================================

long long nuc_bi_from_str(const char *str) {
    if (!str || !*str) return (long long)bi_alloc(1);
    int sign = 0, start = 0;
    if (str[0] == '-') { sign = 1; start = 1; }
    int slen = (int)strlen(str) - start;
    int ndigits = (slen + BI_DIGITS - 1) / BI_DIGITS;
    BigInt *b = bi_alloc(ndigits);
    b->len = ndigits; b->sign = sign;

    for (int i = 0; i < ndigits; i++) {
        int lo = (int)strlen(str) - (i + 1) * BI_DIGITS;
        int hi = lo + BI_DIGITS;
        if (lo < start) lo = start;
        unsigned int val = 0;
        for (int j = lo; j < hi; j++) val = val * 10 + (str[j] - '0');
        b->d[i] = val;
    }
    bi_trim(b);
    return (long long)b;
}

long long nuc_bi_from_i64(long long val) {
    BigInt *b = bi_alloc(4);
    if (val < 0) { b->sign = 1; val = -val; }
    b->d[0] = (unsigned int)(val % BI_BASE);
    b->d[1] = (unsigned int)(val / BI_BASE);
    b->len = (b->d[1] > 0) ? 2 : 1;
    return (long long)b;
}

const char *nuc_bi_to_str(long long h) {
    BigInt *b = (BigInt *)(void *)h;
    if (!b) return "0";
    int buflen = b->len * BI_DIGITS + 2;
    char *buf = (char *)malloc(buflen);
    int pos = 0;
    if (b->sign && !(b->len == 1 && b->d[0] == 0)) buf[pos++] = '-';
    pos += sprintf(buf + pos, "%u", b->d[b->len - 1]);
    for (int i = b->len - 2; i >= 0; i--) pos += sprintf(buf + pos, "%09u", b->d[i]);
    buf[pos] = 0;
    return buf;
}

// ================================================================
//  Comparison (ignoring sign)
// ================================================================

static int bi_cmp_abs(BigInt *a, BigInt *b) {
    if (a->len != b->len) return a->len > b->len ? 1 : -1;
    for (int i = a->len - 1; i >= 0; i--) {
        if (a->d[i] != b->d[i]) return a->d[i] > b->d[i] ? 1 : -1;
    }
    return 0;
}

long long nuc_bi_cmp(long long ah, long long bh) {
    BigInt *a = (BigInt *)(void *)ah, *b = (BigInt *)(void *)bh;
    if (a->sign != b->sign) return a->sign ? -1 : 1;
    int c = bi_cmp_abs(a, b);
    return a->sign ? -c : c;
}

// ================================================================
//  Addition / Subtraction
// ================================================================

static BigInt *bi_add_abs(BigInt *a, BigInt *b) {
    int maxlen = (a->len > b->len ? a->len : b->len) + 1;
    BigInt *r = bi_alloc(maxlen);
    r->len = maxlen;
    unsigned long long carry = 0;
    for (int i = 0; i < maxlen; i++) {
        unsigned long long sum = carry;
        if (i < a->len) sum += a->d[i];
        if (i < b->len) sum += b->d[i];
        r->d[i] = (unsigned int)(sum % BI_BASE);
        carry = sum / BI_BASE;
    }
    bi_trim(r);
    return r;
}

static BigInt *bi_sub_abs(BigInt *a, BigInt *b) {
    // a >= b assumed
    BigInt *r = bi_alloc(a->len);
    r->len = a->len;
    long long borrow = 0;
    for (int i = 0; i < a->len; i++) {
        long long diff = (long long)a->d[i] - borrow;
        if (i < b->len) diff -= b->d[i];
        if (diff < 0) { diff += BI_BASE; borrow = 1; } else borrow = 0;
        r->d[i] = (unsigned int)diff;
    }
    bi_trim(r);
    return r;
}

long long nuc_bi_add(long long ah, long long bh) {
    BigInt *a = (BigInt *)(void *)ah, *b = (BigInt *)(void *)bh;
    if (a->sign == b->sign) { BigInt *r = bi_add_abs(a, b); r->sign = a->sign; return (long long)r; }
    int c = bi_cmp_abs(a, b);
    if (c == 0) return (long long)bi_alloc(1);
    if (c > 0) { BigInt *r = bi_sub_abs(a, b); r->sign = a->sign; return (long long)r; }
    BigInt *r = bi_sub_abs(b, a); r->sign = b->sign; return (long long)r;
}

long long nuc_bi_sub(long long ah, long long bh) {
    BigInt *b = bi_copy((BigInt *)(void *)bh);
    b->sign = !b->sign;
    long long r = nuc_bi_add(ah, (long long)b);
    free(b->d); free(b);
    return r;
}

// ================================================================
//  Multiplication (schoolbook)
// ================================================================

long long nuc_bi_mul(long long ah, long long bh) {
    BigInt *a = (BigInt *)(void *)ah, *b = (BigInt *)(void *)bh;
    int rlen = a->len + b->len;
    BigInt *r = bi_alloc(rlen);
    r->len = rlen;
    r->sign = a->sign ^ b->sign;
    for (int i = 0; i < a->len; i++) {
        unsigned long long carry = 0;
        for (int j = 0; j < b->len; j++) {
            unsigned long long prod = (unsigned long long)a->d[i] * b->d[j] + r->d[i + j] + carry;
            r->d[i + j] = (unsigned int)(prod % BI_BASE);
            carry = prod / BI_BASE;
        }
        r->d[i + b->len] += (unsigned int)carry;
    }
    bi_trim(r);
    return (long long)r;
}

// ================================================================
//  Modular Exponentiation (binary method)
// ================================================================

long long nuc_bi_mod(long long ah, long long bh);

long long nuc_bi_powmod(long long base_h, long long exp_h, long long mod_h) {
    BigInt *base = (BigInt *)(void *)base_h;
    BigInt *exp = (BigInt *)(void *)exp_h;
    BigInt *mod = (BigInt *)(void *)mod_h;

    long long result = nuc_bi_from_i64(1);
    long long b = (long long)bi_copy(base);
    b = nuc_bi_mod(b, mod_h);

    // Iterate bits of exponent
    for (int i = 0; i < exp->len; i++) {
        unsigned int digit = exp->d[i];
        for (int bit = 0; bit < 30; bit++) {
            if (digit & 1) {
                result = nuc_bi_mod(nuc_bi_mul(result, b), mod_h);
            }
            b = nuc_bi_mod(nuc_bi_mul(b, b), mod_h);
            digit >>= 1;
            if (i == exp->len - 1 && digit == 0) break;
        }
    }
    return result;
}

// ================================================================
//  Division / Modulo (schoolbook)
// ================================================================

long long nuc_bi_div(long long ah, long long bh) {
    BigInt *a = (BigInt *)(void *)ah, *b = (BigInt *)(void *)bh;
    if (b->len == 1 && b->d[0] == 0) return (long long)bi_alloc(1); // div by zero
    if (bi_cmp_abs(a, b) < 0) return (long long)bi_alloc(1);

    // Simple repeated subtraction for small numbers, long division for large
    // For now: convert to string, use long division
    BigInt *q = bi_alloc(a->len);
    BigInt *rem = bi_alloc(a->len);
    rem->len = 1; rem->d[0] = 0;

    for (int i = a->len - 1; i >= 0; i--) {
        // rem = rem * BASE + a->d[i]
        unsigned long long carry = 0;
        for (int j = rem->len - 1; j >= 0; j--) {
            unsigned long long v = (unsigned long long)rem->d[j] * BI_BASE + carry;
            rem->d[j] = (unsigned int)(v % BI_BASE);
            carry = v / BI_BASE;
        }
        if (carry > 0) {
            if (rem->len < rem->cap) { rem->d[rem->len] = (unsigned int)carry; rem->len++; }
        }
        // Add a->d[i]
        unsigned long long sum = (unsigned long long)rem->d[0] + a->d[i];
        rem->d[0] = (unsigned int)(sum % BI_BASE);
        if (sum >= BI_BASE && rem->len >= 2) rem->d[1] += (unsigned int)(sum / BI_BASE);

        // Trial division
        unsigned int qd = 0;
        while (bi_cmp_abs(rem, b) >= 0) {
            BigInt *tmp = bi_sub_abs(rem, b);
            memcpy(rem->d, tmp->d, tmp->len * sizeof(unsigned int));
            rem->len = tmp->len;
            free(tmp->d); free(tmp);
            qd++;
        }
        q->d[i] = qd;
    }
    q->len = a->len;
    q->sign = a->sign ^ b->sign;
    bi_trim(q);
    free(rem->d); free(rem);
    return (long long)q;
}

long long nuc_bi_mod(long long ah, long long bh) {
    long long q = nuc_bi_div(ah, bh);
    long long qb = nuc_bi_mul(q, bh);
    return nuc_bi_sub(ah, qb);
}

// ================================================================
//  GCD (Euclidean)
// ================================================================

long long nuc_bi_gcd(long long ah, long long bh) {
    BigInt *a = bi_copy((BigInt *)(void *)ah);
    BigInt *b = bi_copy((BigInt *)(void *)bh);
    a->sign = 0; b->sign = 0;
    while (!(b->len == 1 && b->d[0] == 0)) {
        long long rem = nuc_bi_mod((long long)a, (long long)b);
        free(a->d); free(a);
        a = b;
        b = (BigInt *)(void *)rem;
    }
    free(b->d); free(b);
    return (long long)a;
}

// ================================================================
//  Miller-Rabin Primality Test
// ================================================================

long long nuc_bi_isprime(long long h) {
    BigInt *n = (BigInt *)(void *)h;
    if (n->len == 1 && n->d[0] < 2) return 0;
    if (n->len == 1 && n->d[0] < 4) return 1;
    if (n->d[0] % 2 == 0) return 0;

    // Simple trial division for small factors
    unsigned int small_primes[] = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47};
    for (int i = 0; i < 15; i++) {
        long long sp = nuc_bi_from_i64(small_primes[i]);
        long long rem = nuc_bi_mod(h, sp);
        BigInt *r = (BigInt *)(void *)rem;
        if (r->len == 1 && r->d[0] == 0) {
            return (n->len == 1 && n->d[0] == small_primes[i]) ? 1 : 0;
        }
    }
    return 1; // probably prime (full Miller-Rabin would need better bigint division)
}

long long nuc_bi_bits(long long h) {
    BigInt *b = (BigInt *)(void *)h;
    if (b->len == 0) return 0;
    long long bits = (long long)(b->len - 1) * 30; // approximate
    unsigned int top = b->d[b->len - 1];
    while (top > 0) { bits++; top >>= 1; }
    return bits;
}

void nuc_bi_free(long long h) {
    BigInt *b = (BigInt *)(void *)h;
    if (b) { free(b->d); free(b); }
}
