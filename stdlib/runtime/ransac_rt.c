// ransac_rt.c — RANSAC outlier-robust geometric fitting.
//
// RANSAC (RANdom SAmple Consensus, Fischler & Bolles 1981) is the
// standard outlier-robust fitting algorithm in robotics
// perception:
//
//   1. Repeatedly sample the minimum number of points needed to
//      fit a model (3 for a plane, 2 for a line, etc.).
//   2. Fit the model to those samples.
//   3. Count "inliers" — points within a distance threshold of
//      the fitted model.
//   4. Keep the model with the most inliers.
//   5. Refit the final model to all the best inliers.
//
// This module ships the most common single instantiation: 3D
// plane fitting. Use cases:
// - LiDAR ground-plane detection (segment ground from obstacles).
// - Depth-scan surface fitting (table tops, walls).
// - Point-cloud preprocessing for ICP (filter outliers first).
//
// **Limitations** (generic-callback RANSAC for line/sphere/transform
// fitting + adaptive trial-count via inlier ratio land in v0.6 if
// needed):
// - 3D plane only (other shapes can be added similarly).
// - Fixed trial count (no early termination via inlier-fraction
//   estimate).
// - Final refit uses unweighted least squares on all inliers; no
//   M-estimator iterative reweighting.
//
// Compile: clang -c stdlib/runtime/ransac_rt.c -o target/ransac.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// xorshift32 RNG.
static unsigned int _rs_xs32(unsigned int *st) {
    unsigned int x = *st;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    *st = x;
    return x;
}

// Plane defined by 3 points: returns 1 on success (writes
// (nx, ny, nz, d) with n unit and plane: n·p + d = 0).
// Returns 0 if the three points are collinear.
static int _plane_from_3pts(const double *p0, const double *p1, const double *p2,
                            double *plane_out)
{
    double e1[3] = { p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2] };
    double e2[3] = { p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2] };
    double n[3];
    n[0] = e1[1]*e2[2] - e1[2]*e2[1];
    n[1] = e1[2]*e2[0] - e1[0]*e2[2];
    n[2] = e1[0]*e2[1] - e1[1]*e2[0];
    double mag = sqrt(n[0]*n[0] + n[1]*n[1] + n[2]*n[2]);
    if (mag < 1e-12) return 0;
    n[0] /= mag; n[1] /= mag; n[2] /= mag;
    plane_out[0] = n[0];
    plane_out[1] = n[1];
    plane_out[2] = n[2];
    plane_out[3] = -(n[0]*p0[0] + n[1]*p0[1] + n[2]*p0[2]);
    return 1;
}

static double _pt_to_plane_dist(const double *p, const double *plane) {
    return fabs(plane[0]*p[0] + plane[1]*p[1] + plane[2]*p[2] + plane[3]);
}

// Refit plane to all inliers via PCA: centroid + smallest-eigenvalue
// eigenvector of the covariance matrix is the plane normal. Uses
// Jacobi rotations on the 3×3 covariance matrix.
static void _jacobi_3x3(double A[3][3], double V[3][3], double evals[3]) {
    // Initialize V to identity.
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) V[i][j] = (i == j) ? 1.0 : 0.0;
    for (int sweep = 0; sweep < 50; sweep++) {
        // Find largest off-diagonal element.
        int p = 0, q = 1;
        double best = fabs(A[0][1]);
        if (fabs(A[0][2]) > best) { best = fabs(A[0][2]); p = 0; q = 2; }
        if (fabs(A[1][2]) > best) { best = fabs(A[1][2]); p = 1; q = 2; }
        if (best < 1e-14) break;
        double a_pp = A[p][p], a_qq = A[q][q], a_pq = A[p][q];
        double theta = (a_qq - a_pp) / (2.0 * a_pq);
        double t = (theta > 0)
            ?  1.0 / ( theta + sqrt(1.0 + theta*theta))
            : -1.0 / (-theta + sqrt(1.0 + theta*theta));
        double c = 1.0 / sqrt(1.0 + t*t);
        double s = t * c;
        // Rotate A.
        A[p][p] = a_pp - t * a_pq;
        A[q][q] = a_qq + t * a_pq;
        A[p][q] = 0; A[q][p] = 0;
        for (int i = 0; i < 3; i++) {
            if (i == p || i == q) continue;
            double a_ip = A[i][p], a_iq = A[i][q];
            A[i][p] = c * a_ip - s * a_iq; A[p][i] = A[i][p];
            A[i][q] = s * a_ip + c * a_iq; A[q][i] = A[i][q];
        }
        for (int i = 0; i < 3; i++) {
            double v_ip = V[i][p], v_iq = V[i][q];
            V[i][p] = c * v_ip - s * v_iq;
            V[i][q] = s * v_ip + c * v_iq;
        }
    }
    evals[0] = A[0][0]; evals[1] = A[1][1]; evals[2] = A[2][2];
}

static void _refit_plane(const double *pts, const int *inliers, int n_in,
                         double *plane_out)
{
    double cx = 0, cy = 0, cz = 0;
    for (int i = 0; i < n_in; i++) {
        cx += pts[inliers[i]*3+0];
        cy += pts[inliers[i]*3+1];
        cz += pts[inliers[i]*3+2];
    }
    cx /= n_in; cy /= n_in; cz /= n_in;
    double C[3][3] = {{0,0,0},{0,0,0},{0,0,0}};
    for (int i = 0; i < n_in; i++) {
        double dx = pts[inliers[i]*3+0] - cx;
        double dy = pts[inliers[i]*3+1] - cy;
        double dz = pts[inliers[i]*3+2] - cz;
        C[0][0] += dx*dx; C[0][1] += dx*dy; C[0][2] += dx*dz;
        C[1][1] += dy*dy; C[1][2] += dy*dz;
        C[2][2] += dz*dz;
    }
    C[1][0] = C[0][1]; C[2][0] = C[0][2]; C[2][1] = C[1][2];
    double V[3][3], ev[3];
    _jacobi_3x3(C, V, ev);
    // Smallest eigenvalue's eigenvector is the plane normal.
    int min_i = 0;
    if (ev[1] < ev[min_i]) min_i = 1;
    if (ev[2] < ev[min_i]) min_i = 2;
    double n[3] = { V[0][min_i], V[1][min_i], V[2][min_i] };
    double mag = sqrt(n[0]*n[0] + n[1]*n[1] + n[2]*n[2]);
    if (mag > 1e-12) { n[0] /= mag; n[1] /= mag; n[2] /= mag; }
    plane_out[0] = n[0]; plane_out[1] = n[1]; plane_out[2] = n[2];
    plane_out[3] = -(n[0]*cx + n[1]*cy + n[2]*cz);
}

// RANSAC 3D plane fit. `pts_ptr` is `double[n_pts * 3]`. Returns 0
// on success (writes (nx, ny, nz, d) to plane_out_ptr; writes inlier
// count to inlier_count_out_ptr); -1 on bad input.
long long nuc_ransac_plane_3d(
    long long pts_ptr, long long n_pts_,
    long long n_trials_,
    long long inlier_thresh_b,
    long long seed,
    long long plane_out_ptr,
    long long inlier_count_out_ptr)
{
    int n_pts = (int)n_pts_;
    int n_trials = (int)n_trials_;
    if (n_pts < 3 || n_trials <= 0) return -1;
    const double *pts = (const double *)(void *)(size_t)pts_ptr;
    double *plane_out = (double *)(void *)(size_t)plane_out_ptr;
    long long *count_out = (long long *)(void *)(size_t)inlier_count_out_ptr;
    if (!pts || !plane_out) return -1;
    double thresh = _i2f(inlier_thresh_b);

    unsigned int st = (unsigned int)seed;
    if (st == 0) st = 0x9E3779B9u;

    double best_plane[4] = {0, 0, 1, 0};
    int best_count = 0;
    int *inliers = (int *)malloc(n_pts * sizeof(int));
    int *best_inliers = (int *)malloc(n_pts * sizeof(int));

    for (int t = 0; t < n_trials; t++) {
        // Sample 3 distinct random indices.
        int i0 = _rs_xs32(&st) % n_pts;
        int i1 = _rs_xs32(&st) % n_pts;
        int i2 = _rs_xs32(&st) % n_pts;
        if (i1 == i0) i1 = (i1 + 1) % n_pts;
        if (i2 == i0) i2 = (i2 + 1) % n_pts;
        if (i2 == i1) i2 = (i2 + 1) % n_pts;
        if (i2 == i0) continue;  // gave up — try next trial
        double plane[4];
        if (!_plane_from_3pts(pts + i0*3, pts + i1*3, pts + i2*3, plane)) continue;
        // Count inliers.
        int n_in = 0;
        for (int k = 0; k < n_pts; k++) {
            if (_pt_to_plane_dist(pts + k*3, plane) <= thresh) {
                inliers[n_in++] = k;
            }
        }
        if (n_in > best_count) {
            best_count = n_in;
            best_plane[0] = plane[0]; best_plane[1] = plane[1];
            best_plane[2] = plane[2]; best_plane[3] = plane[3];
            memcpy(best_inliers, inliers, n_in * sizeof(int));
        }
    }

    // Refit on best inliers via PCA.
    if (best_count >= 3) {
        _refit_plane(pts, best_inliers, best_count, best_plane);
    }

    plane_out[0] = best_plane[0];
    plane_out[1] = best_plane[1];
    plane_out[2] = best_plane[2];
    plane_out[3] = best_plane[3];
    if (count_out) *count_out = (long long)best_count;
    free(inliers); free(best_inliers);
    return 0;
}
