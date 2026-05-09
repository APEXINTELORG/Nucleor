// hashmap_rt.c — Hash Map / Dictionary for Nucleor
// Open-addressing with linear probing, string keys, i64 values.
// Auto-resizes at 70% load factor.
//
// Compile: clang -c stdlib/runtime/hashmap_rt.c -o target/hashmap_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ================================================================
//  Hash function (FNV-1a)
// ================================================================

static unsigned long long hm_hash(const char *key) {
    unsigned long long h = 14695981039346656037ULL;
    for (const char *p = key; *p; p++) {
        h ^= (unsigned char)*p;
        h *= 1099511628211ULL;
    }
    return h;
}

// ================================================================
//  Hash Map internals
// ================================================================

#define HM_EMPTY   0
#define HM_USED    1
#define HM_DELETED 2

typedef struct {
    char *key;
    long long val;
    int state;
} HMEntry;

typedef struct {
    HMEntry *buckets;
    int cap;
    int len;
} HashMap;

static HashMap *hm_alloc(int cap) {
    HashMap *m = (HashMap *)malloc(sizeof(HashMap));
    m->cap = cap;
    m->len = 0;
    m->buckets = (HMEntry *)calloc(cap, sizeof(HMEntry));
    return m;
}

static void hm_resize(HashMap *m) {
    int new_cap = m->cap * 2;
    HMEntry *old = m->buckets;
    int old_cap = m->cap;
    m->buckets = (HMEntry *)calloc(new_cap, sizeof(HMEntry));
    m->cap = new_cap;
    m->len = 0;
    for (int i = 0; i < old_cap; i++) {
        if (old[i].state == HM_USED) {
            unsigned long long h = hm_hash(old[i].key) % new_cap;
            while (m->buckets[h].state == HM_USED)
                h = (h + 1) % new_cap;
            m->buckets[h].key = old[i].key; // transfer ownership
            m->buckets[h].val = old[i].val;
            m->buckets[h].state = HM_USED;
            m->len++;
        } else {
            free(old[i].key);
        }
    }
    free(old);
}

static int hm_find(HashMap *m, const char *key) {
    unsigned long long h = hm_hash(key) % m->cap;
    int start = (int)h;
    while (1) {
        if (m->buckets[h].state == HM_EMPTY) return -1;
        if (m->buckets[h].state == HM_USED && strcmp(m->buckets[h].key, key) == 0)
            return (int)h;
        h = (h + 1) % m->cap;
        if ((int)h == start) return -1;
    }
}

// ================================================================
//  Public API
// ================================================================

long long nuc_map_new(void) {
    return (long long)hm_alloc(64);
}

void nuc_map_set(long long handle, const char *key, long long val) {
    HashMap *m = (HashMap *)(void *)handle;
    if (!m || !key) return;

    // Check for existing key
    int idx = hm_find(m, key);
    if (idx >= 0) {
        m->buckets[idx].val = val;
        return;
    }

    // Resize if needed
    if (m->len * 10 >= m->cap * 7) hm_resize(m);

    unsigned long long h = hm_hash(key) % m->cap;
    while (m->buckets[h].state == HM_USED)
        h = (h + 1) % m->cap;

    m->buckets[h].key = (char *)malloc(strlen(key) + 1);
    strcpy(m->buckets[h].key, key);
    m->buckets[h].val = val;
    m->buckets[h].state = HM_USED;
    m->len++;
}

long long nuc_map_get(long long handle, const char *key) {
    HashMap *m = (HashMap *)(void *)handle;
    if (!m || !key) return -9999999;
    int idx = hm_find(m, key);
    if (idx >= 0) return m->buckets[idx].val;
    return -9999999; // sentinel for missing
}

long long nuc_map_has(long long handle, const char *key) {
    HashMap *m = (HashMap *)(void *)handle;
    if (!m || !key) return 0;
    return hm_find(m, key) >= 0 ? 1 : 0;
}

void nuc_map_del(long long handle, const char *key) {
    HashMap *m = (HashMap *)(void *)handle;
    if (!m || !key) return;
    int idx = hm_find(m, key);
    if (idx >= 0) {
        free(m->buckets[idx].key);
        m->buckets[idx].key = NULL;
        m->buckets[idx].state = HM_DELETED;
        m->len--;
    }
}

long long nuc_map_len(long long handle) {
    HashMap *m = (HashMap *)(void *)handle;
    return m ? (long long)m->len : 0;
}

// Returns Vec of key strings (as Nucleor Vec<str>)
long long nuc_map_keys(long long handle) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    HashMap *m = (HashMap *)(void *)handle;
    if (!m) return 0;
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->cap = m->len + 1;
    v->data = (long long *)malloc(v->cap * sizeof(long long));
    v->len = 0;
    for (int i = 0; i < m->cap; i++) {
        if (m->buckets[i].state == HM_USED) {
            v->data[v->len++] = (long long)m->buckets[i].key;
        }
    }
    return (long long)v;
}

// Iterate: get key at position (for iteration)
const char *nuc_map_key_at(long long handle, long long pos) {
    HashMap *m = (HashMap *)(void *)handle;
    if (!m) return "";
    int count = 0;
    for (int i = 0; i < m->cap; i++) {
        if (m->buckets[i].state == HM_USED) {
            if (count == (int)pos) return m->buckets[i].key;
            count++;
        }
    }
    return "";
}

long long nuc_map_val_at(long long handle, long long pos) {
    HashMap *m = (HashMap *)(void *)handle;
    if (!m) return 0;
    int count = 0;
    for (int i = 0; i < m->cap; i++) {
        if (m->buckets[i].state == HM_USED) {
            if (count == (int)pos) return m->buckets[i].val;
            count++;
        }
    }
    return 0;
}

void nuc_map_free(long long handle) {
    HashMap *m = (HashMap *)(void *)handle;
    if (!m) return;
    for (int i = 0; i < m->cap; i++) {
        if (m->buckets[i].key) free(m->buckets[i].key);
    }
    free(m->buckets);
    free(m);
}

// Set with f64 value
void nuc_map_set_f64(long long handle, const char *key, long long val_bits) {
    nuc_map_set(handle, key, val_bits);
}

long long nuc_map_get_f64(long long handle, const char *key) {
    return nuc_map_get(handle, key);
}
