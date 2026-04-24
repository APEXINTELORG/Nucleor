// occgrid_rt.c — 2D log-odds probabilistic occupancy grid.
//
// Each cell stores a log-odds value:
//   log_odds = log(p / (1 − p))
// `0` = unknown (`p = 0.5`); positive = occupied; negative = free.
//
// Sensor updates use the standard inverse-sensor model with
// Bresenham-traced rays:
//   - Cells along the ray (before range) are "free" → subtract `l_free`.
//   - Cell at range is "occupied" (if range < max_range) → add `l_occ`.
//   - Cells beyond max_range are unobserved → no update.
//
// Probability of occupancy at any cell is recovered by the sigmoid:
//   p = 1 / (1 + exp(−log_odds))
//
// Foundation for:
//   - 2D mobile-robot SLAM / mapping (Hector SLAM, gmapping).
//   - Free-space planning (treat cells with `p > 0.5` as obstacles).
//   - Frontier exploration (boundary between known free and unknown).
//
// **Limitations** (3D voxel grid / probabilistic forward sensor
// model / Bayesian downsampling land in v0.6 if needed):
// - 2D only (use `octree.nr` for 3D occupancy).
// - Bresenham raycasting (axis-aligned discretization). For sub-
//   cell precision use a DDA / Amanatides-Woo traversal.
// - Per-cell log-odds clamped to ±20 to avoid runaway saturation.
//
// Compile: clang -c stdlib/runtime/occgrid_rt.c -o target/occgrid.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

#define OCC_CLAMP 20.0

typedef struct {
    int W, H;
    double cell_size;
    double ox, oy;        // world-frame origin of cell (0, 0)'s lower-left corner
    double prior;
    double *lo;           // W*H log-odds
} NOCC;

long long nuc_occgrid_new(long long W_, long long H_, long long cell_b,
                           long long ox_b, long long oy_b)
{
    int W = (int)W_, H = (int)H_;
    if (W <= 0 || H <= 0) return 0;
    double c = _i2f(cell_b);
    if (c <= 0) return 0;
    NOCC *p = (NOCC *)calloc(1, sizeof(NOCC));
    p->W = W; p->H = H; p->cell_size = c;
    p->ox = _i2f(ox_b); p->oy = _i2f(oy_b);
    p->prior = 0.0;
    p->lo = (double *)calloc(W * H, sizeof(double));
    return (long long)(size_t)p;
}

void nuc_occgrid_set_prior(long long h, long long lo_b) {
    NOCC *p = (NOCC *)(void *)(size_t)h;
    if (!p) return;
    p->prior = _i2f(lo_b);
    for (int i = 0; i < p->W * p->H; i++) p->lo[i] = p->prior;
}

void nuc_occgrid_clear(long long h) {
    NOCC *p = (NOCC *)(void *)(size_t)h;
    if (!p) return;
    for (int i = 0; i < p->W * p->H; i++) p->lo[i] = p->prior;
}

// Convert world (x, y) to cell indices. Returns 1 if inside grid.
static int _world_to_cell(NOCC *p, double x, double y, int *ix, int *iy) {
    double fx = (x - p->ox) / p->cell_size;
    double fy = (y - p->oy) / p->cell_size;
    int cx = (int)floor(fx);
    int cy = (int)floor(fy);
    *ix = cx; *iy = cy;
    return (cx >= 0 && cx < p->W && cy >= 0 && cy < p->H);
}

static void _add(NOCC *p, int ix, int iy, double delta) {
    if (ix < 0 || ix >= p->W || iy < 0 || iy >= p->H) return;
    double v = p->lo[iy * p->W + ix] + delta;
    if (v > OCC_CLAMP) v = OCC_CLAMP;
    if (v < -OCC_CLAMP) v = -OCC_CLAMP;
    p->lo[iy * p->W + ix] = v;
}

// Bresenham line from (x0, y0) to (x1, y1). Returns ALL cells on
// the line via callback `f(ix, iy)` — but in C without closures we
// trace inline.
//
// Update one ray: free along the path, occupied at the endpoint
// (if within max_range).
void nuc_occgrid_update_ray(long long h,
    long long sx_b, long long sy_b,
    long long range_b, long long bearing_b,
    long long l_free_b, long long l_occ_b,
    long long max_range_b)
{
    NOCC *p = (NOCC *)(void *)(size_t)h;
    if (!p) return;
    double sx = _i2f(sx_b), sy = _i2f(sy_b);
    double range = _i2f(range_b);
    double bearing = _i2f(bearing_b);
    double l_free = _i2f(l_free_b);
    double l_occ  = _i2f(l_occ_b);
    double max_range = _i2f(max_range_b);
    if (max_range <= 0) max_range = 1e6;

    int hit_endpoint = (range < max_range);
    double end_dist = (range < max_range) ? range : max_range;
    double ex = sx + cos(bearing) * end_dist;
    double ey = sy + sin(bearing) * end_dist;

    int x0, y0, x1, y1;
    _world_to_cell(p, sx, sy, &x0, &y0);
    _world_to_cell(p, ex, ey, &x1, &y1);

    // Bresenham line algorithm.
    int dx = abs(x1 - x0), dy = abs(y1 - y0);
    int sxs = (x0 < x1) ? 1 : -1;
    int sys = (y0 < y1) ? 1 : -1;
    int err = dx - dy;
    int cx = x0, cy = y0;
    while (1) {
        // Mark interior cells as "free".
        if (!(cx == x1 && cy == y1)) _add(p, cx, cy, -l_free);
        if (cx == x1 && cy == y1) break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; cx += sxs; }
        if (e2 <  dx) { err += dx; cy += sys; }
    }
    // Endpoint: occupied if a real hit; otherwise also free (free-space update).
    if (hit_endpoint) _add(p, x1, y1, +l_occ);
    else              _add(p, x1, y1, -l_free);
}

long long nuc_occgrid_log_odds(long long h, long long x_b, long long y_b) {
    NOCC *p = (NOCC *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    int ix, iy;
    if (!_world_to_cell(p, _i2f(x_b), _i2f(y_b), &ix, &iy)) return _f2i(0.0);
    return _f2i(p->lo[iy * p->W + ix]);
}

long long nuc_occgrid_probability(long long h, long long x_b, long long y_b) {
    NOCC *p = (NOCC *)(void *)(size_t)h;
    if (!p) return _f2i(0.5);
    int ix, iy;
    if (!_world_to_cell(p, _i2f(x_b), _i2f(y_b), &ix, &iy)) return _f2i(0.5);
    double l = p->lo[iy * p->W + ix];
    return _f2i(1.0 / (1.0 + exp(-l)));
}

long long nuc_occgrid_is_occupied(long long h, long long x_b, long long y_b,
                                   long long thresh_b)
{
    NOCC *p = (NOCC *)(void *)(size_t)h;
    if (!p) return 0;
    double thresh = _i2f(thresh_b);
    if (thresh <= 0 || thresh >= 1) thresh = 0.5;
    int ix, iy;
    if (!_world_to_cell(p, _i2f(x_b), _i2f(y_b), &ix, &iy)) return 0;
    double l = p->lo[iy * p->W + ix];
    double pp = 1.0 / (1.0 + exp(-l));
    return pp > thresh ? 1 : 0;
}

// Cell-index accessors for direct grid-iteration use cases (rendering, etc.).
long long nuc_occgrid_cell_log_odds(long long h, long long ix_, long long iy_) {
    NOCC *p = (NOCC *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    int ix = (int)ix_, iy = (int)iy_;
    if (ix < 0 || ix >= p->W || iy < 0 || iy >= p->H) return _f2i(0.0);
    return _f2i(p->lo[iy * p->W + ix]);
}

long long nuc_occgrid_width(long long h)  { NOCC *p = (NOCC *)(void *)(size_t)h; return p ? (long long)p->W : 0; }
long long nuc_occgrid_height(long long h) { NOCC *p = (NOCC *)(void *)(size_t)h; return p ? (long long)p->H : 0; }
long long nuc_occgrid_cell_size(long long h) { NOCC *p = (NOCC *)(void *)(size_t)h; return p ? _f2i(p->cell_size) : _f2i(0.0); }

void nuc_occgrid_free(long long h) {
    NOCC *p = (NOCC *)(void *)(size_t)h;
    if (!p) return;
    if (p->lo) free(p->lo);
    free(p);
}
