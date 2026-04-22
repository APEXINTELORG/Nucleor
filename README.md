# Nucleor

**A self-hosted programming language with a complete scientific-computing runtime — linear algebra, tensors, PDE solvers, control systems, automatic differentiation, quantum simulation, and 60+ more rods, all built in.**

```nr
fn main() -> i64 {
    print("Hello, Nucleor!");
    return 0;
}
```

```
nuc build examples/01_hello.nr -o hello
target\hello.exe
> Hello, Nucleor!
```

## Why

Nucleor is what happens when you build a small programming language and don't stop at "hello world." The compiler is self-hosted in ~10,000 lines of Nucleor source. The standard library is ~280+ runtime functions covering most of the scientific computing stack. Together they fit in a 54 MB repo with no external runtime dependencies beyond LLVM.

- **Self-hosted from day one.** The compiler is written in Nucleor and rebuilds itself as a standard CI step. No hidden runtime dependencies; no separate bootstrap language to keep in sync.
- **Real scientific-computing stack, not a toy.** Linear algebra (LU, QR, Cholesky, eigen, SVD), tensor decompositions (CP-ALS, TT-SVD), sparse matrices with CG/GMRES solvers, FFT, signal processing, statistics with t-tests and KDE, ODE solvers (Euler, RK4, RK45, symplectic), root finding, quadrature, B-splines + KAN, interpolation.
- **PDE solvers that actually solve PDEs.** Multigrid Poisson, Lattice Boltzmann fluids, FDTD electromagnetics, heat transfer.
- **Physics built in.** 17 CODATA 2018 constants. SI unit conversion across mass, length, time, temperature, pressure, energy, force, frequency, voltage, current. 3D rigid-body dynamics. Orbital mechanics (Kepler, Hohmann, vis-viva).
- **Modern ML in the box.** Reverse-mode autodiff. Mamba selective scan, RWKV, xLSTM cells. Mixture-of-experts routing. GATv2 graph neural networks. Full state-vector quantum simulator.
- **Algebraic optimization.** Declare a function commutative or associative and the optimizer rewrites call sites accordingly. `@hot` enforces no-heap, no-format, no-indirect-dispatch in a function's body.
- **Real interop.** The shipping `rust_bridge` demonstrates calling Rust crates (regex, base64, hashing) from Nucleor through the C ABI. The same pattern works for any language with `extern "C"` static-library output.
- **Black-Scholes and Greeks** because why not. Plus PCA, PID, Kalman filter, control state-space models.

## Install

Prerequisites: **Windows 10/11 x86_64**, **LLVM 18.x** with `clang.exe`. CUDA Toolkit and Rust toolchain are optional.

```
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor
nuc build examples/01_hello.nr -o hello
target\hello.exe
```

The bootstrap binary `bin/nucleor.exe` is committed to the repo, so you do not need to build the compiler from source on first use. The `nuc.bat` launcher resolves `clang.exe` from `NUCLEOR_CLANG_PATH`, then `LLVM_SYS_180_PREFIX/bin`, then `C:\Program Files\LLVM\bin`, then plain PATH.

POSIX (Linux/macOS) support is planned for v1.1.

## Standard library — by category

**Numerics & linear algebra:** `complex` · `math` · `linalg` (LU, QR, Cholesky, eigen, SVD) · `tensor_nd` · `tensor_decomp` (CP-ALS, TT-SVD) · `sparse` (CSR, CG, GMRES) · `bitwise`

**Numerical methods:** `ode` (Euler, RK4, RK45, symplectic) · `root` (bisection, Newton, Brent) · `quad` (trapezoid, Simpson, Gauss, adaptive, Monte Carlo) · `interp` (linear, cubic spline, Lagrange, Chebyshev, RBF) · `bspline` (+ KAN forward) · `optim` (GD, Adam, simplex, line search, genetic)

**Statistics & signal:** `stats` (regression, t-test, χ², KDE) · `signal` (FIR/IIR/Butterworth/windows) · `fft` (1D, real, convolve, power spectrum) · `pca` (fit, project)

**PDE & physics simulation:** `multigrid` · `fluid` (Lattice Boltzmann) · `emag` (FDTD Maxwell) · `thermo` (heat eq + ideal gas + Carnot + radiation) · `geom` · `rigid_body` · `orbit`

**Physical constants & units:** `physics` (17 CODATA 2018 constants) · `units` (SI conversion across 9 dimensions)

**Symbolic & differentiable:** `autodiff` (reverse mode) · `symbolic` (expression trees + diff)

**Control systems:** `control` (PID + Kalman + state-space)

**Modern ML:** `nn` (Dense + Adam + attention + ensemble) · `gnn` (GATv2 + global attention pool) · `ssm` (Mamba selective scan + RWKV + xLSTM + ZOH) · `moe` (top-k gate + dispatch + load balancing)

**Quantum:** `quantum` (full state-vector simulator: H, X, Y, Z, CNOT, measure)

**Finance:** `finance` (Black-Scholes + all Greeks + implied vol + NPV + IRR + VaR + portfolio opt)

**System & data:** `io` · `fs` · `os` · `env` · `path` · `time` · `concurrency` (threads + mutex + spawn/join) · `cli` · `log` · `test` · `strings` · `fmt` · `json` · `csv` · `ini` · `regex` · `base64` · `uuid` · `queue` · `stack` · `sort` · `collections` · `option` · `result`

**Interop:** `rust` (Rust crates via C ABI) · `python` · `gpu`

That's **65 rods total** in v0.1.1, all building cleanly against the bootstrap binary.

## Tour by example

- [`examples/01_hello.nr`](examples/01_hello.nr) — the smallest possible program.
- [`examples/02_fib.nr`](examples/02_fib.nr) — recursion + iteration.
- [`examples/03_structs.nr`](examples/03_structs.nr) — structs, fields, mutation.
- [`examples/04_rods.nr`](examples/04_rods.nr) — using stdlib rods (strings + JSON).
- [`examples/05_quantum.nr`](examples/05_quantum.nr) — Bell-state preparation on the bundled quantum simulator.
- [`examples/06_perf_attrs.nr`](examples/06_perf_attrs.nr) — `@hot`, `@law`, `@const_fn`.
- [`examples/07_rust_interop.nr`](examples/07_rust_interop.nr) — Rust regex + base64 via `rust_bridge`.
- [`examples/08_linalg.nr`](examples/08_linalg.nr) — solve a linear system, take an SVD.
- [`examples/09_ode.nr`](examples/09_ode.nr) — integrate a damped pendulum with RK4.
- [`examples/10_fft.nr`](examples/10_fft.nr) — round-trip a sine wave through the FFT.
- [`examples/11_pid.nr`](examples/11_pid.nr) — PID controller driving a plant to a setpoint.
- [`examples/12_autodiff.nr`](examples/12_autodiff.nr) — reverse-mode autodiff of `sin(x²) + x`.

## Showcase — animated, color, "did one language really just do that"

Programs in [`examples/showcase/`](examples/showcase/) that demonstrate
things Nucleor is uniquely suited for, with live ANSI-colored visualizations.
All four are one file each.

- [`vqe_h2.nr`](examples/showcase/vqe_h2.nr) — **Variational Quantum Eigensolver** finding the ground state of a 2-qubit Hamiltonian via parameter-shift gradient descent. Live convergence chart with parameter and energy bars updating in place. Other-stack equivalent: PennyLane + PyTorch + OpenFermion + SciPy.
- [`market_maker.nr`](examples/showcase/market_maker.nr) — **Live options market-making engine.** Black-Scholes pricing + full Greeks + PID-driven delta hedging at simulated 10 ms tick. Bloomberg-style dashboard. Other-stack equivalent: Python + QuantLib + filterpy + simple-pid + a C++ rewrite for the latency path.
- [`wing_simulator.nr`](examples/showcase/wing_simulator.nr) — **Coupled fluid + electromagnetic simulator** on the same airfoil cross-section. Lattice Boltzmann (D2Q9) for aerodynamics + FDTD on a Yee grid for electromagnetics, both in one file with one shared geometry. 256-color heatmaps for density, vorticity, and E_z field. Other-stack equivalent: OpenFOAM + Meep + a custom mesh bridge + matplotlib.
- [`lorenz.nr`](examples/showcase/lorenz.nr) — **The Lorenz strange attractor** integrated with RK4, two trajectories from initial conditions 1e-5 apart, rendered as a heatmap of trajectory density. Visual demonstration of sensitive dependence on initial conditions — the iconic butterfly shape emerges in your console.

## Documentation

- [Getting Started](docs/getting-started.md) — install, first build, troubleshooting.
- [Language Tour](docs/language-tour.md) — syntax and idioms by example.
- [Language Reference](docs/language-reference.md) — formal-style spec of types, control flow, attributes, the CLI.
- [Rods and Runtime](docs/rods-and-runtime.md) — the rod catalog with one-liners for each one.
- [Math and Physics](docs/math-and-physics.md) — worked examples across the scientific-computing rods.
- [Architecture](docs/architecture.md) — pipeline (lex → parse → IR → algebraic-rewrite → LLVM → clang), the self-host bootstrap chain, the optimizer.
- [Benchmarks](docs/benchmarks.md) — reproducible numbers from `nuc bench`.

## CLI quick reference

```
nuc init [name]            scaffold a new project
nuc build [file]           compile to native binary
nuc run [file]             compile and run
nuc test [path]            build and run @test / test_* functions
nuc bench [file]           benchmark repeated runs
nuc perf [file]            optimizer + performance diagnostics
nuc check [file]           run all checkers (ownership, type, source, taint, effect)
nuc emit [file]            emit LLVM IR only
nuc stage-dump <stage>     dump compiler stage summaries (tokens|ast|typed|ir|all)
nuc bootstrap status       self-host bootstrap report
nuc clean                  remove target/ and .nuc_cache/ (alias: nuc scram)
nuc zen                    the design principles of Nucleor
nuc mco                    Mars Climate Orbiter — why dimensional analysis matters
nuc help                   full command list
```

## Tab completion

Drop-in completion scripts for `bash`, `zsh`, `fish`, and PowerShell live in
[`tools/completions/`](tools/completions/). One-liner install per shell —
see [`tools/completions/README.md`](tools/completions/README.md).

## Testing this build

```
nuc test tests/
```

This compiles and runs all 24 tests across `tests/lang/`, `tests/attrs/`, `tests/runtime/`, and `tests/rods/`.

For the full smoke gate (all examples + tests + self-host rebuild):

```
powershell.exe -ExecutionPolicy Bypass -File tools\verify.ps1
```

This is what CI runs on every push.

## Versioning

This is **v0.1.1**. The bootstrap binary identifies itself as `Nucleor Compiler 0.2.0-v2` — the V2 designation refers to the second major rewrite of the compiler internals (the rewrite that introduced the algebraic-rewrite optimizer and the V2 attribute set). Future releases will follow semantic versioning starting from v0.1.x.

See [CHANGELOG.md](CHANGELOG.md) for what changed in this release.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: open an issue or PR at https://github.com/APEXINTELORG/Nucleor. We follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

Copyright 2026 Joseph Wescott.
