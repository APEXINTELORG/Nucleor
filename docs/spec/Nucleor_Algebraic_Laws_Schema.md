# Nucleor Algebraic Laws Schema

Nucleor accepts `@law(...)` metadata on functions. The metadata gives tools a
stable way to identify algebraic identities that can be checked, reported, or
used by certification workflows.

The compiler records law metadata during normal compilation. Bounded law checks
run only when requested through the test/check tooling.

## Canonical Law Names

| Name | Shape |
|---|---|
| `identity_left` | `op(identity, x) == x` |
| `identity_right` | `op(x, identity) == x` |
| `associative` | `op(op(a, b), c) == op(a, op(b, c))` |
| `commutative` | `op(a, b) == op(b, a)` |
| `idempotent` | `op(x, x) == x` |
| `involution` | `op(op(x)) == x` |
| `distributive_left` | `mul(a, add(b, c)) == add(mul(a, b), mul(a, c))` |
| `distributive_right` | `mul(add(a, b), c) == add(mul(a, c), mul(b, c))` |

## Diagnostic Contract

- `LAW-001`: generated bounded check failed or the law form is unsupported.
- `LAW-002`: certification proof rejected the law.
- `LAW-003`: a law was present but not usable by the requested optimizer or
  proof mode.
- `LAW-004`: an approximate floating-point law lacks a tolerance contract.

## Example

```nr
@law("commutative")
fn add_i64(a: i64, b: i64) -> i64 {
    return a + b;
}
```

Normal compilation records the metadata. `nuc test --check-laws` asks the tool
suite to generate bounded checks for supported laws.
