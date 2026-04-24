// icp_p2p_rt.c — Point-to-plane ICP (Chen & Medioni 1991).
//
// Given a source cloud P (N_src points) and a target cloud Q
// (N_tgt points) with PER-POINT surface NORMALS n_j, point-to-plane
// ICP minimises the sum of squared point-to-tangent-plane distances:
//
//     min Σ ((R·P_i + t − Q_j) · n_j)²,     j = nn(i)
//
// Each residual is the signed distance from the transformed source
// point to the tangent plane of its target neighbour — not the
// point-to-point distance. This is a SMALL-ANGLE linearisation of
// the rigid transform; at each iteration we solve a linear 6×6
// system for (α, β, γ, tx, ty, tz), then apply the corresponding
// transform and iterate.
//
// Typically converges 3-10× faster than point-to-point ICP on
// planar scenes (room walls, floor, CAD models).
//
// Use:
//   - RGBD / LiDAR alignment (e.g. KinectFusion front-end).
//   - CAD-model registration when you have surface normals.
//   - Scan-matching on a surfel map.
//
// **Limitations** (KD-tree NN / symmetric plane-to-plane metric /
// robust kernel land in v0.6 if needed):
// - Brute-force nearest neighbour O(N_src · N_tgt) per iteration.
// - Target normals must be provided by the caller (compute them
//   with `stdlib/rods/normal_estimation.nr` or similar).
// - No outlier rejection — caller should pre-filter or apply a
//   residual-norm gate before each iteration.
// - Small-angle linearisation assumes the source is already
//   approximately aligned (typical ICP precondition).
//
// Compile: clang -c stdlib/runtime/icp_p2p_rt.c -o target/icp_p2p.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

// Solve 6x6 symmetric positive-semidefinite linear system A x = b
// via Gauss elimination with partial pivoting. Returns 1 on
// success, 0 if singular.
static int _solve6(double A[6][6], double b[6], double x[6]) {
    for (int col = 0; col < 6; col++) {
        int piv = col;
        double best = fabs(A[col][col]);
        for (int r = col + 1; r < 6; r++) {
            if (fabs(A[r][col]) > best) { best = fabs(A[r][col]); piv = r; }
        }
        if (best < 1e-15) return 0;
        if (piv != col) {
            for (int c = 0; c < 6; c++) {
                double t = A[col][c]; A[col][c] = A[piv][c]; A[piv][c] = t;
            }
            double t = b[col]; b[col] = b[piv]; b[piv] = t;
        }
        for (int r = col + 1; r < 6; r++) {
            double f = A[r][col] / A[col][col];
            for (int c = col; c < 6; c++) A[r][c] -= f * A[col][c];
            b[r] -= f * b[col];
        }
    }
    // Back-substitute.
    for (int r = 5; r >= 0; r--) {
        double s = b[r];
        for (int c = r + 1; c < 6; c++) s -= A[r][c] * x[c];
        x[r] = s / A[r][r];
    }
    return 1;
}

// Apply small-angle SO(3)×R^3 update to current rotation R and
// translation t.  (α, β, γ) are the axis-angle vector components.
static void _apply_delta(double R[9], double t[3], const double dx[6]) {
    double a = dx[0], b = dx[1], g = dx[2];
    // Small-angle rotation matrix (Rodrigues for small angle):
    // Rδ = I + [δ]× + ½ [δ]×²  (exact for Rodrigues)
    double theta2 = a*a + b*b + g*g;
    double Rd[9];
    if (theta2 < 1e-20) {
        Rd[0]=1; Rd[1]=-g; Rd[2]=b;
        Rd[3]=g; Rd[4]=1; Rd[5]=-a;
        Rd[6]=-b; Rd[7]=a; Rd[8]=1;
    } else {
        double theta = sqrt(theta2);
        double s = sin(theta) / theta;
        double c = (1.0 - cos(theta)) / theta2;
        Rd[0] = 1 + c*(-g*g - b*b);
        Rd[1] = -s*g + c*(a*b);
        Rd[2] =  s*b + c*(a*g);
        Rd[3] =  s*g + c*(a*b);
        Rd[4] = 1 + c*(-g*g - a*a);
        Rd[5] = -s*a + c*(b*g);
        Rd[6] = -s*b + c*(a*g);
        Rd[7] =  s*a + c*(b*g);
        Rd[8] = 1 + c*(-a*a - b*b);
    }
    // R_new = Rd * R
    double Rn[9];
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            double s = 0;
            for (int k = 0; k < 3; k++) s += Rd[i*3+k] * R[k*3+j];
            Rn[i*3+j] = s;
        }
    }
    memcpy(R, Rn, sizeof(Rn));
    // t_new = Rd * t + delta_t
    double tn[3];
    for (int i = 0; i < 3; i++) {
        tn[i] = Rd[i*3+0]*t[0] + Rd[i*3+1]*t[1] + Rd[i*3+2]*t[2] + dx[3+i];
    }
    memcpy(t, tn, sizeof(tn));
}

// Run point-to-plane ICP. Writes final rotation to R_out (double[9],
// row-major) and translation to t_out (double[3]).
// Returns the number of iterations run (iters_max on non-convergence).
long long nuc_icp_p2p(long long src_ptr, long long n_src_,
                       long long tgt_ptr, long long tgt_normals_ptr, long long n_tgt_,
                       long long max_iters_, long long tol_b,
                       long long R_out_ptr, long long t_out_ptr)
{
    int n_src = (int)n_src_, n_tgt = (int)n_tgt_;
    int max_iters = (int)max_iters_;
    double tol = _i2f(tol_b);
    const double *src = (const double *)(void *)(size_t)src_ptr;
    const double *tgt = (const double *)(void *)(size_t)tgt_ptr;
    const double *tgtN = (const double *)(void *)(size_t)tgt_normals_ptr;
    double *R_out = (double *)(void *)(size_t)R_out_ptr;
    double *t_out = (double *)(void *)(size_t)t_out_ptr;
    if (!src || !tgt || !tgtN || !R_out || !t_out) return 0;
    if (n_src < 1 || n_tgt < 1) return 0;

    // Initialise R = I, t = 0 (or could take an initial guess).
    double R[9] = {1,0,0, 0,1,0, 0,0,1};
    double t[3] = {0, 0, 0};

    int iter = 0;
    for (iter = 0; iter < max_iters; iter++) {
        double A[6][6] = {{0}};
        double b[6] = {0};
        // For each source point, find nearest target point (brute force).
        for (int i = 0; i < n_src; i++) {
            double px = src[i*3+0], py = src[i*3+1], pz = src[i*3+2];
            // Transform: p' = R p + t
            double pxr = R[0]*px + R[1]*py + R[2]*pz + t[0];
            double pyr = R[3]*px + R[4]*py + R[5]*pz + t[1];
            double pzr = R[6]*px + R[7]*py + R[8]*pz + t[2];
            // Find nearest target point.
            int best = 0;
            double best_d2 = 1e300;
            for (int j = 0; j < n_tgt; j++) {
                double dx = tgt[j*3+0] - pxr;
                double dy = tgt[j*3+1] - pyr;
                double dz = tgt[j*3+2] - pzr;
                double d2 = dx*dx + dy*dy + dz*dz;
                if (d2 < best_d2) { best_d2 = d2; best = j; }
            }
            // Target normal n and point q.
            double nx = tgtN[best*3+0], ny = tgtN[best*3+1], nz = tgtN[best*3+2];
            double qx = tgt[best*3+0],  qy = tgt[best*3+1],  qz = tgt[best*3+2];
            // Residual: e = (p' - q) . n
            double ex = pxr - qx, ey = pyr - qy, ez = pzr - qz;
            double r = ex * nx + ey * ny + ez * nz;
            // Jacobian row: J = [ (p' × n)^T , n^T ]
            double jx = pyr * nz - pzr * ny;
            double jy = pzr * nx - pxr * nz;
            double jz = pxr * ny - pyr * nx;
            double j_row[6] = { jx, jy, jz, nx, ny, nz };
            // Accumulate A += J^T J, b += J^T (-r)
            for (int u = 0; u < 6; u++) {
                b[u] += -r * j_row[u];
                for (int v = 0; v < 6; v++) A[u][v] += j_row[u] * j_row[v];
            }
        }
        // Solve A dx = b.
        double dx[6];
        // Copy A because _solve6 overwrites.
        double Ac[6][6];
        memcpy(Ac, A, sizeof(Ac));
        if (!_solve6(Ac, b, dx)) break;

        _apply_delta(R, t, dx);

        // Convergence test: |dx|.
        double nrm2 = 0;
        for (int k = 0; k < 6; k++) nrm2 += dx[k] * dx[k];
        if (sqrt(nrm2) < tol) { iter++; break; }
    }

    memcpy(R_out, R, sizeof(R));
    memcpy(t_out, t, sizeof(t));
    return (long long)iter;
}
