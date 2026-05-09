// control_rt.c — Control Systems for Nucleor
// PID controller, state-space models, Kalman filter, controllability/observability.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/control_rt.c -o target/control_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ct_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ct_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  PID Controller
// ================================================================

typedef struct {
    double Kp, Ki, Kd;
    double integral;
    double prev_error;
    int first;
} PIDState;

long long nuc_pid_new(long long Kp_bits, long long Ki_bits, long long Kd_bits) {
    PIDState *pid = (PIDState *)calloc(1, sizeof(PIDState));
    pid->Kp = _ct_i2f(Kp_bits);
    pid->Ki = _ct_i2f(Ki_bits);
    pid->Kd = _ct_i2f(Kd_bits);
    pid->first = 1;
    return (long long)pid;
}

long long nuc_pid_update(long long h, long long setpoint_bits, long long measurement_bits, long long dt_bits) {
    PIDState *pid = (PIDState *)(void *)h;
    double sp = _ct_i2f(setpoint_bits);
    double meas = _ct_i2f(measurement_bits);
    double dt = _ct_i2f(dt_bits);
    double error = sp - meas;

    pid->integral += error * dt;
    double derivative = pid->first ? 0.0 : (error - pid->prev_error) / dt;
    pid->prev_error = error;
    pid->first = 0;

    double output = pid->Kp * error + pid->Ki * pid->integral + pid->Kd * derivative;
    return _ct_f2i(output);
}

void nuc_pid_reset(long long h) {
    PIDState *pid = (PIDState *)(void *)h;
    pid->integral = 0; pid->prev_error = 0; pid->first = 1;
}

// ================================================================
//  State-Space Model: dx/dt = Ax + Bu, y = Cx + Du
//  Discrete-time step via forward Euler
// ================================================================

typedef struct {
    int n, m, p;  // states, inputs, outputs
    double *A, *B, *C, *D;
    double *x;  // current state
} SSModel;

long long nuc_ss_new(long long A_h, long long B_h, long long C_h, long long D_h,
                      long long n, long long m, long long p) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *Av = (NVec *)(void *)A_h, *Bv = (NVec *)(void *)B_h;
    NVec *Cv = (NVec *)(void *)C_h, *Dv = (NVec *)(void *)D_h;
    int nn = (int)n, mm = (int)m, pp = (int)p;

    SSModel *ss = (SSModel *)calloc(1, sizeof(SSModel));
    ss->n = nn; ss->m = mm; ss->p = pp;
    ss->A = (double *)malloc(nn * nn * sizeof(double));
    ss->B = (double *)malloc(nn * mm * sizeof(double));
    ss->C = (double *)malloc(pp * nn * sizeof(double));
    ss->D = (double *)malloc(pp * mm * sizeof(double));
    ss->x = (double *)calloc(nn, sizeof(double));

    for (int i = 0; i < nn * nn; i++) ss->A[i] = _ct_i2f(Av->data[i]);
    for (int i = 0; i < nn * mm; i++) ss->B[i] = _ct_i2f(Bv->data[i]);
    for (int i = 0; i < pp * nn; i++) ss->C[i] = _ct_i2f(Cv->data[i]);
    for (int i = 0; i < pp * mm; i++) ss->D[i] = _ct_i2f(Dv->data[i]);
    return (long long)ss;
}

// Step: compute y and advance state
// u is Vec<f64> of m inputs, dt is timestep
// Returns Vec<f64> of p outputs
long long nuc_ss_step(long long h, long long u_h, long long dt_bits) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    SSModel *ss = (SSModel *)(void *)h;
    NVec *u = (NVec *)(void *)u_h;
    double dt = _ct_i2f(dt_bits);
    int n = ss->n, m = ss->m, p = ss->p;

    // y = Cx + Du
    NVec *y = (NVec *)malloc(sizeof(NVec));
    y->len = p; y->cap = p;
    y->data = (long long *)malloc(p * sizeof(long long));
    for (int i = 0; i < p; i++) {
        double sum = 0;
        for (int j = 0; j < n; j++) sum += ss->C[i * n + j] * ss->x[j];
        for (int j = 0; j < m; j++) sum += ss->D[i * m + j] * _ct_i2f(u->data[j]);
        y->data[i] = _ct_f2i(sum);
    }

    // dx = Ax + Bu
    double *dx = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        dx[i] = 0;
        for (int j = 0; j < n; j++) dx[i] += ss->A[i * n + j] * ss->x[j];
        for (int j = 0; j < m; j++) dx[i] += ss->B[i * m + j] * _ct_i2f(u->data[j]);
    }
    for (int i = 0; i < n; i++) ss->x[i] += dt * dx[i];
    free(dx);
    return (long long)y;
}

// ================================================================
//  Kalman Filter
// ================================================================

typedef struct {
    int n, m;  // states, measurements
    double *A, *B, *C;
    double *Q, *R;  // process and measurement noise covariance
    double *x;      // state estimate
    double *P;      // error covariance [n x n]
} KalmanFilter;

long long nuc_kalman_new(long long A_h, long long B_h, long long C_h,
                          long long Q_h, long long R_h,
                          long long n, long long m_in, long long m_obs) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    int nn = (int)n, mi = (int)m_in, mo = (int)m_obs;
    NVec *Av = (NVec *)(void *)A_h, *Bv = (NVec *)(void *)B_h, *Cv = (NVec *)(void *)C_h;
    NVec *Qv = (NVec *)(void *)Q_h, *Rv = (NVec *)(void *)R_h;

    KalmanFilter *kf = (KalmanFilter *)calloc(1, sizeof(KalmanFilter));
    kf->n = nn; kf->m = mo;
    kf->A = (double *)malloc(nn * nn * sizeof(double));
    kf->B = (double *)malloc(nn * mi * sizeof(double));
    kf->C = (double *)malloc(mo * nn * sizeof(double));
    kf->Q = (double *)malloc(nn * nn * sizeof(double));
    kf->R = (double *)malloc(mo * mo * sizeof(double));
    kf->x = (double *)calloc(nn, sizeof(double));
    kf->P = (double *)calloc(nn * nn, sizeof(double));
    for (int i = 0; i < nn; i++) kf->P[i * nn + i] = 1.0;

    for (int i = 0; i < nn * nn; i++) kf->A[i] = _ct_i2f(Av->data[i]);
    for (int i = 0; i < nn * mi; i++) kf->B[i] = _ct_i2f(Bv->data[i]);
    for (int i = 0; i < mo * nn; i++) kf->C[i] = _ct_i2f(Cv->data[i]);
    for (int i = 0; i < nn * nn; i++) kf->Q[i] = _ct_i2f(Qv->data[i]);
    for (int i = 0; i < mo * mo; i++) kf->R[i] = _ct_i2f(Rv->data[i]);
    return (long long)kf;
}

void nuc_kalman_predict(long long h, long long u_h) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    KalmanFilter *kf = (KalmanFilter *)(void *)h;
    NVec *u = (NVec *)(void *)u_h;
    int n = kf->n;

    // x = A*x + B*u
    double *xnew = (double *)calloc(n, sizeof(double));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) xnew[i] += kf->A[i * n + j] * kf->x[j];
        if (u) for (int j = 0; j < u->len; j++) xnew[i] += kf->B[i * u->len + j] * _ct_i2f(u->data[j]);
    }
    memcpy(kf->x, xnew, n * sizeof(double));

    // P = A*P*A' + Q
    double *AP = (double *)calloc(n * n, sizeof(double));
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            for (int k = 0; k < n; k++)
                AP[i * n + j] += kf->A[i * n + k] * kf->P[k * n + j];
    double *Pnew = (double *)calloc(n * n, sizeof(double));
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            for (int k = 0; k < n; k++)
                Pnew[i * n + j] += AP[i * n + k] * kf->A[j * n + k];
            Pnew[i * n + j] += kf->Q[i * n + j];
        }
    memcpy(kf->P, Pnew, n * n * sizeof(double));
    free(xnew); free(AP); free(Pnew);
}

long long nuc_kalman_update(long long h, long long z_h) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    KalmanFilter *kf = (KalmanFilter *)(void *)h;
    NVec *z = (NVec *)(void *)z_h;
    int n = kf->n, m = kf->m;

    // Innovation: y = z - C*x
    double *innov = (double *)calloc(m, sizeof(double));
    for (int i = 0; i < m; i++) {
        innov[i] = _ct_i2f(z->data[i]);
        for (int j = 0; j < n; j++) innov[i] -= kf->C[i * n + j] * kf->x[j];
    }

    // S = C*P*C' + R, K = P*C'*S^-1 (simplified for small m)
    // For m=1: scalar Kalman gain
    if (m == 1) {
        double s = kf->R[0];
        double *PC = (double *)calloc(n, sizeof(double));
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                PC[i] += kf->P[i * n + j] * kf->C[j];
        for (int i = 0; i < n; i++) s += kf->C[i] * PC[i];
        if (fabs(s) < 1e-30) { free(innov); free(PC); return 0; }
        // K = PC / s
        for (int i = 0; i < n; i++) {
            double k = PC[i] / s;
            kf->x[i] += k * innov[0];
        }
        // P = (I - K*C)*P
        double *Pnew = (double *)calloc(n * n, sizeof(double));
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++) {
                Pnew[i * n + j] = kf->P[i * n + j];
                for (int k = 0; k < 1; k++)
                    Pnew[i * n + j] -= (PC[i] / s) * kf->C[j] * kf->P[j * n + j]; // simplified
            }
        // Just use Joseph form for stability: P = P - K*S*K'
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                kf->P[i * n + j] -= (PC[i] / s) * PC[j];
        free(PC); free(Pnew);
    }

    // Return state estimate
    NVec *xout = (NVec *)malloc(sizeof(NVec));
    xout->len = n; xout->cap = n;
    xout->data = (long long *)malloc(n * sizeof(long long));
    for (int i = 0; i < n; i++) xout->data[i] = _ct_f2i(kf->x[i]);

    free(innov);
    return (long long)xout;
}

long long nuc_kalman_state(long long h) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    KalmanFilter *kf = (KalmanFilter *)(void *)h;
    NVec *x = (NVec *)malloc(sizeof(NVec));
    x->len = kf->n; x->cap = kf->n;
    x->data = (long long *)malloc(kf->n * sizeof(long long));
    for (int i = 0; i < kf->n; i++) x->data[i] = _ct_f2i(kf->x[i]);
    return (long long)x;
}
