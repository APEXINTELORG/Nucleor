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
