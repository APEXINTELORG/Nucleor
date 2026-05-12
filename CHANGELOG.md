# Changelog

All notable public changes to Nucleor are documented here.

## [1.1.0] - 2026-05-12

### Added

- Linux bootstrap path from `bootstrap/nucleor_s1_seed.ll` through
  `tools/bootstrap_linux.sh`.
- Cross-platform self-host fixed-point check through
  `tools/check_self_host_md5.sh`.
- Compiler-only and process-tree RSS performance accounting for release gates.
- Public CLI maturity specification in `docs/spec/Nucleor_CLI_Maturity_Spec_2026-05-10.md`.

### Changed

- Promoted the v1 audit-closure line into the public v1.1.0 release surface.
- Recovered the ownership-analysis cold path to the v1.0-era performance range
  while preserving the audit safety checks.
- Cached the precompiled runtime object where supported to reduce repeated
  native-link overhead.
- Cleaned the public documentation set so it no longer carries development
  coordination files.

### Fixed

- Windows `bin/nucleor.exe` and tools-suite version labels now report
  `nucleor 1.1.0 (self-hosted, llvm backend)`.
- The v1.0.3 substring regression fix is included: default substring bounds no
  longer pay an input-length scan on the compiler hot path.
- Windows strict cold compile remains under the release budget:
  cold `3.95s`, hot `0.12s`, compiler RSS `352 MB` under the `360 MB` cap.
- Local Windows full verifier evidence: `PASS=1653`, `SKIP=9`, `FAIL=0`.
- Hosted Linux correctness evidence: bootstrap, self-host md5, full
  `verify.sh`, and rust_bridge ownership harness green on Ubuntu 24.04 with
  LLVM 18.

### Known Scope

- macOS is not a release-gated platform for v1.1.0.
- Hosted GitHub runners are correctness runners, not performance-baseline
  locking hosts.
- The CLI is functional but still has a documented maturity roadmap covering
  installer behavior, REPL mode, command inventory parity, and machine-readable
  command output.

## [1.0.0] - 2026-05-08

Initial v1 public line:

- Self-hosted compiler with LLVM backend.
- RFC-0062 memory-safety and effects gate closure.
- Standard library rods for systems, numerics, robotics, quantum, ML-oriented
  helpers, codecs, and FFI surfaces.
- Windows bootstrap binary and portable bootstrap seed.

## [1.0.2] - 2026-05-09

Internal stabilization tag on the v1.0 line. Superseded by v1.1.0 for public
release use.

## [1.0.1] - 2026-05-08

Internal stabilization tag on the v1.0 line. Superseded by v1.1.0 for public
release use.
