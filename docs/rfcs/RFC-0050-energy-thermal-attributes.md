# RFC-0050 — Energy / Thermal Budget Attributes

**Status:** Draft (frontier easy-win — V2.5)
**Date:** 2026-05-03

## Motivation

Edge / embedded / mobile / battery-constrained / thermally-constrained programs need to declare per-fn energy + thermal budgets at compile time, both for documentation and for static analysis (`nuc perf` could flag fns that can't meet the budget). Today Nucleor's RT-attribute quad (`#[no_alloc]`/`#[no_panic]`/`#[no_dyn]`/`#[deadline]`) covers latency + heap allocation; energy + thermal aren't covered.

The frontier writeup proposes `@energy(max=2mJ)`, `@thermal(max_temp=70C)` per-fn budgets.

## Design

Two new attributes, parsed and emitted as advisory metadata (mirroring the existing `#[deadline]` story):

```nucleor
@energy(max=2mJ)
@thermal(max_temp=70C)
fn pid_step(setpoint: f64, measured: f64) -> f64 {
    ...
}
```

Quantity literals: SI energy (`uJ`, `mJ`, `J`), SI temperature (`C`, `K`), with optional ranges (`@thermal(min_temp=-40C, max_temp=85C)` for automotive-grade). Parsed at lex time; numeric value normalized to base unit (Joules, Kelvin) plus a unit tag.

## Implementation

- **Parser:** new attribute kinds at the existing attribute-skip loop (line ~280). Stores parsed budget as fn metadata.
- **Type-check:** advisory only in v2.5. Future ship adds:
  - per-instruction energy model (table of `add: 1pJ`, `mul: 5pJ`, `dram_load: 1nJ`, `tensor_core_op: ...`)
  - call-graph walk summing instruction energies
  - emit `EnergyBudgetExceeded` warning if estimated > declared
- **Codegen:** emits `__nucleor_meta_energy_<fn>` and `__nucleor_meta_thermal_<fn>` symbols that `nuc perf` / `nuc summary` / IDE plugins can read.

## Cost

V2.5 ship: ~150 LOC parser + attribute storage + symbol emit. NO call-graph estimator, NO threshold check (deferred).

Future estimator: ~600 LOC + per-arch instruction-energy tables. Sister to V1.6 no-alloc/panic call-graph propagation.

## Hot-path risk

None. Attributes are metadata-only.

## Frontier connection

Direct frontier writeup §3.2.2 "Energy / thermal budgets." Composes with the existing `#[deadline]` attribute and the future call-graph-propagation infrastructure.

## Closure criteria

- `@energy(max=2mJ)` parses and emits metadata symbol.
- `@thermal(max_temp=70C)` parses and emits metadata symbol.
- `nuc summary` lists fns with budgets.
- Round-2 self-host fixed-point holds.
