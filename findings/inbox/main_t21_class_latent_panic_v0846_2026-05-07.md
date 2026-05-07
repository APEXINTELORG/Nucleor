# Latent tools-suite test-runner panic class — verify gates mask via cache

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Status:** PRE-EXISTING; NOT introduced by the T2.5 `#[manual_drop]`
  fix series (a3203449 / 5a4b790a / cd4f01ae). Bisected against
  `35cfb465` (pre-T2.5 baseline) — panic reproduces there too.
- **Surfaced by:** `tools/verify_fast.sh` post -x → -f sweep run on
  Windows/Git-Bash. Cache disabled for the targeted re-run; full
  verify.sh masks via cache hits.

## Headline

At least 8 verify steps that go through the `nuc test` path silently
fail or panic with `--no-cache` on Windows/Git-Bash. Full
`verify.sh` reports them as `OK` because the prior cached LL-build
output is reused, hiding the live panic. That makes the verify gate's
green claim semi-illusory for these specific steps — they pass when
the cache has good content, but a fresh-clone or
`rm -rf target/.nuc_cache` re-run will surface the underlying bugs.

## Repro of one (T2.1)

```bash
git checkout origin/main
rm -rf target/.nuc_cache target/t21_range_patterns*
bin/nucleor.exe build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
bin/nucleor.exe test tests/smoke/t21_range_patterns.nr --no-cache
```

Output:
```
discovered tests: 3
   test_range_inclusive_boundaries
   test_range_exclusive_normalizes
   test_range_falls_through_to_wildcard
source: target/t21_range_patterns-test__test_harness.nr (3020 bytes)
cache: disabled (sha=none, size 0 MB)
PANIC: index out of bounds: the len is 1 but the index is 1 (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)
RC=0
```

Exit 0 with a panic message: another silent-failure shape — the panic
fires after some side-effects, but the process exits 0 (NUCLEOR_VEC_OOB
guarded), so verify.sh's `grep -q "PASS: ..." || return 1` correctly
fails it but only when the cache miss exposes the panic.

## Bisect result

Tested at:
- `HEAD` (post-T2.5 + sisters): PANIC OOB
- `cd4f01ae~1` (just T2.5 + sister 1, no enum/trait/impl): PANIC OOB
- `a3203449~1` (pre-T2.5 manual_drop): silent RC=0, no test output —
  different symptom, same root: tests aren't actually running
- `35cfb465` (pre-T2.5 work entirely): PANIC OOB

So the `len 1 / index 1` panic predates the manual_drop fix series.
The pre-fix variant (`a3203449~1`) exits 0 silently with no PASS
messages — different surface, same underlying class.

## Affected steps from `verify_fast.sh` cache-miss run

```
[  2/1445] FAIL  compiler ABI tables synced  (  2.73s)
[  7/1445] FAIL  tests/err/*.nr have EXPECT headers  (  0.18s)
[439/1445] FAIL  test features/import_dedupe_lib  (  0.63s)
[1260/1445] FAIL  T2.1 range patterns in match (1..=9 / 1..10)  (  0.18s)
[1268/1445] FAIL  T3.3 static WCET v1 estimator emits warning[RT-004]  (  0.71s)
[1314/1445] FAIL  T3.57 tuple-destructure let safety net (pre-v0.3.81 segfault → clean diagnostic)  (  0.10s)
[1340/1445] FAIL  T3.83 v0.4.33a let tuple-destructure no longer silent-drops bindings  (  0.57s)
[1400/1445] FAIL  T3.141 v0.4.95 — variable-divisor zero panics with clean message (was silent SIGFPE / exit 127)  (  0.05s)
parallel fixtures: PASS 1196, FAIL 1, wall 245.60s, sum 821.01s, speedup 3.34x
```

Most are `nuc test` path through tools-suite. Each likely has its own
specific Vec OOB or silent-no-output flavor depending on the source's
parse tree shape (range patterns, tuple-destructure, deadline annotation,
etc.).

## Why full verify.sh reports them as OK

verify.sh's `t21_range_patterns()` step body (line 4429 of
`tools/verify_fast.sh` / 5702 of `tools/verify.sh`) calls
`"$BIN" test ... > $NUC_VERIFY_STEP_LOG 2>&1` WITHOUT `--no-cache`.
The compile cache is shared across runs at `target/.nuc_cache/`. Once
a previous run produced a known-good LL for the same source, it gets
reused — and the runner skips the parse path that triggers the panic.
The "PASS: test_range_..." lines came from the CACHED run-step output
that was redirected into the log on a previous pass.

Net result: verify gate's PASS claim for these steps is conditional on
"there has been a prior good build at some point in this checkout's
lifetime" — fresh clones get cache-miss panics.

## Recommended action (partner team scope)

This is a tools-suite parser/runtime debugging exercise; not in
integrator scope to root-cause solo. The right shape for the next
rotation:

1. **Add `--no-cache` to verify gates** for the affected step bodies
   so cache-miss failures surface immediately instead of being masked.
   Or: add a `tools/verify_no_cache.sh` driver that runs after
   `rm -rf target/.nuc_cache` to expose the latent class.
2. **Bisect each step independently** — they may have different
   underlying causes (range patterns / tuple destructure / deadline
   annotation each exercise distinct parse paths).
3. **Prefer Vec OOB diagnostic prints over silent-RC=0** — the current
   `len 1 / index 1` class panic is actionable; the "silent RC=0 no
   test output" class is opaque. Wire NUCLEOR_VEC_OOB to print a
   stack-shape hint (caller fn name) before panicking.

## What I did NOT do

- Did not revert any T2.5 manual_drop work. Bisect proves T2.5 fixes
  are not the cause; the panic predates them.
- Did not attempt root-cause on the OOB. That requires a `bisect_mem`
  or a careful trace through tools-suite's test harness path —
  partner-Compiler team scope.
- Did not edit `verify.sh` to add `--no-cache` to these steps. That
  would convert silent-OK to FAIL on every run, blocking the gate.
  Wait until the underlying bugs are root-caused before tightening.

## Honest residual

This finding documents a credibility gap in the current
`PASS=1485 SKIP=2 FAIL=0` headline number on origin/main. The number
is accurate FOR THE STATE THE CACHE IS IN; it is NOT accurate for a
fresh clone. PROBE-3 doc-claim audit (queue handed off in
`Control1.md`) should reference this finding when scoping the
"production readiness" claim — at least 8 of those 1485 PASSes are
cache-conditional.
