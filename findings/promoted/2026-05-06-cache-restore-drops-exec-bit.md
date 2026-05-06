# Native-link cache restore drops executable bit on Linux

**Date:** 2026-05-06
**Surfaced by:** RFC-0063 Phase 1.4 (commit `d298ee8`) — repeated `nuc build` of a Nucleor program ended up producing a non-executable artifact on cache hit.
**Status:** **CLOSED in v0.8.323** — root-caused to `__nucleor_fs_copy_file` not preserving source mode. Fixed by adding POSIX `stat`/`chmod` after the byte copy. Cache-hit `nuc build` now produces `-rwxr-xr-x` matching the fresh-build behavior. `chmod +x` workaround removed from `tools/check_compiler_drift.sh` in the same ship.

## Symptom

Fresh build (cache miss) produces an executable file:
```
$ rm -f target/gen_releases_index target/gen_releases_index.ll target/gen_releases_index.ll.cachekey
$ ./bin/nucleor build tools/gen_releases_index.nr -o gen_releases_index --no-cache
  compiled: target/gen_releases_index
$ ls -la target/gen_releases_index
-rwxr-xr-x  ... target/gen_releases_index    # executable bit set ✓
```

Cache-hit build (same source, second invocation) produces the same
binary content but **without** the executable bit:
```
$ ./bin/nucleor build tools/gen_releases_index.nr -o gen_releases_index
  cache: hit (sha=366e15965fa4, size 1 MB)
$ ls -la target/gen_releases_index
-rw-r--r--  ... target/gen_releases_index    # NO executable bit ✗
$ ./target/gen_releases_index
/bin/bash: line 1: ./target/gen_releases_index: Permission denied
```

The cache content is correct (byte-identical to the fresh build); only
the file mode is wrong.

## Root cause hypothesis

The native-link cache (content-addressed cache v2) likely stores the
compiled binary as a regular file (mode 0644) and restores via
`cp` / `fread` + `fwrite` without preserving / re-applying the
executable bit. On Windows the executable bit is implicit (anything
with `.exe` runs); on Linux the bit must be explicit (`chmod +x` or
`fchmod(S_IXUSR | ...)` after the write).

## Reproduction

```
$ ./bin/nucleor build tools/gen_releases_index.nr -o gen_releases_index --no-cache
$ ls -la target/gen_releases_index | grep -o '^...........'
-rwxr-xr-x

$ ./bin/nucleor build tools/gen_releases_index.nr -o gen_releases_index   # cache hit
$ ls -la target/gen_releases_index | grep -o '^...........'
-rw-r--r--
```

## Fix sketch

In the native-link cache restore path (likely in
`compiler/nucleor_s1_compiler.nr` near the v2 cache lookup logic):

```c
// After restoring the compiled binary from cache:
chmod(restored_path, 0755);  // owner rwx, others rx
```

Or in Nucleor-source equivalent — there's already a `chmod` helper or
file-mode primitive somewhere in the runtime; if not, add one (it's a
single libc call, ~5-line C function).

## Workaround in `tools/check_compiler_drift.sh`

The polyglot manifest dispatcher does `chmod +x` after every native
build to defend against cache-hit case (commit `d298ee8`):

```bash
"$NUCLEOR_BIN" build "$gen_path" -o "$gen_basename" >/dev/null 2>&1 || ...
chmod +x "$ROOT/target/$gen_basename" 2>/dev/null
```

This costs nothing on a fresh build (file already +x) and silently
fixes the cache-hit case.

## Severity

**Medium.** Doesn't affect `bin/nucleor` itself (which is built with
`bash tools/bootstrap_linux.sh`, not via the `nuc build` cache).
Affects every adopter who builds a Nucleor program twice on Linux —
the second invocation produces a "broken" artifact that can't run.

## Cross-references

- Sister bug from same investigation:
  `2026-05-06-nuc-run-linux-path-construction.md` (Windows backslash
  in `nuc run` exec path).
- RFC-0063 Phase 5 (hermetic toolchain) — bears on the experience of
  adopters running native Nucleor tools.
- v0.5-track-l-perf-cache (`tools/perf_baseline.json` history entry):
  introduced the content-addressed cache v2 — likely where the
  executable-bit handling was missed.
