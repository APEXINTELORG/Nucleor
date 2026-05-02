# Track Effects Types Spike - 2026-05-01

Branch: `v06-track-effects-types`
Base: `origin/main` `99d15c5` (`v0.5.3`)

## Scope Shipped

- Parser accepts RFC-0033 first-pass `with [...]` clauses on:
  - `fn f(...) -> T with [...] { ... }`
  - `fn f(...) with [...] { ... }`
  - `extern fn f(...) -> T with [...];`
  - trait method declarations/defaults
  - impl methods
  - function-pointer type syntax: `fn(T) -> U with [...]`
- `with [no_alloc]`, `with [no_panic]`, and `with [no_dyn]` feed the existing RT-001/002/003 enforcement path.
- `extern fn ... with [no_alloc]` and `extern fn ... with [no_panic]` feed the existing RT-005 per-symbol FFI safety lists.
- Direct call threading is covered for first-pass effect rows:
  - `with [Alloc]` called from `with [no_alloc]` emits `EFF-003`.
  - `with [Panic]` called from `with [no_panic]` emits `EFF-003`.
- Existing `#[no_alloc]`, `#[no_panic]`, `#[no_dyn]`, and `#[ffi_no_*]` behavior remains in the same collectors.

## Fixtures Added

- `tests/features/effects_with_positive.nr`
- `tests/err/err_effects_with_no_alloc_vec.nr`
- `tests/err/err_effects_with_no_panic.nr`
- `tests/err/err_effects_with_no_dyn.nr`
- `tests/err/err_effects_with_alloc_call.nr`
- `tests/fixtures/t333_effects_with_ffi.nr`

Verify gate additions:

- `T3.33 RFC-0033 with-effects syntax parses`
- `T3.33 RFC-0033 with [no_alloc] maps to RT-001`
- `T3.33 RFC-0033 with [no_panic] maps to RT-002`
- `T3.33 RFC-0033 with [no_dyn] maps to RT-003`
- `T3.33 RFC-0033 Alloc call rejected from no_alloc`
- `T3.33 RFC-0033 extern with [no_alloc] feeds RT-005`

## Validation Evidence

Final branch was rebased from `v0.5.0` to `v0.5.3` after the full gates below. The upstream delta was docs/index-only (`CHANGELOG.md`, `RELEASES.md`, `docs/UPGRADE_v0.5.0.md`, `docs/milestones/v0.7.0.md`, `docs/milestones/v0.8.0.md`); no compiler/test code changed under the branch. Post-rebase drift, focused RFC-0033 smoke, and fixed-point checks were rerun on `d8bb948`.

Post-rebase checks:

```text
POST_REBASE_RFC0033_SMOKE_OK
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
OK: compiler/nucleor_s1_compiler.nr peak 818 MB / 1024 MB budget, wall 6.139s
OK: compiler/nucleor_s1_compiler.nr peak 822 MB / 1024 MB budget, wall 5.619s
post_rebase_stage1_sha=3854B770801FCA786A5F2C4C2FBD552C227E7A245B59597E8E621DC2435409B3
post_rebase_stage2_sha=3854B770801FCA786A5F2C4C2FBD552C227E7A245B59597E8E621DC2435409B3
POST_REBASE_FIXED_POINT_OK
```

Focused tracked-binary smoke:

```text
PASS tracked bin RFC-0033 smoke + FFI
```

Env-off full gate, with `NUCLEOR_MEM_CAP_KB=1048576`, `NUC_VERIFY_JOBS=2`, and an outer process-tree e-stop at 1024 MB:

```text
verify env-off-2 rc=0 wall=724.6s peak=862MB
PASS: 696
SKIP: 1
```

Env-on full gate, with `NUCLEOR_INT_STRICT_INTRIN=1` and the same memory cap:

```text
verify env-on rc=0 wall=733.8s peak=938MB
PASS: 696
SKIP: 1
```

Two-stage fixed point, strict-intrinsic:

```text
OK: compiler/nucleor_s1_compiler.nr peak 758 MB / 1024 MB budget, wall 4.833s
OK: compiler/nucleor_s1_compiler.nr peak 823 MB / 1024 MB budget, wall 5.38s
stage1_sha=3854B770801FCA786A5F2C4C2FBD552C227E7A245B59597E8E621DC2435409B3
stage2_sha=3854B770801FCA786A5F2C4C2FBD552C227E7A245B59597E8E621DC2435409B3
FIXED_POINT_OK
```

Drift cleanup run after generated manifests were refreshed:

```text
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
```

## Memory Notes

- No e-stop tripped.
- Highest observed full-gate process-tree peak was `938 MB`, below the 1024 MB hard cap.
- Self-host and tools-suite memory gates in `verify.sh` both stayed below their current 1024 MB budgets.

## v0.5.24 Memory-Tighten Update

Follow-up branch: `v06-track-effects-types-mem-tightened`

Base after rebase: `origin/main` `71330cf` (`v0.5.24`)

The urgent memory regression was in the effects header survey path. The
tighten pass removes the full-source stripped-copy allocation in
`collect_headers_with_effect`; the scanner now walks the original source while
skipping line comments, strings, and char literals in place. This preserves the
first-pass RFC-0033 behavior while avoiding the large temporary source copy
during self-host compilation.

Current post-tighten fixed point under the process-tree RSS e-stop:

```text
stage1: OK peak 683 MB / 1000 MB e-stop, wall 5.564s
stage2: OK peak 658 MB / 1000 MB e-stop, wall 5.966s
stage3: OK peak 657 MB / 1000 MB e-stop, wall 5.378s
stage2_sha = stage3_sha = 3B09C5E7347E6D60F9E86A3B2C0B198F7ED7B30CC2A552FE71DA860AC696F2CF
strict-intrin seed refresh: OK peak 566 MB / 1000 MB e-stop, wall 5.949s
```

Current tight memory gates:

```text
self-host:   OK peak 624 MB / 770 MB e-stop, wall 5.620s
tools-suite: OK peak 456 MB / 580 MB e-stop, wall 5.052s
```

Current focused post-rebase validation:

```text
T3.33 RFC-0033 focused matrix: PASS env-off and env-on
  effects positive build/run
  with [no_alloc] -> RT-001
  with [no_panic] -> RT-002
  with [no_dyn] -> RT-003
  Alloc call from [no_alloc] -> EFF-003
  extern with [no_alloc] -> RT-005 warning for host_unsafe only

v0.5.24 1e20 f64 smoke: PASS, build peak 195 MB, run peak 3 MB
compiler drift gate: PASS, peak 49 MB
  OK: tools-suite ABI tables match nucleor_s1_compiler.nr
  OK: helper_manifest.toml is up to date
  OK: rod_manifest.toml is up to date
  OK: RELEASES.md is up to date

NUM-024 audit:
  compiler=0, peak 567 MB / 770 MB
  tools-suite=0, peak 459 MB / 580 MB
```

Full env-off/env-on gates were clean before the v0.5.24 rebase on the same
tightened source shape:

```text
env-off: PASS 705, SKIP 1, wall 969.883s, peak 813.8 MB process-tree
env-on:  PASS 705, SKIP 1, wall 977.931s, peak 761 MB process-tree
```

Post-v0.5.24 rebase did not require source-conflict edits; the only rebase
conflict was generated `bin/nucleor.exe` / `bootstrap/nucleor_s1_seed.ll`, both
regenerated from the rebased compiler and fixed-point checked above.

## v0.5.32 Rebase Refresh

Follow-up branch: `v06-track-effects-types-mem-tightened`

Base after rebase: `origin/main` `a60131b` (`v0.5.32`)

The branch was rebased onto current main after Track Y / Track Z integration.
The source conflicts were in the compiler/runtime memory work and the verify
timing recipe. The rebase kept main's newer per-function IR free and NVec
inline-buffer implementation, then preserved the effects substrate plus the
memory-watchdog tooling.

Watchdog note: Job-object containment is now opt-in with `NUC_RSS_USE_JOB=1`.
On this Windows toolchain, assigning the self-host compiler to a Job object can
leave the compiler waiting after the output artifact has already been emitted.
The default stays on parent-process-tree sampling so self-host builds finish
normally, while focused probes can still opt into Job tracking if needed.

Current post-rebase self-host fixed point under the RSS e-stop:

```text
stage1b: OK peak 581 MB / 1000 MB e-stop, wall 5.317s
stage2:  OK peak 597 MB / 1000 MB e-stop, wall 4.643s
stage3:  OK peak 598 MB / 1000 MB e-stop, wall 4.632s
stage2_sha = stage3_sha = FFD301E4CE8B53588D61B4B8F2396947EFFB9CDA26B65C1A95C860ADA8602BC3
final artifact check from bin\nucleor.exe: OK peak 668 MB / 1000 MB e-stop, wall 4.917s
final artifact check seed hash = bootstrap\nucleor_s1_seed.ll hash = FFD301E4CE8B53588D61B4B8F2396947EFFB9CDA26B65C1A95C860ADA8602BC3
```

Focused current validation:

```text
env-off: tools/run_verify_rss_estop.ps1 --range 236-241
  exit_code 0, wall 70.603s
  T3.33 RFC-0033 with-effects syntax parses: OK
  T3.33 RFC-0033 with [no_alloc] maps to RT-001: OK
  T3.33 RFC-0033 with [no_panic] maps to RT-002: OK
  T3.33 RFC-0033 with [no_dyn] maps to RT-003: OK
  T3.33 RFC-0033 Alloc call rejected from no_alloc: OK
  T3.33 RFC-0033 extern with [no_alloc] feeds RT-005: OK

env-on: tools/run_verify_rss_estop.ps1 -StrictIntrin 1 --range 236-241
  exit_code 0, wall 60.234s
  same six RFC-0033 checks: OK
```

The range wrapper's `peak_mb` output is intentionally not used as the compiler
RSS claim here because Git Bash can hide compiler descendants from the default
parent-tree sampler after Job tracking is disabled. The self-host build
measurements above are the current RSS evidence for this branch.
