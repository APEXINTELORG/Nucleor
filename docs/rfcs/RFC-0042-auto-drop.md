# RFC-0042: Opt-in Auto-Drop for Owned Locals

Status: Stable opt-in (Phase 1 of RFC-0062 G-1, v0.8.20)
Date: 2026-05-01 (drafted) / 2026-05-04 (Phase 1 stabilized)
Successor: RFC-0062 G-1 (Phase 4 v1.0 default-on)

## Problem

Nucleor heap-backed values use the i64 ABI for pointers. Today `Vec<T>` and `HashMap<K,V>` locals require explicit frees such as `vec_free(v)`. This is easy to miss and creates leaks that normal functional tests do not see.

Default-on generated cleanup is unsafe today because existing code often calls the free helpers manually. Blind cleanup would double-free.

## Proposal

Add an opt-in function attribute:

```nucleor
#[auto_drop]
fn f() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1);
    return v.len();
}
```

For functions marked `#[auto_drop]`, lowering tracks local `let` bindings whose full type is drop-eligible:

- `Vec<T>` -> `vec_free`
- `HashMap<K,V>` -> `hashmap_free`

`str` / `String` are intentionally excluded from this first implementation because the current surface type does not distinguish owned heap strings from string literals. String auto-drop needs owned-string provenance before it can be safe.

Generated cleanup runs before every explicit return and before implicit tail returns. Cleanup runs after existing DbC `ensure`/`invariant` exit checks so contracts observe pre-drop state.

## Spike Semantics

- Opt-in per function.
- Tracks local `let` bindings only.
- Explicit free calls on a tracked local mark it freed, preventing generated double-free.
- Rebinding a tracked local drops the old value before storing the replacement.
- Shadowing a tracked local drops the old binding after the RHS of the shadowing `let` and before installing the new binding.
- Returning a tracked local by bare name skips dropping that local on that return path.

## Non-Goals

- Full ownership/move checking.
- Default-on auto-drop.
- Nested branch-scope fallthrough cleanup.
- User struct drop glue.
- Trait-based `Drop` dispatch.

## Validation

`tests/features/rfc0042_auto_drop_vec.nr` covers generated return cleanup, rebinding cleanup, and explicit free without generated double-free. `tools/verify.sh` includes the narrow step `RFC-0042 auto_drop emits owned-local cleanup once`, which compiles the fixture with `--no-link` and asserts exactly four emitted `call void @__nucleor_vec_free` sites.

The rebased Track Z branch at `f78d922` fixed-point self-hosted while monitored by the 1 GB emergency stop: stage1 peak 678 MB, stage2 peak 675 MB, and both LLVM outputs hashed to `9CA0CFA6345820B4A314474C9BDC0406C6998FC3EF06CFD4800CF8890428BC60`. The 1 GB value is a kill threshold, not a memory target.

## Phase 1 stabilization (v0.8.20, 2026-05-04)

The opt-in surface graduates from spike to Stable per RFC-0062 G-1. Phase 1 stabilization commitments:

- The `#[auto_drop]` attribute name and semantics are stable for the duration of v0.x. Adopters can rely on per-function opt-in not being renamed before Phase 4.
- Vec and HashMap are the supported drop-eligible types in v0.x. The list does not contract; it may extend (str / String once owned-string provenance lands; user structs once Drop trait dispatch lands).
- The four Spike Semantics rules (manual-free disables generated drop, rebinding drops old, shadowing drops old, return-by-bare-name skips drop) are the Phase 1 contract.

Phase 4 (v1.0) successor work is tracked in RFC-0062 G-1: default-on auto-drop with explicit `#[manual_drop]` opt-out for the rare cases where adopter code intentionally calls the free helpers. Until Phase 4, `#[auto_drop]` remains opt-in.

Lock-in fixtures (Phase 1):

- `tests/features/rfc0042_auto_drop_vec.nr` — Vec opt-in (existing; covers four sites).
- `tests/fixtures/v0820_g1_auto_drop_hashmap.nr` — HashMap opt-in lock-in.
- `tests/fixtures/v0820_g1_auto_drop_return_local.nr` — return-by-bare-name skip-drop lock-in.
