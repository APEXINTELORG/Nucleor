# Helper2 PKG-1/R06 Native Linux Handoff v0835

Date: 2026-05-06

Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`

Assignment: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\findings\_helper2_assignment_v0828_r06_rust_bridge_ownership_harness_2026-05-06.md`

Scope: Queue 9 Scope AS. This handoff converts the remaining native-only PKG-1 and R06 blockers into exact cloud-agent work. R10-D3 native Linux perf is closed and must not be reopened as the native Linux focus unless new regressions are found.

## Base Branch

Cloud agent must start from:

```text
origin/fix/main-qm7-surface-code-v0827
```

Base observed after fetch in this worktree:

```text
8413358a276e780cc02322cd089279758a33f593
```

Startup commands:

```bash
git fetch origin --prune
git switch -c fix/cloud-pkg1-r06-native-linux-v0835 origin/fix/main-qm7-surface-code-v0827
git merge-base HEAD origin/fix/main-qm7-surface-code-v0827
git status --short --branch
```

Expected merge-base before edits:

```text
8413358a276e780cc02322cd089279758a33f593
```

If `origin/fix/main-qm7-surface-code-v0827` moves, use the new fetched SHA and record it in the transcript. Do not branch from stale helper bases.

## R10-D3 Is Closed

R10-D3 POSIX/native Linux perf evidence is closed. Use these as the current source of truth:

```text
C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\findings\promoted\2026-05-06-r10-d3-native-linux-perf-baseline-captured.md
C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\tools\perf_baseline_linux.json
```

Observed Linux baseline JSON anchors:

```text
platform=linux_x86_64
version_locked_at=v0.8.323-rfc0063-phase1.3-linux-baseline
cold_self_build_seconds=9.05
cold_max_allowed_seconds=10.0
hot_self_build_seconds=0.47
hot_max_allowed_seconds=1.0
cold_peak_memory_mb=286
cold_max_allowed_memory_mb=350
hot_process_tree_peak_memory_mb=17
hot_max_allowed_memory_mb=64
```

Cloud agent may run `bash tools/check_perf_regression.sh --baseline tools/perf_baseline_linux.json` as a sanity check if convenient, but R10-D3 is not the remaining native blocker.

## PKG-1 Native Linux Signed Publish Proof

Current status: open. Windows helper work staged non-mutating dry-run/preflight paths, but native Linux still needs a real signed publish transcript against a throwaway registry/key.

Primary files:

```text
compiler/nucleor_tools_suite.nr
tools/native_release.ps1
tools/VERIFY_TIMING_RECIPE.md
docs/rfcs/v1_PUNCHLIST.md
docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md
findings/inbox/
```

Must not change:

```text
bin/
bootstrap/
tools/verify.sh
tools/verify.ps1
tools/check_compiler_drift.sh
```

Allowed changes if the proof exposes a small fix:

```text
compiler/nucleor_tools_suite.nr
tools/native_release.ps1
tools/VERIFY_TIMING_RECIPE.md
docs/rfcs/v1_PUNCHLIST.md
findings/inbox/<new-native-linux-transcript>.md
```

Preferred native Linux proof commands:

```bash
set -euo pipefail
git fetch origin --prune
git status --short --branch
uname -a
bash tools/bootstrap_linux.sh
test -x ./bin/nucleor
./bin/nucleor --version

./bin/nucleor build compiler/nucleor_s1_compiler.nr -o verify_compiler --no-cache
stage1=target/verify_compiler
test -x "$stage1"
"$stage1" build compiler/nucleor_s1_compiler.nr -o verify_compiler_2 --no-cache
stage2=target/verify_compiler_2
test -x "$stage2"
cmp -s "$stage1" "$stage2"

fixture="tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml"
tmpdir="$(mktemp -d)"
registry="$tmpdir/nucleor-registry"
key_id="throwaway-ci"

./bin/nucleor publish "$fixture" --registry "$registry" --dry-run --sign --key-id "$key_id"
test ! -e "$registry/foo/0.1.0/Nucleor.publish.signature.json"

./bin/nucleor release keygen "$key_id"
./bin/nucleor publish "$fixture" --registry "$registry" --sign --key-id "$key_id"
test -f "$registry/foo/0.1.0/Nucleor.publish.json"
test -f "$registry/foo/0.1.0/Nucleor.package.sha256"
test -f "$registry/foo/0.1.0/Nucleor.publish.signature.json"

pwsh -NoProfile -File tools/native_release.ps1 -Root . package-sign-preflight "$registry/foo/0.1.0" "$key_id" --json
pwsh -NoProfile -File tools/native_release.ps1 -Root . package-verify "$registry/foo/0.1.0" --json
git diff --check
```

Expected pass outputs:

- `bootstrap_linux.sh` leaves an executable `./bin/nucleor`.
- Stage1/stage2 self-host compile succeeds and `cmp -s` returns 0.
- Dry-run publish prints `publish dry-run: no files copied, no registry metadata written, no checksums written, no signatures created`.
- Dry-run does not create `$registry/foo/0.1.0/Nucleor.publish.signature.json`.
- Real throwaway publish writes:
  - `$registry/foo/0.1.0/Nucleor.toml`
  - `$registry/foo/0.1.0/Nucleor.publish.json`
  - `$registry/foo/0.1.0/Nucleor.package.sha256`
  - `$registry/foo/0.1.0/Nucleor.publish.signature.json`
- `package-sign-preflight` JSON reports the package, version, requested key id, and signature target without mutating.
- `package-verify` JSON accepts the signature roundtrip.
- `git diff --check` exits 0.

Expected fail-closed outputs:

- If native Linux `./bin/nucleor` is absent or not executable, stop after bootstrap evidence.
- If signing key creation is missing or broken, record the exact `release keygen` or publish failure.
- If dry-run creates registry files, request changes. That violates the v0831 dry-run contract.
- If real publish signs but verify rejects, request changes. The closure requires creation plus verification.
- If any command uses WSL-mounted Windows `.exe` evidence, reject it as not native POSIX proof.

## R06 Rust Bridge Native POSIX Ownership/Artifact Proof

Current status: open for native POSIX artifact and compiler evidence. Windows harness and POSIX fail-closed checks are staged.

Primary files:

```text
stdlib/rods/rust_bridge/src/lib.rs
stdlib/rods/rust_bridge.nr
tools/check_rust_bridge_ownership.ps1
tools/check_rust_bridge_ownership.sh
tests/features/rust_bridge_string_free_smoke.nr
tests/features/rust_bridge_string_free_repeat_smoke.nr
tests/features/rust_bridge_hash_determinism_smoke.nr
docs/ffi-conventions.md
tools/VERIFY_TIMING_RECIPE.md
findings/inbox/
```

Must not change:

```text
bin/
bootstrap/
tools/verify.sh
tools/verify.ps1
tools/check_compiler_drift.sh
```

Allowed changes if a real POSIX bug appears:

```text
stdlib/rods/rust_bridge/src/lib.rs
stdlib/rods/rust_bridge.nr
tools/check_rust_bridge_ownership.sh
tools/VERIFY_TIMING_RECIPE.md
findings/inbox/<new-r06-native-posix-transcript>.md
```

Native Linux proof commands:

```bash
set -euo pipefail
git fetch origin --prune
git status --short --branch
uname -a
command -v cargo
cargo --version
bash tools/bootstrap_linux.sh
test -x ./bin/nucleor
./bin/nucleor --version

bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --self-test
bash tools/check_rust_bridge_ownership.sh --doctor --json
bash tools/check_rust_bridge_ownership.sh --self-test --json
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 5 --json

test -f stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a
git diff --check
```

Optional stronger leak-signal pass if the host has ASAN or valgrind:

```bash
bash tools/check_rust_bridge_ownership.sh --fixture tests/features/rust_bridge_string_free_repeat_smoke.nr --iterations 100
```

Then run the produced executable under the available leak checker if the harness exposes a stable target path in the transcript.

Expected pass outputs:

- `--doctor` reports native POSIX cargo, POSIX bridge artifact, executable `bin/nucleor`, and focused fixtures ready.
- `--self-test` passes contract and fail-closed simulations.
- `--fixture all --iterations 20` builds and runs the string-free and hash-determinism fixtures.
- JSON modes parse and contain the same pass/fail state as text mode.
- `stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a` exists.
- No Windows `nucleor_rust_bridge.lib` or `bin/nucleor.exe` is accepted as POSIX proof.

Expected fail-closed outputs:

- `UNSUPPORTED rust_bridge ownership: found Windows cargo, not native POSIX cargo`.
- `doctor release-artifact: FAIL - POSIX artifact missing`.
- `doctor compiler-binary: FAIL - native POSIX compiler missing`.
- Missing fixture paths produce a hard failure, not a silent skip.

## Reporting Contract

Native cloud agent should leave one report under:

```text
findings/inbox/
```

The report must include:

```text
Branch:
HEAD:
Base:
Merge-base:
Host uname:
Compiler version:
PKG-1 commands and outputs:
R06 commands and outputs:
Files changed:
Files intentionally not changed:
Validation:
Remaining blockers:
```

Do not update R10-D3 status except to cite it as closed. Do not edit `bin/`, bootstrap scripts, or verify gates as part of this handoff unless the main agent explicitly opens that scope.
