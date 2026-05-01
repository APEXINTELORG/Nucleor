# Track I: RFC-0014 max_depth Full Ship

Date: 2026-05-01
Branch: `v05-track-i-max-depth`
Base at start: `8371700ad7ae1a164a6aba8d4c4d6ca15944c210` (`v0.4.271`)
Remote target: `origin/v05-track-i-max-depth`

## Scope Shipped

Track I implements RFC-0014 `#[max_depth = N]` as a compiler-enforced bounded-recursion feature:

- Parses `#[max_depth = N]` and `#[max_depth(N)]` on function declarations.
- Runs a conservative static analysis pass over the max-depth source view before later rewrites.
- Preserves the existing `#[deadline]` / RT-008 opt-out behavior for bounded recursion.
- Rewrites accepted functions through runtime depth entry/exit calls.
- Adds runtime support in `stdlib/runtime/nucleor_llvm_rt.c`.
- Wires `DEPTH-001..005` through compiler known-code checks, explain text, spec docs, err fixtures, and verify gates.
- Adds positive and negative fixtures plus a runtime overrun fixture.

## Algorithm

The static pass scans `#[max_depth]` function entries and records:

- function name after deadline rewrite
- public recursive call name used in the source body
- declared bound
- raw body text
- parameter text

For direct recursion, the pass proves the supported structural pattern:

- first parameter is the depth counter
- body has an entry guard such as `depth >= N` or `depth > N-1`
- recursive call advances the counter with `depth + 1`

If a recursive call is present but that shape cannot be proven, the compiler emits `DEPTH-001`.
If the proven guard depth exceeds the declared annotation, it emits `DEPTH-002`.

For visible two-function cycles, the pass checks each member's declared/proven bound and emits `DEPTH-003` when the cycle cannot compose safely.

The stack-budget check estimates frame cost from statement count, multiplies by declared depth, and emits `DEPTH-005` when the conservative budget is exceeded.

Invalid placement or non-positive/non-literal annotation values emit `DEPTH-004`.

## Runtime Lowering

Accepted functions are rewritten to call:

- `max_depth_enter(id, limit)` on function entry
- `max_depth_exit(id)` before returns and on fallthrough

The runtime stores per-function counters in thread-local storage and aborts with `error[DEPTH-003]` if the dynamic depth exceeds the declared limit.

## Conservative Surface

The analysis intentionally rejects recursion that may be safe but is not in the proven structural form. Examples:

- non-depth-counter recursion
- unknown callback or function-pointer recursion
- recursive calls without a monotonic `depth + 1` argument
- guard logic hidden behind helper functions
- cycles whose member bounds do not obviously compose

This keeps Track I safe for compiler adoption without requiring a full symbolic evaluator.

## Fixtures

Positive and runtime fixtures:

- `tests/features/rfc0014_max_depth_bounded.nr`
- `tests/fixtures/rfc0014_max_depth_runtime_overrun.nr`

Negative fixtures:

- `tests/err/err_depth_001_unbounded.nr`
- `tests/err/err_depth_002_overflow.nr`
- `tests/err/err_depth_003_cycle.nr`
- `tests/err/err_depth_004_invalid_context.nr`
- `tests/err/err_depth_005_stack_budget.nr`

The verify gate step is:

`RFC-0014 max_depth static analysis + runtime wrapper`

## Validation

Capped fixed-point:

```text
OK: compiler/nucleor_s1_compiler.nr peak 503 MB / 1024 MB budget, wall 4.297s
OK: compiler/nucleor_s1_compiler.nr peak 574 MB / 1024 MB budget, wall 4.049s
stage_i_l=86C61F10280CAC4FB91D6F482FC5B72CC42244CCFD6286CAE79336AB12C2A01F
stage_i_m=86C61F10280CAC4FB91D6F482FC5B72CC42244CCFD6286CAE79336AB12C2A01F
```

Capped tools-suite build:

```text
OK: compiler/nucleor_tools_suite.nr peak 468 MB / 1024 MB budget, wall 3.333s
```

NUM-024 audit:

```text
compiler=0 tools-suite=0
```

Env-off verify:

```text
NUCLEOR_MEM_CAP_KB=1048576 NUCLEOR_INT_STRICT_INTRIN=0 ./tools/verify.sh --no-color
PASS: 651
SKIP: 1
self-host memory: peak 507 MB / 550 MB
tools-suite memory: peak 382 MB / 500 MB
```

Env-on verify:

```text
NUCLEOR_MEM_CAP_KB=1048576 NUCLEOR_INT_STRICT_INTRIN=1 ./tools/verify.sh --no-color
PASS: 651
SKIP: 1
self-host memory: peak 547 MB / 550 MB
tools-suite memory: peak 404 MB / 500 MB
```

Drift checks:

```text
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
OK: no mojibake byte sequences detected
```

## Integration Note

This branch started from `8371700` and `origin/main` advanced while the track was in progress. The branch is intentionally pushed as an isolated Track I ship rather than rebased through unrelated concurrent mainline work. Integration should rebase or cherry-pick onto the then-current main and rerun the full env-off/env-on gate.
