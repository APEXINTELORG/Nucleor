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
