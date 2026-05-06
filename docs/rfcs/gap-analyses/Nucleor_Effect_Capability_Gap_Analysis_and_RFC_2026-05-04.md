# Nucleor — Effect and Capability System: Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS` while drafting this.

---

# Part I — Definitions

## 1.1. The effect/capability pillar

Nucleor's marketing surface (frontier-language audit, README, RFC-0032/0033) presents capability tokens (`SchedulerCap`/`RandomCap`/`FsCap`/`NetCap`) and effect declarations (`requires [...]`, `restricts [...]`, `pure fn`) as **first-class compile-time-enforced contracts**. This document audits whether that's true.

**The headline finding: it is mostly not true in the s1 build path.** The `requires` and `restricts` keywords were deliberately removed from the s1 lexer in v0.3.139/140 to fix silent-miscompute bugs. They are now silently discarded by the s1 parser. Effect enforcement runs in the tools-suite path (`nuc audit`, `nuc check`) but not in `nuc build`. **A user running `nuc build` — the normal workflow — gets no effect signal.**

This is a fundamental trust gap. It needs to be either closed (the effect system actually enforces in `nuc build`) or honestly disclosed (every `requires`/`restricts`/`pure fn` annotation produces a compiler warning explaining it isn't enforced).

## 1.2. Thirteen effect/capability validation categories (E-VAL-1 through E-VAL-13)

Maps to the gap inventory in Part II.

---

# Part II — Gap Analysis

## 2.1. Stated goals

- **RFC-0032 (Draft, target v0.6):** `pure fn`, `requires [effect]`, `restricts [...]` blocks, transitive effect inference, EFF-001..005, capability tokens. "Resurrect V1-quarantined effects syntax."
- **RFC-0033 (Draft, design-only, target v0.5 grammar / v0.9 implementation):** Typed `with [...]` clause on function types, effect-row subtyping, transitive callee-into-caller propagation, EFF-001..008.
- **RFC-0057, RFC-0062 (referenced):** `FsCap`/`NetCap` as capability tokens.

## 2.2. The thirteen gaps

### E-1 — `pure fn` body not enforced in s1 build path — **CRITICAL**
The s1 compiler parses `pure fn`, stores a kind-46 marker node, then performs **zero enforcement.** No effectful-call check, no EFF-001/002 diagnostic. A user writing `pure fn compute(...) { print("hello"); }` gets a binary that runs `print` with no error. The purity contract is a comment, not a guarantee at `nuc build`.

### E-2 — `requires [fs.read]` in user source silently discarded in s1 — **CRITICAL**
Since v0.3.139, `requires` is no longer a keyword. At each parsing site, `skip_bracket_list` consumes the `[...]` content and throws it away. **No AST node is built. No diagnostic fires. No capability checking occurs.** Annotations silently vanish from compilation.

### E-3 — `restricts [io] { ... }` is not valid syntax in s1 build — **CRITICAL**
Since v0.3.140, `restricts` is not a keyword. The intended block-form has no parser branch. In expression position, `restricts` lexes as an identifier; `[io]` is parsed as an index op; `{` begins a struct-literal-like expression. Result is malformed and compiler-specific — no clean parse, no diagnostic, no enforcement.

### E-4 — Effect inference is tools-suite-only and source-text-only — **HIGH**
Transitive propagation through call graph requires `infer_source_effects`, which exists only in tools-suite. The s1 build path has no call-graph effect inference at all. Three deep-chain tests in `_unimplemented/` confirm this is not working even in tools-suite.

### E-5 — `pure fn` effect check is warning-level and builtin-only — **HIGH**
Tools-suite `effect_check_fn` fires EFF-001 as a warning (RFC says error), only for the hardcoded `is_effectful_builtin` list. **Calling a user-defined function with side effects from `pure fn` does NOT trigger EFF-001.** Calling `ambient_random()` from `pure fn` does NOT trigger EFF-001 (not in the list). Pure-fn check is unsound where it does fire.

### E-6 — `FsCap`, `NetCap`, `TimeCap`, `EnvCap` do not exist — **HIGH**
Only `RandomCap` and `SchedulerCap` have `ambient_*` builtins with defined return types. The other four capability tokens mentioned in RFC-0057 and RFC-0062 have **no `ambient_*()` function, no type-level tracking, no enforcement.** Names without implementations.

### E-7 — EFF-001/002 diagnostics do not fire at `nuc build` — **HIGH**
EFF-001 and EFF-002 are registered in s1's diagnostic code table and appear in `nuc explain` output, but **neither fires during `nuc build`.** Tools-suite outputs only. A user relying on `nuc build` for effect safety gets no signal.

### E-8 — `with [...]` clause enforcement is partial and source-text based — **MEDIUM**
The `with [...]` clause is skipped by the AST parser. **Only the `no_alloc`/`Alloc` cross-check is enforced** via source-text header scanning. `with [Panic]`, `with [Filesystem.read(...)]`, `with [IO]`, `with [Random]`, `with [Network.connect(...)]`, `with [pure]` etc. have zero enforcement.

### E-9 — `pure fn` check has bounded same-file/user-surface coverage — **MEDIUM REMAINING**
The s1 build path now rejects `pure fn f()` when it calls a same-file user helper whose body directly performs print/alloc/ambient side effects, when it calls an undeclared extern/default-unsafe effect surface, or when the body uses structured scheduling (`scope { ... }` / `spawn { ... }`) or `channel(...)`. The remaining gap is broader effect inference: transitive `requires [...]` row propagation, imported modules, shadowed names, method calls, closures, higher-order calls, and effect-row subtyping are still not AST-backed.

### E-10 — `ambient_random()` in `pure fn` fires link error, not EFF-001 — **MEDIUM**
The `err_pure_ambient_random.nr` test is in `tests/err/` (active) but with comment: "EXPECT: link error... should fire pure-vs-effect; actually link-fails on `__nucleor_ambient_random` v0.4 placeholder." Test passes for the wrong reason. **No EFF diagnostic fires; runtime helper symbol is missing, causing linker error.**

### E-11 — Cross-module effect propagation absent — **MEDIUM**
Effect inference does not cross `import` module boundaries. Pure function calling imported function with I/O effects will not be flagged.

### E-12 — RFC-0033 v0.9 — grammar reserved only — **LOW**
`with [...]` grammar reserved and parsed (skipped), but type-level effect row, function pointer subtyping, generic effect polymorphism, and closure effect inference described in RFC-0033 are all unimplemented. Definition-of-done checklist entirely unchecked.

### E-13 — EFF-001 documented as warning in tools-suite, not error — **LOW**
RFC-0032 says EFF-001..003 are errors. Tools-suite emits EFF-001 as warning. Contradicts the RFC.

## 2.3. Cross-cutting risks

- **The "tools-suite enforces but build doesn't" pattern is a fundamental trust gap.** Architecture splits enforcement between two compilers. `nuc build` (s1) has zero effect enforcement. CI running only `nuc build` against fixtures gets no effect signal. Effect annotations become misleading documentation.
- **Capability token soundness — aliasable through i64.** `RandomCap` is opaque i64 wrapped in type alias. Nothing prevents `let cap: i64 = 0; let fake: RandomCap = cap;`. Type alias provides naming discipline but not runtime-checked authority.
- **Effect inference completeness.** Source-text scanning means shadowed names, method calls, closures, higher-order calls, and cross-module calls are not correctly analyzed. Same-file pure calls into direct-effect helpers are now covered, but full `requires [...]` row propagation and AST-backed effect inference remain open.
- **The `requires`/`restricts` keyword removal is a public-facing trust issue.** Removal was correct fix for silent-miscompute class. Fix made by silently discarding clause content rather than issuing "feature not yet implemented" diagnostic. **A user writing documented effect syntax today gets no warning that the annotation has zero effect.** From the user's perspective, the annotation looks valid, the code compiles, the contract appears enforced. It is not.

---

# Part III — RFC

## 3.1. Goals

1. **Honest disclosure:** until enforcement is real, every effect/capability annotation produces a compiler warning explaining it is not enforced.
2. **Close the three CRITICAL gaps** by either implementing enforcement or restoring the keywords with proper diagnostics.
3. **Unify the two compilation paths** — `nuc build` and tools-suite should have the same enforcement surface, not divergent ones.
4. **Real capability tokens** — implement `FsCap`, `NetCap`, `TimeCap`, `EnvCap`, and make their use checkable.

## 3.2. Closure plan, by gap

### E-1, E-2, E-3 (s1 silently accepts/discards effect annotations) — Phase 1 emergency

**Immediate (Phase 1):** Restore `pure`, `requires`, `restricts` as recognized contextual keywords in s1. When parsed, they store an AST annotation. **Emit a warning E-WARN-001:** "Effect annotation accepted but enforcement is incomplete in `nuc build`. Run `nuc check` for full effect analysis. See RFC-0032." This eliminates the silent-discard trust hazard.

**Short-term (Phase 2):** Move the tools-suite `effect_check_fn` and `infer_source_effects` into the s1 compilation pipeline. `nuc build` runs the same effect checks as `nuc audit`. EFF-001/002/003 become build errors, not just tools-suite warnings.

**Medium-term (Phase 3):** Replace source-text scanning with AST-based effect inference. Cross-module call graph through the import resolver. Comments and shadowed names no longer pollute the analysis.

**v1.0 (Phase 4):** Effect annotations are fully enforced at `nuc build`. The warning E-WARN-001 is removed (no longer needed).

### E-4, E-9, E-11 (effect inference incomplete) — Phase 2-3
Cross-references E-1/2/3 Phase 2-3. Same closure work.

### E-5 (pure-fn check is warning + builtin-only) — Phase 2
- Promote EFF-001 from warning to error.
- Extend `is_effectful_builtin` to include `ambient_random`, `ambient_scheduler`, `ambient_fs` (when implemented), `ambient_net` (when implemented), `ambient_time`, `ambient_env`.
- Same-file transitive check: pure fn calling a user fn with direct print/alloc/ambient side effects now triggers EFF-001.
- Pure effect-surface expansion: pure fn calling an undeclared extern now triggers EFF-001, and pure fn bodies using structured scheduling (`scope { ... }` / `spawn { ... }`) or `channel(...)` trigger EFF-001. Remaining work is effect-row propagation beyond these bounded same-file/default-extern cases.

### E-6 (missing capability tokens) — Phase 2
Implement `FsCap`, `NetCap`, `TimeCap`, `EnvCap`:
- Add `ambient_fs()`, `ambient_net()`, `ambient_time()`, `ambient_env()` as runtime functions returning typed handles
- Add type recognition in s1 (move-only Copy types; `RandomCap` style)
- Add use-site enforcement: any function performing fs/net/time/env operation must take the corresponding capability as a parameter (or call `ambient_*` and consume the capability)

### E-7 (EFF-001/002 not fired at build) — Phase 1
Same as E-1/2/3 Phase 1 emergency closure. Once the tools-suite effect checker runs in s1, EFF-001/002 fire at build.

### E-8 (`with [...]` enforcement partial) — Phase 2-3
- Phase 2: extend the source-text scanner to handle the full effect catalog (Panic, IO, Random, Network, Filesystem, etc.), not just no_alloc/Alloc.
- Phase 3: AST-based effect-row checking per RFC-0033.

### E-10 (ambient_random link-error workaround) — Phase 1
Implement `__nucleor_ambient_random` runtime function (currently the placeholder). Replace the err test's failure mode with proper EFF-001 firing.

### E-12 (RFC-0033 grammar only) — Phase 3-4
RFC-0033 implementation per its v0.9 schedule. Function-pointer effect subtyping, generic effect polymorphism, closure effect inference. Large work but explicitly v0.9-deferred and acceptable for v1.0 if Phase 1-2 closures are in place.

### E-13 (EFF-001 severity inconsistency) — Phase 1
Promote tools-suite EFF-001 from warning to error to match RFC-0032.

## 3.3. Phasing summary

| Phase | What lands | Closures |
|---|---|---|
| **Phase 1 (emergency)** | E-WARN-001 disclosure warning on every effect annotation; EFF-001 promoted to error; ambient_random impl | E-1 P1, E-2 P1, E-3 P1, E-7, E-10, E-13 |
| **Phase 2** | Tools-suite effect checks merged into s1 build; EFF-001/002/003 build errors; transitive pure-fn check; FsCap/NetCap/TimeCap/EnvCap implemented; full effect catalog scanner | E-1 P2, E-2 P2, E-3 P2, E-4, E-5, E-6, E-8 P2, E-9, E-11 |
| **Phase 3** | AST-based effect inference, cross-module call graph, RFC-0033 effect-row checking | E-1 P3, E-4 P3, E-8 P3, E-12 P3 |
| **Phase 4 (v1.0 gate)** | Full enforcement; E-WARN-001 removed; RFC-0033 effect-row subtyping | E-1 P4, E-12 P4 |

## 3.4. v1.0 release gate

Phases 1-2 minimum. Phase 3 (AST-based inference, cross-module) for v1.0 if feasible, otherwise documented as v1.x. **The trust gap closure (Phase 1 disclosure warning) MUST land before any further marketing of the effect/capability system as a feature.**

## 3.5. Open questions

1. Should `requires`/`restricts` be promoted back to hard keywords in v1.0, or remain contextual? Hard keywords are cleaner but require migration for any user code that named functions `requires`/`restricts`. Recommendation: contextual through v1.0; hard keywords only if RFC-0032 reaches Phase 4.
2. Capability token soundness — should `RandomCap` etc. be **typed structs**, not type aliases? Recommendation: yes, struct wrapping the i64 handle, so type confusion can't bypass the capability check.
3. Should the build-time effect check be optional (off by default for performance) or always on? Recommendation: always on; effect check is fast; off-by-default re-creates the trust gap.

---

# Part IV — Disposition

**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Effect_Capability_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
