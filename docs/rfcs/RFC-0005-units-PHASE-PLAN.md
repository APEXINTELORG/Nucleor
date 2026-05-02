# RFC-0005 — Phasing Plan

| Field | Value |
|---|---|
| **Parent RFC** | `RFC-0005-units.md` |
| **Created** | 2026-05-02 |
| **Author** | main agent |
| **Goal** | Break the ~1530-LOC RFC-0005 implementation into 5 shippable phases so any single ship is bounded and the gate stays green between phases. |

---

## Why phase

The parent RFC's implementation table totals **~1530 LOC** across
parser, type checker, codegen, stdlib, and diagnostics. Single-ship
attempts repeatedly drift; each phase below is sized to fit a single
ship cycle (compile → fixed-point → drift gate → focused verify)
without burning the 770 MB / 580 MB per-process budget or stretching
self-host wall past ~6 s.

Phases are sequenced so each ship leaves the tree in a consistent
state. **No phase ships a partial diagnostic that's wired but
mis-firing** — every UNIT-* code added is fixture-tested in the
same ship.

---

## Phase 1 — Parser surface freeze + dimension polynomial substrate

**Target:** v0.7.x ship cycle. **LOC budget:** ~250 (parser) + ~80
(polynomial helpers) = ~330.

### Deliverables

1. **Parser**
   - Recognise `unit<T, dim>` as a type expression (`parse_type`
     extension). `dim` is a parse-time string capturing the dim
     expression source verbatim — algebra deferred to phase 2.
   - Recognise `value{unit_expr}` literals (`parse_expr` extension).
     Lower as a kind-NN node carrying the unit_expr source string.
2. **Polynomial helpers (no diagnostics yet)**
   - `dim_poly_parse(s: str) -> Vec<i32>` returning a length-7
     vector of integer exponents on the SI base dimensions
     `[length, mass, time, current, temperature, amount, luminous]`.
   - `dim_poly_eq(a, b)`, `dim_poly_add(a, b)` (multiply),
     `dim_poly_sub(a, b)` (divide), `dim_poly_scale(a, n)` (power),
     `dim_poly_zero()` (dimensionless).
3. **Smoke fixture**: `tests/lang/units_parser_only.nr` confirms
   `let x: unit<f64, m> = 10.0{m};` parses without diagnostic and
   the dim string round-trips through the parser.

### Out of scope

- Type-check diagnostics (UNIT-001..005 still reserved-only).
- Codegen behaviour for unit literals (lowered to bare `T` for now
  — same as today).
- Stdlib unit aliases.

### Validation

- Stage1+2 self-host fixed point.
- Drift gate clean.
- Focused verify on the new fixture only.

---

## Phase 2 — Type checker UNIT-001 + UNIT-002

**Target:** v0.7.x cycle after phase 1. **LOC budget:** ~280
(type-check) + ~60 (diagnostic emit) = ~340.

### Deliverables

1. **Dimension equality on add/sub.** When type-check sees
   `unit<T, A> + unit<T, B>` or `… - …`, run `dim_poly_eq(A, B)`;
   on mismatch emit `error[UNIT-001]: cannot add unit<T, X> and
   unit<T, Y>`.
2. **Dimension multiplication on `*` / `/`.** Resulting type's dim
   is `dim_poly_add` / `dim_poly_sub` of operand dims.
3. **Power expression `^N`** with literal integer `N`.
   `dim_poly_scale(A, N)`. Non-integer literal → `error[UNIT-003]`.
4. **`UNIT-002` for implicit conversion attempts.** `let x:
   unit<T, A> = expr_with_dim_B` where `A != B` → `UNIT-002`.
5. **Fixtures (4 negative + 4 positive)**:
   - `err_unit_001_add_mismatch.nr`
   - `err_unit_001_sub_mismatch.nr`
   - `err_unit_002_implicit_convert.nr`
   - `err_unit_003_non_integer_power.nr`
   - `units_phase2_mul_div.nr`
   - `units_phase2_power.nr`
   - `units_phase2_dimensionless.nr`
   - `units_phase2_chain.nr` (m / s = m·s⁻¹)

### Out of scope

- `.into()` for cross-system conversion (phase 3).
- Stdlib SI alias library (phase 4).
- Codegen — units stripped at lowering (same as phase 1).

### Validation

- Full verify gate (the 8 new fixtures + every existing test must
  remain green; UNIT-001..003 firing is not allowed to break any
  current code).

---

## Phase 3 — `.into()` cross-system conversion + UNIT-004

**Target:** v0.7.x cycle after phase 2. **LOC budget:** ~180.

### Deliverables

1. **`From<unit<T, A>>` for `unit<T, B>`** trait synthesis when an
   explicit conversion factor is provided in stdlib (deferred to
   phase 4 for SI ↔ imperial bodies; phase 3 just wires the trait
   shape).
2. **`UNIT-004`: unknown unit alias.** When a unit literal references
   an alias not registered in the prelude or via `import`, emit
   `error[UNIT-004]: unknown unit alias 'X'`.
3. **Fixtures**:
   - `err_unit_004_unknown_alias.nr`
   - `units_phase3_into.nr` (with a single hand-written conversion
     impl in the fixture; no stdlib dependency yet)

### Validation

- Same as phase 2.

---

## Phase 4 — Stdlib SI + imperial + robotics alias rods

**Target:** v0.7.x cycle after phase 3. **LOC budget:** ~600 across
three rods.

### Deliverables

1. `stdlib/rods/units_si.nr` — `m, kg, s, A, K, mol, cd, N, J, W,
   Pa, Hz, V, Ω, F, T, rad, sr, lm, lx`.
2. `stdlib/rods/units_imperial.nr` — `ft, in, lb, slug, mph` with
   exact conversion factors.
3. `stdlib/rods/units_robotics.nr` — `deg, rpm, g (force), rad/s,
   m/s²`.
4. **Fixtures:** `units_si_smoke.nr`, `units_imperial_smoke.nr`,
   `units_robotics_smoke.nr`. Each exercises `let x: unit<f64,
   <alias>> = <value>{<alias>};` for every alias in the rod.

### Validation

- Same as phase 2 + each new rod gets a smoke step in `verify.sh`
  (`example units_si_smoke`, etc.).

---

## Phase 5 — UNIT-005 + V1 quarantine port

**Target:** v0.7.x cycle after phase 4. **LOC budget:** ~110.

### Deliverables

1. **`UNIT-005`: dimensional inconsistency in `@law` annotation.**
   Hooks into the existing algebraic-laws system (`#[law]`) so
   declarations like `@law commute: a*b == b*a` where `a` and `b`
   have incompatible dimensions are caught at parse + type-check.
2. **Port the 3 quarantined `err_unit_*` tests** from
   `tests/err/_unimplemented/` to `tests/err/`. Each must fire the
   right UNIT-* code and the diagnostic text must match the parent
   RFC's spec section 3.7.
3. **Update V1 quarantine README** to point at the parent RFC and
   note that `unit<T, dim>` is no longer quarantined.

### Validation

- Full verify gate green at each phase boundary.
- RFC-0005 §7 definition-of-done all 5 boxes checked.

---

## Phase budget summary

| Phase | LOC | Cumulative | Risk |
|---|---|---|---|
| 1 — parser surface + poly substrate | ~330 | 330 | low |
| 2 — UNIT-001/002/003 type check | ~340 | 670 | medium |
| 3 — `.into()` + UNIT-004 | ~180 | 850 | low |
| 4 — stdlib alias rods | ~600 | 1450 | low |
| 5 — UNIT-005 + V1 port | ~110 | 1560 | low |

Total ~1560 vs RFC's ~1530 estimate (60-LOC buffer for the 7
fixture files added across phases).

---

## Coordination notes

- **Don't split phases across consultant + main lanes.** Each phase
  touches `nucleor_s1_compiler.nr` plus fixtures; mid-phase
  collision on the parser is hard to merge.
- **Phase 1 must precede everything.** Don't ship a UNIT-* diagnostic
  without the polynomial substrate it reasons over.
- **Memory budget:** unchanged across phases (770 MB self-host
  cap). The polynomial helpers add no per-call overhead — they're
  type-check time only and run once per arithmetic node.
- **Time budget:** target stage1 self-host stays ≤ 6 s wall through
  all 5 phases. If any phase pushes past, audit immediately
  (likely a per-call hot-path regression — see
  `feedback_perf_regression_pattern.md`).

---

## Pointers

- Parent RFC: `docs/rfcs/RFC-0005-units.md`
- V1 quarantine: `tests/err/_unimplemented/err_unit_*.nr`
- Spine RFC ledger: `BUILD_PATH_v0.4_to_v1.3.md` §3 + §8.5.
- v0.6.0 milestone: `docs/milestones/v0.6.0.md` (RFC-0005 +
  RFC-0008 listed as a single success criterion;  this plan
  splits RFC-0005 across 5 ships).
