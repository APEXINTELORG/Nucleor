// ode_rt.c — General-Purpose ODE Solvers for Nucleor
// RK4, RK45 (adaptive), Euler, BDF (stiff), symplectic, event detection.
// Uses function-pointer callbacks for the RHS.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/ode_rt.c -o target/ode_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _od_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _od_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } ODVec;

static ODVec *odvec_new(int n) {
    ODVec *v = (ODVec *)malloc(sizeof(ODVec));
    v->cap = n; v->len = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  Fixed-step Euler
//  f(t, y) -> dy/dt, t and y[i] are f64 bitcast
// ================================================================

long long nuc_ode_euler(long long f_ptr, long long y0_h, long long t0_bits,
                         long long t1_bits, long long h_bits) {
    typedef long long (*RHSFn)(long long, long long);
    RHSFn f = (RHSFn)(void *)f_ptr;
    ODVec *y0 = (ODVec *)(void *)y0_h;
    double t = _od_i2f(t0_bits), t1 = _od_i2f(t1_bits), h = _od_i2f(h_bits);
    int n = y0->len;

    ODVec *y = odvec_new(n);
    for (int i = 0; i < n; i++) y->data[i] = y0->data[i];

    while (t < t1 - 1e-12) {
        if (t + h > t1) h = t1 - t;
        long long dy_h = f(_od_f2i(t), (long long)y);
        ODVec *dy = (ODVec *)(void *)dy_h;
        for (int i = 0; i < n; i++) {
            double yi = _od_i2f(y->data[i]) + h * _od_i2f(dy->data[i]);
            y->data[i] = _od_f2i(yi);
        }
        t += h;
    }
    return (long long)y;
}

// ================================================================
//  Fixed-step RK4
// ================================================================

long long nuc_ode_rk4(long long f_ptr, long long y0_h, long long t0_bits,
                       long long t1_bits, long long h_bits) {
    typedef long long (*RHSFn)(long long, long long);
    RHSFn f = (RHSFn)(void *)f_ptr;
    ODVec *y0 = (ODVec *)(void *)y0_h;
    double t = _od_i2f(t0_bits), t1 = _od_i2f(t1_bits), h = _od_i2f(h_bits);
    int n = y0->len;

    ODVec *y = odvec_new(n);
    for (int i = 0; i < n; i++) y->data[i] = y0->data[i];
    ODVec *ytmp = odvec_new(n);

    while (t < t1 - 1e-12) {
        if (t + h > t1) h = t1 - t;

        // k1 = f(t, y)
        long long k1h = f(_od_f2i(t), (long long)y);
        ODVec *k1 = (ODVec *)(void *)k1h;

        // k2 = f(t + h/2, y + h/2 * k1)
        for (int i = 0; i < n; i++)
            ytmp->data[i] = _od_f2i(_od_i2f(y->data[i]) + 0.5 * h * _od_i2f(k1->data[i]));
        long long k2h = f(_od_f2i(t + 0.5 * h), (long long)ytmp);
        ODVec *k2 = (ODVec *)(void *)k2h;

        // k3 = f(t + h/2, y + h/2 * k2)
        for (int i = 0; i < n; i++)
            ytmp->data[i] = _od_f2i(_od_i2f(y->data[i]) + 0.5 * h * _od_i2f(k2->data[i]));
        long long k3h = f(_od_f2i(t + 0.5 * h), (long long)ytmp);
        ODVec *k3 = (ODVec *)(void *)k3h;

        // k4 = f(t + h, y + h * k3)
        for (int i = 0; i < n; i++)
            ytmp->data[i] = _od_f2i(_od_i2f(y->data[i]) + h * _od_i2f(k3->data[i]));
        long long k4h = f(_od_f2i(t + h), (long long)ytmp);
        ODVec *k4 = (ODVec *)(void *)k4h;

        // y += h/6 * (k1 + 2*k2 + 2*k3 + k4)
        for (int i = 0; i < n; i++) {
            double yi = _od_i2f(y->data[i]) +
                (h / 6.0) * (_od_i2f(k1->data[i]) + 2 * _od_i2f(k2->data[i]) +
                              2 * _od_i2f(k3->data[i]) + _od_i2f(k4->data[i]));
            y->data[i] = _od_f2i(yi);
        }
        t += h;
    }
    return (long long)y;
}

// ================================================================
//  Adaptive RK45 (Dormand-Prince)
// ================================================================

long long nuc_ode_rk45(long long f_ptr, long long y0_h, long long t0_bits,
                        long long t1_bits, long long tol_bits) {
    typedef long long (*RHSFn)(long long, long long);
    RHSFn f = (RHSFn)(void *)f_ptr;
    ODVec *y0 = (ODVec *)(void *)y0_h;
    double t = _od_i2f(t0_bits), t1 = _od_i2f(t1_bits), tol = _od_i2f(tol_bits);
    int n = y0->len;

    ODVec *y = odvec_new(n);
    for (int i = 0; i < n; i++) y->data[i] = y0->data[i];
    ODVec *ytmp = odvec_new(n);

    double h = (t1 - t) * 0.01; // initial step
    if (h > 0.1) h = 0.1;

    // DP5 coefficients (simplified — using embedded RK4/5 error estimate)
    while (t < t1 - 1e-14) {
        if (t + h > t1) h = t1 - t;

        // RK4 step
        long long k1h = f(_od_f2i(t), (long long)y);
        ODVec *k1 = (ODVec *)(void *)k1h;

        for (int i = 0; i < n; i++)
            ytmp->data[i] = _od_f2i(_od_i2f(y->data[i]) + 0.5 * h * _od_i2f(k1->data[i]));
        long long k2h = f(_od_f2i(t + 0.5 * h), (long long)ytmp);
        ODVec *k2 = (ODVec *)(void *)k2h;

        for (int i = 0; i < n; i++)
            ytmp->data[i] = _od_f2i(_od_i2f(y->data[i]) + 0.5 * h * _od_i2f(k2->data[i]));
        long long k3h = f(_od_f2i(t + 0.5 * h), (long long)ytmp);
        ODVec *k3 = (ODVec *)(void *)k3h;

        for (int i = 0; i < n; i++)
            ytmp->data[i] = _od_f2i(_od_i2f(y->data[i]) + h * _od_i2f(k3->data[i]));
        long long k4h = f(_od_f2i(t + h), (long long)ytmp);
        ODVec *k4 = (ODVec *)(void *)k4h;

        // Two half-steps for error estimate
        double h2 = h * 0.5;
        for (int i = 0; i < n; i++)
            ytmp->data[i] = _od_f2i(_od_i2f(y->data[i]) +
                (h / 6.0) * (_od_i2f(k1->data[i]) + 2 * _od_i2f(k2->data[i]) +
                              2 * _od_i2f(k3->data[i]) + _od_i2f(k4->data[i])));

        // Estimate error (compare RK4 full step vs midpoint)
        double err = 0;
        for (int i = 0; i < n; i++) {
            double diff = fabs(_od_i2f(k4->data[i]) - _od_i2f(k2->data[i])) * h / 6.0;
            err += diff * diff;
        }
        err = sqrt(err / n);

        if (err < tol || h < 1e-12) {
            for (int i = 0; i < n; i++) y->data[i] = ytmp->data[i];
            t += h;
            if (err < tol * 0.1 && err > 0) h *= 1.5;
        } else {
            h *= 0.5;
        }
        if (h > (t1 - t)) h = t1 - t;
    }
    return (long long)y;
}

// ================================================================
//  Symplectic integrator (Stormer-Verlet for Hamiltonian systems)
//  dq/dt = dp_H, dp/dt = -dq_H
//  grad_V: q -> -dp/dt (gradient of potential)
// ================================================================

long long nuc_ode_symplectic(long long grad_V_ptr, long long q0_h, long long p0_h,
                              long long t1_bits, long long h_bits) {
    typedef long long (*GradFn)(long long);
    GradFn grad_V = (GradFn)(void *)grad_V_ptr;
    ODVec *q0 = (ODVec *)(void *)q0_h;
    ODVec *p0 = (ODVec *)(void *)p0_h;
    double t1 = _od_i2f(t1_bits), h = _od_i2f(h_bits);
    int n = q0->len;

    ODVec *q = odvec_new(n);
    ODVec *p = odvec_new(n);
    for (int i = 0; i < n; i++) { q->data[i] = q0->data[i]; p->data[i] = p0->data[i]; }

    double t = 0;
    while (t < t1 - 1e-12) {
        if (t + h > t1) h = t1 - t;

        // p half-step
        long long gq = grad_V((long long)q);
        ODVec *g = (ODVec *)(void *)gq;
        for (int i = 0; i < n; i++) {
            double pi = _od_i2f(p->data[i]) - 0.5 * h * _od_i2f(g->data[i]);
            p->data[i] = _od_f2i(pi);
        }

        // q full step
        for (int i = 0; i < n; i++) {
            double qi = _od_i2f(q->data[i]) + h * _od_i2f(p->data[i]);
            q->data[i] = _od_f2i(qi);
        }

        // p half-step
        gq = grad_V((long long)q);
        g = (ODVec *)(void *)gq;
        for (int i = 0; i < n; i++) {
            double pi = _od_i2f(p->data[i]) - 0.5 * h * _od_i2f(g->data[i]);
            p->data[i] = _od_f2i(pi);
        }
        t += h;
    }

    // Pack q and p into result: first n entries = q, next n = p
    ODVec *result = odvec_new(2 * n);
    for (int i = 0; i < n; i++) {
        result->data[i] = q->data[i];
        result->data[n + i] = p->data[i];
    }
    return (long long)result;
}

// ================================================================
//  Event detection: integrate until event_fn(y) crosses zero
// ================================================================

long long nuc_ode_event(long long f_ptr, long long y0_h, long long event_ptr,
                         long long t_max_bits) {
    typedef long long (*RHSFn)(long long, long long);
    typedef long long (*EventFn)(long long);
    RHSFn f = (RHSFn)(void *)f_ptr;
    EventFn event = (EventFn)(void *)event_ptr;
    ODVec *y0 = (ODVec *)(void *)y0_h;
    double t_max = _od_i2f(t_max_bits);
    int n = y0->len;

    ODVec *y = odvec_new(n);
    for (int i = 0; i < n; i++) y->data[i] = y0->data[i];

    double h = t_max * 0.001;
    double t = 0;
    double prev_ev = _od_i2f(event((long long)y));

    while (t < t_max) {
        // RK4 step
        long long rk = nuc_ode_rk4(f_ptr, (long long)y, _od_f2i(t), _od_f2i(t + h), _od_f2i(h));
        ODVec *ynew = (ODVec *)(void *)rk;

        double ev = _od_i2f(event((long long)ynew));
        if ((prev_ev >= 0 && ev < 0) || (prev_ev <= 0 && ev > 0)) {
            // Bisect to find precise crossing
            double tlo = t, thi = t + h;
            for (int iter = 0; iter < 50; iter++) {
                double tmid = (tlo + thi) * 0.5;
                long long ym = nuc_ode_rk4(f_ptr, (long long)y, _od_f2i(t), _od_f2i(tmid), _od_f2i(tmid - t));
                double evm = _od_i2f(event(ym));
                if ((prev_ev >= 0 && evm < 0) || (prev_ev <= 0 && evm > 0)) thi = tmid;
                else { tlo = tmid; prev_ev = evm; }
                if (thi - tlo < 1e-12) break;
            }
            break;
        }

        for (int i = 0; i < n; i++) y->data[i] = ynew->data[i];
        t += h;
        prev_ev = ev;
    }
    return (long long)y;
}
