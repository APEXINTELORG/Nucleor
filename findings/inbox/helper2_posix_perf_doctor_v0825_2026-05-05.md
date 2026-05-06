# Helper2 v0825 - POSIX Perf Doctor Mode

Date: 2026-05-05
Owner: helper2
Branch: `fix/helper2-posix-perf-doctor-v0825`
Base: `origin/main` at `5abcaa240cdf8546378cdf1bf116d71106516515`

## Summary

Added `bash tools/check_perf_regression.sh --doctor` as a preflight-only
readiness mode for the R10-D3 POSIX perf/RSS gate. It prints concise status
lines for native Linux readiness, `/proc`, shell tools, `clang`,
`tools/run_capped.sh`, baseline/source files, native `bin/nucleor`, and ELF
proof when `file` is available.

The normal perf measurement path remains unchanged: WSL is still refused,
thresholds/sample counts/RSS budgets are unchanged, and `tools/verify.sh`
continues to map standalone exit `96` to an explicit `SKIP`.

## Repo State

```text
worktree: C:\Users\JoeWe\Nucleor_OSS_helper2_posix_perf_doctor_v0825
branch: fix/helper2-posix-perf-doctor-v0825
base before helper2 commit: 5abcaa240cdf8546378cdf1bf116d71106516515
origin/main: 5abcaa240cdf8546378cdf1bf116d71106516515
merge-base before helper2 commit: 5abcaa240cdf8546378cdf1bf116d71106516515
```

## Host Type

```text
$ uname -a
Linux Larry 6.6.87.2-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Thu Jun  5 18:30:46 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux

$ cat /proc/sys/kernel/osrelease
6.6.87.2-microsoft-standard-WSL2

$ command -v clang || true
<no output>

$ file bin/nucleor bin/nucleor.exe
bin/nucleor:     cannot open `bin/nucleor' (No such file or directory)
bin/nucleor.exe: PE32+ executable (console) x86-64, for MS Windows, 9 sections
```

This host is WSL2, has no `clang` on PATH, and has only the Windows
`bin/nucleor.exe`; it is not a valid native Linux POSIX perf/RSS evidence
runner.

## Doctor Output

Command:

```bash
bash tools/check_perf_regression.sh --doctor
```

Output summary:

```text
doctor native-linux: FAIL - WSL kernel is shell-check only for this gate osrelease=6.6.87.2-microsoft-standard-WSL2
doctor linux-proc: OK - /proc is present
doctor required-shell-tools: OK - awk grep sed sort date mktemp rm tail bash setsid
doctor clang: FAIL - missing from PATH
doctor run-capped: OK - /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_posix_perf_doctor_v0825/tools/run_capped.sh
doctor baseline-and-source: OK - baseline=/mnt/c/Users/JoeWe/Nucleor_OSS_helper2_posix_perf_doctor_v0825/tools/perf_baseline.json source=/mnt/c/Users/JoeWe/Nucleor_OSS_helper2_posix_perf_doctor_v0825/compiler/nucleor_s1_compiler.nr
doctor native-executable: FAIL - native /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_posix_perf_doctor_v0825/bin/nucleor is missing or not executable; bin/nucleor.exe is Windows-only
doctor elf-proof: FAIL - cannot inspect missing binary: /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_posix_perf_doctor_v0825/bin/nucleor
doctor result: unsupported for native POSIX perf evidence
exit=96
```

## Validation

```text
$ bash -n tools/check_perf_regression.sh
exit=0

$ bash tools/check_perf_regression.sh --help
exit=0
help includes: --doctor              Print native POSIX perf readiness checks, then exit

$ bash tools/check_perf_regression.sh --doctor
exit=96
result: unsupported for native POSIX perf evidence

$ bash tools/check_perf_regression.sh --verbose
exit=96
UNSUPPORTED POSIX perf: WSL is shell-check only for this gate; use a native Linux runner for R10-D3 perf/RSS evidence

$ NO_COLOR=1 bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"
[ 60/1120] SKIP  T1.8 POSIX perf + memory regression monitor  (  0.02s)
PASS: 0
SKIP: 278
exit=0

$ git diff --check
exit=0
```

## R10-D3 Status

R10-D3 remains blocked on this machine because the host is WSL2 and lacks a
native Linux `bin/nucleor` ELF plus `clang`. The new doctor mode makes those
blockers explicit before a runner attempts cold/hot POSIX samples. R10-D3 can
only close after a true native Linux runner reports `--doctor` exit `0` and
records the real cold/hot/RSS perf transcript.
