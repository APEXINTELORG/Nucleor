# Unimplemented-feature negative tests

These 17 negative tests come from the V1 archive
(`Archive/Nucleor_Copy/examples/`) and exercise compiler errors for language
features that **were planned but never landed in the self-hosted OSS
compiler**:

| Feature | Tests |
|---|---|
| `pure fn` keyword (`compute` cannot call `read_data`) | `err_pure_*` (4 remaining; `err_pure_requires.nr` promoted in v0.8.320) |
| `requires [effect]` clauses on functions | `err_effect_*` (4), `err_restricts_*` (2 remaining; `err_restricts_builtin_io.nr` promoted in v0.8.321) |
| `unit<T, dim>` dimensional units (`m + s` rejected) | `err_unit_*` (3) |
| `Box<T>` heap allocation | `err_box_use_after_move` |
| Governance attributes (`@authored`, `no_unsafe`) | `err_policy_*` (2) |

The OSS self-host compiler accepts the source and either ignores the
unrecognized tokens or compiles them as plain functions — so these tests
silently *pass* compilation when the V1 design intended them to fail. They
are kept here as **a punchlist** for the day those features are
implemented; once a feature lands, move its tests back up to
`tests/err/` and the verify gate will start enforcing them.

The verify gate (`tools/verify.ps1`) does **not** descend into this
directory, so these files do not block CI.
