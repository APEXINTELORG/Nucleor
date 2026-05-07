# Lane 8 / Queue 8B — Linux release prerequisite doctor

Date: 2026-05-07 (UTC)
Agent: cloud claude (Cloud_Control1.md punchlist)
Branch (harness-assigned): `claude/cloud-control-punchlist-bPLVn`
Punchlist-named branch: `fix/cloud-linux-release-prereq-doctor-v0845` (not used; same harness deviation as 8A)
Base: `origin/main` @ `5890c84603bd46fc6d86b9500b2ef7cd4ae4d63c`

## Host

```
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
```

## Tool versions

```
clang        = Ubuntu clang version 18.1.3 (1ubuntu1)   [/usr/bin/clang]
cargo        = 1.94.1 (29ea6fb6a 2026-03-24)            [/root/.cargo/bin/cargo]
rustc        = 1.94.1 (e408947bf 2026-03-25)
bash         = GNU bash 5.2.21(1)-release
pwsh         = (missing)
ssh-keygen   = (missing)
```

## Goal

Add a small shell/PowerShell doctor or docs section for the Linux release prerequisites: `pwsh`, `ssh-keygen`, `clang`, `cargo`, `bin/nucleor`, `bin/nucleor_tools`. No Python helper.

## Files added / changed

- `tools/release_doctor.sh` (new, executable, 100% POSIX shell — no Python).
  - Mirrors the doctor-line output convention of `tools/check_perf_regression.sh --doctor` for greppability (`doctor <name>: OK|FAIL|SKIP - <detail>`).
  - Probes (in order, all required): `native-linux`, `clang`, `cargo`, `pwsh`, `ssh-keygen`, `bin-nucleor` (ELF check via `file`), `bin-nucleor-tools` (ELF check via `file`).
  - Refuses WSL kernels (`is_wsl()` checks `/proc/sys/kernel/osrelease` and `/proc/version` for `microsoft|wsl`).
  - Refuses Windows `.exe` for binary probes.
  - Modes: default human, `--json` machine-readable (validated via `python3 -c json.load`), `--quiet` summary-only.
  - Exit codes match the perf doctor: `0` ready, `2` usage error, `96` unsupported (one or more required probes failed).
- `docs/process/semver-and-release.md` — new §3.0 "Linux release prerequisites" section pointing at the doctor, listing each probe with its purpose, and giving the typical Debian/Ubuntu install hints.

## Validation

### `bash tools/release_doctor.sh` — pre-build (no `bin/nucleor_tools` yet)

```
doctor native-linux: OK - kernel=Linux osrelease=6.18.5
doctor clang: OK - /usr/bin/clang — Ubuntu clang version 18.1.3 (1ubuntu1)
doctor cargo: OK - /root/.cargo/bin/cargo — cargo 1.94.1 (29ea6fb6a 2026-03-24)
doctor pwsh: FAIL - missing from PATH; install pwsh
doctor ssh-keygen: FAIL - missing from PATH; install openssh-client (ed25519 release signing relies on ssh-keygen -Y sign/verify)
doctor bin-nucleor: OK - bin/nucleor (...ELF 64-bit LSB pie executable, x86-64...)
doctor bin-nucleor-tools: FAIL - missing: bin/nucleor_tools (build via ./bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools and copy target/nucleor_tools to bin/)
doctor result: unsupported for native Linux release / publish flow (3 required probe(s) failed)
```

Exit code: 96.

### After building `bin/nucleor_tools`

```
$ ./bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools
  ...
  emitted: target/nucleor_tools.ll (7020252 bytes)
  compiled: target/nucleor_tools
$ cp target/nucleor_tools bin/nucleor_tools
$ file bin/nucleor_tools
bin/nucleor_tools: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked, ...
$ bash tools/release_doctor.sh
doctor native-linux: OK - ...
doctor clang: OK - ...
doctor cargo: OK - ...
doctor pwsh: FAIL - missing from PATH; install pwsh
doctor ssh-keygen: FAIL - missing from PATH; install openssh-client (ed25519 release signing relies on ssh-keygen -Y sign/verify)
doctor bin-nucleor: OK - bin/nucleor (...ELF...)
doctor bin-nucleor-tools: OK - bin/nucleor_tools (...ELF...)
doctor result: unsupported for native Linux release / publish flow (2 required probe(s) failed)
```

Exit code: 96. The `bin-nucleor-tools` probe correctly flipped from FAIL to OK after the build, and the failures now isolate the genuine missing OS-level prereqs on this runner.

### `--json`

JSON validates with `python3 -c "import sys, json; json.load(sys.stdin)"` (printed `valid JSON, probes: 7`). All 7 probes appear with `name`, `status`, `required`, `detail`. `result: "ready"` when zero required failures, otherwise `result: "unsupported"` plus `required_failures: <n>`.

### `--quiet`

Prints only the final summary line (`doctor result: ...`) plus the same exit code.

### Syntax

`bash -n tools/release_doctor.sh` clean.

## Rule compliance

- No Python in the doctor itself (`#!/usr/bin/env bash` + POSIX-friendly utilities only — `awk`, `grep`, `sed`, `cat`, `command -v`, `file`, `tr`, `head`).
- WSL/Wine/Windows-`.exe` evidence is rejected (WSL via `is_wsl`, `.exe` via case-glob in `probe_native_binary`).
- Pure additive change; no existing flow was rewired.

## Residuals

- This runner does not have `pwsh` or `ssh-keygen` installed; the doctor correctly reports them as missing. The rule from Cloud_Control1.md says "If a Linux prerequisite is missing, write a blocker naming the exact missing tool and the smallest docs/tooling patch needed". Both tools are addressed via the docs install-hints table in §3.0 of `docs/process/semver-and-release.md`. The doctor itself is the smallest tooling patch.
- Pre-existing PowerShell-only paths (`tools/native_release.ps1`, `tools/measure_peak_build.ps1`, etc.) are out of scope for 8B; the punchlist explicitly accepts a doctor-or-docs delivery and forbids Python rewrites. No POSIX `tools/native_release.sh` exists yet — referenced in `docs/rfcs/gap-analyses/Nucleor_Module_Packaging_Gap_Analysis_and_RFC_2026-05-04.md` as PKG-1 P2 future work.
- The doctor flags `pwsh` as a hard requirement (consistent with the existing release flow). If a future change makes `pwsh` optional (e.g., a POSIX `native_release.sh`), drop `pwsh` from `required` in `tools/release_doctor.sh`.
