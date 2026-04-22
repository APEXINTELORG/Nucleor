# RFC-0009 — Static WCET via Heptane Integration

| Field | Value |
|---|---|
| **Number** | 0009 |
| **Title** | Static worst-case execution time analysis via Heptane integration |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.7.0 ("AI Training + Real-Time Linux") |
| **Depends on** | RFC-0001 (`#[deadline]`), RFC-0006 (`#[require]`/`#[ensure]` provide loop-bound info) |

---

## 1. Summary

Add a `--profile=cert` build mode that runs **Heptane** (open-source
WCET analyzer from IRISA, used in real safety-critical systems) over
the LLVM `MachineInstr`-level output of `#[deadline]`-annotated
functions to produce **provable** upper bounds on execution time.

```nucleor
#[no_alloc, no_panic, deadline = 100us]
fn ekf_update(state: &mut Ekf, z: &Vec<f64, Pool>) {
    assume!(z.len() == 12);
    for i in 0..12 { ... }
}

// nuc check --profile=cert
// Output:
//   ekf_update: WCET 84.3 us @ 168 MHz Cortex-M4F (provable)
//   ekf_update: WCET 11.2 us @ 1 GHz Cortex-A72 (provable)
//   --> within deadline 100 us ✓
```

For users who need **safety certification** (ISO 26262 ASIL-D, IEC
61508 SIL-3, DO-178C Level A), the runtime-checked `#[deadline]`
from RFC-0001 is insufficient — they need static proof. Heptane
provides this for ARM Cortex-M and Cortex-A.

---

## 2. Motivation

RFC-0001 ships `#[deadline]` with **runtime** enforcement (HW timer
trap on overrun). That's sound — overruns are caught — but it's not
**provable**. Cert auditors require an upper bound that's known
before deployment.

Static WCET is a 30-year research field. Tools:

| Tool | Status | Targets |
|---|---|---|
| **aiT** (AbsInt) | Commercial; gold standard. Used in Airbus, Boeing. | x86, ARM, PowerPC, many MCUs |
| **Bound-T** (Tidorum) | Commercial; defunct | Many MCUs |
| **Heptane** (IRISA) | **Open source**, BSD license | ARM Cortex-M, MIPS |
| **Chronos** (NUS) | Open source | ARM, x86 |
| **OTAWA** (IRIT) | Open source | ARM, PowerPC, RISC-V (research) |

Heptane is the right pick: open source, ARM-strong (matches our
embedded targets), and actively maintained. We integrate it as an
optional backend.

---

## 3. Design

### 3.1 Build profile

```
nuc check --profile=cert <project>
```

Pipeline:
1. Compile the project as usual to LLVM `.ll`.
2. Lower to target `MachineInstr` (`llc -O3 -march=thumbv7em ...`).
3. Disassemble the `.o` file.
4. Invoke Heptane on each `#[deadline]`-annotated function.
5. Compare Heptane's WCET against the declared deadline.
6. Emit `nuc check` report; fail build if any deadline exceeded.

### 3.2 Loop-bound annotations

Heptane requires loop-bound info. Sources:
- `assume!(arr.len() == N)` (RFC-0004) — implies trip count
- `#[require(arr.len() <= N)]` (RFC-0006)
- `for i in 0..N` literal — direct
- `#[loop_bound(N)]` attribute (NEW) — explicit

```nucleor
#[no_alloc, deadline = 50us]
fn process(arr: &[f64; 32]) {
    #[loop_bound(32)]
    for i in 0..arr.len() { ... }
}
```

### 3.3 Per-target cost tables

Heptane needs instruction-level cycle counts. Ships baselines for:
- Cortex-M0+ (1 cyc most, 32 cyc div)
- Cortex-M3 (1-2 cyc most)
- Cortex-M4F (1-2 cyc, 14-cyc divide, 1-cyc FPU)
- Cortex-M7 (dual-issue, more complex; conservative bounds)
- Cortex-A53 (in-order, simpler)
- Cortex-A72 (out-of-order, very conservative bounds — accept loose)

Cost tables in `tools/wcet/cost_tables/<target>.toml`.

### 3.4 Compositional analysis across calls

Heptane analyzes one function at a time. Cross-function propagation:

For each `#[deadline = T_callee]` function, the WCET upper bound
becomes part of the caller's analysis (instead of re-analyzing the
callee body). This makes large programs analyzable.

The compiler emits a `<function>.wcet` sidecar file per
`#[deadline]` function with its proven WCET. Callers consume the
sidecar.

### 3.5 Indirect calls and `#[no_dyn]`

Heptane cannot analyze indirect calls without conservative bounds.
RFC-0001's `#[no_dyn]` makes all calls direct, enabling tight
analysis. **`--profile=cert` requires `#[no_dyn]` on all
`#[deadline]` functions**; if a function has `#[deadline]` but not
`#[no_dyn]`, the compiler errors WCET-001.

### 3.6 Cache modeling

WCET on systems with cache is hard. Heptane supports:
- "No cache" mode (worst case: every load is L3 latency)
- LRU cache with per-platform parameters (set associativity, line size)

For cert profile on Cortex-A class, default to no-cache for safety.
Users can provide platform-specific cache config in
`nuc.toml [wcet.cache]` if they want tighter bounds.

### 3.7 Diagnostics

| Code | Meaning |
|---|---|
| WCET-001 | `#[deadline]` function uses dynamic dispatch (cert profile only) |
| WCET-002 | Loop bound unknown — add `#[loop_bound(N)]` or `assume!(arr.len() == N)` |
| WCET-003 | WCET exceeds declared deadline |
| WCET-004 | Indirect-call bound unknown |
| WCET-005 | Recursive call exceeds `#[max_depth]` (RFC-0014) |
| WCET-006 | Heptane analysis failed (internal tool error) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Driver | New `--profile=cert` mode | ~150 |
| Heptane integration | Subprocess + IR/asm bridging | ~600 |
| Loop-bound annotations | `#[loop_bound]` parse + propagate | ~150 |
| Sidecar `.wcet` files | Emit + consume | ~200 |
| Cost tables | Per-target TOML | ~300 |
| Diagnostics | WCET-001…006 | ~200 |
| **Total** | | **~1600** |

Plus shipping Heptane binary as a build dependency (~few MB).

---

## 5. Alternatives considered

- **aiT (commercial)** — gold standard but $$$. Defer; can ship as
  optional backend in v0.8.
- **In-house WCET analyzer** — multi-year. Don't reinvent.
- **Measurement-based timing analysis (MBTA)** — empirical, not
  provable. Useful for v0.5 (`nuc check --wcet` runs benchmarks);
  not enough for cert.
- **Skip cert profile entirely** — abandons safety-cert path.
  Rejected per the Decisions doc commitment.

## 6. Open questions

1. Distribute Heptane binary, or require user to install? Recommend
   distribute via `nuc install heptane` after dependency-manager lands.
2. Cache-modeling defaults — conservative (no-cache) or platform-
   specific? Per project; default to conservative.
3. WCET bound caching — invalidate when source changes; rebuild on
   demand. Standard incremental-build problem.
4. RISC-V — Heptane has limited support. Add OTAWA as alternative
   backend in v0.8?

## 7. Definition of done

- [ ] `--profile=cert` mode works on Linux + Windows
- [ ] Heptane integrated, runs on Cortex-M4F + Cortex-A72 targets
- [ ] Cost tables shipped for at least M4F, A72, RV32IMAC
- [ ] WCET-001…006 diagnostics fire correctly
- [ ] Demo: PID controller proven within 100 µs deadline on M4F
- [ ] CHANGELOG documents cert profile + provable WCET

## 8. Future extensions

- aiT backend (commercial)
- OTAWA backend (RISC-V)
- Cache-aware analysis tighter bounds
- Multi-core analysis with shared-cache contention modeling

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.7 schedule
- [ ] LOC budget ~1600 fits
- [ ] Pitch survives ("provable WCET, free, OSS, ARM-strong, integrates
      with `#[deadline]`")
