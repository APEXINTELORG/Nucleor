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
- **E-9 same-file pure transitive user/requires-row check:** DONE for
  Phase 2b partial on 2026-05-06 — `pure fn` now emits `EFF-001`
  when it calls a same-file user helper whose body directly performs
  print/alloc/ambient side effects, when it calls a same-file function
  declaring a `requires [...]` row, or when it calls a same-file wrapper
  that immediately violates a callee requires row; active fixtures
  `err_pure_transitive_user_effect.nr`, `err_pure_violation.nr`, and
  `err_pure_inference.nr` lock this.
- **E-10/E-11 pure effect-surface expansion:** DONE for another
  Phase 2b partial on 2026-05-06 — `pure fn` now emits `EFF-001`
  for undeclared extern calls, structured scheduling blocks
  (`scope { ... }` / `spawn { ... }`), and `channel(...)`; active
  fixtures `err_pure_extern_default_effect.nr` and
  `err_pure_scope_schedule.nr` lock the first two surfaces.
- **E-12 pure builtin print-family I/O:** DONE for Phase 2b partial on
  2026-05-06 — pure/const/hot body scans now treat `print_*` and
  `eprint*` helper calls as I/O; active fixture
  `err_pure_builtin_io.nr` locks the archived `print_int` case.
- **E-2 `pure fn` + `requires [...]` contradiction:** DONE for
  Phase 1 — `nuc build` emits `EFF-002`; active fixture
  `err_pure_requires.nr` locks this.
- **Standalone `requires [...]` direct calls:** DONE for Phase 1 —
  `nuc build` emits `EFF-001` when a same-file caller invokes a fn
  with a `requires [...]` row but does not declare the required
  effect; active fixture `err_effect_requires_direct.nr` locks this.
- **RFC-0033 `with [...]` subset:** PARTIAL — `with [no_alloc]`
  calling `with [Alloc]` emits `EFF-003`; active fixture
  `err_effects_with_alloc_call.nr` locks this.
- **Block-form `restricts [...] { ... }`:** DONE for Phase 1
  no-silent-trust-gap behavior — `nuc build` emits `EFF-003`
  saying the block form is not yet enforced by s1 and must not be
  relied on as a compile-time guarantee; active fixture
  `err_restricts_builtin_io.nr` locks this.
- **Still open:** full standalone `requires [...]` row enforcement
  beyond bounded same-file/direct-wrapper calls, real block-form
  `restricts [...]` enforcement, deeper transitive `requires [...]` row
  propagation, cross-module propagation, method/closure/higher-order
  effects, and broader RFC-0033 effect-row subtyping.
- **Phase 2b:** effect-row enforcement in the main build path.
- **Phase 4:** Hard error.

### T-3, T-4 — Type system silent fallthrough — Phase 1 DONE; Phase 2b queued

- **T-3 char-cast Phase 1:** DONE v0.8.46 audit-pass info, locked v0.8.78 fixture.
- **T-3 char-cast Phase 2b partial:** DONE for const-foldable
  `as char` codepoints — `nuc build` emits `TYP-026` for values
  outside `0..0x10FFFF` or inside the surrogate range; active
  fixture `err_t3_invalid_char_cast.nr` locks this. Runtime/IR
  char distinctness and non-constant proof remain queued.
- **T-4 empty-type compat Phase 1:** DONE v0.8.79 canary fixture (well-typed path locked; inversion protocol encoded for when Phase 2b strict mode lands).
- **Phase 2b still open:** T-4 strict empty-type compatibility,
  broader T-3 char distinctness, and non-constant char-cast proof.
  The earlier
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

- **PKG-1 (Linux `nuc publish --sign`):** OPEN — needs native
  Linux runner evidence plus publish/sign dry-run or preflight
  closure. Current `nuc publish --sign` delegates from s1 to the
  tools-suite, copies into a local registry, then invokes
  `tools/native_release.ps1` for package signing; the missing closure
  is Linux evidence for that signed publish path plus non-mutating
  package/signing preflight semantics. See
  `findings/inbox/helper2_release_tooling_closure_v0830_2026-05-06.md`.
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
- **Phase 2a round-trip:** DONE 2026-05-05 — `qm7_clifford_reset_rebuild_smoke.nr`
  locks reset-to-zero handle reuse plus repeatable [[5,1,3]] code rebuild
  on fresh code handles.
- **Phase 2b rotated surface d=3:** DONE 2026-05-06 —
  `qm7_clifford_surface_d3_smoke.nr` locks the published Surface-17
  stabilizer/logical set from Tomita/Svore Table II, 9 physical qubits,
  8 generators, distance 3, 27/27 single-qubit detectable errors, and
  non-detectability of the logical `X2 X4 X6` / `Z0 Z4 Z8` operators.
- **Still open for Phase 2 closure:** published weight-enumerator parity.
  Current public Clifford APIs expose distance and detectability, not a
  stabilizer/logical weight-enumerator surface.

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
- **RT-G1 Phase 1.5:** DONE on 2026-05-05 — `#[no_alloc]`
  now rejects direct same-file calls into helpers whose own bodies
  contain known allocation patterns. Remaining gap: deeper
  transitive calls, cross-module callees, and fn-pointer dispatch
  still require the AST/IR traversal pass.
- **Still open:** `#[deadline]` numeric/WCET backing and broader RT
  attribute enforcement audit.

### Algebraic Laws
- Source: `gap-analyses/Nucleor_Algebraic_Laws_Gap_Analysis_and_RFC_2026-05-04.md`
- **Status:** IN FLIGHT — do not remove or demote. Current compiler
  captures `@law(...)` at lex time, has a metadata-only optimizer pass
  scaffold, reserves LAW diagnostics, and has smoke fixtures for
  capture, bounded `--check-laws` validation, and optimizer identity
  eligibility.
- **Phase 1 honesty pass:** DONE in docs on 2026-05-05 — public docs now
  say the current shipped contract is capture + audit metadata, not
  finished user-law rewrites or generated property tests.
- **Phase 2:** wire captured law metadata into verified low-risk
  rewrites (`identity`, `absorbing`, `idempotent`, `involution`) behind
  a proof/check gate.
- **Phase 3a:** DONE on 2026-05-06 — `nuc test --check-laws`
  generates bounded integer checks for low-risk forms (`commutative`,
  `associative`, `identity`, `absorbing`, `idempotent`, `involution`)
  and hard-errors deprecated aliases / unknown names (`LAW-001`,
  `LAW-006`, `LAW-007`, `LAW-008`). Remaining Phase 3 work:
  Arbitrary-driven broad property tests, `distributive_over` /
  `inverse` / `fusion` generation, float `eps` / `approximate`
  semantics, and optimizer rewrite gating.
- **Phase 4:** add cert-profile SMT/proof obligations and float-law
  safeguards (`LAW-002`, `LAW-004`).

## Tier B items (compilation, runtime, execution)

### Interop / FFI
- Source: `gap-analyses/Nucleor_Interop_FFI_Gap_Analysis_and_RFC_2026-05-04.md`
- Already partially closed by RFC-0062 G-5/G-7/G-9 Phase 1+2a. Cross-reference pending.
- **R06 Phase 2/3 rust_bridge ownership harness:** BRANCH-READY on helper2
  v0828 (`fix/helper2-r06-rust-bridge-ownership-harness-v0828`) — adds
  standalone PowerShell and POSIX opt-in harnesses for `rust_free_str`
  ownership evidence. Windows prerequisites are available and the harness
  ran repeated ownership cycles through the focused smoke fixture. The
  broader repeat fixture covers all seven Rust string-returning bridge
  functions. The continuation adds a deterministic `rust_hash_string_fnv1a`
  fixture, `all` fixture selectors, and opt-in machine-readable JSON output
  for future release scripts without wiring the harness into normal verify
  or perf gates. Queue 2 adds no-build self-test mode, fail-closed
  prerequisite simulations for cargo/compiler/artifact, JSON stability
  transcript, future CI allowlist/denylist notes, and a residual blocker
  reduction plan. Remaining R06 work: native POSIX compiler/artifact
  evidence, optional ASAN/valgrind-style leak-signal evidence, and the
  broader cross-boundary ownership contract for Python/shared-library FFI.

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
- **PERF-5 reproducibility routine gate:** DONE 2026-05-06 —
  `tools/verify.sh` now runs `nuc verify-reproducible` against the
  provenance fixture and requires both byte-identical IR and linked
  EXE output. `tools/verify.ps1` already carried the sibling step.
- General CI integration remains open.

## Tier C items (stdlib coherence)

### Numeric Correctness (beyond NUM-G1)
- Source: `gap-analyses/Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md`

### Tensor / ML / Autodiff (beyond ML-1)
- Source: `gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`

### Quantum (beyond QM-7)
- Source: `gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- **QM-6 MPS Bell probability fixture:** DONE for Phase 1+2b on
  2026-05-06 — `mps_prob0(h, q)` exposes single-qubit probability
  readout from the MPS contraction, `mps_prob_basis(h, basis_bits)`
  exposes computational-basis joint probability, and
  `mps_bell_probabilities_smoke.nr` compares Bell-circuit MPS
  marginals plus |00>/|11> joint probabilities against the qsim
  reference expectations. Remaining gap: no bulk statevector extraction
  API.
- **QM-2 qsim statevector checked init:** DONE for Phase 1+2a on
  2026-05-06 — `qsim_init_preflight(n)` returns stable status codes
  (`0=ok`, `1=invalid_qubit_count`, `2=over_capacity`) and
  `qsim_init_checked(n)` returns `0` before dangerous invalid/over-cap
  allocation. `qsim_state_capacity_status_smoke.nr` locks in-range,
  invalid, over-cap, and checked-init behavior. Remaining gap: raw
  `qsim_init(n)` remains an escape hatch for callers that bypass the
  checked wrapper.
- **QM-8/QM-9 qsim_graph gate-DAG status preflight:** DONE for
  Phase 1 on 2026-05-05 — `qsim_gate_record_preflight(q1, q2)`
  returns stable status codes (`0=ok`, `1=out_of_range`,
  `2=dag_full`) before adopters call the raw `qsim_gate_record`
  escape hatch. Focused fixture covers valid one-qubit/two-qubit
  args, out-of-range args, and a filled 4096-slot DAG. Remaining
  gap: raw C runtime still returns `-1`; no auto-entangle or
  thread-safety semantics are implied.
- **QM-9 checked qsim gate-record wrapper:** DONE for Phase 1 on
  2026-05-05 — `qsim_gate_record_checked(name, q1, q2)` returns
  real gate IDs on success and structured negative status
  (`-1=out_of_range`, `-2=dag_full`, `-3=unknown raw failure`).
  The raw C runtime ABI remains unchanged.
- **R11-D4 qsim auto-entangle:** DONE for Phase 2a on 2026-05-06 —
  `qsim_cnot`, `qsim_cz`, `qsim_crk`, and `qsim_ccx` now
  auto-register with `qsim_graph`'s entanglement tracker in the same
  semantic places their trace hooks declare entanglement. `qsim_swap`
  inherits this through its existing CNOT decomposition. Remaining
  gaps: raw gate-DAG auto-recording and pthread/async thread-safety.
- **R11-D4 qsim gate-DAG auto-record:** DONE for Phase 2b on
  2026-05-06 — the same high-level qsim entangling wrappers now call
  `qsim_gate_record_checked` after the wrapped operation. `qsim_swap`
  inherits three CNOT records through its decomposition. `qsim_ccx`
  records two control-target relationships because the public checked
  record surface is two-qubit. Remaining gap: process-local graph
  state is not thread-safe across pthread/async boundaries.
- **R11-D4 qsim graph lifecycle auto-record closure:** DONE for
  Phase 2d on 2026-05-06 — focused coverage now locks
  `qsim_graph_clear()` resetting both entanglement and gate-DAG state,
  fresh post-clear qsim runs starting with zero graph counts, exact
  one-record behavior for CNOT/CZ/CRK, inherited three-record SWAP, and
  the documented two-control-target CCX representation. Remaining gap:
  process-local graph state is not thread-safe across pthread/async
  boundaries.
- **R11-D4 qsim graph query contract:** DONE for Phase 2e on
  2026-05-06 — `qsim_graph_query_contract_smoke.nr` now locks public
  `qsim_gate_dag_parent_count`, `qsim_gate_dag_parent_at`, and
  transitive `qsim_gate_dag_depends_on` behavior after mixed checked
  records plus high-level CNOT/CZ/CRK/SWAP auto-recording. Remaining
  gap: process-local graph state is not thread-safe across pthread/async
  boundaries.
- **QM-11 diff_sim checked init:** DONE for Phase 1+2a on 2026-05-06
  — `diff_sim_init_preflight(nq, n_cores)` exposes stable status
  codes for invalid/over-cap qubits and cores, and
  `diff_sim_init_checked(nq, n_cores, mode_bits, seed)` returns `0`
  before native clamp behavior. `diff_sim_capacity_status_smoke.nr`
  locks the public 12-qubit, 16-core, 200-gate cap surface. Remaining
  gap: raw `diff_sim_init(...)` remains an escape hatch for callers
  that bypass the checked wrapper.
- **QM-12 shared gate constants:** DONE for the common gate subset on
  2026-05-06 — `quantum_gates.nr` now provides shared H/CNOT/X/Z IDs
  consumed by both MPS and diff_sim, with `quantum_gate_constants_smoke.nr`
  locking cross-rod consistency. Remaining gap: rotation IDs are still
  rod-specific (`MPS RZ=4/RX=5`, `diff_sim RZ=6`) until native dispatch
  tables unify or a typed enum lands.
- **QM-13 schedule overlap / checked insertion:** DONE for Phase 1+2a
  on 2026-05-06 — `schedule_validate_no_same_qubit_overlap(sched)`
  detects same-qubit pulse overlap and malformed schedules, and
  `schedule_push_at(&mut sched, pulse, qubit, start_ns)` now supports
  backend-parallel insertion with same-qubit overlap rejection. Legacy
  `schedule_push` remains serialized append. Remaining gap: no backend
  calibration/resource scheduler or hardware target lowering.
- **QM-14 logical-qubit registry cap + partial release:** DONE for
  Phase 1+2a on 2026-05-06 — `logical_qubit_max_registry`,
  `logical_qubit_registry_preflight`, slots-remaining helpers,
  `logical_qubit_release(lq)`, and `logical_qubit_release_handle(handle)`
  are fixture-backed by `logical_qubit_registry_capacity_smoke.nr`.
  Released slots are reused and `logical_qubit_clear()` still wipes the
  process-local registry. Remaining gap: registry remains process-local
  and not thread-safe.

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

- **TOOLCHAIN-PY-1 — Remove Python from self-host compiler reproducibility compare:** DONE 2026-05-06. Python interop (`stdlib/rods/python.nr` + `python_rt.c`) remains intentional and is not part of this item. Maintenance generators under `tools/*.py` can stay for now. The product/toolchain path no longer shells out to `python -c "import filecmp"` inside `verify-reproducible`; Windows uses `fc /B`, POSIX keeps `cmp -s`, and the compiler/seed artifacts were rebuilt and promoted through the normal md5/drift/perf validation lane. Helper2 Queue 4 reclassified the residual Python references as intentional interop, maintenance-only, optional doctor, or test/reference material; see `findings/inbox/helper2_release_tooling_closure_v0830_2026-05-06.md`.

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
  stabilizer Vec wrappers, a [[5,1,3]] distance/detectable-error smoke
  fixture, and reset/rebuild round-trip coverage. The compiler Tier-C
  disclosure was updated so imports no longer claim zero Clifford
  coverage. Rotated surface-code and published weight-enumerator parity
  remain open.
- **2026-05-06**: QM-7 Phase 2b adds rotated Surface-17 d=3 fixture
  coverage from Tomita/Svore Table II. Remaining open item is published
  weight-enumerator parity, blocked on a new Clifford rod enumerator API.
- **2026-05-05**: Effect/capability Phase 1 advanced again.
  Block-form `restricts [...] { ... }` now emits `EFF-003` during
  `nuc build` instead of accepting or misparsing an unenforced
  guarantee. Real restricts-block effect enforcement remains open.
- **2026-05-06**: Effect/capability Phase 2b partial advanced.
  `pure fn` now rejects same-file calls into user helpers whose bodies
  directly perform print/alloc/ambient side effects; active fixture
  `err_pure_transitive_user_effect.nr` locks the transitive helper
  case. Full `requires [...]` transitive row propagation, real
  restricts-block enforcement, cross-module propagation, and
  RFC-0033 row subtyping remain open.
- **2026-05-06**: Effect/capability Phase 2b partial advanced again.
  `pure fn` now rejects undeclared extern calls and structured scheduling
  in the build path with `EFF-001`; fixtures
  `err_pure_extern_default_effect.nr` and `err_pure_scope_schedule.nr`
  moved out of `_unimplemented/`.
- **2026-05-06**: Effect/capability Phase 2b fixture promotion advanced.
  Archived pure negatives for builtin print-family I/O, direct
  `requires [...]` callee calls, and immediate wrapper inference now live
  under `tests/err/` as `err_pure_builtin_io.nr`,
  `err_pure_violation.nr`, and `err_pure_inference.nr`.
- **2026-05-06**: TOOLCHAIN-PY-1 closed. `nuc verify-reproducible`
  no longer requires Python for its Windows byte-compare path; it
  now uses `fc /B` for linked binary comparison and retains `cmp -s`
  for POSIX. Python interop rods remain intentional and unchanged.
- **2026-05-06**: PERF-5 closed for the canonical bash gate.
  `tools/verify.sh` now includes a routine RFC-NRT-003
  `verify-reproducible` step requiring byte-identical IR and EXE
  outputs for `tests/fixtures/t477_provenance_section.nr`.
