# Cloud Claude Dispatch v0839: PKG-1 and R06 Native Linux Proof

Date: 2026-05-06
Owner: cloud Claude lane 1
Base: current `origin/main` at or after `35028273`
Branch: `fix/cloud-claude-pkg-r06-linux-proof-v0839`

## Goal

Close the native Linux proof gap for:

- PKG-1 signed package publish and verification.
- R06 POSIX `rust_bridge` ownership harness evidence.

This lane is proof-first. Use a true Linux host. Do not use WSL, Wine, Windows
`.exe` binaries, or copied Windows artifacts as POSIX evidence.

## Start Commands

```bash
git fetch origin
git checkout -B fix/cloud-claude-pkg-r06-linux-proof-v0839 origin/main
git status --short --branch
git log --oneline --decorate -5
uname -a
test "$(uname -s)" = "Linux"
```

## Scope A: PKG-1 Signed Publish Proof

Use the exact current command shape. Earlier dispatches used stale command
forms; do not use `./bin/nucleor release keygen`, `nuc publish --key <path>`,
or `package-sign-preflight --key-id <id>`.

```bash
set -euo pipefail

bash tools/bootstrap_linux.sh
test -x ./bin/nucleor
./bin/nucleor --version

./bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
test -x ./target/nucleor_tools

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

If this fails, capture the exact command, exit code, stdout/stderr, host
details, and file path responsible. If the fix is small and local, patch it on
the same branch. If it is not small, stop after writing the blocker report.

## Scope B: R06 POSIX rust_bridge Ownership Proof

Required commands:

```bash
bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --self-test
bash tools/check_rust_bridge_ownership.sh --doctor --json
bash tools/check_rust_bridge_ownership.sh --self-test --json
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 5 --json
test -f stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a
```

Doctor must reject Windows cargo, Windows `.lib` artifacts, and Windows
`bin/nucleor.exe` evidence. On Linux, the normal non-doctor fixture path may
build the Rust static archive before compiling the focused Nucleor fixtures.

## Scope C: Report

Create:

```text
findings/inbox/cloud_claude_pkg_r06_linux_proof_v0839_2026-05-06.md
```

Include:

- branch, HEAD, base, merge-base;
- `uname -a`, shell, `pwsh` path/version, `ssh-keygen` path/version;
- `./bin/nucleor --version`;
- PKG-1 command transcript summary and artifact paths;
- proof that dry-run wrote no signature;
- proof that signed publish wrote metadata/checksum/signature;
- package preflight and verify JSON summaries;
- R06 doctor/self-test/repeat fixture outputs;
- changed files, if any;
- exact blockers, if any;
- whether main needs drift, perf, self-host, or full verify.

## Validation If Code Changes

Always:

```bash
git diff --check
```

If compiler/tooling source changes:

```bash
bash tools/check_compiler_drift.sh
```

If release tooling changes:

```bash
pwsh -NoProfile -File tools/native_release.ps1 -Root . keygen throwaway-ci --json
```

Do not run full verify by default. Keep this lane focused on native Linux
PKG-1/R06 proof.

