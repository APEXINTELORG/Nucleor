# Lane 2 / Queue 2B — Method/impl effect enforcement

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Branch:** `fix/effects-method-impl-ambiguity-v0845`
- **Base:** `origin/main` @ `92f8efd88fa3409822e1681a239abfae79c63a2c`
- **Host:** Windows 11 26200, PowerShell + bash via Git for Windows

## Headline

Same-file `impl` method effect enforcement was already empirically
covered by the existing substring-search machinery (`enforce_requires_direct_calls`
matches `obj.method(` via the literal `method(` substring), so the
three handoff fixtures (direct row mismatch, body builtin transitive,
restricts block reaching method I/O) already fired EFF-001 / EFF-003
without code changes. The real residual was a **production-blocker
false positive** when two `impl` blocks declare methods with the same
unqualified name and distinct rows.

v0845 lane 2 adds `name_has_distinct_rows_in_table` and routes the
three effect-enforcement entry points through it — when ambiguity is
detected, the row check is skipped (fail-open) so adopter code with
unrelated same-name methods does not block on a spurious EFF-001.
Receiver-type-aware resolution for the ambiguous case is Phase 4 /
RFC-0033 broader effect-row subtyping.

## Empirical baseline (pre-fix, on `origin/main` @ 92f8efd8)

| Probe                                        | Behavior                          |
|----------------------------------------------|------------------------------------|
| Method declared `requires [io.write]`, caller `[net]` | EFF-001 ✓ already worked  |
| Method body uses `print`, caller `[net]`     | EFF-001 transitive ✓ already worked |
| `restricts [io.write] { obj.method(); }` reaches print | EFF-003 ✓ already worked |
| Same-name methods on two impls (one rowed, one not), un-rowed call | **EFF-001 false positive** — production blocker |
| Method declared `[io.write]`, caller `[io.write]` (positive) | builds + runs ✓ already worked |

## Change

### Compiler

- Added helper `name_has_distinct_rows_in_table(table, name) -> i64`
  that returns 1 only when the resolved-source fn table has two or
  more entries sharing the name AND with textually-distinct
  `requires [...]` rows (per `str_eq`). Returns 0 when the name
  appears once, or when every same-name entry has the same row.
- `enforce_requires_direct_calls` direct-call loop: gated the row
  check on `name_has_distinct_rows_in_table(table, callee) == 0`.
  Ambiguous-name callees skip silently — body substring still scans
  the rest of the table for unambiguous matches.
- `requires_transitive_missing` body walk: same gate. When the
  callee's name is ambiguous, the row check is skipped and the
  recursion falls through to the body walk (under depth=8 budget),
  so transitive un-rowed chains via builtins still surface.
- `restricts_transitive_check` body walk: same gate. Same fall-open
  semantics — the row check skips on ambiguity, the body walk
  continues, so direct builtin reach in an ambiguous method's body
  still trips EFF-003.
- EFF-G123 banner: added the closed-status sentence for same-file
  `impl` method enforcement (citing the substring path), and noted
  the ambiguous-name fail-open. Remaining-open list now reads
  "ambiguous-name same-file methods (fail-open since v0845)".

### Tests

| File | Class | EXPECT |
|---|---|---|
| `tests/err/err_method_requires_direct.nr` | negative | `error[EFF-001]` |
| `tests/err/err_method_body_builtin_transitive.nr` | negative | `error[EFF-001]` (transitive) |
| `tests/err/err_restricts_block_method_io.nr` | negative | `error[EFF-003]` |
| `tests/features/method_requires_clean_smoke.nr` | positive | clean build + prints "emit ok" |
| `tests/features/method_ambiguous_name_fail_open_smoke.nr` | positive | clean build (proves fail-open) |

### Punchlist

- `docs/rfcs/v1_PUNCHLIST.md` Effects/capabilities §"Still open":
  added v0845 lane 2 closed-status entry citing the five locking
  fixtures; remaining-open list now reflects only the surfaces that
  genuinely remain (depth>8 chains, ambiguous-name receiver
  resolution, closures, fn-pointer capture, RFC-0033 subtyping,
  selective/glob imports).

## Validation transcript

Stage1 build from edited source: 3.07s (under 4s budget).

Stage1 binary against fixtures:
- 3 negatives → expected EFF-001 / EFF-003 ✓
- 2 positives → clean build + run, ambiguous-name positive proves
  fail-open works (pre-fix it false-positived EFF-001) ✓
- Queue 2A regression: cross-module depth + clean smoke unchanged ✓
- Existing same-file fixtures: requires_row_direct_call + clean_smoke
  unchanged ✓

Self-host fixed-point + bootstrap seed:

```
bash tools/check_self_host_md5.sh
  OK: self-host compiler IR fixed point holds md5=0bdc11ea8e6df91d73bf2a12cd8553c9
  OK: bootstrap seed matches current self-host IR md5=0bdc11ea8e6df91d73bf2a12cd8553c9
```

Drift / perf:

```
bash tools/check_compiler_drift.sh
  OK: ... s1 + tools_suite ABI clean (RFC-0063 12-token-id drift unchanged)

pwsh tools/check_perf_regression.ps1
  OK perf: cold=3.39s/4s, hot=0.41s/1s,
           cold_tree=346/400 cold_compiler=332/350 (under budget)
```

Promoted-binary spot check:
- `bin/nucleor.exe build tests/err/err_method_requires_direct.nr` →
  EFF-001 ✓
- `bin/nucleor.exe build tests/features/method_ambiguous_name_fail_open_smoke.nr`
  → builds + runs, exit 0 ✓

## Files changed

```
compiler/nucleor_s1_compiler.nr                   (4 hunks: helper + 3 entry-point gates + banner)
docs/rfcs/v1_PUNCHLIST.md                         (1 hunk: Effects §still-open replaced)
tests/err/err_method_requires_direct.nr           (new)
tests/err/err_method_body_builtin_transitive.nr   (new)
tests/err/err_restricts_block_method_io.nr        (new)
tests/features/method_requires_clean_smoke.nr     (new)
tests/features/method_ambiguous_name_fail_open_smoke.nr (new)
bin/nucleor.exe                                   (refreshed: stage1 of edited source)
bootstrap/nucleor_s1_seed.ll                      (refreshed: stage2 IR md5 0bdc11ea)
findings/inbox/main_lane2_2B_method_impl_effects_v0845_2026-05-07.md (this report)
```

## Honest residuals

1. **Ambiguous-name receiver resolution.** When two impls declare
   methods with the same name and distinct rows, the row check is
   skipped. This is a deliberate fail-open to unblock adopter code;
   genuinely-violating calls on the ambiguous case go undetected.
   Receiver-type-aware resolution requires AST-level lookup (Phase 4
   / RFC-0033 broader effect-row subtyping). The body walk still
   reaches builtins via the substring path, so transitive
   builtin-effect violations on ambiguous methods still surface.
2. **Methods on tuple structs / generic param types.** Out of scope —
   the current substring-search approach is method-name-only;
   generics inherit the same name-collision treatment.
3. **Method calls via dyn-trait dispatch.** Out of scope — Queue 2C.
