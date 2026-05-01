# Track L perf baseline lock + content-addressed cache spike

Date: 2026-05-01
Branch: `v05-track-l-perf-cache`
Base: `541b8cffe31ca553c0da03ee99f2c6c4d770d87a`
Closeout deadline: `2026-05-01 07:10:22 -04:00`

## Status

Track L is implemented and validated on the isolated branch. It has not been merged to
`main`.

The branch is intentionally pushed as an integration artifact so the main workflow can
diff, review, and integrate it without overwriting `main`.

## Scope

- Added content-addressed cache v2 under `target/.nuc_cache_v2/<prefix>/<sha>.ll`.
- Cache key includes compiler identity, canonical build flags, strict arithmetic mode,
  DbC mode, and source content.
- Added `--cache-stats` and `clean --cache`.
- Added cache correctness fixtures:
  - `tests/features/cache_v2_round_trip.nr`
  - `tests/features/cache_v2_invalidation.nr`
- Added `tools/measure_track_l_perf.ps1`.
- Updated `tools/check_perf_regression.ps1` to use scoped process-tree memory
  measurement instead of global compiler process cleanup.
- Locked `tools/perf_baseline.json` from the Track L measurement set.
- Wired the Track L cache gate into `tools/verify.sh` and `tools/verify.ps1`.
- Added missing explain-registry entries for `CONTRACT-008`, `CONTRACT-009`,
  `CONTRACT-010`, and `ATOMIC-006` after the env-off gate exposed drift.

## Cache proof

Focused cache proof against the rebuilt local compiler:

```text
MISS1 OK
HIT OK
CLEAN OK
INVAL MISS OK
TOUCH HIT OK
CONTENT MISS OK
```

This proves first-build store, second-build hit, `clean --cache`, mtime-only
touch stability, and content-mutation invalidation.

## Fixed point and memory

All compiler promotion runs used a 1024 MB process-tree cap.

```text
OK: compiler/nucleor_s1_compiler.nr peak 677 MB / 1024 MB budget, wall 4.498s
OK: compiler/nucleor_s1_compiler.nr peak 644 MB / 1024 MB budget, wall 4.49s
stage_l_l=6037AFCB85E1C7988BA74BE9254451A2D0C662541F651567B8F96557A907F73A
stage_l_m=6037AFCB85E1C7988BA74BE9254451A2D0C662541F651567B8F96557A907F73A
FIXED_POINT_OK 6037AFCB85E1C7988BA74BE9254451A2D0C662541F651567B8F96557A907F73A
```

Tools-suite rebuild:

```text
OK: compiler/nucleor_tools_suite.nr peak 514 MB / 1024 MB budget, wall 3.754s
```

After explain-registry patch:

```text
OK: compiler/nucleor_tools_suite.nr peak 516 MB / 1024 MB budget, wall 3.699s
EXPLAIN_OK CONTRACT-008
EXPLAIN_OK CONTRACT-009
EXPLAIN_OK CONTRACT-010
EXPLAIN_OK ATOMIC-006
```

## NUM-024 audit

```text
NUM024 compiler=0 tools-suite=0
```

## Full verify

Env-off verify after the explain-registry patch:

```text
PASS: 676
SKIP: 1
```

Env-on verify:

```text
PASS: 676
SKIP: 1
```

Env-on watchdog metadata:

```json
{
  "name": "track_l_verify_on_accept",
  "exit_code": 0,
  "killed": false,
  "reason": "",
  "peak_mb": 771,
  "wall_seconds": 609.508,
  "deadline": "2026-05-01 07:10:22 -04:00"
}
```

## Drift checks

```text
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
OK: no mojibake byte sequences detected
```

## Perf lock

`tools/perf_baseline.json` is locked for Track L with 10 cold and 10 hot samples
per config under a 1024 MB process-tree cap.

Baseline summary recorded in the JSON:

- env-default strict-on: cold p50 `4.643s`, cold p95 `5.928s`, hot p50 `1.222s`, hot p95 `1.743s`, peak `679 MB`
- env-off: cold p50 `4.555s`, cold p95 `4.965s`, hot p50 `1.127s`, hot p95 `1.736s`, peak `677 MB`
- wrapping fixture: cold p50 `0.708s`, cold p95 `1.142s`, hot p50 `0.648s`, hot p95 `1.219s`, peak `217 MB`

## Integration note

This branch was not rebased onto current `origin/main` during closeout. Integrators should
diff `v05-track-l-perf-cache` against its base and then replay or merge deliberately onto
the latest mainline.
