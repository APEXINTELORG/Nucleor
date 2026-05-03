---
title: When two traits define a method with the same name and both are impl'd for the same struct, the compiler emits `PANIC: duplicate pub fn name across modules: <Type>__<method>`. The diagnostic mentions "two modules" but the trait impls are in the same file. Adopters expect ambiguity-resolution UFCS (`<W as T1>::name(&w)`) or a clean "ambiguous method dispatch" diagnostic.
severity: wrong-error / translation-fidelity (canonical Rust pattern produces misleading diag)
probe_file: probes/types/method_ambiguity_two_traits.nr (probe-branch)
diagnostic_actual: pre-fix — `ERROR: duplicate top-level fn name 'W__name' ... Two modules in this compile unit both declare a 'pub fn' with this name. ... PANIC: duplicate pub fn name across modules: W__name`
diagnostic_expected: clean ERROR `ambiguous method 'W::name': both impl T1 for W and impl T2 for W define name(). Use UFCS to disambiguate: <W as T1>::name(&w) or <W as T2>::name(&w)`. Mirror Rust's E0034.
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main f78d922
status: PARTIAL — clean diag with shape detection + UFCS-noted-as-forward-roadmap shipped v0.6.23. Real UFCS disambiguation deferred.
---

## Closure (main agent v0.6.23 — diagnostic-text-only, partial)

`compiler/nucleor_s1_compiler.nr` `emit_module_ext` duplicate-fn-name
check — added a shape detection: when the colliding name has the form
`<Type>__<method>` (Title-cased prefix + `__` separator), emit a
clean "ambiguous method dispatch" ERROR. Cross-module duplicate-fn
case continues with the original diag.

The check uses two simple heuristics:
1. Name contains `__` separator with non-empty prefix and suffix.
2. First character is upper-case (Title-cased — looks like a Type).

Both heuristics match the Nucleor mangling convention for trait-impl
methods. Fall-through to original diag if either fails.

## Repro (now produces accurate diag)

```nucleor
trait T1 { fn name(self: &Self) -> str; }
trait T2 { fn name(self: &Self) -> str; }
struct W;
impl T1 for W { fn name(self: &W) -> str { return "T1::name"; } }
impl T2 for W { fn name(self: &W) -> str { return "T2::name"; } }
fn main() -> i32 {
    let w: W = W {};
    print(w.name());
    return 0;
}
```

Pre-v0.6.23: misleading "duplicate pub fn name across modules: W__name"
with "rename one of the definitions" workaround that doesn't apply.

Post-v0.6.23: "ambiguous method `W::name()` — two trait impls on `W`
define a method named `name()`" with Rust E0034 reference + accurate
workaround (rename one trait's method or split across distinct
concrete types) + UFCS-as-forward-roadmap note.

## Forward-roadmap (full UFCS)

Real `<W as T1>::name(&w)` UFCS disambiguation requires:
- Parser: `<Type as Trait>::method` qualifier syntax.
- Type-check: resolve the trait-bound impl table per qualifier.
- Codegen: generate the type-mangled call with trait-disambiguating
  segments (probably `<Type>__<Trait>__<method>` instead of the
  current `<Type>__<method>`).

Deferred to a post-v0.6 RFC. For now adopters work around with method
renaming or separate concrete types.

## Promoted

- Fixture: `tests/err/err_method_ambiguity_two_traits.nr` (negative).
- Fix shipped (diag text only): v0.6.23. Real UFCS deferred.
- Promoted: 2026-05-02 PM by main agent (probe commit on
  `origin/probe/exploration`).
