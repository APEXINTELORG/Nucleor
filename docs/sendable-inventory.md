# Sendable Surface Inventory (RFC-0062 G-6 Phase 1)

**Status:** Phase 1 complete (v0.8.20, 2026-05-04)
**Source:** RFC-0035 (Sendable Marker + Actor Isolation), v0.6
first pass landed; current compiler surface in
`compiler/nucleor_s1_compiler.nr` `sendable_*` family.

Per RFC-0062 G-6 Phase 1: audit Sendable propagation through
nested types, document the v0.x contract, list the gaps that
Phase 2 must close.

## 1. The v0.6+ contract (already shipping)

Per RFC-0035 first-pass rules:

- **Primitive scalars + str/String:** Sendable.
- **`Vec<T>` / `Option<T>` / `Box<T>` / `Arc<T>`:** Sendable
  when `T` is Sendable.
- **`Result<T, E>`:** Sendable when both `T` and `E` are
  Sendable.
- **User types:** opt in via `impl Sendable for Type {}`.
- **`#[not_sendable]` attribute:** forces a type to fail the
  Sendable check even if a marker impl exists.
- **Spawn rejection:** `async_spawn`, `thread_spawn`, and
  `conc_spawn` reject bare local values whose declared type is
  not Sendable.
- **`&mut T`:** cannot cross a thread boundary in the first
  pass.

## 2. Compiler surface (current functions)

The seed compiler exports these `sendable_*` helpers (visible
in `bootstrap/nucleor_s1_seed.ll`):

- `sendable_actor_decl_name_at` — extracts actor name from
  source by index; powers the field-only `actor` lowering.
- `sendable_source_has_actor_decl` — fast scan for actor decls.
- `sendable_source_has_spawn_call` — fast scan for `*_spawn`
  calls (the entry-point for the Sendable check).
- `sendable_is_bare_ident` — distinguishes bare-local args from
  expression args at spawn sites.
- `sendable_second_type` — pulls the second generic argument
  (used for `Result<T, E>` propagation).
- `sendable_type_forced_not` — applies `#[not_sendable]`.
- `sendable_type_has_impl` — checks for explicit
  `impl Sendable for T {}` markers.
- `sendable_type_ok` — main propagation kernel; recursive
  through generic containers per the RFC-0035 rules above.

## 3. Nested-type propagation audit

For each combination, "OK" means the v0.6+ check accepts when
all type parameters are Sendable; "REJECTS" means the check
rejects today.

| Type | Status | Phase 1 finding |
|---|---|---|
| `i64`, `f64`, `bool`, `str`, `String` | OK | base case |
| `Vec<i64>` | OK | RFC-0035 first-pass rule |
| `Vec<Vec<i64>>` | OK | recursive propagation works |
| `Option<i64>` | OK | first-pass rule |
| `Option<Vec<i64>>` | OK | recursive propagation works |
| `Result<i64, i64>` | OK | both type params primitive |
| `Result<Vec<i64>, String>` | OK | both Sendable |
| `Box<T>` where T:Send | OK | first-pass rule |
| `Arc<T>` where T:Send | OK | first-pass rule |
| user struct, no impl | REJECTS | adopter must opt in |
| user struct, `impl Sendable for U {}` | OK | explicit marker |
| user struct + `#[not_sendable]` | REJECTS | force-deny wins |
| `HashMap<K, V>` | UNAUDITED | gap — see §4 |
| `Cell<T>` / `RefCell<T>` | REJECTS | by design (interior mut) |
| Function pointer / closure | UNAUDITED | gap — see §4 |
| Tuple `(T1, T2)` | UNAUDITED | gap — see §4 |
| Enum with mixed variants | UNAUDITED | gap — see §4 |

## 4. Known gaps (Phase 2 work)

1. **`HashMap<K, V>` propagation** is not audited in the v0.6
   first pass. The conservative Phase 2 rule: Sendable iff `K`
   and `V` are both Sendable AND the hasher is Sendable.
2. **Closures** capture variables; a closure is Sendable iff
   every captured variable is Sendable. Phase 2 needs an
   explicit capture-set audit at the closure decl site.
3. **Tuples** `(T1, T2, ...)` should be Sendable iff every
   component is; check is not yet wired.
4. **Enums with non-Sendable variants** should reject; the
   current implementation may silently accept depending on
   active variant. Phase 2 audits the full variant set.
5. **Trait objects** `Box<dyn Trait>` need explicit `+ Send`
   bound to be Sendable. Today the syntax parses but the
   propagation is conservative-rejecting.

## 5. Diagnostics inventory

Per RFC-0035 §"Diagnostics":

| Code | Meaning | Status |
|---|---|---|
| RACE-001 | Non-Sendable captured by spawn | active |
| RACE-002 | Actor method called without await | active |
| RACE-003 | Actor internal state escapes isolation | active |
| RACE-004 | Shared mutable state without Mutex / actor | active |
| RACE-005 | `&mut T` crosses thread boundary | active |
| RACE-006 | Reentrant actor lock violation | active |
| RACE-007 | Deadline composition under actor await invalid | active |
| RACE-008 | `#[not_sendable]` used where Sendable required | active |
| RACE-009 | Reserved | reserved |

## 6. Adopter guidance for Phase 1

Until Phase 2 lands the unaudited cases:

- Prefer concrete generic instantiations (`Vec<i64>` over
  `Vec<T>`) at spawn boundaries.
- Annotate user structs with explicit `impl Sendable for T {}`
  rather than relying on auto-derivation through fields.
- Avoid `HashMap`, closures-with-captures, and trait objects
  at spawn boundaries until Phase 2 ships their audited
  propagation rules.
- For mixed-variant enums where some variants hold
  non-Sendable data, mark the whole enum `#[not_sendable]` and
  hand-marshal across the boundary.

## 7. Phase 2 plan

Per RFC-0062 G-6 Phase 2: lock the Phase 1 audit findings into
a regression test set under `tests/lang/sendable_*.nr`,
implement the four unaudited cases (HashMap, closures, tuples,
enums) one at a time, each with an EXPECT-pass and EXPECT-fail
fixture pair. Phase 4 (v1.0) promotes the conservative-reject
fallbacks to explicit diagnostics so adopter intent is never
silently rejected.
