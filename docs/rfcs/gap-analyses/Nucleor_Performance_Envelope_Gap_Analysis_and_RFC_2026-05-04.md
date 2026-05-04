# Nucleor — Performance Envelope, Regression Detection, and Reproducibility Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS`.

---

# Part I — Definition

## 1.1. The performance pillar

Performance is enforced by tooling, not by the language. `tools/check_perf_regression.ps1` + `tools/perf_baseline.json` + `tools/verify_timings.csv` + `tools/bisect_mem.sh` form the regression detection apparatus. Reproducibility is enforced by `verify-reproducible` + `.nucprov` + `/Brepro`.

**Headline finding: the documented performance diagnostic codes (`HotViolation`, `HeapInLoop`, etc.) do not exist in the compiler.** They appear only in `docs/architecture.md`. `nuc perf` emits three heuristic strings, none of them the named codes. **Build tier `--tier` flag is documented but not implemented** — the clang invocation never appends `-O` or `-flto`. Tier 0/1/2 are aspirational labels.

---

# Part II — Gap Inventory

## PERF-1 — Build tier `--tier` flag is documented but not implemented — **HIGH**
Architecture doc states Tier 0 (`-O0`), Tier 1 (`-O1` default), Tier 2 (`-O3`+LTO). Flag in completions and router's advanced flag list. **Compiler parser has no `--tier` handler. Clang invocation never passes `-O` flag.** `build-fast` and `build` use same code path. No measured perf delta between tiers. No gate enforcing them.

## PERF-2 — Eight named diagnostic codes documented but never emitted — **HIGH**
`LargeCopy`, `HeapInLoop`, `VirtualDispatchHot`, `RcOverhead`, `StringFormatHot`, `MissingLayout`, `LawMissing`, `HotViolation` appear only in `docs/architecture.md`. `nuc perf` emits only three heuristic strings. The `@hot`-attribute scan supposed to fire these codes is not present.

## PERF-3 — `check_perf_regression.ps1` not called as step in `verify.sh` — **HIGH**
References it in comment (line 290) but does not invoke. Invoked inside `verify.ps1`. Linux/WSL users running `bash tools/verify.sh` get no perf gate.

## PERF-4 — `NUCLEOR_INT_STRICT_ARITH` absent from cache key — **HIGH**
v2 cache canonical flags include only `NUCLEOR_INT_STRICT_INTRIN` and `NUCLEOR_DBC_MODE`. **Flipping `NUCLEOR_INT_STRICT_ARITH` (changes binop IR from wrapping to overflow-panic calls) is not cache-invalidating.** Cached build under wrapping semantics served unchanged under strict-arith mode.

## PERF-5 — `verify-reproducible` not in routine verify gate — **MEDIUM**
SLSA-Build-Level-3 invariant must be invoked manually. Not a step in `verify.sh` or `verify.ps1`. No scheduled or ship-time check that confirms current compiler binary satisfies invariant.

## PERF-6 — Memory baseline (679 MB) is 5x regression from old target (131 MB) — **MEDIUM**
Track L reset measurement methodology to "process-tree WorkingSet64 including clang descendants" (from parent-only). Process-tree approach is correct, but 679 MB covers clang's working set, not just compiler. Ceiling 747 MB gives little headroom; clang version change could exceed without compiler regression.

## PERF-7 — Per-rod performance unmonitored — **MEDIUM**
No per-rod compile-time or run-time thresholds. Rods correctness-tested only. Rod silently introducing O(N²) compilation behavior would not be caught until full-compiler self-build regressed.

## PERF-8 — Cold/hot memory tracked under ceiling only for cold — **LOW**
`hot_mem_mb` computed in `check_perf_regression.ps1` but no `hot_max_allowed_memory_mb` field. Folded into `cold_mem_mb` via max — separate hot-memory threshold absent. Memory spike that only occurs on hot runs not caught independently.

## PERF-9 — `nuc perf` emits compile-path timings only, not generated-code performance — **MEDIUM**
Measures front-end phase times in ms. Does not measure or estimate runtime performance of compiled output, instruction count, register pressure, inlining depth. Users relying on `nuc perf` for runtime-perf diagnosis find only compiler-path information.

## PERF-10 — v0.3.205 strlen footgun class has no automated static-analysis guard — **HIGH**
13× regression caught by human observation. Post-hoc docs say "runtime helper added strlen/vec_len per call." Probe agent found second instance (47× hot). Prevention is reactive (perf ceiling catches after fact) and pattern-name printing. **No pre-ship static check scans for "O(input-size) operations called from hot inner loop."**

## PERF-11 — `bisect_mem.sh` excursion threshold (600 MB) below current baseline (679 MB) — **HIGH**
Default `EXCURSION_MB=600` triggers on every normal run since Track L baseline is 679 MB. Run without overriding `--excursion-mb` would false-positive and start bisecting on clean build.

## PERF-12 — No documented Cranelift path exists — **MEDIUM**
NR050 explain mentions "Cranelift or LLVM rejected the IR" but no Cranelift backend code path exists. Referenced only in error message text. Architecture doc describes three tiers all via clang/LLVM.

## Cross-cutting risks
- **Cache correctness under partial env change.** `NUCLEOR_INT_STRICT_ARITH` not in cache key → silent execution of stale IR if mixed across sessions.
- **Process-tree memory accounting creates clang-version sensitivity.** Clang upgrade increasing peak by 70+ MB would blow ceiling without compiler regression.
- **Tier documentation/implementation skew creates adopter expectations that cannot be met.** `nuc build --tier 2` returns same binary as `--tier 0`.
- **`verify-reproducible` infrastructure with no routine signal.** New change introducing timestamp/iteration order/absolute path would silently break reproducibility between ships.

---

# Part III — RFC

## 3.1. Goals
1. Make `--tier` flag actually produce different binaries (PERF-1).
2. Implement the eight perf diagnostic codes (PERF-2).
3. Cross-platform perf gate parity (PERF-3).
4. Add static guards for the strlen-in-loop class (PERF-10).
5. Fix bisect threshold (PERF-11) immediately — it's currently false-positive on every normal run.

## 3.2. Closure plan

**Phase 1 (emergency):**
- PERF-11: bump `bisect_mem.sh` `EXCURSION_MB` default from 600 to 800 (above current 679 MB baseline + headroom). Document override path.
- PERF-4: add `NUCLEOR_INT_STRICT_ARITH` to cache canonical flags. Cache invalidates when flag flips.
- PERF-1 P1: emit warning when `--tier` flag is passed: "Tier flag accepted but not yet wired to clang invocation. Tracked for v0.5+."
- PERF-2 P1: same for `nuc perf`'s missing diagnostic codes — emit a header note: "Eight named diagnostic codes (HotViolation, HeapInLoop, ...) planned for v0.5+. Current output is 3-line heuristic."
- PERF-12: remove "Cranelift" from NR050 explain text or document the absent backend honestly.

**Phase 2 (short-term):**
- PERF-1 P2: implement `--tier 0|1|2` end-to-end. Tier 0: `-O0`, no LTO. Tier 1: `-O1`, default. Tier 2: `-O3 -flto`. Add tier-delta gate: cold/hot timing must show measurable delta between tiers.
- PERF-2 P2: implement the eight perf diagnostic codes. `@hot`-scoped scan for: heap allocation in `@hot` body (HotViolation+HeapInLoop), `format!`/`println!` in `@hot` body (StringFormatHot), indirect dispatch (VirtualDispatchHot), missing `@layout` on hot-path struct (MissingLayout), missing `@law` on function with provable algebraic structure (LawMissing).
- PERF-3: port `check_perf_regression.ps1` core logic to bash (`tools/check_perf_regression.sh`). Same baseline JSON, same 3-cold + 3-hot sampling. Wire into `verify.sh` as named step.
- PERF-5: add `verify-reproducible` as routine step in both `verify.sh` and `verify.ps1`. Two iterations, hash compare, fail on diverge.
- PERF-8: add `hot_max_allowed_memory_mb` to `perf_baseline.json` and check it independently from cold.

**Phase 3 (medium-term):**
- PERF-7: per-rod perf gates. Each rod gets a small benchmark fixture; compile-time and (where applicable) run-time thresholds in `tools/perf_baseline_rods.json`.
- PERF-9: extend `nuc perf` with codegen-side analysis: instruction count from LLVM IR, function size, hot-loop detection. Even rough metrics surface real codegen perf concerns.
- PERF-10: static analysis pass that flags any function called inside `@hot` or inside a `for`/`while` body when the function's body contains `strlen`, `vec_len`, or other O(input) operations that scan the entire structure. Pattern-based; false-positive rate must be low. Diagnostic: PERF-FOOTGUN-001.

**Phase 4 (v1.0 gate):**
- PERF-6: separate compiler-only memory measurement from clang-inclusive. Two baselines: `compiler_peak_mb` (parent process only) and `process_tree_peak_mb` (current behavior). Ceilings tracked separately so clang version change doesn't false-positive.
- Cranelift backend (PERF-12) — if it's a real architectural goal, ship it. Otherwise remove all references.

## 3.3. v1.0 release gate
Phase 1 emergency fixes immediately (PERF-11 is currently false-positive on every run). Phase 2 minimum for v1.0. Phase 3-4 acceptable as v1.x.

## 3.4. Open questions
1. PERF-10 false-positive risk — how aggressively to flag patterns? Recommendation: conservative (flag only obvious cases), let user disable per-function with `#[allow_fn(PERF-FOOTGUN-001)]`.
2. Should the eight perf diagnostic codes be errors or warnings by default? Recommendation: warnings under normal mode, errors under `--strict`.
3. Cranelift backend — actual goal or vestigial? If goal, scope it; if vestigial, remove the references.

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
