# Cloud Linux Dispatch v0837: PKG-1 and R06 Native Proof

Audience: cloud Codex agent running on a true native Linux host.

Do not use WSL, Windows `.exe` interop, or Windows cargo as POSIX proof. If
`uname -s` is not `Linux`, stop and write a blocker report instead of running
the proof commands.

## Current Base

Start from current `origin/main`:

```bash
git fetch origin --prune
git checkout -B fix/helper2-native-linux-pkg-r06-closure-v0837 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Expected assignment-time base:

```text
9c29f246a0639b7fbe82e65f283baa4fda9689b3
```

If `origin/main` has advanced, use the fetched current `origin/main` and record
the actual base in your report.

## Read These First

The full helper2 workstream and detailed command contract are in:

```text
findings/_helper2_assignment_v0828_r06_rust_bridge_ownership_harness_2026-05-06.md
findings/inbox/helper2_pkg_r06_native_linux_handoff_v0835_2026-05-06.md
docs/rfcs/v1_PUNCHLIST.md
docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md
```

Queue 10 in the helper2 assignment is authoritative for this task.

## Mission

Close the two remaining native Linux evidence blockers:

1. PKG-1 native Linux signed publish proof.
2. R06 native POSIX rust_bridge ownership/artifact proof.

R10-D3 native Linux perf is already closed. Do not reopen perf unless a command
in this task directly proves a regression.

## PKG-1 Required Proof

Run a native Linux signed publish roundtrip against a throwaway registry/key:

```bash
set -euo pipefail
uname -a
test "$(uname -s)" = "Linux"
git status --short --branch
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

Do not use `./bin/nucleor release keygen`, `nuc publish --key <path>`, or
`package-sign-preflight --key-id <id>` for this proof. Current tools-suite
dispatch exposes `publish`, while `tools/native_release.ps1` exposes
`keygen <key-id>` and `package-sign-preflight <dir> [key-id]`.
The `publish` command is routed through the tools-suite binary, so a fresh
Linux checkout must build `compiler/nucleor_tools_suite.nr` before invoking
`./bin/nucleor publish`; `target/nucleor_tools` is sufficient and does not need
to be copied into `bin/`.

If `native_release.ps1 keygen`, signed publish, or package verification is
absent or fails, capture the exact command, stdout/stderr, exit code, and
likely source path. Do not paper over it with a docs-only DONE claim.

## R06 Required Proof

Run the native POSIX rust_bridge harness:

```bash
set -euo pipefail
uname -a
test "$(uname -s)" = "Linux"
command -v cargo
cargo --version
test -x ./bin/nucleor
./bin/nucleor --version

bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --self-test
bash tools/check_rust_bridge_ownership.sh --doctor --json
bash tools/check_rust_bridge_ownership.sh --self-test --json
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 5 --json
test -f stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a
```

Optional stronger signal if available:

```bash
bash tools/check_rust_bridge_ownership.sh --fixture string-free-repeat --iterations 100
```

Do not count `nucleor_rust_bridge.lib`, Windows cargo, or `bin/nucleor.exe` as
POSIX proof.

## Allowed Changes

Allowed if needed:

```text
tools/native_release.ps1
compiler/nucleor_tools_suite.nr only if publish CLI dispatch is truly broken
tests/fixtures/t14_registry/
stdlib/rods/rust_bridge/src/lib.rs
stdlib/rods/rust_bridge.nr
tools/check_rust_bridge_ownership.sh
tools/VERIFY_TIMING_RECIPE.md
docs/ffi-conventions.md
docs/rfcs/v1_PUNCHLIST.md
docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md
findings/inbox/helper2_pkg1_native_linux_signed_publish_v0837_2026-05-06.md
findings/inbox/helper2_r06_native_posix_rust_bridge_v0837_2026-05-06.md
```

Do not edit:

```text
bin/
bootstrap/
performance baselines
broad verify gates unless explicitly required by a source fix
```

## Validation

Always run:

```bash
git diff --check
```

Run if touched:

```bash
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
```

Run self-host/perf only if compiler, bootstrap, binary, cache, or hot toolchain
paths changed. Do not run full verify by default.

## Deliverable

Push:

```text
fix/helper2-native-linux-pkg-r06-closure-v0837
```

Final report must include:

```text
Branch:
HEAD:
Base:
Merge-base:
Host uname:
Compiler version:
PKG-1 status:
PKG-1 commands and outputs:
R06 status:
R06 commands and outputs:
Files changed:
Files intentionally not changed:
Validation:
Remaining blockers:
Whether main needs drift/self-host/perf/full verify:
```

If native Linux evidence cannot be produced, push a blocker report with exact
failing commands and no status overclaim.
