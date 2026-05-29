// reach_rt.c — Monte Carlo reachability mapper for arm robots.
//
// Samples N joint configurations uniformly within per-joint bounds,
// runs a user-supplied forward-kinematics callback on each, stores
// the resulting end-effector positions as a workspace cloud.
// Foundation for:
//   - Workspace volume estimation (sample density × cell volume).
//   - Reachable-region queries ("can the end-effector reach this
//     pose at all?").
//   - Manipulability shaping (combine with `kdt.nr` or `sgrid.nr`
//     for spatial queries).
//
// FK callback signature:
//   long long fk(long long joints_ptr, long long ee_xyz_out_ptr);
//   - joints_ptr: double[n_joints]   — joint values to evaluate
//   - ee_xyz_out_ptr: double[3]      — write end-effector (X, Y, Z)
//
// Workflow:
//
//   1. nuc_reach_new(n_joints, n_samples, seed)
//   2. set per-joint bounds via nuc_reach_set_joint_limit
//   3. nuc_reach_compute(h, fk_fp) — runs the sampling
//   4. query: nuc_reach_density_in_sphere, nuc_reach_get_ee,
//             nuc_reach_workspace_extent
//   5. nuc_reach_free(h)
//
// Limitations (joint-limit-aware sampling / non-uniform priors /
// KD-tree-accelerated queries land in v0.6 if needed):
// - Uniform sampling within per-joint bounds (no manifold sampling
//   for closed kinematic chains).
// - Brute-force density query: `O(N)` per query. For many queries,
//   pipe the EE samples through `kdt.nr` or `sgrid.nr` for
//   accelerated lookup.
// - End-effector POSITION only (no orientation). Add a 6-D variant
//   in v0.6 if needed.
//
// Compile: clang -c stdlib/runtime/reach_rt.c -o target/reach.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*reach_fk_fn_t)(long long joints_ptr, long long ee_xyz_out_ptr);

typedef struct {
    int n_joints;
    int n_samples;
    double *lo, *hi;
    double *joints_scratch;       // n_joints
    double *ee;                    // n_samples * 3
    int n_done;                    // = n_samples after compute
    unsigned long long rng;
} NREACH;

static unsigned long long _xs(NREACH *p) {
    unsigned long long x = p->rng;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    if (x == 0) x = 0xdeadbeefdeadbeefULL;
    p->rng = x; return x;
}
static double _rng_unit(NREACH *p) {
    return ((double)(_xs(p) >> 11)) * (1.0 / (double)(1ULL << 53));
}

long long nuc_reach_new(long long n_joints_, long long n_samples_, long long seed) {
    int nj = (int)n_joints_, ns = (int)n_samples_;
    if (nj <= 0 || ns <= 0) return 0;
    NREACH *p = (NREACH *)calloc(1, sizeof(NREACH));
    p->n_joints = nj;
    p->n_samples = ns;
    p->lo = (double *)malloc(nj * sizeof(double));
    p->hi = (double *)malloc(nj * sizeof(double));
    for (int i = 0; i < nj; i++) { p->lo[i] = -3.14159265358979; p->hi[i] = 3.14159265358979; }
    p->joints_scratch = (double *)malloc(nj * sizeof(double));
    p->ee = (double *)calloc(ns * 3, sizeof(double));
    p->rng = (unsigned long long)seed * 6364136223846793005ULL + 1442695040888963407ULL;
    if (p->rng == 0) p->rng = 1;
    return (long long)(size_t)p;
}

void nuc_reach_set_joint_limit(long long h, long long j_, long long lo_b, long long hi_b) {
    NREACH *p = (NREACH *)(void *)(size_t)h;
    if (!p) return;
    int j = (int)j_;
    if (j < 0 || j >= p->n_joints) return;
    double lo = _i2f(lo_b), hi = _i2f(hi_b);
    if (lo > hi) { double t = lo; lo = hi; hi = t; }
    p->lo[j] = lo;
    p->hi[j] = hi;
}

// Run the sampling. Returns the number of samples computed
// (= n_samples on success).
long long nuc_reach_compute(long long h, long long fk_fp) {
    NREACH *p = (NREACH *)(void *)(size_t)h;
    if (!p) return 0;
    reach_fk_fn_t fk = (reach_fk_fn_t)(void *)(size_t)fk_fp;
    if (!fk) return 0;
    for (int s = 0; s < p->n_samples; s++) {
        for (int j = 0; j < p->n_joints; j++) {
            double r = _rng_unit(p);
            p->joints_scratch[j] = p->lo[j] + r * (p->hi[j] - p->lo[j]);
        }
        fk((long long)(size_t)p->joints_scratch,
           (long long)(size_t)(p->ee + s * 3));
    }
    p->n_done = p->n_samples;
    return (long long)p->n_done;
}

long long nuc_reach_count(long long h) {
    NREACH *p = (NREACH *)(void *)(size_t)h;
    return p ? (long long)p->n_done : 0;
}

long long nuc_reach_get_ee(long long h, long long sample_, long long dim_) {
    NREACH *p = (NREACH *)(void *)(size_t)h;
    if (!p || sample_ < 0 || sample_ >= p->n_done || dim_ < 0 || dim_ > 2)
        return _f2i(0.0);
    return _f2i(p->ee[(int)sample_ * 3 + (int)dim_]);
}

// Count samples within a sphere of radius r centered at (x, y, z).
long long nuc_reach_density_in_sphere(long long h, long long x_b, long long y_b,
                                       long long z_b, long long r_b)
{
    NREACH *p = (NREACH *)(void *)(size_t)h;
    if (!p) return 0;
    double x = _i2f(x_b), y = _i2f(y_b), z = _i2f(z_b), r = _i2f(r_b);
    double r2 = r * r;
    long long n = 0;
    for (int s = 0; s < p->n_done; s++) {
        double dx = p->ee[s*3+0] - x;
        double dy = p->ee[s*3+1] - y;
        double dz = p->ee[s*3+2] - z;
        if (dx*dx + dy*dy + dz*dz <= r2) n++;
    }
    return n;
}

// Workspace bounding-box extent on axis (0=x, 1=y, 2=z). Writes
// (min, max) to out_ptr (double[2]).
void nuc_reach_workspace_extent(long long h, long long axis_, long long out_ptr) {
    NREACH *p = (NREACH *)(void *)(size_t)h;
    if (!p || p->n_done == 0) return;
    double *o = (double *)(void *)(size_t)out_ptr;
    if (!o) return;
    int axis = (int)axis_;
    if (axis < 0 || axis > 2) return;
    double mn =  INFINITY, mx = -INFINITY;
    for (int s = 0; s < p->n_done; s++) {
        double v = p->ee[s*3 + axis];
        if (v < mn) mn = v;
        if (v > mx) mx = v;
    }
    o[0] = mn;
    o[1] = mx;
}

void nuc_reach_free(long long h) {
    NREACH *p = (NREACH *)(void *)(size_t)h;
    if (!p) return;
    if (p->lo) free(p->lo);
    if (p->hi) free(p->hi);
    if (p->joints_scratch) free(p->joints_scratch);
    if (p->ee) free(p->ee);
    free(p);
}
