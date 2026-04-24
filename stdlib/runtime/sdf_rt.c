// sdf_rt.c — 2D Signed Distance Field on a regular grid.
//
// Stores a distance field `φ(x, y)` discretized on a `W × H` grid
// with cell size `dx` and world origin `(ox, oy)`. By convention,
// `φ > 0` outside obstacles, `φ < 0` inside, `φ = 0` on the
// boundary.
//
// Queries between cell centers use bilinear interpolation.
// Gradients are computed from the same bilinear field via partial
// derivatives — i.e. piecewise constant within each cell, which is
// fine for steering / repulsion uses.
//
// Foundation for:
//   - Continuous collision queries: `φ(x, y)` ≤ 0 ⇔ inside obstacle.
//   - Repulsive potential fields (`apf.nr`-style): force ∝ −∇φ
//     scaled by some monotone function of `φ`.
//   - Cost-aware planning: feed `φ` into A* / D* Lite as a
//     traversal-cost field that softens around obstacle boundaries.
//   - Distance-aware MPC stage cost to keep the robot away from
//     obstacles.
//
// Setup helpers:
//   `nuc_sdf_set(h, ix, iy, v_b)` — write a single cell.
//   `nuc_sdf_compute_from_circles(h, centers_ptr, radii_ptr, n)` —
//     builds the field from a list of circular obstacles
//     (`centers_ptr` is `double[n][2]`, `radii_ptr` is `double[n]`).
//
// **Limitations** (3D / Eikonal sweep / fast-marching land in v0.6
// if needed):
// - 2D only.
// - `compute_from_circles` is the only built-in "field-from-shapes"
//   helper; for arbitrary geometry the caller fills cells manually
//   or runs Eikonal sweep externally.
// - Bilinear-only (no higher-order interpolation).
//
// Compile: clang -c stdlib/runtime/sdf_rt.c -o target/sdf.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int W, H;
    double dx;
    double ox, oy;
    double *phi;        // W * H, row-major (y * W + x)
} NSDF;

long long nuc_sdf_new(long long W_, long long H_, long long dx_b,
                       long long ox_b, long long oy_b)
{
    int W = (int)W_, H = (int)H_;
    if (W <= 1 || H <= 1) return 0;
    double dx = _i2f(dx_b);
    if (dx <= 0) return 0;
    NSDF *p = (NSDF *)calloc(1, sizeof(NSDF));
    p->W = W; p->H = H;
    p->dx = dx;
    p->ox = _i2f(ox_b);
    p->oy = _i2f(oy_b);
    p->phi = (double *)malloc(W * H * sizeof(double));
    // Default = +∞ (everything is "free space" until populated).
    for (int i = 0; i < W*H; i++) p->phi[i] = 1e18;
    return (long long)(size_t)p;
}

long long nuc_sdf_width(long long h)  { NSDF *p = (NSDF *)(void *)(size_t)h; return p ? (long long)p->W : 0; }
long long nuc_sdf_height(long long h) { NSDF *p = (NSDF *)(void *)(size_t)h; return p ? (long long)p->H : 0; }
long long nuc_sdf_dx(long long h)     { NSDF *p = (NSDF *)(void *)(size_t)h; return p ? _f2i(p->dx) : _f2i(0.0); }

void nuc_sdf_set(long long h, long long ix_, long long iy_, long long v_b) {
    NSDF *p = (NSDF *)(void *)(size_t)h;
    if (!p) return;
    int ix = (int)ix_, iy = (int)iy_;
    if (ix < 0 || ix >= p->W || iy < 0 || iy >= p->H) return;
    p->phi[iy * p->W + ix] = _i2f(v_b);
}
long long nuc_sdf_get(long long h, long long ix_, long long iy_) {
    NSDF *p = (NSDF *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    int ix = (int)ix_, iy = (int)iy_;
    if (ix < 0 || ix >= p->W || iy < 0 || iy >= p->H) return _f2i(0.0);
    return _f2i(p->phi[iy * p->W + ix]);
}

// Bilinear-interpolated distance at world (x, y).
long long nuc_sdf_query(long long h, long long x_b, long long y_b) {
    NSDF *p = (NSDF *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double x = _i2f(x_b), y = _i2f(y_b);
    double fx = (x - p->ox) / p->dx;
    double fy = (y - p->oy) / p->dx;
    int ix = (int)floor(fx);
    int iy = (int)floor(fy);
    double tx = fx - ix;
    double ty = fy - iy;
    if (ix < 0)         { ix = 0; tx = 0; }
    if (ix >= p->W - 1) { ix = p->W - 2; tx = 1; }
    if (iy < 0)         { iy = 0; ty = 0; }
    if (iy >= p->H - 1) { iy = p->H - 2; ty = 1; }
    double v00 = p->phi[(iy  )*p->W + ix  ];
    double v10 = p->phi[(iy  )*p->W + ix+1];
    double v01 = p->phi[(iy+1)*p->W + ix  ];
    double v11 = p->phi[(iy+1)*p->W + ix+1];
    double v0 = v00 * (1.0 - tx) + v10 * tx;
    double v1 = v01 * (1.0 - tx) + v11 * tx;
    return _f2i(v0 * (1.0 - ty) + v1 * ty);
}

// Bilinear-interpolated gradient (∂φ/∂x, ∂φ/∂y) at world (x, y).
// Output written to gx_out_ptr, gy_out_ptr (each a double).
void nuc_sdf_gradient(long long h, long long x_b, long long y_b,
                      long long gx_out_ptr, long long gy_out_ptr)
{
    NSDF *p = (NSDF *)(void *)(size_t)h;
    if (!p) return;
    double x = _i2f(x_b), y = _i2f(y_b);
    double fx = (x - p->ox) / p->dx;
    double fy = (y - p->oy) / p->dx;
    int ix = (int)floor(fx);
    int iy = (int)floor(fy);
    double tx = fx - ix;
    double ty = fy - iy;
    if (ix < 0)         { ix = 0; tx = 0; }
    if (ix >= p->W - 1) { ix = p->W - 2; tx = 1; }
    if (iy < 0)         { iy = 0; ty = 0; }
    if (iy >= p->H - 1) { iy = p->H - 2; ty = 1; }
    double v00 = p->phi[(iy  )*p->W + ix  ];
    double v10 = p->phi[(iy  )*p->W + ix+1];
    double v01 = p->phi[(iy+1)*p->W + ix  ];
    double v11 = p->phi[(iy+1)*p->W + ix+1];
    // ∂φ/∂fx and ∂φ/∂fy of the bilinear surface. Convert from
    // grid-units to world by dividing by dx.
    double dphi_dfx = (1.0 - ty) * (v10 - v00) + ty * (v11 - v01);
    double dphi_dfy = (1.0 - tx) * (v01 - v00) + tx * (v11 - v10);
    double *gx = (double *)(void *)(size_t)gx_out_ptr;
    double *gy = (double *)(void *)(size_t)gy_out_ptr;
    if (gx) *gx = dphi_dfx / p->dx;
    if (gy) *gy = dphi_dfy / p->dx;
}

// Build SDF from a list of circular obstacles. centers_ptr is
// double[n_obs][2] (cx, cy per obstacle); radii_ptr is double[n_obs].
// φ(cell) = min over obstacles of (distance from cell center to
// circle perimeter, signed).
void nuc_sdf_compute_from_circles(long long h, long long centers_ptr,
                                  long long radii_ptr, long long n_obs_)
{
    NSDF *p = (NSDF *)(void *)(size_t)h;
    if (!p) return;
    int n_obs = (int)n_obs_;
    double *centers = (double *)(void *)(size_t)centers_ptr;
    double *radii   = (double *)(void *)(size_t)radii_ptr;
    if (!centers || !radii) return;
    for (int iy = 0; iy < p->H; iy++) {
        double y = p->oy + iy * p->dx;
        for (int ix = 0; ix < p->W; ix++) {
            double x = p->ox + ix * p->dx;
            double best = 1e18;
            for (int k = 0; k < n_obs; k++) {
                double dx = x - centers[k*2 + 0];
                double dy = y - centers[k*2 + 1];
                double d  = sqrt(dx*dx + dy*dy) - radii[k];
                if (d < best) best = d;
            }
            p->phi[iy * p->W + ix] = best;
        }
    }
}

void nuc_sdf_free(long long h) {
    NSDF *p = (NSDF *)(void *)(size_t)h;
    if (!p) return;
    if (p->phi) free(p->phi);
    free(p);
}
