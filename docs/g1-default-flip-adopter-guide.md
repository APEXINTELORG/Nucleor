# G-1 Default-Flip Adopter Guide (RFC-0062 — v1.0 retrospective)

**Status:** v1.0 — auto-drop is the default. This document is a
retrospective of the v0.8.x experiment that hardened the flip
before it shipped, plus the v1.0 opt-out mechanism for adopters
who need explicit lifetime control.

## The flip, as shipped at v1.0

In v1.0, every function auto-drops heap-backed locals at function
exit by default. Bindings of `Vec<T>`, `HashMap<K,V>`, `String`,
`Box<T>`, `VecDeque<T>` are freed when they go out of scope, with
no explicit `vec_free` / `hashmap_free` call required.

Adopters who need explicit lifetime control (intentionally retaining
heap state across the function boundary, FFI handoff, or staged
free patterns) opt out per-function with `#[manual_drop]`:

```nr
#[manual_drop]
fn build_vec_for_caller() -> Vec<i64> {
    let v: Vec<i64> = vec_new();
    vec_push(v, 1); vec_push(v, 2); vec_push(v, 3);
    return v;          // caller owns; no auto-drop here
}
```

The OSS compiler self-host source uses `#[manual_drop]` only for
the small handful of fns that intentionally pass heap-backed
ownership across boundaries (the build driver, the diagnostic emit
path); everything else relies on the default.

## Migration from pre-v1.0 sources

Pre-v1.0 sources tagged `#[auto_drop]` per-function and required
explicit `vec_free` / `hashmap_free` everywhere else. Migrating
to v1.0:

1. Remove `#[auto_drop]` annotations — they are now redundant
   (the compiler accepts the attribute and treats it as a no-op
   for backward source compatibility).
2. Remove explicit `vec_free` / `hashmap_free` / etc. calls at
   end-of-scope where the binding is dropped at scope exit. The
   auto-drop pipeline detects existing `*_free` calls and
   suppresses the generated drop, so leaving them in is correct
   but redundant.
3. For functions that intentionally return owned heap state,
   either let the bare-name return pass ownership (auto-drop
   skips dropped-by-return bindings), or annotate the function
   with `#[manual_drop]` if you need full explicit control.

## Legacy env-var (deprecated; defaults to flipped at v1.0)

The pre-v1.0 experiment shipped behind `NUC_AUTO_DROP_DEFAULT`.
At v1.0 the default IS the flip; the env var is no longer
load-bearing. Setting `NUC_AUTO_DROP_DEFAULT=0` is a legacy
escape hatch retained for adopter-side migration only — new code
should not depend on it.

```
info[FLIP-G1]: NUC_AUTO_DROP_DEFAULT=1 — Phase 2b-3 default-flip ENABLED for this build.
```

The above message was emitted by pre-v1.0 builds when the env
var was set. v1.0 builds do not emit it for the default path; the
flip is unconditional.

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

## Historical gap (v0.8.39 — closed v0.8.75)

The env-flip mechanism worked for adopter fixtures but produced
byte-identical IR for the seed compiler self-host. The seed had
89 default-flip-candidate fns (audited via the now-retired
`tools/g1_default_flip_safety_audit.py`) that didn't receive the
generated drop calls under the env var.

The gap was traced to `name_in_auto_drop` returning 1 while
`auto_drop_register` failed to register the binding for cleanup.
Root cause and resolution are documented in
`docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md` §2b-3-trace. The
unconditional default-flip landed in v0.8.75.

## Timeline

- v0.8.31–v0.8.32: `#[manual_drop]` reserved + suppress wired
- v0.8.35–v0.8.37: safety audit tool + auto-classifier (retired
  v0.8.323 — RFC-0063 Phase 1.1; one-shot purpose served)
- v0.8.39: env-gated flip experiment (this ship enables this guide)
- v0.8.64: cache_v2_canonical_flags root-caused; trace closed
- v0.8.75: Phase 2b-3 — default-flip unconditional ✅
- v1.0 (target): Phase 4 — `#[manual_drop]` becomes only valid in
  unsafe blocks; env-var gate removed
