# Helper2 v0829 - R06 rust_bridge harness contract closure

Date: 2026-05-06
Owner: helper2
Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
Branch: `fix/helper2-r06-rust-bridge-ownership-harness-v0828`
Queue start commit: `c003119bc1bd9e23ccc91d31d9aa6d492c79a995`
Base / merge-base checked before edits: `5ec86d7e4d965359348d33826553659157d16016`

## Scope Result

Queue 2 stayed inside the opt-in Rust bridge harness lane. No compiler,
`bin/`, `bootstrap/`, normal verify/perf gate, vendored dependency, runtime
ABI, or Python-helper edits were made.

Completed scopes:

```text
Scope F: DONE - no-build self-test mode for PowerShell and POSIX harnesses.
Scope G: DONE - test-only fail-closed prerequisite simulations.
Scope H: DONE - punchlist, timing recipe, and release closure report.
Scope I: DONE - JSON field set and stability transcript.
Scope J: DONE - future CI allowlist/denylist review.
Scope K: DONE - residual blocker reduction table.
```

Files changed:

```text
tools/check_rust_bridge_ownership.ps1
tools/check_rust_bridge_ownership.sh
tools/VERIFY_TIMING_RECIPE.md
docs/rfcs/v1_PUNCHLIST.md
findings/inbox/helper2_r06_rust_bridge_harness_contract_v0829_2026-05-06.md
```

## Harness Additions

PowerShell:

```text
-SelfTest
-SimulateMissing cargo|compiler|bridge-artifact|none
```

POSIX:

```text
--self-test
--simulate-missing cargo|compiler|bridge-artifact|none
```

Self-test does not run Cargo, compile Nucleor, build fixtures, or require a
bridge artifact. It validates supported selectors, invalid-selector failure,
JSON contract keys, and fail-closed prerequisite simulation for cargo,
compiler, and bridge artifact.

The simulation hook is test-only. It does not mutate `PATH`, rename the real
compiler, rename bridge artifacts, or install/uninstall tools.

## Validation Transcript

```text
$ [System.Management.Automation.PSParser]::Tokenize(...)
PSParser OK

$ bash -n tools/check_rust_bridge_ownership.sh
bash -n OK

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -SelfTest
self-test selector:string-free: OK
self-test selector:hash: OK
self-test selector:all: OK
self-test selector:invalid: OK
self-test json:required-keys: OK
self-test fail-closed:cargo: OK
self-test json:fail-closed:cargo: OK
self-test fail-closed:compiler: OK
self-test json:fail-closed:compiler: OK
self-test fail-closed:bridge-artifact: OK
self-test json:fail-closed:bridge-artifact: OK
self-test result: passed
exit=0

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -SelfTest -Json | ConvertFrom-Json
exit=0 status=passed mode=self-test checks=11

$ bash tools/check_rust_bridge_ownership.sh --self-test
self-test selector:string-free: OK
self-test selector:hash: OK
self-test selector:all: OK
self-test selector:invalid: OK
self-test json:required-keys: OK
self-test fail-closed:cargo: OK
self-test json:fail-closed:cargo: OK
self-test fail-closed:compiler: OK
self-test json:fail-closed:compiler: OK
self-test fail-closed:bridge-artifact: OK
self-test json:fail-closed:bridge-artifact: OK
self-test result: passed
exit=0

$ bash tools/check_rust_bridge_ownership.sh --self-test --json | ConvertFrom-Json
exit=0 status=passed mode=self-test checks=11

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor -Json | ConvertFrom-Json
exit=0 status=ready mode=doctor fixture=string-free cargo=True

$ bash tools/check_rust_bridge_ownership.sh --doctor --json | ConvertFrom-Json
exit=96 status=unsupported mode=doctor reason=found Windows cargo, not native POSIX cargo: /mnt/c/Users/JoeWe/.cargo/bin/cargo.exe

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture all -Iterations 5
building focused fixture: tests/features/rust_bridge_string_free_smoke.nr
building focused fixture: tests/features/rust_bridge_hash_determinism_smoke.nr
OK rust_bridge ownership: fixture_selector=all iterations=5 fixture_executions=10 fixture_alloc_free_cycles=510 bridge_artifact=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib executable=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\target\_rust_bridge_ownership_check.exe
exit=0

$ git diff --check
warning: in the working copy of 'tools/check_rust_bridge_ownership.ps1', LF will be replaced by CRLF the next time Git touches it
exit=0
```

Focused simulation checks:

```text
$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor -Json -SimulateMissing cargo | ConvertFrom-Json
exit=96 status=unsupported reason=simulated missing cargo

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Json -SimulateMissing compiler | ConvertFrom-Json
exit=96 status=unsupported reason=simulated missing compiler

$ bash tools/check_rust_bridge_ownership.sh --doctor --json --simulate-missing bridge-artifact | ConvertFrom-Json
exit=96 status=unsupported reason=simulated missing bridge artifact

$ bash tools/check_rust_bridge_ownership.sh --json --simulate-missing compiler | ConvertFrom-Json
exit=96 status=unsupported reason=simulated missing compiler
```

Invalid selector checks:

```text
$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture invalidSelector
ERROR rust_bridge ownership: invalid fixture selector 'invalidSelector'; expected string-free, hash, all, string-free-repeat, or an explicit .nr fixture path
exit=2

$ bash tools/check_rust_bridge_ownership.sh --fixture invalidSelector
ERROR rust_bridge ownership: invalid fixture selector 'invalidSelector'; expected string-free, hash, all, string-free-repeat, or an explicit .nr fixture path
exit=2
```

## JSON Contract

Stable top-level field set:

```text
schema_version
host_family
mode
fixture_selector
iterations_requested
fixture_executions_completed
cargo
bridge_artifact
compiler
result_status
failure_reason
fixtures
simulated_missing
self_test_checks
```

Stable nested readiness field set:

```text
cargo.present
cargo.path
bridge_artifact.present
bridge_artifact.path
compiler.present
compiler.path
fixtures[].key
fixtures[].path
fixtures[].present
fixtures[].rust_owned_free_cycles_per_execution
```

POSIX additionally includes `cargo.native`.

No timestamps, random IDs, temp paths, or host-specific ordering were added.
Future CI should compare the field set, enum/status values, fixture keys, and
cycle counts. CI should ignore or normalize the host-specific path values:
`cargo.path`, `bridge_artifact.path`, `compiler.path`, and `fixtures[].path`.

## JSON Examples

Windows doctor JSON:

```json
{
  "schema_version": 1,
  "host_family": "windows",
  "mode": "doctor",
  "fixture_selector": "string-free",
  "iterations_requested": 100,
  "fixture_executions_completed": 0,
  "cargo": {
    "present": true,
    "path": "C:\\Users\\JoeWe\\.cargo\\bin\\cargo.exe"
  },
  "bridge_artifact": {
    "present": true,
    "path": "C:\\Users\\JoeWe\\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\\stdlib\\rods\\rust_bridge\\target\\release\\nucleor_rust_bridge.lib"
  },
  "compiler": {
    "present": true,
    "path": "C:\\Users\\JoeWe\\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\\bin\\nucleor.exe"
  },
  "result_status": "ready",
  "failure_reason": "",
  "fixtures": [
    {
      "key": "string-free",
      "path": "C:\\Users\\JoeWe\\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\\tests\\features\\rust_bridge_string_free_smoke.nr",
      "present": true,
      "rust_owned_free_cycles_per_execution": 100
    }
  ],
  "simulated_missing": "none",
  "self_test_checks": []
}
```

Windows run JSON:

```json
{
  "schema_version": 1,
  "host_family": "windows",
  "mode": "run",
  "fixture_selector": "string-free",
  "iterations_requested": 1,
  "fixture_executions_completed": 1,
  "result_status": "passed",
  "failure_reason": "",
  "simulated_missing": "none"
}
```

POSIX fail-closed run JSON on this WSL/Windows host:

```json
{
  "schema_version": 1,
  "host_family": "posix",
  "mode": "run",
  "fixture_selector": "string-free",
  "iterations_requested": 1,
  "fixture_executions_completed": 0,
  "cargo": {
    "present": true,
    "native": false,
    "path": "/mnt/c/Users/JoeWe/.cargo/bin/cargo.exe"
  },
  "bridge_artifact": {
    "present": false,
    "path": "/mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a"
  },
  "compiler": {
    "present": false,
    "path": "/mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/bin/nucleor"
  },
  "result_status": "unsupported",
  "failure_reason": "found Windows cargo, not native POSIX cargo: /mnt/c/Users/JoeWe/.cargo/bin/cargo.exe",
  "simulated_missing": "none"
}
```

POSIX self-test JSON has the same field set and records `11` completed
self-test checks. It passes even though native POSIX cargo/compiler/artifacts
are unavailable because self-test intentionally does not build or run fixtures.

## Inventory

Rust bridge ownership and deterministic-hash surfaces found by inventory:

```text
stdlib/rods/rust.nr
stdlib/rods/rust_bridge/src/lib.rs
tests/features/rust_bridge_string_free_smoke.nr
tests/features/rust_bridge_string_free_repeat_smoke.nr
tests/features/rust_bridge_hash_determinism_smoke.nr
tests/features/rust_bridge_hash_deterministic.nr
tests/rods/rust_interop.nr
tools/check_rust_bridge_ownership.ps1
tools/check_rust_bridge_ownership.sh
tools/VERIFY_TIMING_RECIPE.md
docs/rfcs/v1_PUNCHLIST.md
docs/rfcs/gap-analyses/Nucleor_Interop_FFI_Gap_Analysis_and_RFC_2026-05-04.md
docs/getting-started.md
docs/rods-and-runtime.md
docs/milestones/v0.2.0.md
```

## Future CI Allowlist / Denylist

Safe to consider for default CI:

```text
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -SelfTest
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -SelfTest -Json
bash -n tools/check_rust_bridge_ownership.sh
bash tools/check_rust_bridge_ownership.sh --self-test
bash tools/check_rust_bridge_ownership.sh --self-test --json
```

Safe as platform-specific readiness checks, but should not be treated as
ownership-run evidence by themselves:

```text
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor -Json
bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --doctor --json
```

Keep opt-in because they require Cargo, built bridge libs, and compiler
artifacts:

```text
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture all -Iterations 20
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture string-free-repeat -Iterations 100
bash tools/check_rust_bridge_ownership.sh --fixture string-free-repeat --iterations 100
```

Keep out of default gates until the owning implementation work lands:

```text
native POSIX leak-profiler runs such as ASAN or valgrind
Python/shared-library cross-boundary ownership checks
Rust bridge ABI/runtime changes
vendored Rust dependency changes
normal verify/perf gate wiring for rust_bridge ownership
```

## Residual Blocker Reduction Table

| Blocker id | Current evidence | Smallest code surface needed | Expected validation | Class |
|---|---|---|---|---|
| R06-B1 bridge artifact discovery | Windows `.lib` discovered; POSIX `.a` is fail-closed on this WSL host. | Native POSIX runner with native `cargo`, native `bin/nucleor`, and `libnucleor_rust_bridge.a`. | `bash tools/check_rust_bridge_ownership.sh --doctor --json`; `bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20 --json`. | CI / Rust crate |
| R06-B2 Rust-owned string/free ownership contract | Fixtures cover default string-free path and all seven string-returning bridge functions. | Optional native allocator/leak profiler wrapper if closure requires leak evidence beyond repeated run success. | Windows harness already passes; native `valgrind` or ASAN run remains separate. | Rust crate / CI |
| R06-B3 deterministic hash/string-return coverage | `rust_hash_string_fnv1a` is covered by `tests/features/rust_bridge_hash_determinism_smoke.nr`; owned strings in that fixture are freed. | None for harness scope; broader adoption may need docs on replacing randomized `rust_hash_string`. | `pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture hash -Iterations 20`. | Docs / tests |
| R06-B4 JSON output stability | Stable field set recorded; no timestamps or random IDs. | Future CI should normalize path fields before comparing JSON. | `pwsh ... -SelfTest -Json | ConvertFrom-Json`; `bash ... --self-test --json`. | Tools / CI |
| R06-B5 fail-closed prerequisite behavior | Self-test covers missing cargo/compiler/artifact; explicit simulation checks return `96` with failure reason. | None for harness scope. | `-SimulateMissing cargo`; `--simulate-missing compiler`; `--simulate-missing bridge-artifact`. | Tools |
| R06-B6 future CI gating boundary | Allowlist/denylist defined; no normal verify/perf wiring added. | Mainline owner chooses whether self-test-only belongs in normal verify. | Keep full fixture runs opt-in until platform prerequisites are guaranteed. | CI / docs |
| R06-B7 broader cross-boundary FFI ownership | rust_bridge path improved; gap RFC still names Python/shared-library ownership as broader unresolved issue. | Separate runtime/ABI design for Python and shared-library FFI free hooks. | Future fixtures under separate R06 lane; not this harness. | Runtime ABI |

## Remaining R06 Work

The helper2 harness lane is branch-ready for review. Remaining R06 work is not
blocked by this branch, but it is outside this worktree's available evidence:

```text
native POSIX proof with native cargo, bin/nucleor, and libnucleor_rust_bridge.a
optional ASAN/valgrind-style leak evidence
broader Python/shared-library FFI ownership contract
mainline decision on whether self-test-only checks belong in normal verify
```
