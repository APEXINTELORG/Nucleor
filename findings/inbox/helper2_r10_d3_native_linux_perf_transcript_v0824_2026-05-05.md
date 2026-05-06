# Helper2 R10-D3 Native Linux Perf Transcript v0824

Date: 2026-05-05
Owner: helper2
Branch: `probe/helper2-r10-d3-native-linux-perf-transcript-v0824`
Base: `origin/main` at `409175e63a59e70248a7085502858661d66f45f1`

## Summary

R10-D3 cannot close from this machine. The available shell is WSL2, not native
Linux, there is no native ELF `bin/nucleor`, and the POSIX perf gate correctly
refuses to treat WSL as valid POSIX RSS/perf evidence.

No perf thresholds were changed. No native Linux closure claim is made.

## Base and Branch

```text
worktree: C:\Users\JoeWe\Nucleor_OSS_helper2_native_linux_perf_transcript_v0824
branch: probe/helper2-r10-d3-native-linux-perf-transcript-v0824
merge-base HEAD origin/main: 409175e63a59e70248a7085502858661d66f45f1
```

This branch was created fresh from current `origin/main`; no v0822 base or
prior helper branch was reused. It was later rebased onto
`409175e63a59e70248a7085502858661d66f45f1` after `origin/main` advanced.

## Host Proof

```bash
uname -a
```

```text
Linux Larry 6.6.87.2-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Thu Jun  5 18:30:46 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux
```

```bash
cat /proc/sys/kernel/osrelease
```

```text
6.6.87.2-microsoft-standard-WSL2
```

This is WSL2. Per the R10-D3 contract, WSL is shell-check-only evidence and
cannot prove native POSIX process-tree RSS or cold/hot timing.

## Native Compiler Proof

```bash
command -v clang || true
```

Result: no output; `clang` is not on the Linux PATH.

```bash
file bin/nucleor bin/nucleor.exe 2>/dev/null || true
```

```text
bin/nucleor:     cannot open `bin/nucleor' (No such file or directory)
bin/nucleor.exe: PE32+ executable (console) x86-64, for MS Windows, 9 sections
```

There is no native ELF `bin/nucleor` available in this worktree. The checked-in
compiler binary is the Windows PE executable, which is invalid for POSIX RSS
evidence.

## Commands Run

```bash
bash tools/check_perf_regression.sh --verbose
```

```text
UNSUPPORTED POSIX perf: WSL is shell-check only for this gate; use a native Linux runner for R10-D3 perf/RSS evidence
exit=96
```

```bash
bash tools/bootstrap_linux.sh --seed-only
```

```text
bootstrap_linux: clang not found on PATH
                 install LLVM 18 (sudo apt install clang-18 / brew install llvm@18)
exit=1
```

```bash
NO_COLOR=1 bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"
```

Key lines:

```text
       UNSUPPORTED POSIX perf: WSL is shell-check only for this gate; use a native Linux runner for R10-D3 perf/RSS evidence
[ 59/1114] SKIP  T1.8 POSIX perf + memory regression monitor  (  0.02s)
PASS: 0
SKIP: 277
exit=0
```

## Perf Transcript

No native perf transcript exists from this host. The standalone POSIX perf gate
refused to run with exit `96`, which is the correct unsupported-host behavior.

## Verify Selector Transcript

The focused verify selector does not claim pass evidence. It maps the
unsupported POSIX perf host to an explicit `SKIP`, preserving the no-false-green
contract.

```text
[ 59/1114] SKIP  T1.8 POSIX perf + memory regression monitor  (  0.02s)
PASS: 0
SKIP: 277
exit=0
```

## Whether R10-D3 Can Close

R10-D3 cannot close from this environment.

Required closure evidence still needs a true native Linux runner with:

- non-WSL Linux kernel,
- Linux `clang`/LLVM toolchain,
- native ELF `bin/nucleor`,
- `bash tools/check_perf_regression.sh --verbose` passing,
- `bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"`
  reporting the perf step as `OK`, not `SKIP`.

## Remaining Blocker

The blocker is environmental, not a repo script failure:

- host is WSL2 (`microsoft-standard-WSL2`),
- no Linux `clang` on PATH,
- no native ELF `bin/nucleor`,
- POSIX perf gate correctly exits `96` unsupported.

The next run must happen on a true native Linux machine or CI runner.
