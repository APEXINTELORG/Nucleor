# Changelog

All notable public changes to Nucleor are documented here.

## [1.1.1] - 2026-05-28

**Compiler file split, parser sync, hot-path perf reclaim, closure-capture
correctness, and use-std-* cfile fix.**

### Added

- `examples/30_typed_matrix.nr` — newtype-wrapper pattern for the
  scientific surface. `docs/internals/typed-wrappers.md` documents the
  pattern and its roadmap toward const-generic dimensions.
- `examples/29_scientific_benchmark.nr` — reproducible linalg/FFT/sort
  numbers, summarized in `docs/benchmarks.md`.
- `docs/why-nucleor.md` — one-page pitch with the honest limitations.
- `docs/internals/bootstrap.md` — seed-regeneration walkthrough.
- `docs/internals/file-split-roadmap.md` — design notes for the
  44 KLOC -> 14-module split.
- `docs/internals/history.md` — archived source-comment narrative
  pulled out of the per-fn defensive-halt blocks.
- `tools/gen_rt_name_fn.nr` — generator that emits
  `compiler/s1/get_rt_name.gen.nr` from `compiler/s1/get_rt_name.tsv`.
  `tools/check_rt_name_table.sh` enforces TSV <-> .gen.nr parity.
- `tools/strip_version_stamps.py` — one-shot helper that extracted
  215 multi-line `// vX.Y.Z` comment blocks to `history.md`.
- Tagged `PASS/SKIP/FAIL` breakdown in `tools/verify.sh` output so
  the 1660+ step count groups by area (drift, examples, parser,
  rfcs, tests, etc.) instead of a single opaque total.

### Changed

- `compiler/nucleor_s1_compiler.nr` split from 44,451 lines into a
  206-line entry plus 14 modules under `compiler/s1/` (lex, parse,
  ir, optim, builtins, emit, lower, diag, check_eff, check_own,
  check_type, cache, modules, cli). Each module is 0.5-5 KLOC.
- `compiler/nucleor_tools_suite.nr` split from 16,683 lines into a
  103-line entry plus 14 modules under `compiler/ts/`, parallel to
  the s1 layout.
- `compiler/s1/builtins.nr` shrinks 1448 -> 476 lines after lifting
  the 977-line `get_rt_name` if-chain to the generated `.gen.nr`.
- README leads with the Linux bootstrap path; `bin/nucleor.exe` is
  demoted to convenience.
- CHANGELOG Known Scope flags `@law(...)` rewrites, const-generic
  dimensions for scientific types, and RFC-0018 module-pub
  granularity as scaffolded.
- Closure values are now tagged i64 pointers (`env_ptr | 1`) rather
  than bare function pointers. The i64-everywhere ABI is preserved;
  indirect call sites dispatch on the low bit to handle both bare
  fn-ptrs and closures. Existing user code is unaffected.
- C runtime helpers that accept a `fn_ptr` argument
  (`vec_map_i64`, `vec_filter_i64`, `vec_fold_i64`, etc.;
  `thread_spawn`, `async_spawn`) now dispatch through tag-aware
  inline helpers. Accepts both bare fn-ptrs and boxed closure values
  transparently.

### Fixed

- Closure captures are now per-closure-instance, not per-literal. Two
  closures produced from the same literal (e.g. via a factory fn)
  carry independent captures and can be called in any order with
  correct results. Pre-fix, the global capture table keyed only by
  the literal's lex-time id meant every subsequent call to the
  factory stomped the prior closure's captures. See
  `tests/lang/closure_capture_*.nr` for the regression fixtures and
  `docs/internals/closures.md` for the implementation.
- `use std::*` / `use crate::*` / `use super::*` / `mod foo;`
  directives now compose imported rods' `#cfile` entries into the
  clang link line. Pre-fix the early raw-source cache fast path
  detected only line-start `import "..."` directives; sources using
  only `use`/`mod` forms took the fast path with
  `imported = [src_path]`, so `collect_native_directives` walked
  only the top-level file and missed rod-side C sources. The link
  failed with undefined references like `rods_f64_div` /
  `rods_trace_enabled` only on a warm `cache_v2` hit (cold path was
  unaffected because the `.ll` cache didn't exist yet). The detector
  now flags all four directive forms; false positives just route
  through the slow path (same correct output, ~10x build-time penalty).
- Hot self-build: `compile_file_mode`'s `load_resolved_source_bundle`
  had a guard that disabled the module-graph cache for compiler
  sources. Defensible when those were single-file (nothing to cache),
  broken post-split (forced a 215 ms `resolve_source` phase on every
  hot build). Guard lifted; hot self-build moves 0.70 s -> 0.40 s.
- Cold compiler memory: `resolve_source_with_records_active` held
  each imported file's source through the recursive resolve and to
  fn-return because the surrounding fn is `#[manual_drop]`. Inlined
  the `priv_apply_if_opted_in` logic at the call site so the alias
  vs new-allocation case can be distinguished, then freed isrc and
  isrc_used appropriately after the recursive call returns. Cold
  compiler RSS 365 MB -> 360 MB.
- Compiler drift gate (`tools/check_compiler_drift.sh`) extractors
  silently broke after the s1 split because they grepped the main
  file (post-split: 206 lines, mostly empty of the matched patterns).
  Every extractor returned an empty set on both sides and the gate
  falsely reported `OK`. The script now builds combined
  `main + s1/*.nr` and `main + ts/*.nr` views in a temp dir and
  routes content-bearing extractors through those. Also dropped the
  gawk-only 3-arg `match()` form in `extract_manual_drop_parse_fns`
  (mawk on Ubuntu emitted a parse-time syntax error that silently
  produced empty output).
- `compiler/ts/parse.nr`: 8 `parse_*` fns missing `#[manual_drop]`
  that the s1 siblings carry. Closed the strict-mode drift FAIL.
- `compiler/ts/parse.nr::parse_match_stmt`: added the three
  defensive halts from s1 (`|` or-pattern, `let` in match-guard,
  `=` in arm-body). Closes the last WARN-tier drift item; both
  parser paths now reject the same three Rust idioms with the same
  diagnostic shape.

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
- The duplicate parser surface between `compiler/s1/parse.nr` and
  `compiler/ts/parse.nr` (+ `compiler/nucleor_rfc0063_shared_wave2.nr`)
  remains. The drift gate's release-blocking items are all closed;
  the architectural cleanup is tracked as RFC-0063 Phase 2.0
  (parser unification — single source of truth). Closing it
  eliminates ~22 mirrored parser fns and the shared-wave layer
  that was created to share parser code.

### Deprecated

- `__nucleor_capture_set` / `__nucleor_capture_get` and the
  associated `g_capture_table` static buffer are retained as
  compatibility shims but no longer emitted by the codegen. Slated
  for removal in a future release.

### Release evidence

- Verify: `PASS=1662 SKIP=8 FAIL=0` on Linux.
- Drift gate (normal + strict): all OK.
- Self-host fixed point holds; seed sha
  `38c34be4b84396dc0d0a712be7a9630567a965401d79547f3098472fc7d46bdb`.
- Cold self-build: 8.5 s (ceiling 35 s). Hot self-build: 0.40 s
  median (ceiling 0.7 s). Cold compiler RSS: 360 MB (ceiling 375 MB).

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
