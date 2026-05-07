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
- **C-10 thread barrier:** DONE for Phase 2 on 2026-05-06 —
  `thread_barrier_new`, `thread_barrier_wait`, and
  `thread_barrier_free` expose a reusable fixed-party runtime barrier.
  `concurrency.nr` documents this surface but does not re-export it,
  avoiding duplicate `thread_rt.c` linkage when adopters import both
  rods. The runtime is backed by Win32 condition variables / POSIX
  pthread condition variables. `thread_barrier_smoke.nr` runs four OS
  threads through two rendezvous rounds and verifies no worker passes
  the first barrier before all peers arrive.
- **C-11 mutex destroy:** DONE for Phase 1 on 2026-05-06 —
  `conc_mutex_destroy` / `conc_mutex_free` release the native
  `CRITICAL_SECTION` or `pthread_mutex_t` allocated by `conc_mutex()`.
  `concurrency_mutex_destroy_smoke.nr` locks single and repeated
  lock/unlock/free cycles.
- **C-16 channel close semantics:** DONE for Phase 2 on 2026-05-06 —
  `conc_channel_close` marks a bounded channel closed, leaves buffered
  values readable, ignores sends after close, and makes recv on a closed
  empty channel return `0` instead of blocking forever.
  `concurrency_channel_close_smoke.nr` locks the contract.
- **C-17 typed atomic width wrappers:** DONE for Phase 2 on 2026-05-06 —
  `AtomicU64`, `AtomicI32`, and `AtomicU32` now expose typed
  ordered load/store/fetch/swap/CAS wrappers over the existing i64
  atomic storage cell, closing the raw-handle escape hatch.
  `rfc0007_atomic_width_wrappers.nr` locks representative operations.
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
  `err_pure_scope_schedule.nr` lock the first two surfaces, and
  `err_pure_channel_effect.nr` locks the channel/synchronization surface.
- **E-12 pure builtin print-family I/O:** DONE for Phase 2b partial on
  2026-05-06 — pure/const/hot body scans now treat `print_*` and
  `eprint*` helper calls as I/O; active fixture
  `err_pure_builtin_io.nr` locks the archived `print_int` case.
- **E-2 `pure fn` + `requires [...]` contradiction:** DONE for
  Phase 1 — `nuc build` emits `EFF-002`; active fixture
  `err_pure_requires.nr` locks this.
- **Standalone `requires [...]` direct/body/helper calls:** DONE for
  Phase 1 — `nuc build` emits `EFF-001` when a same-file caller
  invokes a fn with a `requires [...]` row but does not declare the
  required effect, when a fn's own `requires [...]` row omits a known
  builtin body effect, or when a bounded same-file un-rowed helper
  chain reaches such a builtin effect. Active fixtures
  `err_effect_requires_direct.nr` (empty caller row),
  `err_requires_row_direct_call.nr` (caller row declares a different
  family — `net` vs callee `io.read`),
  `err_requires_row_builtin_io_mismatch.nr` (own body uses
  `print_int` / `io.write` under `requires [net]`), and
  `err_requires_row_transitive_builtin_io.nr` (un-rowed helper reaches
  `print_int`) lock the negative path; `effect_requires_direct_ok.nr`,
  `requires_row_clean_smoke.nr`, and
  `requires_row_transitive_builtin_ok.nr` lock the positive path.
  Cloud Claude lane 2 v0839 added the family-root and
  disjoint-family fixtures on 2026-05-06; helper1 v0844 added the
  body/helper builtin enforcement.
- **RFC-0033 `with [...]` subset:** PARTIAL — `with [no_alloc]`
  calling `with [Alloc]` emits `EFF-003`; active fixture
  `err_effects_with_alloc_call.nr` locks this.
- **Block-form `restricts [...] { ... }`:** DONE Phase 2b first
  slice plus bounded transitive follow-up (local-claude
  v0840/v0841/v0843)
  — block-form parses cleanly and the
  same-file source pre-pass `enforce_restricts_block_effects` emits
  `error[EFF-003]` when a direct call inside the block targets a
  builtin in the print-family / channel / namespaced alloc-constructor
  effect map or a same-file user fn whose declared `requires [...]`
  row overlaps the deny row. v0841 also walks un-rowed same-file user
  fn callees up to depth=3 and emits EFF-003 when the reachable chain
  hits a builtin or rowed callee whose effect overlaps the deny row.
  v0843 consolidates the row extractor for `requires [...]` and
  `with [...]`, reuses a unified same-file function table for
  restricts transitive scans, raises the bounded same-file restricts
  chain cap to 8 hops, and threads the actual matching sub-effect
  token into diagnostics (`Alloc.heap` in the `Alloc` family instead
  of only `Alloc`).
  Clean blocks and clean transitive helper chains compile and run normally.
  Active fixtures: `err_restricts_block_builtin_io.nr` (negative —
  direct `putchar` under `restricts [io.write]`),
  `err_restricts_block_alloc.nr` (negative — direct `Vec::new` under
  `restricts [alloc]`), `restricts_block_disjoint_call.nr` (positive
  — call to a disjoint-family `requires [io.read]` callee under
  `restricts [net]`),
  `err_restricts_block_transitive_unrowed_io.nr` (negative — un-rowed
  one-hop helper reaching `requires [io.read]`),
  `err_restricts_block_transitive_deep_chain.nr` (negative —
  un-rowed depth=3 helper chain reaching `requires [net.connect]`),
  `err_restricts_block_transitive_depth8_chain.nr` (negative —
  deeper helper ladder still caught within the depth=8 budget),
  `restricts_block_transitive_clean_smoke.nr` (positive — clean
  un-rowed helper chain),
  `restricts_block_transitive_depth8_clean_smoke.nr` (positive —
  deeper clean helper ladder), and
  `restricts_block_clean_smoke.nr` (positive — pure-arithmetic
  clean block builds and exits 0). Pre-existing fail-closed
  companions still halt the build via the new pre-pass or via
  `enforce_requires_direct_calls`: `err_restricts_builtin_io.nr`,
  `err_restricts_violation.nr`, `err_restricts_specific.nr`,
  `err_restricts_channel_effect.nr`, and `err_effect_transitive.nr`
  emit EFF-003; `err_effect_inference.nr` and
  `err_effect_deep_chain.nr` now also emit EFF-003 on the restricts
  surface while retaining the independent EFF-001 signal for the
  un-rowed intermediate helpers.
- **v0845 lane 2 (Queue 2A) — cross-module propagation closed for the
  flat-namespace `import "..."` surface.** The resolved-source pre-pass
  inlines imported module bodies before `enforce_requires_direct_calls`
  and `enforce_restricts_block_effects` run, so the same-file diagnostics
  already covered the cross-module case for direct rowed-callee
  mismatches and bounded-transitive un-rowed chains. Empirical probe
  surfaced the only real residual: the `requires [...]` transitive
  budget was 3 hops, while the `restricts` path used 8. A 4..=7-hop
  un-rowed chain to a builtin/rowed leaf fell silently through the
  bound (cross-module or same-file). v0845 raises the requires bound
  to 8 to match `restricts_transitive_check`. Visited-set dedup keeps
  termination O(N) per chain. Locked by:
  `tests/err/err_requires_cross_module_aux.nr` (lib),
  `tests/err/err_requires_cross_module_direct.nr` (negative — cross-
  module direct rowed-callee mismatch),
  `tests/err/err_requires_cross_module_transitive.nr` (negative — cross-
  module un-rowed helper transitively reaching `print()`),
  `tests/err/err_requires_cross_module_depth.nr` (negative — 4-deep
  cross-module chain that previously silent-passed at depth=3),
  `tests/err/err_restricts_cross_module_aux.nr` (lib) +
  `tests/err/err_restricts_cross_module_transitive.nr` (negative —
  `restricts [io.write] { ... }` block reaching imported `print()`),
  and `tests/features/requires_cross_module_aux.nr` +
  `tests/features/requires_cross_module_clean_smoke.nr` (positive —
  matching cross-module rows compile + run).
- **v0845 lane 2 (Queue 2B) — same-file `impl` method effect
  enforcement closed for the unique-name case.** The substring-search
  call-site check in `enforce_requires_direct_calls` accidentally
  covers `obj.method(...)` because `.method(` contains `method(`, so
  with the resolved-source pre-pass already inlining methods'
  declarations and bodies, every same-file method effect mismatch
  surfaces the same EFF-001 / EFF-003 the free-fn surface does. The
  one regression risk that made this surface stay listed as open was
  same-name methods on different `impl` blocks: with two methods named
  `emit` and conflicting rows, the substring search couldn't pick
  which receiver-typed call site resolved to which impl, so the row
  check would false-positive on the un-rowed call. v0845 adds
  `name_has_distinct_rows_in_table` and routes `enforce_requires_direct_calls`,
  `requires_transitive_missing`, and `restricts_transitive_check`
  through it: when the table has two entries sharing a name with
  textually-distinct rows, the row check is skipped (fail-open) and
  the body walk continues. Receiver-type-aware resolution for the
  ambiguous-name path is Phase 4 / RFC-0033 broader effect-row
  subtyping. Locked by:
  `tests/err/err_method_requires_direct.nr` (negative — direct method
  row mismatch),
  `tests/err/err_method_body_builtin_transitive.nr` (negative — method
  body reaches builtin io.write under incompatible caller row),
  `tests/err/err_restricts_block_method_io.nr` (negative — restricts
  block reaches method-internal io.write),
  `tests/features/method_requires_clean_smoke.nr` (positive — matching
  rows compile + run), and
  `tests/features/method_ambiguous_name_fail_open_smoke.nr` (positive —
  same-name methods with distinct rows compile cleanly via the
  fail-open path; pre-v0845 this fixture's source false-positived
  EFF-001).
- **Still open:** full standalone `requires [...]` row enforcement
  beyond depth=8 helper chains, ambiguous-name method receiver
  resolution (fail-open since v0845; full type-aware lookup is Phase 4),
  closures and function-pointer effect capture, broader RFC-0033
  effect-row subtyping, and selective `use path::{a, b}` / glob
  `use path::*` import surfaces (resolver phase 2).
- **Phase 2b:** effect-row enforcement in the main build path.
- **Phase 4:** Hard error.

### RFC-0063 Phase 2.0 — Parser/tools-suite unification and duplicate deletion

- **Source:** `RFC-0063-production-readiness-roadmap.md`
- **Severity:** TOOLCHAIN CORRECTNESS / PERF / MAINTAINABILITY
- **Status:** WAVE 10 PARTIAL DONE; BROAD DELETION OPEN. `tools/audit_dup_fns.nr`
  and `tools/audit_dup_fns_report.csv` now map the duplicate
  function surface between `compiler/nucleor_s1_compiler.nr` and
  `compiler/nucleor_tools_suite.nr`.
- **Important accounting:** v0838 retired 12 byte-identical non-parser
  tools-suite helper duplicates, v0839 retired 40 more
  byte-identical `own_*` ownership helpers, v0840 Wave 3 retired 25
  byte-identical `ir_*` helpers, v0840 Wave 4 retired 25
  byte-identical cache/path/host helpers, v0840 Wave 5 retired
  20 byte-identical atomic-ordering/map/container helpers, v0841 Wave 6
  retired 29 byte-identical smap/diagnostic/record/source helpers, and
  v0842 Wave 7 retired 33 byte-identical string/classifier/profiling/
  type-env/module/format/privacy/CLI helpers, v0842 Wave 8 retired
  29 byte-identical codegen/type-ref/sendable/ownership-format helpers,
  and v0844 Wave 9 retired 19 normalized-identical same-signature
  body-diff helpers. v0845 Wave 10 Queue 1A retired 18 more
  byte-identical low-level accessor and non-core helper duplicates by
  moving them into
  `compiler/nucleor_rfc0063_shared_wave1.nr` and importing that module
  from `compiler/nucleor_tools_suite.nr`. The s1 compiler remains the
  raw canonical copy for these batches. The broad s1-to-tools import is
  still open because the remaining duplicate names would collide unless
  they are deleted/renamed in the same ship.
- **Current audit counts after v0845 Wave 10 Queue 1A refresh:** 186
  duplicate function names: 26 `IDENTICAL` safe-delete candidates,
  144 `SIG_MATCH_BODY_DIFFERS` review/replace candidates, and 16
  `SIG_DIFFERS` per-function lift/adapter candidates.
- **Next build item:** delete or import the remaining 26 identical duplicates
  through the RFC-0063 parser/tools-suite unification strategy, then
  continue the 144 same-signature body-diff candidates and 16
  signature-diff candidates in follow-on waves.
- **Required gates for any deletion wave:** `bash tools/check_compiler_drift.sh`,
  focused `nuc check` / `nuc build-strict` / `nuc abi inspect` smoke,
  self-host fixed point if `bin/nucleor.exe` or
  `bootstrap/nucleor_s1_seed.ll` changes, and perf gate if the compiler
  or tools-suite hot path changes.

### T-3, T-4 — Type system silent fallthrough — Phase 1 DONE; Phase 2b queued

- **T-3 char-cast Phase 1:** DONE v0.8.46 audit-pass info, locked v0.8.78 fixture.
- **T-3 char-cast Phase 2b partial:** DONE for const-foldable and
  narrow non-constant guarded `as char` proof. `nuc build` /
  `build-strict` emit `TYP-026` for invalid constant codepoints
  outside `0..0x10FFFF`, surrogate constants, and unguarded
  non-constant casts. The recognized dynamic proof is fail-closed:
  the exact binding must be guarded in the same `if` then-branch by
  `v >= 0 && v < 0xD800` or equivalent ordering. Active fixtures
  `err_t3_invalid_char_cast.nr`, `err_t3_nonconstant_char_cast.nr`,
  `t3_nonconstant_char_cast_guarded_smoke.nr`, and
  `t3_const_char_cast_smoke.nr` lock this. Runtime/IR char
  distinctness remains queued.
- **T-4 empty-type compat Phase 1:** DONE v0.8.79 canary fixture (well-typed path locked; inversion protocol encoded for when Phase 2b strict mode lands).
- **T-4 Phase 2b partial:** DONE 2026-05-06 for core helper return
  typing. Strict inference now knows `str_len`, `str_char_at`,
  `str_substring`, trim variants, `args_get`, and `file_read_string`
  in both compiler copies; `t4_strict_core_helper_rtypes.nr` locks the
  positive strict-mode assignment path.
- **T-4 Phase 2b partial:** DONE 2026-05-06 for direct IO/env/path
  helper return typing. Strict inference now knows scalar/string return
  types for direct `env_*`, `getcwd`/`getenv`, OS-info, read-only FS,
  path, and byte-compare helpers; `t4_strict_io_path_helper_rtypes.nr`
  locks the positive strict-mode assignment path.
- **T-4 Phase 2b partial:** DONE 2026-05-06 for format/string helper
  return typing. Strict inference now knows scalar/string return types
  for direct string predicates, format helpers, integer parse/format
  helpers, and core string utility helpers; `t4_strict_format_string_helper_rtypes.nr`
  locks the positive strict-mode assignment path.
- **T-4 Phase 2b partial:** DONE 2026-05-07 for direct numeric/f64 helper
  return typing. Strict inference now knows scalar return types for
  direct elementary f64 helpers, f64 bit reinterpret helpers, and
  `f64_to_i32` in both compiler copies; `t4_strict_remaining_helper_rtypes.nr`
  locks the positive strict-mode assignment path.
- **T-4 Phase 2b partial:** DONE 2026-05-07 for direct scalar time/clock
  helper return typing. Strict inference now knows i64 return types for
  direct `now_ms`, `sleep_ms`/`sleep_us`, monotonic/wall-clock time,
  timestamp decomposition, and elapsed-time helpers in both compiler
  copies; `t4_strict_time_helper_rtypes.nr` locks the positive
  strict-mode assignment path.
- **Phase 2b still open:** T-4 strict empty-type compatibility beyond
  covered core/IO/path/format/string/numeric/time helper returns,
  broader T-3 runtime/IR char distinctness, and wider scalar-proof
  recognition beyond the current fail-closed non-constant guard
  pattern.
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

- **PKG-1 (Linux `nuc publish --sign`):** DONE 2026-05-07
  (v0842) — native Linux proof on kernel 6.18.5 bootstraps
  `bin/nucleor` from `bootstrap/nucleor_s1_seed.ll`, builds
  `bin/nucleor_tools`, creates a throwaway ed25519 key, runs
  dry-run signed publish with no registry artifacts, then performs
  real `nuc publish --sign --key-id throwaway-ci` to a throwaway
  registry and verifies the resulting package signature with
  `tools/native_release.ps1 package-verify`. Evidence:
  `findings/inbox/cloud_linux_pkg1_signed_publish_v0842_2026-05-07.md`.
  Fresh Linux runners still need documented prereqs (`pwsh`,
  `openssh-client`/`ssh-keygen`, clang, and a locally built
  `bin/nucleor_tools`), but no PKG-1 publish-path blocker remains.
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
- **Phase 2c bounded weight-enumerator surface:** DONE 2026-05-06 —
  `qm7_clifford_weight_enumerator_smoke.nr` locks
  `cliff_stabilizer_weight_count` and `cliff_logical_weight_count` on the
  same Surface-17 stabilizer set. The fixture verifies internal exhaustive
  counts by weight; external published weight-enumerator value citations remain
  an advisory documentation gap, not a missing runtime surface.
- **Phase 2c citation row:** DONE 2026-05-07 (v0845) —
  `qm7_clifford_weight_enumerator_smoke.nr` now carries an explicit
  citation chain in its header tying the asserted stabilizer/logical
  weight-count distribution to the generator set in
  `qm7_clifford_surface_d3_smoke.nr`, which itself cites
  Tomita and Svore, "Low-distance surface codes under realistic
  quantum noise," Phys. Rev. A 90, 062320 (2014), Table II.
  The asserted counts are exhaustive deterministic consequences of the
  cited generator set, not a separately published enumerator value.
  This closes the advisory documentation gap for the in-tree counts;
  separate citation-backed external enumerator-VALUE parity (cross-
  validating the same numbers against a third-party enumerator computed
  in another framework) remains optional future work, only required if
  a launch artifact specifically demands it.
- **Phase 2d bounded property micro-suite:** DONE 2026-05-06 —
  `qm7_clifford_property_micro_suite.nr` locks clone/reset isolation,
  small gate-sequence identities, repeatable [[5,1,3]] rebuilds, logical
  non-detectability, single-error detectability, and five-qubit
  stabilizer/logical weight-count consistency.
- **Phase 2e OpenQASM 2.0 emit-only:** DONE 2026-05-07 (v0842) —
  `stdlib/rods/quantum.nr` ships a minimal emit-only OpenQASM 2.0
  surface (`qasm2_program_new`, `qasm2_emit_h/x/z/cx`,
  `qasm2_emit_named_1q/2q`, `qasm2_render`, `qasm2_supported_gate`,
  `qasm2_status_*`, `qasm2_limitations`). Header is fixed to
  `OPENQASM 2.0;` + `include "qelib1.inc";` + `qreg q[N];`. Supported
  subset is H/X/Z/CX. Name-dispatched emit returns
  `qasm2_status_unsupported_gate` (4) for any other name without
  mutating the program. Active fixtures:
  `qm7_openqasm2_emit_smoke.nr`, `qm7_openqasm2_unsupported_gate_smoke.nr`.
- **Phase 2f OpenQASM 2.0 minimal parser:** DONE 2026-05-08 (v0843) —
  `stdlib/rods/quantum.nr` ships `qasm2_parse(src)` plus
  `qasm2_parse_result_status`, `qasm2_parse_result_program`,
  `qasm2_program_eq`, and `qasm2_status_parse_explain`. The parser
  accepts ONLY the deterministic emit dialect produced by
  `qasm2_render` (fixed header lines + per-line H/X/Z/CX bodies
  separated by `\n`); it has no whitespace tolerance, comment
  handling, alternative spelling, parameterized rotations, or
  classical control. Status codes 6–10 cover
  `parse_empty_source`, `parse_unexpected_header`,
  `parse_malformed_qreg`, `parse_unsupported_gate`,
  `parse_malformed_gate`; out-of-range qubit references and
  same-qubit CX in the source propagate the existing emit-side
  codes (`qubit_out_of_range`, `same_qubit`,
  `invalid_qubit_count`). Active fixture
  `qm7_openqasm2_roundtrip_smoke.nr` locks 19 invariants including
  exact byte round-trip on a 5-gate canonical program, an
  empty-body program, and every documented failure mode.
- **Still open for Phase 2 closure:** a citation-backed external
  published weight-enumerator parity row if the launch docs
  require one. General OpenQASM 2.0 importing of foreign sources
  (whitespace, comments, parameterized gates, measurements,
  classical control) remains future work.

### UNIT-1 — Typed dimensional units archive guard — Phase 1 guard + positive API partial DONE

- **Source:** `RFC-0005-units.md`, `RFC-0047-typed-units-7vector.md`
- **Status:** FAIL-CLOSED ARCHIVE GUARD DONE 2026-05-06. The main
  `nuc build` preflight now rejects the three V1 archive hazards that
  previously compiled through erased storage: bare numeric-to-unit
  initialization (`TYP-007`), adding mismatched dimensions (`TYP-003`),
  and assigning a velocity-shaped unit value into a distance binding
  (`TYP-008`). Active fixtures: `err_unit_bare_coercion.nr`,
  `err_unit_mismatch.nr`, `err_unit_assign.nr`.
- **Positive API surface:** PARTIAL DONE 2026-05-07. `units.nr`
  now exposes nominal `UnitDistance` and `UnitVelocity` structs with
  explicit constructors, accessors, conversion helpers, same-dimension
  add/sub helpers, and distance-over-time velocity construction over
  the existing f64 + unit-ID storage contract. Active fixtures:
  `unit_distance_positive_smoke.nr`, `unit_velocity_positive_smoke.nr`.
- **Positive API expansion (v0845):** PARTIAL DONE 2026-05-07
  (v0845) — `units.nr` adds nominal `UnitTime`, `UnitMass`, and
  `UnitAcceleration` structs with the same nominal-storage contract,
  parallel constructor / accessor / `value_as` / same-dimension `add` /
  `sub` helpers, plus the dimension-safe
  `unit_acceleration_from_velocity_time` construction (canonical
  mps^2 normalization). New active fixtures:
  `unit_time_positive_smoke.nr`, `unit_mass_positive_smoke.nr`,
  `unit_acceleration_positive_smoke.nr`. No parser/type-algebra
  changes; this is library-level expansion only.
- **Still open:** full parser/type-checker dimension algebra for
  `unit<T, dim>`, UNIT-001..005 semantic diagnostics, 7-vector lowering,
  literal suffix support, and broader positive typed-unit API coverage.

### ROBO-7 — Frame-typing safety

- **Source:** `gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- **Severity:** SAFETY (Mars Climate Orbiter failure mode — was live pre-v0838)
- **Status:** PARTIAL — Phase B step-3 diagnostic broadening is live
  (FRAME-001 fires for `Pose<Frame_X>` mismatches at let-binding,
  call-argument, struct/tuple init, assignment, return, and binop
  sites); v0841 adds the first adopter-facing stdlib typed-pose
  migration in `kinematics.nr`. Full `tf` / `se3` transform typing
  remains queued behind `Transform<From, To>` / FRAME-002/003.
- **Phase 1:** DONE — `stdlib/rods/kinematics_frame.nr` ships zero-cost
  `Frame_*` marker structs + numeric ID surface + runtime check helpers
  (`kinematics_frame_compatible_strict`, `_assert`, `_require`,
  `_check_pair`); audit-discovery counter live in the compiler since
  v0.8.145.
- **Phase B step-1 (audit):** DONE v0.8.145 — compiler counts
  `Pose<F>` and `Frame_*` annotations and emits an info line.
- **Phase B step-2 (let-binding enforcement):** DONE v0838 — new
  `frame_mismatch_visible` helper in `compiler/nucleor_s1_compiler.nr`
  rejects two types whose first generic args carry distinct `Frame_*`
  phantom tags on matching base names (`Frame_Unknown` is the
  RFC-0046 §migration sentinel and matches anything; untagged types
  are unaffected). `let p_camera: Pose<Frame_Camera> = p_base;` (where
  `p_base: Pose<Frame_Base>`) now fires `error[FRAME-001]` with the
  Mars-Climate-Orbiter framing and a `kinematics_transform` fix
  pointer instead of a silent miscompute. Positive coverage:
  `tests/features/robo7_frame_positive_smoke.nr` (5 invariants —
  same-frame, Frame_Unknown left/right migration sentinel, untagged
  → tagged opt-in flow, chain preservation). Negative coverage:
  `tests/err/err_robo7_frame_mismatch.nr` (FRAME-001 fires).
- **Phase B step-3 (broaden diagnostics):** DONE in v0840 repair —
  shared `frame_mismatch_diag_message` keeps the canonical
  Mars-Climate-Orbiter framing and upgrades call arguments, named
  struct fields, tuple-struct fields, assignments, indexed
  assignments, field assignments, explicit returns, tail-expression
  returns, and binary/operator operands from generic `TYP-*`
  surfaces to `error[FRAME-001]` only when
  `frame_mismatch_visible(expected, actual)` confirms a true
  frame-tag mismatch. Non-frame mismatches retain their original
  diagnostics.
- **Phase B step-4 (stdlib migration prep):** PARTIAL v0841 —
  `stdlib/rods/kinematics.nr` now exposes a zero-cost phantom-frame
  `Pose` facade over the existing Vec3 / Quat handles plus typed
  `kinematics_transform*` helpers. Existing handle-level `pose_*`
  APIs remain unchanged for backwards compatibility. Positive
  coverage: `tests/features/robo7_kinematics_typed_pose_smoke.nr`
  proves Frame_Unknown migration, camera-to-base, and base-to-camera
  transform paths. Negative coverage:
  `tests/err/err_robo7_kinematics_transform_call_mismatch.nr`
  proves a base-frame pose cannot be passed to the camera-to-base
  stdlib API.
- **Phase 4 (v1.0 hard-error promotion):** OPEN — migrate
  the remaining raw `tf.nr` / `se3.nr` surfaces from integer frame
  IDs and pointer tuples to typed transform wrappers; deprecate
  `Frame_Unknown` and require explicit frames everywhere by v1.0.

### PERF-11 — bisect_mem threshold — DONE

- **Status:** DONE v0.8.84 — `EXCURSION_MB` raised 600 → 750 MB to match baseline+10% (747 MB ceiling). False-positive on every run eliminated.

## Other Tier A items (not on critical-findings list but still launch-blockers)

### Real-Time / Determinism
- Source: `gap-analyses/Nucleor_RealTime_Determinism_Gap_Analysis_and_RFC_2026-05-04.md`
- **RT-G1/RT-G3 Phase 2b:** helper1 v0838 adds bounded same-file
  closure for `#[no_alloc]` and `#[no_panic]`: caller -> helper ->
  known allocating/panicking helper now fails. Helper1 v0842 deepens
  the same-file closure to a small bounded caller-chain pass, so
  caller -> helper -> helper -> known allocating/panicking helper also
  fails. Remaining gap: cross-module callees, closures, fn-pointer
  dispatch, and deeper-than-bound helper paths still require the
  AST/IR traversal pass.
- **Still open:** `#[deadline]` numeric/certified-WCET backing and
  broader RT attribute enforcement audit.

### Algebraic Laws
- Source: `gap-analyses/Nucleor_Algebraic_Laws_Gap_Analysis_and_RFC_2026-05-04.md`
- **Status:** IN FLIGHT — do not remove or demote. Current compiler
  captures `@law(...)` at lex time, has a metadata-only optimizer pass
  scaffold, reserves LAW diagnostics, and has smoke fixtures for
  capture, bounded `--check-laws` validation, and optimizer identity
  eligibility.
- **Phase 3b:** helper1 v0838 adds bounded integer `distributive_over`
  checks and makes unsupported canonical law forms / float modifiers
  fail closed under `nuc test --check-laws`.
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
- **R06 Phase 2/3 rust_bridge ownership harness:** POSIX ownership
  proof CLOSED 2026-05-07 (v0842) — helper2 v0828 added standalone
  PowerShell and POSIX opt-in harnesses for `rust_free_str` ownership
  evidence; the native Linux proof runs the POSIX harness on kernel
  6.18.5 with native cargo/rustc/clang, covers all seven Rust
  string-returning bridge functions, exercises 70,000 alloc/free
  cycles through `rust_free_str`, emits the JSON harness transcript,
  and strengthens the result with valgrind 3.22.0 memcheck showing
  0 definite/indirect leaks for the string-free, string-free-repeat,
  and hash-control fixtures. Evidence:
  `findings/inbox/cloud_linux_r06_rust_bridge_proof_v0842_2026-05-07.md`.
  Remaining R06 future work: cross-platform hash byte transcript
  pairing Windows + POSIX, RFC-0062 Phase 2b/4 `unsafe` /
  `#[allow(direct_ffi)]` enforcement for direct FFI calls, concurrent
  ownership stress, and the broader cross-boundary ownership contract
  for Python/shared-library FFI.

### Performance Envelope (beyond PERF-11)
- Source: `gap-analyses/Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md`
- **R13-D5 POSIX real RSS e-stop parity:** DONE on main
  2026-05-05 (`fb8b7c0b`) — adds Linux `/proc` process-tree cap
  wrapper and removes the soft `NUC_TRACE_ALLOC` green fallback from
  memory-budget gates.
- **R10-D3 POSIX cold/hot perf gate prep:** CLOSED 2026-05-06 —
  integrated on main 2026-05-05 (`1a962893`), then closed by the
  native Linux transcript in
  `findings/promoted/2026-05-06-r10-d3-native-linux-perf-baseline-captured.md`
  and the locked Linux baseline in `tools/perf_baseline_linux.json`.
  The POSIX gate remains wired through `tools/verify.sh`, refuses WSL /
  Windows `.exe` interop as RSS evidence, and uses the Linux baseline
  via `tools/check_perf_regression.sh --baseline tools/perf_baseline_linux.json`
  until platform-aware default selection lands.
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
- **QM-1 qsim header compatibility:** DONE for Phase 1 on 2026-05-06
  — the advertised `qsim_prob`, `qsim_statevec`, and `qsim_copy`
  surfaces now exist in `stdlib/rods/quantum.nr`. `qsim_prob` supports
  both 0/1 outcomes, `qsim_statevec` returns the statevector handle
  explicitly, and `qsim_copy` deep-copies complex amplitude handles.
  `qsim_header_compat_smoke.nr` locks the behavior.
- **QM-3 MPS named gate wrappers:** DONE for Phase 1 on 2026-05-06
  — `mps_h`, `mps_x`, `mps_z`, `mps_rz`, `mps_rx`, `mps_cnot`,
  `mps_gate_*` constants, `mps_gate_type_supported`, and
  `mps_gate_kind` let adopters use named/logical surfaces instead of
  raw magic integers for shipped MPS gates. `mps_named_gate_wrappers_smoke.nr`
  and `quantum_gate_constants_smoke.nr` lock the surface. Remaining
  gap: the raw `mps_gate(...)` integer escape hatch remains for
  compatibility, and missing MPS runtime gates (Y/S/T/RY/CZ/SWAP/Toffoli)
  still need future dispatch.
- **QM-4 MPS non-adjacent CNOT SWAP-overhead accounting:** DONE for
  Phase 1 on 2026-05-06 — `mps_cnot_swap_overhead(nq, ctrl, tgt)`
  exposes a preflight estimate, `mps_last_swap_overhead(h)` reports
  the most recent high-level MPS gate's inserted SWAP count, and
  `mps_total_swap_overhead(h)` accumulates observed overhead on the
  handle. `mps_swap_overhead_smoke.nr` locks adjacent,
  non-adjacent, reverse-direction, invalid, and non-CNOT reset
  behavior. Remaining gap: the overhead is not yet emitted into S12b
  trace records.
- **QM-5 MPS SVD convergence/clamp diagnostics:** DONE for Phase 1 on
  2026-05-06 — `mps_last_svd_converged`,
  `mps_last_svd_sweeps`, `mps_last_svd_off_norm`,
  `mps_last_svd_negative_clamps`, `mps_total_svd_nonconverged`,
  and `mps_total_svd_negative_clamps` expose the Jacobi SVD
  convergence and negative-eigenvalue-clamp boundary. The focused
  `mps_svd_diagnostics_smoke.nr` locks initial/default status and a
  Bell two-qubit SVD that converges without clamps. Remaining gap:
  truncation-error magnitude is still not quantified, and
  nonconvergence is reported rather than hard-failed.
- **QM-6 MPS Bell probability fixture:** DONE for Phase 1+2c on
  2026-05-06 — `mps_prob0(h, q)` exposes single-qubit probability
  readout from the MPS contraction, `mps_prob_basis(h, basis_bits)`
  exposes computational-basis joint probability, `mps_statevector(h)`
  exposes a capped qsim-compatible `Vec<complex>` extraction, and
  `mps_bell_probabilities_smoke.nr` compares Bell-circuit MPS
  marginals plus |00>/|11> joint probabilities against the qsim
  reference expectations. The statevector path fails closed above
  `mps_statevector_max_qubits()` to avoid 2^n memory blowups.
- **QM-6 high-qubit bounded range extraction:** DONE for Phase 2a on
  2026-05-06 — `mps_statevector_range(h, start_basis, count)` and
  `mps_statevector_range_max_count()` let callers materialize a bounded
  basis-amplitude window without raising the full-state cap; active fixture
  `mps_statevector_range_smoke.nr` locks high-qubit product-state range
  extraction, Bell-window extraction, and fail-closed invalid/cap behavior.
- **QM-6 streaming-range fold helpers:** DONE for Phase 2e on
  2026-05-07 (v0842) — `mps_statevector_range_prob_sum(h, start, count)`
  and `mps_statevector_range_nonzero_count(h, start, count)` fold an
  arbitrary basis range into a single scalar without allocating a
  per-amplitude `Vec<complex>`; memory stays `O(MPS_MAX_BOND)`
  regardless of `count`. The fold cap
  `mps_statevector_range_max_fold_count()` is `1<<20` (1,048,576),
  higher than the materializing cap because no per-state allocation
  is needed. Stable error sentinels (`prob_sum` = `_mf2i(-1.0)`,
  `nonzero_count` = `-1`) cover invalid handle / out-of-range /
  over-cap; a valid empty range (`count=0`) folds to `0`. The same
  `1e-15` zero-clamp the materializing path uses is applied here so
  fold values are numerically consistent with a fold over the
  materialized vec. Active fixture
  `mps_statevector_range_fold_smoke.nr` locks Bell + GHZ
  full-range / sub-range / single-state probabilities, empty-range,
  and every error-sentinel path.
  Remaining gap: true external-sink / callback streaming (per-state
  user callbacks across the FFI boundary) is QM-6 Phase 2f future
  work.
- **QM-2 qsim statevector checked init:** DONE for Phase 1+2b on
  2026-05-06 — `qsim_init_preflight(n)` returns stable status codes
  (`0=ok`, `1=invalid_qubit_count`, `2=over_capacity`) and
  `qsim_init(n)` / `qsim_init_checked(n)` return `0` before dangerous invalid/over-cap
  allocation. `qsim_state_capacity_status_smoke.nr` locks in-range,
  invalid, over-cap, checked-init, and raw-init fail-closed behavior.
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
  gap: raw gate-DAG auto-recording.
- **R11-D4 qsim gate-DAG auto-record:** DONE for Phase 2b on
  2026-05-06 — the same high-level qsim entangling wrappers now call
  `qsim_gate_record_checked` after the wrapped operation. `qsim_swap`
  inherits three CNOT records through its decomposition. `qsim_ccx`
  records two control-target relationships because the public checked
  record surface is two-qubit. Remaining gap: process-local graph
  state is serialized by a global lock rather than per-graph handles.
- **R11-D4 qsim graph lifecycle auto-record closure:** DONE for
  Phase 2d on 2026-05-06 — focused coverage now locks
  `qsim_graph_clear()` resetting both entanglement and gate-DAG state,
  fresh post-clear qsim runs starting with zero graph counts, exact
  one-record behavior for CNOT/CZ/CRK, inherited three-record SWAP, and
  the documented two-control-target CCX representation. Remaining gap:
  process-local graph state is serialized by a global lock rather than
  per-graph handles.
- **R11-D4 qsim graph query contract:** DONE for Phase 2e on
  2026-05-06 — `qsim_graph_query_contract_smoke.nr` now locks public
  `qsim_gate_dag_parent_count`, `qsim_gate_dag_parent_at`, and
  transitive `qsim_gate_dag_depends_on` behavior after mixed checked
  records plus high-level CNOT/CZ/CRK/SWAP auto-recording. Remaining
  gap: process-local graph state is serialized by a global lock rather
  than per-graph handles.
- **R11-D4 qsim graph thread-safety guard:** DONE for Phase 2f+ on
  2026-05-06 — `qsim_graph_is_thread_safe()` returns `1`,
  `qsim_graph_requires_external_lock()` returns `0`, and the C runtime
  serializes all public qsim_graph entry points with a small C11 atomic
  spinlock over the process-local union-find and gate-DAG arrays.
  `qsim_graph_thread_safety_disclosure_smoke.nr` locks this contract, and
  `qsim_graph_thread_guard_smoke.nr` runs four concurrent worker threads
  against disjoint graph updates and verifies exact final counts.
  Remaining gap: per-graph handle state for scalable independent graph
  ownership.
- **QM-11 diff_sim checked init:** DONE for Phase 1+2b on 2026-05-06
  — `diff_sim_init_preflight(nq, n_cores)` exposes stable status
  codes for invalid/over-cap qubits and cores, and
  `diff_sim_init(nq, n_cores, mode_bits, seed)` /
  `diff_sim_init_checked(...)` return `0` before native allocation
  for invalid/over-cap inputs. `diff_sim_capacity_status_smoke.nr`
  locks the public 12-qubit, 16-core, 200-gate cap surface and raw-init
  fail-closed behavior.
- **QM-12 shared gate constants / logical gate kinds:** DONE for Phase 1+2b on
  2026-05-06 — `quantum_gates.nr` now provides shared H/CNOT/X/Z IDs
  consumed by both MPS and diff_sim, with `quantum_gate_constants_smoke.nr`
  locking cross-rod consistency. It also provides logical `qgate_kind_*`
  constants plus explicit `qgate_kind_to_mps` / `qgate_kind_to_diff`
  mappers so RZ routes to each rod's native dispatch ID and unsupported
  rotations such as diff_sim RX fail closed with `qgate_unsupported()`.
  Remaining gap: native dispatch tables are still separate raw ABIs for
  compatibility, but cross-rod callers no longer need to reuse raw rotation
  integers.
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
- **QM-16 qsim trajectory noise channels:** DONE for Phase 1 on
  2026-05-06 — `qsim_noise_bit_flip`, `qsim_noise_dephase`, and
  `qsim_noise_depolarizing` expose caller-controlled stochastic
  trajectory noise with probability validation and status returns.
  `qsim_noise_trajectory_smoke.nr` locks deterministic `p=0` / `p=1`
  behavior and invalid-probability handling. Remaining gap: this is
  not a full density-matrix/Kraus backend; amplitude damping, phase
  damping, mixed-state composition, and exact channel composition
  remain future work.
- **QM-17 qsim mid-circuit feedback primitive:** DONE for Phase 1 on
  2026-05-06 — `qsim_if_measure(sv, measure_q, expected, then_gate,
  then_q, else_gate, else_q, angle)` measures one qubit and immediately
  applies a supported one-qubit feedback gate on the then/else branch.
  `qsim_if_measure_feedback_smoke.nr` locks deterministic then/else
  behavior plus invalid expected-outcome and invalid feedback-gate
  statuses. Remaining gap: hardware timing and target-lowering
  semantics remain RFC-0054 Phase B.

### Robotics (beyond ROBO-7)
- Source: `gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- **ROBO-1 TOPP diagonal torque-limit tightening:** DONE for Phase 1 on
  2026-05-06. The multi-DOF TOPP solver now accepts per-joint
  `inertia` and `tau_max`, exposes `topp_effective_amax`, and
  tightens each acceleration bound by `tau_max / inertia` when that
  limit is active; `topp_torque_limit_smoke.nr` proves the torque
  box materially lengthens traversal time versus the same kinematic
  path. Remaining gap: full coupled TOPP-RA with path-dependent
  torque/dynamics constraints, asymmetric limits, and non-diagonal
  inertia/Coriolis/gravity terms.
- **ROBO-3 analytical IK path:** DONE for Phase 1 on 2026-05-06.
  `ik_analytic_planar_2link` provides a closed-form two-revolute-link
  planar solver with elbow branch selection and unreachable-target
  refusal; `ik_analytic_planar_2link_smoke.nr` locks the exact
  `(1, 1)` target solution plus an unreachable case. Remaining gap:
  6-DOF canonical manipulator solvers, branch enumeration,
  singularity classification, and FK-backed solution validation.
- **ROBO-4 6D IK nullspace posture:** DONE for Phase 1 on
  2026-05-06. `ik_dls_solve_6d_nullspace` uses the 6 x n pose
  Jacobian and projects preferred posture through `(I - J+J)`;
  `ik_6d_nullspace_smoke.nr` proves the pose task solves while a
  task-invisible redundant DOF moves toward `q_pref`. Remaining gap:
  production fixture on a true 7-DOF arm with orientation + posture
  coupling, stronger convergence/scaling policy, and singularity /
  limit-avoidance evidence.
- **ROBO-2 DMP multi-DOF batch wrapper:** DONE for Phase 1 on
  2026-05-06. `dmp_multi_new`, `dmp_multi_learn`,
  `dmp_multi_reset`, and `dmp_multi_step` expose a whole-joint-vector
  DMP surface backed by one scalar DMP per joint; `dmp_multi_smoke.nr`
  proves sample-major 2-DOF train/reset/step through public f64
  buffers. Remaining gap: true coupled-basis learning across DOFs
  rather than independent per-joint primitives.
- **ROBO-12 AHRS magnetometer yaw correction:** DONE for Phase 1 on
  2026-05-06. `ahrs_update_mag` adds a 9-DOF Mahony update path using
  calibrated body-frame magnetometer input against a world +X magnetic
  reference; `ahrs_magnetometer_yaw_smoke.nr` proves yaw correction
  from an initial 90-degree heading error. Remaining gap:
  local declination/calibration helpers, stronger high-dynamics
  rejection, and Madgwick variant.
- **ROBO-14 end-to-end robotics smoke:** DONE for Phase 1 on
  2026-05-06. `stdlib/rods/f64_buffer.nr` and
  `stdlib/runtime/f64_buffer_rt.c` close the raw `double[]` fixture
  plumbing gap; `tests/features/robo14_end_to_end_smoke.nr` now runs
  IK -> RRT free-space plan -> CHOMP smooth -> TOPP time profile -> FK
  endpoint verification on a deterministic planar arm. Remaining gap:
  upgrade this to a production-grade 6-DOF pose/orientation fixture
  with nonzero collision/obstacle callbacks and dynamics-aware timing.
- **ROBO-13 OBB-OBB collision / CCD:** DONE for Phase 1 on
  2026-05-06. `coll_obb_obb` adds static SAT overlap and
  `coll_ccd_obb_obb` computes time-of-impact for linearly translated
  OBB centers with fixed orientations; `collision_obb_ccd_smoke.nr`
  locks overlap, clear, initial-hit, swept-hit, and swept-clear cases.
  Remaining gap: angular CCD and convex mesh-vs-mesh sweep.
- **ROBO-11 quantum twin naming:** DONE for Phase 1 on 2026-05-06.
  `quantum_twin.nr` is now the honest import alias for the existing
  twin-core quantum noise model, while `twin_core.nr` remains
  backward compatible and explicitly says it is not a robotics digital
  twin. Remaining gap: real robotics digital twin / sim-to-real rod.
- **ROBO-5 TF timestamped interpolation:** DONE for Phase 1 on
  2026-05-06. `tf_add_frame_at`, `tf_set_pose_at`, and `tf_lookup_at`
  keep the latest two stamped samples per frame and interpolate
  translation plus normalized quaternion orientation for in-window
  lookups; `tf_timestamped_lookup_smoke.nr` locks midpoint
  interpolation, out-of-window rejection, and legacy latest-pose
  compatibility. Remaining gap: string-keyed frame names, disconnected
  forest support, deeper history buffers, cache/lazy lookup strategy,
  and hard-RT allocation protocol.
- **ROBO-6 URDF topology:** DONE for Phase 1 on 2026-05-06.
  `<parent link>` / `<child link>` metadata is parsed and queryable,
  out-of-source-order serial trees are ordered by topology for
  `urdf_to_fk_chain`, and branching/forest topologies are refused
  instead of silently flattened; `urdf_branch_topology_smoke.nr`
  locks branch detection/refusal and topology-ordered serial FK export.
  Remaining gap: true branched-tree FK/runtime surface, xacro subset
  expansion, and richer link/visual/collision/inertial model handling.
- **ROBO-8 CHOMP covariant preconditioning:** DONE for Phase 1 on
  2026-05-06. `chomp_optimize_covariant` applies the inverse
  clamped-endpoint smoothness metric (`A^-1 grad`) before stepping;
  `chomp_covariant_preconditioner_smoke.nr` proves a smoothness-only
  zig-zag collapses while endpoints stay fixed. Remaining gap:
  high-DOF / obstacle-gradient production evidence, exact SDF
  gradients, and tuning guidance for `metric_reg` / `max_step`.
- **ROBO-9 Cartesian CHOMP:** DONE for Phase 1 on 2026-05-06.
  `chomp_optimize_cartesian_planar_2link` optimizes a planar 2-link
  joint path against a Cartesian end-effector target path with
  analytical FK/Jacobian gradients; `chomp_cartesian_planar_2link_smoke.nr`
  proves task-space cost drops while endpoints stay clamped. Remaining
  gap: generic high-DOF robot-model FK/Jacobian support,
  obstacle/SDF-aware Cartesian gradients, and production manipulator
  reach-around fixtures.
- **ROBO-10 HWBC strict priority evidence:** DONE for Phase 1 on
  2026-05-06. `tests/features/hwbc_strict_priority_smoke.nr` proves
  the existing Siciliano-Slotine null-space `hwbc` rod preserves a
  higher-priority joint command against a conflicting lower-priority
  task while satisfying an independent lower-priority null-space task.
  Remaining gap: box-constrained hierarchy and torque-level /
  dynamics-coupled control.

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
  (`1a962893`). The gate is wired but intentionally refuses WSL/interop.
- **2026-05-06**: R10-D3 native Linux perf evidence closed by
  `findings/promoted/2026-05-06-r10-d3-native-linux-perf-baseline-captured.md`
  and `tools/perf_baseline_linux.json`: cold 9.05s, hot 0.47s,
  cold process-tree RSS 286MB, hot process-tree RSS 17MB.
- **2026-05-05**: QM-7 Phase 2a advanced with typed Clifford
  stabilizer Vec wrappers, a [[5,1,3]] distance/detectable-error smoke
  fixture, and reset/rebuild round-trip coverage. The compiler Tier-C
  disclosure was updated so imports no longer claim zero Clifford
  coverage. Rotated surface-code was still open at this checkpoint.
- **2026-05-06**: QM-7 Phase 2b adds rotated Surface-17 d=3 fixture
  coverage from Tomita/Svore Table II.
- **2026-05-06**: QM-7 Phase 2c adds bounded Clifford stabilizer/logical
  weight-enumerator helpers and locks Surface-17 internal exhaustive counts.
- **2026-05-06**: QM-7 Phase 2d adds a bounded Clifford property
  micro-suite over clone/reset isolation, small gate-sequence identities,
  and repeatable [[5,1,3]] code invariants.
- **2026-05-07** (v0842): QM-7 Phase 2e closes the OpenQASM 2.0 emit
  tail with a minimal emit-only stdlib surface in
  `stdlib/rods/quantum.nr` (qasm2_program_new / emit_h/x/z/cx /
  emit_named_1q/2q / render / supported_gate / status_* /
  limitations). Active fixtures `qm7_openqasm2_emit_smoke.nr` and
  `qm7_openqasm2_unsupported_gate_smoke.nr` lock supported emits,
  unsupported-gate refusal at status code 4 without mutation, fixed
  header preamble, qubit-out-of-range and same-qubit CX rejections,
  and limitations text. Remaining open items are OpenQASM 2.0
  *import/parser* round-trip and optional external citation-backed
  published weight-enumerator parity.
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
- **2026-05-06**: Effect/capability Phase 2b fixture lock expanded.
  `err_pure_channel_effect.nr` now keeps the existing `channel(...)`
  pure-function effect check in the active negative suite.
- **2026-05-06**: Effect/capability archive cleanup promoted the
  remaining archived restricts/effect negative fixtures into the active
  suite as explicit `EFF-003` fail-closed coverage. This does not claim
  real block-form restricts enforcement; it closes the no-silent-accept
  coverage gap while deeper effect-row enforcement remains queued.
- **2026-05-06**: RFC-0062 ownership fixture closure promoted the V1
  archive `Box<T>` use-after-move test. `is_copy_type` now classifies
  `Box<...>` as non-Copy before `type_base_name` unwraps the inner type;
  `err_box_use_after_move.nr` locks the `OWN-001` diagnostic.
- **2026-05-06**: RFC-0005 typed-units archive guard promoted the V1
  `err_unit_*` negative fixtures into the active suite. `nuc build`
  now fails closed for the archived bare numeric-to-unit, mismatched
  add/sub, and velocity-to-distance assignment hazards without claiming
  full `unit<T, dim>` algebra; UNIT-001..005 and 7-vector semantics
  remain queued.
- **2026-05-06**: Effect/capability Phase 2b fixture promotion advanced.
  Archived pure negatives for builtin print-family I/O, direct
  `requires [...]` callee calls, and immediate wrapper inference now live
  under `tests/err/` as `err_pure_builtin_io.nr`,
  `err_pure_violation.nr`, and `err_pure_inference.nr`.
- **2026-05-06**: TOOLCHAIN-PY-1 closed. `nuc verify-reproducible`
  no longer requires Python for its Windows byte-compare path; it
  now uses `fc /B` for linked binary comparison and retains `cmp -s`
  for POSIX. Python interop rods remain intentional and unchanged.
- **2026-05-06**: RFC-0063 Track C Phase 5.5 closed for the drift
  gate. `tools/check_compiler_drift.sh` no longer probes for Python or
  executes `.py` generators; drift-gated freshness checks now require
  native `.nr` generators through `bin/nucleor`.
- **2026-05-06**: PERF-5 closed for the canonical bash gate.
  `tools/verify.sh` now includes a routine RFC-NRT-003
  `verify-reproducible` step requiring byte-identical IR and EXE
  outputs for `tests/fixtures/t477_provenance_section.nr`.
- **2026-05-06**: Cloud-agent dispatch pack added at
  `docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md`.
  It expands the remaining ten-lane punchlist with completion estimates,
  source RFCs, cloud-agent split, write scopes, non-scope, and validation
  gates for external dispatch.
- **2026-05-06**: Cloud-agent dispatch pack expanded with first-class
  visibility for the external ML Suite / ML Expansion spine lane and
  `Nucleor_Translate` forward-commitment. These stay outside the ten core
  compiler/runtime lanes: ML Suite code remains external, and Translate is
  pull-in-gated on completion plus revalidation before any `nuc port` shim.
- **2026-05-07**: v0845 remaining-work agent handoff added at
  `docs/rfcs/v1_REMAINING_PUNCHLIST_AGENT_HANDOFF_v0845_2026-05-07.md`.
  It refreshes the old v0834 cloud dispatch pack after the v0838-v0844
  integrations, requires one isolated worktree per agent, and lays out
  loop-safe queues for RFC-0063, effects, RT determinism, laws, ROBO-7,
  T-3/T-4, UNIT-1, R06/FFI, Linux CI/proof, quantum, ML Suite, and
  Translate visibility.
- **2026-05-06**: T-4 strict inference Phase 2b partial advanced.
  Core runtime helper return types are now known in both compiler copies,
  and `tests/features/t4_strict_core_helper_rtypes.nr` locks the positive
  strict-mode assignment path.
- **2026-05-06**: T-4 strict inference Phase 2b partial advanced again.
  Direct IO/env/path runtime helper return types are now known in both
  compiler copies, and `tests/features/t4_strict_io_path_helper_rtypes.nr`
  locks the positive strict-mode assignment path.
- **2026-05-07**: T-4 strict inference Phase 2b partial advanced.
  Direct numeric/f64 runtime helper return types are now known in both
  compiler copies, and `tests/features/t4_strict_remaining_helper_rtypes.nr`
  locks the positive strict-mode assignment path.
