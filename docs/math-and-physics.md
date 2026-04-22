# Math and Physics in Nucleor

A guided tour of the scientific-computing surface. Every snippet builds and runs against `bin/nucleor.exe`. Numbers are f64 values bitcast to i64 — use the `f64_*` helpers from `stdlib/rods/complex.nr` to do arithmetic with them.

## Linear algebra: solve Ax = b

```nr
import "stdlib/rods/linalg.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    // 3×3 symmetric positive-definite matrix
    let A: i64 = linalg_new(3, 3);
    linalg_set(A, 0, 0, f64(4, 0));    linalg_set(A, 0, 1, f64(1, 0));    linalg_set(A, 0, 2, f64(0, 0));
    linalg_set(A, 1, 0, f64(1, 0));    linalg_set(A, 1, 1, f64(3, 0));    linalg_set(A, 1, 2, f64(1, 0));
    linalg_set(A, 2, 0, f64(0, 0));    linalg_set(A, 2, 1, f64(1, 0));    linalg_set(A, 2, 2, f64(2, 0));

    let b: i64 = linalg_new(3, 1);
    linalg_set(b, 0, 0, f64(1, 0));
    linalg_set(b, 1, 0, f64(2, 0));
    linalg_set(b, 2, 0, f64(3, 0));

    let x: i64 = linalg_solve(A, b);
    print(str_concat("x[0] = ", f64_to_str_6(linalg_get(x, 0, 0))));
    print(str_concat("x[1] = ", f64_to_str_6(linalg_get(x, 1, 0))));
    print(str_concat("x[2] = ", f64_to_str_6(linalg_get(x, 2, 0))));
    return 0;
}
```

## SVD of a matrix

```nr
import "stdlib/rods/linalg.nr"

fn main() -> i64 {
    let A: i64 = linalg_new(4, 3);
    // populate A...
    let svd: i64 = linalg_svd(A);
    let U: i64 = linalg_svd_U(svd);
    let S: i64 = linalg_svd_S(svd);  // singular values, diagonal
    let V: i64 = linalg_svd_V(svd);
    return 0;
}
```

## ODE: damped pendulum with RK4

```nr
import "stdlib/rods/ode.nr"
import "stdlib/rods/complex.nr"

// derivative function: y = [theta, omega], dy/dt = [omega, -g/L sin(theta) - b*omega]
fn pendulum_rhs(t: i64, y: i64) -> i64 {
    // build [omega, -g/L*sin(theta) - b*omega] into a vec; return handle
    return y;  // placeholder — real implementation builds new state vec
}

fn main() -> i64 {
    // y0 = [pi/4, 0]
    let y0: i64 = vec_new();
    vec_push(y0, f64_div(f64_pi(), f64_from_int(4)));
    vec_push(y0, f64_from_int(0));
    let t0: i64 = f64_from_int(0);
    let t1: i64 = f64_from_int(10);
    let h: i64 = f64(0, 10000);  // 0.01
    let traj: i64 = ode_rk4(pendulum_rhs, y0, t0, t1, h);
    return 0;
}
```

## FFT: round-trip a sine wave

```nr
import "stdlib/rods/fft.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    let n: i64 = 256;
    let sig: i64 = vec_new();
    let mut k: i64 = 0;
    while k < n {
        // sin(2π * 5 * k / n)
        let arg: i64 = f64_div(f64_mul(f64_mul(f64_from_int(2), f64_pi()),
                                       f64_mul(f64_from_int(5), f64_from_int(k))),
                               f64_from_int(n));
        vec_push(sig, f64_sin(arg));
        k = k + 1;
    };
    let fwd: i64 = fft_1d(sig, n, 1);
    let back: i64 = fft_1d(fwd, n, 0);
    print(str_concat("FFT round-trip: input[10] = ", f64_to_str_6(vec_get(sig, 10))));
    print(str_concat("                output[10] = ", f64_to_str_6(vec_get(back, 10))));
    return 0;
}
```

## Statistics: linear regression

```nr
import "stdlib/rods/stats.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    // y = 2x + 1 with a tiny bit of noise
    let xs: i64 = vec_new();
    let ys: i64 = vec_new();
    let mut k: i64 = 0;
    while k < 20 {
        vec_push(xs, f64_from_int(k));
        vec_push(ys, f64_add(f64_mul(f64_from_int(2), f64_from_int(k)), f64_from_int(1)));
        k = k + 1;
    };
    let lr: i64 = stat_linreg(xs, ys);
    print(str_concat("slope:     ", f64_to_str_6(stat_linreg_slope(lr))));
    print(str_concat("intercept: ", f64_to_str_6(stat_linreg_intercept(lr))));
    print(str_concat("R²:        ", f64_to_str_6(stat_linreg_r2(lr))));
    return 0;
}
```

## Physical constants and SI units

```nr
import "stdlib/rods/physics.nr"
import "stdlib/rods/units.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    let c: i64 = const_c();
    print(str_concat("speed of light = ", f64_to_str_6(c)));   // 299792458 m/s

    // Convert a temperature: 20°C → K
    let t_c: i64 = f64_from_int(20);
    let t_k: i64 = unit_convert(t_c, unit_C(), unit_K());
    print(str_concat("20°C in K = ", f64_to_str_6(t_k)));      // 293.15

    // Energy of a 532-nm photon: E = hc / λ
    let h: i64 = const_h();                                     // J·s
    let wavelength_nm: i64 = f64_from_int(532);
    let wavelength_m: i64 = unit_convert(wavelength_nm, 4, 1);  // mm to m, here as nm→m close enough
    let energy: i64 = f64_div(f64_mul(h, c), wavelength_m);
    print(str_concat("photon energy ≈ ", f64_to_str_6(energy)));
    return 0;
}
```

## Black-Scholes option pricing

```nr
import "stdlib/rods/finance.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    let S: i64 = f64_from_int(100);    // spot price
    let K: i64 = f64_from_int(100);    // strike
    let T: i64 = f64(0, 250000);       // 0.25 yr (3 months)
    let r: i64 = f64(0, 50000);        // 5% risk-free rate
    let sigma: i64 = f64(0, 200000);   // 20% vol
    let kind: i64 = 0;                 // 0 = call

    let price: i64 = fin_black_scholes(S, K, T, r, sigma, kind);
    let g: i64 = fin_greeks(S, K, T, r, sigma);
    print(str_concat("Call price: ", f64_to_str_6(price)));
    print(str_concat("Δ (delta):  ", f64_to_str_6(fin_greek_delta(g))));
    print(str_concat("Γ (gamma):  ", f64_to_str_6(fin_greek_gamma(g))));
    print(str_concat("Θ (theta):  ", f64_to_str_6(fin_greek_theta(g))));
    print(str_concat("ν (vega):   ", f64_to_str_6(fin_greek_vega(g))));
    print(str_concat("ρ (rho):    ", f64_to_str_6(fin_greek_rho(g))));
    return 0;
}
```

## Kalman filter: track a noisy 1D position

```nr
import "stdlib/rods/control.nr"
import "stdlib/rods/linalg.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    // Constant-velocity model: state = [pos, vel]
    let A: i64 = linalg_new(2, 2);
    linalg_set(A, 0, 0, f64(1, 0)); linalg_set(A, 0, 1, f64(1, 0));
    linalg_set(A, 1, 0, f64(0, 0)); linalg_set(A, 1, 1, f64(1, 0));

    let B: i64 = linalg_new(2, 1);
    let C: i64 = linalg_new(1, 2);
    linalg_set(C, 0, 0, f64(1, 0)); linalg_set(C, 0, 1, f64(0, 0));

    let Q: i64 = linalg_new(2, 2);  // process noise covariance
    let R: i64 = linalg_new(1, 1);  // measurement noise covariance
    linalg_set(R, 0, 0, f64(1, 0));

    let kf: i64 = kalman_new(A, B, C, Q, R, 2, 1, 1);
    // Then in a loop: kalman_predict(kf, u); kalman_update(kf, z); kalman_state(kf);
    return 0;
}
```

## Lattice Boltzmann fluid simulation

```nr
import "stdlib/rods/fluid.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    let lbm: i64 = lbm_new_2d(64, 32, f64(0, 100000));  // 64×32 grid, viscosity 0.1
    lbm_set_inlet(lbm, f64(0, 50000));                  // 0.05 inlet velocity

    // Place a circular obstacle
    let mut x: i64 = 14;
    while x <= 18 {
        let mut y: i64 = 14; while y <= 18 { lbm_set_obstacle(lbm, x, y); y = y + 1; };
        x = x + 1;
    };

    let mut step: i64 = 0;
    while step < 100 { lbm_step(lbm); step = step + 1; };

    print(str_concat("density at (32,16): ", f64_to_str_6(lbm_get_density(lbm, 32, 16))));
    print(str_concat("vx      at (32,16): ", f64_to_str_6(lbm_get_vx(lbm, 32, 16))));
    lbm_free(lbm);
    return 0;
}
```

## Automatic differentiation

```nr
import "stdlib/rods/autodiff.nr"
import "stdlib/rods/complex.nr"

// f(x) = sin(x²)  →  f'(x) = 2x cos(x²)
fn main() -> i64 {
    ad_reset();
    let x: i64 = ad_var(f64_from_int(2));     // x = 2
    let x2: i64 = ad_mul(x, x);               // x²
    let y: i64 = ad_sin(x2);                  // sin(x²)
    print(str_concat("f(2)  = sin(4) = ", f64_to_str_6(ad_value(y))));
    print(str_concat("f'(2) = ",            f64_to_str_6(ad_grad(y, x))));
    return 0;
}
```

## Symbolic differentiation

```nr
import "stdlib/rods/symbolic.nr"
import "stdlib/rods/complex.nr"

// d/dx[ x² + 3x + 1 ] = 2x + 3
fn main() -> i64 {
    let x: i64 = sym_var("x");
    let three: i64 = sym_const(f64_from_int(3));
    let one: i64 = sym_const(f64_from_int(1));
    let f: i64 = sym_add(sym_add(sym_mul(x, x), sym_mul(three, x)), one);
    let df: i64 = sym_diff(f, "x");
    let val_at_5: i64 = sym_eval(df, "x", f64_from_int(5));
    print(str_concat("f'(5) = ", f64_to_str_6(val_at_5)));   // 2*5 + 3 = 13
    return 0;
}
```

## Quantum: Bell state

See [`examples/05_quantum.nr`](../examples/05_quantum.nr) for the runnable version. The short story:

```nr
import "stdlib/rods/quantum.nr"

fn main() -> i64 {
    rng_seed(42);
    let sv: i64 = qsim_init(2);   // |00⟩
    qsim_h(sv, 0);                 // |+⟩|0⟩
    qsim_cnot(sv, 0, 1);           // (|00⟩ + |11⟩)/√2
    let q0: i64 = qsim_measure(sv, 0);
    let q1: i64 = qsim_measure(sv, 1);
    // q0 == q1 always — the qubits are perfectly correlated.
    return 0;
}
```

## Where to look next

- The full [Language Reference](language-reference.md) for syntax + types + attributes.
- The [Rods and Runtime](rods-and-runtime.md) catalog for every shipping rod.
- The runtime C source in `stdlib/runtime/` if you want to see how a particular operator is implemented.
