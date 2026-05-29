// klt_rt.c — Lucas-Kanade single-feature tracker.
//
// Given two grayscale images `I1`, `I2` and a feature point `p` in
// `I1`, find the displacement `(dx, dy)` such that
//
//   I1(p + offset) ≈ I2(p + (dx, dy) + offset)
//
// for all `offset` within a window of radius `r` around `p`.
// Iteratively solved via the standard Lucas-Kanade Newton update:
//
//   H · Δ = −b
//   H = [[Σ Ix², Σ Ix·Iy], [Σ Ix·Iy, Σ Iy²]]
//   b = [Σ Ix·It,  Σ Iy·It]
//   It = I2(p + (dx, dy) + offset) − I1(p + offset)
//
// `Ix`, `Iy` are I1 image gradients (computed once on entry; the
// inverse-compositional version of LK uses *I1's* gradients
// throughout the iteration).
//
// Sub-pixel image access uses bilinear interpolation. Image
// boundary handling: replicate (clamp).
//
// Use cases:
//   - Visual-odometry feature flow.
//   - Optical-flow / structure-from-motion pipelines.
//   - Template tracking (one feature per call).
//
// Limitations (multi-scale pyramid / multi-feature parallel
// tracking / SSD residual / orientation tracking land in v0.6 if
// needed):
// - Single feature per call. For dense flow, call once per feature
//   (or once per pyramid level for large displacements).
// - Translation only — no scale / rotation / affine warp.
// - For displacements > a few pixels, build an image pyramid via
//   `imgproc_resize_bilinear` and call this iteratively coarse-
//   to-fine.
//
// Compile: clang -c stdlib/runtime/klt_rt.c -o target/klt.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

static inline int _clamp(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

// Bilinear sample of the grayscale image at fractional (x, y).
// Replicate boundary.
static double _sample(const double *img, int W, int H, double x, double y) {
    int ix = (int)floor(x), iy = (int)floor(y);
    double tx = x - ix, ty = y - iy;
    int ix0 = _clamp(ix,     0, W - 1);
    int ix1 = _clamp(ix + 1, 0, W - 1);
    int iy0 = _clamp(iy,     0, H - 1);
    int iy1 = _clamp(iy + 1, 0, H - 1);
    double v00 = img[iy0*W + ix0];
    double v10 = img[iy0*W + ix1];
    double v01 = img[iy1*W + ix0];
    double v11 = img[iy1*W + ix1];
    double v0 = v00 * (1.0 - tx) + v10 * tx;
    double v1 = v01 * (1.0 - tx) + v11 * tx;
    return v0 * (1.0 - ty) + v1 * ty;
}

// Returns 1 on success, 0 if Hessian is singular at any iter.
// `dx_dy_out` is `double[2]` — initial guess on entry, refined on
// return.
long long nuc_klt_track(long long img1_ptr, long long img2_ptr,
                         long long W_, long long H_,
                         long long fx_b, long long fy_b,
                         long long radius_, long long max_iters_,
                         long long tol_b,
                         long long dx_dy_out_ptr)
{
    int W = (int)W_, H = (int)H_;
    int r = (int)radius_;
    int max_iters = (int)max_iters_;
    if (max_iters <= 0) max_iters = 20;
    if (r < 1) r = 1;
    const double *I1 = (const double *)(void *)(size_t)img1_ptr;
    const double *I2 = (const double *)(void *)(size_t)img2_ptr;
    double *dxdy = (double *)(void *)(size_t)dx_dy_out_ptr;
    if (!I1 || !I2 || !dxdy) return 0;
    double fx = _i2f(fx_b), fy = _i2f(fy_b);
    double tol = _i2f(tol_b);
    if (tol <= 0) tol = 1e-3;

    double dx = dxdy[0], dy = dxdy[1];

    for (int iter = 0; iter < max_iters; iter++) {
        double Hxx = 0, Hxy = 0, Hyy = 0;
        double bx = 0, by = 0;

        for (int oy = -r; oy <= r; oy++) {
            for (int ox = -r; ox <= r; ox++) {
                double sx = fx + ox;
                double sy = fy + oy;

                // I1 gradient via central differences (sub-pixel-accurate).
                double Ix = 0.5 * (_sample(I1, W, H, sx + 1, sy)
                                 - _sample(I1, W, H, sx - 1, sy));
                double Iy = 0.5 * (_sample(I1, W, H, sx, sy + 1)
                                 - _sample(I1, W, H, sx, sy - 1));
                // It = I2(warped) - I1
                double It = _sample(I2, W, H, sx + dx, sy + dy)
                          - _sample(I1, W, H, sx, sy);
                Hxx += Ix * Ix;
                Hxy += Ix * Iy;
                Hyy += Iy * Iy;
                bx  += Ix * It;
                by  += Iy * It;
            }
        }

        double det = Hxx * Hyy - Hxy * Hxy;
        if (fabs(det) < 1e-12) return 0;
        // Δ = -H⁻¹ · b
        double inv_det = 1.0 / det;
        double Δx = -inv_det * ( Hyy * bx - Hxy * by);
        double Δy = -inv_det * (-Hxy * bx + Hxx * by);
        dx += Δx;
        dy += Δy;

        if (fabs(Δx) < tol && fabs(Δy) < tol) break;
    }

    dxdy[0] = dx;
    dxdy[1] = dy;
    return 1;
}
