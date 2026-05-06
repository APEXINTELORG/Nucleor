# Helper2 HERM-A Numerics Matrix Closure v0846

Date: 2026-05-06

Worktree:

`C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`

Branch:

`fix/helper2-herm-a-numerics-v0846`

Base:

- `origin/fix/main-qm7-surface-code-v0827`: `c5ba8d02962ec15a35dbfb30b9b13d34d06a75fa`
- `merge-base HEAD origin/fix/main-qm7-surface-code-v0827`: `c5ba8d02962ec15a35dbfb30b9b13d34d06a75fa`

## Scope AP Result

HERM-A is not a release/product/toolchain blocker on the current integration
base. `tools/gen_numerics_matrix.py` is not used by normal product commands,
bootstrap, full verify, fast verify, release freshness checks, or
`tools/check_compiler_drift.sh`.

It should not be ported to native Nucleor as-is. The Python generator is stale
relative to the committed numerics matrix and would rewrite current fixtures
back to older syntax.

## Evidence

Current committed matrix shape:

```text
p1_intarith 24
p11_format 3
p12_rods 1
p2_literals 6
p3_layout 5
p4_cast 8
p5_float 4
p6_bitwise 4
p7_overflow 4
p8_vec 3
p9_ffi 1
total=63
```

`tests/lang/numerics_matrix/MANIFEST.md` says this tree is not picked up by the
standard verify gate and must be run through the dedicated numerics runner:

```text
PowerShell: pwsh tools/run_numerics_matrix.ps1
Bash:       bash tools/run_numerics_matrix.sh
```

Search evidence for product/gate usage:

```powershell
rg -n "gen_numerics_matrix|numerics_matrix|HERM-A|Python" tools docs findings tests
rg -n "gen_numerics_matrix|run_numerics_matrix|tests/lang/numerics_matrix|numerics_matrix" tools\check_compiler_drift.sh tools\verify.ps1 tools\verify.sh tools\verify_fast.sh docs\rfcs\RFC-0063-production-readiness-roadmap.md docs\rfcs\v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md docs\rfcs\v1_PUNCHLIST.md
```

Observed gate references:

```text
tools/run_numerics_matrix.sh
tools/run_numerics_matrix.ps1
tests/lang/numerics_matrix/MANIFEST.md
docs/rfcs/RFC-0063-production-readiness-roadmap.md
docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md
```

No active `tools/check_compiler_drift.sh`, `tools/verify.ps1`,
`tools/verify.sh`, or `tools/verify_fast.sh` invocation uses
`tools/gen_numerics_matrix.py`.

## Python Oracle Staleness

Probe command:

```powershell
python tools\gen_numerics_matrix.py
git diff --name-only -- tests\lang\numerics_matrix
git diff --numstat -- tests\lang\numerics_matrix
git restore -- tests\lang\numerics_matrix
```

Observed output:

```text
Wrote 63 test files into C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\tests\lang\numerics_matrix
```

Changed files from the Python generator:

```text
tests/lang/numerics_matrix/p6_bitwise/and_u8.nr
tests/lang/numerics_matrix/p6_bitwise/or_u32.nr
tests/lang/numerics_matrix/p6_bitwise/shl_u8.nr
tests/lang/numerics_matrix/p6_bitwise/shr_i8.nr
tests/lang/numerics_matrix/p7_overflow/checked_add_u8.nr
tests/lang/numerics_matrix/p7_overflow/saturating_add_u8.nr
tests/lang/numerics_matrix/p7_overflow/wrapping_add_u8.nr
tests/lang/numerics_matrix/p8_vec/vec_f32_basic.nr
tests/lang/numerics_matrix/p8_vec/vec_i32_roundtrip.nr
tests/lang/numerics_matrix/p8_vec/vec_u8_size.nr
```

Numstat:

```text
2  5   tests/lang/numerics_matrix/p6_bitwise/and_u8.nr
2  4   tests/lang/numerics_matrix/p6_bitwise/or_u32.nr
3  5   tests/lang/numerics_matrix/p6_bitwise/shl_u8.nr
4  7   tests/lang/numerics_matrix/p6_bitwise/shr_i8.nr
3  6   tests/lang/numerics_matrix/p7_overflow/checked_add_u8.nr
3  3   tests/lang/numerics_matrix/p7_overflow/saturating_add_u8.nr
3  5   tests/lang/numerics_matrix/p7_overflow/wrapping_add_u8.nr
7  12  tests/lang/numerics_matrix/p8_vec/vec_f32_basic.nr
9  12  tests/lang/numerics_matrix/p8_vec/vec_i32_roundtrip.nr
6  15  tests/lang/numerics_matrix/p8_vec/vec_u8_size.nr
```

The stale rewrites would replace newer bitwise rod-based fixtures, direct
overflow helper calls, and generic vector backing fixtures with older syntax.
Those probe edits were restored before this branch's actual changes.

## Changed Files

- `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- `docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md`
- `findings/inbox/helper2_herm_a_numerics_matrix_v0846_2026-05-06.md`

## Decision

No `tools/gen_numerics_matrix.nr` was added in this slice.

Smallest safe next implementation surface:

1. Decide whether the numerics matrix should remain generated at all now that
   it has evolved past the Python generator.
2. If yes, refresh `tools/gen_numerics_matrix.py` to match the committed
   63-file matrix exactly.
3. Only then port the refreshed generator to native Nucleor and compare against
   the committed matrix.

Until step 2 is done, a native port would preserve a stale oracle rather than
remove a real release dependency.

## Validation

Commands:

```powershell
bash tools/check_compiler_drift.sh
git diff --check
git status --short --branch
```

Observed output:

```text
bash tools/check_compiler_drift.sh
Exit code: 0
WARN: parser fn 'parse_match_stmt' diverges between s1 and tools_suite
WARN: parser fn 'parse_stmt' diverges between s1 and tools_suite
WARN: parser fn 'parse_expr' diverges between s1 and tools_suite
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: promoted compiler version matches source (0.8.323)
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
OK: audit_dup_fns_report.csv is up to date
OK: CHANGELOG.md covers every git tag
OK: s1 compiler_version_label() matches CHANGELOG.md (0.8.323)
OK: tools_suite compiler_version_label() matches CHANGELOG.md (0.8.323)
OK: no opt-in privatization markers (pub fn) in compiler source

git diff --check
Exit code: 0

git status --short --branch
## fix/helper2-herm-a-numerics-v0846...origin/fix/main-qm7-surface-code-v0827 [ahead 1]
```
