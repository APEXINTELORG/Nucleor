# Queue 1 finding — Algebraic Laws Phase 3b broad property pack (local-claude2 v0842)

- **Branch:** `fix/local-claude2-law-phase3b-property-pack-v0842`
- **HEAD:** `1eda36196c16ebfeeef3d4a0db8d679f618e68bb`
- **Base / merge-base:** `4fa86e027a08f5e83dbc6e931dd42e1234894a21` (origin/main, `docs: dispatch v0842 parallel agent queues`)
- **Commits on branch (2):**
  - `4f71318d compiler: bounded integer inverse law (Phase 3b broad property pack)`
  - `1eda3619 tests/verify: bounded inverse-law smokes + verify wires (Phase 3b property pack)`
- **Pushed:** yes (`origin fix/local-claude2-law-phase3b-property-pack-v0842`)

Codex integration base: `origin/main` at
`3b135fba compiler: type remaining numeric helper returns`.

## Implemented behavior

`nuc test --check-laws` now generates bounded integer round-trip
checks for the canonical unary form `@law(inverse = g)`.

For each unary fn `f` annotated with `@law(inverse = g)` the
generator emits the four round-trips:

```
f(g(7))  == 7
f(g(-3)) == -3
g(f(5))  == 5
g(f(-1)) == -1
```

Diagnostic class is `LAW-001` (existing code, no new code added).
Failure modes:

- **Arity mismatch:** `error[LAW-001]: inverse law requires a unary fn: <fn>`
- **Missing partner-fn name:** `error[LAW-001]: inverse law requires a partner function name (e.g. \`inverse = g\`): <fn>`
- **Counterexample at any of the four sample integers:** `error[LAW-001]: inverse counterexample for <fn>` (raised by the generated harness, identical mechanism as commutative/associative/identity/etc.).

`fusion`, `seed=`, `cases=` remain in the canonical-but-unsupported
bucket and continue to fail closed via the existing message.
Float / `eps=` / `approximate` still fail closed with `LAW-004`
upstream of the inverse path.

## Files

### Compiler (1 file, 53 insertions)

- `compiler/nucleor_tools_suite.nr`
  - New `law_append_inverse_checks(sb, fn_name, inv_fn)` — emits
    the four bounded round-trips (mirrors `law_append_involution_checks`
    but with an external partner fn).
  - Dispatcher branch in `law_generate_check_fn` for
    `str_starts_with(item, "inverse=") == 1` — gates on
    `arity == 1` and `str_len(law_item_value(item)) > 0` before
    calling the new helper. `fusion` / `seed=` / `cases=` keep the
    pre-existing canonical-not-generated branch unchanged.

### Test fixtures (3 files)

- `tests/features/law_inverse_bounded_smoke.nr` — **NEW** positive smoke.
  `@law(inverse = negate)` on `negate(a) = -a` (negate is its own
  inverse). Plain run rc=0, `--check-laws` rc=0, generated harness
  reports `PASS: __nucleor_law_check_0`.
- `tests/features/law_schema_malformed_inverse_smoke.nr` — **NEW**
  fail-closed smoke. `@law(inverse =)` (empty partner). Plain run
  rc=0; `--check-laws` emits
  `error[LAW-001]: inverse law requires a partner function name`
  and exits nonzero.
- `tests/features/law_schema_inverse_unsupported_smoke.nr` — prose
  comment updated only. The fixture's body (`id_law` claiming
  `neg_law` as inverse — false) is now exercised through the new
  generator and caught as a counterexample (`error[LAW-001]:
  inverse counterexample for id_law`). `--check-laws` still exits
  nonzero with `LAW-001`, so the existing verify expectation holds.

### Verify wiring (1 file, +20 lines)

- `tools/verify.sh` — extended `cli_check_laws_smoke` with the
  positive smoke (must `PASS`, must emit `__nucleor_law_check_*`)
  and the malformed smoke (must fail with `LAW-001` + the
  `partner function name` substring). Existing
  `law_schema_inverse_unsupported_smoke.nr` block left in place.

## Validation

All commands run from the worktree root with the freshly rebuilt
`bin/nucleor_tools.exe`.

```
$ rm -f target/nucleor_tools.exe target/nucleor_tools.ll
$ ./bin/nucleor.exe build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
  functions: 716   (was 715 pre-branch)
  strings:   5643  (was 5637)
  optimized: 1387 instructions
$ cp target/nucleor_tools.exe bin/nucleor_tools.exe
```

```
$ ./bin/nucleor.exe test tests/features/law_inverse_bounded_smoke.nr --check-laws --no-cache
info[CHECK-LAWS]: generated bounded integer law checks
  PASS: __nucleor_law_check_0
test result: PASS (1 test)
```

```
$ ./bin/nucleor.exe test tests/features/law_schema_malformed_inverse_smoke.nr --check-laws --no-cache
error[LAW-001]: inverse law requires a partner function name (e.g. `inverse = g`): id_law_malformed
(rc != 0)
```

```
$ ./bin/nucleor.exe test tests/features/law_schema_inverse_unsupported_smoke.nr --check-laws --no-cache
... __nucleor_law_check_0 generated ...
error[LAW-001]: inverse counterexample for id_law
PANIC: LAW-001
(rc != 0)
```

Regression sweep — every pre-existing law fixture preserves its
prior rc and diagnostic class:

| fixture | --check-laws result | expected diagnostic |
|---|---|---|
| `law_check_true_smoke.nr` | rc=0, PASS (2 tests) | n/a |
| `law_check_distributive_true_smoke.nr` | rc=0, PASS (2 tests) | n/a |
| `law_check_false_smoke.nr` | rc!=0 | LAW-001 (commutative counterexample) |
| `law_schema_alias_zero_smoke.nr` | rc!=0 | LAW-006 |
| `law_schema_alias_distributive_smoke.nr` | rc!=0 | LAW-007 |
| `law_schema_unknown_smoke.nr` | rc!=0 | LAW-008 |
| `law_schema_approximate_unsupported_smoke.nr` | rc!=0 | LAW-004 |
| `law_schema_f64_unsupported_smoke.nr` | rc!=0 | LAW-004 |

S1 self-host smoke:

```
$ ./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o _claude2_law_s1_v0842 --no-link --no-cache
  functions: 838
  optimized: 2123 instructions
  emitted: target/_claude2_law_s1_v0842.ll (11663183 bytes)
  (build OK)
```

Drift / ABI / diff sanity:

```
$ bash tools/check_compiler_drift.sh
WARN: parser fn 'parse_expr' diverges between s1 and tools_suite
      (pre-existing — RFC-0063 Phase 2.0; not introduced by this branch)
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: promoted compiler version matches source (0.8.323)
OK: helper_manifest.toml is up to date

$ bash tools/check_rod_void_abi.sh
OK: rod void ABI clean (355 C void nuc_* definitions, 1275 non-void rod externs checked)

$ git diff --check
(no output — no whitespace/merge markers introduced)
```

Perf regression:

```
$ pwsh -NoProfile -File tools/check_perf_regression.ps1
OK perf: cold=3.88s (max 4s) | hot=0.44s (max 1s) | mem cold_tree=362/400MB cold_compiler=348/350MB hot_tree=70/128MB hot_compiler=55/64MB
```

`tools/verify_timings.csv` is not present in this worktree (it is
populated only by full `verify.sh` runs); the perf-regression
script ran cleanly within all four cold/hot budgets.

## Worktree note

The shared worktree at `Nucleor_OSS_integrate_helper2_wave5_v0840`
flipped its checkout HEAD twice during this run (to a
`fix/local-claude3-qm6-mps-streaming-range-v0842` branch and again
to `fix/local-claude-r05-transitive-effects-v0841`) while edits
were in flight, which silently reverted in-tree law fixtures and
verify wiring on disk. Both commits in this branch were created
locally then cherry-picked back onto a fresh
`fix/local-claude2-law-phase3b-property-pack-v0842` checked out
from `origin/main` and pushed before any further interleaving.
The pushed remote branch is the source of truth for this finding.

## Remaining law Phase 3 / 4 work

## Codex Integration Validation

Additional commands run from
`C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_law_phase3b_v0842`:

```text
PASS .\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
PASS .\bin\nucleor.exe test tests\features\law_inverse_bounded_smoke.nr --check-laws --no-cache
PASS .\bin\nucleor.exe test tests\features\law_schema_malformed_inverse_smoke.nr --check-laws --no-cache fails with LAW-001 + partner function name
PASS .\bin\nucleor.exe test tests\features\law_schema_inverse_unsupported_smoke.nr --check-laws --no-cache fails with LAW-001 inverse counterexample
PASS bash -n tools/verify.sh
PASS bash tools/check_compiler_drift.sh (known RFC-0063 parser warnings only)
PASS bash tools/check_rod_void_abi.sh
PASS git diff --check
```

This integration does not change `compiler/nucleor_s1_compiler.nr` or the
promoted compiler binary, so self-host and cold perf gates were not rerun for
this report/fixture/tools-suite-only slice.

After this delivery, the open Phase 3 surface listed in
`docs/rfcs/v1_PUNCHLIST.md` Algebraic Laws is:

- `fusion` generation (composable maps; needs syntax for binding
  partner fns / seeing the composition chain).
- Arbitrary-driven broad property tests (`seed = N`, `cases = N`
  modifiers) — currently fail-closed; need a property-test driver
  before they become accepted modifiers.
- Float `eps` / `approximate` semantics — needs an explicit
  tolerance contract before LAW-004 stops being the right answer.
- Optimizer rewrite gating (`LAW-003`) — Queue 2 of this dispatch
  starts exactly that: a proof-backed identity rewrite gated on
  `--check-laws` having validated the law metadata.

Phase 4 still owes cert-profile SMT/proof obligations and float-law
safeguards (`LAW-002`, `LAW-004` cert hardening).
