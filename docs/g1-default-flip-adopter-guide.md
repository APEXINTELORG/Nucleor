# G-1 Default-Flip Adopter Guide (RFC-0062 Phase 2b-3)

**Status:** v0.8.39 experiment — adopter validation phase
**Final ship:** Phase 2b-3 unconditional flip, after seed-side trace

## What's the flip?

Today (v0.x): a Nucleor function only gets auto-drop semantics
if it's tagged `#[auto_drop]`. Bindings of `Vec<T>`, `HashMap<K,V>`,
`String`, `Box<T>`, `VecDeque<T>` that don't have an explicit
`vec_free` / `hashmap_free` / etc. leak at function exit.

After Phase 2b-3 ships (v0.9.x): every function will auto-drop
heap-backed locals by default. Adopters can opt out per-function
with `#[manual_drop]` if they intentionally retain heap state
across the function boundary.

## Validating your code today

The default-flip mechanism shipped behind an env-var gate in
v0.8.39. Adopters can opt in to test their code against the
future semantics:

```bash
# Bash / WSL
NUC_AUTO_DROP_DEFAULT=1 nucleor build my_code.nr -o out

# PowerShell
$env:NUC_AUTO_DROP_DEFAULT='1'; nucleor build my_code.nr -o out
```

When the env var is set, the build emits:

```
info[FLIP-G1]: NUC_AUTO_DROP_DEFAULT=1 — Phase 2b-3 default-flip ENABLED for this build.
```

## What to check

1. **Compile cleanly.** No new errors or panics from the flip.
2. **Run without segfault / double-free.** The auto-drop
   pipeline already handles `explicit free disables generated
   drop` — if you have explicit `vec_free(v)`, the generated
   drop is suppressed for `v`. But verify your test suite
   passes.
3. **Memory usage matches expectations.** With auto-drop,
   per-call peak memory should DECREASE for fns that previously
   leaked. If it INCREASES, you may have a use-after-drop bug
   (a binding whose lifetime extends past where you thought it
   did).

## Reporting

If something breaks under the flip, you have three remediation
paths:

- **Option A:** Add `#[manual_drop]` to the affected fn. Suppresses
  the auto-drop entirely; behavior identical to today's default.
- **Option B:** Refactor to return the owned value (bare-name
  return). The auto-drop pipeline skips the drop on a bare-name
  return, transferring ownership to the caller.
- **Option C:** Add explicit `vec_free(v)` (etc.) before the
  return. The pipeline detects this and skips the generated
  drop.

If none of these options seem right, file a report on the
RFC-0062 G-1 issue tracker with a minimal repro.

## Smoke fixture

`tests/fixtures/v0840_g1_flip_adopter_smoke.nr` exercises the
pipeline. With/without the env var:

- Without flip: build emits 1 `vec_free` reference (just the
  declaration). Runtime returns rc=3 (Vec has 3 elements).
- With flip: build emits 2 `vec_free` references (declaration +
  auto-drop call inserted at fn exit). Runtime returns rc=3
  (same observable behavior; the leak is silently fixed).

## Known gap (v0.8.39)

The env-flip mechanism works for adopter fixtures but produces
byte-identical IR for the seed compiler self-host. The seed has
89 default-flip-candidate fns (per `tools/g1_safety_audit_report.txt`)
that don't receive the generated drop calls under the env var.

The gap is between `name_in_auto_drop` returning 1 and
`auto_drop_register` actually registering the binding for cleanup.
Hypotheses are documented in `docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md`
§2b-3-trace investigation notes. The unconditional default-flip
(Phase 2b-3 final) waits on resolving this gap.

## Timeline

- v0.8.31–v0.8.32: `#[manual_drop]` reserved + suppress wired
- v0.8.35–v0.8.37: safety audit tool + auto-classifier
- v0.8.39: env-gated flip experiment (this ship enables this guide)
- vNext: trace + fix the seed-side gap
- vNext+1: Phase 2b-3 — flip default unconditionally
- vNext+2: Phase 4 — `#[manual_drop]` becomes only valid in
  unsafe blocks; remove the env-var gate
