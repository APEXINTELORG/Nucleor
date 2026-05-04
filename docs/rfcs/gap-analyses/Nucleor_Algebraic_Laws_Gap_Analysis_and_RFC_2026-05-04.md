# Nucleor — Algebraic Laws (`@law`) Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS` while drafting this.

---

# Part I — Definition

## 1.1. The algebraic-law pillar

`@law(...)` is positioned in the README, frontier audit, and language reference as one of Nucleor's headline differentiators: "no other mainstream language ships this as a first-class attribute." The claim is that user-declared algebraic laws (commutativity, associativity, identity, absorbing, idempotency, involution, fusion) drive an IR-level rewrite optimizer.

**The headline finding: the entire `@law` mechanism is silently dropped at lex time.** The lexer hits `@`, recognizes the generic attribute-skip path, and discards the whole `@law(...)` token sequence. There is no AST node, no IR annotation, no optimizer pass that consumes laws, no `Arbitrary` trait, no `nuc test --check-laws` (the CLI flag is silently dropped by the router), no Z3 integration. **The marketing claim is not backed by any implementation.**

Paradoxically, this means the soundness question is moot today: because no rewrite based on `@law` ever fires, no wrong `@law` declaration can produce a wrong result. The soundness hole only opens once the implementation lands.

---

# Part II — Gap Inventory

## LAW-1 — `@law(...)` is completely lexer-dropped — **CRITICAL**
The lexer's generic `@attr(...)` skip silently consumes every `@law(...)` annotation with no warning, no audit count, no forward-pass to any later stage. Zero AST representation. Fix requires lex-time extraction of the law token and argument list, attachment to function AST node, propagation to IR.

## LAW-2 — No optimizer pass consumes law annotations — **CRITICAL**
`opt_fn` runs 5 passes (constant folding, copy propagation, CSE, dead-store elim, DCE); none is an algebraic-rewrite pass. Language reference and `examples/06_perf_attrs.nr` claim identity-elimination, idempotence-folding, etc. fire at compile time — they do not. New pass `opt_law_rewrite_block` must be written.

## LAW-3 — `nuc test --check-laws` is a CLI no-op — **HIGH**
In `nuc_router.ps1`, `--check-laws` hits the `$ignored.Add($arg)` branch. The flag is accepted then silently discarded. Property-test synthesizer, `Arbitrary` trait, auto-generated `__law_*` test functions do not exist anywhere.

## LAW-4 — `Arbitrary` trait not implemented — **HIGH**
RFC-0031 §3.2 budgets ~400 LOC for `Arbitrary` impls for primitives, Vec, Option, Result, tuples. Nothing matching this name appears in the compiler or stdlib.

## LAW-5 — Z3/CVC5 integration (`--profile=cert`) not implemented — **MEDIUM**
The `cert` profile appears nowhere in the compiler. LAW-002 is registered in diagnostics but no SMT encoding or subprocess call to Z3/CVC5 exists.

## LAW-6 — Law-naming discrepancy between RFC-0031 and language-reference — **LOW**
RFC uses `inverse=g` and `zero=Z` (7 forms); reference uses `involution` and `absorbing` (8 forms, including `fusion` and `distributive`). Neither is enforced today; when LAW-1 is fixed, parser must resolve canonical names.

## LAW-7 — No `tests/features/rfc0031_*` fixture — **LOW**
Only `@law` test file is `tests/attrs/laws.nr`, which tests function correctness but not optimizer behavior. No fixture would fail if a law-driven rewrite is broken.

## LAW-8 — Build audit has no `@law` count — **LOW**
The build audit counts `@hot`, `@const_fn`, `#[max_depth]`, `#[deadline]` but has no `@law` audit count.

## LAW-9 — LAW-001/LAW-002 diagnostic codes are unreachable — **LOW**
Defined in explain registry, but property-test generation and SMT proof are unimplemented; codes can never fire. Misleading signal for adopters reading `nuc explain LAW-001`.

## Cross-cutting risks
- **Float associativity in strict mode:** Once LAW-1+2 land, `@law(associative)` on f64 gives wrong results. LAW-004 is defined to warn but only as docs infrastructure.
- **Overflow in identity/absorbing rewrites:** Constant-fold pass could fold using law before strict-mode overflow intrinsics inserted.
- **`#[test]` discovery gap interacts with `--check-laws`:** Auto-generated `__law_*` tests need a working test runner before `--check-laws` can function.
- **Marketing claim risk:** README and frontier audit treat `@law` as a shipped differentiator; it is not.

---

# Part III — RFC

## 3.1. Goals
1. Either ship the `@law` mechanism honestly or remove the marketing claim until it ships.
2. Honest disclosure in Phase 1: every `@law(...)` annotation produces a warning explaining it is not yet enforced.
3. Phase 2-3: lex-time extraction, AST attachment, optimizer pass.
4. Phase 4 (v1.0 gate): property-test verification + SMT proof obligations.

## 3.2. Closure plan

**Phase 1 (immediate, emergency disclosure):**
- Lexer extracts `@law(...)` content (instead of dropping) and emits warning LAW-WARN-001: "Algebraic law annotation accepted but not yet enforced. Optimizer rewrites based on `@law` are planned for v0.5+. See RFC-0031."
- Remove LAW-001/002 from `is_known_diag_code` registry until enforcement exists, OR add explicit "(not yet implemented)" to their explain text.
- Documentation pass: README and language reference clearly mark `@law` as planned, not shipped.
- Resolves: LAW-1 (partial — extracts but doesn't act), LAW-9.

**Phase 2 (short-term):**
- Lex-time extraction stores law kinds + arguments on function AST node.
- New optimizer pass `opt_law_rewrite_block` consumes the annotations:
  - Identity elimination: `f(x, identity_value) → x` and `f(identity_value, x) → x`
  - Absorbing elimination: `f(x, absorbing_value) → absorbing_value`
  - Idempotence folding: `f(x, x) → x`
  - Involution: `f(f(x)) → x`
- Audit block extended to count and name `@law`-annotated functions.
- Resolves: LAW-1, LAW-2 (partial), LAW-8.

**Phase 3 (medium-term):**
- Associative reassociation pass (commutative+associative both required).
- Distributive law and fusion pass.
- Resolves: LAW-2 (full).

**Phase 4 (v1.0 gate):**
- `nuc test --check-laws` synthesizes property tests from `@law` declarations.
- `Arbitrary` trait + impls for primitives and standard collections.
- Z3/CVC5 integration for `--profile=cert` SMT proof obligations.
- Float associativity check (LAW-004): warning when `@law(associative)` on float-returning function without `eps` parameter.
- Strict-mode interaction: identity/absorbing rewrites must respect overflow semantics.
- Resolves: LAW-3, LAW-4, LAW-5, LAW-6 (canonical names enforced), LAW-7 (fixtures land alongside).

## 3.3. v1.0 release gate
Phase 1 minimum (honest disclosure) must land before any further marketing. Phase 2-3 land alongside the type-system width-correct work (T-1) since both are optimizer-pass changes. Phase 4 acceptable to ship as v1.x if Phases 1-3 cover the core rewrites.

## 3.4. Open questions
1. Resolve naming discrepancy: keep RFC-0031's `inverse`/`zero` or language-reference's `involution`/`absorbing`? Recommendation: language-reference names; they're more standard mathematical terminology.
2. Should Phase 2 ship without commutative/associative reassociation? Recommendation: yes — identity/absorbing/idempotence/involution are higher-leverage and lower-risk than reassociation (which interacts with FP precision).
3. Does the `nuc test --check-laws` framework depend on the broader `#[test]` framework being shipped? Recommendation: yes — defer to after `#[test]` is real.

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Algebraic_Laws_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
