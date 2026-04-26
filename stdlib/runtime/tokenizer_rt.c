// tokenizer_rt.c — Text Tokenization for Nucleor
// Byte-Pair Encoding (BPE) training and encoding/decoding, plus char-level fallback.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/tokenizer_rt.c -o target/tokenizer_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { long long *data; int len; int cap; } TKVec;

static TKVec *tkvec_new(int n) {
    TKVec *v = (TKVec *)malloc(sizeof(TKVec));
    v->len = n; v->cap = n > 0 ? n : 16;
    v->data = (long long *)calloc(v->cap, sizeof(long long));
    return v;
}

static void tkvec_push(TKVec *v, long long val) {
    if (v->len >= v->cap) {
        v->cap = v->cap * 2 + 8;
        v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
    }
    v->data[v->len++] = val;
}

// ================================================================
//  Tokenizer state
// ================================================================

typedef struct {
    // Merges: pair (a, b) -> merged_id
    int *merge_a;
    int *merge_b;
    int *merge_id;
    int n_merges;
    int merge_cap;
    // Vocab: id -> string
    char **vocab;
    int vocab_size;
    int vocab_cap;
} BPETokenizer;

static BPETokenizer *tok_alloc(void) {
    BPETokenizer *t = (BPETokenizer *)calloc(1, sizeof(BPETokenizer));
    t->merge_cap = 1024;
    t->merge_a = (int *)malloc(t->merge_cap * sizeof(int));
    t->merge_b = (int *)malloc(t->merge_cap * sizeof(int));
    t->merge_id = (int *)malloc(t->merge_cap * sizeof(int));
    t->vocab_cap = 512;
    t->vocab = (char **)calloc(t->vocab_cap, sizeof(char *));
    // Init base vocab: single bytes 0-255
    for (int i = 0; i < 256; i++) {
        t->vocab[i] = (char *)malloc(2);
        t->vocab[i][0] = (char)i;
        t->vocab[i][1] = 0;
    }
    t->vocab_size = 256;
    return t;
}

static void tok_add_merge(BPETokenizer *t, int a, int b) {
    if (t->n_merges >= t->merge_cap) {
        t->merge_cap *= 2;
        t->merge_a = (int *)realloc(t->merge_a, t->merge_cap * sizeof(int));
        t->merge_b = (int *)realloc(t->merge_b, t->merge_cap * sizeof(int));
        t->merge_id = (int *)realloc(t->merge_id, t->merge_cap * sizeof(int));
    }
    t->merge_a[t->n_merges] = a;
    t->merge_b[t->n_merges] = b;

    // Create merged vocab entry
    if (t->vocab_size >= t->vocab_cap) {
        t->vocab_cap *= 2;
        t->vocab = (char **)realloc(t->vocab, t->vocab_cap * sizeof(char *));
    }
    int la = (int)strlen(t->vocab[a]), lb = (int)strlen(t->vocab[b]);
    t->vocab[t->vocab_size] = (char *)malloc(la + lb + 1);
    memcpy(t->vocab[t->vocab_size], t->vocab[a], la);
    memcpy(t->vocab[t->vocab_size] + la, t->vocab[b], lb + 1);

    t->merge_id[t->n_merges] = t->vocab_size;
    t->vocab_size++;
    t->n_merges++;
}

// ================================================================
//  BPE Training
// ================================================================

long long nuc_tok_bpe_train(const char *text, long long target_vocab_size) {
    if (!text) return 0;
    BPETokenizer *tok = tok_alloc();
    int tvs = (int)target_vocab_size;
    int text_len = (int)strlen(text);

    // Initial tokenization: one token per byte
    int *tokens = (int *)malloc(text_len * sizeof(int));
    int n_tokens = text_len;
    for (int i = 0; i < text_len; i++) tokens[i] = (unsigned char)text[i];

    while (tok->vocab_size < tvs && n_tokens > 1) {
        // Count all adjacent pairs
        // Simple O(n) scan for most frequent pair
        int best_a = -1, best_b = -1, best_count = 0;
        for (int i = 0; i < n_tokens - 1; i++) {
            int a = tokens[i], b = tokens[i + 1];
            int count = 0;
            for (int j = i; j < n_tokens - 1; j++) {
                if (tokens[j] == a && tokens[j + 1] == b) count++;
            }
            if (count > best_count) { best_count = count; best_a = a; best_b = b; }
        }
        if (best_count < 2) break; // no pair appears more than once

        // Merge pair
        tok_add_merge(tok, best_a, best_b);
        int new_id = tok->vocab_size - 1;

        // Apply merge to token sequence
        int new_len = 0;
        for (int i = 0; i < n_tokens; i++) {
            if (i < n_tokens - 1 && tokens[i] == best_a && tokens[i + 1] == best_b) {
                tokens[new_len++] = new_id;
                i++; // skip next
            } else {
                tokens[new_len++] = tokens[i];
            }
        }
        n_tokens = new_len;
    }

    free(tokens);
    return (long long)tok;
}

// ================================================================
//  Encode
// ================================================================

long long nuc_tok_encode(long long tok_h, const char *text) {
    BPETokenizer *tok = (BPETokenizer *)(void *)tok_h;
    if (!tok || !text) return 0;
    int text_len = (int)strlen(text);

    int *tokens = (int *)malloc(text_len * sizeof(int));
    int n = text_len;
    for (int i = 0; i < text_len; i++) tokens[i] = (unsigned char)text[i];

    // Apply merges in order
    for (int m = 0; m < tok->n_merges; m++) {
        int a = tok->merge_a[m], b = tok->merge_b[m], id = tok->merge_id[m];
        int new_len = 0;
        for (int i = 0; i < n; i++) {
            if (i < n - 1 && tokens[i] == a && tokens[i + 1] == b) {
                tokens[new_len++] = id;
                i++;
            } else {
                tokens[new_len++] = tokens[i];
            }
        }
        n = new_len;
    }

    TKVec *result = tkvec_new(0);
    for (int i = 0; i < n; i++) tkvec_push(result, tokens[i]);
    free(tokens);
    return (long long)result;
}

// ================================================================
//  Decode
// ================================================================

const char *nuc_tok_decode(long long tok_h, long long token_ids_h) {
    BPETokenizer *tok = (BPETokenizer *)(void *)tok_h;
    TKVec *ids = (TKVec *)(void *)token_ids_h;
    if (!tok || !ids) return "";

    int total_len = 0;
    for (int i = 0; i < ids->len; i++) {
        int id = (int)ids->data[i];
        if (id >= 0 && id < tok->vocab_size)
            total_len += (int)strlen(tok->vocab[id]);
    }

    char *result = (char *)malloc(total_len + 1);
    int pos = 0;
    for (int i = 0; i < ids->len; i++) {
        int id = (int)ids->data[i];
        if (id >= 0 && id < tok->vocab_size) {
            int len = (int)strlen(tok->vocab[id]);
            memcpy(result + pos, tok->vocab[id], len);
            pos += len;
        }
    }
    result[pos] = 0;
    return result;
}

long long nuc_tok_vocab_size(long long tok_h) {
    BPETokenizer *tok = (BPETokenizer *)(void *)tok_h;
    return tok ? (long long)tok->vocab_size : 0;
}

// ================================================================
//  Simple char-level tokenizer
// ================================================================

long long nuc_tok_char_level(const char *text) {
    if (!text) return 0;
    int n = (int)strlen(text);
    TKVec *result = tkvec_new(0);
    for (int i = 0; i < n; i++) tkvec_push(result, (unsigned char)text[i]);
    return (long long)result;
}

// ================================================================
//  Save / Load
// ================================================================

void nuc_tok_save(long long tok_h, const char *path) {
    BPETokenizer *tok = (BPETokenizer *)(void *)tok_h;
    if (!tok || !path) return;
    FILE *f = fopen(path, "wb");
    if (!f) return;
    fwrite(&tok->vocab_size, sizeof(int), 1, f);
    fwrite(&tok->n_merges, sizeof(int), 1, f);
    for (int i = 0; i < tok->n_merges; i++) {
        fwrite(&tok->merge_a[i], sizeof(int), 1, f);
        fwrite(&tok->merge_b[i], sizeof(int), 1, f);
        fwrite(&tok->merge_id[i], sizeof(int), 1, f);
    }
    for (int i = 0; i < tok->vocab_size; i++) {
        int len = (int)strlen(tok->vocab[i]);
        fwrite(&len, sizeof(int), 1, f);
        fwrite(tok->vocab[i], 1, len, f);
    }
    fclose(f);
}

long long nuc_tok_load(const char *path) {
    if (!path) return 0;
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    BPETokenizer *tok = (BPETokenizer *)calloc(1, sizeof(BPETokenizer));
    fread(&tok->vocab_size, sizeof(int), 1, f);
    fread(&tok->n_merges, sizeof(int), 1, f);
    tok->merge_cap = tok->n_merges + 16;
    tok->merge_a = (int *)malloc(tok->merge_cap * sizeof(int));
    tok->merge_b = (int *)malloc(tok->merge_cap * sizeof(int));
    tok->merge_id = (int *)malloc(tok->merge_cap * sizeof(int));
    for (int i = 0; i < tok->n_merges; i++) {
        fread(&tok->merge_a[i], sizeof(int), 1, f);
        fread(&tok->merge_b[i], sizeof(int), 1, f);
        fread(&tok->merge_id[i], sizeof(int), 1, f);
    }
    tok->vocab_cap = tok->vocab_size + 16;
    tok->vocab = (char **)calloc(tok->vocab_cap, sizeof(char *));
    for (int i = 0; i < tok->vocab_size; i++) {
        int len;
        fread(&len, sizeof(int), 1, f);
        tok->vocab[i] = (char *)malloc(len + 1);
        fread(tok->vocab[i], 1, len, f);
        tok->vocab[i][len] = 0;
    }
    fclose(f);
    return (long long)tok;
}

void nuc_tok_free(long long tok_h) {
    BPETokenizer *tok = (BPETokenizer *)(void *)tok_h;
    if (!tok) return;
    for (int i = 0; i < tok->vocab_size; i++) free(tok->vocab[i]);
    free(tok->vocab); free(tok->merge_a); free(tok->merge_b); free(tok->merge_id); free(tok);
}

// ================================================================
//  Token-vector accessors (NUC-IMPROVE-006, v0.3.144)
// ================================================================
//
// Pre-v0.3.144, nuc_tok_encode and nuc_tok_char_level returned an
// opaque i64 handle to a TKVec but the .nr surface had no way to
// read the encoded length, index into the token sequence, free the
// vec, or call nuc_tok_decode (which existed in this file but was
// never exposed). These four accessors plus the existing decode
// close the gap. Adopters can now write the canonical round-trip:
//
//   let ids: i64 = tok_encode(tok, "hello");
//   let n: i64 = tok_vec_len(ids);
//   for i in 0..n { print(tok_vec_at(ids, i)); }
//   let decoded: str = tok_decode(tok, ids);
//   tok_vec_free(ids);

long long nuc_tok_vec_len(long long ids_h) {
    TKVec *v = (TKVec *)(void *)ids_h;
    if (!v) return 0;
    return (long long)v->len;
}

long long nuc_tok_vec_at(long long ids_h, long long idx) {
    TKVec *v = (TKVec *)(void *)ids_h;
    if (!v) return 0;
    if (idx < 0 || idx >= v->len) return 0;
    return v->data[idx];
}

void nuc_tok_vec_free(long long ids_h) {
    TKVec *v = (TKVec *)(void *)ids_h;
    if (!v) return;
    free(v->data);
    free(v);
}
