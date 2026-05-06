# Helper2 HERM-B Native TOML Parity v0845

Date: 2026-05-06

Worktree:

`C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`

Branch:

`fix/helper2-herm-b-native-toml-v0845`

Base:

- `origin/fix/main-qm7-surface-code-v0827`: `c5ba8d02962ec15a35dbfb30b9b13d34d06a75fa`
- `merge-base HEAD origin/fix/main-qm7-surface-code-v0827`: `c5ba8d02962ec15a35dbfb30b9b13d34d06a75fa`

## Scope

Validate the native helper manifest TOML generator against the Python generator
and the existing compiler drift gate.

The current integration base already contains:

- `tools/gen_helper_manifest.nr`
- `tools/gen_helper_manifest.py`
- `tools/check_compiler_drift.sh` wired to check
  `docs/rfcs/helper_manifest.toml` against `tools/gen_helper_manifest.nr`

So this slice is report-only. It does not duplicate TOML emission in
`tools/gen_helper_manifest_inventory.nr`.

## Validation

### Native generator build

Command:

```powershell
bin\nucleor.exe build tools\gen_helper_manifest.nr -o target\helper2_gen_helper_manifest_v0845
```

Result:

```text
Exit code: 0
source: tools\gen_helper_manifest.nr (65023 bytes)
mode: fast (ownership + type)
functions: 16
strings: 657
compiled: target\helper2_gen_helper_manifest_v0845.exe
cache: miss -> stored (sha=c38494d5ef38, size 1 MB)
```

### Python/native TOML comparison

Commands:

```powershell
python tools\gen_helper_manifest.py
Copy-Item -LiteralPath docs\rfcs\helper_manifest.toml -Destination target\helper_manifest_python_v0845.toml -Force
target\helper2_gen_helper_manifest_v0845.exe
Copy-Item -LiteralPath docs\rfcs\helper_manifest.toml -Destination target\helper_manifest_native_v0845.toml -Force
```

Result:

```text
Python generator:
Wrote C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\docs\rfcs\helper_manifest.toml
Total helpers: 875
REVIEW REQUIRED: 0

Native generator:
Wrote docs/rfcs/helper_manifest.toml
Total helpers: 875
REVIEW REQUIRED: 0
```

Comparison normalized only the attribution source
`tools/gen_helper_manifest.py` -> `tools/gen_helper_manifest.nr` and CRLF/LF
line endings.

```text
normalized_same=True
python_bytes=365075
native_bytes=352753
python_lines=12323
native_lines=12323
```

The byte-count difference is explained by line endings. After newline
normalization and the expected generator attribution change, the TOML content is
identical.

### Drift gate

Command:

```powershell
bash tools/check_compiler_drift.sh
```

Result:

```text
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
```

The parser divergence warnings are existing tracked RFC-0063 Phase 2.0 warnings;
the drift script exits successfully.

### Cleanliness

Command:

```powershell
git diff --check
git status --short --branch
```

Result before this report was added:

```text
git diff --check: exit code 0
## fix/helper2-herm-b-native-toml-v0845
```

## Non-Goals

- No compiler source edits.
- No bootstrap edits.
- No `bin/` edits.
- No `tools/verify.*` gate edits.
- No generated `docs/rfcs/helper_manifest.toml` commit.
- Full `tools/verify.sh` was not run for this report-only parity slice.

## Conclusion

`tools/gen_helper_manifest.nr` is parity-clean with the Python generator under
the expected attribution and newline normalization, and the existing drift gate
accepts the native generator as the freshness source for
`docs/rfcs/helper_manifest.toml`.
