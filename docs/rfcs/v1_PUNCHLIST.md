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
| Phase 2b-3-trace | OPEN | Why seed IR byte-identical under flip — H1-H4 hypotheses |
| Phase 2b-3 final | BLOCKED on trace | Unconditional default-flip ship |
| Phase 3 | QUEUED | Default-on with `#[manual_drop]` opt-out |
| Phase 4 | v1.0 cut | Hard error, `#[manual_drop]` deprecated |

## CRITICAL silent-miscompute / launch-blocker (Tier-A-priority across all RFCs)

These bubble up from across the 14 RFCs. They block OSS public
launch. After memory safety completes, these are next-priority.

### NUM-G1 — f64 lex truncation to 6 decimal digits

- **Source:** `gap-analyses/Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** LAUNCH-BLOCKER (silent miscompute — affects every float user)
- **Symptom:** `3.1415926535897932` becomes `3.141592` at lex time. No diagnostic.
- **Phase 1:** Audit-pass info diagnostic counting f64 literals with >6 decimal digits.
- **Phase 2b:** Lex-time precision-preserving f64 parser.
- **Phase 4:** Hard error if precision loss is non-zero.
- **Test:** `tests/lang/numeric_lex_precision.nr` — assert `3.1415926535897932 != 3.141592`.

### ML-1 — `nuc_attn_flash` ABI mismatch

- **Source:** `gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** LAUNCH-BLOCKER (silent miscompute on every flash-attention call)
- **Symptom:** rod takes 6 args; C runtime takes 7. The 7th C arg is read from uninitialized stack.
- **Phase 1:** Fix the rod signature OR fix the C signature. Add ABI parity test.
- **Phase 2b:** Helper-manifest ABI parity gate at compile time.
- **Test:** `tests/runtime/nuc_attn_flash_abi.nr` — call with known inputs, verify deterministic output.

### C-1, C-2 — Concurrency (Linux silently broken)

- **Source:** `gap-analyses/Nucleor_Concurrency_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** LAUNCH-BLOCKER (Linux), needs spot-test
- **Symptom:**
  - C-1: cancel token is a linker bomb (extern fn declared, body absent on Linux).
  - C-2: POSIX channel is a no-op stub.
- **Phase 1:** CI gate that builds + smokes a concurrency test on Linux.
- **Phase 2b:** Implement the missing impls.

### E-1, E-2, E-3 — Effect / Capability silent-discard

- **Source:** `gap-analyses/Nucleor_Effect_Capability_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** TRUST GAP (effects parse but don't enforce)
- **Symptom:** `pure fn`, `requires`, `restricts` parse, `nuc build` accepts, no enforcement.
- **Phase 1:** Audit-pass info diagnostic showing effect-keyword counts.
- **Phase 2b:** Per-fn enforcement passes.
- **Phase 4:** Hard error.

### T-3, T-4 — Type system silent fallthrough

- **Source:** `gap-analyses/Nucleor_Type_System_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** SILENT-MISCOMPUTE
- **Symptom:**
  - T-3: `char` typed compatible with any int.
  - T-4: empty type "" compatible with anything (silent fallthrough).
- **Phase 1:** Add stricter type-equality check; fail-fast on `""` type.
- **Phase 2b:** Replace `str_eq(t1, t2)` calls with structural type check.

### BOOT-3, BOOT-4 — Self-host fixed-point integrity

- **Source:** `gap-analyses/Nucleor_Self_Hosting_Bootstrap_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** SELF-HOST INTEGRITY
- **Symptom:** Fixed-point check guards a 50-line smoke proxy, NOT the 10K-line compiler self-IR.
- **Phase 1:** Replace fixed-point check with compiler-self-IR md5 verification.
- **Phase 2b:** CI gate enforces.

### PKG-1, PKG-3 — Packaging

- **Source:** `gap-analyses/Nucleor_Module_Packaging_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** LAUNCH-BLOCKER (Linux), TRUST GAP
- **Symptom:**
  - PKG-1: Linux `nuc publish --sign` silently broken.
  - PKG-3: Semver constraints don't resolve (only exact strings work).
- **Phase 1:** Fix Linux publish path. Implement semver resolver.

### QM-7 — Clifford rod zero test coverage

- **Source:** `gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** UNVALIDATED (41KB stabilizer formalism)
- **Phase 1:** Property tests for stabilizer normal form invariants.

### ROBO-7 — Frame-typing safety

- **Source:** `gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** SAFETY (Mars Climate Orbiter failure mode is live)
- **Phase 1:** Add unit-of-measure tagging to frame types.
- **Phase 2b:** Compile-time check that frame tags are consistent across operations.

### PERF-11 — bisect_mem threshold below baseline

- **Source:** `gap-analyses/Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** TELEMETRY (false-positive every run)
- **Symptom:** `bisect_mem.sh` excursion threshold 600 MB, current baseline 679 MB.
- **Phase 1:** Update threshold to baseline +10% (~750 MB).

## Other Tier A items (not on critical-findings list but still launch-blockers)

### Real-Time / Determinism
- Source: `gap-analyses/Nucleor_RealTime_Determinism_Gap_Analysis_and_RFC_2026-05-04.md`
- Phase 1: audit `#[deadline]` / `#[no_alloc]` enforcement.

### Algebraic Laws
- Source: `gap-analyses/Nucleor_Algebraic_Laws_Gap_Analysis_and_RFC_2026-05-04.md`
- Phase 1: property test set for math identities.

## Tier B items (compilation, runtime, execution)

### Interop / FFI
- Source: `gap-analyses/Nucleor_Interop_FFI_Gap_Analysis_and_RFC_2026-05-04.md`
- Already partially closed by RFC-0062 G-5/G-7/G-9 Phase 1+2a. Cross-reference pending.

### Performance Envelope (beyond PERF-11)
- Source: `gap-analyses/Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md`
- General perf-budget gates; CI integration.

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
- BOOT-3, BOOT-4 (self-host integrity)

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

## Updates log

- **2026-05-04** v0.8.43: Punchlist file created. 14 gap RFCs integrated into spine. RFC-0062 memory-safety remains in flight; other 13 queued behind it.
