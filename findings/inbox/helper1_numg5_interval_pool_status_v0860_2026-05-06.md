# Helper1 NUM-G5 Interval Pool Status/Preflight v0860

## Summary

Added public interval pool introspection helpers so callers can avoid the
fixed-size interval allocation cliff before constructing large proof workloads.

New rod helpers:

- `iv_pool_capacity()`
- `iv_pool_used()`
- `iv_pool_remaining()`
- `iv_pool_preflight(count)`

The runtime already fails closed on exhaustion instead of wrapping to slot 1.
This slice makes the capacity contract queryable without forcing tests or
callers to allocate millions of intervals just to discover the boundary.

## Evidence

Focused fixture:

- `tests/features/interval_pool_status_smoke.nr`

The fixture verifies:

- Capacity is public and large enough for the configured pool.
- Remaining slots match `capacity - used`.
- Negative preflight and impossible allocation counts fail closed.
- Allocating two intervals advances used/remaining by two.
- `iv_reset(checkpoint)` restores the previous accounting.

## Residual Gaps

- The pool is still fixed-size and process-local.
- This slice does not add dynamic pool growth or a freelist.
- Exhaustion itself is not forced in the fixture because that would require
  roughly two million allocations and would be a poor normal gate.

## Files Changed

- `stdlib/runtime/interval_rt.c`
- `stdlib/rods/interval.nr`
- `tests/features/interval_pool_status_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md`
