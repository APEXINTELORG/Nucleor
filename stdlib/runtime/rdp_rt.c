// rdp_rt.c — Ramer-Douglas-Peucker polyline simplification.
//
// Given an N-point polyline in D-dimensional space, returns a
// simplified polyline containing a subset of the original points
// such that no dropped point is farther than `ε` from the
// piecewise-linear approximation formed by the kept points.
//
// Classic recursive algorithm:
//   simplify(lo, hi, ε, keep):
//     if hi − lo ≤ 1: return        (adjacent endpoints, nothing between)
//     find the point in (lo, hi) with max perpendicular distance to
//     the line segment from points[lo] to points[hi]
//     if max_dist ≤ ε: return       (drop all interior points)
//     else:
//       keep[argmax] = 1
//       simplify(lo, argmax, ε, keep)
//       simplify(argmax, hi, ε, keep)
//
// Endpoints are always kept. Works for any dimensionality: the
// perpendicular distance from a point p to the segment a–b in N-D
// is computed via projection onto the segment direction.
//
// Use cases:
//   - GPS / odometry trace compaction.
//   - Path simplification after RRT / A* (removes redundant
//     collinear waypoints for a cleaner executor-facing trajectory).
//   - 2D / 3D polyline rendering LOD.
//
// **Limitations** (Visvalingam-Whyatt / curvature-aware simplification
// land in v0.6 if needed):
// - Distance metric is Euclidean perpendicular-to-segment only.
// - Recursion depth up to `N` in the worst case (caller should
//   keep N reasonable — tens of thousands is fine on modern stacks).
//
// Compile: clang -c stdlib/runtime/rdp_rt.c -o target/rdp.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Perpendicular distance² from point p to segment a–b (both N-D).
static double _dist2_to_segment(const double *p, const double *a, const double *b, int dim) {
    double ab2 = 0, ap_dot_ab = 0;
    for (int k = 0; k < dim; k++) {
        double ab = b[k] - a[k];
        double ap = p[k] - a[k];
        ab2 += ab * ab;
        ap_dot_ab += ap * ab;
    }
    if (ab2 < 1e-18) {
        // a == b; distance is just |p − a|.
        double s = 0;
        for (int k = 0; k < dim; k++) {
            double d = p[k] - a[k];
            s += d * d;
        }
        return s;
    }
    double t = ap_dot_ab / ab2;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    double s = 0;
    for (int k = 0; k < dim; k++) {
        double q = a[k] + t * (b[k] - a[k]);
        double d = p[k] - q;
        s += d * d;
    }
    return s;
}

// Iterative RDP using an explicit stack to avoid C recursion
// depth issues with long polylines.
typedef struct { int lo, hi; } _RDPFrame;

// Simplify polyline. `keep_out_ptr` is `i64[n]`; on return,
// `keep[i] = 1` for kept points, `0` for dropped. Returns the
// kept-point count.
long long nuc_rdp_simplify(long long pts_ptr, long long n_, long long dim_,
                            long long epsilon_b, long long keep_out_ptr)
{
    int n = (int)n_, dim = (int)dim_;
    if (n <= 0 || dim <= 0) return 0;
    const double *pts = (const double *)(void *)(size_t)pts_ptr;
    long long *keep = (long long *)(void *)(size_t)keep_out_ptr;
    if (!pts || !keep) return 0;
    double eps = _i2f(epsilon_b);
    if (eps < 0) eps = 0;
    double eps2 = eps * eps;

    for (int i = 0; i < n; i++) keep[i] = 0;
    keep[0] = 1;
    keep[n - 1] = 1;
    if (n <= 2) return 2;

    int stack_cap = n + 16;
    _RDPFrame *stack = (_RDPFrame *)malloc(stack_cap * sizeof(_RDPFrame));
    int sp = 0;
    stack[sp++] = (_RDPFrame){ 0, n - 1 };

    while (sp > 0) {
        _RDPFrame f = stack[--sp];
        int lo = f.lo, hi = f.hi;
        if (hi - lo <= 1) continue;
        // Find point in (lo, hi) with max perpendicular distance².
        double max_d2 = 0;
        int argmax = -1;
        for (int i = lo + 1; i < hi; i++) {
            double d2 = _dist2_to_segment(pts + i*dim, pts + lo*dim, pts + hi*dim, dim);
            if (d2 > max_d2) { max_d2 = d2; argmax = i; }
        }
        if (argmax < 0 || max_d2 <= eps2) continue;
        keep[argmax] = 1;
        if (sp + 2 >= stack_cap) {
            stack_cap = stack_cap * 2 + 16;
            stack = (_RDPFrame *)realloc(stack, stack_cap * sizeof(_RDPFrame));
        }
        stack[sp++] = (_RDPFrame){ lo, argmax };
        stack[sp++] = (_RDPFrame){ argmax, hi };
    }

    long long count = 0;
    for (int i = 0; i < n; i++) if (keep[i]) count++;
    free(stack);
    return count;
}
