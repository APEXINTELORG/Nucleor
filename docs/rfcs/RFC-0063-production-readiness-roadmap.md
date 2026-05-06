# RFC-0063 — Production Readiness Roadmap

**Status:** Draft
**Date:** 2026-05-06
**Author:** main agent (per joewescott10-png direction)
**Successor to:** v1_PUNCHLIST.md launch sequence; sister to RFC-0062 (memory safety) and the 14 gap-analysis RFCs of 2026-05-04.

---

## Summary

The v0.8.x ship train (v0.8.17 → v0.8.322) has closed most silent-miscompute and trust-gap items but left three patchwork residues that block a production-ready cut: helper-runtime sprawl, perf engineering by intuition rather than measurement, and Python-on-PATH dependencies in dev tooling. This RFC architects the path that closes all three to a level that reads as "production-grade systems language" rather than "actively-shipping prototype."

Two pillars frame every choice below:

1. **Robust** — every silent miscompute closed; every helper classified + effect-tagged; hermetic toolchain; deterministic / reproducible / self-host-stable on every commit; hard-error tier reached for the trust-gap RFCs.
2. **Fast as physics allows** — performance is a first-order goal: measured baselines (not intuited), monomorphized generics (not per-type sprawl), profile-guided + link-time optimization on the shipped compiler binary, per-arch SIMD specialization for hot helpers, hot-path inlining backed by real flame data.

This is a **multi-ship architectural roadmap**, not a single punchlist. It supersedes the loose "Track 3 / Track 4 / Track 5" framing from the v0.8.323 design checkpoint with a concrete phased plan.

---

## Goals

### G1. Soundness — robust by construction
- 0 unclassified helpers (achieved v0.8.323 ✅).
- 0 silent miscomputes — every diagnostic emits at the right tier.
- Hard-error promotion of the v1.0 RFC-0062 gates (Phase 4: deny-by-default for ownership, effects, lifetimes, frame-typing).
- Effect-row enforcement enforces cross-module — no `pure fn` / `requires [...]` is honored at the warning tier any more.
- Reproducible builds proven byte-identical via the native `file_bytes_equal` path (achieved v0.8.323 ✅).
- Self-host fixed point checked on every commit, on Linux and Windows runners.

### G2. Hermetic toolchain
- Zero non-clang dependencies on adopter machines for `nuc build` / `nuc verify-reproducible`. Python out of the compiler product (achieved v0.8.323 ✅); Python out of dev tooling next.
- gawk/mawk/bash 4.x cross-compatibility for every script in `tools/` (mawk silent-pass closed v0.8.323 ✅; further audit pending).
- All build artifacts producible from the seed `.ll` + the runtime `.c` alone — no auxiliary scripts required for the smoke build.

### G3. Coherent runtime
- The 874-helper runtime collapses to a smaller surface via real generics — `vec_push<T>`, `str_format<T>`, etc. — instead of per-type monomorphization sprawl. Target: VectorOps 113 → ~30, StringFormat 131 → ~50.
- Every helper has known purity, panic-class, allocation, and effect-row metadata (achieved v0.8.323 ✅; per-helper refinement is follow-on).
- ABI-table drift (parser-fn parity, IR declares, get_rt_name) caught on every commit by `tools/check_compiler_drift.sh` — already in place.

### G4. Performance — measured, not guessed
- Production binary (`bin/nucleor`) shipped with PGO + LTO. Baseline a 5–15% improvement on cold compile of `nucleor_s1_compiler.nr` (the canonical workload).
- Hot-path helpers identified from real flame graphs and either inlined (`#[inline]` source attribute → LLVM `alwaysinline`) or specialized per-arch (AVX2 / AVX-512 / NEON SIMD variants for memcpy, memcmp, str/vec batch ops, FP reductions).
- Compile-time perf and runtime perf both regression-tracked via `tools/check_perf_regression.{sh,ps1}` against `tools/perf_baseline.json`.
- Native Linux perf transcript captured (R10-D3 closure, currently pending).

### G5. Test + drift coverage at production tier
- Every RFC-tagged surface has at least one positive smoke + one negative err fixture.
- Every `tests/err/_unimplemented/` fixture has a phase-targeted closure plan in v1_PUNCHLIST.md.
- POSIX validation runner active for C-1 / C-2 / C-3 concurrency items (currently pending: blocked on Linux CI).
- Drift gates (helper_manifest, rod_manifest, RELEASES, CHANGELOG↔tag, parser-fn parity, version-label↔CHANGELOG) all pass on every commit.

## Non-goals

- This RFC does **not** redesign the v0.8 type system, ownership model, or effect vocabulary. Those are tracked in RFC-0062 and the 14 gap-analyses (2026-05-04).
- This RFC does **not** dictate v1.x language features (linear types, real Drop trait, async/await scheduling). Those belong in `RFC_v1_FORWARD_ROADMAP.md`.
- This RFC does **not** touch the Python interop rod (`stdlib/rods/python.nr` + `python_rt.c`) — that's product, parallel to the Rust interop rod, and **opt-in**. Adopters who don't `import "stdlib/rods/python.nr"` carry zero Python dependency.

---

## Current State Assessment (v0.8.323)

### Closed in v0.8.x
- Memory safety RFC-0062 Phase 2b unconditional default-flip (v0.8.75)
- 14 gap-analysis RFCs delivered as Drafts (2026-05-04)
- 9/14 critical Tier-A trust-gap items at Phase 1 enforcement
- Self-host fixed-point integrity gate (v0.8.319)
- POSIX RSS e-stop parity (R13-D5, 2026-05-05)
- POSIX perf gate prep (R10-D3 integration, 2026-05-05)
- ~170 rod smoke fixtures shipped (v0.8.100 → v0.8.322)
- All 72 Unclassified helpers reclassified into a 17-class taxonomy (v0.8.323)
- TOOLCHAIN-PY-1 closed: `verify-reproducible` is now Python-free (v0.8.323)
- mawk silent-pass in `tools/check_compiler_drift.sh` closed (v0.8.323) — surfaces 18 previously-hidden parser-fn drift entries
- `compiler_version_label()` ↔ CHANGELOG.md parity gate (v0.8.323)

### Still patchwork — this RFC's scope
- **874-helper runtime** is grid-derived in part but accreted in part. VectorOps (113) and StringFormat (131) carry the most monomorphization sprawl.
- **18 parser-fn token drift entries** (parse_match_stmt 3, parse_stmt 3, parse_expr 12) silently masked until v0.8.323; need explicit closure ship.
- **5 build-time Python generators** (`tools/gen_*.py`, 65 KB Python total) keep dev environments Python-dependent.
- **No PGO / LTO** on the shipped compiler binary — leaves measurable performance on the table.
- **No flame-graph evidence** behind the inlining-vs-not choice for hot helpers; v0.8.308 (12s → 3.7s body-diagnostic consolidation) was the only data-driven perf ship in the recent train.
- **17 `tests/err/_unimplemented/`** fixtures parked behind future enforcement promotion.

---

## Architecture

### Track A — Generic monomorphization (closes Track 3 properly)

**Problem.** The runtime has 113 VectorOps + 131 StringFormat helpers because the source language emits per-type calls (`vec_push_i64`, `vec_push_f64`, `vec_push_str`, `vec_push_struct_X`) and the runtime hand-writes one helper per concrete type. This is patchwork; it's also fragile because adding a new type means wiring 4–6 new runtime symbols + 4–6 new compiler-table entries.

**Solution.** Source-level generic monomorphization with type-driven specialization at compile time:

```nucleor
fn vec_push<T>(v: &mut Vec<T>, item: T) -> i64 { ... }
```

Lowers to one runtime helper template, instantiated per `T` at IR emission. The compiler:
1. Parses `<T>` as a type parameter (RFC-0042 substrate already exists; needs review for full coverage).
2. Collects every concrete instantiation site during type-check.
3. Emits one `define` per instantiation in IR with name-mangled symbol (`__nucleor_vec_push__i64`, `__nucleor_vec_push__f64`, ...).
4. Garbage-collects unused instantiations via DCE (already in place — saw "DCE: 35 of 807 fns elided").

**Migration path:**
- Phase A1 (~2 ships): inventory existing `<T>`-using code in compiler + stdlib; close the parser/typecheck gaps; ensure trait-bound dispatch works for all primitive types.
- Phase A2 (~3 ships): rewrite VectorOps as generic `Vec<T>::push / pop / get / len / map / filter / fold` once. Delete the per-type runtime symbols when CI proves the generic version is byte-identical to the hand-written family.
- Phase A3 (~3 ships): same for StringFormat — `Format<T> for { i64, f64, bool, char, str, Vec<T>, ... }`.
- Phase A4 (~1 ship): retirement audit — the 113 + 131 = 244 collapsed to ~80 generic templates + ~10 runtime-level intrinsics.

**Robustness payoff:**
- Type safety enforced once, at the generic, not duplicated 8-way.
- Adding a new primitive type (`f8e4m3` already exists; `bfloat16x4` future) costs *zero* new helpers.
- Effect-row classification once per generic, not 8 times.

**Performance payoff:**
- Monomorphization yields **byte-identical** machine code to hand-coded per-type helpers (Rust / C++ template proof).
- LLVM's optimizer sees the generic body and inlines it across instantiations more aggressively than it would with isolated runtime calls.
- Smaller `bin/nucleor` (fewer distinct symbols) → better i-cache.

### Track B — Profile-guided performance (closes Track 4 properly)

**Problem.** "Hot path" is currently identified by intuition + post-hoc observation (v0.8.308 was a real win but reactive). For a production-grade compiler we need a forward-looking discipline.

**Solution.** Three-layer perf system:

#### B1. Baseline + regression gate (foundation)
- Run `tools/check_perf_regression.sh` on every commit on a native Linux runner.
- Baseline locked in `tools/perf_baseline.json` (already exists). Tighten to: cold p50 < 4.5s, hot p50 < 1.3s, peak RSS < 700 MB on the canonical workload (`nucleor_s1_compiler.nr` self-build).
- Any commit moving the p95 by > 5% blocks until investigated.
- Native Linux transcript captured (currently the R10-D3 evidence gap).

#### B2. Hot-path identification + inlining
- Capture flame graph of the canonical workload via `perf record` + `flamegraph.pl` (Linux) and Windows ETW or vtune equivalent.
- Identify the top-20 helpers by self-time and top-20 by call-count × cycles-per-call.
- Apply `#[inline]` source attribute → LLVM `alwaysinline` for any helper where the inlined body cost < calling overhead × call-count threshold.
- Re-baseline, lock the new floor.
- Repeat each release cycle.

#### B3. Per-arch SIMD specialization
- For a curated set (memcpy / memcmp / vec-arith / str-batch / FP reductions / softmax / matmul tile), emit per-arch tuned variants:
  - x86-64 baseline (SSE2)
  - x86-64-v3 (AVX2 + FMA + BMI2)
  - x86-64-v4 (AVX-512)
  - ARM64 (NEON) and ARM64 SVE
- Runtime dispatch via `#ifdef` + CPUID at C level, or LLVM's `target_clones`.
- Locked behind `--march=native` or per-shipped-binary target tuning.

#### B4. Production binary cut
- `bin/nucleor` shipped with `-O3 -flto=full` and PGO using a representative training set: compile `nucleor_s1_compiler.nr` + `nucleor_tools_suite.nr` + the 70 examples + the 1000-fixture verify suite as the training corpus.
- Goal: 5–15% cold-compile improvement vs unoptimized binary.
- CI gate ensures release artifact carries PGO data section.

### Track C — Hermetic toolchain (closes Track 5 properly)

**Problem.** 5 dev-time Python generators keep adopters tied to a Python install for tasks like regenerating `helper_manifest.toml`. Worse: the manifest *gates* the drift check, so `bash tools/check_compiler_drift.sh` hard-fails without Python in PATH.

**Solution.** Port all 5 to native Nucleor `nuc gen-*` subcommands. Retire the one-shot `g1_default_flip_safety_audit.py` since RFC-0062 G-1 is unconditional now.

**Order (smallest first to prove pattern):**

| Order | Script | Size | Status |
|---|---|---|---|
| C1 | `g1_default_flip_safety_audit.py` | 12 KB | **Retire** — G-1 default-flip is unconditional v0.8.75 |
| C2 | `gen_releases_index.py` | 4.7 KB | Port to `nuc gen-releases-index` |
| C3 | `gen_rod_manifest.py` | 6 KB | Port to `nuc gen-rod-manifest` |
| C4 | `gen_benchmark_summary.py` | 6 KB | Port to `nuc gen-benchmark-summary` |
| C5 | `gen_numerics_matrix.py` | 13.7 KB | Port to `nuc gen-numerics-matrix` |
| C6 | `gen_helper_manifest.py` | 35 KB | Port last — most evolved, requires regex + TOML emission |

**Per-port checklist:**
1. Native Nucleor implementation under `compiler/nucleor_tools_suite.nr` as a `nuc gen-*` dispatch.
2. Output byte-identical to the Python version (locked via `tools/check_compiler_drift.sh` regression).
3. `tools/check_compiler_drift.sh` removes the `python` PATH check for that generator.
4. Python source kept for one release cycle as a comparison oracle, then deleted.

**Rod prerequisites for the bigger ports:**
- Robust regex (probably needs RFC-grade audit — currently a few `*_match` helpers but no clear regex DSL).
- TOML emission (have the parser; emission needs structured serialization).
- File walking (have basic `fs_*` helpers; `fs_walk_dir` may need a real iterator).

These rod gaps may themselves spawn their own RFCs — track separately.

### Track D — Cross-cutting gates (insurance)

**On every commit:**
1. `tools/verify.sh --sequential-fixtures` — full 1100+ step regression.
2. `tools/check_compiler_drift.sh` — ABI tables, manifests, RELEASES, CHANGELOG↔tag, version-label↔CHANGELOG, parser-fn parity.
3. `tools/check_self_host_md5.sh` — fixed point on stage1 IR == stage2 IR == seed.
4. `tools/check_perf_regression.sh` — cold/hot/peak-RSS budget on canonical workload.
5. `tools/check_mojibake.sh` — UTF-8 byte-sequence corruption.
6. `tools/check_rod_void_abi.sh` — runtime void-symbol parity.
7. `nuc verify-reproducible compiler/nucleor_s1_compiler.nr` — byte-identical IR + EXE under `--no-cache`.
8. Native Linux + Windows runners both green.

**On every release:**
- All of the above, plus:
- Fresh PGO training run.
- Fresh per-arch SIMD specialization rebuild.
- `gen_helper_manifest.py` + companions emit zero diff.

---

## Phased Execution

Order is by dependency, not value. Each row is one ship cut unless noted.

### Phase 1 — Foundation (next 5 ships, ~1 week at current velocity)

| Ship | What | Why first |
|---|---|---|
| 1.1 | C1: retire `g1_default_flip_safety_audit.py` | Trivial; demonstrates the retirement pattern |
| 1.2 | Close the 18-entry parser-fn drift in `nucleor_tools_suite.nr` | B1 surfaced this; blocks `nuc test` / `nuc build-strict` correctness |
| 1.3 | Capture native Linux perf baseline transcript (R10-D3 closure) | Unblocks Track B; required for hot-path data |
| 1.4 | C2: port `gen_releases_index.py` → `nuc gen-releases-index` | Smallest port; proves the native-tooling pattern |
| 1.5 | Effect-row enforcement Phase 2b (E-2 / E-3 cross-module) | Unblocked by Track 1's classification; cleanest soundness win |

### Phase 2 — Generics substrate (next 5–7 ships)

| Ship | What |
|---|---|
| 2.1 | Generic-parser audit: confirm `<T>` parsing in fn / impl / struct / where-clause is uniformly accepted |
| 2.2 | Type-substitution + monomorphization in IR-lowering pass |
| 2.3 | Symbol-mangling scheme for monomorphized instances (stable, deterministic) |
| 2.4 | Trait-bound dispatch verified for all primitives (i8/16/32/64, u8/16/32/64, f16/32/64, bf16, bool, char, str, Vec<T>, &T, &mut T) |
| 2.5 | DCE audit: unused instantiations elide cleanly |
| 2.6 | RFC-0042 alignment: where-clause unification w/ trait-bound dispatch |

### Phase 3 — Helper consolidation (Track A executed; ~6 ships)

| Ship | What |
|---|---|
| 3.1 | VectorOps reduction wave 1: `Vec<T>::{push, pop, get, set, len}` generic + retire `vec_*_{i32,i64,f32,f64,...}` family |
| 3.2 | VectorOps wave 2: `Vec<T>::{map, filter, fold, sum, min, max}` |
| 3.3 | VectorOps wave 3: `Vec<T>::{contains, index_of, sort, reverse, clone}` |
| 3.4 | StringFormat wave 1: `Format<T>` trait + `int_to_str`/`f64_to_str`/`bool_to_str` collapsed |
| 3.5 | StringFormat wave 2: `format!`/`println!`/`print!` macro lowering through generic Format |
| 3.6 | Cleanup: retire all per-type runtime symbols, regenerate manifest, expect ~244 → ~80 |

### Phase 4 — Performance maximization (Track B executed; ~5 ships)

| Ship | What |
|---|---|
| 4.1 | Capture flame graph on canonical workload; surface top-20 hot helpers |
| 4.2 | `#[inline]` source attribute + LLVM alwaysinline for measured-hot helpers |
| 4.3 | Per-arch SIMD specialization for memcpy / memcmp / vec-arith / FP reductions |
| 4.4 | LTO build: `-flto=full` for `bin/nucleor` shipping |
| 4.5 | PGO: capture training profile, instrument, retrain, ship optimized release binary |

### Phase 5 — Hermetic toolchain (Track C continued; ~5 ships)

| Ship | What |
|---|---|
| 5.1 | C3: port `gen_rod_manifest.py` → native |
| 5.2 | C4: port `gen_benchmark_summary.py` → native |
| 5.3 | C5: port `gen_numerics_matrix.py` → native |
| 5.4 | C6: port `gen_helper_manifest.py` → native (most complex; requires regex + TOML emission stdlib) |
| 5.5 | Drop `python` from `tools/check_compiler_drift.sh` requirements; mark hermetic |

### Phase 6 — Hard-error promotion (v1.0 cut, ~3 ships)

| Ship | What |
|---|---|
| 6.1 | RFC-0062 Phase 3: deny-by-default for memory safety |
| 6.2 | Effect-row Phase 2b → Phase 4: hard-error for unrequired effect |
| 6.3 | Frame-typing ROBO-7 hard-error; T-3 / T-4 Phase 2b strict mode |

**v1.0 release condition:** all Phase 6 gates green + all Phase 1–5 closed + 30 days of canary green CI.

---

## Open Questions

1. **Generics scope** — RFC-0042 already exists for trait-bound dispatch. Is full v1 monomorphization in scope for v1.0, or does v1.0 ship with the current per-type runtime + a transition path to monomorphization in v1.x?

2. **PGO training corpus** — should the corpus be held public (so adopters can re-train on their own workloads) or proprietary to the release pipeline?

3. **Native Linux runner cadence** — POSIX validation has been blocked on this since C-1/C-2/C-3 closure. Is there a budget to provision a dedicated GH Action or self-hosted Linux runner, or do we drive POSIX validation via WSL on the existing Windows runner with the doctor mode?

4. **Per-arch SIMD distribution** — does `nuc build` ship a fat binary (all archs) or rely on per-platform release artifacts? Affects download size + dispatch overhead.

5. **Generator output stability** — when porting `tools/gen_*.py` to native, do we lock byte-identical output against the Python version (regression-tested) or define a cleaner output format and migrate the gate?

---

## Acceptance Criteria

A v1.0 cut on this RFC requires:

- [ ] G1: 0 silent miscomputes under the v0.8.323 trust-gap probes; effect-row hard-error active; reproducibility gate green.
- [ ] G2: zero non-clang adopter machine deps for `nuc build` and `nuc verify-reproducible`; mawk/gawk cross-compatible tools.
- [ ] G3: 874-helper runtime → ≤ 700 helpers with no per-type duplication remaining in VectorOps + StringFormat.
- [ ] G4: PGO + LTO release binary; ≥10% cold-compile p50 improvement vs current; flame-graph-driven inlining for top-20 hot helpers; per-arch SIMD for memcpy/memcmp/vec-arith.
- [ ] G5: 100% rod smoke coverage, 100% err fixture coverage, drift gates green on every commit on Linux + Windows runners.

---

## References

- RFC-0042 — `#[auto_drop]` opt-in cleanup substrate (relevant for Track A)
- RFC-0062 — Memory safety / borrow / ownership gap closure (anchors Phase 6.1)
- RFC-0042 + RFC_v1_FORWARD_ROADMAP.md — generic / trait substrate
- v1_PUNCHLIST.md — current canonical sequencing (this RFC supersedes for v1.0 production cut)
- 14 gap-analyses (2026-05-04) — sister RFCs for the trust-gap closure work
- v0.8.323 (this ship) — closes 4 audit-pass tooling bugs (B1–B4) + 72 Unclassified helpers (Track 1) + TOOLCHAIN-PY-1 (Track 2 / C0).
