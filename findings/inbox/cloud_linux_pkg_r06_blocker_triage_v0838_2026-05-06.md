# Cloud Linux PKG-1/R06 Blocker Triage v0838

Date: 2026-05-06
Triage host: Windows local repo inspection
Cloud branch checked: `fix/helper2-native-linux-pkg-r06-closure-v0837`

## Status

The cloud branch on GitHub is still at the original dispatch commit:

```text
9448f335178cb7ecac9b3b7700e132c9c80507e8 refs/heads/fix/helper2-native-linux-pkg-r06-closure-v0837
```

No pushed blocker report was visible on that branch during this triage. Treat
any cloud blocker claims as unverified until the cloud agent pushes a report or
pastes exact command output.

## Confirmed Dispatch Contract Bug

The v0837 cloud packet used commands that do not match the implemented release
tooling contract:

- `./bin/nucleor release keygen --out ... --key-id ...` is not exposed by the
  tools-suite command dispatcher.
- `nuc publish --key <path>` is not accepted by `run_publish_command`; the
  current publish command accepts `--sign` and `--key-id <id>`.
- `tools/native_release.ps1 package-sign-preflight ... --key-id <id>` is not
  accepted; the PowerShell release tool accepts the requested key ID as a
  positional third argument: `package-sign-preflight <dir> [key-id]`.

Source evidence:

- `compiler/nucleor_tools_suite.nr` dispatches `publish` but has no matching
  `release` top-level command.
- `compiler/nucleor_tools_suite.nr::run_publish_command` usage is
  `nuc publish [path/to/Nucleor.toml|project_dir] [--registry <dir>] [--dry-run] [--sign [--key-id <id>]]`.
- `tools/native_release.ps1::Parse-ReleaseArgs` only treats `--json`,
  `--output=json`, and `--output json` as named options; command-specific key
  IDs are positional.
- `tools/native_release.ps1` implements `keygen [key-id]`,
  `package-sign <dir> [key-id]`, `package-sign-preflight <dir> [key-id]`, and
  `package-verify <dir>`.

## Corrected PKG-1 Command Shape

Use this command shape on native Linux:

```bash
set -euo pipefail
uname -a
test "$(uname -s)" = "Linux"
git status --short --branch
bash tools/bootstrap_linux.sh
test -x ./bin/nucleor
./bin/nucleor --version
command -v pwsh
command -v ssh-keygen

tmp="$(mktemp -d)"
registry="$tmp/nucleor-registry"
keydir="$tmp/nucleor-keys"
mkdir -p "$registry" "$keydir"
export NUCLEOR_POLICY_ROOT="$keydir"

./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
  --registry "$registry" \
  --dry-run \
  --sign \
  --key-id throwaway-ci

test ! -e "$registry/foo/0.1.0/Nucleor.publish.signature.json"

pwsh -NoProfile -File tools/native_release.ps1 -Root . keygen throwaway-ci --json

./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
  --registry "$registry" \
  --sign \
  --key-id throwaway-ci

test -f "$registry/foo/0.1.0/Nucleor.toml"
test -f "$registry/foo/0.1.0/Nucleor.publish.json"
test -f "$registry/foo/0.1.0/Nucleor.package.sha256"
test -f "$registry/foo/0.1.0/Nucleor.publish.signature.json"

pwsh -NoProfile -File tools/native_release.ps1 -Root . package-sign-preflight \
  "$registry/foo/0.1.0" \
  throwaway-ci \
  --json

pwsh -NoProfile -File tools/native_release.ps1 -Root . package-verify \
  "$registry/foo/0.1.0" \
  --json
```

If this still fails on native Linux, the cloud agent should push the exact
stdout/stderr, exit code, host details, and source-path attribution.

## R06 Notes

The R06 POSIX rust_bridge harness is still the right native-Linux proof path.
Its doctor intentionally rejects Windows cargo, Windows `.lib` artifacts, and
`bin/nucleor.exe`. On a true Linux host, a missing
`stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a` is not an
automatic blocker because the normal non-doctor run attempts `cargo build
--release` before compiling the focused Nucleor fixtures.

Required R06 command shape remains:

```bash
bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --self-test
bash tools/check_rust_bridge_ownership.sh --doctor --json
bash tools/check_rust_bridge_ownership.sh --self-test --json
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 5 --json
test -f stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a
```

## Files Updated

- `docs/rfcs/CLOUD_LINUX_PKG_R06_DISPATCH_v0837_2026-05-06.md`
- `findings/_helper2_assignment_v0828_r06_rust_bridge_ownership_harness_2026-05-06.md`
- `tools/VERIFY_TIMING_RECIPE.md`

Validation: `git diff --check` passed.
