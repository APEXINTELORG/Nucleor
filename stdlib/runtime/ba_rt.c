// ba_rt.c — Bundle Adjustment (visual SLAM back-end).
//
// Jointly optimizes a set of camera SE(3) poses and a set of 3D
// world points to minimize the sum of squared 2-D reprojection
// errors over a list of (camera, point, pixel) observations.
//
// Camera model: pinhole with shared focal length f and principal
// point (cx, cy). Cameras stored as (t ∈ ℝ³, q ∈ SO(3)) where q is
// a unit quaternion. The camera-frame point is computed as:
//
//   X_cam = R_iᵀ · (X_world − t_i)
//
// (i.e. the camera pose (t, R) is the camera frame in the world;
// world points map into the camera frame by the inverse transform).
// Pinhole projection:
//
//   u_pred = cx + f · X_cam[0] / X_cam[2]
//   v_pred = cy + f · X_cam[1] / X_cam[2]
//
// Residual per observation:
//   r = (u_pred − u_meas, v_pred − v_meas)  ∈ ℝ²
//
// Optimization variables:
//   - 6-DOF SE(3) perturbation per camera (camera 0 is gauge-fixed)
//   - 3-DOF translation per 3D point
//
// Numerical Jacobians via central differences (2 × 9 evaluations per
// observation per iter — 6 cam DOF + 3 point DOF). Linear normal
// equations H · δ = −b solved with dense Gauss-Jordan + small LM
// damping. Camera 0 is fixed to break the global rigid-motion
// ambiguity; for full-scale visual SLAM you'd also fix one point's
// distance to break the scale ambiguity, but for small problems the
// damping handles it implicitly.
//
// **Limitations** (sparse Schur complement, robust kernels,
// per-camera intrinsics, distortion models land in v0.6 if needed):
// - Dense linear solve: O(dof³) where dof = 6·(N_cam − 1) + 3·N_pts.
//   Fine for N_cam ≤ 30 and N_pts ≤ 100. Real visual SLAM uses
//   sparse Schur (separates camera and point blocks) for large maps.
// - Single shared focal length + principal point (per-camera
//   intrinsics + radial distortion land in v0.6 if needed).
// - L₂ cost only — no robust kernels (Huber, Cauchy).
// - Numerical FD Jacobians (closed-form Jacobians + sparsity make
//   real-world BA much faster).
//
// Compile: clang -c stdlib/runtime/ba_rt.c -o target/ba.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int cam_i, pt_j;
    double u_meas, v_meas;
    double info;            // scalar weight (information per pixel)
} _BAObs;

typedef struct {
    int n_cams, n_pts;
    double focal, cx, cy;
    double *cams;           // n_cams × 7  (t[3], q[4])
    double *pts;            // n_pts × 3   (X, Y, Z)
    int n_obs, cap_obs;
    _BAObs *obs;
} NBA;

// === Quaternion helpers ===

static void _q_normalize(double *q) {
    double n = sqrt(q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3]);
    if (n > 1e-12) { q[0]/=n; q[1]/=n; q[2]/=n; q[3]/=n; }
    else { q[0]=1; q[1]=q[2]=q[3]=0; }
}
static void _q_mul(const double *q1, const double *q2, double *qo) {
    qo[0] = q1[0]*q2[0] - q1[1]*q2[1] - q1[2]*q2[2] - q1[3]*q2[3];
    qo[1] = q1[0]*q2[1] + q1[1]*q2[0] + q1[2]*q2[3] - q1[3]*q2[2];
    qo[2] = q1[0]*q2[2] - q1[1]*q2[3] + q1[2]*q2[0] + q1[3]*q2[1];
    qo[3] = q1[0]*q2[3] + q1[1]*q2[2] - q1[2]*q2[1] + q1[3]*q2[0];
}
static void _q_conj(const double *q, double *qo) {
    qo[0]=q[0]; qo[1]=-q[1]; qo[2]=-q[2]; qo[3]=-q[3];
}
static void _q_rotate(const double *q, const double *v, double *vo) {
    double tx = 2.0*(q[2]*v[2] - q[3]*v[1]);
    double ty = 2.0*(q[3]*v[0] - q[1]*v[2]);
    double tz = 2.0*(q[1]*v[1] - q[2]*v[0]);
    vo[0] = v[0] + q[0]*tx + (q[2]*tz - q[3]*ty);
    vo[1] = v[1] + q[0]*ty + (q[3]*tx - q[1]*tz);
    vo[2] = v[2] + q[0]*tz + (q[1]*ty - q[2]*tx);
}
static void _so3_exp(const double *omega, double *q_out) {
    double a = sqrt(omega[0]*omega[0]+omega[1]*omega[1]+omega[2]*omega[2]);
    if (a < 1e-9) {
        q_out[0]=1; q_out[1]=omega[0]*0.5; q_out[2]=omega[1]*0.5; q_out[3]=omega[2]*0.5;
        _q_normalize(q_out); return;
    }
    double ha = a*0.5, sn = sin(ha)/a;
    q_out[0]=cos(ha); q_out[1]=omega[0]*sn; q_out[2]=omega[1]*sn; q_out[3]=omega[2]*sn;
}

// === Linear solver ===
static int _gj_inv(const double *A, int n, double *Ainv) {
    int aug_w = 2*n;
    double *aug = (double *)malloc(n*aug_w*sizeof(double));
    for (int i=0;i<n;i++){
        for (int j=0;j<n;j++) aug[i*aug_w+j] = A[i*n+j];
        for (int j=0;j<n;j++) aug[i*aug_w+n+j] = (i==j)?1.0:0.0;
    }
    for (int i=0;i<n;i++){
        int piv=i;
        for (int r=i+1;r<n;r++) if (fabs(aug[r*aug_w+i])>fabs(aug[piv*aug_w+i])) piv=r;
        if (fabs(aug[piv*aug_w+i])<1e-12){ free(aug); return 0; }
        if (piv!=i){
            for (int j=0;j<aug_w;j++){ double t=aug[i*aug_w+j]; aug[i*aug_w+j]=aug[piv*aug_w+j]; aug[piv*aug_w+j]=t; }
        }
        double inv = 1.0/aug[i*aug_w+i];
        for (int j=0;j<aug_w;j++) aug[i*aug_w+j]*=inv;
        for (int r=0;r<n;r++){
            if (r==i) continue;
            double f = aug[r*aug_w+i];
            for (int j=0;j<aug_w;j++) aug[r*aug_w+j] -= f*aug[i*aug_w+j];
        }
    }
    for (int i=0;i<n;i++) for (int j=0;j<n;j++) Ainv[i*n+j] = aug[i*aug_w+n+j];
    free(aug);
    return 1;
}

// === API ===

long long nuc_ba_new(long long n_cams, long long n_pts,
    long long focal_b, long long cx_b, long long cy_b)
{
    int nc = (int)n_cams, np = (int)n_pts;
    if (nc <= 0 || np <= 0) return 0;
    NBA *p = (NBA *)calloc(1, sizeof(NBA));
    p->n_cams = nc;
    p->n_pts = np;
    p->focal = _i2f(focal_b);
    p->cx = _i2f(cx_b);
    p->cy = _i2f(cy_b);
    p->cams = (double *)calloc(nc*7, sizeof(double));
    for (int i=0;i<nc;i++) p->cams[i*7+3] = 1.0;     // identity quaternion
    p->pts = (double *)calloc(np*3, sizeof(double));
    p->cap_obs = 64;
    p->obs = (_BAObs *)calloc(p->cap_obs, sizeof(_BAObs));
    return (long long)(size_t)p;
}

void nuc_ba_set_cam(long long h, long long i, long long t_ptr, long long q_ptr) {
    NBA *p = (NBA *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n_cams) return;
    double *t = (double *)(void *)(size_t)t_ptr;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (t) { p->cams[i*7+0]=t[0]; p->cams[i*7+1]=t[1]; p->cams[i*7+2]=t[2]; }
    if (q) {
        p->cams[i*7+3]=q[0]; p->cams[i*7+4]=q[1]; p->cams[i*7+5]=q[2]; p->cams[i*7+6]=q[3];
        _q_normalize(p->cams + i*7 + 3);
    }
}

void nuc_ba_get_cam(long long h, long long i, long long t_ptr, long long q_ptr) {
    NBA *p = (NBA *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n_cams) return;
    double *t = (double *)(void *)(size_t)t_ptr;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (t) { t[0]=p->cams[i*7+0]; t[1]=p->cams[i*7+1]; t[2]=p->cams[i*7+2]; }
    if (q) { q[0]=p->cams[i*7+3]; q[1]=p->cams[i*7+4]; q[2]=p->cams[i*7+5]; q[3]=p->cams[i*7+6]; }
}

void nuc_ba_set_pt(long long h, long long j, long long p_ptr) {
    NBA *p = (NBA *)(void *)(size_t)h;
    if (!p || j < 0 || j >= (long long)p->n_pts) return;
    double *pt = (double *)(void *)(size_t)p_ptr;
    if (pt) { p->pts[j*3+0]=pt[0]; p->pts[j*3+1]=pt[1]; p->pts[j*3+2]=pt[2]; }
}

void nuc_ba_get_pt(long long h, long long j, long long p_ptr) {
    NBA *p = (NBA *)(void *)(size_t)h;
    if (!p || j < 0 || j >= (long long)p->n_pts) return;
    double *pt = (double *)(void *)(size_t)p_ptr;
    if (pt) { pt[0]=p->pts[j*3+0]; pt[1]=p->pts[j*3+1]; pt[2]=p->pts[j*3+2]; }
}

long long nuc_ba_add_obs(long long h, long long cam_i, long long pt_j,
    long long u_b, long long v_b, long long info_b)
{
    NBA *p = (NBA *)(void *)(size_t)h;
    if (!p) return -1;
    if (cam_i < 0 || cam_i >= (long long)p->n_cams) return -1;
    if (pt_j  < 0 || pt_j  >= (long long)p->n_pts)  return -1;
    if (p->n_obs >= p->cap_obs) {
        p->cap_obs *= 2;
        p->obs = (_BAObs *)realloc(p->obs, p->cap_obs * sizeof(_BAObs));
    }
    _BAObs *o = &p->obs[p->n_obs];
    o->cam_i = (int)cam_i; o->pt_j = (int)pt_j;
    o->u_meas = _i2f(u_b); o->v_meas = _i2f(v_b);
    double w = _i2f(info_b);
    o->info = (w > 0) ? w : 1.0;
    return (long long)(p->n_obs++);
}

// Projection of world point pw through camera (t, q) into pixel (u, v).
// Returns 0 if behind camera (Z ≤ 0); 1 on success.
static int _project(const double *t_cam, const double *q_cam,
                    const double *pw, double focal, double cx, double cy,
                    double *u, double *v)
{
    double rel[3] = { pw[0]-t_cam[0], pw[1]-t_cam[1], pw[2]-t_cam[2] };
    double q_inv[4]; _q_conj(q_cam, q_inv);
    double X[3]; _q_rotate(q_inv, rel, X);
    if (X[2] <= 1e-9) return 0;
    *u = cx + focal * X[0] / X[2];
    *v = cy + focal * X[1] / X[2];
    return 1;
}

// Compute 2-D residual for an observation given current state.
static int _obs_residual(NBA *p, _BAObs *o, double *r_out) {
    double *t_cam = p->cams + o->cam_i*7;
    double *q_cam = p->cams + o->cam_i*7 + 3;
    double *pw = p->pts + o->pt_j*3;
    double u, v;
    if (!_project(t_cam, q_cam, pw, p->focal, p->cx, p->cy, &u, &v)) {
        r_out[0] = 1e3; r_out[1] = 1e3;        // huge penalty if behind camera
        return 0;
    }
    r_out[0] = u - o->u_meas;
    r_out[1] = v - o->v_meas;
    return 1;
}

// Apply 6-DOF perturbation to a camera in place.
static void _apply_cam_local(double *t, double *q, const double *delta) {
    t[0]+=delta[0]; t[1]+=delta[1]; t[2]+=delta[2];
    double dq[4]; _so3_exp(delta+3, dq);
    double qn[4]; _q_mul(q, dq, qn);
    q[0]=qn[0]; q[1]=qn[1]; q[2]=qn[2]; q[3]=qn[3];
    _q_normalize(q);
}

// Compute residual for an observation when camera i has been
// perturbed by delta (6-DOF). Restores original cam afterwards.
static void _residual_with_cam_perturb(NBA *p, _BAObs *o, const double *delta_cam,
                                       double *r_out)
{
    double *t = p->cams + o->cam_i*7;
    double *q = p->cams + o->cam_i*7 + 3;
    double t_save[3] = {t[0],t[1],t[2]};
    double q_save[4] = {q[0],q[1],q[2],q[3]};
    _apply_cam_local(t, q, delta_cam);
    _obs_residual(p, o, r_out);
    t[0]=t_save[0]; t[1]=t_save[1]; t[2]=t_save[2];
    q[0]=q_save[0]; q[1]=q_save[1]; q[2]=q_save[2]; q[3]=q_save[3];
}

// Compute residual when point j has been perturbed by delta_pt (ℝ³).
static void _residual_with_pt_perturb(NBA *p, _BAObs *o, const double *delta_pt,
                                      double *r_out)
{
    double *pt = p->pts + o->pt_j*3;
    double save[3] = {pt[0], pt[1], pt[2]};
    pt[0]+=delta_pt[0]; pt[1]+=delta_pt[1]; pt[2]+=delta_pt[2];
    _obs_residual(p, o, r_out);
    pt[0]=save[0]; pt[1]=save[1]; pt[2]=save[2];
}

// Numerical Jacobians: J_cam (2×6), J_pt (2×3).
static void _obs_jacobians(NBA *p, _BAObs *o, double *J_cam, double *J_pt) {
    double eps = 1e-6;
    double rp[2], rm[2];
    double d[6];
    // J_cam (only meaningful if cam_i > 0 — caller skips otherwise).
    for (int k = 0; k < 6; k++) {
        for (int kk = 0; kk < 6; kk++) d[kk] = 0;
        d[k] = eps; _residual_with_cam_perturb(p, o, d, rp);
        d[k] = -eps; _residual_with_cam_perturb(p, o, d, rm);
        for (int r = 0; r < 2; r++) J_cam[r*6 + k] = (rp[r] - rm[r]) / (2.0 * eps);
    }
    double dp[3];
    for (int k = 0; k < 3; k++) {
        for (int kk = 0; kk < 3; kk++) dp[kk] = 0;
        dp[k] = eps; _residual_with_pt_perturb(p, o, dp, rp);
        dp[k] = -eps; _residual_with_pt_perturb(p, o, dp, rm);
        for (int r = 0; r < 2; r++) J_pt[r*3 + k] = (rp[r] - rm[r]) / (2.0 * eps);
    }
}

long long nuc_ba_optimize(long long h, long long max_iters, long long tol_b) {
    NBA *p = (NBA *)(void *)(size_t)h;
    if (!p || p->n_cams < 1 || p->n_pts < 1) return -1;
    int N = p->n_cams, M = p->n_pts;
    int dof_cam = 6 * (N - 1);          // cam 0 fixed
    int dof_pt = 3 * M;
    int dof = dof_cam + dof_pt;
    if (dof <= 0) return -1;
    double tol = _i2f(tol_b);

    double *H_mat = (double *)calloc(dof*dof, sizeof(double));
    double *b_vec = (double *)calloc(dof,    sizeof(double));
    double *Hinv  = (double *)malloc(dof*dof*sizeof(double));
    double *delta = (double *)malloc(dof*    sizeof(double));
    double J_cam[12], J_pt[6], r0[2];

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        memset(H_mat, 0, dof*dof*sizeof(double));
        memset(b_vec, 0, dof*sizeof(double));

        for (int o_idx = 0; o_idx < p->n_obs; o_idx++) {
            _BAObs *o = &p->obs[o_idx];
            _obs_residual(p, o, r0);
            _obs_jacobians(p, o, J_cam, J_pt);
            double w = o->info;
            int g_cam = (o->cam_i == 0) ? -1 : 6 * (o->cam_i - 1);
            int g_pt  = dof_cam + 3 * o->pt_j;

            // cam-cam block.
            if (g_cam >= 0) {
                for (int r = 0; r < 6; r++) {
                    for (int c = 0; c < 6; c++) {
                        double s = 0;
                        for (int k = 0; k < 2; k++) s += J_cam[k*6+r] * w * J_cam[k*6+c];
                        H_mat[(g_cam+r)*dof + (g_cam+c)] += s;
                    }
                    double s = 0;
                    for (int k = 0; k < 2; k++) s += J_cam[k*6+r] * w * r0[k];
                    b_vec[g_cam+r] += s;
                }
            }
            // pt-pt block.
            for (int r = 0; r < 3; r++) {
                for (int c = 0; c < 3; c++) {
                    double s = 0;
                    for (int k = 0; k < 2; k++) s += J_pt[k*3+r] * w * J_pt[k*3+c];
                    H_mat[(g_pt+r)*dof + (g_pt+c)] += s;
                }
                double s = 0;
                for (int k = 0; k < 2; k++) s += J_pt[k*3+r] * w * r0[k];
                b_vec[g_pt+r] += s;
            }
            // cam-pt cross blocks.
            if (g_cam >= 0) {
                for (int r = 0; r < 6; r++) {
                    for (int c = 0; c < 3; c++) {
                        double s = 0;
                        for (int k = 0; k < 2; k++) s += J_cam[k*6+r] * w * J_pt[k*3+c];
                        H_mat[(g_cam+r)*dof + (g_pt+c)] += s;
                        H_mat[(g_pt+c)*dof + (g_cam+r)] += s;
                    }
                }
            }
        }

        // LM damping. Heavier on point translations than cameras to
        // help with the unfixed-scale ambiguity in small problems.
        for (int i = 0; i < dof_cam; i++) H_mat[i*dof + i] += 1e-9;
        for (int i = dof_cam; i < dof; i++) H_mat[i*dof + i] += 1e-6;

        if (!_gj_inv(H_mat, dof, Hinv)) break;
        for (int i = 0; i < dof; i++) {
            double s = 0;
            for (int j = 0; j < dof; j++) s += Hinv[i*dof + j] * b_vec[j];
            delta[i] = -s;
        }

        double max_step = 0;
        // Apply camera updates.
        for (int i = 1; i < N; i++) {
            int g = 6 * (i - 1);
            _apply_cam_local(p->cams + i*7, p->cams + i*7 + 3, delta + g);
            for (int k = 0; k < 6; k++) {
                double v = fabs(delta[g+k]);
                if (v > max_step) max_step = v;
            }
        }
        // Apply point updates.
        for (int j = 0; j < M; j++) {
            int g = dof_cam + 3 * j;
            p->pts[j*3+0] += delta[g+0];
            p->pts[j*3+1] += delta[g+1];
            p->pts[j*3+2] += delta[g+2];
            for (int k = 0; k < 3; k++) {
                double v = fabs(delta[g+k]);
                if (v > max_step) max_step = v;
            }
        }
        if (max_step < tol) { iter++; break; }
    }

    free(H_mat); free(b_vec); free(Hinv); free(delta);
    return iter;
}

long long nuc_ba_total_cost(long long h) {
    NBA *p = (NBA *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double total = 0;
    double r[2];
    for (int o_idx = 0; o_idx < p->n_obs; o_idx++) {
        _BAObs *o = &p->obs[o_idx];
        _obs_residual(p, o, r);
        total += o->info * (r[0]*r[0] + r[1]*r[1]);
    }
    return _f2i(total);
}

void nuc_ba_free(long long h) {
    NBA *p = (NBA *)(void *)(size_t)h;
    if (!p) return;
    if (p->cams) free(p->cams);
    if (p->pts) free(p->pts);
    if (p->obs) free(p->obs);
    free(p);
}
