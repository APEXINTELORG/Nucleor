# Track max_depth extensions spike - 2026-05-01

## Branch

- Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_max_depth_extensions`
- Branch: `v06-track-max-depth-extensions`
- Base: `701035f4d6aa60f94c25f5274eb0df7810010e91` (`v0.5.10`)
- Scope: RFC-0014 conservative static-analysis extensions from Parallel-1 Pick 2.

## Implemented

- Extended `#[max_depth]` proof recognition beyond the Track I substrate:
  - depth-counter flow can use any named integer parameter, not only the first non-self parameter.
  - positive literal strides such as `depth + 2` and `2 + depth` are accepted when the bound accounts for the stride.
  - simple helper guards can prove the base case when the helper's body exposes the guard.
  - callback parameters called inside a bounded function must be marked `#[no_recurse]`.
  - raw recursive SCCs are rejected unless every edge is proven and every member uses the same bound.
- Added parser/signature handling so parameter-site attributes like `#[no_recurse]` do not get mistaken for argument names in generated wrapper calls.
- Mirrored DEPTH-001 explanation text into `compiler/nucleor_tools_suite.nr`.
- Extended `tools/verify.sh` RFC-0014 gate with 5 positive fixtures and 5 negative fixtures.

## Fixtures

Positive fixtures:

- `tests/features/rfc0014_max_depth_param_flow.nr`
- `tests/features/rfc0014_max_depth_stride.nr`
- `tests/features/rfc0014_max_depth_helper_guard.nr`
- `tests/features/rfc0014_max_depth_no_recurse_callback.nr`
- `tests/features/rfc0014_max_depth_scc.nr`

Negative fixtures:

- `tests/err/err_depth_001_callback_unknown.nr`
- `tests/err/err_depth_001_non_monotonic.nr`
- `tests/err/err_depth_001_helper_unproven.nr`
- `tests/err/err_depth_002_stride_bound.nr`
- `tests/err/err_depth_003_scc_unproven.nr`

## Conservative Cases

- Callback recursion remains rejected unless the callback parameter is explicitly marked `#[no_recurse]`.
- Helper guard proof is intentionally shallow; helpers must expose a simple guard that the analyzer can inspect.
- Mutual recursion requires equal `#[max_depth]` bounds across the proven SCC.
- Stride recursion still fails if the declared bound cannot cover the literal stride.

## Validation

Targeted RFC-0014 extension fixture sweep:

- Positive fixtures all build and run.
- Negative fixtures emitted expected codes: DEPTH-001, DEPTH-002, and DEPTH-003.

Capped compiler promotion:

- Stage 1 self-build: peak 650 MB / 1024 MB, wall 5.236s.
- Stage 2 self-build: peak 662 MB / 1024 MB, wall 4.947s.
- Stage 3 self-build: peak 625 MB / 1024 MB, wall 5.195s.
- Fixed point:
  - stage2 `15693A36B96C67F472453C900AC620C6583D967C73AF47B450C76C22CC7F9056`
  - stage3 `15693A36B96C67F472453C900AC620C6583D967C73AF47B450C76C22CC7F9056`

Drift and audit:

- `bash tools/check_compiler_drift.sh`
  - tools-suite ABI tables match.
  - `helper_manifest.toml` up to date.
  - `rod_manifest.toml` up to date.
  - `RELEASES.md` up to date.
- NUM-024 audit: `compiler=0 tools-suite=0`.

Full verify:

- Env-off: `NUCLEOR_INT_STRICT_INTRIN=0`, `PASS: 700`, `SKIP: 1`, RSS watchdog peak 968.2 MB, no kill.
- Env-on: `NUCLEOR_INT_STRICT_INTRIN=1`, `PASS: 700`, `SKIP: 1`, RSS watchdog peak 881.9 MB, no kill.

## Socket Firewall Note

The Windows Defender prompt for the socket rod is real but not a blocker for this branch. The current worktree already has Allow rules for:

- `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_max_depth_extensions\target\_pv_rods_socket.exe`

The branch also pre-seeded Block rules for the older possible names:

- `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_max_depth_extensions\target\socket.exe`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_max_depth_extensions\target\socket_test.exe`

The rod test binds localhost/high ports and does not require external inbound network permission, so either Allow or Block avoids an unattended dialog without changing the expected result.
