# RFC-0047 — Typed Units `unit<T, [kg, m, s, A, K, mol, cd]>`

**Status:** Draft (frontier easy-win — V2.2)
**Date:** 2026-05-03
**Predecessor:** Existing `units.nr` rod does runtime conversion across 11 dimensions; V2 had the typed `unit<T, dim>` form with a 7-element `[i8; 7]` SI dimension vector tracked in IR. Lift V2's implementation.

## Motivation

The Mars Climate Orbiter problem (frame mismatch is RFC-0046's concern) AND its sister: unit mismatch. `let force: f64 = 9.8 * mass;` is dimensionally wrong if `mass` is in kg and the literal `9.8` is gravity (m/s²) — Newtons fall out, not "kg·m/s²" the user expected. Today Nucleor catches none of this.

V2 had the typed form via a 7-element `[i8; 7]` (kg, m, s, A, K, mol, cd) phantom on every numeric. Multiplication adds the dimension vectors element-wise; division subtracts; equality requires identical vectors.

## Design

```nucleor
type Mass<T>     = unit<T, [1, 0, 0, 0, 0, 0, 0]>;     // kg
type Length<T>   = unit<T, [0, 1, 0, 0, 0, 0, 0]>;     // m
type Time<T>     = unit<T, [0, 0, 1, 0, 0, 0, 0]>;     // s
type Acceleration<T> = unit<T, [0, 1, -2, 0, 0, 0, 0]>;  // m/s²
type Force<T>    = unit<T, [1, 1, -2, 0, 0, 0, 0]>;    // kg·m/s² (Newton)

let m: Mass<f64>         = 5.0_kg;
let g: Acceleration<f64> = 9.81_mps2;
let f: Force<f64>        = m * g;     // ✓ dimensions add: [1,0,0,...] + [0,1,-2,...] = [1,1,-2,...]
```

Literal suffixes (`_kg`, `_m`, `_s`, `_N`, `_J`, `_W`, `_Pa`, `_Hz`, ...) lex to the matching `unit<T, [...]>` type. SI prefixes (`_mm`, `_km`, `_us`, `_GHz`) lex to the same dim vector with a scaled magnitude.

## Implementation

- **Parser:** `unit<T, [a,b,c,d,e,f,g]>` accepted as type expression. Literal suffixes lex to `unit<f64, [...]>` with SI-prefix scaling baked in at lex-time.
- **Type-check:** `types_compatible(unit<T, [v1...]>, unit<T, [v2...]>)` requires `v1 == v2`. Multiplication: dim-vector add. Division: dim-vector sub. Power: scalar mul of dim vector. Cast `as f64` strips the dimension (escape hatch — adopter loses dim safety, gets bare scalar).
- **Codegen:** zero-cost. The dim vector is purely type-level; runtime only sees the scalar T.

Lifting V2's implementation: V2 stored the `[i8; 7]` in the type-string slot. Reuse that wire format.

## Cost

~400 LOC compiler-side (parser for the bracket-form type, dim-arithmetic in type-check). ~200 LOC stdlib (literal suffix table, SI prefix scaling). One fixture per dimension per arithmetic op (~30 fixtures).

## Hot-path risk

None. Codegen sees only the bare T.

## Frontier connection

Direct instance of frontier writeup §3.2.2 "physical units as types." Pairs with **RFC-0046 coordinate frames** (same phantom-type pattern).

## Closure criteria

- `let f: Force<f64> = mass * accel;` type-checks.
- `let bad: Force<f64> = mass + accel;` rejects with TYP-008 dim-mismatch.
- Literal suffixes (`5.0_kg`, `9.81_mps2`, `1.5_N`) lex correctly with dim attached.
- SI-prefix scaling (`5.0_mg` → 0.005 internally) preserves dim.
- Round-2 self-host fixed-point holds.
