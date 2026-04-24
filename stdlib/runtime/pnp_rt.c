// pnp_rt.c — Perspective-n-Point: camera pose from known 3D points
// + their image projections.
//
// Given N known 3D points X_i in world frame and their observed 2D
// pixel projections u_i, plus the camera intrinsics K, find the
// camera pose (R, t) such that K(R·X_i + t) projects to u_i (after
// perspective division).
//
// Foundation for:
// - Object pose estimation against a known CAD-model point cloud.
// - Visual odometry front-end (track 3D landmarks across frames).
// - AR markers / fiducials (estimate camera pose from corner pixels).
// - Hand-eye calibration target tracking.
//
// Algorithm: iterative Gauss-Newton on reprojection error.
// Pose is parameterized as (R, t); each iteration solves for an
// SE(3) increment (δω, δt) that minimizes Σ ‖uᵢ − π(K·(R·Xᵢ + t))‖².
//
// Update rule:
//   R ← exp(δω) · R       (left-perturbed rotation update)
//   t ← exp(δω) · t + δt
// where exp(δω) is the small-angle Rodrigues approximation for
// stability (full Rodrigues for big steps).
//
// **Limitations** (closed-form EPnP / P3P initialization, RANSAC-
// based outlier rejection land in v0.6 if needed):
// - Iterative-only — no closed-form initialization. Caller must
//   supply a reasonable initial guess (or use identity pose; for
//   typical visual servoing setups this converges within 5-10 iters).
// - No outlier rejection — caller pre-filters via RANSAC if the
//   point correspondences are noisy.
// - Pinhole intrinsics only (no distortion model).
//
// Compile: clang -c stdlib/runtime/pnp_rt.c -o target/pnp.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// 6×6 Gauss-Jordan inverse.
static int _gj_inv_6(double *A, double *Ainv) {
    double aug[6][12];
    for (int i = 0; i < 6; i++) {
        for (int j = 0; j < 6; j++) aug[i][j] = A[i*6 + j];
        for (int j = 0; j < 6; j++) aug[i][6 + j] = (i == j) ? 1.0 : 0.0;
    }
    for (int i = 0; i < 6; i++) {
        int piv = i;
        for (int r = i + 1; r < 6; r++) {
            if (fabs(aug[r][i]) > fabs(aug[piv][i])) piv = r;
        }
        if (fabs(aug[piv][i]) < 1e-14) return 0;
        if (piv != i) {
            for (int j = 0; j < 12; j++) {
                double t = aug[i][j]; aug[i][j] = aug[piv][j]; aug[piv][j] = t;
            }
        }
        double inv = 1.0 / aug[i][i];
        for (int j = 0; j < 12; j++) aug[i][j] *= inv;
        for (int r = 0; r < 6; r++) {
            if (r == i) continue;
            double f = aug[r][i];
            for (int j = 0; j < 12; j++) aug[r][j] -= f * aug[i][j];
        }
    }
    for (int i = 0; i < 6; i++)
        for (int j = 0; j < 6; j++) Ainv[i*6 + j] = aug[i][6 + j];
    return 1;
}

// Rodrigues: axis-angle (3-vec) → 3×3 rotation matrix.
static void _rodrigues(const double *r, double *R) {
    double th = sqrt(r[0]*r[0] + r[1]*r[1] + r[2]*r[2]);
    if (th < 1e-12) {
        R[0]=1; R[1]=0; R[2]=0; R[3]=0; R[4]=1; R[5]=0; R[6]=0; R[7]=0; R[8]=1;
        return;
    }
    double kx = r[0]/th, ky = r[1]/th, kz = r[2]/th;
    double c = cos(th), s = sin(th), C = 1 - c;
    R[0] = c + kx*kx*C;       R[1] = kx*ky*C - kz*s;  R[2] = kx*kz*C + ky*s;
    R[3] = ky*kx*C + kz*s;    R[4] = c + ky*ky*C;     R[5] = ky*kz*C - kx*s;
    R[6] = kz*kx*C - ky*s;    R[7] = kz*ky*C + kx*s;  R[8] = c + kz*kz*C;
}

static void _mat3_mul(const double *A, const double *B, double *C) {
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) {
            C[i*3+j] = A[i*3+0]*B[0*3+j] + A[i*3+1]*B[1*3+j] + A[i*3+2]*B[2*3+j];
        }
}
static void _mat3_vec(const double *A, const double *v, double *out) {
    out[0] = A[0]*v[0] + A[1]*v[1] + A[2]*v[2];
    out[1] = A[3]*v[0] + A[4]*v[1] + A[5]*v[2];
    out[2] = A[6]*v[0] + A[7]*v[1] + A[8]*v[2];
}

// PnP iterative solver. `R_inout` (double[9] row-major) and
// `t_inout` (double[3]) hold initial guess on entry, refined on
// exit. Returns iterations performed; -1 on bad input.
long long nuc_pnp_solve(
    long long pts3d_ptr,         // double[N*3]
    long long pts2d_ptr,         // double[N*2]
    long long n_pts_,
    long long fx_b, long long fy_b,
    long long cx_b, long long cy_b,
    long long max_iters_,
    long long R_inout_ptr, long long t_inout_ptr)
{
    int N = (int)n_pts_;
    int max_iters = (int)max_iters_;
    if (N < 3 || max_iters <= 0) return -1;
    const double *X = (const double *)(void *)(size_t)pts3d_ptr;
    const double *u = (const double *)(void *)(size_t)pts2d_ptr;
    double *R = (double *)(void *)(size_t)R_inout_ptr;
    double *t = (double *)(void *)(size_t)t_inout_ptr;
    if (!X || !u || !R || !t) return -1;
    double fx = _i2f(fx_b), fy = _i2f(fy_b);
    double cx = _i2f(cx_b), cy = _i2f(cy_b);

    double *J = (double *)malloc(2 * N * 6 * sizeof(double));
    double *r_vec = (double *)malloc(2 * N * sizeof(double));

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        // Build residuals + Jacobian.
        for (int i = 0; i < N; i++) {
            // X_cam = R · X_world + t
            double Xc[3];
            _mat3_vec(R, X + i*3, Xc);
            Xc[0] += t[0]; Xc[1] += t[1]; Xc[2] += t[2];
            if (Xc[2] < 1e-9) {
                // Behind camera; set to small positive to avoid div-by-zero.
                Xc[2] = 1e-9;
            }
            double iz = 1.0 / Xc[2];
            double xn = Xc[0] * iz;
            double yn = Xc[1] * iz;
            double u_pred = fx * xn + cx;
            double v_pred = fy * yn + cy;
            // Residual: predicted − observed.
            r_vec[i*2 + 0] = u_pred - u[i*2 + 0];
            r_vec[i*2 + 1] = v_pred - u[i*2 + 1];
            // Jacobian wrt (δω, δt) (6 DOF). For left-perturbed pose
            // x_cam_new = exp(δω)·x_cam + δt, we have:
            //   ∂x_cam/∂δω = -[x_cam]_×   (skew-symmetric of x_cam)
            //   ∂x_cam/∂δt = I
            // ∂(u, v)/∂x_cam (2×3):
            //   [fx/z       0      -fx·x/z²]
            //   [  0       fy/z    -fy·y/z²]
            // Combine: ∂(u,v)/∂(δω, δt) = ∂(u,v)/∂x_cam · [∂x_cam/∂δω | I]
            double Pu[3] = { fx * iz,       0,         -fx * Xc[0] * iz * iz };
            double Pv[3] = { 0,             fy * iz,   -fy * Xc[1] * iz * iz };
            // ∂x_cam/∂δω = -[Xc]_×:
            //   row 0 (∂Xc[0]/∂δω): -[0, -Xc[2], Xc[1]]·δω = [0, Xc[2], -Xc[1]]
            //   row 1: [-Xc[2], 0, Xc[0]]
            //   row 2: [Xc[1], -Xc[0], 0]
            double dXc_dom[3][3] = {
                {  0,        Xc[2],   -Xc[1] },
                { -Xc[2],    0,        Xc[0] },
                {  Xc[1],   -Xc[0],    0     }
            };
            // J row for u-residual: Pu · [dXc_dom | I_3]
            for (int j = 0; j < 3; j++) {
                double s = 0;
                for (int k = 0; k < 3; k++) s += Pu[k] * dXc_dom[k][j];
                J[(i*2+0)*6 + j] = s;
            }
            J[(i*2+0)*6 + 3] = Pu[0];   // δt_x
            J[(i*2+0)*6 + 4] = Pu[1];   // δt_y
            J[(i*2+0)*6 + 5] = Pu[2];   // δt_z
            // J row for v-residual.
            for (int j = 0; j < 3; j++) {
                double s = 0;
                for (int k = 0; k < 3; k++) s += Pv[k] * dXc_dom[k][j];
                J[(i*2+1)*6 + j] = s;
            }
            J[(i*2+1)*6 + 3] = Pv[0];
            J[(i*2+1)*6 + 4] = Pv[1];
            J[(i*2+1)*6 + 5] = Pv[2];
        }

        // Normal equations: H · δξ = -b where H = JᵀJ + λI, b = Jᵀr.
        double H[36] = {0}, b[6] = {0};
        for (int i = 0; i < 6; i++)
            for (int j = 0; j < 6; j++) {
                double s = 0;
                for (int k = 0; k < 2*N; k++) s += J[k*6 + i] * J[k*6 + j];
                H[i*6 + j] = s + (i == j ? 1e-9 : 0);
            }
        for (int i = 0; i < 6; i++) {
            double s = 0;
            for (int k = 0; k < 2*N; k++) s += J[k*6 + i] * r_vec[k];
            b[i] = s;
        }
        double Hinv[36];
        if (!_gj_inv_6(H, Hinv)) break;
        double dxi[6];
        for (int i = 0; i < 6; i++) {
            double s = 0;
            for (int j = 0; j < 6; j++) s += Hinv[i*6 + j] * b[j];
            dxi[i] = -s;
        }

        // Apply update: R ← exp(δω) · R; t ← exp(δω) · t + δt.
        double dR[9];
        _rodrigues(dxi, dR);   // δω = dxi[0..2]
        double R_new[9], t_rot[3];
        _mat3_mul(dR, R, R_new);
        _mat3_vec(dR, t, t_rot);
        for (int i = 0; i < 9; i++) R[i] = R_new[i];
        t[0] = t_rot[0] + dxi[3];
        t[1] = t_rot[1] + dxi[4];
        t[2] = t_rot[2] + dxi[5];
        // Convergence: small step.
        double mag2 = 0;
        for (int i = 0; i < 6; i++) mag2 += dxi[i] * dxi[i];
        if (mag2 < 1e-18) { iter++; break; }
    }

    free(J); free(r_vec);
    return iter;
}

// Reprojection RMS error after applying (R, t).
long long nuc_pnp_reprojection_rms(
    long long pts3d_ptr, long long pts2d_ptr, long long n_pts_,
    long long fx_b, long long fy_b, long long cx_b, long long cy_b,
    long long R_ptr, long long t_ptr)
{
    int N = (int)n_pts_;
    if (N <= 0) return _f2i(0.0);
    const double *X = (const double *)(void *)(size_t)pts3d_ptr;
    const double *u = (const double *)(void *)(size_t)pts2d_ptr;
    const double *R = (const double *)(void *)(size_t)R_ptr;
    const double *t = (const double *)(void *)(size_t)t_ptr;
    double fx = _i2f(fx_b), fy = _i2f(fy_b);
    double cx = _i2f(cx_b), cy = _i2f(cy_b);
    double sse = 0;
    int n_ok = 0;
    for (int i = 0; i < N; i++) {
        double Xc[3];
        _mat3_vec(R, X + i*3, Xc);
        Xc[0] += t[0]; Xc[1] += t[1]; Xc[2] += t[2];
        if (Xc[2] < 1e-9) continue;
        double up = fx * Xc[0] / Xc[2] + cx;
        double vp = fy * Xc[1] / Xc[2] + cy;
        double du = up - u[i*2 + 0];
        double dv = vp - u[i*2 + 1];
        sse += du*du + dv*dv;
        n_ok++;
    }
    if (n_ok == 0) return _f2i(0.0);
    return _f2i(sqrt(sse / n_ok));
}
