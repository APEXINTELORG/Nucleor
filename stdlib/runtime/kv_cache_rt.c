// kv_cache_rt.c — Paged KV Cache for Nucleor
// Block-based KV storage with page tables, eviction, prefix sharing.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/kv_cache_rt.c -o target/kv_cache_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static double _kc_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _kc_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } KCVec;

#define KV_BLOCK_SIZE 16   // tokens per block
#define KV_MAX_BLOCKS 4096
#define KV_MAX_LAYERS 64
#define KV_MAX_HEADS  64

typedef struct {
    double *k_data;  // [block_size * head_dim]
    double *v_data;
    int ref_count;
    int used;        // number of tokens filled (0..block_size)
} KVBlock;

typedef struct {
    int n_layers, n_heads, head_dim;
    int block_size;
    KVBlock *blocks;       // pool of all blocks
    int n_blocks;
    int *free_list;
    int free_top;
    // Per-sequence page tables: page_table[layer][head][logical_block] = physical_block
    int **page_tables;     // flat: [n_layers * n_heads * max_seq_blocks]
    int max_seq_blocks;
    int seq_len;           // current sequence length
} KVCache;

long long nuc_kv_cache_new(long long n_layers, long long n_heads, long long head_dim, long long max_seq) {
    int nl = (int)n_layers, nh = (int)n_heads, hd = (int)head_dim;
    int max_blocks = ((int)max_seq + KV_BLOCK_SIZE - 1) / KV_BLOCK_SIZE;
    int total_blocks = nl * nh * max_blocks;
    if (total_blocks > KV_MAX_BLOCKS * 16) total_blocks = KV_MAX_BLOCKS * 16;

    KVCache *cache = (KVCache *)calloc(1, sizeof(KVCache));
    cache->n_layers = nl; cache->n_heads = nh; cache->head_dim = hd;
    cache->block_size = KV_BLOCK_SIZE;
    cache->max_seq_blocks = max_blocks;

    // Allocate block pool
    cache->n_blocks = total_blocks;
    cache->blocks = (KVBlock *)calloc(total_blocks, sizeof(KVBlock));
    for (int i = 0; i < total_blocks; i++) {
        cache->blocks[i].k_data = (double *)calloc(KV_BLOCK_SIZE * hd, sizeof(double));
        cache->blocks[i].v_data = (double *)calloc(KV_BLOCK_SIZE * hd, sizeof(double));
    }

    // Free list
    cache->free_list = (int *)malloc(total_blocks * sizeof(int));
    cache->free_top = total_blocks;
    for (int i = 0; i < total_blocks; i++) cache->free_list[i] = total_blocks - 1 - i;

    // Page tables (initialized to -1 = unmapped)
    int pt_size = nl * nh * max_blocks;
    cache->page_tables = (int **)malloc(sizeof(int *));
    cache->page_tables[0] = (int *)malloc(pt_size * sizeof(int));
    for (int i = 0; i < pt_size; i++) cache->page_tables[0][i] = -1;

    return (long long)cache;
}

static int kv_alloc_block(KVCache *cache) {
    if (cache->free_top <= 0) return -1;
    return cache->free_list[--cache->free_top];
}

static void kv_free_block(KVCache *cache, int block_id) {
    if (block_id >= 0) {
        cache->blocks[block_id].used = 0;
        cache->blocks[block_id].ref_count = 0;
        cache->free_list[cache->free_top++] = block_id;
    }
}

// ================================================================
//  Insert KV for a token at given position
// ================================================================

void nuc_kv_cache_insert(long long ch, long long layer, long long head, long long pos,
                          long long k_vec_h, long long v_vec_h) {
    KVCache *cache = (KVCache *)(void *)ch;
    KCVec *kv = (KCVec *)(void *)k_vec_h;
    KCVec *vv = (KCVec *)(void *)v_vec_h;
    int l = (int)layer, h = (int)head, p = (int)pos;
    int logical_block = p / cache->block_size;
    int offset = p % cache->block_size;
    int hd = cache->head_dim;

    // Page table index
    int pt_idx = l * cache->n_heads * cache->max_seq_blocks + h * cache->max_seq_blocks + logical_block;
    int *pt = cache->page_tables[0];

    // Allocate block if needed
    if (pt[pt_idx] < 0) {
        int bid = kv_alloc_block(cache);
        if (bid < 0) return; // out of memory
        pt[pt_idx] = bid;
        cache->blocks[bid].ref_count = 1;
    }

    int bid = pt[pt_idx];
    KVBlock *blk = &cache->blocks[bid];

    // Copy K and V vectors
    for (int i = 0; i < hd && i < kv->len; i++)
        blk->k_data[offset * hd + i] = _kc_i2f(kv->data[i]);
    for (int i = 0; i < hd && i < vv->len; i++)
        blk->v_data[offset * hd + i] = _kc_i2f(vv->data[i]);

    if (offset + 1 > blk->used) blk->used = offset + 1;
    if (p + 1 > cache->seq_len) cache->seq_len = p + 1;
}

// ================================================================
//  Lookup: gather KV for a range of positions
//  Returns flat Vec [n_positions * head_dim] for K (and similarly V)
// ================================================================

long long nuc_kv_cache_get_k(long long ch, long long layer, long long head,
                               long long start_pos, long long end_pos) {
    KVCache *cache = (KVCache *)(void *)ch;
    int l = (int)layer, h = (int)head;
    int sp = (int)start_pos, ep = (int)end_pos;
    int hd = cache->head_dim;
    int n = ep - sp;

    KCVec *out = (KCVec *)malloc(sizeof(KCVec));
    out->len = n * hd; out->cap = out->len;
    out->data = (long long *)malloc(out->len * sizeof(long long));

    int *pt = cache->page_tables[0];
    for (int p = sp; p < ep; p++) {
        int lb = p / cache->block_size;
        int off = p % cache->block_size;
        int pt_idx = l * cache->n_heads * cache->max_seq_blocks + h * cache->max_seq_blocks + lb;
        int bid = pt[pt_idx];
        int dst = (p - sp) * hd;
        if (bid >= 0) {
            for (int i = 0; i < hd; i++)
                out->data[dst + i] = _kc_f2i(cache->blocks[bid].k_data[off * hd + i]);
        } else {
            for (int i = 0; i < hd; i++) out->data[dst + i] = _kc_f2i(0.0);
        }
    }
    return (long long)out;
}

long long nuc_kv_cache_get_v(long long ch, long long layer, long long head,
                               long long start_pos, long long end_pos) {
    KVCache *cache = (KVCache *)(void *)ch;
    int l = (int)layer, h = (int)head;
    int sp = (int)start_pos, ep = (int)end_pos;
    int hd = cache->head_dim;
    int n = ep - sp;

    KCVec *out = (KCVec *)malloc(sizeof(KCVec));
    out->len = n * hd; out->cap = out->len;
    out->data = (long long *)malloc(out->len * sizeof(long long));

    int *pt = cache->page_tables[0];
    for (int p = sp; p < ep; p++) {
        int lb = p / cache->block_size;
        int off = p % cache->block_size;
        int pt_idx = l * cache->n_heads * cache->max_seq_blocks + h * cache->max_seq_blocks + lb;
        int bid = pt[pt_idx];
        int dst = (p - sp) * hd;
        if (bid >= 0) {
            for (int i = 0; i < hd; i++)
                out->data[dst + i] = _kc_f2i(cache->blocks[bid].v_data[off * hd + i]);
        } else {
            for (int i = 0; i < hd; i++) out->data[dst + i] = _kc_f2i(0.0);
        }
    }
    return (long long)out;
}

long long nuc_kv_cache_seq_len(long long ch) { return ((KVCache *)(void *)ch)->seq_len; }

long long nuc_kv_cache_blocks_used(long long ch) {
    KVCache *cache = (KVCache *)(void *)ch;
    return cache->n_blocks - cache->free_top;
}

// Evict oldest blocks (sliding window eviction)
void nuc_kv_cache_evict_before(long long ch, long long pos) {
    KVCache *cache = (KVCache *)(void *)ch;
    int max_block = (int)pos / cache->block_size;
    int *pt = cache->page_tables[0];
    int pt_total = cache->n_layers * cache->n_heads * cache->max_seq_blocks;

    for (int l = 0; l < cache->n_layers; l++)
        for (int h = 0; h < cache->n_heads; h++)
            for (int b = 0; b < max_block; b++) {
                int idx = l * cache->n_heads * cache->max_seq_blocks + h * cache->max_seq_blocks + b;
                if (pt[idx] >= 0) { kv_free_block(cache, pt[idx]); pt[idx] = -1; }
            }
}

void nuc_kv_cache_free(long long ch) {
    KVCache *cache = (KVCache *)(void *)ch;
    if (!cache) return;
    for (int i = 0; i < cache->n_blocks; i++) {
        free(cache->blocks[i].k_data); free(cache->blocks[i].v_data);
    }
    free(cache->blocks); free(cache->free_list);
    free(cache->page_tables[0]); free(cache->page_tables);
    free(cache);
}
