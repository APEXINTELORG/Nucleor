# Nucleor

**A self-hosted systems programming language with an industrial scientific-computing runtime built in. v1.0.**

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

## What it is

Nucleor is what happens when you build a small programming language and refuse to stop at "hello world." The compiler is **self-hosted in ~50,000 lines of Nucleor source**, rebuilds itself from a committed `.ll` seed in a 3.5 seconds, and emits LLVM IR linked through `clang` to a native binary.

The standard library is **~250 rods** (`stdlib/rods/*.nr` — modules you `import`) backed by **190 runtime C source files**. The full ABI surface — every helper the compiler can emit calls to — is **875 `__nucleor_*` symbols** organized into 17 effect-tagged classes (math, vectors, collections, IO, statistics, time, randomness, concurrency, tensor ops, FFT, autodiff, control flow, allocation, ADT, introspection, data codec, tooling). Catalog at [`docs/rfcs/helper_manifest.toml`](docs/rfcs/helper_manifest.toml). The whole repo fits in ~55 MB with no external runtime dependencies beyond LLVM 18.

**v1.0 highlights** (released 2026-05-08):

- **Memory safety as a first-class compile-time guarantee.** All 11 RFC-0062 gates closed at hard-error severity: borrow checking, single-input lifetime enforcement, IR-level use-after-drop, conditional-move tracking, definite-assignment flow analysis, heap-aliasing detection through `Vec<&T>` and HashMap mutation, Sendable closure propagation across spawn boundaries, FFI null-contract enforcement with deref dataflow, FFI bounds-check discipline, unsafe-block audit, and a full effect-annotations framework (`#[effect(frees, may_return_null, direct_ffi, unsafe, borrows_mut)]`).
- **Real scientific computing, not a toy.** Linear algebra (LU/QR/Cholesky/eigen/SVD), tensor decompositions (CP-ALS, TT-SVD), sparse solvers (CG/GMRES), FFT, signal processing, statistics with t-tests + KDE, ODE solvers (Euler/RK4/RK45/symplectic), root finding, quadrature, B-splines + KAN, interpolation. Multigrid Poisson, Lattice Boltzmann fluids, FDTD electromagnetics, heat transfer.
- **Modern ML in the box.** Reverse-mode autodiff. Mamba selective scan, RWKV, xLSTM cells. Mixture-of-experts routing. GATv2 graph neural networks. Full state-vector quantum simulator. ONNX + GGUF + Hugging Face artifact loaders. Quantization (Q4/int8/ternary/FP8). Speculative decoding. Diffusion sampling. **PROBE-2 4-pipeline parity gate against sklearn** (decision-tree classification + linear regression + KMeans + BernoulliNB).
- **Robotics, control, planning.** Kinematics + dynamics + URDF parsing. Forward + inverse kinematics (DH parameters + damped least squares). Trajectory generation (quintic, trapezoidal, S-curve, DMP, TOPP). Path planning (RRT + variants, PRM, A*, D* Lite, DWA, Dubins, Reeds-Shepp). Collision detection (sphere/capsule/AABB/OBB + GJK + EPA + CCD). Whole-body control. ZMP. EKF + UKF + AHRS. iLQR + cilQR + DDP + MPC + MPPI.
- **Quantum.** Full state-vector simulator. Matrix Product States. Clifford stabilizer formalism. Photonic + neuromorphic + logical-qubit primitives. Entanglement-DAG tracking + checked gate-DAG recording.
- **SI units and type-level dimensions.** 17 CODATA 2018 constants. Conversion across mass, length, time, temperature, pressure, energy, force, frequency, voltage, current. Wrong-unit operations are compile-time errors.
- **Production-grade toolchain.** Self-host fixed-point gate. Six drift gates (helper manifest, rod manifest, RELEASES, CHANGELOG↔tag, parser-fn parity, version-label↔CHANGELOG). Mojibake-clean enforcement. Help-coverage gate. Real-world driver smoke. Per-step verify timings with regression detection. Reproducible builds proven byte-identical.

## Try it

Prerequisites: **Windows 10/11 x86_64** or **Linux x86_64**, **LLVM 18.x** with `clang.exe`. CUDA Toolkit and Rust toolchain are optional.

```
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor
nuc build examples/01_hello.nr -o hello
target\hello.exe        # Windows
./target/hello          # Linux
```

The bootstrap binary is committed to the repo, so you don't need to build the compiler from source on first use. The `nuc.bat` (Windows) / `nuc` (POSIX) launcher resolves `clang.exe` from `NUCLEOR_CLANG_PATH`, then `LLVM_SYS_180_PREFIX/bin`, then `C:\Program Files\LLVM\bin`, then plain PATH.

POSIX (Linux) self-build is operational — `tools/bootstrap_linux.sh` builds the compiler from the seed; `tools/verify.sh` runs the full ~1500-step gate. Native Linux perf baseline at `tools/perf_baseline_linux.json`. macOS bootstrap pending hardware availability for the CI gate.

## What's in the box

This README sketches it; the real reference is **[`docs/NUCLEOR_FEATURE_INVENTORY.md`](docs/NUCLEOR_FEATURE_INVENTORY.md)** — a category-by-category walk through every shipping feature with API depth on tensor math, the graphics + plotting surfaces, the ML facades, the quantum stack, the robotics planners, etc.

The short tour:

**Numerics + linear algebra:** `complex` · `math` · `math_typed` · `linalg` (LU + QR + Cholesky + eigen + SVD + condition + pseudo-inverse) · `tensor_nd` (N-d tensors with broadcast + einsum-shape inference) · `tensor_decomp` (CP-ALS + TT-SVD + Tucker) · `sparse` (CSR + CG + GMRES + preconditioned variants) · `fft` (1D + real + convolve + power spectrum + Bluestein) · `bigint` (karatsuba mult, modular exp) · `bitwise` · `taylor` (validated Taylor-arithmetic ODE) · `interval` (rigorous interval arithmetic) · `fixed_point` · `pca` · `ridge`

**Numerical methods:** `ode` (Euler + RK4 + RK45 + symplectic + BDF) · `root` (bisection + Newton + Brent) · `quad` (Simpson + Gauss + adaptive Gauss-Kronrod + Romberg + Monte Carlo) · `interp` (linear + cubic spline + Lagrange + Chebyshev + RBF + Akima) · `bspline` + KAN forward · `optim` (GD + Adam + Nelder-Mead + line search + genetic + simulated annealing + L-BFGS) · `cspline` · `bezier` · `catmullrom`

**Statistics + signal:** `stats` (regression + t-test + χ² + KDE + bootstrap CI) · `signal` (FIR + IIR + Butterworth + windows + STFT + resample) · `bayesian` (MCMC + NUTS) · `dtw`

**PDE + physics simulation:** `multigrid` (Poisson with V/W/full multigrid) · `fluid` (Lattice Boltzmann D2Q9 + D3Q19) · `emag` (FDTD Maxwell with PML) · `thermo` · `geom` · `rigid_body` · `orbit` (Kepler + Hohmann + vis-viva + J2)

**Constants + units:** `physics` (17 CODATA 2018 constants) · `units` (SI conversion across 9 dimensions, type-level)

**Symbolic + autodiff:** `autodiff` (reverse-mode) · `symbolic` (expression trees + simplification + diff + substitution) · `nn_autodiff` · `transformer_autodiff` · `differentiable`

**Control + estimation:** `control` (PID + Kalman + state-space) · `lqr` · `mpc` · `mppi` · `ilqr` · `cilqr` · `ddp` · `pidc` · `ekf` · `ukf` · `pgs` · `pgs3`

**Robotics:** `kinematics` + `kinematics_frame`/`kinematics_transform` (typed transforms) · `fk_chain` (DH parameters) · `ik_dls` (damped least squares + joint limits + singularity detection) · `urdf` parser · `trajectory` (quintic + trapezoidal + S-curve + DMP + TOPP) · `collision` (sphere/capsule/AABB/OBB + GJK + EPA + CCD) · `bvh` · `rrt` (RRT + RRT-Connect + RRT* + goal-region) · `prm` · `astar` · `dstar` · `dwa` · `dubins` · `reeds_shepp` · `stanley` · `purepursuit` · `vfh` · `mecanum` · `skid_steer` · `diff_drive` · `bicycle` · `ahrs` · `wbc`/`hwbc` (whole-body control) · `zmp` · `dynamics` (Newton-Euler + composite-rigid-body) · `harris` · `klt` · `hough` + `hough_circle` · `canny` · `sobel` · `ransac` · `hull` · `delaunay` · `voronoi` · `icp` + `icp_p2p` · `pcalign` · `scanmatch` · `occgrid` · `voxel` · `pnp` · `handeye` · `grasp` · `mesh` · `sdf` · `bt` (behavior trees) · `mppi` · `ba` (Bundle Adjustment) · `pf` (particle filter) · `chomp` (covariant trajectory optimization)

**Modern ML:** `nn` (Dense + Adam + attention + ensemble) · `gnn` (GATv2 + global attention pool) · `ssm` (Mamba selective scan + RWKV + xLSTM + ZOH) · `moe` (top-k gate + expert dispatch + load balancing) · `transformer` (multi-head attention + FFN + layernorm) · `attention2` (FlashAttention-shape + ALiBi + RoPE + sliding-window) · `activation2` (GELU + SwiGLU + Mish + Squareplus + ReGLU) · `tokenizer` (BPE + WordPiece + SentencePiece-shape) · `embedding` · `kv_cache` · `quantize` (Q4 + int8 + ternary + FP8 with calibration) · `rl` (replay + GAE + PPO + DQN) · `loss` (MSE + cross-entropy + huber + focal + contrastive) · `speculative` (LLM speculative decoding) · `diffusion` (DDPM + DDIM)

**ML lifecycle:** `ml/data_facade` · `ml/learn_facade` · `ml/serve_facade` · `ml/ship_facade` · `ml/lab_facade` · `ml/experiment_facade` · `ml/bench_facade` · `ml/cert_facade` · `ml/contract_facade` · `ml/sbom_facade` · `ml/parity_manifest` · `ml/onnx_facade` · `ml/gguf_facade` · `ml/hf_facade` · `ml/model_io_facade` · `ml/quantize` · `ml/ml_health_facade` · `ml/probes` (PROBE-2 4-pipeline parity gate vs sklearn — opt-in via `NUC_VERIFY_ML_PROBE=1`)

**Quantum:** `quantum` (full state-vector: H + X + Y + Z + S + T + CNOT + CZ + CRK + CCX + SWAP + measure) · `quantum_gates` · `qsim_graph` (entanglement DAG + checked gate-DAG) · `qtraj` (quantum trajectories) · `mps` (Matrix Product States + TEBD + DMRG) · `clifford` (stabilizer formalism for QEC) · `photonic` · `neuromorphic` · `logical_qubit`

**Finance:** `finance` (Black-Scholes + all Greeks + implied vol + NPV + IRR + VaR + CVaR + portfolio optimization)

**System + IO:** `io` · `fs` + `fs_extras` · `os` · `env` · `path` · `time` + `datetime` + `time_typed` · `concurrency` (threads + mutex + condvar + spawn/join + atomic) · `cli` · `log` · `lsp` · `multi_core` · `distributed` · `comm` (allreduce + broadcast + scatter + gather) · `socket` (TCP + UDP) · `mpsc_queue` · `spsc_queue` · `serial` · `mmap` · `process` · `thread`

**Data structures + algorithms:** `collections` · `option` · `result` · `queue` · `pqueue` · `stack` · `vecdeque` · `btreemap` · `btreeset` · `hashmap` · `hashset` · `sort` · `string_algo` (KMP + Levenshtein + Trie + Aho-Corasick + suffix-array) · `bloom` (+ HyperLogLog) · `bm25` · `kdtree` · `hnsw` · `pq` (product quantization) · `embedding`

**Crypto + codecs:** `crypto` (AES + ChaCha20 + Poly1305 + HMAC + KDF + ECDSA + Ed25519) · `pq_crypto` (Kyber + Dilithium) · `digest` (SHA-256/512 + BLAKE3) · `compress` (gzip + deflate + lz4) · `base64` · `regex` · `uuid` (v4 + v7) · `json` + `jsonl` · `csv` + `csv_table` · `ini` · `toml` · `binary`

**Image + audio + plotting:** `audio` (WAV + STFT + MFCC + spectrogram + resample) · `image` (PPM + BMP + convolutions) · `image_pyramid` (Gaussian + Laplacian) · `imgproc` (blur + threshold + morphology + color conv) · `color` (RGB/HSV/LAB/XYZ/sRGB) · `vision` · `plot` (SVG: line + scatter + bar + histogram + heatmap + contour) · `graph_render` (force-directed graph viz)

**Bio:** `bioseq` (FASTA + FASTQ + alignment scoring)

**Governance + provenance:** `admit` · `governance` (AuthorRecord registry) · `capabilities` · `model_provenance` · `sbom_facade` · `cert_facade`

**Interop:** `rust` + `rust_bridge` (Rust crates via C ABI — regex + base64 + hashing demo) · `python` (opt-in) · `gpu` (CUDA + ROCm + Metal targets) · `simd` (AVX2 + AVX-512 + NEON)

That's **~250 rods total**, all building cleanly against the bootstrap binary. Full per-rod catalog with API surface and stability classification at [`docs/rfcs/rod_manifest.toml`](docs/rfcs/rod_manifest.toml). Deep walkthrough at [`docs/NUCLEOR_FEATURE_INVENTORY.md`](docs/NUCLEOR_FEATURE_INVENTORY.md).

## Memory safety — what the language guarantees

Every Nucleor program at v1.0 gets the following compile-time guarantees, with span-aware diagnostic codes pointing at the offending line:

- **No use-after-drop, no double-free.** `OWN-G4-USE-AFTER-DROP` fires if you read a binding after `vec_free` / `hashmap_free` / `str_free`. Auto-drop is on by default for `Vec` / `HashMap` / `Box` / `String` / `VecDeque` — opt out with `#[manual_drop]` only when you need explicit lifetime control.
- **No use-after-move on conditional paths.** `OWN-G8-COND-MOVE` fires if a binding is moved on one arm of an `if/else` but not the other and you read it after the join.
- **No reads before definite assignment.** `INIT-G11-READ-BEFORE-INIT` fires for `let mut x: T;` followed by an unguarded read. The DA flow analysis allows it when every CFG path assigns before the read.
- **Lifetime soundness.** `BORROW-G2-LIFETIME` fires when a fn with one ref input and a ref return type returns a borrow that doesn't trace back to the input.
- **No silent heap aliasing.** `ALIAS-G3-VEC-OF-REFS` fires when `vec_push` lands on a `Vec<&T>` (pushes a borrow into a Vec where the syntactic tracker can't see element aliasing). `ALIAS-G3-HASHMAP-REHASH` fires when a mutating `hashmap_*` call invalidates an outstanding borrow.
- **Sendable closure propagation across spawn boundaries.** `SEND-G6-HASHMAP` / `SEND-G6-CLOSURE-CAPTURE` / `SEND-G6-TUPLE` / `SEND-G6-ENUM` fire when a spawn-call argument is non-Sendable (recursive capture-set walker — bare-parameter closures stay clean).
- **FFI null contract.** `FFI-G5-NULL-DEREF` fires when you use a raw pointer returned from a `may_return_null` extern fn without a dominating `ptr_is_null(<binding>)` guard. The guard-state lattice intersects at if/else joins.
- **FFI direct-call discipline.** `FFI-G9-MISSING-ALLOW-DIRECT-FFI` fires when you call an extern fn without `#[effect(direct_ffi)]` or `#[allow_effect(direct_ffi)]` on the calling fn.
- **Audited unsafe.** `UNSAFE-G7-MISSING-ALLOW` fires when you write an `unsafe { }` block without `#[effect(unsafe)]` or `#[allow_effect(unsafe)]`. The OSS compiler self-host source contains zero unsafe blocks.
- **Effect annotations.** `EFFECT-G10-UNDECLARED` / `EFFECT-G10-MISSING-ALLOW` / `EFFECT-G10-WRONG-ROW` enforce the contract between declared and produced effects on every fn boundary. Initial vocabulary: `frees`, `borrows_mut`, `may_return_null`, `direct_ffi`, `unsafe`. Spec at [`docs/rfcs/RFC-0062-effects-extension.md`](docs/rfcs/RFC-0062-effects-extension.md).

Every diagnostic has a printable description: `nuc explain CODE`.

## Tour by example

See [`examples/README.md`](examples/README.md) for the full index. The short tour:

**Tier 1 — language tour:**
- [`examples/01_hello.nr`](examples/01_hello.nr) — the smallest possible program.
- [`examples/02_fib.nr`](examples/02_fib.nr) — recursion + iteration.
- [`examples/03_structs.nr`](examples/03_structs.nr) — structs, fields, mutation.
- [`examples/04_rods.nr`](examples/04_rods.nr) — using stdlib rods (strings + JSON).

**Tier 2 — scientific computing:**
- `lorenz` — Lorenz attractor with RK4.
- `vqe_h2` — Variational Quantum Eigensolver for H₂.
- `market_maker` — Black-Scholes + Greeks demo.
- `wing_simulator` — FDTD electromagnetics.

```
nuc build [path] [--release] [-o name]
nuc run [path]
nuc test [file]
nuc check [file]           run all checkers (ownership, type, source, taint, effect)
nuc explain CODE           print the description of a diagnostic code
```

## Verification gate

`tools/verify.sh` runs the full ~1500-step gate (Linux + Windows). Includes:
- Compiler binary smoke
- ABI parity checks (s1 ↔ tools-suite, drift gates)
- Tools-suite rebuild
- Mojibake-clean source enforcement
- Help-coverage (every dispatched cmd in `nuc help`)
- Build + run every example under `examples/`
- Build + run every positive test under `tests/{lang,attrs,runtime,rods,features}/`
- Confirm every `tests/err/*.nr` fails with at least a diagnostic line
- T1.7 bootstrap seed matches current compiler
- T1.8 self-host compiler IR fixed point (md5 stage1 == stage2 == seed)
- PROBE-1: real-world drivers (`nuc build/run/test/check/summary/explain/init/clean`)
- PROBE-2: ML pipeline parity (DT + LR + KMeans + NB) — opt-in via `NUC_VERIFY_ML_PROBE=1`

The gate also enforces a **400 MB peak-allocation budget on the self-host compile** (current: ~185 MB) and tracks per-step timings against `tools/perf_baseline.json` / `tools/perf_baseline_linux.json` for regression detection.

v1.0.0 verify result: **PASS=1518 / SKIP=3 / FAIL=0** on Windows.

## License + contributing

- License: [`LICENSE`](LICENSE) (Apache-2.0)
- Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Security: [`SECURITY.md`](SECURITY.md) — coordinated disclosure via GitHub Security Advisory
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Release index: [`RELEASES.md`](RELEASES.md)
- v1.x roadmap: [`docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md`](docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md) §2A + [`docs/rfcs/RFC-0063-production-readiness-roadmap.md`](docs/rfcs/RFC-0063-production-readiness-roadmap.md)
