# RFC-0062 Implementation Plan — Memory-Safety, Borrow, Ownership

**Status:** Active spec (started 2026-05-04)
**Companion to:** `docs/rfcs/RFC-0062-memory-safety-borrow-ownership-gap-closure.md`
**Mandate:** Full memory safety in place **before OSS public launch**. Deal-breaker.
**Perf budget:** Cold compile ≤ 4s soft (Job #1), ≤ 5.93s hard. Memory ≤ 770MB peak. Targets hold across the entire deployment.

This document is the ship-by-ship execution plan for RFC-0062. The gap RFC defines WHAT must close; this plan defines HOW and WHEN. Updated each ship as Phases land.

---

## 1. Why this is a launch blocker

Nucleor's external positioning (language tour, READMEs, RFC index) implies Rust-equivalent memory safety:

- "Borrow checker" — RFC-0035 first pass + Phase 1 BR-7 audit
- "Ownership semantics" — OWN-VAL-1..5 diagnostics
- "Lifetime annotations" — `<'a>` parses

Today, half of the surface is shape-only:

- Lifetime annotations parse but don't enforce
- `#[auto_drop]` is opt-in (default = manual `vec_free`)
- Heap-aliasing through `Vec<&T>` and `HashMap` re-binding is undetected
- Conditional-divergence move tracking has gaps
- FFI null + bounds trust is not checked

**Shipping OSS with this gap == false advertising.** The cornerstone language claim must hold by v1.0.

---

## 2. Phase taxonomy (mapped from RFC-0062)

| Phase | Scope | Risk | Adopter signal |
|---|---|---|---|
| **Phase 1** | Docs, audits, warning-only diagnostics. **DONE** v0.8.17–v0.8.20. | Zero | Informational |
| **Phase 2a** | Audit-pass heuristic warnings. Textual pre-pass. False-positive-prone. | Low | `info[...]` |
| **Phase 2b** | Real analysis: per-fn IR-level checker passes. Sound but conservative. | Medium | `warning[...]` |
| **Phase 3** | Default-on with explicit opt-out (`#[allow(...)]`, `#[manual_drop]`). | Medium | `warning[...]` (deny-by-default) |
| **Phase 4** | Hard errors. Promoted at v1.0 cut. Adopter must close all violations. | High | `error[...]` |

**Phase 2 is split into 2a (heuristic) and 2b (proper analysis)** because heuristic passes ship in days while proper analysis takes weeks. Both deliver real adopter value — 2a covers the 80% obvious-pattern cases at ~zero perf cost; 2b covers the soundness gap.

---

## 2A. v1.0 ship status (2026-05-08, integrator lane Phase A)

This section is the running v1.0 cut-line tracker. It is updated each
ship; per-gap detail lives in §3.

### Shipped — integrator lane (Phase A)

- **G-1 Phase 2b-3 unconditional default-flip** + transitive-handoff
  recognizer extended to kind-7 fn calls (commits f69234d8 + 08eba3c4
  + 8cdee78d). The actual blocking bug class — silent
  move-into-struct-field handoff — is closed structurally for the
  entire stdlib surface. Self-host fixed-point md5 =
  `86b491ca2d056f6006f4545e0e29d706`. PASS=1488 / SKIP=1 / FAIL=0
  both Linux + Windows.
- **G-3 / G-4 / G-5 / G-6 / G-9 audit-pass visibility raise** —
  existing Phase 2a heuristic info diagnostics promoted to
  `warning[...]:` level. **This is a visibility change on the
  existing heuristic, NOT real Phase 3 per-fn analysis.** The
  heuristic surface (textual count of `Vec<&`, `vec_free`,
  `*const c_void`, `HashMap<`, `move |`, `extern fn`) remains
  unchanged — the diagnostic now fires at warning tier so adopters
  see it in normal builds. Proper Phase 3 (region-token
  invalidation, IR-level use-after-drop, null-check inference,
  Sendable closure, bounds-check lint) is post-v1.0 hardening.
- **G-7 Phase 3 audit added** — `warning[UNSAFE-G7]:` surfaces any
  `unsafe { }` block in adopter code at compile time. Same
  audit-pass shape as the others (textual count). The OSS compiler
  self-host source contains zero unsafe blocks, so this warning
  never fires on a clean OSS build.

### In flight — cloud lane (Phase B prereq)

- Q1: G-2 single-input lifetime check — real per-fn analysis pass
- Q2: G-4 IR-level use-after-drop tracking — real per-fn analysis
- Q3: G-8 move-state join at branch merge — extends today's
  transitive-handoff fix
- Q4: G-11 definite-assignment flow analysis
- Q5: RFC-0063 waves 12-16 (parser/tools-suite duplicate retirement)

Brief: `CLOUD_AGENT_V1_FINISH_BRIEF_2026-05-07.md` (root of repo).

### Residual past v1.0 cut

- G-3 / G-5 / G-6 / G-9 real Phase 3 per-fn analysis (region tokens,
  null-check inference, Sendable closure, bounds-check lint)
- G-1 Phase 4 (remove `#[manual_drop]` entirely) — requires the 8
  parser fns to migrate to lifetime annotations or `unsafe { }`
  block bodies; not a v1.0 blocker because Phase 2b-3 default-flip
  already closes the silent-leak gap
- G-10 effect annotations (cross-fn ownership)

### v1.0 cut criteria

v1.0.0 tag ships when:
1. All Q1..Q5 closed at Phase 2b-or-better with verify GREEN both hosts
2. Self-host fixed-point md5 stable across the cumulative batch
3. Per-step verify timings ≤ 1.3× baseline (`tools/verify_timings.csv`)
4. CHANGELOG `[Unreleased]` entry promoted to `[1.0.0] — <date>`
5. `compiler_version_label()` bumped to `"1.0.0"` in both
   `compiler/nucleor_s1_compiler.nr` and `compiler/nucleor_tools_suite.nr`
6. Drift gate clean (`tools/check_compiler_drift.sh`)
7. Git tag `v1.0.0` pushed with release notes

---

## 3. Per-gap implementation plan

### G-1 — `#[auto_drop]` default-on (CRITICAL)

**Problem:** Heap-backed locals (`Vec<T>`, `HashMap<K,V>`) require explicit `vec_free` / `hashmap_free` unless the function is marked `#[auto_drop]`. Adopters miss frees → leaks.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Stable opt-in | RFC-0042 graduated to "Stable opt-in". v0.8.20. | 0 |
| 2a | — | Skip; G-1 has no heuristic phase | — |
| 2b-1 | Reserve `#[manual_drop]` attribute, info-only | v0.8.31. Parse + heads-up info diagnostic. | +0.02s |
| 2b-2 | Wire `#[manual_drop]` as actual override of `#[auto_drop]` | v0.8.32. Fn with both attrs gets manual_drop semantics (suppress). | +0.02s |
| 2b-2.5 | Per-fn safety audit tool | v0.8.35. Survey identifies 89 default-flip candidates. | runtime tool, not compile cost |
| 2b-2.6 | Auto-classifier on candidates | v0.8.37. HANDOFF-SUSPECT vs LEAK-FIX-LIKELY. **0 / 89** classified handoff-suspect. | runtime tool |
| 2b-2.7 | Per-candidate dataflow review | DEFERRED. Confirms classifier; identifies any dataflow-handoff cases the textual heuristic missed. | 0 (annotations only) |
| 2b-3-exp | Env-gated default-flip experiment | v0.8.38. NUC_AUTO_DROP_DEFAULT=1 enables flip for adopter validation. | runtime opt-in |
| 2b-3-trace | Identify why seed IR is byte-identical under flip | NEXT. The 89 candidate fns don't receive generated drop calls — code path gap. | 0 |
| 2b-3 | Flip default unconditionally | (after trace) | +0.05s |

### 2b-3-trace investigation notes (v0.8.40 partial)

Confirmed via standalone smoke that `env_get_or("NUC_AUTO_DROP_DEFAULT", "MISSING")`
correctly returns `"MISSING"` when unset and `"1"` when set. So the env-var
plumbing is functional at the runtime level.

Confirmed via FLIP-G1 audit-pass diagnostic that `env_get_or` is invoked during
seed self-host compilation and returns `"1"` when the env var is set.

But seed IR remains byte-identical (41 vec_free calls under both modes). The
gap is somewhere between `name_in_auto_drop` returning 1 (which it should under
flip) and `auto_drop_register` actually registering the binding for cleanup.

Hypotheses to test:
- (H1) `name_in_auto_drop` for the candidate fns is NOT being called from
  `lower_fn` (maybe an earlier dispatch routes the fns elsewhere)
- (H2) `name_in_auto_drop` returns 1 but `__auto_drop_enabled` sym isn't being
  set (maybe overwritten by a later sym_init call)
- (H3) `auto_drop_register` is called but `auto_drop_helper_for_type(tstr)`
  returns `""` because tstr doesn't match `Vec<...>` / `HashMap<...>`
  (maybe due to type-inference returning a non-canonical form)
- (H4) `auto_drop_register` registers correctly but `auto_drop_emit_live` isn't
  called at the right return path for these fns

Each hypothesis requires a targeted debug print at the relevant site to
confirm or rule out. Deferred to a focused future ship.
| 2b-3 | Flip default-on with `#[manual_drop]` opt-out | Lower every fn body as if it had `#[auto_drop]`; respect explicit `#[manual_drop]` to suppress. **DONE 2026-05-08** (commits f69234d8 + 08eba3c4 + 8cdee78d). Transitive-handoff recognizer extended to kind-7 fn calls — closes the move-into-struct-field handoff class structurally. PASS=1488/SKIP=1/FAIL=0 both hosts. Self-host fixed-point md5 = `86b491ca2d056f6006f4545e0e29d706`. | +0.05s (measured: cold compile 3.56s — DOWN from 3.87s pre-patch because kind-7 handoff recognition reduces redundant drop emissions across stdlib) |
| 3 | `#[manual_drop]` retained as first-class opt-out attribute through v1.0 | The 8 parser fns (`parse_generic_params`, `parse_fn_decl`, `parse_struct_decl`, `parse_enum_decl`, `parse_trait_decl`, `parse_impl_block`, `parse_match_stmt`, `parse_let`) carry `#[manual_drop]` and were validated as NOT redundant under default-flip via sub-experiment (see `findings/inbox/main_parser_revert_under_default_flip_v0846_2026-05-07.md`). The pr() Vec<i32>-wrapper handoff pattern is a distinct bug class still requiring the attribute. **manual_drop is a first-class language feature through v1.0.** | 0 |
| 4 | Remove `#[manual_drop]` entirely; only `unsafe { }` blocks can skip drop | **POST-v1.0.** Requires the 8 parser fns to migrate to either lifetime annotations or `unsafe { }` block bodies. Not a v1.0 blocker — manual_drop with the structural Phase 2b-3 default-flip already closes the silent-leak gap. Re-evaluate after Q1 (lifetime enforcement) lands. | 0 |

**Perf strategy:** the auto-drop lowering pass already exists for opt-in. Phase 2b just flips the default. The pass itself is O(N) over each fn AST and runs once per fn during lowering — adding it to all fns is +0.05s on the seed self-host. Acceptable.

### G-2 — Lifetime parameter enforcement (CRITICAL)

**Problem:** `<'a>` annotations parse, lex, type-check. The borrow checker does NOT enforce them. Two distinct `<'a>` regions in the same fn can alias.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | BR-7 warning | Audit-pass count of lifetime tokens. v0.8.17. | +0.0s (collapsed in v0.8.23) |
| 2a | — | Skip; G-2 needs proper analysis | — |
| 2b | Single-input single-output lifetime check | Per-fn pass: if signature is `fn f<'a>(x: &'a T) -> &'a U`, the returned reference must be derived from `x`. Conservative reject if not provable. | +0.1s per fn with lifetimes (~10% of fns); skip otherwise via early-exit |
| 3 | Multi-input lifetime check + lifetime elision rules | Standard Rust lifetime elision (`fn f(&self, x: &T) -> &T` infers `<'a>(&'a self, &'a T) -> &'a T`). | +0.05s incremental |
| 4 | Promote BR-7 warning to error | `<'a>` syntax must validate or compile fails. v1.0 cut. | 0 |

**Perf strategy:** the lifetime checker runs ONLY on functions whose AST contains lifetime tokens. Pre-pass detection (which we already have via BR-7 audit) gates the analysis. Most adopter code has zero lifetime tokens → zero cost. For functions with lifetimes, per-fn cost is bounded by AST node count.

### G-3 — Heap aliasing through Vec/HashMap (HIGH)

**Problem:** `Vec<&T>` containing two borrows of the same `T` is invisible to the syntactic tracker. HashMap rehash invalidates outstanding value borrows but the tracker doesn't notice.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Documentation | `docs/heap-aliasing-evidence.md` v0.8.18. | 0 |
| 2a | Heuristic warning when `Vec<&T>` is constructed | Audit-pass count of `Vec<&` substring. | +0.02s |
| 2b | Region-token invalidation on HashMap mutating calls | Each HashMap binding gets a region-token; `insert`/`remove`/`clear`/`reserve` bumps it; outstanding value borrows are invalidated. | +0.15s (region token tracking per-fn) |
| 3 | Vec-of-reference flow analysis | When `Vec<&T>` is constructed, conservatively assume every element borrows from the same region. | +0.1s |
| 4 | Promote both to errors | v1.0 cut. | 0 |

**Perf strategy:** region-token tracking uses indexed integers, NOT pointer-heavy maps. Per-fn arena allocation, freed at fn exit. Memory peak unchanged.

### G-4 — Double-free / use-after-drop (HIGH)

**Problem:** `vec_free(v); ...; v.push(7);` — adopter manually frees then uses. Today: silent crash.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | OWN-012 reservation | `docs/diagnostics/own-codes.md` v0.8.18. | 0 |
| 2a | Audit-pass info | Count `vec_free(` / `hashmap_free(` occurrences. **DONE v0.8.24.** | +0.03s (already paid) |
| 2b | IR-level use-after-drop tracking | Per-fn: `vec_free(v)` marks `v` as freed; subsequent reads/writes are warnings. | +0.08s per fn with explicit frees |
| 3 | Promote to deny-by-default warning | Adopters must add `#[allow(use_after_drop)]` to suppress (rare). | 0 |
| 4 | Hard error | v1.0 cut. | 0 |

**Perf strategy:** the drop tracker is a small per-binding flag (1 bit per local). Only runs on fns containing `vec_free` / `hashmap_free` (detected via the existing Phase 2a count).

### G-5 — FFI null contract (HIGH)

**Problem:** `extern fn fopen_or_null(path: str) -> *const c_void` returns NULL on failure. Adopter code that doesn't null-check before deref segfaults.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Documentation | `docs/ffi-conventions.md` v0.8.18. | 0 |
| 2a | Audit-pass info | Count `*const c_void` and `*mut c_void` return types. | +0.02s |
| 2b | Per-fn null-check inference | If extern fn returns `*const T`, the wrapping rod fn must include `ptr_is_null` or `unsafe { }` block before deref. | +0.05s per rod fn |
| 3 | Promote to lint warning | `#[allow(no_null_check)]` opt-out. | 0 |
| 4 | Hard error | v1.0 cut. | 0 |

**Perf strategy:** null-check inference is a textual pre-pass for the receiver; full IR analysis for the dereference path. Bounded by extern-fn-call-site count which is small.

### G-6 — Sendable propagation through nested types (HIGH)

**Problem:** `HashMap<K,V>`, closures, tuples, mixed-variant enums — Sendable propagation is unaudited / silently accepts.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Inventory | `docs/sendable-inventory.md` v0.8.20. | 0 |
| 2a | — | Skip; G-6 needs type-system work | — |
| 2b | Close 4 unaudited cases | HashMap (Sendable iff K,V Sendable AND hasher Sendable). Closures (Sendable iff captures Sendable). Tuples (componentwise). Enums (every variant). | +0.1s per spawn-call site |
| 3 | Tighten dyn-trait + Send bound requirement | `Box<dyn Trait>` requires explicit `+ Send` for spawn args. | 0 |
| 4 | RACE-NNN promotions | v1.0 cut. | 0 |

**Perf strategy:** Sendable check runs at spawn-call sites (already gated). The 4 new cases extend the existing kernel — same per-site cost, just more rules.

### G-7 — `unsafe { }` block audit (HIGH)

**Problem:** Per RFC-0062: "any unsafe block that hasn't been inventoried = silent trust."

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Inventory | `docs/unsafe-audit.md` v0.8.17. **Result: zero unsafe blocks in OSS .nr tree.** | 0 |
| 2a | — | N/A — nothing to enforce when count is zero | — |
| 2b | Property tests per C-runtime function | ~40 `*_rt.c` files; each gets a Nucleor fixture that fuzzes the FFI boundary invariant. | runtime cost, not compile cost |
| 3 | `@policy(no_unsafe)` default for new rod modules | Existing rods grandfathered. | 0 |
| 4 | All rod modules opt-in via `#[allow(unsafe)]` | v1.0 cut. | 0 |

**Perf strategy:** Phase 2b is runtime tests only. Phase 3-4 is policy-attribute enforcement which is one audit-pass scan.

### G-8 — Conditional-divergence move tracking (MEDIUM)

**Problem:** `if cond { take(v) } else { borrow(&v) }` — one path moves, the other borrows. After the if, `v` is partially consumed. Today the tracker doesn't reason about it.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Test set | `tests/fixtures/v0819_g8_*.nr` v0.8.19. | 0 |
| 2a | Audit-pass info | Detect `match`/`if-else` arms with mixed move/borrow patterns. | +0.05s |
| 2b | Per-fn move-state join | At control-flow join points, intersect move state across all incoming paths. Conservative: any path-with-move taints. | +0.12s per fn with conditionals (most fns) |
| 3 | Promote to warning | `#[allow(divergent_move)]` opt-out. | 0 |
| 4 | Hard error | v1.0 cut. | 0 |

**Perf strategy:** the join analysis is a small bitset operation per join point. Bounded by AST node count. Per-fn arena, no cumulative cost.

### G-9 — FFI bounds-check trust (MEDIUM)

**Problem:** Direct `extern fn` calls bypass the safe-code bounds check insertion. Adopter writing custom FFI gets no warning.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Documentation | `docs/ffi-conventions.md` §2 v0.8.18. | 0 |
| 2a | Audit-pass info | Count direct extern-fn calls outside `#[allow(direct_ffi)]`. | +0.02s |
| 2b | Per-call-site lint | Each extern-fn call without `#[allow]` gets a warning. | +0.03s |
| 3 | Promote `#[allow]` requirement | Extern-fn calls must have `#[allow(direct_ffi)]` on the caller fn or be inside `unsafe { }`. | 0 |
| 4 | Promote to hard error if missing | v1.0 cut. | 0 |

**Perf strategy:** call-site count, bounded by FFI use which is rare in adopter code.

### G-10 — Cross-fn ownership tracking (MEDIUM)

**Problem:** OWN-VAL diagnostics fire at fn boundary but not across fn calls. `f(&v)` where `f` does `vec_free(v)` internally is invisible.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Tracked via G-2 | The lifetime checker (G-2) handles cross-fn cases when lifetimes are annotated. | 0 |
| 2a | — | — | — |
| 2b | Effect annotations on fn signatures | `#[effect(frees)]`, `#[effect(borrows_mut)]`, etc. Inferred where possible; explicit at FFI boundary. | +0.1s |
| 3 | Promote inference + warning | Cross-fn ownership violations become warnings. | 0 |
| 4 | Hard error + required effect annotations at FFI boundary | v1.0 cut. | 0 |

**Perf strategy:** effect inference runs in a single pass after type-check; uses the existing AST.

### G-11 — Definite-assignment (MS-7 uninitialized read) (LOW)

**Problem:** TYP-008 already rejects `let mut x: i64;` even when every branch assigns. Strict but loud.

| Phase | Scope | Approach | Cold cost |
|---|---|---|---|
| 1 | Lock-in fixtures | `tests/err/err_g11_*.nr` v0.8.19. | 0 |
| 2a | — | TYP-008 already covers the simple case | — |
| 2b | Definite-assignment flow analysis | Track per-binding "assigned-on-every-incoming-path" bit at every read. Relax TYP-008 when satisfied. | +0.08s per fn with mut-without-init bindings |
| 3 | TYP-008 becomes Phase 2b-aware | Only fires when DA fails. | 0 |
| 4 | Stable | v1.0 cut. | 0 |

**Perf strategy:** the DA pass is a small bitset per binding, propagated through CFG. Per-fn arena.

---

## 4. Sequencing — ship-by-ship plan

### Wave A — Phase 2a audit-pass info diagnostics (in flight)

Heuristic warnings that ship in single ships. Goal: every gap has visible compile-time signal by ship +5.

| Ship | Gap | Status |
|---|---|---|
| v0.8.24 | G-4 OWN-012 audit-pass info | DONE |
| v0.8.25 | G-5 FFI null-return audit-pass info | DONE |
| v0.8.26 | G-9 direct-FFI audit-pass info | DONE |
| v0.8.27 | G-3 Vec-of-ref + HashMap-mut audit-pass info | DONE |
| v0.8.29 | G-8 cond-divergence Phase 2a info — **WAVE A COMPLETE** | DONE |
| v0.8.29+ | Wave B begins — Phase 2b proper analysis (per-fn IR-level checkers) | next |

### Wave B — Phase 2b proper analysis (medium, lockable)

Per-fn analysis passes. Each its own ship + tests.

| Ship | Gap | Effort | Cold delta |
|---|---|---|---|
| v0.9.x — TBD | G-2 single-input single-output lifetime | Medium | +0.1s on fns with lifetimes only |
| v0.9.x — TBD | G-4 IR-level use-after-drop | Small | +0.08s |
| v0.9.x — TBD | G-11 definite-assignment relaxation | Medium | +0.08s |
| v0.9.x — TBD | G-8 cond-divergence move-state join | Medium | +0.12s |
| v0.9.x — TBD | G-1 default-on auto-drop (with `#[manual_drop]` opt-out) | Medium | +0.05s |
| v0.9.x — TBD | G-3 region-token + Vec-of-ref flow | Large | +0.2s combined |
| v0.9.x — TBD | G-5 null-check inference | Small | +0.05s |
| v0.9.x — TBD | G-6 close 4 Sendable cases | Medium-Large | +0.1s on spawn sites |
| v0.9.x — TBD | G-9 direct-FFI lint | Small | +0.03s |
| v0.9.x — TBD | G-10 effect annotations + inference | Medium | +0.1s |
| v0.9.x — TBD | G-7 property tests per `*_rt.c` | Large | runtime, not compile |

### Wave C — Phase 3 default-on with opt-outs

Each Wave B item promotes from warning to deny-by-default after lock-in. Ships when adopter migration impact is acceptable.

### Wave D — Phase 4 hard errors (v1.0 cut)

Single coordinated cut. All Phase 4 promotions ship together as the v1.0 release. Adopter migration window between final v0.9 and v1.0 = 30 days.

---

## 5. Perf strategy — keeping cold under 4s through Wave D

Cold-time cost projection if every Phase 2b lands without optimization:

```
Baseline (v0.8.24):  3.39s
+ G-1 default-on:    +0.05
+ G-2 lifetime:      +0.10
+ G-3 region+vof:    +0.20
+ G-4 IR drop:       +0.08
+ G-5 null inf:      +0.05
+ G-6 4-cases:       +0.10
+ G-8 cond-div:      +0.12
+ G-9 direct-FFI:    +0.03
+ G-10 effects:      +0.10
+ G-11 DA:           +0.08
                     -----
Naive total:         4.30s  ← BREAKS Job #1
```

**This is unacceptable.** We need optimization built into each ship from day one. Five mandatory perf disciplines:

### 5.1 Early-exit on irrelevant code

Every Phase 2b checker must early-exit on functions where the relevant syntax is absent. The Phase 2a audit-pass scans (which we'll batch into one multi-needle pass) produce per-source-bundle counts for each construct. If the count is zero, skip the analysis entirely.

```nucleor
// Pattern for every Phase 2b checker:
fn run_g2_lifetime_check(ast: AST, audit_counts: AuditCounts) {
    if audit_counts.lifetime_tokens == 0 { return; }  // 99% of adopter code
    // ... real analysis only when needed ...
}
```

Expected savings: **0.4-0.6s** for typical adopter code (which has zero lifetime tokens, zero `unsafe`, zero direct FFI).

### 5.2 Per-function arena allocation

Every per-fn analysis pass uses a per-fn arena. Allocated at fn-enter, freed at fn-exit. No cumulative heap growth across fns. This is critical for the seed compiler self-host where 1000+ fns get analyzed.

Expected savings: **memory peak preserved at ~315MB** vs naive growth to ~600MB.

### 5.3 Multi-needle batched audit-pass scans — REVISITED

The original projection assumed batching 5 audit passes into one walk would save 0.15-0.25s. **Empirically false.** Two failed experiments:

1. **Vec<i64> consolidated batched pass (v0.8.28 attempt):** Vec-allocation + vec_get/vec_set per match imposed more overhead than the 4 saved walk-loop bookkeeping cycles. Net regression ~0.4s cold.
2. **3-needle cascade-if helper (`audit_count_three_needles_total`)** used at v0.8.33 first-attempt: cold 3.48 → 4.41s, hot 0.40 → 0.78s. Cascade-if branching pattern interferes with the tight inner-loop optimization.

**What works:** the v0.8.23 BR-7 collapse (3 needles into 1 helper) is the only success — likely because the source there already has `<'a` / `<'b` / `&'static` co-located in adopter signatures. Generic 3-needle batching does NOT win.

**Validated pattern:** each new Phase 2a audit uses 1-3 SEPARATE `simple_attribute_audit_count` calls, gated behind a cheap `str_index_of` pre-check. The gate skips full scans when none of the needles are textually present in the source. Adopter cost: zero unless the relevant pattern appears.

This is the pattern locked at v0.8.33 (G-6 SEND-G6 audit). All future Phase 2a / 2b audits should follow it.

### 5.4 Incremental cache friendliness

Every checker pass must integrate with the existing `.nuc_cache` infrastructure. Per-fn cache key = (fn source hash, checker version). Unchanged fns skip the analysis entirely.

This is automatic for adopter code (most fns unchanged across rebuilds) and 90%+ effective for the self-host (only edited fns re-analyzed).

Expected savings: **incremental rebuild stays at 0.4s hot** even after all Phase 2b lands.

### 5.5 Parallelism (Phase 4 only)

Per-fn analyses are embarrassingly parallel. Phase 4 ships parallelize them across CPU cores. Cold time on a 4-core machine drops by 2-3x.

Expected savings: **cold ~1.5s** on a 4-core machine after Wave D.

### Realistic projection with optimizations

```
Baseline (v0.8.24):           3.39s
+ Phase 2b passes (naive):    +0.91s  (sum of all deltas)
- Early-exit savings:         -0.50s  (most adopter code)
- Multi-needle batch:         -0.20s
- Arena reuse:                 0.0s   (memory only)
- Incremental cache:          -0.10s  (effective hit rate)
                              ------
Pre-Phase 4 cold:             3.50s   ← under Job #1
- Phase 4 parallelism:        -1.20s
                              ------
Post-Phase 4 cold:            2.30s   ← well under Job #1
```

**Cold time stays ≤ 4s through every ship of Wave A, B, C, D.** Memory peak stays ≤ 315MB through Wave A and B; Wave C may push to ~340MB; Wave D parallelism takes it back to ~320MB.

---

## 6. Validation gate

(Validation protocol document deferred per user directive. This section will fold in once that doc lands.)

Each ship in Wave A/B/C/D must include:

- Smoke fixture exercising the new diagnostic (positive case)
- Negative fixture in `tests/err/` if applicable (lock-in)
- Self-host fixed-point md5 verified
- Cold time ≤ 4s on a 5-run sample with mean ≤ 3.6s
- Memory peak ≤ 770MB hard, ≤ 360MB soft target
- CHANGELOG entry referencing the gap and phase

---

## 7. Status snapshot

**Updated 2026-05-04 after v0.8.24 ship.**

| Gap | P1 | P2a | P2b | P3 | P4 |
|---|---|---|---|---|---|
| G-1 auto-drop | ✓ v0.8.20 | n/a | queued | queued | v1.0 |
| G-2 lifetime | ✓ v0.8.17 | warn | queued | queued | v1.0 |
| G-3 heap alias | ✓ v0.8.18 | **✓ v0.8.27** | queued | queued | v1.0 |
| G-4 double-free | ✓ v0.8.18 | **✓ v0.8.24** | queued | queued | v1.0 |
| G-5 FFI null | ✓ v0.8.18 | **✓ v0.8.25** | queued | queued | v1.0 |
| G-6 Sendable | ✓ v0.8.20 | n/a | queued | queued | v1.0 |
| G-7 unsafe audit | ✓ v0.8.17 | n/a (zero unsafe) | runtime tests | queued | v1.0 |
| G-8 cond-divergence | ✓ v0.8.19 | **✓ v0.8.29** | queued | queued | v1.0 |
| G-9 FFI bounds | ✓ v0.8.18 | **✓ v0.8.26** | queued | queued | v1.0 |
| G-10 cross-fn | ✓ via G-2 | queued | queued | queued | v1.0 |
| G-11 MS-7 stress | ✓ v0.8.19 | n/a | queued | queued | v1.0 |

Phase 1 complete. Phase 2a one of five landed. Phases 2b/3/4 fully scoped, queued for Wave B/C/D execution.

---

## 8. Updates log

- **2026-05-04** v0.8.24: G-4 Phase 2a OWN-012 audit-pass info diagnostic landed. Plan document created.
- **2026-05-04** v0.8.25: G-5 Phase 2a FFI-NULL audit-pass info diagnostic landed.
- **2026-05-04** v0.8.26: G-9 Phase 2a FFI-DIRECT audit-pass info diagnostic landed. Three info diagnostics now firing on seed self-host (44 frees, 4 raw-ptr returns, 27 extern fns).
- **2026-05-04** v0.8.27: G-3 Phase 2a ALIAS-G3 audit-pass info diagnostic landed. Four info diagnostics now firing (added 3 Vec-of-reference patterns). Cold creeping to ~3.94-4.29s — at Job #1 ceiling. Next ship promoted: v0.8.29 perf consolidation (multi-needle batched scan) ahead of G-8 to claw back budget.
- **2026-05-04** v0.8.29: **WAVE A COMPLETE.** G-8 Phase 2a CFG-G8 info diagnostic landed (match-expression count). Five info diagnostics + BR-7 warning all firing on seed self-host. The promoted "v0.8.29 consolidation" experiment was attempted (Vec<i64> multi-needle batched, then str_count-routed) and BOTH reverted: Vec<i64> overhead regressed cold ~0.4s; str_count routing regressed hot from 0.40 to 0.79s. Current per-needle Nucleor-source loops are fastest in practice. Cold mean 3.71s (under Job #1). Real perf wins for Wave B will require per-source-hash audit cache infrastructure, not naive consolidation.
