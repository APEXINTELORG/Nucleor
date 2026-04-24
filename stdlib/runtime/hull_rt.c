// hull_rt.c — 2D convex hull via Andrew's monotone chain.
//
// Given N 2D points, compute the convex hull as an ordered
// sequence of indices into the input array (counter-clockwise).
//
// Algorithm (Andrew 1979): O(N log N).
//   1. Sort points by x (ties broken by y).
//   2. Build the LOWER hull by left-to-right scan, popping any
//      vertex that doesn't make a left turn with the current edge.
//   3. Build the UPPER hull by right-to-left scan, same rule.
//   4. Concatenate (lower + upper, excluding the duplicate
//      endpoints).
//
// Foundation for:
// - Grasp wrench space construction (convex hull of contact-
//   force generators).
// - Object bounding-shape extraction from depth scans.
// - Collision broad-phase precomputation (replace mesh with hull
//   for cheaper queries).
//
// Compile: clang -c stdlib/runtime/hull_rt.c -o target/hull.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Cross-product sign for orientation of (O, A, B): > 0 if CCW.
static double _cross_o(const double *pts, int o, int a, int b) {
    double ox = pts[o*2+0], oy = pts[o*2+1];
    double ax = pts[a*2+0] - ox, ay = pts[a*2+1] - oy;
    double bx = pts[b*2+0] - ox, by = pts[b*2+1] - oy;
    return ax * by - ay * bx;
}

// Pre-sort comparator: by x ascending, then y ascending.
static const double *_g_pts;
static int _cmp_xy(const void *aa, const void *bb) {
    int a = *(const int *)aa, b = *(const int *)bb;
    double ax = _g_pts[a*2+0], ay = _g_pts[a*2+1];
    double bx = _g_pts[b*2+0], by = _g_pts[b*2+1];
    if (ax < bx) return -1;
    if (ax > bx) return  1;
    if (ay < by) return -1;
    if (ay > by) return  1;
    return 0;
}

// Compute the 2D convex hull of `pts_ptr` (double[n_pts * 2]).
// Writes the hull point indices into `hull_out_indices_ptr`
// (caller-allocated int buffer of at least n_pts entries; written
// in CCW order). Returns the number of hull points; -1 on bad
// input.
long long nuc_hull_2d(long long pts_ptr, long long n_pts_,
                     long long hull_out_indices_ptr)
{
    int n = (int)n_pts_;
    if (n < 1) return -1;
    const double *pts = (const double *)(void *)(size_t)pts_ptr;
    int *out = (int *)(void *)(size_t)hull_out_indices_ptr;
    if (!pts || !out) return -1;

    if (n == 1) { out[0] = 0; return 1; }
    if (n == 2) { out[0] = 0; out[1] = 1; return 2; }

    // Sort indices by (x, y).
    int *idx = (int *)malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) idx[i] = i;
    _g_pts = pts;
    qsort(idx, n, sizeof(int), _cmp_xy);

    // Build lower + upper hulls (max 2n indices total).
    int *hull = (int *)malloc(2 * n * sizeof(int));
    int k = 0;

    // Lower hull (left to right).
    for (int i = 0; i < n; i++) {
        while (k >= 2 && _cross_o(pts, hull[k-2], hull[k-1], idx[i]) <= 0) k--;
        hull[k++] = idx[i];
    }
    // Upper hull (right to left).
    int t = k + 1;
    for (int i = n - 2; i >= 0; i--) {
        while (k >= t && _cross_o(pts, hull[k-2], hull[k-1], idx[i]) <= 0) k--;
        hull[k++] = idx[i];
    }
    int n_hull = k - 1;     // last point is the start point repeated
    for (int i = 0; i < n_hull; i++) out[i] = hull[i];

    free(idx); free(hull);
    return (long long)n_hull;
}

// Convex-hull area (positive scalar). Uses the shoelace formula
// over the hull vertices.
long long nuc_hull_2d_area(long long pts_ptr, long long n_pts_,
                          long long hull_indices_ptr, long long n_hull_)
{
    int n_hull = (int)n_hull_;
    if (n_hull < 3) return _f2i(0.0);
    const double *pts = (const double *)(void *)(size_t)pts_ptr;
    const int *idx = (const int *)(void *)(size_t)hull_indices_ptr;
    double s = 0;
    for (int i = 0; i < n_hull; i++) {
        int j = (i + 1) % n_hull;
        s += pts[idx[i]*2+0] * pts[idx[j]*2+1];
        s -= pts[idx[j]*2+0] * pts[idx[i]*2+1];
        (void)n_pts_;
    }
    return _f2i(0.5 * fabs(s));
}
