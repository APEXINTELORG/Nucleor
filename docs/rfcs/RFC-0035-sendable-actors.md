# RFC-0035 - Sendable Marker + Actor Isolation

| Field | Value |
|---|---|
| Number | 0035 |
| Title | Sendable Marker + Actor Isolation |
| Status | Draft |
| Target release | v0.9 |

## Summary

RFC-0035 adds static data-race prevention through two constructs:

- `Sendable`, an empty marker trait for values that are safe to cross
  task or thread boundaries.
- `actor`, a declaration form for isolated mutable state whose fields
  cannot be accessed directly outside the actor.

The v0.6 first pass is intentionally smaller than the full v0.9 design.
It accepts `trait Sendable {}` and explicit `impl Sendable for T {}` marker
impls, recovers field-only `actor Name { ... }` declarations through a
contextual source expander, and emits RACE diagnostics for the most important
unsafe boundary cases.

## First-Pass Rules

- Primitive scalar values, `str`, `String`, and Sendable containers are
  Sendable.
- `Vec<T>`, `Option<T>`, `Box<T>`, and `Arc<T>` are Sendable when `T` is
  Sendable.
- `Result<T, E>` is Sendable when both `T` and `E` are Sendable.
- A user type can opt in with `impl Sendable for Type {}`.
- `#[not_sendable]` forces a type to fail Sendable checks, even if it also
  has an explicit impl.
- `async_spawn`, `thread_spawn`, and `conc_spawn` reject bare local values
  whose declared type is not Sendable.
- `&mut T` cannot cross a thread boundary in the first pass.
- Field-only `actor` declarations lower through the existing struct path,
  while direct external field access on a variable typed as that actor emits
  `RACE-003`.

## Deferred

Full v0.9 actor runtime serialization, actor method `await` enforcement,
structural field-by-field Sendable derivation, lifetime proof for borrowed
values, and reentrant actor lock analysis remain deferred.

## Diagnostics

| Code | Meaning |
|---|---|
| RACE-001 | Non-Sendable value captured by spawned closure or spawn-style call |
| RACE-002 | Actor method called without await |
| RACE-003 | Actor internal state escapes isolation |
| RACE-004 | Shared mutable state without Mutex or actor |
| RACE-005 | `&mut T` crosses a thread boundary |
| RACE-006 | Reentrant actor lock violation |
| RACE-007 | Deadline composition under actor await is invalid |
| RACE-008 | `#[not_sendable]` type used where Sendable is required |
| RACE-009 | Reserved |
| RACE-010 | Reserved |
