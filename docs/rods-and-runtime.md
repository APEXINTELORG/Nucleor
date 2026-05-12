# Rods and the Runtime

Nucleor's standard library is organized as **rods**: small, focused modules paired with their C runtime. The v1.1 tree ships about **290 rods** covering general utilities, scientific computing, modern ML, physics simulation, real-time control, quantum simulation, and systems integration. The full per-rod catalog with API surface and stability is generated at [`docs/rfcs/rod_manifest.toml`](rfcs/rod_manifest.toml).

## Anatomy of a rod

A rod is two files in `stdlib/rods/` (or one rod + one runtime file in `stdlib/runtime/`):

- `<name>.nr` — the Nucleor-side wrapper. Declares `extern fn` bindings for the C symbols, provides Nucleor-friendly wrappers around them, and includes `#cfile` directives to tell the compiler what C source to compile and link.
- `<name>_rt.c` — the C implementation.

Example: `stdlib/rods/quantum.nr` calls into `stdlib/rods/quantum_rt.c`. When a user program does `import "stdlib/rods/quantum.nr"`, the compiler reads the `#cfile` directive and arranges for `quantum_rt.c` to be compiled and linked into the final binary. Some rods (linalg, physics, ode, etc.) point at runtime files in `stdlib/runtime/` instead.

## The shipping rod catalog

The tables below describe a representative subset of the public rod surface.
Up-to-date enumerations of every rod with stability and API surface live in
[`docs/rfcs/rod_manifest.toml`](rfcs/rod_manifest.toml) and
[`docs/rfcs/rod_manifest_schema.md`](rfcs/rod_manifest_schema.md).

### Core utilities

| Rod | Provides |
|---|---|
| `strings.nr`     | `strings_contains`, `starts_with`, `ends_with`, `to_upper/lower`, `split`, `join`, `trim`, `replace`, `repeat`, `pad_*`, `char_to_str` |
| `fmt.nr`         | `fmt_int`, `bool`, `hex/oct/bin`, `float_approx`, `pad_*`, `format`, `to_int` |
| `bitwise.nr`     | `bit_and`, `or`, `xor`, `not`, `shift_left/right`, `test`, `set`, `clear` |
| `math.nr`        | `math_abs`, `min`, `max`, `clamp`, `pow_int`, `sqrt_int`, `gcd`, `lcm`, `is_even`, `is_odd` |
| `complex.nr`     | f64 helpers (add/sub/mul/div, sqrt/sin/cos/atan2/exp/log/pow), constants (π, e, τ, √2), complex numbers, RNG (`rng_seed`, `rng_f64`, `rng_normal`) |

### Linear algebra and tensors

| Rod | Provides |
|---|---|
| `linalg.nr`        | Matrix construction, basic ops (add/sub/scale/mul/transpose/trace/norm/det/inv/rank), **LU**, **QR**, **Cholesky**, **eigen**, **SVD**, ridge regression, identity matrix |
| `tensor_nd.nr`     | N-dimensional tensors: arbitrary-rank shapes, multi-index and flat access, reshape, slice, element-wise add/mul, scale, sum-along-axis, batched matmul |
| `tensor_decomp.nr` | **CP-ALS** (PARAFAC), **Tensor-Train SVD**, Kronecker product, Khatri-Rao product |
| `sparse.nr`        | CSR sparse matrices: from-COO, from-dense, set/get/transpose, sparse mat-vec, **conjugate gradient**, **GMRES** |

### Numerical methods

| Rod | Provides |
|---|---|
| `ode.nr`     | Explicit Euler, fixed-step **RK4**, adaptive **RK45**, symplectic (Hamiltonian-preserving), event detection |
| `root.nr`    | Bisection, **Newton's method**, secant, **Brent**, multi-dim Newton for systems |
| `quad.nr`    | Trapezoid, Simpson, Gauss-Legendre, adaptive, 2D, **Monte Carlo** |
| `interp.nr`  | Linear, **cubic spline**, Lagrange, Chebyshev (fit + eval), 2D bilinear, **RBF** (radial basis function) |
| `bspline.nr` | B-spline eval, basis functions, derivatives, uniform knot vector, **KAN forward** (Kolmogorov-Arnold) |
| `optim.nr`   | Gradient descent, **Adam**, Nelder-Mead simplex, line search, genetic optimizer |

### Statistics and signal processing

| Rod | Provides |
|---|---|
| `stats.nr`   | Mean, median, var, std, covariance, correlation, percentile, histogram, **linear regression** (slope/intercept/R²), **t-test**, **chi-square**, **kernel density estimation** |
| `signal.nr`  | FIR / IIR filtering, **Butterworth** design, Hamming / Hann / Blackman windows, **envelope**, zero-crossing count, up/down-sampling |
| `fft.nr`     | 1D complex / real FFT, fast convolution, power spectrum, cross-correlation |
| `pca.nr`     | Fit, project a sample onto top-k components, per-component variance ratio, eigenvalues |

### PDE solvers and physics simulation

| Rod | Provides |
|---|---|
| `multigrid.nr`  | 2D **multigrid Poisson** solve + residual norm |
| `fluid.nr`      | 2D **Lattice Boltzmann** with obstacles, inlet velocity, density, velocity field, vorticity |
| `emag.nr`       | 2D **FDTD electromagnetics** with materials, sources, E_z/H_x/H_y fields, energy integration |
| `thermo.nr`     | 2D **heat equation**, steady-state, ideal gas law, **Carnot efficiency**, blackbody radiation |
| `geom.nr`       | 2D convex hull, point-in-polygon, line intersection, polygon area, closest pair, bbox, point-to-line distance |
| `rigid_body.nr` | 3D rigid body dynamics: position, velocity, rotation, angular velocity, force/torque, gravity, integration step, sphere-sphere collision |
| `orbit.nr`      | **Kepler-to-Cartesian**, orbital period, **Hohmann transfer**, two-body propagation, vis-viva, escape velocity |

### Physical constants and units

| Rod | Provides |
|---|---|
| `physics.nr` | **17 CODATA 2018 constants**: c, h, ℏ, k_B, e, m_e, m_p, m_n, G, N_A, R, ε₀, μ₀, σ (Stefan-Boltzmann), α (fine-structure), a₀ (Bohr), R∞ (Rydberg), eV, u, π, e (Euler), v_sound |
| `units.nr`   | SI unit conversion across mass (kg/g/lb/oz), length (m/km/cm/mm/in/ft/mi), time (s/ms/μs/min/hr/day), temperature (K/C/F), pressure (Pa/kPa/atm/bar/psi), energy (J/kJ/cal/eV/kWh), force (N/kN/lbf), frequency (Hz/kHz/MHz/GHz), angle (rad/deg), voltage (V/mV), current (A/mA) |

### Symbolic and differentiable computing

| Rod | Provides |
|---|---|
| `autodiff.nr` | **Reverse-mode automatic differentiation** with var/const, +/-/×/÷, sin/cos/exp/log/sqrt/pow/abs/tanh, value + gradient extraction, tape reset and checkpointing (20 fns) |
| `symbolic.nr` | Expression trees: const + named vars, +/-/×/÷/^, sin/cos/exp/log/sqrt/neg, **symbolic differentiation**, numerical evaluation with variable substitution |

### Control systems

| Rod | Provides |
|---|---|
| `control.nr` | **PID controller** (new, update, reset), state-space model (new, step), **Kalman filter** (new, predict, update, state extraction) |

### Modern ML

| Rod | Provides |
|---|---|
| `nn.nr`   | Dense layers, forward/backward, **Adam optimizer**, attention, ensemble (30 externs) |
| `gnn.nr`  | **GATv2Conv**, **GlobalAttention pooling**, graph construction (15 externs) |
| `ssm.nr`  | **Mamba selective scan**, **SSD chunked**, **RWKV-WKV** (linear attention), **xLSTM cell**, ZOH discretization |
| `moe.nr`  | **Top-k gating**, route indices/weights, expert dispatch + combine, load balancing |

### Quantum

| Rod | Provides |
|---|---|
| `quantum.nr` | Full state-vector simulator: H, X, Y, Z, S, T, RX, RY, RZ, **CNOT**, **measurement** with collapse, density-matrix observables (16 externs) |

### Finance

| Rod | Provides |
|---|---|
| `finance.nr` | **Black-Scholes** option pricing, full **Greeks** (Δ, Γ, Θ, ν, ρ), implied volatility, NPV, IRR, **value-at-risk**, mean-variance portfolio optimization |

### Data and serialization

| Rod | Provides |
|---|---|
| `json.nr`        | JSON parse, stringify, value construction (from_int/string/bool/array/object) |
| `csv.nr`         | CSV parse and format |
| `ini.nr`         | INI file parse |
| `regex.nr`       | Simple character-class predicates (use `rust.nr` for full regex) |
| `base64.nr`      | base64 encode/decode |
| `uuid.nr`        | UUID generation |

### System

| Rod | Provides |
|---|---|
| `io.nr`          | Console output extensions |
| `fs.nr`          | File system primitives |
| `os.nr`          | Process exit, OS info |
| `env.nr`         | Environment variable access |
| `path.nr`        | Path manipulation |
| `time.nr`        | `time_now_ms`, `time_sleep_ms`, `time_format_ms` |
| `concurrency.nr` | `conc_mutex`, `conc_lock`, `conc_unlock`, `conc_spawn`, `conc_join`, `conc_parallel` |
| `cli.nr`         | Command-line argument parsing |
| `log.nr`         | Logging primitives |
| `test.nr`        | Test framework with assertions |

### Data structures

| Rod | Provides |
|---|---|
| `collections.nr` | Higher-level vector ops |
| `option.nr`      | `Option` type and helpers |
| `result.nr`      | `Result` type and helpers |
| `queue.nr`       | FIFO queue |
| `stack.nr`       | LIFO stack |
| `sort.nr`        | Sorting primitives |

### Specialty / interop

| Rod | Provides |
|---|---|
| `rust.nr`       | Rust crate interop via `rust_bridge` (regex, base64, hashing, sorting) |
| `python.nr`     | Optional Python FFI (requires Python on PATH) |
| `gpu.nr`        | GPU kernel orchestration |
| `multi_core.nr` | Multi-core trace recording for ensemble experiments |
| `ridge.nr`      | Ridge regression with gradient descent (pure Nucleor) |
| `twin_core.nr`  | Backward-compatible quantum noise twin-core comparison utilities |
| `quantum_twin.nr` | Honest alias for the twin-core quantum noise model; not a robotics digital twin |

## The runtime boundary

Every Nucleor program is linked with `stdlib/runtime/nucleor_llvm_rt.c`. This file is the **mandatory boundary** — it provides:

- Basic I/O: `__nucleor_print_str`, `__nucleor_print_i64`, `__nucleor_print_bool`
- File access, process control, args, time, hashing
- `Vec` and string-builder primitives
- Threads, mutex (with `_value` ABI variants), channels, atomics
- RNG (via `#include "rng_rt.c"`)
- Numeric intrinsics, tensor / allocator / device hooks

Beyond `nucleor_llvm_rt.c`, the C runtime files in `stdlib/runtime/` (`fft_rt.c`, `tensor_rt.c`, `linalg_rt.c`, `physics_const_rt.c`, etc.) are **opt-in**: they are only compiled and linked when a rod that uses them includes the appropriate `#cfile` directive. A program that only uses `print` and arithmetic links exactly one C file.

## Writing your own rod

The fastest way to add a function from C, Rust, Zig, or Go to Nucleor:

### From C

Create `my_rod_rt.c`:

```c
long long my_double(long long x) {
    return x * 2;
}
```

Create `my_rod.nr`:

```nr
#cfile "my_rod_rt.c"

extern fn my_double(x: i64) -> i64;
```

Use it:

```nr
import "path/to/my_rod.nr"

fn main() -> i64 {
    print(str_from_int(my_double(21)));
    return 0;
}
```

### From Rust

The shipping `rust_bridge` (in `stdlib/rods/rust_bridge/`) is a working example. The pattern:

1. Build a Rust crate with `crate-type = ["staticlib"]`.
2. Mark exported functions `#[no_mangle] pub extern "C"`.
3. Take and return `*const c_char` (with `CString::into_raw`) for string interop.
4. Build with `cargo build --release` to produce a `.lib`.
5. In your `.nr` wrapper, declare `extern fn` bindings, add `#libpath "rust_bridge/target/release"`, and `#link "your_crate_name"`.

The compile-and-link step is then identical to a C rod — the user just `import`s the `.nr` wrapper.

### From any language with C-ABI static-library output

The mechanism (`#cfile` for C, `#link` + `#libpath` for everything else) is language-neutral. Anything that produces a static library with `extern "C"`-style symbols can be wrapped in a `.nr` file the same way.
