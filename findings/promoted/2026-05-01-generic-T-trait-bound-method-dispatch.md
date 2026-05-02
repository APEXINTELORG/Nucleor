---
title: `fn f<T>(x: T) where T: Show { x.show() }` — generic body's `x.show()` synthesised `vec_show` (i64-ABI Vec fallback) instead of dispatching to the concrete T's impl
severity: silent-miscompute / wrong-error (generic-fn body method dispatch)
probe_file: probes/generics/trait_bound_method_dispatch.nr (probe-branch)
diagnostic_actual: pre-fix — clang link `error[TYP-005]` "receiver type `Vec<T>` has no method `.show()`"; underlying IR had `call i64 @vec_show(...)` referencing an undefined `vec_show` symbol.
diagnostic_expected: monomorphisation of `print_show(a)` → calls A::show; `print_show(b)` → calls B::show. The trait-bound `T: Show` drives method dispatch.
discovered_against: main v0.5.4 (atomic_swap ship; the hazard is general — applies to every trait-bound generic fn body)
commit: probe d72b85d + main 26159e4
status: CLOSED in v0.5.31 Track Y merge (`aa8e44e` + integration `f78d922`)
---

## Repro

```nr
trait Show {
    fn show(self) -> i64;
}

struct A { v: i64 }
struct B { v: i64 }

impl Show for A { fn show(self) -> i64 { self.v + 100 } }
impl Show for B { fn show(self) -> i64 { self.v + 200 } }

fn print_show<T>(x: T) where T: Show {
    print_int(x.show() as i32);   // ← lowered to call @vec_show pre-Track-Y
}

fn main() -> i32 {
    let a: A = A { v: 1 };
    let b: B = B { v: 2 };
    print_show(a);
    print_show(b);
    0
}
```

## Closure (main agent v0.5.31 Track Y merge)

`compiler/nucleor_s1_compiler.nr` `lower_expr` kind-8 (method receiver)
now consults a per-fn generic-trait-bound table populated by `lower_fn`
when the fn declaration has `?<trait>` bound markers on its generic
params. When the receiver type resolves to a generic-T parameter that
carries a single bound implementation in the trait_impls registry, the
dispatch routes through the bound's concrete impl rather than the
fallback `vec_<method>` synthesis path.

Conservative guard: if the bound has multiple concrete impls for the
same method (so monomorphic dispatch is genuinely ambiguous in the
absence of monomorphisation), the compiler emits
`error[TYP-007]: generic trait-bound method dispatch for `T: …` method
`.X()` is ambiguous` and halts. This avoids the previous silent miscompute
where any of the candidate impls might have been selected.

Track Y commit: `6eadedb` (parallel-1, rebased onto v0.5.30). Merged
to main as `aa8e44e` ("v0.5.31: merge Track Y — generic T: Trait method
dispatch (parallel-1)"). Validation: 1 positive fixture
`tests/features/rfc0024_generic_trait_bound_dispatch.nr` + 1 negative
`tests/err/err_generic_trait_bound_dispatch_ambiguous.nr`. Full
verify gate green at v0.5.31 (722/722 PASS post-fix).

## Sister hazard

Distinct from the inferred-let-binding generic-T propagation hazard
(`2026-05-01-generic-T-propagation-spsc-option-str.md`, closed via
v0.5.13 `e6ce28d`). That sister bug fixed type INFERENCE on the
call site; this finding fixes type DISPATCH inside the generic body.

## Forward-roadmap caveats

- Full per-call-site monomorphisation (separate fn body per concrete
  T) is deferred to v0.9 alongside RFC-0034 `[]` compile-time params.
  Current closure path emits one ABI-level fn body and routes the
  dispatch via the trait_impls registry — works for single-impl
  bounds but rejects ambiguous multi-impl bounds with TYP-007.

## Promoted

- Fixture: `tests/features/rfc0024_generic_trait_bound_dispatch.nr`
  (positive) + `tests/err/err_generic_trait_bound_dispatch_ambiguous.nr`
  (negative).
- Fix shipped: v0.5.31 Track Y merge (`aa8e44e`, integrated
  `f78d922`).
- Promoted: 2026-05-02 by main agent (probe commit `d72b85d` on
  `origin/probe/exploration`).
