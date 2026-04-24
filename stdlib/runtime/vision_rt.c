// vision_rt.c — Camera-projection primitives for robotics vision.
//
// Standard pinhole model:
//
//     X_cam   = R · X_world + t
//     [u·s]                          [X_cam.x]
//     [v·s]   = K · X_cam   where K = [fx 0 cx]
//     [s  ]                          [0 fy cy]
//                                     [0  0  1]
//     u, v   = (u·s, v·s) / s        (pixel coords)
//
// Foundation for hand-eye calibration, image-based visual
// servoing (v0.2.225), object pose estimation, and any vision-in-
// the-loop control. Pinhole is the default camera model in robotics
// (real lenses add distortion that's typically pre-undistorted by
// the camera driver before the points reach this layer).
//
// Compile: clang -c stdlib/runtime/vision_rt.c -o target/vision.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Build a 3×3 intrinsics matrix (row-major) into a caller-allocated
// 9-double buffer. Standard pinhole layout: K[0]=fx, K[2]=cx,
// K[4]=fy, K[5]=cy, K[8]=1, others zero.
long long nuc_cam_intrinsics_set(long long K_ptr,
    long long fx_b, long long fy_b, long long cx_b, long long cy_b)
{
    double *K = (double *)(void *)(size_t)K_ptr;
    if (!K) return -1;
    for (int i = 0; i < 9; i++) K[i] = 0;
    K[0] = _i2f(fx_b);
    K[2] = _i2f(cx_b);
    K[4] = _i2f(fy_b);
    K[5] = _i2f(cy_b);
    K[8] = 1.0;
    return 0;
}

// Project a single 3D world point to pixel coordinates via the
// pinhole model. Returns 1 on success (point in front of camera),
// 0 if the point is behind (z ≤ 0). Writes (u, v) to uv_out_ptr.
long long nuc_cam_project(long long K_ptr,
    long long R_ptr, long long t_ptr,
    long long X_ptr, long long uv_out_ptr)
{
    const double *K = (const double *)(void *)(size_t)K_ptr;
    const double *R = (const double *)(void *)(size_t)R_ptr;
    const double *t = (const double *)(void *)(size_t)t_ptr;
    const double *X = (const double *)(void *)(size_t)X_ptr;
    double *uv = (double *)(void *)(size_t)uv_out_ptr;
    if (!K || !R || !t || !X || !uv) return 0;

    // X_cam = R·X_world + t.
    double Xc[3];
    Xc[0] = R[0]*X[0] + R[1]*X[1] + R[2]*X[2] + t[0];
    Xc[1] = R[3]*X[0] + R[4]*X[1] + R[5]*X[2] + t[1];
    Xc[2] = R[6]*X[0] + R[7]*X[1] + R[8]*X[2] + t[2];
    if (Xc[2] <= 1e-9) return 0;
    // Normalized image plane.
    double xn = Xc[0] / Xc[2];
    double yn = Xc[1] / Xc[2];
    // Apply intrinsics.
    uv[0] = K[0]*xn + K[2];
    uv[1] = K[4]*yn + K[5];
    return 1;
}

// Batch project N 3D points. Skips (writes NaN) for points behind
// the camera. `X_ptr` is a `double[N*3]` world-frame point array;
// `uv_out_ptr` is a `double[N*2]` output buffer.
long long nuc_cam_project_batch(long long K_ptr,
    long long R_ptr, long long t_ptr,
    long long X_ptr, long long N_,
    long long uv_out_ptr)
{
    int N = (int)N_;
    if (N <= 0) return 0;
    const double *X = (const double *)(void *)(size_t)X_ptr;
    double *uv = (double *)(void *)(size_t)uv_out_ptr;
    if (!X || !uv) return 0;
    long long ok = 0;
    double pt[3], px[2];
    for (int i = 0; i < N; i++) {
        pt[0] = X[i*3+0]; pt[1] = X[i*3+1]; pt[2] = X[i*3+2];
        long long s = nuc_cam_project(K_ptr, R_ptr, t_ptr,
            (long long)(size_t)pt, (long long)(size_t)px);
        if (s) {
            uv[i*2+0] = px[0]; uv[i*2+1] = px[1];
            ok++;
        } else {
            uv[i*2+0] = NAN; uv[i*2+1] = NAN;
        }
    }
    return ok;
}

// Image (interaction) Jacobian for a feature point at normalized
// image coordinates (x, y) and depth Z (camera frame). Returns the
// 2×6 matrix L (row-major) such that
//
//     [ẋ; ẏ] = L · v_cam,   v_cam = (vx, vy, vz, ωx, ωy, ωz)
//
// per Chaumette & Hutchinson 2006. Used by image-based visual
// servoing (v0.2.225).
//
//     L = [ -1/Z    0    x/Z    xy   -(1+x²)    y   ]
//         [   0  -1/Z   y/Z   1+y²    -xy     -x   ]
//
// Note: (x, y) here are *normalized* image coordinates (pixel u,v
// after subtracting principal point and dividing by focal length),
// not raw pixel coordinates.
long long nuc_cam_image_jacobian(
    long long x_b, long long y_b, long long Z_b,
    long long L_out_ptr)
{
    double x = _i2f(x_b), y = _i2f(y_b), Z = _i2f(Z_b);
    double *L = (double *)(void *)(size_t)L_out_ptr;
    if (!L || Z <= 1e-9) return -1;
    double iZ = 1.0 / Z;
    L[0] = -iZ;     L[1] =  0;     L[2] =  x * iZ;
    L[3] =  x * y;  L[4] = -(1 + x*x); L[5] = y;
    L[6] =  0;      L[7] = -iZ;    L[8] =  y * iZ;
    L[9] = 1 + y*y; L[10] = -x*y;  L[11] = -x;
    return 0;
}

// === Image-based visual servoing (v0.2.225) =============================
//
// Standard IBVS control law (Chaumette & Hutchinson 2006). Given
// k feature points observed in the current image (s_current) and
// their desired image positions (s_desired), compute the camera-
// frame Cartesian velocity v_cam = (vx, vy, vz, ωx, ωy, ωz) that
// drives s_current → s_desired:
//
//     v_cam = −λ · L⁺ · (s_current − s_desired)
//
// where L is the 2k × 6 stacked image Jacobian and L⁺ is the
// damped-least-squares pseudoinverse `(LᵀL + δ²I)⁻¹·Lᵀ`. The
// caller-supplied depths Z[] estimate the per-feature scene depth
// in the camera frame; these can come from a stereo pair, RGBD
// sensor, or model-based depth predictor.
//
// The output `v_cam` is the world-frame Cartesian velocity the
// camera should achieve. To translate to joint commands, multiply
// by the robot Jacobian's pseudoinverse: `qd = J_robot⁺ · v_cam`
// (using the existing IK damped pseudoinverse). For an eye-in-hand
// configuration where the camera is mounted on the end-effector,
// also compose with the end-effector → camera transform.
//
// **Limitations**:
// - Point features only (line-feature L_s and pose-feature L_s
//   variants land in v0.6 if needed).
// - User must supply per-feature depth (no monocular depth
//   estimation).
// - Constant damping (no adaptive λ).

// Inline 6×6 Gauss-Jordan inverse. Returns 1 on success, 0 if singular.
static int _gj_inv_6x6(const double *A, double *Ainv) {
    double aug[6][12];
    for (int i = 0; i < 6; i++) {
        for (int j = 0; j < 6; j++) aug[i][j] = A[i*6 + j];
        for (int j = 0; j < 6; j++) aug[i][6 + j] = (i == j) ? 1.0 : 0.0;
    }
    for (int i = 0; i < 6; i++) {
        int piv = i;
        for (int r = i + 1; r < 6; r++) {
            double a1 = aug[r][i]; if (a1 < 0) a1 = -a1;
            double a2 = aug[piv][i]; if (a2 < 0) a2 = -a2;
            if (a1 > a2) piv = r;
        }
        double pa = aug[piv][i]; if (pa < 0) pa = -pa;
        if (pa < 1e-12) return 0;
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

long long nuc_ibvs_velocity(
    long long s_current_ptr, long long s_desired_ptr,
    long long Z_ptr, long long n_features_,
    long long fx_b, long long fy_b, long long cx_b, long long cy_b,
    long long lambda_b, long long damping_b,
    long long v_cam_out_ptr)
{
    int n = (int)n_features_;
    if (n <= 0) return -1;
    const double *sc = (const double *)(void *)(size_t)s_current_ptr;
    const double *sd = (const double *)(void *)(size_t)s_desired_ptr;
    const double *Z  = (const double *)(void *)(size_t)Z_ptr;
    double *v_cam = (double *)(void *)(size_t)v_cam_out_ptr;
    if (!sc || !sd || !Z || !v_cam) return -1;
    double fx = _i2f(fx_b), fy = _i2f(fy_b);
    double cx = _i2f(cx_b), cy = _i2f(cy_b);
    double lambda = _i2f(lambda_b);
    double delta = _i2f(damping_b);
    double delta2 = delta * delta;

    // Build stacked image Jacobian L (2n × 6) and error e (2n).
    double *L = (double *)malloc(2 * n * 6 * sizeof(double));
    double *e = (double *)malloc(2 * n * sizeof(double));
    for (int i = 0; i < n; i++) {
        // Convert current and desired pixel coords to normalized.
        double xc_n = (sc[i*2+0] - cx) / fx;
        double yc_n = (sc[i*2+1] - cy) / fy;
        double xd_n = (sd[i*2+0] - cx) / fx;
        double yd_n = (sd[i*2+1] - cy) / fy;
        e[i*2+0] = xc_n - xd_n;
        e[i*2+1] = yc_n - yd_n;
        // Image Jacobian at the CURRENT feature's normalized coords
        // and depth.
        double Zi = Z[i];
        if (Zi <= 1e-9) { free(L); free(e); return -1; }
        double iZ = 1.0 / Zi;
        // Row 2i: -1/Z, 0, x/Z, xy, -(1+x²), y
        L[(2*i+0)*6 + 0] = -iZ;
        L[(2*i+0)*6 + 1] =  0;
        L[(2*i+0)*6 + 2] =  xc_n * iZ;
        L[(2*i+0)*6 + 3] =  xc_n * yc_n;
        L[(2*i+0)*6 + 4] = -(1 + xc_n*xc_n);
        L[(2*i+0)*6 + 5] =  yc_n;
        // Row 2i+1: 0, -1/Z, y/Z, 1+y², -xy, -x
        L[(2*i+1)*6 + 0] =  0;
        L[(2*i+1)*6 + 1] = -iZ;
        L[(2*i+1)*6 + 2] =  yc_n * iZ;
        L[(2*i+1)*6 + 3] =  1 + yc_n*yc_n;
        L[(2*i+1)*6 + 4] = -xc_n*yc_n;
        L[(2*i+1)*6 + 5] = -xc_n;
    }

    // Damped pseudoinverse: L⁺ = (LᵀL + δ²I)⁻¹·Lᵀ.
    // Compute LᵀL  (6×6).
    double LtL[36];
    for (int r = 0; r < 6; r++)
        for (int c = 0; c < 6; c++) {
            double s = 0;
            for (int k = 0; k < 2*n; k++) s += L[k*6 + r] * L[k*6 + c];
            LtL[r*6 + c] = s + (r == c ? delta2 : 0);
        }
    double LtL_inv[36];
    if (!_gj_inv_6x6(LtL, LtL_inv)) { free(L); free(e); return -1; }
    // L⁺ = LtL_inv · Lᵀ  (6 × 2n).
    // v_cam = -λ · L⁺ · e  (length 6).
    for (int i = 0; i < 6; i++) {
        double s = 0;
        for (int j = 0; j < 6; j++) {
            double row_j = 0;
            for (int k = 0; k < 2*n; k++) row_j += L[k*6 + j] * e[k];
            s += LtL_inv[i*6 + j] * row_j;
        }
        v_cam[i] = -lambda * s;
    }

    free(L); free(e);
    return 0;
}
