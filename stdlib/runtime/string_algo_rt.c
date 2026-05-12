// string_algo_rt.c — String Algorithms for Nucleor
// KMP search, Levenshtein distance, longest common subsequence, trie.
//
// Compile: clang -c stdlib/runtime/string_algo_rt.c -o target/string_algo_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { long long *data; int len; int cap; } SAVec;

static void savec_push(SAVec *v, long long val) {
    if (v->len >= v->cap) { v->cap = v->cap * 2 + 8; v->data = (long long *)realloc(v->data, v->cap * sizeof(long long)); }
    v->data[v->len++] = val;
}

// ================================================================
//  KMP String Search (returns Vec of match positions)
// ================================================================

long long nuc_str_kmp_search(const char *text, const char *pattern) {
    if (!text || !pattern) return 0;
    int n = (int)strlen(text), m = (int)strlen(pattern);
    if (m == 0) return 0;

    // Build failure function
    int *fail = (int *)calloc(m, sizeof(int));
    int k = 0;
    for (int i = 1; i < m; i++) {
        while (k > 0 && pattern[k] != pattern[i]) k = fail[k - 1];
        if (pattern[k] == pattern[i]) k++;
        fail[i] = k;
    }

    SAVec *matches = (SAVec *)malloc(sizeof(SAVec));
    matches->len = 0; matches->cap = 64;
    matches->data = (long long *)malloc(64 * sizeof(long long));

    k = 0;
    for (int i = 0; i < n; i++) {
        while (k > 0 && pattern[k] != text[i]) k = fail[k - 1];
        if (pattern[k] == text[i]) k++;
        if (k == m) {
            savec_push(matches, i - m + 1);
            k = fail[k - 1];
        }
    }
    free(fail);
    return (long long)matches;
}

// ================================================================
//  Levenshtein Edit Distance
// ================================================================

long long nuc_str_levenshtein(const char *a, const char *b) {
    if (!a || !b) return 0;
    int m = (int)strlen(a), n = (int)strlen(b);
    int *prev = (int *)malloc((n + 1) * sizeof(int));
    int *curr = (int *)malloc((n + 1) * sizeof(int));

    for (int j = 0; j <= n; j++) prev[j] = j;
    for (int i = 1; i <= m; i++) {
        curr[0] = i;
        for (int j = 1; j <= n; j++) {
            int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
            int del = prev[j] + 1;
            int ins = curr[j - 1] + 1;
            int sub = prev[j - 1] + cost;
            curr[j] = del;
            if (ins < curr[j]) curr[j] = ins;
            if (sub < curr[j]) curr[j] = sub;
        }
        int *tmp = prev; prev = curr; curr = tmp;
    }
    int result = prev[n];
    free(prev); free(curr);
    return (long long)result;
}

// ================================================================
//  Longest Common Subsequence
// ================================================================

const char *nuc_str_lcs(const char *a, const char *b) {
    if (!a || !b) return "";
    int m = (int)strlen(a), n = (int)strlen(b);
    int *dp = (int *)calloc((size_t)(m + 1) * (n + 1), sizeof(int));

    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            if (a[i - 1] == b[j - 1])
                dp[i * (n + 1) + j] = dp[(i - 1) * (n + 1) + j - 1] + 1;
            else {
                int u = dp[(i - 1) * (n + 1) + j], l = dp[i * (n + 1) + j - 1];
                dp[i * (n + 1) + j] = u > l ? u : l;
            }
        }
    }

    int lcs_len = dp[m * (n + 1) + n];
    char *lcs = (char *)malloc(lcs_len + 1);
    int pos = lcs_len;
    lcs[pos] = 0;

    int i = m, j = n;
    while (i > 0 && j > 0) {
        if (a[i - 1] == b[j - 1]) { lcs[--pos] = a[i - 1]; i--; j--; }
        else if (dp[(i - 1) * (n + 1) + j] > dp[i * (n + 1) + j - 1]) i--;
        else j--;
    }

    free(dp);
    return lcs;
}

// ================================================================
//  Trie
// ================================================================

#define TRIE_ALPHA 128 // ASCII

typedef struct TrieNode TrieNode;
struct TrieNode {
    TrieNode *children[TRIE_ALPHA];
    int is_end;
};

static TrieNode *trie_new_node(void) {
    return (TrieNode *)calloc(1, sizeof(TrieNode));
}

long long nuc_str_trie_new(void) {
    return (long long)trie_new_node();
}

void nuc_str_trie_insert(long long th, const char *word) {
    TrieNode *node = (TrieNode *)(void *)th;
    if (!node || !word) return;
    for (const char *p = word; *p; p++) {
        int c = (unsigned char)*p;
        if (c >= TRIE_ALPHA) continue;
        if (!node->children[c]) node->children[c] = trie_new_node();
        node = node->children[c];
    }
    node->is_end = 1;
}

long long nuc_str_trie_contains(long long th, const char *word) {
    TrieNode *node = (TrieNode *)(void *)th;
    if (!node || !word) return 0;
    for (const char *p = word; *p; p++) {
        int c = (unsigned char)*p;
        if (c >= TRIE_ALPHA || !node->children[c]) return 0;
        node = node->children[c];
    }
    return node->is_end ? 1 : 0;
}

long long nuc_str_trie_starts_with(long long th, const char *prefix) {
    TrieNode *node = (TrieNode *)(void *)th;
    if (!node || !prefix) return 0;
    for (const char *p = prefix; *p; p++) {
        int c = (unsigned char)*p;
        if (c >= TRIE_ALPHA || !node->children[c]) return 0;
        node = node->children[c];
    }
    return 1;
}

// Count words with prefix
static int trie_count(TrieNode *node) {
    if (!node) return 0;
    int count = node->is_end ? 1 : 0;
    for (int i = 0; i < TRIE_ALPHA; i++) count += trie_count(node->children[i]);
    return count;
}

long long nuc_str_trie_count_prefix(long long th, const char *prefix) {
    TrieNode *node = (TrieNode *)(void *)th;
    if (!node || !prefix) return 0;
    for (const char *p = prefix; *p; p++) {
        int c = (unsigned char)*p;
        if (c >= TRIE_ALPHA || !node->children[c]) return 0;
        node = node->children[c];
    }
    return (long long)trie_count(node);
}

static void trie_free(TrieNode *node) {
    if (!node) return;
    for (int i = 0; i < TRIE_ALPHA; i++) trie_free(node->children[i]);
    free(node);
}

void nuc_str_trie_free(long long th) {
    trie_free((TrieNode *)(void *)th);
}
