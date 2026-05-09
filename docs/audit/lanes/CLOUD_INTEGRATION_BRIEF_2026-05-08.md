# Cloud Integration Brief — Audit Fix Integration → v1.0.1

**Date:** 2026-05-08
**Owner:** cloud agent (Linux preferred — faster verify, no Windows-only verify thrash)
**Branch to work on:** `integrate/audit-fix-2026-05-08` on `origin` (`APEXINTELORG/Nucleor-archive` private repo)

## Required reading (all in this branch)

Everything the agent needs is committed under `docs/audit/`:

**Original recon findings — what we're trying to solve (read these to understand the actual defects):**
- `docs/audit/findings/audit_recon_pass1_lexer_parser_2026-05-08.md` — Layer 1
- `docs/audit/findings/audit_recon_pass1_typesystem_2026-05-08.md` — Layer 2
- `docs/audit/findings/audit_recon_pass1_diagnostics_2026-05-08.md` — Layer 3 (cross-cutting)
- `docs/audit/findings/audit_recon_pass1_memsafe_2026-05-08.md` — Layer 4 (RFC-0062 G-1..G-11)
- `docs/audit/findings/audit_recon_pass1_concurrency_2026-05-08.md` — Layer 5
- `docs/audit/findings/audit_recon_pass1_codegen_2026-05-08.md` — Layer 6
- `docs/audit/findings/audit_recon_pass1_runtime_abi_2026-05-08.md` — Layer 7
- `docs/audit/findings/audit_recon_pass1_numeric_2026-05-08.md` — Layer 8
- `docs/audit/findings/audit_recon_pass1_stdlib_math_2026-05-08.md` — Layer 9a
- `docs/audit/findings/audit_recon_pass1_stdlib_robo_quantum_ffi_2026-05-08.md` — Layer 9b
- `docs/audit/findings/audit_recon_pass1_examples_docs_2026-05-08.md` — Layer 10

**Per-lane fix briefs — what each lane was tasked with (read these to understand the remediation contracts):**
- `docs/audit/lanes/LANE_1_TYPE_FLOW_CODEGEN.md`
- `docs/audit/lanes/LANE_2_MEMORY_SAFETY_ENCAPSULATION.md`
- `docs/audit/lanes/LANE_3_VERIFY_HARNESS_DIAGNOSTICS.md`
- `docs/audit/lanes/LANE_4_LEXER_PARSER_ROBUSTNESS.md`
- `docs/audit/lanes/LANE_5_STDLIB_CORRECTNESS.md`
- `docs/audit/lanes/LANE_6_RUNTIME_ABI_RT_EFFECTS.md`
- `docs/audit/lanes/LANE_7_DOCS_USER_SURFACE.md`
- `docs/audit/lanes/AUDIT_FIX_CONTROL.md` — master coord with cross-lane dependencies + cherry-pick order

**Per-lane completion reports — what each lane actually closed (read these to understand current state):**
- `docs/audit/lanes/LANE_1_REPORT.md` — type flow + codegen u64
- `docs/audit/lanes/LANE_2_REPORT.md` — memory safety + handle encapsulation
- `docs/audit/lanes/LANE_3_REPORT.md` — verify harness + diagnostics (already integrated)
- `docs/audit/lanes/LANE_4_REPORT.md` — lexer/parser robustness
- `docs/audit/lanes/LANE_5_REPORT.md` — stdlib correctness (math + robotics + quantum + FFI)
- `docs/audit/lanes/LANE_6_REPORT.md` — runtime ABI + RT + effects (already integrated, base)
- `docs/audit/lanes/LANE_7_REPORT.md` — docs + user surface
- `docs/audit/lanes/_lane5_diff_tests.py` — Lane 5's numpy/scipy/sklearn differential harness (informational)

The agent should skim every recon file at minimum to understand the audit scope, then read the per-lane brief + report for the lane currently being integrated. The lane reports document partial closures, deferrals, and cross-lane handoffs that may affect integration sequencing.

## Context

Pass-1 recon audit surfaced 244 findings across 11 layers (39 Critical, 77 High, ~71 Med, ~26 Low, ~31 Note).

Seven parallel cloud lanes produced fix branches:

| Lane | Branch | Tip SHA | Notes |
|---|---|---|---|
| L1 | `fix/audit-lane-1-type-flow-codegen-2026-05-08` | `34dd9d2d` | type flow + codegen u64; 5 Crit closed, 3 Partial. Agent rebuilt bin. |
| L2 | `fix/audit-lane-2-memory-safety-2026-05-08` | `924390fe` | G-1..G-11 false negatives + handle encapsulation + NVec layout; 12/14 Crit closed |
| L3 | `fix/audit-lane-3-verify-harness-2026-05-08` | `213a7e5f` | verify harness exit-code-aware, F-DIAG-003 fixed, 18 negative tests |
| L4 | `fix/audit-lane-4-lexer-parser-2026-05-08` | `3ab1dd0b` | lexer/parser robustness; F-066 root cause + parse_depth helpers; agent verify 1360 PASS / 1 FAIL (drift, fixed in same commit) / 8 SKIP |
| L5 | `fix/audit-lane-5-stdlib-correctness-2026-05-08` | `3009e11a` | stdlib math + robotics + quantum + FFI; 5/5 Crit closed; differential vs numpy/scipy/sklearn passing |
| L6 | `fix/audit-lane-6-runtime-abi-rt-2026-05-08` | `b5023920` | runtime ABI + RT scanner + effects wiring + SI dim wiring; **3 Crit + 17 High closed; verify PASS=1519 / SKIP=9 / FAIL=0 (cleanest baseline)** |
| L7 | `fix/audit-lane-7-docs-user-surface-2026-05-08` | `88fb1ec9` | docs/CLI mass cleanup + nuc help + nuc explain G-series + strict-flag-check |

## Integration state on `integrate/audit-fix-2026-05-08`

Current tip: `f6ef5451`. Already on this branch:

1. **Base:** L6 fast-forwarded onto pre-cherrypick main (`c40cb904`). All L6's runtime/ABI/effects/RT/manifest fixes integrated. Verified PASS=1519/SKIP=9/FAIL=0 on the L6 branch tip.
2. **L3 squash:** harness hardening + diagnostic plumbing layered as a single squash commit (`f6ef5451`) using `--strategy-option=ours` for derived-file conflicts. Source-only.

Remaining lanes to layer onto this base: **L1, L2, L4, L5, L7.**

## Why this is on a cloud agent

Earlier integrator-side cherry-picks (Windows local, foreground) hit:
1. Verify-process thrash (9 concurrent verify.sh runs starving the system) — eventually killed
2. Bootstrap break — auto-merge across all 7 lanes' compiler edits produced a state where L4's `parse_depth_*` helper declares were not being emitted by any available bin even though source had them. Diagnosis was incomplete; integrator pivoted to L6-base + layered approach (this brief).

Cloud Linux agent has:
- Cleaner verify environment (no Windows-side process limits)
- Faster bootstrap loops
- Ability to spend uninterrupted time on the bootstrap chain without integrator-machine resource competition

## Mandate

Layer the remaining 5 lanes onto current `integrate/audit-fix-2026-05-08` base, producing a buildable, verify-clean v1.0.1 candidate.

**Strategy: bootstrap-aware sequential layering.**

For each lane, in this order — **L4, L1, L2, L5, L7**:

1. **Squash-merge the lane's source onto current base:**
   ```
   git merge --squash --strategy-option=ours origin/<lane-branch>
   ```
   Resolve any remaining conflicts manually. For derived files (`bin/nucleor.exe`, `bootstrap/nucleor_s1_seed.ll`, `tools/audit_dup_fns_report.csv`, `docs/rfcs/helper_manifest.toml`), keep the integration branch's current version — they get regenerated next.

2. **Rebuild bin from current source.** Use either:
   - The current `bin/nucleor.exe` (if it can compile the merged source — likely true for L4 first since the previous bin is L6's which doesn't know L4's parse_depth additions; this WILL fail link)
   - **Fallback when current bin can't bootstrap:** copy a temporary bin from the lane's worktree that knows the new helpers (e.g., for L4 layer, use `worktrees/audit_fix_lane_4/bin/nucleor.exe` as the bootstrap bin).

   The bootstrap chain is:
   - L6 base bin: knows L6's emit_externs additions
   - After L4 layer: needs a bin knowing L6's + L4's additions. Strategy: use L4's bin to compile the merged source. L4's bin doesn't know L6's added externs, but those should come through `extern fn` declarations in stdlib `.nr` files (not via emit_externs), so it should still work at the compiler-source level.
   - Iterate.

3. **Smoke + verify per lane:**
   - Build hello example: `bin/nucleor.exe build examples/01_hello.nr -o target/hello_smoke && target/hello_smoke.exe`
   - Run `bash tools/verify.sh` ONCE per lane layer
   - Goal: PASS climbing as new tests land; FAIL=0 expected; SKIP may grow with new platform-gated tests

4. **Commit per lane:** one squash commit per lane integration. Co-authored trailer.

5. **After all 5 lanes layered:**
   - Bump `compiler_version_label` from "1.0.0" to "1.0.1" in:
     - `compiler/nucleor_s1_compiler.nr`
     - `compiler/nucleor_tools_suite.nr`
   - Add `## [1.0.1] — 2026-05-08` block to `CHANGELOG.md` (template at end of this brief)
   - Final regen of seed + bin
   - Final verify FAIL=0 must hold
   - Tag `v1.0.1` (annotated)
   - Push branch + tag to `origin`

## Bootstrap diagnosis hints

The integrator-side bootstrap break was: when integrated `compiler/nucleor_s1_compiler.nr` was compiled by various lane bins, the resulting IR had `call i64 @__nucleor_parse_depth_dec()` references but NO matching `declare i64 @__nucleor_parse_depth_dec()` at module scope. This caused clang IR validation to fail at link time.

The compiler's `emit_externs()` function (around source line 8674-8970 in integrated source) hardcodes those declares. So either:
- The function isn't being called for the integrated source's compile path (unlikely — it's called from `emit_module_ext` line 10013)
- A compiled-into-bin version of `emit_externs` is missing the declares (likely — depends which bin is in use)
- The merge introduced a duplicate or misordered emit_externs that emits the OLD declare set

**Recommended diagnostic:** after the L4 layer step, before rebuilding, do a quick:
```
grep -n 'emit_externs\b' compiler/nucleor_s1_compiler.nr
```
to confirm exactly ONE definition of `emit_externs` exists and the parse_depth declares are inside it. If duplicates exist, deduplicate keeping the version with parse_depth declares. Then proceed with rebuild.

If rebuild still fails: try using L4's worktree bin (`worktrees/audit_fix_lane_4/bin/nucleor.exe` — md5 `a9dc97b865b2408a9b7c8a6e514bb476`, 2522112 bytes) which has parse_depth in its compiled emit_externs.

## Verify policy

- Run `bash tools/verify.sh` ONCE per lane layer at end of that layer.
- FAIL=0 required to proceed to next lane.
- If FAIL>0, investigate that lane's specific failure, fix-forward (do NOT skip), then re-verify.
- Final FAIL=0 is the v1.0.1 ship gate.

## Cherry-pick / source-of-truth files for findings

- `docs/audit/findings/audit_recon_pass1_*_2026-05-08.md` — original recon findings per layer
- `docs/audit/lanes/LANE_<N>_*.md` — per-lane briefs
- `docs/audit/lanes/AUDIT_FIX_CONTROL.md` — master coordination doc

## CHANGELOG template

```markdown
## [1.0.1] — 2026-05-08

Audit-driven hardening release. Pass-1 recon audit identified 244 findings across 11 layers; seven parallel fix lanes closed the substantive Critical/High set. Verify gate hardened to expose the original blind spots that allowed the v1.0 ship to pass with these defects latent.

### Verify harness (Lane 3)
- Negative-test runner now requires both expected diagnostic regex AND non-zero exit code. Previously regex-only, allowing OWN-001 to slip past as a warning emitting RC=0.
- Differential codegen step compiles `.nr` + `.c` reference, bit-compares output (catches the i64-everywhere class).
- Contention/UAF/platform smokes added.
- Negative coverage gate: every emitted diagnostic code must have ≥1 fixture in `tests/err/`.

### Memory safety (Lane 2 + RFC-0062)
- G-1..G-11 false-negative closure: 12/14 Critical fixed. Notable: G-4 `as`-cast UAF wrapper, G-11 if-without-else init, G-8 textbook one-arm move, G-3 hashmap_free during shared borrow.
- `EFFECT-G10-OPT-IN-CLIFF` fires when source has zero `#[effect]` annotations (closes the silent disable).
- Concurrency primitives (`AtomicI64`, `Channel`, `Mutex`, `Thread`, `Future`, `Barrier`) handle types are now opaque — `CONC-G6-OPAQUE-HANDLE` rejects literal-construction.
- `Future.consumed` flag — `thread_future_get` is idempotent.
- `NVec` canonicalized in `stdlib/runtime/nvec.h` with `_Static_assert(sizeof(NVec) == 32)`; 20+ sister `_rt.c` redeclarations removed; `tools/check_nvec_layout.sh` drift gate added.

### Type flow + codegen (Lane 1)
- `u64 < u64` now emits `icmp ult` (was `icmp slt`).
- `u64 >> n` emits `lshr` (was `ashr`).
- `u64 / u64` and `u64 % u64` route to new `__nucleor_panic_div_u64` / `_rem_u64` runtime helpers.
- `f64/f32 as {i8,u8,i16,u16}` saturating-rounds via 8 new `__nucleor_f{32,64}_to_{i8,u8,i16,u16}` helpers (RFC-0015 §3.5).
- Type system: duplicate-type-param `<T,T>` rejected (TYP-042); type-param shadowing primitive rejected (TYP-041).

### Lexer / parser (Lane 4)
- F-066 root cause: lexer's terminal silent-byte-skip replaced with `LEX-001 unexpected byte`. Closes ~10 silent-accept findings.
- `let x: 1 + 1 = 5;` → `PARSE-TYPE-001` (was SIGSEGV).
- Recursive-descent depth limit 1024 → `PARSE-DEPTH-001` (was stack overflow).
- Embedded NUL → `LEX-002` (was silent source truncation, smuggling vector).
- Hex literal overflow → `NUM-021` (was silent wrap; decimal was checked, hex wasn't).
- `1e400` → `LEX-NUM-FLOAT-OVERFLOW` (was silent Inf bit pattern).
- 24+ silent-accept hardenings: number literal hygiene, char-literal misclassification, missing-comma, closing-delim recovery, closure-no-body, import shape, keyword-as-binding.

### Runtime ABI + RT (Lane 6)
- 10 missing manifest rows added (proc_*, mutex_free, channel_close, vec_u8_extend_from_ptr, str_intern_stats accessor); manifest now 886 helpers (was 875), 0 REVIEW REQUIRED.
- `unit_convert_f64` wires `dim_check_or_panic`: cross-dimensional conversions now `UNIT-DIM-001`.
- `bit_shift_*`/`bit_set/clear/test` shift count bounds `[0, 63]` → `BIT-001` (was C UB).
- RT-attribute scanner replaced substring matching with proper expression walk (catches Vec::with_capacity, Box::new, array OOB v.get(i), fn-pointer call, helper-chain depth).
- `#[atomic]`/`#[isr]` blocking detection extended to multi-hop call graph.
- `proc_run1` shell-injection guard via per-platform quoting.
- `proc_capture_stdout` thread-safety: `_Thread_local` status slot.
- RFC-0001 §3.2.4 deadline semantics downgraded to "best-effort post-hoc detection" (HW-timer trap deferred to v1.1+).

### Stdlib correctness (Lane 5)
- TT-SVD real implementation (was stub returning identity matrices). Tolerance 1.74e-16 to 1.24e-15 against numpy reference.
- CP-ALS proper pseudoinverse (was diagonal-only "solve"). Relerr 5.34e-13.
- `nuc_ridge_predict` no longer clips outputs to `[0,1]` (sklearn parity).
- `nuc_t3_slice` bounds check.
- `nuc_mat_eig` non-symmetric input → `MAT-EIG-NOT-SYMMETRIC` (was wrong eigenvalues silently).
- `nuc_mat_rank` no longer leaks SVD U/S/V/EigResult.
- QR rank-deficient zeroes Q on `norm < 1e-15`.
- URDF default joint axis fixed to `(1,0,0)` per spec (was `(0,0,1)`; affected every URDF without explicit `<axis>`).
- URDF parser emits `URDF-PARSE-001` on unclosed `<joint>` (was silent absorbing).
- Quantum: qsim/qsim_graph/trace qubit caps reconciled; sparsity threshold standardized on `|amp|²`; CNOT control-|0⟩ no false entanglement; `qsim_measure` zero-norm guard.
- FFI: `tests/rods/rust_interop.nr` calls `rust_free_str`; `rust_bridge` Cargo.toml regex pinned to `1.10`.

### Docs + CLI surface (Lane 7)
- `nuc help` no longer lists unimplemented `add | remove | update` aliases.
- `nuc explain` database covers the v1.0 G-series codes (was returning "unknown error code" for OWN-G4-*, BORROW-G2-*, ALIAS-G3-*, SEND-G6-*, FFI-G5/G9-*, UNSAFE-G7-*, EFFECT-G10-*).
- `language-reference.md` rewritten to v1.0; keyword set synced to actual lexer.
- `examples/README.md` install paths fixed: `target/hello.exe` (Windows) / `./target/hello` (Linux).
- `--release` / `--tier` mentions removed from README + architecture (unimplemented); strict-flag-check added so future drift surfaces as `warning: unknown flag '--XYZ' (ignored)`.
- `nuc gen-headers` listed in `nuc help`.
- SARIF driver version bumped 0.1.0 → 1.0.0.
- `verify.sh` step-count comment updated to ~1518 as of v1.0.0.

### Residuals carried to v1.0.2 / v1.x
- L1 partials: F-019 (PANIC on dup impls — diag wired but trailing PANIC needs second bootstrap), F-002 (cross-enum match — MATCH-016 wired, scrut_t population gating), F-003 (i64→i32 narrow — TYP-044 gated by `NUC_STRICT_NUMERIC=1` to preserve existing fixtures), F-006 (generic enum payload — blocked on full monomorphization).
- L2 partials: G4-A-1/A-2 (cast-walk closes most-common shapes; full branch-merge fix-point deferred), G6-A-1 (per-shape struct-field recursion deferred).
- F-NUM-004 mixed-width arithmetic (NUM-001) — RFC amendment recommended.
- F-CONC-006/007 Windows mutex/channel parity — integrator-local pending.
- Per-rod `#[effect(...)]` retrofit — 216 .nr / 1786 extern decls — adopter-incremental.
- macOS native bootstrap — pending hardware.

### Verify
PASS=??? / SKIP=??? / FAIL=0 (filled at integration time).

### Self-host fixed-point
`<md5>` (filled at integration time).
```

## Output

- Branch `integrate/audit-fix-2026-05-08` updated with all 5 remaining lane integrations + version bump + CHANGELOG + tag
- Tag `v1.0.1` (annotated)
- Push to `origin` (archive)
- Brief summary back: per-lane integration status, final verify counts, bootstrap chain decisions made, any deferrals beyond what's in the residuals section
