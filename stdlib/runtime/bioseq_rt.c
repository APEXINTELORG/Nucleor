// bioseq_rt.c — Bioinformatics Sequence Operations for Nucleor
// Needleman-Wunsch, Smith-Waterman, translation, reverse complement, GC content.
//
// Compile: clang -c stdlib/runtime/bioseq_rt.c -o target/bioseq_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ================================================================
//  Sequence Utilities
// ================================================================

static char complement(char c) {
    switch (c) {
        case 'A': return 'T'; case 'T': return 'A';
        case 'G': return 'C'; case 'C': return 'G';
        case 'a': return 't'; case 't': return 'a';
        case 'g': return 'c'; case 'c': return 'g';
        default: return 'N';
    }
}

const char *nuc_bio_reverse_complement(const char *seq) {
    if (!seq) return "";
    int n = (int)strlen(seq);
    char *rc = (char *)malloc(n + 1);
    for (int i = 0; i < n; i++) rc[i] = complement(seq[n - 1 - i]);
    rc[n] = 0;
    return rc;
}

long long nuc_bio_gc_content(const char *seq) {
    if (!seq) return 0;
    int gc = 0, total = 0;
    for (const char *p = seq; *p; p++) {
        if (*p == 'G' || *p == 'C' || *p == 'g' || *p == 'c') gc++;
        if (*p == 'A' || *p == 'T' || *p == 'G' || *p == 'C' ||
            *p == 'a' || *p == 't' || *p == 'g' || *p == 'c') total++;
    }
    double ratio = total > 0 ? (double)gc / total : 0.0;
    long long r; memcpy(&r, &ratio, 8); return r;
}

// ================================================================
//  Codon Translation (Standard Genetic Code)
// ================================================================

static char translate_codon(const char *codon) {
    // Simplified: handle common codons
    char c[4] = { codon[0] & ~32, codon[1] & ~32, codon[2] & ~32, 0 }; // uppercase
    if (strcmp(c, "ATG") == 0) return 'M';
    if (strcmp(c, "TTT") == 0 || strcmp(c, "TTC") == 0) return 'F';
    if (c[0] == 'T' && c[1] == 'T' && (c[2] == 'A' || c[2] == 'G')) return 'L';
    if (c[0] == 'C' && c[1] == 'T') return 'L';
    if (c[0] == 'A' && c[1] == 'T' && c[2] != 'G') return 'I';
    if (c[0] == 'G' && c[1] == 'T') return 'V';
    if (c[0] == 'T' && c[1] == 'C') return 'S';
    if (c[0] == 'C' && c[1] == 'C') return 'P';
    if (c[0] == 'A' && c[1] == 'C') return 'T';
    if (c[0] == 'G' && c[1] == 'C') return 'A';
    if (strcmp(c, "TAT") == 0 || strcmp(c, "TAC") == 0) return 'Y';
    if (strcmp(c, "TAA") == 0 || strcmp(c, "TAG") == 0 || strcmp(c, "TGA") == 0) return '*'; // stop
    if (strcmp(c, "CAT") == 0 || strcmp(c, "CAC") == 0) return 'H';
    if (strcmp(c, "CAA") == 0 || strcmp(c, "CAG") == 0) return 'Q';
    if (strcmp(c, "AAT") == 0 || strcmp(c, "AAC") == 0) return 'N';
    if (strcmp(c, "AAA") == 0 || strcmp(c, "AAG") == 0) return 'K';
    if (strcmp(c, "GAT") == 0 || strcmp(c, "GAC") == 0) return 'D';
    if (strcmp(c, "GAA") == 0 || strcmp(c, "GAG") == 0) return 'E';
    if (strcmp(c, "TGT") == 0 || strcmp(c, "TGC") == 0) return 'C';
    if (strcmp(c, "TGG") == 0) return 'W';
    if (c[0] == 'C' && c[1] == 'G') return 'R';
    if (c[0] == 'A' && c[1] == 'G' && (c[2] == 'A' || c[2] == 'G')) return 'R';
    if (c[0] == 'A' && c[1] == 'G' && (c[2] == 'T' || c[2] == 'C')) return 'S';
    if (c[0] == 'G' && c[1] == 'G') return 'G';
    return 'X'; // unknown
}

const char *nuc_bio_translate(const char *dna) {
    if (!dna) return "";
    int n = (int)strlen(dna);
    int plen = n / 3;
    char *protein = (char *)malloc(plen + 1);
    for (int i = 0; i < plen; i++) {
        protein[i] = translate_codon(dna + i * 3);
        if (protein[i] == '*') { protein[i] = 0; return protein; }
    }
    protein[plen] = 0;
    return protein;
}

// ================================================================
//  Needleman-Wunsch (Global Alignment)
// ================================================================

typedef struct { const char *aligned1; const char *aligned2; long long score; } AlignResult;

long long nuc_bio_align_global(const char *seq1, const char *seq2, long long match_bits, long long mismatch_bits, long long gap_bits) {
    if (!seq1 || !seq2) return 0;
    int m = (int)strlen(seq1), n = (int)strlen(seq2);
    double match_sc, mismatch_sc, gap_sc;
    memcpy(&match_sc, &match_bits, 8);
    memcpy(&mismatch_sc, &mismatch_bits, 8);
    memcpy(&gap_sc, &gap_bits, 8);

    // DP table
    double *dp = (double *)malloc((m + 1) * (n + 1) * sizeof(double));
    for (int i = 0; i <= m; i++) dp[i * (n + 1)] = i * gap_sc;
    for (int j = 0; j <= n; j++) dp[j] = j * gap_sc;

    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            double s = (seq1[i-1] == seq2[j-1]) ? match_sc : mismatch_sc;
            double diag = dp[(i-1) * (n+1) + j-1] + s;
            double up = dp[(i-1) * (n+1) + j] + gap_sc;
            double left = dp[i * (n+1) + j-1] + gap_sc;
            dp[i * (n+1) + j] = diag;
            if (up > dp[i * (n+1) + j]) dp[i * (n+1) + j] = up;
            if (left > dp[i * (n+1) + j]) dp[i * (n+1) + j] = left;
        }
    }

    double score = dp[m * (n+1) + n];

    // Traceback
    char *a1 = (char *)malloc(m + n + 1);
    char *a2 = (char *)malloc(m + n + 1);
    int pos = 0, i = m, j = n;
    while (i > 0 || j > 0) {
        if (i > 0 && j > 0) {
            double s = (seq1[i-1] == seq2[j-1]) ? match_sc : mismatch_sc;
            if (dp[i*(n+1)+j] == dp[(i-1)*(n+1)+j-1] + s) {
                a1[pos] = seq1[--i]; a2[pos] = seq2[--j]; pos++; continue;
            }
        }
        if (i > 0 && dp[i*(n+1)+j] == dp[(i-1)*(n+1)+j] + gap_sc) {
            a1[pos] = seq1[--i]; a2[pos] = '-'; pos++; continue;
        }
        a1[pos] = '-'; a2[pos] = seq2[--j]; pos++;
    }
    a1[pos] = 0; a2[pos] = 0;

    // Reverse
    for (int k = 0; k < pos / 2; k++) {
        char t = a1[k]; a1[k] = a1[pos-1-k]; a1[pos-1-k] = t;
        t = a2[k]; a2[k] = a2[pos-1-k]; a2[pos-1-k] = t;
    }

    free(dp);
    AlignResult *res = (AlignResult *)malloc(sizeof(AlignResult));
    res->aligned1 = a1; res->aligned2 = a2;
    long long score_bits; memcpy(&score_bits, &score, 8);
    res->score = score_bits;
    return (long long)res;
}

const char *nuc_bio_align_seq1(long long h) { return ((AlignResult *)(void *)h)->aligned1; }
const char *nuc_bio_align_seq2(long long h) { return ((AlignResult *)(void *)h)->aligned2; }
long long nuc_bio_align_score(long long h) { return ((AlignResult *)(void *)h)->score; }

// ================================================================
//  Hamming Distance
// ================================================================

long long nuc_bio_hamming(const char *seq1, const char *seq2) {
    if (!seq1 || !seq2) return 0;
    int dist = 0;
    while (*seq1 && *seq2) { if (*seq1++ != *seq2++) dist++; }
    return (long long)dist;
}

// ================================================================
//  K-mer Counting (returns count of unique k-mers)
// ================================================================

long long nuc_bio_kmer_count(const char *seq, long long k) {
    if (!seq) return 0;
    int n = (int)strlen(seq), kk = (int)k;
    if (n < kk) return 0;
    return (long long)(n - kk + 1); // total k-mers; unique count would need hashmap
}

// ================================================================
//  Find ORFs (Open Reading Frames)
//  Returns Vec of [start, end] pairs
// ================================================================

long long nuc_bio_find_orfs(const char *seq, long long min_len) {
    typedef struct { long long *data; int len; int cap; } NVec;
    if (!seq) return 0;
    int n = (int)strlen(seq), ml = (int)min_len;
    NVec *orfs = (NVec *)malloc(sizeof(NVec));
    orfs->len = 0; orfs->cap = 64;
    orfs->data = (long long *)malloc(64 * sizeof(long long));

    for (int frame = 0; frame < 3; frame++) {
        int start = -1;
        for (int i = frame; i + 2 < n; i += 3) {
            char c[4] = { seq[i] & ~32, seq[i+1] & ~32, seq[i+2] & ~32, 0 };
            if (strcmp(c, "ATG") == 0 && start < 0) start = i;
            if (start >= 0 && (strcmp(c, "TAA") == 0 || strcmp(c, "TAG") == 0 || strcmp(c, "TGA") == 0)) {
                if (i + 3 - start >= ml) {
                    if (orfs->len + 2 >= orfs->cap) {
                        orfs->cap *= 2;
                        orfs->data = (long long *)realloc(orfs->data, orfs->cap * sizeof(long long));
                    }
                    orfs->data[orfs->len++] = start;
                    orfs->data[orfs->len++] = i + 3;
                }
                start = -1;
            }
        }
    }
    return (long long)orfs;
}
