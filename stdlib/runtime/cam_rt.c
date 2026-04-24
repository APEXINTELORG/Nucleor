// cam_rt.c — Pinhole camera with Brown-Conrady (radial-tangential)
// distortion.
//
// Camera intrinsics:
//   K = [[fx,  0, cx],
//        [ 0, fy, cy],
//        [ 0,  0,  1]]
//
// Brown-Conrady distortion (5 parameters):
//   r² = x_n² + y_n²     (normalized image-plane radius²)
//   x_d = x_n · (1 + k₁·r² + k₂·r⁴ + k₃·r⁶)
//        + 2·p₁·x_n·y_n + p₂·(r² + 2·x_n²)
//   y_d = y_n · (1 + k₁·r² + k₂·r⁴ + k₃·r⁶)
//        + p₁·(r² + 2·y_n²) + 2·p₂·x_n·y_n
//
// Camera pose (t, q) is the camera frame in the world (so a world
// point P maps to camera frame as `X_cam = qᵀ · (P − t)`). Same
// convention as `ba.nr`'s bundle-adjustment camera.
//
// Compare to `ba.nr`'s built-in projection — that one is fixed at
// pure pinhole (no distortion) and tied to the BA solver state.
// `cam.nr` is a standalone utility for any camera-using code.
//
// **Limitations** (fish-eye / equidistant / equirectangular
// projections land in v0.6 if needed):
// - Single rectilinear pinhole + Brown-Conrady distortion.
// - `unproject` returns a 3-vec direction in the world frame
//   (parameterized by depth on the way); does NOT iteratively
//   undistort (caller is expected to feed already-rectified pixels
//   when undistorting; full inverse distortion requires an
//   iterative root-find that lands in v0.6).
//
// Compile: clang -c stdlib/runtime/cam_rt.c -o target/cam.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    double fx, fy, cx, cy;
    double k1, k2, k3, p1, p2;
    double t[3];
    double q[4];          // body→world, scalar-first
} NCAM;

static void _q_normalize(double *q) {
    double n = sqrt(q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3]);
    if (n > 1e-12) { q[0]/=n; q[1]/=n; q[2]/=n; q[3]/=n; }
    else { q[0]=1; q[1]=q[2]=q[3]=0; }
}
static void _q_conj(const double *q, double *o) {
    o[0]=q[0]; o[1]=-q[1]; o[2]=-q[2]; o[3]=-q[3];
}
static void _q_rotate(const double *q, const double *v, double *o) {
    double tx = 2.0*(q[2]*v[2] - q[3]*v[1]);
    double ty = 2.0*(q[3]*v[0] - q[1]*v[2]);
    double tz = 2.0*(q[1]*v[1] - q[2]*v[0]);
    o[0] = v[0] + q[0]*tx + (q[2]*tz - q[3]*ty);
    o[1] = v[1] + q[0]*ty + (q[3]*tx - q[1]*tz);
    o[2] = v[2] + q[0]*tz + (q[1]*ty - q[2]*tx);
}

long long nuc_cam_new(long long fx_b, long long fy_b, long long cx_b, long long cy_b) {
    NCAM *p = (NCAM *)calloc(1, sizeof(NCAM));
    p->fx = _i2f(fx_b);
    p->fy = _i2f(fy_b);
    p->cx = _i2f(cx_b);
    p->cy = _i2f(cy_b);
    p->q[0] = 1.0;        // identity orientation
    return (long long)(size_t)p;
}

void nuc_cam_set_distortion(long long h, long long k1_b, long long k2_b, long long k3_b,
                             long long p1_b, long long p2_b)
{
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return;
    p->k1 = _i2f(k1_b);
    p->k2 = _i2f(k2_b);
    p->k3 = _i2f(k3_b);
    p->p1 = _i2f(p1_b);
    p->p2 = _i2f(p2_b);
}

void nuc_cam_set_pose(long long h, long long t_ptr, long long q_ptr) {
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return;
    double *t = (double *)(void *)(size_t)t_ptr;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (t) { p->t[0] = t[0]; p->t[1] = t[1]; p->t[2] = t[2]; }
    if (q) {
        p->q[0] = q[0]; p->q[1] = q[1]; p->q[2] = q[2]; p->q[3] = q[3];
        _q_normalize(p->q);
    }
}

void nuc_cam_intrinsic_matrix(long long h, long long K_out_ptr) {
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return;
    double *K = (double *)(void *)(size_t)K_out_ptr;
    if (!K) return;
    K[0] = p->fx; K[1] = 0;     K[2] = p->cx;
    K[3] = 0;     K[4] = p->fy; K[5] = p->cy;
    K[6] = 0;     K[7] = 0;     K[8] = 1.0;
}

// Project a world point into pixel coordinates. Returns 1 on
// success, 0 if the point is behind the camera (Z ≤ 0). Writes
// (u, v) to uv_out_ptr (double[2]).
long long nuc_cam_project(long long h, long long P_w_ptr, long long uv_out_ptr) {
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return 0;
    double *Pw = (double *)(void *)(size_t)P_w_ptr;
    double *uv = (double *)(void *)(size_t)uv_out_ptr;
    if (!Pw || !uv) return 0;
    double rel[3] = { Pw[0] - p->t[0], Pw[1] - p->t[1], Pw[2] - p->t[2] };
    double q_inv[4]; _q_conj(p->q, q_inv);
    double X[3]; _q_rotate(q_inv, rel, X);
    if (X[2] <= 1e-9) return 0;

    double xn = X[0] / X[2];
    double yn = X[1] / X[2];
    double r2 = xn*xn + yn*yn;
    double r4 = r2 * r2;
    double r6 = r4 * r2;
    double radial = 1.0 + p->k1*r2 + p->k2*r4 + p->k3*r6;
    double xd = xn * radial + 2.0*p->p1*xn*yn + p->p2*(r2 + 2.0*xn*xn);
    double yd = yn * radial + p->p1*(r2 + 2.0*yn*yn) + 2.0*p->p2*xn*yn;

    uv[0] = p->fx * xd + p->cx;
    uv[1] = p->fy * yd + p->cy;
    return 1;
}

// Backproject an undistorted pixel + depth into a world point.
// Caller is responsible for undistortion if the pixel came from a
// distorted image.
void nuc_cam_unproject(long long h, long long u_b, long long v_b, long long depth_b,
                       long long P_out_ptr)
{
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return;
    double *P = (double *)(void *)(size_t)P_out_ptr;
    if (!P) return;
    double u = _i2f(u_b), v = _i2f(v_b), z = _i2f(depth_b);
    double xn = (u - p->cx) / p->fx;
    double yn = (v - p->cy) / p->fy;
    double X_cam[3] = { xn * z, yn * z, z };
    // World point = q · X_cam + t
    double X_w[3]; _q_rotate(p->q, X_cam, X_w);
    P[0] = X_w[0] + p->t[0];
    P[1] = X_w[1] + p->t[1];
    P[2] = X_w[2] + p->t[2];
}

// Apply the distortion model to a normalized image-plane point
// (xn, yn) — handy for testing / pre-warping. Writes (xd, yd) to
// out_ptr (double[2]).
void nuc_cam_distort(long long h, long long xn_b, long long yn_b, long long out_ptr) {
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return;
    double *o = (double *)(void *)(size_t)out_ptr;
    if (!o) return;
    double xn = _i2f(xn_b), yn = _i2f(yn_b);
    double r2 = xn*xn + yn*yn;
    double r4 = r2 * r2;
    double r6 = r4 * r2;
    double radial = 1.0 + p->k1*r2 + p->k2*r4 + p->k3*r6;
    o[0] = xn * radial + 2.0*p->p1*xn*yn + p->p2*(r2 + 2.0*xn*xn);
    o[1] = yn * radial + p->p1*(r2 + 2.0*yn*yn) + 2.0*p->p2*xn*yn;
}

// === Iterative inverse-distortion (v0.2.279) ===
//
// Given a distorted normalized point (x_d, y_d), solve for the
// undistorted normalized point (x_n, y_n) via fixed-point
// iteration (OpenCV-style):
//
//   x_n^{k+1} = (x_d − tangential_x(x_n^k, y_n^k)) / radial(x_n^k, y_n^k)
//   y_n^{k+1} = (y_d − tangential_y(x_n^k, y_n^k)) / radial(x_n^k, y_n^k)
//
// Initialized with x_n = x_d, y_n = y_d. Converges in 5–10 iters
// for moderate distortion. For extreme distortion (fish-eye) use
// a different model (planned for v0.6).
void nuc_cam_undistort_normalized(long long h, long long xd_b, long long yd_b,
                                   long long n_iters_, long long out_ptr)
{
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return;
    double *o = (double *)(void *)(size_t)out_ptr;
    if (!o) return;
    int n_iters = (int)n_iters_;
    if (n_iters <= 0) n_iters = 10;

    double xd = _i2f(xd_b), yd = _i2f(yd_b);
    double xn = xd, yn = yd;
    for (int it = 0; it < n_iters; it++) {
        double r2 = xn * xn + yn * yn;
        double r4 = r2 * r2;
        double r6 = r4 * r2;
        double radial = 1.0 + p->k1*r2 + p->k2*r4 + p->k3*r6;
        if (radial < 1e-9) break;
        double dx_tan = 2.0 * p->p1 * xn * yn + p->p2 * (r2 + 2.0 * xn * xn);
        double dy_tan = p->p1 * (r2 + 2.0 * yn * yn) + 2.0 * p->p2 * xn * yn;
        double xn_new = (xd - dx_tan) / radial;
        double yn_new = (yd - dy_tan) / radial;
        if (fabs(xn_new - xn) < 1e-12 && fabs(yn_new - yn) < 1e-12) {
            xn = xn_new; yn = yn_new;
            break;
        }
        xn = xn_new; yn = yn_new;
    }
    o[0] = xn;
    o[1] = yn;
}

// Convenience: undistort a pixel (u, v) and unproject with depth.
// Iterates the inverse-distortion model on the normalized
// coordinate (`(u − cx)/fx`, `(v − cy)/fy`), then back-projects
// like `nuc_cam_unproject` would.
void nuc_cam_unproject_distorted(long long h, long long u_b, long long v_b,
                                  long long depth_b, long long n_iters_,
                                  long long P_out_ptr)
{
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return;
    double *P = (double *)(void *)(size_t)P_out_ptr;
    if (!P) return;
    double u = _i2f(u_b), v = _i2f(v_b), z = _i2f(depth_b);
    double xd = (u - p->cx) / p->fx;
    double yd = (v - p->cy) / p->fy;
    double und[2];
    nuc_cam_undistort_normalized(h, _f2i(xd), _f2i(yd), n_iters_,
                                  (long long)(size_t)und);
    double X_cam[3] = { und[0] * z, und[1] * z, z };
    double X_w[3]; _q_rotate(p->q, X_cam, X_w);
    P[0] = X_w[0] + p->t[0];
    P[1] = X_w[1] + p->t[1];
    P[2] = X_w[2] + p->t[2];
}

void nuc_cam_free(long long h) {
    NCAM *p = (NCAM *)(void *)(size_t)h;
    if (!p) return;
    free(p);
}
