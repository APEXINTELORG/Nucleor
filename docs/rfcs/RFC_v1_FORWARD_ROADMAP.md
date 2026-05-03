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

#### V1.1 — Tuple-struct positional-field synthesis + `.0`/`.1` access

**Status today:** v0.6.53 ships parse halt with named-field workaround
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

#### V1.2 — Generic-T inference for literal init

**Status today:** v0.5.x partial closes inline-bound owned-T case.
v0.6.x ships type alias resolver. Still open: `let b: Box<i64> =
Box::new(5);` fails TYP-008 because `5` defaults to i32 and types_compatible
recurses on Box<i32> vs Box<i64>.

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

#### V1.4 — derive(PartialEq) / Hash for Vec / struct / HashMap

**Status today:** assert_eq! pointer-compare extends pre-v0.6.x family.
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

#### V1.7 — UFCS dispatch `<S as Foo>::f(&s)`

**Status today:** v0.6.60 parse halt. Adopters need UFCS only when
multiple traits provide the same method name (rare in practice).

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

#### V1.9 — assert!/assert_eq!/assert_ne! format-args expansion

**Status today:** v0.6.39 closed panic! mode-5. Asserts still drop.
v0.6.73-attempt regressed perf 1.7s due to per-call-site comma-walking.

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
- **`[VAL; N]` array literal repeat-init** — parse + lower (~200 lines).
- **`&[T]` slice param** — parse + lower (~250 lines).
- **`fn-no-tail-expr` Repro 3** — needs AST-level `;` tracking (~100 lines, but invasive).
- **`fn-ptr struct field direct call`** — parse `(struct.field)(args)` as indirect call (~150 lines).
- **method ambiguity UFCS resolution** — sister to V1.7.
- **Tuple destructure in let** — `let (a, b) = (5, 7);` (~150 lines, sister to V1.1).
- **i32 binop narrowing in expression context** — extend narrow_via_as to non-let contexts (~300 lines, hot-path risk).

## Cost summary

| Tier | Items | Total LOC | Perf risk |
|---|---|---|---|
| Tier 1 (V1.1–V1.3) | 3 | ~3000 | High (borrow-checker) |
| Tier 2 (V1.4–V1.6) | 3 | ~1800 | Medium |
| Tier 3 (V1.7+) | 8+ | ~2200 | Mostly low per-item |

Grand total: ~7000+ LOC of v1 work across 14+ items.

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
