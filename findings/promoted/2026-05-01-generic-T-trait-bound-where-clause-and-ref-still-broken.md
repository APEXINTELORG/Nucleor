---
title: v0.5.31 Track Y closes generic-T-trait-bound dispatch ONLY for the inline-bound + owned-T + single-impl shape. The `<T> where T: Show` (where-clause) form falls through to `vec_show` synthetic helper at link time. The `<T: Show>(x: &T)` (reference receiver) form still TYP-006's at the call site.
severity: silent-miscompute / wrong-error (partial close — sister to closed v0.5.31)
probe_file: probes/types/generic_trait_bound_shapes.nr (probe-branch)
diagnostic_actual: pre-fix — where-clause shape link-failed `error[TYP-005]: undefined fn vec_show`; reference-receiver shape fired `error[TYP-006]: argument type mismatch in call to 'ps'`.
diagnostic_expected: same dispatch behavior as v0.5.31's inline-bound owned-T case — bound-scoped impl lookup, prints 101 for `A { v: 1 }` (where-clause).
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main aa8e44e
status: PARTIAL — where-clause shape CLOSED in v0.6.11 (this ship). Reference-receiver shape still OPEN; deferred to a follow-on ship.
---

## v0.5.31 → v0.6.11 coverage map

| Shape | Pre-v0.6.11 | Post-v0.6.11 |
|---|---|---|
| `<T: Show>` owned, single impl | ✓ PASS | ✓ PASS |
| `<T> where T: Show` owned, single impl | ❌ link `vec_show` | ✅ CLOSED — bound dispatch routes to A::show |
| `<T: Show>(x: &T)` reference receiver, single impl | ❌ TYP-006 | ❌ STILL OPEN — deferred |
| Nested generic `outer<T: Show>(x: T) { inner(x) }` calling `inner<T: Show>(x: T) { x.show() }` | ❌ TYP-005 in inner | ❌ STILL OPEN — deferred (bound not propagated through generic-to-generic call) |

## Repro: where-clause shape (CLOSED in v0.6.11)

```nr
trait Show { fn show(self) -> i64; }
struct A { v: i64 }
impl Show for A { fn show(self) -> i64 { self.v + 100 } }
fn ps<T>(x: T) -> i64 where T: Show { x.show() }
fn main() -> i32 { print_int(ps(A { v: 1 }) as i32); 0 }
```

Pre-fix: `error[TYP-005]: undefined function 'vec_show'` at clang link.
Post-fix: prints `101`, exits 0.

## Closure (main agent v0.6.11)

`compiler/nucleor_s1_compiler.nr` — replaced `skip_where_clause` with a
new helper `parse_where_clause_into_gparams` at the `parse_fn_decl`
call site. The helper walks `where T: A + B, U: C` and splices `?A` /
`?B` markers into the gparams Vec right after T's entry, `?C` after
U's. Lifetime entries (prefixed `'`) are preserved. This produces the
exact same gparams shape that inline `<T: A + B>` already emits, so
`lower_fn`'s Track Y bound-capture pass and `lower_expr` kind-8
receiver dispatch see the bound regardless of which syntactic form
the adopter wrote.

`parse_fn_decl` was refactored to track gparams as `Vec<i32>` through
the where-clause processing (deferring `mk_list` until after the
clause has been processed) so the helper can mutate the Vec in place.
The other call sites of `skip_where_clause` (parse_extern_fn,
parse_struct_decl, parse_impl_block, parse_match_in_let) remain on
the original skipper since their AST nodes don't surface generic
bounds today.

Stage1/2 self-host fixed point md5 `e5653940…`. Tools-suite compiles
clean (no parse-side regression on ~30k LOC of real Nucleor code).
Drift gate 5/5 OK. New positive fixture
`tests/features/rfc0024_generic_trait_bound_where_clause.nr` exercises
the canonical where-clause shape with a single impl and asserts
`ps(A { v: 1 })` returns 101. Track Y's existing inline-form positive
+ ambiguity-guard negative fixtures both stay green.

## Reference-receiver + nested-generic — STILL OPEN

The `<T: Show>(x: &T)` reference-receiver shape and the nested-generic
propagation shape are deferred to a follow-on ship. Both stem from a
different code path (kind-8 receiver-type unwrapping must honor the
`T = A` substitution before the bound check; nested-generic call sites
need bound propagation through the call chain, not just the immediate
fn body).

## Cross-ref

- v0.5.31 commit `aa8e44e` — closes the inline-bound owned-T case (Track Y).
- v0.6.11 commit (this ship) — closes the where-clause owned-T case.
- `tests/features/rfc0024_generic_trait_bound_dispatch.nr` — v0.5.31 inline positive.
- `tests/features/rfc0024_generic_trait_bound_where_clause.nr` — v0.6.11 where-clause positive.
- `tests/err/err_generic_trait_bound_dispatch_ambiguous.nr` — Track Y ambiguity guard (TYP-007), still green.

## Promoted

- Fixture: `tests/features/rfc0024_generic_trait_bound_where_clause.nr` (positive).
- Fix shipped: v0.6.11 (pending verify gate green at write time).
- Promoted: 2026-05-02 PM by main agent (probe commit `c4a76e2` on
  `origin/probe/exploration`).
