# Nucleor v1.0 Launch Punchlist

**Status:** Active spec (started 2026-05-04)
**Source RFCs:** `docs/rfcs/gap-analyses/` (14 RFCs)
**Companion plans:** `RFC-0062-IMPLEMENTATION-PLAN.md` (memory safety, in flight)

This file is the canonical sequenced punchlist for Nucleor v1.0
public OSS launch. It integrates the 14 gap-analysis RFCs
delivered 2026-05-04 with the in-flight RFC-0062 memory-safety
work. Items are sequenced for maximum parallelism subject to
the user directive: **memory safety closes first; the other 13
RFCs are first-class punchlist items after that.**

Each line carries a tracking code, severity, source RFC, and
ship-status. Items advance through the same Phase 1 / 2a / 2b /
3 / 4 sequence used for RFC-0062. Phase 4 = v1.0 hard-error cut.

## Active (in flight)

### RFC-0062 — Memory Safety / Borrow / Ownership

| Phase | Status | Notes |
|---|---|---|
| Phase 1 | DONE | v0.8.17–v0.8.20 (11 gaps) |
| Phase 2a Wave A | DONE | v0.8.24–v0.8.36 (8 audit-pass info diagnostics) |
| Phase 2b-1/2/2.5/2.6/2.7 | DONE | v0.8.31, .32, .35, .37, .41, .42 (manual_drop wired, audit, classifier, annotations) |
| Phase 2b-3-experiment | DONE | v0.8.38/39 (env-gated NUC_AUTO_DROP_DEFAULT=1) |
| Phase 2b-3-trace | DONE | v0.8.64 — root-caused as cache-key bug; cache_v2_canonical_flags didn't include NUC_AUTO_DROP_DEFAULT |
| Phase 2b-3 final | DONE | v0.8.75 — unconditional default-flip landed |
| G-3 dataflow handoff suppression | DONE | v0.8.74 + v0.8.76/.77 regression coverage |
| G-4 double-free guard | DONE | v0.8.68/.69 (sentinel-based) |
| Phase 3 (deny-by-default) | QUEUED | v0.9 cut |
| Phase 4 (hard-error) | QUEUED | v1.0 cut |

## CRITICAL silent-miscompute / launch-blocker (Tier-A-priority across all RFCs)

These bubble up from across the 14 RFCs. They block OSS public
launch. After memory safety completes, these are next-priority.

### NUM-G1 — f64 lex truncation to 6 decimal digits — RETIRED

- **Status:** RETIRED (2026-05-04, v0.8.66) — probe verified bit-identical-to-strtod for 16-digit literals on v0.4.180. Original gap-RFC headline does not reproduce. Audit-pass diagnostic dropped to avoid wrong-class flagging adopter code.
- **Note:** A different bug (int_part overflow at >=1e13 — compile-time PANIC) exists; queued separately if it ever needs Phase 1 audit.

### ML-1 — `nuc_attn_flash` ABI mismatch — DONE

- **Status:** DONE — primary fix v0.8.45 (nuc_attn_flash 6→7 args). Sister fixes v0.8.66 for nuc_attn_gqa (7→8), nuc_attn_mla_compress/decompress (5→4).
- **Test:** ABI parity verified by helper_manifest drift gate.

### C-1, C-2, C-3 — Concurrency — DONE

- **C-1 cancel_token (Win32 + POSIX impls):** DONE v0.8.83 (helper agent — InterlockedExchange64 / __sync_lock_test_and_set + smoke fixture).
- **C-2 POSIX channel:** DONE v0.8.85 (pthread_mutex + 2x cond_var bounded-FIFO mirroring Win32 semantics; finding `findings/promoted/2026-05-04-c-2-posix-channel-stub-...` closed).
- **C-3 ordered atomic C backing:** DONE v0.8.86 — reclassified as wrong-class. Compiler emits LLVM atomic intrinsics directly (atomicrmw / load atomic / store atomic / cmpxchg); C-fallback path doesn't fire. Regression canary `tests/features/c3_ordered_atomics_direct_smoke.nr` locks behavior.
- **POSIX validation:** still pending Linux CI runner; fixtures stage ready.

### E-1, E-2, E-3 — Effect / Capability trust gap

- **Source:** `gap-analyses/Nucleor_Effect_Capability_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** TRUST GAP (effect rows are still incomplete)
- **E-1 direct `pure fn` side effects:** DONE for Phase 1 —
  `nuc build` emits `EFF-001` for direct print/alloc/ambient-capability
  use; active fixtures `err_pure_print_build.nr` and
  `err_pure_ambient_random.nr` lock this.
- **E-2 `pure fn` + `requires [...]` contradiction:** DONE for
  Phase 1 — `nuc build` emits `EFF-002`; active fixture
  `err_pure_requires.nr` locks this.
- **RFC-0033 `with [...]` subset:** PARTIAL — `with [no_alloc]`
  calling `with [Alloc]` emits `EFF-003`; active fixture
  `err_effects_with_alloc_call.nr` locks this.
- **Still open:** standalone `requires [...]` row enforcement,
  block-form `restricts [...]`, transitive user-call effect inference,
  and cross-module propagation.
- **Phase 2b:** effect-row enforcement in the main build path.
- **Phase 4:** Hard error.

### T-3, T-4 — Type system silent fallthrough — Phase 1 DONE; Phase 2b queued

- **T-3 char-cast Phase 1:** DONE v0.8.46 audit-pass info, locked v0.8.78 fixture.
- **T-4 empty-type compat Phase 1:** DONE v0.8.79 canary fixture (well-typed path locked; inversion protocol encoded for when Phase 2b strict mode lands).
- **Phase 2b for both:** queued — needs compiler edit. The earlier
  v0.8.79/v0.8.83 Windows-PE link-hang concern is no longer treated
  as a current blocker after v0.8.319 rebuilt/promoted
  `bin/nucleor.exe` + `bootstrap/nucleor_s1_seed.ll`, passed
  self-host fixed-point, and compiled focused user fixtures.

### BOOT-3, BOOT-4 — Self-host fixed-point integrity

- **Source:** `gap-analyses/Nucleor_Self_Hosting_Bootstrap_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** SELF-HOST INTEGRITY
- **Status:** DONE — `tools/check_self_host_md5.sh` builds the full
  self-host compiler twice, compares stage1/stage2 emitted compiler IR,
  and compares stage2 IR against `bootstrap/nucleor_s1_seed.ll`.
- **Evidence:** 2026-05-05 gate PASS, md5
  `9c991a17cfa5b0f97a8ce0021cac6fe3`.

### PKG-1, PKG-3 — Packaging

- **PKG-1 (Linux `nuc publish --sign`):** OPEN — needs Linux runner.
- **PKG-3 (semver resolver) — DONE for v1.0 syntax surface:**
  - caret `^X.Y.Z` v0.8.89
  - tilde `~X.Y.Z` v0.8.90
  - wildcard `*` / `X.*` / `X.Y.*` v0.8.91
  - comparison `>=` `<=` `>` `<` v0.8.92
  - compound `>=A <B` v0.8.93
  - lockfile-driven resolution remains v1.x.

### QM-7 — Clifford rod test coverage — Phase 1 DONE

- **Status:** DONE v0.8.87/.88 — 12 deterministic correctness assertions covering init/lifecycle, single-qubit gates (X/Y/Z/S/S^4), two-qubit (CNOT^2 identity, control-zero no-op), entanglement (Bell, GHZ).
- **Phase 2a:** DONE 2026-05-05 — `qm7_clifford_distance_5qubit_smoke.nr`
  locks typed `Vec<i64>` stabilizer insertion plus the known [[5,1,3]]
  perfect-code distance and 15/15 single-qubit detectable-error count.
- **Still open for Phase 2 closure:** surface-code distance d=3 rotated
  planar and weight-enumerator validation against published code.

### ROBO-7 — Frame-typing safety

- **Source:** `gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** SAFETY (Mars Climate Orbiter failure mode is live)
- **Status:** OPEN — needs new types + compiler edit. Compiler-edit
  shipping is unblocked by v0.8.319 evidence; implementation remains
  queued behind higher-priority trust-gap closure.
- **Phase 1:** Add unit-of-measure tagging to frame types.
- **Phase 2b:** Compile-time check that frame tags are consistent across operations.

### PERF-11 — bisect_mem threshold — DONE

- **Status:** DONE v0.8.84 — `EXCURSION_MB` raised 600 → 750 MB to match baseline+10% (747 MB ceiling). False-positive on every run eliminated.

## Other Tier A items (not on critical-findings list but still launch-blockers)

### Real-Time / Determinism
- Source: `gap-analyses/Nucleor_RealTime_Determinism_Gap_Analysis_and_RFC_2026-05-04.md`
- Phase 1: audit `#[deadline]` / `#[no_alloc]` enforcement.

### Algebraic Laws
- Source: `gap-analyses/Nucleor_Algebraic_Laws_Gap_Analysis_and_RFC_2026-05-04.md`
- **Status:** IN FLIGHT — do not remove or demote. Current compiler
  captures `@law(...)` at lex time, has a metadata-only optimizer pass
  scaffold, reserves LAW diagnostics, and has smoke fixtures for
  capture / `--check-laws` acknowledgment / optimizer identity
  eligibility.
- **Phase 1 honesty pass:** DONE in docs on 2026-05-05 — public docs now
  say the current shipped contract is capture + audit metadata, not
  finished user-law rewrites or generated property tests.
- **Phase 2:** wire captured law metadata into verified low-risk
  rewrites (`identity`, `absorbing`, `idempotent`, `involution`) behind
  a proof/check gate.
- **Phase 3:** add generated property tests for `nuc test --check-laws`
  and canonical-law validation (`LAW-001`, `LAW-006`, `LAW-007`,
  `LAW-008`).
- **Phase 4:** add cert-profile SMT/proof obligations and float-law
  safeguards (`LAW-002`, `LAW-004`).

## Tier B items (compilation, runtime, execution)

### Interop / FFI
- Source: `gap-analyses/Nucleor_Interop_FFI_Gap_Analysis_and_RFC_2026-05-04.md`
- Already partially closed by RFC-0062 G-5/G-7/G-9 Phase 1+2a. Cross-reference pending.

### Performance Envelope (beyond PERF-11)
- Source: `gap-analyses/Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md`
- **R13-D5 POSIX real RSS e-stop parity:** DONE on main
  2026-05-05 (`fb8b7c0b`) — adds Linux `/proc` process-tree cap
  wrapper and removes the soft `NUC_TRACE_ALLOC` green fallback from
  memory-budget gates.
- **R10-D3 POSIX cold/hot perf gate prep:** INTEGRATED on main
  2026-05-05 (`1a962893`) — adds `tools/check_perf_regression.sh`,
  wires the POSIX perf monitor into `tools/verify.sh`, refuses WSL /
  Windows `.exe` interop as RSS evidence, and documents native Linux
  validation. Native Linux transcript still required before R10-D3
  can be marked closed.
- General CI integration remains open.

## Tier C items (stdlib coherence)

### Numeric Correctness (beyond NUM-G1)
- Source: `gap-analyses/Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md`

### Tensor / ML / Autodiff (beyond ML-1)
- Source: `gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`

### Quantum (beyond QM-7)
- Source: `gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`

### Robotics (beyond ROBO-7)
- Source: `gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`

## Sequencing — proposed waves

### Wave 0 (now): Memory Safety closure
- Resolve Phase 2b-3-trace mystery
- Land Phase 2b-3 unconditional flip
- Phase 3 + Phase 4 follow

### Wave 1 (parallel after Wave 0 unblocks): Critical silent-miscompute findings
Each gets its own ship sequence (Phase 1 docs/audit → Phase 2a info → Phase 2b
proper analysis → Phase 4 hard error):
- NUM-G1 (priority — affects every float user)
- ML-1 (priority — silent miscompute on adopter ML code)
- T-3, T-4 (silent fallthroughs)
- C-1, C-2 (Linux concurrency)
- E-1, E-2, E-3 (effect trust gap)
- BOOT-3, BOOT-4 (self-host integrity) — DONE

### Wave 2: Other Tier A + Tier B
- Real-Time / Determinism enforcement
- Algebraic Laws property tests
- Interop / FFI extensions
- Module / Packaging fixes (PKG-1, PKG-3)

### Wave 3: Tier C correctness
- Numeric beyond NUM-G1
- Tensor/ML beyond ML-1
- Quantum (QM-7 first)
- Robotics (ROBO-7 first)

### Wave 4: v1.0 cut
- All Phase 4 promotions land together
- Adopter migration window 30 days

## Deferred tail (do not preempt active lanes)

- **TOOLCHAIN-PY-1 — Remove Python from self-host compiler reproducibility compare:** DEFERRED. Python interop (`stdlib/rods/python.nr` + `python_rt.c`) remains intentional and is not part of this item. Maintenance generators under `tools/*.py` can stay for now. The deferred cleanup is only the product/toolchain path where `compiler/nucleor_s1_compiler.nr` shells out to `python -c "import filecmp"` inside `verify-reproducible`; replace it later with a Nucleor/toolchain-native byte comparison, then rebuild/promote `bin/nucleor.exe` and `bootstrap/nucleor_s1_seed.ll` with normal md5/drift/perf validation.

## Updates log

- **2026-05-04** v0.8.43: Punchlist file created. 14 gap RFCs integrated into spine. RFC-0062 memory-safety remains in flight; other 13 queued behind it.
- **2026-05-04** v0.8.113: Punchlist refreshed to reflect v0.8.45 → v0.8.112 progress. RFC-0062 Phase 2b-3 final landed v0.8.75 (unconditional default-flip). NUM-G1 retired (probe wrong-class). NUM-G2 fully closed (math_abs/gcd/lcm v0.8.80, math_pow_int v0.8.81). NUM-G8 closed (TLS overflow flag v0.8.82). C-1/C-2/C-3 closed (helper v0.8.83, me v0.8.85/.86). ML-1 closed (v0.8.45/.66 sisters). T-3/T-4 Phase 1 done (audit + canary). PKG-3 fully closed for v1.0 semver (v0.8.89-.93). PERF-11 closed (v0.8.84). QM-7 Phase 1 done (12 assertions v0.8.87/.88). 16 stdlib rods first-coverage (v0.8.94 - .112). 4 pre-existing bugs surfaced; 3 fixed (CSV trailing-empty v0.8.105, dt mktime/gmtime v0.8.106, bm25 doc_count v0.8.108). At that snapshot, E-1/2/3, BOOT-3/4, NUM-G9, ROBO-7 remained OPEN pending compiler-edit ship proof. PKG-1 needs Linux runner.
- **2026-05-05**: BOOT-3/BOOT-4 rechecked against current `tools/check_self_host_md5.sh`; the live gate already verifies full compiler self-IR fixed point and seed md5, not a smoke proxy. Marked DONE with md5 `9c991a17cfa5b0f97a8ce0021cac6fe3`.
- **2026-05-05** v0.8.319: Compiler-edit ship path revalidated.
  Rebuilt/promoted `bin/nucleor.exe` and `bootstrap/nucleor_s1_seed.ll`
  from a compiler source edit, proved self-host fixed-point md5
  `fc9c22e7b2e36a43eb6705071bd3db16`, rechecked focused EFF user
  fixtures, and passed the perf gate at cold 3.57s / 309MB
  process-tree RSS. The prior Windows-PE link-hang concern is no
  longer a current blocker for queued compiler-edit punchlist lanes.
- **2026-05-05** v0.8.320: Effect/capability Phase 1 advanced.
  `pure fn ... requires [...]` now emits `EFF-002` during `nuc build`;
  promoted `err_pure_requires.nr` from `_unimplemented/` into the
  active negative suite and added missing EXPECT headers to active
  import-cycle helper fixtures. Self-host fixed-point md5:
  `697bea7d73dc8d72ceeba86e9b886f79`; perf gate: cold 3.60s / 307MB
  process-tree RSS.
- **2026-05-05**: POSIX cold/hot perf gate prep integrated on main
  (`1a962893`). The gate is wired but intentionally refuses WSL/interop;
  native Linux evidence is still required for R10-D3 closure.
- **2026-05-05**: QM-7 Phase 2a advanced with typed Clifford
  stabilizer Vec wrappers and a [[5,1,3]] distance/detectable-error
  smoke fixture. The compiler Tier-C disclosure was updated so imports
  no longer claim zero Clifford coverage. Rotated surface-code and
  published weight-enumerator parity remain open.
