# Changelog

All notable public changes to Nucleor are documented here.

## [1.1.1] - unreleased

**Closure capture correctness + per-iteration drop emission.**

### Fixed

- Closure captures are now per-closure-instance, not per-literal. Two
  closures produced from the same literal (e.g. via a factory fn)
  carry independent captures and can be called in any order with
  correct results. Pre-fix, the global capture table keyed only by
  the literal's lex-time id meant every subsequent call to the
  factory stomped the prior closure's captures. See
  `tests/lang/closure_capture_*.nr` for the regression fixtures and
  `docs/internals/closures.md` for the implementation.

### Changed

- Closure values are now tagged i64 pointers (`env_ptr | 1`) rather
  than bare function pointers. The i64-everywhere ABI is preserved;
  indirect call sites dispatch on the low bit to handle both bare
  fn-ptrs and closures. Existing user code is unaffected.
- C runtime helpers that accept a `fn_ptr` argument
  (`vec_map_i64`, `vec_filter_i64`, `vec_fold_i64`, etc.;
  `thread_spawn`, `async_spawn`) now dispatch through tag-aware
  inline helpers. Accepts both bare fn-ptrs and boxed closure values
  transparently.

### Known Limitations

- Owned values (Vec, HashMap, str, Closure) declared inside a
  `while` / `for` loop body are not released until the enclosing
  function returns. RSS grows linearly with iteration count for
  such patterns. The conservative fix (emit drops at end of body)
  was attempted but reverted because the auto-drop framework's
  handoff tracker only recognizes built-in `vec_push` / `vec_set`
  / `hashmap_insert` / `node_add` and misses user-defined fns that
  take ownership (e.g. `json_array_push(arr, elem)`). Proper
  per-iteration drops require either a wider handoff tracker or
  escape analysis. Tracked separately as `fix/loop-iter-drops`.

### Deprecated

- `__nucleor_capture_set` / `__nucleor_capture_get` and the
  associated `g_capture_table` static buffer are retained as
  compatibility shims but no longer emitted by the codegen. Slated
  for removal in a future release.

## [1.1.0] - 2026-05-12

**Linux bootstrap, release verification, Windows perf gate, and public-doc cleanup.**

### Added

- Linux bootstrap path from `bootstrap/nucleor_s1_seed.ll` through
  `tools/bootstrap_linux.sh`.
- Cross-platform self-host fixed-point check through
  `tools/check_self_host_md5.sh`.
- Compiler-only and process-tree RSS performance accounting for release gates.
- Public CLI maturity specification in `docs/spec/Nucleor_CLI_Maturity_Spec_2026-05-10.md`.
- Public `SAFETY.md` covering robotics, hardware-control, real-time, untrusted
  code, and release-artifact safety boundaries.

### Changed

- Promoted the v1 safety-hardening line into the public v1.1.0 release surface.
- Recovered the ownership-analysis cold path to the v1 performance range while
  preserving the safety checks.
- Cached the precompiled runtime object where supported to reduce repeated
  native-link overhead.
- Cleaned the public documentation set so it no longer carries development
  coordination files.

### Fixed

- Windows `bin/nucleor.exe` and tools-suite version labels now report
  `nucleor 1.1.0 (self-hosted, llvm backend)`.
- The substring hot-path regression fix is included: default substring bounds
  no longer pay an input-length scan on the compiler hot path.
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
- Robotics, control, and real-time features are not safety-certified; users
  integrating with physical systems must follow `SAFETY.md`.
- `@law(...)` is **scaffolded, not active**. Lex-time capture and
  diagnostic surfacing work; user-law-driven call-site rewrites,
  generated property tests, and proof obligations are roadmap work
  (`docs/architecture.md:91-95`). Treat `@law` as documentation and
  checker metadata until the rewrite pass lands.
- Const-generic dimensions for scientific types (`Matrix<R, C>`,
  `QState<N>`, `f64<Unit>`) are not yet in the language. The
  typed-newtype-wrapper pattern (`examples/30_typed_matrix.nr`,
  `docs/internals/typed-wrappers.md`) is the current best practice;
  shape and unit checks remain runtime, not compile-time.
- Module-level `pub`/private granularity (RFC-0018) is partial — some
  cross-module helpers need lifting to `pub` on the file-split branch.
  No ABI risk; cosmetic visibility surface only.

## [1.0.0] - 2026-05-08

**Initial v1 line: self-hosted compiler, LLVM backend, Windows bootstrap, and portable bootstrap seed.**

Initial v1 public line:

- Self-hosted compiler with LLVM backend.
- Memory-safety and effects diagnostics promoted to release gates.
- Standard library rods for systems, numerics, robotics, quantum, ML-oriented
  helpers, codecs, and FFI surfaces.
- Windows bootstrap binary and portable bootstrap seed.

## [1.0.2] - 2026-05-09

**Maintenance tag on the v1.0 line. Superseded by v1.1.0 for new installs.**

Maintenance tag on the v1.0 line. Superseded by v1.1.0 for new installs.

## [1.0.1] - 2026-05-08

**Maintenance tag on the v1.0 line. Superseded by v1.1.0 for new installs.**

Maintenance tag on the v1.0 line. Superseded by v1.1.0 for new installs.
