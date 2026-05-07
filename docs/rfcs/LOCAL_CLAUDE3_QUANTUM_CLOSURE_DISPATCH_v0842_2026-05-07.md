# Local Claude3 dispatch v0842 - Quantum closure

Audience: local Claude3
Base: fetch current `origin/main` before each queue
Mode: implementation, focused validation, push branch, write report

Stay in the quantum stdlib/runtime/tests lane. Do not edit R05, ROBO-7,
RFC-0063, RT/laws, package/R06, `bin/`, or `bootstrap/` unless a compiler
source change is explicitly required. No Python helpers.

## Queue 1 - QM-7 OpenQASM2 Minimal Interop

Branch:

```text
fix/local-claude3-qm7-openqasm2-minimal-v0842
```

Start:

```powershell
git fetch origin
git checkout -B fix/local-claude3-qm7-openqasm2-minimal-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Goal:

- Close the QM-7 OpenQASM2 interop tail with a minimal, honest surface.
- Prefer deterministic emit/parse helpers in Nucleor stdlib over a compiler
  syntax change.

Primary files:

```text
stdlib/rods/quantum.nr
stdlib/rods/qsim_graph.nr
stdlib/rods/quantum_gates.nr
tests/features/qm7_*.nr
docs/rfcs/v1_PUNCHLIST.md
```

Preferred implementation:

- Add a minimal OpenQASM2 emitter for the already-supported gate subset:
  `OPENQASM 2.0;`, `qreg`, `h`, `x`, `z`, `cx`.
- Add a parser/validator only if it can be kept small and deterministic.
  Otherwise add emit-only plus explicit docs that import remains open.
- Use stable status codes for unsupported gates.

Candidate fixtures:

```text
tests/features/qm7_openqasm2_emit_smoke.nr
tests/features/qm7_openqasm2_unsupported_gate_smoke.nr
```

Validation:

```powershell
.\bin\nucleor.exe build tests\features\qm7_openqasm2_emit_smoke.nr -o _qm7_openqasm2_emit_v0842 --no-cache
.\target\_qm7_openqasm2_emit_v0842.exe
bash tools/check_rod_void_abi.sh
git diff --check
```

Run compiler drift/perf only if compiler or hot toolchain code changes.

Deliverable:

```text
findings/inbox/local_claude3_qm7_openqasm2_minimal_v0842_2026-05-07.md
```

## Queue 2 - QM-6 MPS External Sink / Streaming Range

Start this only after Queue 1 is pushed or explicitly blocked. Fetch current
`origin/main` and start a fresh branch.

Branch:

```text
fix/local-claude3-qm6-mps-streaming-range-v0842
```

Start:

```powershell
git fetch origin
git checkout -B fix/local-claude3-qm6-mps-streaming-range-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Goal:

- Close the remaining QM-6 external-sink/callback-style tail without raising
  full statevector memory caps.
- Keep memory bounded and deterministic.

Preferred implementation:

- Add a bounded `mps_statevector_range_*` sink helper that writes or folds a
  range without materializing a full vector above the cap.
- If callbacks are not first-class enough, implement a deterministic fold API
  such as count/nonzero checksum/sum over a capped range and document why real
  callback streaming remains future work.

Primary files:

```text
stdlib/rods/quantum.nr
stdlib/runtime/quantum_rt.c
tests/features/mps_statevector_range_smoke.nr
docs/rfcs/v1_PUNCHLIST.md
```

Candidate fixtures:

```text
tests/features/mps_statevector_range_fold_smoke.nr
tests/features/mps_statevector_streaming_cap_smoke.nr
```

Validation:

```powershell
.\bin\nucleor.exe build tests\features\mps_statevector_range_fold_smoke.nr -o _mps_range_fold_v0842 --no-cache
.\target\_mps_range_fold_v0842.exe
bash tools/check_rod_void_abi.sh
git diff --check
```

Run perf if runtime hot paths are materially changed.

Deliverable:

```text
findings/inbox/local_claude3_qm6_mps_streaming_range_v0842_2026-05-07.md
```

Include branch, HEAD, base, merge-base, exact quantum surface implemented,
memory-bound reasoning, changed files, validation, and remaining quantum tails.
