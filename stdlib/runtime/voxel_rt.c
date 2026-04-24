// voxel_rt.c — Dense 3D voxel grid for occupancy / scalar fields.
//
// Complements `octree.nr`: dense storage is faster than sparse
// octree for cluttered scenes (no tree traversal per query) but
// memory-intensive for sparse scenes (allocates the full grid up
// front).
//
// Use cases:
// - Inflated obstacle costmap for dense-environment local
//   planning.
// - Voxel-based collision check in tightly-packed cells.
// - Signed distance field caching for rapid distance queries.
//
// Storage: a flat `n_total = nx · ny · nz` byte array, with
// values { 0 = unknown, 1 = free, 2 = occupied }. Linear index:
// `idx = i + j·nx + k·nx·ny`.
//
// Compile: clang -c stdlib/runtime/voxel_rt.c -o target/voxel.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

#define _VOX_UNKNOWN  0
#define _VOX_FREE     1
#define _VOX_OCCUPIED 2

typedef struct {
    int nx, ny, nz;
    double cx, cy, cz;     // world-frame center of grid
    double res;            // voxel side length
    unsigned char *cells;  // nx · ny · nz
} NVoxel;

// Construct a voxel grid centered at (cx, cy, cz) with the given
// resolution and grid dimensions. The grid spans
// [c - res·n/2, c + res·n/2] per axis.
long long nuc_vox_new(
    long long cx_b, long long cy_b, long long cz_b,
    long long res_b,
    long long nx_, long long ny_, long long nz_)
{
    int nx = (int)nx_, ny = (int)ny_, nz = (int)nz_;
    if (nx <= 0 || ny <= 0 || nz <= 0) return 0;
    NVoxel *v = (NVoxel *)calloc(1, sizeof(NVoxel));
    v->nx = nx; v->ny = ny; v->nz = nz;
    v->cx = _i2f(cx_b); v->cy = _i2f(cy_b); v->cz = _i2f(cz_b);
    v->res = _i2f(res_b);
    long long total = (long long)nx * ny * nz;
    v->cells = (unsigned char *)calloc(total, 1);
    return (long long)(size_t)v;
}

// Convert a world-frame coordinate to voxel index (per axis).
// Returns 1 if inside the grid (writes (i, j, k)), 0 otherwise.
static int _world_to_voxel(NVoxel *v, double x, double y, double z,
                           int *i_out, int *j_out, int *k_out)
{
    double half_x = v->res * v->nx * 0.5;
    double half_y = v->res * v->ny * 0.5;
    double half_z = v->res * v->nz * 0.5;
    if (x < v->cx - half_x || x > v->cx + half_x) return 0;
    if (y < v->cy - half_y || y > v->cy + half_y) return 0;
    if (z < v->cz - half_z || z > v->cz + half_z) return 0;
    int i = (int)((x - (v->cx - half_x)) / v->res);
    int j = (int)((y - (v->cy - half_y)) / v->res);
    int k = (int)((z - (v->cz - half_z)) / v->res);
    if (i < 0) i = 0; if (i >= v->nx) i = v->nx - 1;
    if (j < 0) j = 0; if (j >= v->ny) j = v->ny - 1;
    if (k < 0) k = 0; if (k >= v->nz) k = v->nz - 1;
    *i_out = i; *j_out = j; *k_out = k;
    return 1;
}

long long nuc_vox_insert(long long h, long long x_b, long long y_b, long long z_b,
                        long long occupied)
{
    NVoxel *v = (NVoxel *)(void *)(size_t)h;
    if (!v) return -1;
    int i, j, k;
    if (!_world_to_voxel(v, _i2f(x_b), _i2f(y_b), _i2f(z_b), &i, &j, &k)) return -1;
    long long idx = (long long)i + (long long)j * v->nx + (long long)k * v->nx * v->ny;
    v->cells[idx] = occupied ? _VOX_OCCUPIED : _VOX_FREE;
    return 0;
}

long long nuc_vox_query(long long h, long long x_b, long long y_b, long long z_b)
{
    NVoxel *v = (NVoxel *)(void *)(size_t)h;
    if (!v) return 0;
    int i, j, k;
    if (!_world_to_voxel(v, _i2f(x_b), _i2f(y_b), _i2f(z_b), &i, &j, &k)) return 0;
    long long idx = (long long)i + (long long)j * v->nx + (long long)k * v->nx * v->ny;
    return (long long)v->cells[idx];
}

// Occupancy stats: total cell count + number of occupied cells.
long long nuc_vox_occupied_count(long long h) {
    NVoxel *v = (NVoxel *)(void *)(size_t)h;
    if (!v) return 0;
    long long total = (long long)v->nx * v->ny * v->nz;
    long long occ = 0;
    for (long long i = 0; i < total; i++) if (v->cells[i] == _VOX_OCCUPIED) occ++;
    return occ;
}

long long nuc_vox_total_count(long long h) {
    NVoxel *v = (NVoxel *)(void *)(size_t)h;
    if (!v) return 0;
    return (long long)v->nx * v->ny * v->nz;
}

void nuc_vox_free(long long h) {
    NVoxel *v = (NVoxel *)(void *)(size_t)h;
    if (!v) return;
    if (v->cells) free(v->cells);
    free(v);
}
