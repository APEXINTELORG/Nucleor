# Nucleor — Self-Hosting and Bootstrap Integrity Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS`.

---

# Part I — Definition

## 1.1. The bootstrap pillar

Self-hosting from day one is one of Nucleor's headline architectural commitments. The fixed-point CI gate, byte-identical IR across iterations, and signed bootstrap binary are positioned as the credibility moat that justifies every other claim about the language. If the bootstrap chain breaks or silently drifts, every downstream guarantee is suspect.

**The headline finding: the load-bearing fixed-point check is implemented as a 50-line smoke proxy, not as the full self-IR diff the contract describes.** The compiler's own 10K-line self-IR is never compared across iterations. A silent miscompute in the optimizer or emitter that changed the compiler's self-IR but not `arith.nr`'s IR would pass the gate, and the resulting binary would not be stably reproducible from the next iteration.

---

# Part II — Gap Inventory

## BOOT-1 — Bootstrap binary identity claim is stale in contract — **LOW**
`NUCLEOR_BOOTSTRAP_CONTRACT.md` says binary identifies as `Nucleor Compiler 0.2.0-v2`. Actual binary reports `nucleor 0.4.180`. Confusion for any reader verifying contract manually.

## BOOT-2 — Two undocumented binaries committed in `bin/` — **MEDIUM**
`bin/nucleor_O2.exe` and `bin/nucleor_s1_backup.exe` present, not mentioned in `bin/README.md` or contract. `.gitignore` only excludes `bin/nucleor_v*.exe`, not these. Provenance, version, relationship to canonical `bin/nucleor.exe` undocumented. Future release engineers cannot determine intent.

## BOOT-3 — Full self-IR fixpoint check is not implemented; deferred since v0.2.310 — **CRITICAL**
The fixpoint step in both `verify.ps1` (line 891) and `verify.sh` compares SHA256 of a small smoke file's IR (`tests/lang/arith.nr`), not the full compiler self-build IR. Comment explicitly notes "Stronger: exact-match diff; deferred to v0.2.310+." **The two-iteration `diff -q target/nucleor_vNNN.ll target/nucleor_v(NNN+1).ll` described in the contract as the load-bearing gate is NOT what the verify step actually runs.**

## BOOT-4 — Stage divergence detection has no full-IR comparison — **CRITICAL**
T1.7 compares bootstrap seed against current emission (one-direction freshness check). Fixpoint step checks small smoke. **No gate diffs the compiler's own LLVM IR across two self-application iterations.** Subtle miscompute in optimizer/emitter could produce non-fixed-point for full compiler while passing smoke.

## BOOT-5 — `verify.sh` (POSIX gate) has no T1.8 perf regression step — **HIGH**
`check_perf_regression.ps1` is Windows/PowerShell-only. `verify.sh` references it in comment but does not invoke it. **Cold/hot timing and memory not enforced on Linux/macOS gate runs.**

## BOOT-6 — Perf baseline ceilings stale in audit references — **LOW**
Old (3.64s/0.89s/131MB) figures in some docs are two baseline generations stale. Current locked baseline (Track L, 2026-05-01): 5.93s cold / 1.74s hot / 747 MB ceiling.

## BOOT-7 — Linux/macOS bootstrap unshipped; v0.3.0 success criteria all unchecked — **HIGH**
No `bin/nucleor` ELF or Mach-O committed. `bootstrap_linux.sh` automates procedure but has never been run in CI. v0.3.0 milestone success criteria checkboxes all `[ ]`. Cross-platform audit is from 2026-04-22.

## BOOT-8 — `__nucleor_channel_*` and `__nucleor_pipe_*` POSIX stubs are silent no-ops — **CRITICAL** (cross-references concurrency C-1, C-2)
Lines 3841–3844, 3423–3425 of `nucleor_llvm_rt.c`. Programs using `concurrency.nr` or pipes on Linux silently lose all messages/data. No verify-gate step exercises this on POSIX.

## BOOT-9 — Memory budget enforcement on POSIX falls back to weaker `NUC_TRACE_ALLOC` — **MEDIUM**
`_memory_budget_for` in `verify.sh` prefers PowerShell process-tree sampler when available; on pure Linux falls back to `NUC_TRACE_ALLOC` cumulative counting. Comment notes fallback "does not enforce real RSS e-stop." 770/580 MB ceilings soft on Linux.

## BOOT-10 — No documented Windows recovery procedure — **HIGH**
`bootstrap_linux.sh` covers POSIX recovery via seed `.ll`. **No equivalent PowerShell recovery script for Windows.** `nucleor_s1_backup.exe` present but undocumented. Windows user with broken `bin/nucleor.exe` has no documented path back without Linux/macOS host.

## BOOT-11 — Cache v2 architecture doc mismatch — **LOW**
`docs/architecture.md` describes cache as `.nuc_cache/<fn_hash>.ll` (old v1 path). Track L moved to `target/.nuc_cache_v2/<prefix>/<sha>.ll`. Architecture doc not updated.

## BOOT-12 — Verify step count in contract is stale — **LOW**
Contract states "204 steps as of v0.2.131". Both verify scripts grown substantially beyond (600+ fixture steps as of v0.4.x). Misleading for anyone estimating gate coverage.

## Cross-cutting risks
- **The fixpoint check guards the wrong IR surface (BOOT-3+4 compound).** Gate passes as long as 50-line smoke compiles identically. Compiler change introducing non-fixpoint in 10K-line self-compiler IR but not in `arith.nr` would pass.
- **Silent failures on Linux bootstrap (BOOT-7+8+9 compound).** Linux gate passes, programs appear to work, correctness guarantees silently absent.
- **Perf gate Windows-exclusive (BOOT-5+6).** Linux CI never enabled would have no perf signal.

---

# Part III — RFC

## 3.1. Goals
1. Restore the contract's promised IR comparison: full self-IR fixpoint check, not smoke proxy.
2. Cross-platform bootstrap parity (Linux/macOS native binaries + perf gate parity).
3. Documented recovery procedures for both Windows and POSIX.
4. Resolve undocumented `bin/` artifacts.

## 3.2. Closure plan

**Phase 1 (emergency, doc + audit):**
- Update `NUCLEOR_BOOTSTRAP_CONTRACT.md`: correct binary version string (BOOT-1), document or remove `nucleor_O2.exe` / `nucleor_s1_backup.exe` (BOOT-2), update step count (BOOT-12), update architecture cache path (BOOT-11).
- Document Windows recovery procedure in `bootstrap/README.md` — even if it requires a temporary Linux/macOS pass for now (BOOT-10).

**Phase 2 (full self-IR fixpoint check):**
- New verify step "self-host full-IR fixpoint": stage-1 builds compiler → emit `target/_self_v1.ll`; stage-2 (using stage-1 binary) builds compiler → emit `target/_self_v2.ll`; SHA256 diff. Step fails if diverge.
- Optional stage-3 fixpoint check for v1.0: build with stage-2 binary, confirm v3 matches v2.
- Resolves: BOOT-3, BOOT-4.

**Phase 3 (POSIX parity):**
- Implement `__nucleor_channel_*` and `__nucleor_pipe_*` for POSIX (cross-references concurrency C-1, C-2).
- Port `check_perf_regression.ps1` logic to bash (or invoke pwsh on Linux if available).
- Strengthen POSIX memory budget enforcement (use `getrusage` or `/proc/self/status` instead of `NUC_TRACE_ALLOC`).
- Resolves: BOOT-5, BOOT-8, BOOT-9.

**Phase 4 (v1.0 gate, Linux/macOS native bootstrap):**
- Run `bootstrap_linux.sh` in CI; commit resulting `bin/nucleor` ELF.
- Equivalent macOS pipeline; commit `bin/nucleor` Mach-O.
- Documented Windows recovery script (`tools/bootstrap_windows.ps1`).
- v0.3.0 milestone closes.
- Resolves: BOOT-7, BOOT-10 (full).

## 3.3. v1.0 release gate
Phases 1-2 minimum (BOOT-3+4 are CRITICAL). Phases 3-4 strongly preferred but Linux/macOS bootstrap can ship as v1.x if Windows continues to be the primary target.

## 3.4. Open questions
1. Should the full self-IR fixpoint check use SHA256 only, or also `diff -q` for human-readable failure mode? Recommendation: SHA256 for gate fail/pass + auto-diff dump on failure.
2. POSIX channel implementation: pthread-based or native eventfd? Recommendation: pthread for portability across BSD variants.
3. Is committing `bin/nucleor` ELF in the OSS repo acceptable, or should it be a release artifact only? Recommendation: release artifact via `tools/bootstrap_*.sh` regenerating from the source seed.

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Self_Hosting_Bootstrap_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
