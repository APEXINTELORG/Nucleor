# Benchmarks

Numbers below are reproducible from this repo with `nuc bench`. The intent is to
characterize the v0.2 self-host bootstrap pipeline, not to compete with mature
production compilers — that comparison comes after v1.0.

## Self-host build time

Building the full self-host compiler from source on a laptop-class machine:

| Stage | Wall time |
|---|---|
| Clean self-build of `compiler/nucleor_s1_compiler.nr`         | ~27 s |
| Internal timed build (excluding clang link)                   | ~24 s (type-check dominates) |
| Same build with module cache hit                              | sub-second IR cache; ~5 s clang link |

The compiler itself is one `.nr` file (~467 KB source / **8897 LOC** /
**365 reachable functions** after dead-code elimination /
**664 optimizer instructions** / 3932 strings) producing a
**~2.6 MB LLVM IR module** that clang then turns into the
**~845 KB `nucleor.exe` binary**. Numbers as of v0.2.97 — bumped
from v0.1-era estimates (~330 KB / 5700 functions / 10000 LOC /
1.8 MB IR / 3 MB binary). The `nucleor.exe` binary is roughly a
quarter of the v0.1-era size because the optimizer + DCE pass
shipped in the v0.1.46–v0.1.65 chain stripped most of the
unreachable surface.

## Hello-world build time

```
nuc build examples/01_hello.nr -o hello
```

End-to-end compile time on the same machine: under 200 ms (cold), under 50 ms (warm cache). The breakdown is dominated by the clang link step, not Nucleor's own pipeline.

## Quantum simulator throughput

`examples/05_quantum.nr` runs 1024 shots of a 2-qubit Bell-state preparation (`H` then `CNOT` then measure both qubits). Total wall time including init, gate application, and measurement collapse: under 50 ms on a single core.

For comparison, the same circuit in `nuc bench tests/rods/quantum_basic.nr` over 200 shots reproduces perfect entanglement (`q0 == q1` every time, 0 violations).

## Reproducing benchmarks

```
nuc bench compiler/nucleor_s1_compiler.nr   --iterations 5
nuc bench examples/05_quantum.nr            --iterations 10
```

`nuc bench` builds the source once, then runs the resulting binary `--iterations` times (default 10) with `--warmup` runs before timing (default 1). It reports min, max, median, and mean wall time.

## What is not benchmarked here

- Backend codegen quality (LLVM does most of the work; Nucleor IR is small and friendly to the optimizer).
- Memory footprint (no formal accounting yet).
- Compile speed vs. other systems (apples-to-apples requires equivalent programs in each language; deferred to v1.0).

If you have a benchmark you'd like to see, open an issue at
https://github.com/APEXINTELORG/Nucleor.
