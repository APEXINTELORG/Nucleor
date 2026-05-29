// handeye_rt.c — Tsai-Lenz / Park-Martin hand-eye calibration.
//
// Computes the unknown end-effector → camera transform X given a
// sequence of robot motion / camera motion pairs (A, B). The
// classic AX = XB problem in robotics:
//
//   A_i = inv(robot_pose_i) · robot_pose_{i+1}    (between two poses)
//   B_i = inv(camera_pose_i) · camera_pose_{i+1}  (between same two views of a fixed target)
//   X   = transform from end-effector to camera   (unknown)
//
// Foundation for any vision-in-the-loop robot control where the
// camera is mounted on the end-effector — visual servoing, object
// pose estimation, eye-in-hand object tracking. The result X is
// what relates the camera observation frame to the robot's
// kinematic chain.
//
// Algorithm:
//   1. Rotation step (Procrustes / Horn): the AX=XB rotation
//      constraint reduces to R_x · axis(R_b) = axis(R_a) per
//      motion pair. Solve via Horn 1987's quaternion-based
//      closed-form rotation alignment (same machinery as ICP).
//   2. Translation step: with R_x known, AX=XB gives the linear
//      system (R_a − I)·t_x = R_x·t_b − t_a per motion pair.
//      Solve via normal equations, accumulated over all motions.
//
// Limitations (joint rotation+translation optimization
// (Daniilidis 1999 dual quaternion form) lands in v0.6 if needed):
// - Two-step (rotation, then translation). The joint solver
//   couples the two steps and can be marginally more accurate.
// - Requires ≥ 3 motion pairs with non-collinear rotation axes
//   for the Procrustes step to be well-conditioned.
//
// Compile: clang -c stdlib/runtime/handeye_rt.c -o target/handeye.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Rotation-matrix log: extract axis-angle vector (axis × angle).
static void _rot_log(const double *R, double *axis_out) {
    // angle = arccos((trace(R) − 1) / 2); axis from skew part.
    double tr = R[0] + R[4] + R[8];
    double cos_a = 0.5 * (tr - 1.0);
    if (cos_a > 1.0) cos_a = 1.0;
    if (cos_a < -1.0) cos_a = -1.0;
    double angle = acos(cos_a);
    if (fabs(angle) < 1e-9) {
        axis_out[0] = 0; axis_out[1] = 0; axis_out[2] = 0;
        return;
    }
    double s = 2.0 * sin(angle);
    if (fabs(s) < 1e-9) {
        // Angle near π — use the symmetric formulation.
        // R = I + 2·skew(axis)·sin(π/2)·... → fall back to small-axis mode.
        axis_out[0] = (R[7] - R[5]);
        axis_out[1] = (R[2] - R[6]);
        axis_out[2] = (R[3] - R[1]);
        double m = sqrt(axis_out[0]*axis_out[0] + axis_out[1]*axis_out[1] + axis_out[2]*axis_out[2]);
        if (m > 1e-12) {
            axis_out[0] = (axis_out[0] / m) * angle;
            axis_out[1] = (axis_out[1] / m) * angle;
            axis_out[2] = (axis_out[2] / m) * angle;
        }
        return;
    }
    axis_out[0] = (R[7] - R[5]) / s * angle;
    axis_out[1] = (R[2] - R[6]) / s * angle;
    axis_out[2] = (R[3] - R[1]) / s * angle;
}

// Quaternion to rotation matrix (row-major).
static void _quat_to_R(const double *q, double *R) {
    double w = q[0], x = q[1], y = q[2], z = q[3];
    R[0] = 1 - 2*(y*y + z*z);  R[1] = 2*(x*y - w*z);      R[2] = 2*(x*z + w*y);
    R[3] = 2*(x*y + w*z);      R[4] = 1 - 2*(x*x + z*z);  R[5] = 2*(y*z - w*x);
    R[6] = 2*(x*z - w*y);      R[7] = 2*(y*z + w*x);      R[8] = 1 - 2*(x*x + y*y);
}

// 4×4 top-eigenvector via shifted power iteration.
static void _top_eigenvec_4x4(const double *N, double *v_out) {
    double tr = N[0] + N[5] + N[10] + N[15];
    double mu = tr / 4.0;
    double M[16];
    for (int i = 0; i < 16; i++) M[i] = N[i];
    for (int i = 0; i < 4; i++) M[i*4 + i] -= mu;
    double v[4] = {1, 0, 0, 0};
    for (int it = 0; it < 80; it++) {
        double v2[4];
        for (int i = 0; i < 4; i++) {
            v2[i] = M[i*4+0]*v[0] + M[i*4+1]*v[1] + M[i*4+2]*v[2] + M[i*4+3]*v[3];
        }
        double nrm = sqrt(v2[0]*v2[0] + v2[1]*v2[1] + v2[2]*v2[2] + v2[3]*v2[3]);
        if (nrm < 1e-18) break;
        for (int i = 0; i < 4; i++) v[i] = v2[i] / nrm;
    }
    v_out[0] = v[0]; v_out[1] = v[1]; v_out[2] = v[2]; v_out[3] = v[3];
}

// Build the 4×4 N matrix from cross-covariance H (3×3 row-major).
static void _build_N(const double *H, double *N) {
    double Sxx = H[0], Sxy = H[1], Sxz = H[2];
    double Syx = H[3], Syy = H[4], Syz = H[5];
    double Szx = H[6], Szy = H[7], Szz = H[8];
    N[0]  =  Sxx + Syy + Szz;
    N[1]  =  Syz - Szy;
    N[2]  =  Szx - Sxz;
    N[3]  =  Sxy - Syx;
    N[4]  =  Syz - Szy;
    N[5]  =  Sxx - Syy - Szz;
    N[6]  =  Sxy + Syx;
    N[7]  =  Szx + Sxz;
    N[8]  =  Szx - Sxz;
    N[9]  =  Sxy + Syx;
    N[10] = -Sxx + Syy - Szz;
    N[11] =  Syz + Szy;
    N[12] =  Sxy - Syx;
    N[13] =  Szx + Sxz;
    N[14] =  Syz + Szy;
    N[15] = -Sxx - Syy + Szz;
}

// In-place Gauss-Jordan inverse on small n×n.
static int _gj_inv(double *A, int n, double *Ainv) {
    int aug_w = 2 * n;
    double *aug = (double *)malloc((size_t)n * aug_w * sizeof(double));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) aug[i*aug_w + j] = A[i*n + j];
        for (int j = 0; j < n; j++) aug[i*aug_w + n + j] = (i == j) ? 1.0 : 0.0;
    }
    for (int i = 0; i < n; i++) {
        int piv = i;
        for (int r = i + 1; r < n; r++) {
            if (fabs(aug[r*aug_w + i]) > fabs(aug[piv*aug_w + i])) piv = r;
        }
        if (fabs(aug[piv*aug_w + i]) < 1e-12) { free(aug); return 0; }
        if (piv != i) {
            for (int j = 0; j < aug_w; j++) {
                double t = aug[i*aug_w + j];
                aug[i*aug_w + j] = aug[piv*aug_w + j];
                aug[piv*aug_w + j] = t;
            }
        }
        double inv = 1.0 / aug[i*aug_w + i];
        for (int j = 0; j < aug_w; j++) aug[i*aug_w + j] *= inv;
        for (int r = 0; r < n; r++) {
            if (r == i) continue;
            double f = aug[r*aug_w + i];
            for (int j = 0; j < aug_w; j++) aug[r*aug_w + j] -= f * aug[i*aug_w + j];
        }
    }
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) Ainv[i*n + j] = aug[i*aug_w + n + j];
    free(aug);
    return 1;
}

// Hand-eye solver. Returns 0 on success; -1 if not enough motions
// or if the translation system is singular.
long long nuc_handeye_calibrate(
    long long Ra_array_ptr, long long ta_array_ptr,
    long long Rb_array_ptr, long long tb_array_ptr,
    long long n_motions_,
    long long Rx_out_ptr, long long tx_out_ptr)
{
    int N = (int)n_motions_;
    if (N < 3) return -1;
    const double *Ra = (const double *)(void *)(size_t)Ra_array_ptr;
    const double *ta = (const double *)(void *)(size_t)ta_array_ptr;
    const double *Rb = (const double *)(void *)(size_t)Rb_array_ptr;
    const double *tb = (const double *)(void *)(size_t)tb_array_ptr;
    double *Rx = (double *)(void *)(size_t)Rx_out_ptr;
    double *tx = (double *)(void *)(size_t)tx_out_ptr;
    if (!Ra || !ta || !Rb || !tb || !Rx || !tx) return -1;

    // === Rotation step ===
    // Build cross-covariance H = Σ axis(R_b) · axis(R_a)ᵀ, then
    // use Horn quaternion method to recover R_x.
    double H[9] = {0};
    for (int i = 0; i < N; i++) {
        double axis_a[3], axis_b[3];
        _rot_log(Ra + i*9, axis_a);
        _rot_log(Rb + i*9, axis_b);
        for (int r = 0; r < 3; r++)
            for (int c = 0; c < 3; c++)
                H[r*3 + c] += axis_b[r] * axis_a[c];
    }
    double Nmat[16];
    _build_N(H, Nmat);
    double q[4];
    _top_eigenvec_4x4(Nmat, q);
    _quat_to_R(q, Rx);

    // === Translation step ===
    // Per motion: (R_a − I) · t_x = R_x · t_b − t_a.
    // Stack and solve via normal equations: AᵀA · t_x = Aᵀ · b.
    double AtA[9] = {0}, Atb[3] = {0};
    for (int i = 0; i < N; i++) {
        double M[9];
        for (int j = 0; j < 9; j++) M[j] = Ra[i*9 + j];
        M[0] -= 1.0; M[4] -= 1.0; M[8] -= 1.0;
        // RHS: R_x · t_b − t_a.
        double Rxtb[3];
        Rxtb[0] = Rx[0]*tb[i*3+0] + Rx[1]*tb[i*3+1] + Rx[2]*tb[i*3+2];
        Rxtb[1] = Rx[3]*tb[i*3+0] + Rx[4]*tb[i*3+1] + Rx[5]*tb[i*3+2];
        Rxtb[2] = Rx[6]*tb[i*3+0] + Rx[7]*tb[i*3+1] + Rx[8]*tb[i*3+2];
        double b_vec[3] = {
            Rxtb[0] - ta[i*3+0],
            Rxtb[1] - ta[i*3+1],
            Rxtb[2] - ta[i*3+2]
        };
        // Accumulate AᵀA and Aᵀb.
        for (int r = 0; r < 3; r++)
            for (int c = 0; c < 3; c++) {
                double s = 0;
                for (int k = 0; k < 3; k++) s += M[k*3 + r] * M[k*3 + c];
                AtA[r*3 + c] += s;
            }
        for (int r = 0; r < 3; r++) {
            double s = 0;
            for (int k = 0; k < 3; k++) s += M[k*3 + r] * b_vec[k];
            Atb[r] += s;
        }
    }
    double AtA_inv[9];
    if (!_gj_inv(AtA, 3, AtA_inv)) return -1;
    for (int i = 0; i < 3; i++) {
        double s = 0;
        for (int j = 0; j < 3; j++) s += AtA_inv[i*3 + j] * Atb[j];
        tx[i] = s;
    }
    return 0;
}
