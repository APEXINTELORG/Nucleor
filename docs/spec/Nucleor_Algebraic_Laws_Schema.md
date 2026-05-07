# Nucleor Algebraic Laws — Canonical `@law(...)` Schema

**Version:** v0.8.264 (locked 2026-05-05 per audit R14-D5).
**Status:** Phase 3b — canonical names locked across docs + tests;
`nuc test --check-laws` generates bounded integer checks for low-risk
forms and rejects deprecated aliases, unsupported canonical forms,
float/approximate modifiers, and unknown names with LAW diagnostics.
**Sources of truth (must agree):**
- `docs/spec/Nucleor_Algebraic_Laws_Schema.md` (this file — primary)
- `docs/rfcs/RFC-0031-algebraic-laws.md` §3.1
- `docs/language-reference.md` §8
- `tests/attrs/laws.nr`

If any of the four diverges, this file wins. The audit's R14-D5
build plan (`BUILD_PLAN_R14_algebraic_laws.md` §1) requires the
schema below to be the only spelling accepted.

---

## 1. Canonical law set

| Canonical name | Form | Meaning | Notes |
|---|---|---|---|
| `commutative` | `@law(commutative)` | `f(a, b) == f(b, a)` | binary fn only |
| `associative` | `@law(associative)` | `f(f(a, b), c) == f(a, f(b, c))` | binary fn only |
| `identity = E` | `@law(identity = E)` | `f(a, E) == a AND f(E, a) == a` | `E` is a constant or const fn returning the identity element |
| `idempotent` | `@law(idempotent)` | `f(a, a) == a` for binary; `f(f(x)) == f(x)` for unary | applies to both arities |
| `involution` | `@law(involution)` | `f(f(a)) == a` | unary fn only; special case of `inverse = f` |
| `absorbing = Z` | `@law(absorbing = Z)` | `f(a, Z) == Z AND f(Z, a) == Z` | binary fn only; `Z` is the absorbing element |
| `distributive_over = g` | `@law(distributive_over = g)` | `f(a, g(b, c)) == g(f(a, b), f(a, c))` | binary `f`, binary `g`; `g` must be in scope at the @law site |
| `inverse = g` | `@law(inverse = g)` | `g(f(a)) == a AND f(g(a)) == a` | both `f` and `g` are unary; `g` must be in scope |
| `fusion` | `@law(fusion)` | `(f ∘ g) ∘ h == f ∘ (g ∘ h)` for composable maps | structural / category-theoretic; allows the optimizer to reassociate composition chains |

## 2. Modifier attributes

These compose with any law to tune the future Arbitrary-driven
property-test driver or relax exact-equality semantics:

| Modifier | Form | Effect |
|---|---|---|
| `eps = T` | `@law(commutative, eps = 1e-9)` | float laws use this absolute tolerance instead of bit-exact equality |
| `approximate` | `@law(associative, approximate)` | implies `eps` is meaningful; documents that the law holds in expectation only (e.g. floating-point associativity) |
| `seed = N` | `@law(commutative, seed = 42)` | pins the property-test RNG seed for reproducibility |
| `cases = N` | `@law(commutative, cases = 5000)` | overrides default 1000 generated cases |

## 3. Deprecated aliases (`--check-laws` hard errors)

| Alias | Canonical replacement | Compile disposition | `nuc test --check-laws` disposition |
|---|---|---|---|
| `zero = Z` | `absorbing = Z` | accepted at lex for backward compatibility | hard error - `error[LAW-006]: deprecated alias zero = Z; use absorbing = Z` |
| `distributive` (bare) | `distributive_over = g` | accepted at lex for backward compatibility | hard error - `error[LAW-007]: deprecated alias bare distributive; use distributive_over = g` |

Aliases are documented here so adopters who used the pre-canonical
spelling (RFC-0031 mid-2025 wording) have a migration path.

## 4. Combination semantics

A single `@law(...)` may declare multiple properties separated by
commas:

```nucleor
@law(commutative, associative, identity = 0, absorbing = MAX_I64)
fn add_saturating(a: i64, b: i64) -> i64 { ... }
```

The shipped `--check-laws` slice generates bounded integer checks for
`commutative`, `associative`, `identity`, `absorbing`, `idempotent`,
`involution`, `distributive_over`, and `inverse` (round-trip
`f(g(a)) == a` AND `g(f(a)) == a` at four bounded sample integers).
The remaining canonical form `fusion` and property-driver modifiers
(`seed`, `cases`) fail closed with `LAW-001` until their checker ships.
Float/approximate modifiers (`eps`, `approximate`) fail closed with
`LAW-004` until the tolerance contract ships (RFC-0031 float phase).
A law that fails any generated check fails the whole `@law(...)` block.

## 5. Schema-violation diagnostic codes

| Code | Meaning |
|---|---|
| `LAW-001` | Generated law check failed, the declaration has an incompatible arity, or a canonical form lacks a shipped bounded checker |
| `LAW-003` | `@law(use = other_law)` cited a law the optimizer can't recognize |
| `LAW-004` | Float/approximate law modifier used before tolerance semantics ship |
| `LAW-006` | Deprecated alias `zero = Z` (use `absorbing = Z`) - `--check-laws` hard error |
| `LAW-007` | Deprecated alias `distributive` bare (use `distributive_over = g`) - `--check-laws` hard error |
| `LAW-008` | Unrecognized law name (fix the spelling or remove) - `--check-laws` hard error |

Normal compile still emits audit-info `LAW-G123` for adopter visibility.
`nuc test --check-laws` emits `LAW-001` for generated check failures
and unsupported canonical integer-law forms, emits `LAW-004` for
float/approximate modifiers, and promotes `LAW-006`/`LAW-007`/`LAW-008`
to hard errors.

## 6. References

- Spine §15 (R14 build-it decision, 2026-05-05)
- `BUILD_PLAN_R14_algebraic_laws.md` §1 R14-D5
- RFC-0031 §3.1 (this file mirrors and extends)
- v0.8.262 R14-D1 Phase 1 (lex-time `@law` capture)
- v0.8.263 R14-D3 Phase 1 (router `--check-laws` un-ignore)
- v0.8.264 R14-D5 Phase 1 (this schema)
- v0.8.328 R14 Phase 2a (`nuc test --check-laws` bounded integer checks)
- helper1 v0838 R14 Phase 3b (`distributive_over` bounded checks + fail-closed unsupported forms)
