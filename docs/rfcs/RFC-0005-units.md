# RFC-0005 — `unit<T, dim>` Typed Dimensional Units

| Field | Value |
|---|---|
| **Number** | 0005 |
| **Title** | `unit<T, dim>` — typed dimensional units (resurrect from V1 quarantine) |
| **Status** | Partial (audited v0.4.189). Stdlib `units.nr` rod ships with named unit IDs (`unit_m`, `unit_kg`, `unit_s`, etc.) and a `nuc_unit_convert` runtime helper that converts a numeric value between two unit IDs (length / mass / time / temperature / pressure / energy / force / frequency / angle / voltage / current). UNIT-001..005 diagnostic codes reserved + entries in `nuc explain`. **Deferred to v0.6+:** the `unit<T, dim>` typed-dimensional surface (compile-time dimension checking on arithmetic) — UNIT-001..005 emit sites are not yet wired into the type checker. |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.6.0 ("Embedded + AI Inference") |
| **Depends on** | RFC-0001, RFC-0003 (compositional with typed frames) |

---

## 1. Summary

Add a typed-units system to the language: `unit<T, dim>` carries a
runtime `T` value plus a compile-time dimension expression `dim`.
Arithmetic between units is dimension-checked at compile time.

```nucleor
let dist:  unit<f64, m>      = 10{m};
let time:  unit<f64, s>      = 5{s};
let speed: unit<f64, m/s>    = dist / time;       // OK: m / s = m/s
let bad:   unit<f64, m>      = dist + time;       // ERROR: m + s
let ok:    unit<f64, m>      = dist + 3{m};       // OK
let acc:   unit<f64, m/s^2>  = speed / time;      // OK

let force: unit<f64, kg*m/s^2> = 9.8{kg} * acc;   // OK; same as N
let force_n: unit<f64, N>      = force.into();    // explicit conversion to derived unit
```

The compiler tracks units as a polynomial in seven SI base
dimensions (length, mass, time, current, temperature, amount of
substance, luminous intensity). Arithmetic operations enforce the
dimension algebra. **Catches the Mars Climate Orbiter bug class at
compile time.**

This RFC resurrects the V1 quarantined `unit<T, dim>` design
(`tests/err/_unimplemented/err_unit_*`) — that code's intent was
right, the implementation never landed. v0.6 ships it.

---

## 2. Motivation

### 2.1 The bug class

Unit-confusion bugs are catastrophic and recurring:
- **Mars Climate Orbiter (1999):** $327M loss. Newton-seconds vs
  pound-force-seconds.
- **Gimli Glider (1983):** Air Canada 767 ran out of fuel at 41,000 ft;
  kg vs lb.
- **Robotics weekly:** rad vs deg in joint targets, m vs mm in tool
  offsets, m/s vs km/h in waypoints.

### 2.2 Prior art

| Language | Approach | Limitation |
|---|---|---|
| **F#** | First-class `[<Measure>]` types | The reference design |
| **Frink** | Whole language is units-aware | Niche; not a systems language |
| **Boost.Units** (C++) | Template-based, compile-time | Verbose, slow compile |
| **Rust uom crate** | Macro-based, compile-time | Not stable / built-in |
| **Ada** | `Ada.Numerics.Generic_Real_Arrays` lacks units; users add | Not built-in |
| **Java JSR-385** | Runtime-checked | Runtime cost; missed at compile time |

**Nucleor's opportunity:** ship F#-grade dimensional units as a first-
class language feature, integrated with the existing
generics/algebraic-laws system.

---

## 3. Design

### 3.1 Dimension algebra

Seven SI base dimensions, indexed by integer (or rational) exponents:

```
[length, mass, time, current, temperature, amount, luminous]
```

Examples:
- `m` = `[1, 0, 0, 0, 0, 0, 0]`
- `s` = `[0, 0, 1, 0, 0, 0, 0]`
- `m/s` = `[1, 0, -1, 0, 0, 0, 0]`
- `N` (Newton) = `[1, 1, -2, 0, 0, 0, 0]`
- dimensionless = `[0, 0, 0, 0, 0, 0, 0]`

Algebra:
- `unit<T, A> * unit<T, B>` → `unit<T, A+B>`
- `unit<T, A> / unit<T, B>` → `unit<T, A-B>`
- `unit<T, A> + unit<T, A>` → `unit<T, A>` (same dim only)
- `unit<T, A> ^ N` (literal `N`) → `unit<T, A*N>`
- `sqrt(unit<T, A>)` → `unit<T, A/2>` (requires rational exponents)

### 3.2 Syntax

```nucleor
// Literal: value{unit_expr}
let x: unit<f64, m> = 10.0{m};
let y: unit<f64, m/s> = 25.0{m/s};
let z: unit<f64, kg*m/s^2> = 9.8{kg*m/s^2};

// Type expression in declaration
let v: unit<f32, rad/s> = ...;

// Conversion between equivalent dimensions
let n: unit<f64, N> = z.into();   // kg*m/s^2 ≡ N

// Dimensionless
let r: unit<f64, _> = 3.14;       // bare numbers acquire dimensionless
```

### 3.3 Standard unit alias library

`stdlib/rods/units_si.nr` ships SI units:
- Base: `m, kg, s, A, K, mol, cd`
- Derived: `N, J, W, Pa, Hz, V, Ω, F, T, rad, sr, lm, lx, etc.`

`stdlib/rods/units_imperial.nr` ships imperial (with explicit
conversion factors): `ft, in, lb, slug, mph, etc.`

`stdlib/rods/units_robotics.nr` ships common robotics units: `deg`,
`rpm`, `g` (g-force), `rad/s`, `m/s^2`.

### 3.4 Conversion across systems

`From<unit<f64, m>>` for `unit<f64, ft>` is implemented with the
exact factor:

```nucleor
impl From<unit<f64, m>> for unit<f64, ft> {
    fn from(x: unit<f64, m>) -> Self { x.value() * 3.28084 }
}
```

User must call `.into()` or `From::from` explicitly — no implicit
conversion. **Rationale:** silent unit conversions are exactly the
bug class we're trying to prevent.

### 3.5 Composition with `Frame<>` (RFC-0003)

```nucleor
struct Pose<F: Frame> {
    translation: Point3<F>,        // implicitly meters
    rotation: Quat<F>,             // implicitly radians
}

// Or explicit:
struct PoseUnitful<F: Frame, U: Length> {
    translation: Point3<F, U>,
    rotation: Quat<F>,             // rotation is always rad
}
```

For v0.6, units are orthogonal to frames. The user declares the unit
on the `f64` element, the frame on the spatial type. v0.7 may unify.

### 3.6 Composition with `#[no_panic]`

Unit types are POD-ish; arithmetic on them doesn't introduce panics
beyond what the underlying `T` already does. RFC-0001 attributes
compose cleanly.

### 3.7 Diagnostics

```
error[UNIT-001]: cannot add unit<f64, m> and unit<f64, s>
  --> src/control.nr:14:21
   |
12 | let dist: unit<f64, m> = 10{m};
13 | let time: unit<f64, s> = 5{s};
14 | let bad = dist + time;
   |                  ^^^^ expected dimension `m`, found `s`
   |
   = note: unit arithmetic requires matching dimensions
   = help: did you mean to multiply? `dist * time` → unit<f64, m*s>
```

| Code | Meaning |
|---|---|
| UNIT-001 | Add/sub mismatched dimensions |
| UNIT-002 | Implicit conversion attempted (use `.into()`) |
| UNIT-003 | Power expression is non-integer at compile time |
| UNIT-004 | Unknown unit alias |
| UNIT-005 | Dimensional inconsistency in `@law` annotation |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `value{unit_expr}` literal, `unit<T, dim>` type | ~250 |
| Type checker | Dimension polynomial arithmetic, equality | ~500 |
| Codegen | Strip units (zero runtime cost) | ~30 |
| Stdlib | `units_si.nr`, `units_imperial.nr`, `units_robotics.nr` | ~600 |
| Diagnostics | UNIT-001…005 | ~150 |
| **Total** | | **~1530** |

Test plan: ports the 3 quarantined `err_unit_*` tests back to
`tests/err/`, plus 10 positive tests in `tests/lang/units_*.nr`.

---

## 5. Alternatives considered

- **Runtime-only checking** — defeats purpose; rejected.
- **Per-quantity wrapper structs** (Boost.Units) — verbose, no
  dimension algebra; rejected.
- **Macros only** — uom-crate-style; loses type-system integration.
  Rejected.
- **Skip units entirely** — leaves the bug class open. Rejected per
  user mandate.

---

## 6. Open questions

1. Rational exponents (m^(1/2)) for stochastic process units? Recommend
   yes via `Rational<i32>` exponent type.
2. `radian` as truly dimensionless or as base dimension? SI says
   dimensionless; ISO 80000 disagrees. Recommend dimensionless +
   compiler warning when `m + rad`.
3. Currency units (`USD`, `EUR`) — out of scope.
4. Compile-time unit conversion folding — yes via const-eval.

---

## 7. Definition of done

- [ ] Dimension algebra implemented; UNIT-001…005 diagnostics fire
- [ ] SI base + derived units shipped
- [ ] All 3 quarantined `err_unit_*` tests pass
- [ ] CHANGELOG documents `unit<T, dim>` and units library
- [ ] V1 quarantine README updated to point at units RFC

## 8. Future extensions

- Unification with `Frame<>` so spatial types carry units implicitly
- Unit-aware optimizer rewrites (e.g., `sqrt(x*x) ≡ x`)
- Affine units (Celsius vs Kelvin offset) — non-trivial, defer
- Currency / percentage / custom dimensions

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.6 release schedule
- [ ] LOC budget ~1530 fits
- [ ] Pitch survives ("Mars Climate Orbiter doesn't happen")
