# Helper2 v0828 - R06 Rust Bridge Ownership Harness

Date: 2026-05-06
Owner: helper2
Branch: `fix/helper2-r06-rust-bridge-ownership-harness-v0828`
Base: `origin/main` at `5ec86d7e4d965359348d33826553659157d16016`

## Summary

Added an opt-in PowerShell harness for R06 Phase 2 rust_bridge ownership
verification:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Iterations 100
```

The harness checks cargo, the `stdlib/rods/rust_bridge` crate, the expected
release bridge artifact, the compiler binary, and
`tests/features/rust_bridge_string_free_smoke.nr`. The normal run builds the
Rust bridge artifact when missing, builds the focused fixture, and repeatedly
runs the resulting executable. Each fixture run performs 100 Rust string
alloc/free cycles.

No compiler, `bin/`, bootstrap, `verify.sh`, `verify.ps1`, or perf-gate files
were edited.

## Repo State

```text
worktree: C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828
branch: fix/helper2-r06-rust-bridge-ownership-harness-v0828
base before helper2 commit: 5ec86d7e4d965359348d33826553659157d16016
origin/main: 5ec86d7e4d965359348d33826553659157d16016
merge-base before helper2 commit: 5ec86d7e4d965359348d33826553659157d16016
```

## Files Changed

```text
tools/check_rust_bridge_ownership.ps1
tools/check_rust_bridge_ownership.sh
tools/VERIFY_TIMING_RECIPE.md
docs/rfcs/v1_PUNCHLIST.md
tests/features/rust_bridge_string_free_repeat_smoke.nr
findings/inbox/helper2_r06_rust_bridge_ownership_harness_v0828_2026-05-06.md
```

Generated during validation but ignored by the repo:

```text
stdlib/rods/rust_bridge/Cargo.lock
stdlib/rods/rust_bridge/target/
target/_rust_bridge_ownership_check.exe
```

## Prerequisites Observed

```text
cargo: C:\Users\JoeWe\.cargo\bin\cargo.exe
compiler: C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\bin\nucleor.exe
bridge crate: C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge
bridge artifact after harness build: C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib
fixture: C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\tests\features\rust_bridge_string_free_smoke.nr
```

## Validation

```text
$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor
doctor cargo: OK - C:\Users\JoeWe\.cargo\bin\cargo.exe
doctor bridge-crate: OK - C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge
doctor release-artifact: OK - C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib
doctor compiler-binary: OK - C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\bin\nucleor.exe
doctor focused-fixture: OK - C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\tests\features\rust_bridge_string_free_smoke.nr
doctor fixture-buildable: OK - prerequisites are sufficient to build tests/features/rust_bridge_string_free_smoke.nr
doctor result: ready for rust_bridge ownership harness
exit=0

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Iterations 20
building focused fixture: tests/features/rust_bridge_string_free_smoke.nr
OK rust_bridge ownership: iterations=20 fixture_alloc_free_cycles=2000 bridge_artifact=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib executable=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\target\_rust_bridge_ownership_check.exe
exit=0

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Iterations 100
building focused fixture: tests/features/rust_bridge_string_free_smoke.nr
OK rust_bridge ownership: iterations=100 fixture_alloc_free_cycles=10000 bridge_artifact=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib executable=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\target\_rust_bridge_ownership_check.exe
exit=0

$ [System.Management.Automation.PSParser]::Tokenize(...)
PSParser OK

$ git diff --check
exit=0
```

## Continuation Scope B/C Results

The appended assignment queue was read from:

```text
C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\findings\_helper2_assignment_v0828_r06_rust_bridge_ownership_harness_2026-05-06.md
```

Scope B added `tools/check_rust_bridge_ownership.sh`. It mirrors the
PowerShell contract for POSIX hosts and refuses Windows interop artifacts as
POSIX evidence.

Scope C added `tests/features/rust_bridge_string_free_repeat_smoke.nr`, a
broader fixture covering all seven Rust string-returning functions:

```text
rust_regex_find
rust_regex_replace_all
rust_sort_ints
rust_sort_strings
rust_to_uppercase
rust_base64_encode
rust_base64_decode
```

Each repeat-fixture process run performs 700 Rust string alloc/free cycles.

Additional validation:

```text
$ bash -n tools/check_rust_bridge_ownership.sh
exit=0

$ bash tools/check_rust_bridge_ownership.sh --doctor
doctor cargo: FAIL - found Windows cargo, not native POSIX cargo: /mnt/c/Users/JoeWe/.cargo/bin/cargo.exe
doctor bridge-crate: OK - /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/stdlib/rods/rust_bridge
doctor release-artifact: FAIL - POSIX artifact missing; Windows artifact is not accepted: /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/stdlib/rods/rust_bridge/target/release/nucleor_rust_bridge.lib
doctor compiler-binary: FAIL - native POSIX compiler missing; Windows .exe is not accepted: /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/bin/nucleor.exe
doctor focused-fixture: OK - /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/tests/features/rust_bridge_string_free_smoke.nr
doctor fixture-buildable: FAIL - missing native POSIX cargo, compiler, bridge crate/artifact, or fixture
doctor result: not ready for POSIX rust_bridge ownership harness
exit=96

$ bash tools/check_rust_bridge_ownership.sh --fixture tests/features/rust_bridge_string_free_repeat_smoke.nr --iterations 20
UNSUPPORTED rust_bridge ownership: found Windows cargo, not native POSIX cargo: /mnt/c/Users/JoeWe/.cargo/bin/cargo.exe
exit=96

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Iterations 20
building focused fixture: tests/features/rust_bridge_string_free_smoke.nr
OK rust_bridge ownership: iterations=20 fixture_alloc_free_cycles=2000 bridge_artifact=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib executable=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\target\_rust_bridge_ownership_check.exe
exit=0

$ pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture tests\features\rust_bridge_string_free_repeat_smoke.nr -Iterations 100
building focused fixture: tests/features/rust_bridge_string_free_repeat_smoke.nr
OK rust_bridge ownership: iterations=100 fixture_alloc_free_cycles=70000 bridge_artifact=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib executable=C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\target\_rust_bridge_ownership_check.exe
exit=0

$ [System.Management.Automation.PSParser]::Tokenize(...)
PSParser OK

$ git diff --check
exit=0
```

`tools/VERIFY_TIMING_RECIPE.md` now includes a Windows/POSIX artifact matrix
and exact commands for both harnesses. `docs/rfcs/v1_PUNCHLIST.md` now records
R06 Phase 2 as branch-ready, with native POSIX compiler/artifact evidence and
external leak-signal evidence still open.

## R06 Phase 2 Remainder

This slice delivers the standalone, opt-in ownership harness and proves the
current Windows host can build and repeatedly run the rust_bridge
`rust_free_str` fixtures. It does not claim heap-leak absence from an external
allocator profiler or native POSIX closure. Remaining work is native
Linux/macOS evidence with native `cargo`, `bin/nucleor`, and
`libnucleor_rust_bridge.a`, plus an optional native leak-signal path such as
ASAN or valgrind if R06 Phase 2 requires allocator-profiler evidence rather
than repeated crash/hang-free ownership cycles.
