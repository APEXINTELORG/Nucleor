// sgrid_rt.c — Spatial hash grid for fast 3D nearest-neighbor
// queries.
//
// Bins points into cubic cells of side `cell_size`. Nearest-
// neighbor queries scan only the query cell + neighbors instead
// of all points, giving roughly O(1) average-case lookup for
// uniformly-distributed point clouds.
//
// Foundation for:
// - Faster ICP nearest-neighbor (vs the brute-force O(N) in
//   `icp.nr`).
// - Large-roadmap PRM expansion (find k nearest existing nodes
//   without scanning all of them).
// - Particle-grid neighborhood lookups in physics sims.
//
// **Limitations** (KD-tree / R-tree variants land in v0.6 if
// needed for non-uniform point distributions):
// - Cell size is fixed; choose ≈ expected nearest-neighbor
//   distance for best performance.
// - For very non-uniform clouds, a KD-tree adapts better.
// - Single-bin storage: no bin overflow logic — bins grow
//   dynamically.
//
// Compile: clang -c stdlib/runtime/sgrid_rt.c -o target/sgrid.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int *idx;       // flat point indices
    int n, cap;
} _SBin;

typedef struct {
    int n_pts;
    int cap_pts;
    double *pts;          // n_pts × 3
    double cell_size;
    int n_bins;           // total bins
    int hash_buckets;     // number of hash buckets
    _SBin *bins;          // hash_buckets entries
} NSGrid;

// FNV-1a 32-bit on 3 ints, then mod by hash_buckets.
static unsigned int _hash3(int i, int j, int k, int n) {
    unsigned int h = 2166136261u;
    h = (h ^ (unsigned int)i) * 16777619u;
    h = (h ^ (unsigned int)j) * 16777619u;
    h = (h ^ (unsigned int)k) * 16777619u;
    return h % (unsigned int)n;
}

long long nuc_sgrid_new(long long cell_size_b, long long n_pts_hint) {
    NSGrid *g = (NSGrid *)calloc(1, sizeof(NSGrid));
    g->cell_size = _i2f(cell_size_b);
    if (g->cell_size <= 0) g->cell_size = 0.1;
    g->cap_pts = (int)((n_pts_hint > 16) ? n_pts_hint : 16);
    g->pts = (double *)malloc(g->cap_pts * 3 * sizeof(double));
    g->hash_buckets = 1024;   // fixed bucket count; grows poorly above ~5000 pts
    g->bins = (_SBin *)calloc(g->hash_buckets, sizeof(_SBin));
    return (long long)(size_t)g;
}

static void _bin_push(NSGrid *g, int bucket, int point_idx) {
    _SBin *b = &g->bins[bucket];
    if (b->n >= b->cap) {
        b->cap = (b->cap == 0) ? 4 : b->cap * 2;
        b->idx = (int *)realloc(b->idx, b->cap * sizeof(int));
    }
    b->idx[b->n++] = point_idx;
}

long long nuc_sgrid_insert(long long h, long long x_b, long long y_b, long long z_b) {
    NSGrid *g = (NSGrid *)(void *)(size_t)h;
    if (!g) return -1;
    if (g->n_pts >= g->cap_pts) {
        g->cap_pts *= 2;
        g->pts = (double *)realloc(g->pts, g->cap_pts * 3 * sizeof(double));
    }
    double x = _i2f(x_b), y = _i2f(y_b), z = _i2f(z_b);
    g->pts[g->n_pts*3+0] = x;
    g->pts[g->n_pts*3+1] = y;
    g->pts[g->n_pts*3+2] = z;
    int i = (int)floor(x / g->cell_size);
    int j = (int)floor(y / g->cell_size);
    int k = (int)floor(z / g->cell_size);
    unsigned int bucket = _hash3(i, j, k, g->hash_buckets);
    _bin_push(g, (int)bucket, g->n_pts);
    return (long long)(g->n_pts++);
}

long long nuc_sgrid_count(long long h) {
    NSGrid *g = (NSGrid *)(void *)(size_t)h;
    return g ? (long long)g->n_pts : 0;
}

// Nearest neighbor of (x, y, z) in the grid. Returns the point
// index or -1 if grid is empty. Scans the query cell + all 26
// neighbor cells; if no point found, falls back to a brute-force
// scan as a safety net.
long long nuc_sgrid_nearest(long long h, long long x_b, long long y_b, long long z_b) {
    NSGrid *g = (NSGrid *)(void *)(size_t)h;
    if (!g || g->n_pts == 0) return -1;
    double x = _i2f(x_b), y = _i2f(y_b), z = _i2f(z_b);
    int i0 = (int)floor(x / g->cell_size);
    int j0 = (int)floor(y / g->cell_size);
    int k0 = (int)floor(z / g->cell_size);
    int best = -1;
    double best_d2 = 1e300;
    for (int di = -1; di <= 1; di++)
    for (int dj = -1; dj <= 1; dj++)
    for (int dk = -1; dk <= 1; dk++) {
        unsigned int b = _hash3(i0+di, j0+dj, k0+dk, g->hash_buckets);
        _SBin *bin = &g->bins[b];
        for (int q = 0; q < bin->n; q++) {
            int pi = bin->idx[q];
            // Re-verify cell membership (hash collisions can mix
            // points from different cells into the same bucket).
            int pi_i = (int)floor(g->pts[pi*3+0] / g->cell_size);
            int pi_j = (int)floor(g->pts[pi*3+1] / g->cell_size);
            int pi_k = (int)floor(g->pts[pi*3+2] / g->cell_size);
            if (pi_i != i0+di || pi_j != j0+dj || pi_k != k0+dk) continue;
            double dx = g->pts[pi*3+0] - x;
            double dy = g->pts[pi*3+1] - y;
            double dz = g->pts[pi*3+2] - z;
            double d2 = dx*dx + dy*dy + dz*dz;
            if (d2 < best_d2) { best_d2 = d2; best = pi; }
        }
    }
    if (best < 0) {
        // Safety fallback: brute force. Guarantees correctness even
        // when the cell + 1-ring is empty (very large query offset
        // from any inserted point).
        for (int i = 0; i < g->n_pts; i++) {
            double dx = g->pts[i*3+0] - x;
            double dy = g->pts[i*3+1] - y;
            double dz = g->pts[i*3+2] - z;
            double d2 = dx*dx + dy*dy + dz*dz;
            if (d2 < best_d2) { best_d2 = d2; best = i; }
        }
    }
    return (long long)best;
}

void nuc_sgrid_free(long long h) {
    NSGrid *g = (NSGrid *)(void *)(size_t)h;
    if (!g) return;
    if (g->pts) free(g->pts);
    if (g->bins) {
        for (int i = 0; i < g->hash_buckets; i++) {
            if (g->bins[i].idx) free(g->bins[i].idx);
        }
        free(g->bins);
    }
    free(g);
}
