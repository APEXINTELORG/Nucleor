// compress_rt.c — Data Compression for Nucleor
// LZ77, Huffman, Run-Length Encoding.
//
// Compile: clang -c stdlib/runtime/compress_rt.c -o target/compress_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { long long *data; int len; int cap; } CMVec;

// ================================================================
//  Run-Length Encoding
// ================================================================

const char *nuc_compress_rle(const char *data, long long len) {
    if (!data || len <= 0) return "";
    int n = (int)len;
    int cap = n * 2 + 16;
    char *out = (char *)malloc(cap);
    int pos = 0;

    int i = 0;
    while (i < n) {
        char c = data[i];
        int count = 1;
        while (i + count < n && data[i + count] == c && count < 255) count++;
        if (pos + 16 >= cap) { cap *= 2; out = (char *)realloc(out, cap); }
        pos += sprintf(out + pos, "%d%c", count, c);
        i += count;
    }
    out[pos] = 0;
    return out;
}

const char *nuc_decompress_rle(const char *data, long long len) {
    if (!data) return "";
    int n = (int)len;
    int cap = n * 4 + 16;
    char *out = (char *)malloc(cap);
    int pos = 0, i = 0;

    while (i < n) {
        int count = 0;
        while (i < n && data[i] >= '0' && data[i] <= '9') {
            count = count * 10 + (data[i] - '0'); i++;
        }
        if (i >= n) break;
        char c = data[i++];
        if (pos + count + 1 >= cap) { cap = (pos + count) * 2; out = (char *)realloc(out, cap); }
        for (int j = 0; j < count; j++) out[pos++] = c;
    }
    out[pos] = 0;
    return out;
}

// ================================================================
//  LZ77 Compression (simplified)
//  Output format: sequence of (offset, length, next_char) triples
// ================================================================

typedef struct { unsigned char *data; int len; } CompBuf;

long long nuc_compress_lz77(const char *data, long long len) {
    if (!data || len <= 0) return 0;
    int n = (int)len;
    int window = 4096;
    int lookahead = 18;

    int cap = n * 2;
    unsigned char *out = (unsigned char *)malloc(cap);
    int opos = 0;
    int i = 0;

    while (i < n) {
        int best_off = 0, best_len = 0;
        int search_start = (i - window > 0) ? i - window : 0;

        for (int j = search_start; j < i; j++) {
            int ml = 0;
            while (ml < lookahead && i + ml < n && data[j + ml] == data[i + ml]) ml++;
            if (ml > best_len) { best_len = ml; best_off = i - j; }
        }

        if (opos + 4 >= cap) { cap *= 2; out = (unsigned char *)realloc(out, cap); }

        if (best_len >= 3) {
            out[opos++] = 1; // match flag
            out[opos++] = (unsigned char)(best_off >> 8);
            out[opos++] = (unsigned char)(best_off & 0xFF);
            out[opos++] = (unsigned char)best_len;
            i += best_len;
        } else {
            out[opos++] = 0; // literal flag
            out[opos++] = (unsigned char)data[i++];
        }
    }

    CompBuf *buf = (CompBuf *)malloc(sizeof(CompBuf));
    buf->data = out; buf->len = opos;
    return (long long)buf;
}

const char *nuc_decompress_lz77(long long buf_h) {
    CompBuf *buf = (CompBuf *)(void *)buf_h;
    if (!buf) return "";
    int cap = buf->len * 4;
    char *out = (char *)malloc(cap);
    int opos = 0, i = 0;

    while (i < buf->len) {
        if (opos + 256 >= cap) { cap *= 2; out = (char *)realloc(out, cap); }
        if (buf->data[i] == 1 && i + 3 < buf->len) {
            i++;
            int offset = (buf->data[i] << 8) | buf->data[i + 1]; i += 2;
            int length = buf->data[i++];
            int src = opos - offset;
            for (int j = 0; j < length; j++) out[opos++] = out[src + j];
        } else if (buf->data[i] == 0 && i + 1 < buf->len) {
            i++;
            out[opos++] = (char)buf->data[i++];
        } else {
            break;
        }
    }
    out[opos] = 0;
    return out;
}

long long nuc_compress_size(long long buf_h) {
    CompBuf *buf = (CompBuf *)(void *)buf_h;
    return buf ? (long long)buf->len : 0;
}

void nuc_compress_free(long long buf_h) {
    CompBuf *buf = (CompBuf *)(void *)buf_h;
    if (buf) { free(buf->data); free(buf); }
}
