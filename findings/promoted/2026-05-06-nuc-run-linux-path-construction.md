# `nuc run` uses Windows-style path on Linux

**Date:** 2026-05-06
**Surfaced by:** RFC-0063 Phase 1.4 (commit `d298ee8`) — when wiring the native gen_releases_index.nr port into `tools/check_compiler_drift.sh`, the natural `nuc run <file>` invocation failed on Linux.
**Status:** **CLOSED in v0.8.323** — `compiler/nucleor_s1_compiler.nr` `nuc run` dispatch now reads `host_is_windows() ? "target\\" : "./target/"` for the exe directory and uses `host_exe_suffix()` (which returns `.exe` on Windows, `""` on POSIX). Verified `./bin/nucleor run examples/01_hello.nr` prints `Hello, Nucleor!` on Linux.

## Symptom

```
$ ./bin/nucleor run tools/gen_releases_index.nr
cache: hit (sha=366e15965fa4, size 1 MB)
  emitted: target/gen_releases_index.ll (113191 bytes)
  native link: cache hit (sha=8a02c168582b)
sh: 1: targetgen_releases_index.exe: not found
nuc run: child exited rc=32512 from target\gen_releases_index.exe
```

`nuc run` constructs the executable path as `target\gen_releases_index.exe`:
- backslash separator (Windows convention; Linux uses forward slash)
- `.exe` suffix (Windows convention; Linux executables have no extension)

The shell sees the backslash as a line-continuation, collapses
`target\gen_releases_index.exe` into the literal token
`targetgen_releases_index.exe`, then fails to exec it.

`nuc build` (the underlying compile step) works correctly on Linux —
it produces `target/gen_releases_index` (forward slash, no extension).
The bug is purely in how `nuc run` constructs the path it then hands
to `system()` / spawn.

## Root cause hypothesis

Somewhere in `nuc run` dispatch (in `compiler/nucleor_s1_compiler.nr`),
the executable path is constructed with hardcoded `\` and `.exe`,
likely from a Windows-first ship that wasn't generalized when the
Linux bootstrap landed.

Workaround in code that needs to invoke a freshly-built Nucleor
program on Linux: do `nuc build` + execute `./target/<name>` directly
(see `tools/check_compiler_drift.sh:case ".nr"` for the working pattern).

## Reproduction

```
$ ./bin/nucleor build examples/01_hello.nr -o hello   # OK
$ ./bin/nucleor run examples/01_hello.nr               # FAIL
sh: 1: targethello.exe: not found
nuc run: child exited rc=32512 from target\hello.exe
```

## Fix sketch

In the `nuc run` dispatch:

```nucleor
let sep: str = if host_is_windows() == 1 { "\\" } else { "/" };
let suffix: str = if host_is_windows() == 1 { ".exe" } else { "" };
let exe_path: str = str_concat("target", str_concat(sep, str_concat(out_name, suffix)));
```

Or read the resolved exe path from the compile result rather than
re-constructing it. The compile step itself prints
`compiled: target/gen_releases_index` (correct Linux path) — there's
authoritative information on disk that `run` can reuse.

## Cross-references

- `tools/check_compiler_drift.sh` (commit `d298ee8`): worked around
  by doing `bin/nucleor build` + direct executable invocation, with a
  comment pointing at this finding.
- Sister bug surfaced same investigation:
  `2026-05-06-cache-restore-drops-exec-bit.md` — different platform
  layer issue (cache hit drops chmod +x).
- RFC-0063 Phase 5 (hermetic toolchain) — the dev-time generator
  ports rely on `nuc build + exec` until this is fixed; once fixed,
  drift gate can simplify to `nuc run`.
