# RFC v1 Forward Roadmap — deferred items from v0.6.x punchlist

> Drafted 2026-05-03 by main agent at end of v0.6.48–v0.6.72 ship session.
> Probe inbox is at 0 unmatched. Six multi-finding workstreams closed.
> All remaining work is v1-class: requires dedicated design + ship cycles
> and will likely cost perf budget, breaking the v0.6.70 cold ~3.1s floor
> that the no-drift rule protects. Each item below has been prototyped or
> evaluated; the cost/benefit notes are concrete.
>
> Pick items in priority order based on adopter pain. Each item gets its
> own RFC + dedicated cycle when chosen.

## Priority tiers

### Tier 1 — biggest adopter pain

These are items where adopters porting Rust code hit them DAILY. Closing
them widens translation fidelity meaningfully.

#### V1.1 — Tuple-struct positional-field synthesis + `.0`/`.1` access  ✅ CLOSED v0.6.74

**Closed v0.6.73 (step 1: parse acceptance) + v0.6.74 (steps 2+3:
ctor + positional access).** Tuple-struct decl, constructor call,
and `.0`/`.1` field access all working. Sister `match` nested
struct pattern (sub-case 1 in NR020 finding) clean-halts; full
recursion belongs in a separate parse-extension cycle.

**Status today (historical):** v0.6.53 shipped parse halt with named-field workaround
diagnostic. Adopters port-blocked on any Rust crate using `struct
Pair(T1, T2);` shapes (very common — RGB colors, 2D points, fn-pointer
wrappers, newtype patterns).

**Scope:**
- Extend `parse_struct_decl` to accept paren-form, synthesize fields named `__0`, `__1`, etc.
- Extend `parse_postfix` `.<digit>` access path to map to `__<digit>` field lookup.
- Constructor call `P(a, b)` already syntactically resembles a fn call — reuse the kind-7 type-check path with positional-arg-to-named-field mapping.

**Estimated cost:** ~600 lines compiler-side. Some perf cost from
field-name-resolution lookup at `.0`/`.1` sites — should be small if
implemented as direct kind-9 branch.

**Sister:** nested struct pattern `match l { Line { a: Point { x, y }, b: _ } => x }`
— same v1.1 ship if recursive `parse_match_struct_binding_block` is added.

#### V1.2 — Generic-T inference for literal init  ✅ CLOSED v0.6.75

**Closed v0.6.75 (2026-05-03).** `types_compatible` extended with
explicit Box<T> recursion shape (matching the existing Vec/Option
pattern) plus a literal-default widening rule — i32 actual accepted
into wider int-typed expected (i64 / isize / i16 / i8). Cheap
first-char gate ('B' check) preserves the cold floor.

**Status today (historical):** v0.5.x partial closed inline-bound owned-T case.
v0.6.x shipped type alias resolver. v0.6.75 closed the Box<T> + literal
case via types_compatible recursion + literal-default widening.

**Scope:**
- Extend `type_expr` with optional `expected_t: str` hint parameter.
- At kind-7 (call) sites where the receiver expects a generic instantiation, propagate the expected T into argument typing.
- Update int-literal default to widen toward the expected type when expected is a wider int.

**Estimated cost:** ~300 lines. Hot-path risk medium — the expected-T
hint flows through every type_expr call site, so any non-zero overhead
multiplies. Use Optional pattern (empty str = no hint, fast path).

**Sister:** iter map type-changing closure collect, `<T: Show>(x: &T)` reference-receiver shape.

#### V1.3 — Drop / RAII auto-call on scope exit

**Status today:** All Drop / leak findings (vec-alloc-leak,
str-concat-rebind-leak, drop-trait-never-auto-called,
move-semantics-not-enforced) deferred. Adopters explicitly call
`vec_free` / `string_free` / `hashmap_free` — discipline-based, error-prone.

**Scope:**
- Borrow-checker pass: compute scope-exit points per binding (early-return, panic, normal block end, loop iter boundaries).
- For each binding of a heap-allocating type or with impl Drop, emit the cleanup call at scope-exit points.
- Move-semantics enforcement: track `let v2 = v;` as ownership transfer; reject use of `v` after.

**Estimated cost:** ~2000-3000 lines. New flow-analysis pass. **Significant
perf cost** — ownership tracking runs per-stmt and is fundamentally
required for safety. Acceptable within the v1 boundary because adopter
benefit (no manual cleanup) is huge.

### Tier 2 — high adopter pain but narrower

#### V1.4 — derive(PartialEq) / Hash for Vec / struct / HashMap  ✅ CLOSED v0.6.85

**Closed v0.6.85 (2026-05-03; paired with v0.6.84).** Textual pre-pass
`expand_derive_partialeq` auto-generates `<Type>__derived_eq(a, b) ->
i64` helpers (v0.6.84). lower_expr binop kind-4 op==30/31 routes
`==` / `!=` to the helper via `sym_get(__fnret_<Type>__derived_eq)`;
type_expr suppresses the TYP-011 ptr-compare diag when the helper
exists (v0.6.85). Generic structs and Hash/Default still pinned to
the monomorphisation v1.x ship.

**Status today (historical):** assert_eq! pointer-compare extends pre-v0.6.x family.
str values get structural compare via __nucleor_str_eq; other heap-types
get pointer compare → false negatives on byte-equal but differently-allocated values.

**Scope:**
- At struct decl with `#[derive(PartialEq)]`, auto-emit `__<Type>_eq(a, b)` fn that field-wise compares.
- assert_eq! / `==` for kind-12 struct ctor recipients dispatch to derived eq.
- Same for Vec<T> (element-wise via vec_eq), HashMap<K, V> (key-set + value-by-key).

**Estimated cost:** ~400 lines per derived trait. Per-struct emit is
proportional to field count. Hot-path negligible (only fires on
explicit comparisons).

#### V1.5 — Length-tagged str ABI

**Status today:** `str_len(s)` calls C strlen → truncates at NUL byte.
`str_concat`/`str_substring` produce fresh allocations. NUL-bearing
str values silently truncate.

**Scope:**
- New header: `{ char *data; size_t len; }` for str.
- Rewrite ~30 `__nucleor_str_*` runtime helpers to use length-tagged ABI.
- Update str literal emission to include the length tag.
- Adopter migration: existing `str_*` helpers transparently still work; binary-safe code can skip NUL-truncation hazards.

**Estimated cost:** ~600 lines + ~30 helpers. **Cross-cutting ABI change** —
breaks every existing fixture. High risk; needs paired migration tooling.

#### V1.6 — RFC-0008 phase 2 (no-alloc / no-panic call-graph propagation)

**Status today:** v0.6.x catches direct alloc/panic in `#[no_alloc]` /
`#[no_panic]` / `#[isr]` fn bodies. Helper-routed alloc/panic compiles
clean — defeats the safety promise transitively.

**Scope:**
- Per-fn analysis: classify each fn as alloc-y / panic-y based on body content.
- Call graph walk from each `#[no_alloc]` / `#[no_panic]` / `#[isr]` root.
- Reject if any reached fn is alloc-y / panic-y.
- Indirect-call (fn ptr / closure) handling: conservative reject without explicit annotation.

**Estimated cost:** ~500-800 lines. Type-check time only (compile-time, not runtime). Hot-path: walks call graph per `#[isr]` fn — cost proportional to graph size.

### Tier 3 — translation-fidelity polish

#### V1.7 — UFCS dispatch `<S as Foo>::f(&s)`  ✅ CLOSED v0.6.81

**Closed v0.6.81 (2026-05-03).** parse_primary `<` branch now parses
`<TypeName as TraitName>::method(args)` (with optional `<...>` trait
generics) and lowers to kind-7 call on the existing type-mangled name
`<Type>__<method>`. UFCS-as-disambiguator under multi-trait collision
remains pinned to per-trait mangling (v1.x trait-dispatch ship); for
now v0.6.81 is a translation-fidelity surface for adopters porting
Rust code.

**Status today (historical):** v0.6.60 parse halt. v0.6.81 added the
canonical shape acceptance.

**Scope:**
- parse_primary `<` branch: parse `<TypeExpr as TraitName>::method`.
- type-check: bound-scoped dispatch to specific trait impl.
- lower: generate the explicit method call with disambiguated name.

**Estimated cost:** ~250 lines. Mid v1 work.

#### V1.8 — break-with-value `let r = loop { break 42; };`

**Status today:** v0.6.57 parse halt. Adopters use mut-outer-var workaround.

**Scope:**
- parse_stmts kind-26 (break) branch: accept optional value expression.
- Lower: emit value into a per-loop result slot; `let r = loop {...}` reads from slot.

**Estimated cost:** ~200 lines. Small v1 ship.

#### V1.9 — assert!/assert_eq!/assert_ne! format-args expansion  ✅ CLOSED v0.6.76

**Closed v0.6.76 (2026-05-03).** Textual rewrite at expand_format_macros
pass: cheap name gate (`assert`/`assert_eq`/`assert_ne`) plus comma-count
+ `"`-shape check identifies format-arg form, then rewrites to
`if !(cond) { panic!(fmt, args); };` (or `==`/`!=` for the eq/ne
variants). Reuses mode-5 fmt_build_expansion. Cold stays at 3.35–3.4s
(baseline 3.16s) — comma walk cost limited to assert calls only.

**Status today (historical):** v0.6.39 closed panic! mode-5. Asserts still dropped.
v0.6.73-attempt regressed perf 1.7s due to per-call-site comma-walking.
v0.6.76 fixed via name-cheap gate.

**Scope:**
- Cheap pre-check at the macro substitution path: detect format-arg form via single-`"` peek after `(`.
- Multi-arg form expands to `{ if !(cond) { panic("fmt-expanded"); }; }` block.

**Estimated cost:** ~150 lines + careful perf measurement. Risk:
per-assert cost. Use shape detection to avoid full walk.

#### V1.10 — Closure capture flow inside loop bodies

**Status today:** Closures + while/loop body captures fail (3 sister
findings: closure-cant-call-sibling, closure-vec-capture-with-while,
closure-capture-broken-in-loop-bodies).

**Scope:**
- Closure body env-set: walk enclosing scope for sibling closure bindings.
- Capture-flow: detect re-write of captured slots inside loop iter; pin
  vs copy as needed.

**Estimated cost:** ~400 lines. Sister to V1.3 borrow-checker.

#### V1.11 — Other deferred items (smaller)

- **HashMap<i64, V> key-type-aware** — separate hash/eq helpers per key-type-class. (~600 lines, runtime ABI extension.)
- **`[VAL; N]` array literal repeat-init** — ✅ CLOSED v0.6.77 (parse_primary `[` branch peeks for `;` after first item, expands to N-item kind-47 array literal; literal-int count only, hard cap N ≤ 1024, runtime-evaluated counts go through `vec![V; N]`).
- **`&[T]` slice param** — ✅ CLOSED v0.6.78 (parse_type `[` branch peeks for `]` after inner type — bare `[T]` resolves to `Vec<T>` so `&[T]` becomes `&Vec<T>`. Length-tagged slice ABI remains pinned to V1.5).
- **`fn-no-tail-expr` Repro 3** — needs AST-level `;` tracking (~100 lines, but invasive).
- **`fn-ptr struct field direct call`** — parse `(struct.field)(args)` as indirect call (~150 lines).
- **method ambiguity UFCS resolution** — sister to V1.7.
- **Tuple destructure in let** — `let (a, b) = (5, 7);` (~150 lines, sister to V1.1).
- **i32 binop narrowing in expression context** — extend narrow_via_as to non-let contexts (~300 lines, hot-path risk).

### Tier 4 — Drift restoration (added 2026-05-03)

These three items are documented drift from Nucleor V2 — features that existed in V2 but were lost in OSS. Each has a dedicated RFC. Sister memo: `Desktop/Nucleor_Drift_Triage_2026-05-03.md`.

#### V1.12 — Restore `fixed<I, F>` IR type
**RFC:** `RFC-0043-fixed-point-IR-type.md`. Pre-fix: parse-only sugar that collapses to `i64`. Post-fix: full IR type with width tracking. Cost: ~300 LOC compiler + 6 runtime helpers.

#### V1.13 — Per-BinOp `OverflowMode` field
**RFC:** `RFC-0044-per-binop-overflow-mode.md`. Pre-fix: block-form only (`wrapping{}`/`saturating{}`/`checked{}`). Post-fix: per-op `*#wrap` / `*#sat` / `*#trap` markers + Cast equivalents alongside the block form. Cost: ~150 LOC.

#### V1.14 — Restore `@differentiable` annotation
**RFC:** `RFC-0045-differentiable-attribute.md`. Pre-fix: dropped from OSS entirely. Post-fix: parser+attribute marker; semantic enforcement deferred. Cost: ~50 LOC.

### Tier 5 — Governance rod (added 2026-05-03 — DECISION MADE: Shape B / optional rod)

#### V1.15 — `governance.nr` rod (Shape B — optional, NOT compiler enforcement)
**RFC:** `RFC-0060-governance-rod.md` (promoted from `SPEC-governance-attributes.md` placeholder).
**Source spec:** `Desktop/Nucleor_Governance_Rod_Spec_2026-05-03.md`.
**Decision:** governance ships as an OPTIONAL rod. s1 compiler stays as-is. Rod surfaces `AuthorRecord` / `PolicyDecl` / `EvidenceBundle` / `SchemaDecl` types, `nuc gov` CLI subcommands, and Ed25519 signing for evidence bundles.
**Blocking prerequisite (Phase 1):** restore `tools/native_release.ps1` (currently missing — `nuc publish --sign` non-functional).
**Total cost:** ~600-800 LOC `.nr` + ~400-500 LOC C runtime + ~100-150 LOC CLI dispatch.

### Tier 6 — Tooling drift (added 2026-05-03)

#### V1.16 — LSP server reinstatement
**SPEC:** `SPEC-LSP-server.md`. V0 path: subprocess LSP daemon (~600 LOC + ~200 LOC compiler `--lsp-mode`). V1 path: library factor for live diagnostics (~3000 LOC compiler refactor).

### Tier 7 — Graph remediation (added 2026-05-03)

#### V1.17 — Graph polish (Tier 1+2+5 from spec)
**RFC:** `RFC-0061-graph-remediation.md` Tiers 1, 2, 5.
**Source spec:** `Desktop/Nucleor_Graph_Remediation_Spec_2026-05-03.md`.
- Tier 1 (V1.17a): missing wrapper fns + adjacency-matrix view + CLI verb docs + 3 smoke fixtures (~150 LOC stdlib + 50 LOC docs).
- Tier 2 (V1.17b): `nuc deps graph` CLI with text/json/dot/mermaid renderers (~150-200 LOC).
- Tier 5 (V1.17c): `docs/graph-capabilities.md` consolidation.

#### V1.18 — Trace/event graph hardening (Tier 3 from spec)
Expose quantum entanglement tracker + gate-influence DAG as queryable graphs. ~150-180 LOC across `quantum.nr` + `quantum_rt.c`.

#### V1.19 — Graph-aware optimization passes (Tier 4 from spec — DECISION REQUIRED)
**Preflight:** Sonnet confirm-pass against `Desktop/Nucleor_V2/` to confirm whether V2 had `attention()` → `flash_attention` rewrites + call-graph-driven inlining shipped or just staged. If shipped: Option B (selective restore — 2 highest-value rewrites). If staged: Option A (defer + document).

## Cost summary

| Tier | Items | Total LOC | Perf risk |
|---|---|---|---|
| Tier 1 (V1.1–V1.3) | 3 | ~3000 | High (borrow-checker) |
| Tier 2 (V1.4–V1.6) | 3 | ~1800 | Medium |
| Tier 3 (V1.7+) | 8+ | ~2200 | Mostly low per-item |
| Tier 4 (V1.12–V1.14, drift restore) | 3 | ~500 | Low |
| Tier 5 (V1.15, governance — TBD) | 1 | TBD | TBD |
| Tier 6 (V1.16, LSP) | 1 | ~800 (v0) / ~3500 (v1) | Low (subprocess); medium (library) |

Grand total: ~7000+ LOC of v1 work across 17+ items (pre-governance-TBD).

## See also

- **`RFC_v2_FRONTIER_ROADMAP.md`** — frontier features (V2.1 through V2.13). Easy wins (RFC-0046 through RFC-0051) should run BEFORE deep V1 work.
- **`Desktop/Nucleor_Drift_Triage_2026-05-03.md`** — verified-drift triage memo (provides rationale + status for each drift item).
- **`Desktop/Nucleor_Build_Spine/BUILD_PATH_v0.4_to_v1.3.md`** — canonical 1–13 punchlist (the spine).
- **Nucleor_Translate** project at `Desktop/Nucleor_Translate/` — language translator (Python/Rust/etc → Nucleor); separate spine consumer.
- **ML expansion docs** — `Desktop/Nucleor_Build_Spine/03_TRIAGE/ML_EXPANSION_SET_INTEGRATION_2026-05-01.md` + `Desktop/Nucleor_ML_Expansion_Spine_Integration_Brief_2026-05-01.md` + `Desktop/Nucleor_Build_Spine/07_CODEX_DOCS/ML_EXPANSION_INPUTS_2026-05-01/` — ML expansion items get folded into V2 frontier roadmap and Nucleor_Translate's spec phase.

## Recommended first ship

**V1.1 tuple-struct positional-field synthesis** — biggest adopter
pain (every Rust crate using tuple structs blocked); bounded scope
(~600 lines); minimal perf risk; concrete success criterion (existing
`struct P(T1, T2);` code compiles).

Start there if you want to extend Nucleor's v0.6 boundary into v1.

## Pinned-perf-floor protocol

If any v1 item ships, the perf floor MUST be measured and enforced
post-ship per `feedback_nucleor_perf_no_drift.md`. The cap is
cold ≤ 5.93s warn / 6.5s e-stop, peak_mem ≤ 770 MB self-host. The
v0.6.70 baseline (cold 3.16s, peak_mem ~318 MB) is the floor —
v1 items that genuinely need to extend this require explicit user
acceptance of the new floor.

Process per ship:
1. Pre-ship: 3-sample baseline measurement.
2. Implement.
3. Post-ship: 3-sample measurement.
4. If median cold > pre-ship median + 200ms OR peak_mem > pre-ship + 30 MB,
   bisect via `tools/check_perf_regression.ps1` and either optimize or
   user-approve the new floor before commit.
