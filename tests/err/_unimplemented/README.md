# Unimplemented-feature negative tests

These 2 negative tests come from the V1 archive
(`Archive/Nucleor_Copy/examples/`) and exercise compiler errors for language
features that **were planned but never landed in the self-hosted OSS
compiler**:

| Feature | Tests |
|---|---|
| `pure fn` keyword (`compute` cannot call `read_data`) | DONE for the archived same-file surfaces: `err_pure_requires.nr`, direct side-effect helper, builtin print-family I/O, same-file `requires [...]` call, same-file wrapper inference, extern-default, and structured scheduling are all promoted under `tests/err/`. |
| `requires [effect]` clauses on functions | DONE for archive coverage: `err_effect_*` and `err_restricts_*` fixtures are active under `tests/err/` as fail-closed `EFF-003` coverage for block-form `restricts [...] { ... }`. Real restricts-block enforcement remains open in the main punchlist. |
| `unit<T, dim>` dimensional units (`m + s` rejected) | DONE for archive guard coverage: `err_unit_bare_coercion.nr`, `err_unit_mismatch.nr`, and `err_unit_assign.nr` are active under `tests/err/` as fail-closed preflight coverage. Full typed-unit algebra and UNIT-001..005 remain queued by RFC-0005/RFC-0047. |
| `Box<T>` heap allocation | DONE for archive coverage: `err_box_use_after_move.nr` is active under `tests/err/` and locks `Box<T>` as non-Copy under OWN-001. |
| Governance attributes (`@authored`, `no_unsafe`) | `err_policy_*` (2), retained here as superseded V1 archive material. RFC-0060 now says governance ships as an optional rod, not compiler-level `@policy(...)` build blocking. |

The OSS self-host compiler accepts the source and either ignores the
unrecognized tokens or compiles them as plain functions — so these tests
silently *pass* compilation when the V1 design intended them to fail. They
are kept here as **a punchlist** for the day those features are
implemented or deliberately reclassified; once a feature lands, move its
tests back up to `tests/err/` and the verify gate will start enforcing
them.

The verify gate (`tools/verify.ps1`) does **not** descend into this
directory, so these files do not block CI.
