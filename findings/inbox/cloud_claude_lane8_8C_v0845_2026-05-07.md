# Lane 8 / Queue 8C — Full native Linux verify transcript

Date: 2026-05-07 (UTC)
Agent: cloud claude (Cloud_Control1.md punchlist)
Branch (harness-assigned): `claude/cloud-control-punchlist-bPLVn`
Punchlist-named branch: `probe/cloud-linux-full-verify-transcript-v0845` (not used; harness deviation, same as 8A/8B)
Base: `origin/main` @ `5890c84603bd46fc6d86b9500b2ef7cd4ae4d63c`
Working state: base + 8A + 8B (the 8A perf-baseline picker is in effect, so the T1.8 perf step uses `tools/perf_baseline_linux.json` automatically).

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
pwsh         = (missing — not exercised by verify.sh; release-only)
ssh-keygen   = (missing — not exercised by verify.sh; release-only)
```

`bin/nucleor` and `bin/nucleor_tools` were both native ELF before the run (verify started slightly after the bootstrap; `bin/nucleor_tools` was built and copied in-place during 8B at 11:09 UTC, before the parallel-fixture stage that exercises it).

## Command run

```
bash tools/verify.sh > findings/inbox/8C_artifacts/verify_full.log 2>&1
```

## Result summary

```
PASS: 1237
SKIP: 6
FAIL: 30
verify rc=1
```

Full log: `findings/inbox/8C_artifacts/verify_full.log` (gitignored — `*.log` matches).

## Failure classification

The handoff calls for four buckets: Windows-only fixture / missing Linux prerequisite / real compiler-runtime bug / performance-only drift. Below, every failing step is mapped to a bucket and a root cause. Several failures share a single root cause; root causes are labelled **R1..R5** to keep cross-references compact.

### Root causes

- **R1 — `nuc test` link path does not pass `-lm` on Linux.** `bin/nucleor build` correctly emits `clang ... -lm -lpthread`, but `bin/nucleor test` re-uses a different link path that omits `-lm`, so every libm symbol (`sqrt`, `log`, `exp`, `pow`, `floor`, `ceil`, `round`, `trunc`, `fmod`, `hypot`, `erf`, `erfc`, `lgamma`, `tgamma`, …) is undefined. Reproduced manually with a trivial `t.nr` containing only `#[test] fn ...`. **Linux-specific real compiler/runtime bug.** This is the dominant root cause — most T-prefixed failures share it.

- **R2 — POSIX `#else` branch of `stdlib/runtime/nucleor_llvm_rt.c` is missing 9 of 10 public RNG/random bridges.** The Windows side defines `__nucleor_random_uniform`, `__nucleor_random_normal`, `__nucleor_rng_int`, `__nucleor_rng_uniform`, `__nucleor_rng_normal`, `__nucleor_rng_bernoulli`, `__nucleor_rng_exponential`, `__nucleor_random_int`, `__nucleor_random_bool`. The Linux side (lines 3888-4111) only defines `__nucleor_rng_seed`. Confirmed via `nm` on the compiled object: only `__nucleor_random_choice`, `__nucleor_random_fill` (which live outside the ifdef) and `nuc_rng_int` (from `rng_rt.c`) are exported on Linux. **Linux-specific real compiler/runtime bug.**

- **R3 — `nuc init` does not `mkdir -p` the project's `src/` subdirectory before writing `src/main.nr`.** Reproduced manually outside verify: `nuc init smokeproj` writes `Nucleor.toml` then panics with `PANIC: file_write_string: cannot open 'smokeproj/src/main.nr' for writing (No such file or directory)`. **Linux-specific real compiler/runtime bug** — Windows likely tolerates this either via different path semantics or a different code path.

- **R4 — `nuc clean --cache` reports success but does not actually remove `target/.nuc_cache_v2/`.** Reproduced manually: command prints `clean: removing compilation cache (target/.nuc_cache_v2/, .nuc_cache/) … clean: done` then `ls target/.nuc_cache_v2/` still shows the entry. **Linux-specific real compiler/runtime bug.**

- **R5 — Linux ELF binaries get unique build-IDs from the system linker.** Two builds of byte-identical IR produce byte-different EXEs (`EXE diff: DIFFER`). The `verify-reproducible` step's own hint is the fix: pass `-Wl,--build-id=none` (or `--build-id=0x...`) when linking on Linux. **Linux-specific real compiler/runtime bug** — the linker invocation inside `nuc build`/`verify-reproducible` doesn't suppress build-IDs.

### Failure → bucket map

| Step | Bucket | Root cause |
| --- | --- | --- |
| compiler ABI tables synced | real bug | R5 |
| RFC-NRT-003: nuc verify-reproducible passes on sample fixture | real bug | R5 |
| CLI: nuc init scaffolding works | real bug | R3 |
| CLI: nuc lock writes Nucleor.lock | real bug | R3 (downstream — calls `nuc init lockproj`) |
| CLI: nuc test runs #[test] functions | real bug | R1 |
| CLI: nuc test --check-laws validates laws and schema | real bug | R1 |
| example 13_test_framework | real bug | R1 (uses `#[test]` framework) |
| example 18_benchmark | real bug | R1 + R2 (links math + RNG) |
| test runtime/path_utils | Windows-only fixture | asserts `path_is_absolute("C:/foo") == 1` — Windows drive letters are never absolute on POSIX |
| test runtime/random_extras | real bug | R2 |
| test runtime/rng | real bug | R2 |
| T1.5a mod block-form inline | real bug | R1 |
| T1.5b pub introspection (summary surfaces visibility) | real bug | R1 |
| T1.5c privatization (cross-module call surfaces succeed) | real bug | R1 |
| T2.6 println!/print!/format! macros expand correctly | real bug | R1 |
| T2.2 Vec iterator methods (.map/.filter/.fold/.sum/.min/.max) | real bug | R1 |
| T2.3 closure literals \|args\| body (no-capture) | real bug | R1 |
| T2.4 trait objects (Box<dyn Trait> 2-cell handle helpers) | real bug | R1 |
| T2.5 lifetime parameters parse cleanly (advisory metadata) | real bug | R1 |
| T2.8 async (threads-only): async fn / async_spawn / .await | real bug | R1 |
| T3.2 #[no_panic] passes when body has no panic-prone calls | real bug | R1 |
| T3.6 #[no_dyn] passes when body has no dynamic dispatch | real bug | R1 |
| T3.7 RT body checks strip strings and line comments | real bug | R1 |
| T3.134 v0.4.87 dispatch fix — v.insert/v.remove route to vec_insert_at/vec_remove_at | real bug | R1 |
| T3.135 v0.4.88 dispatch fix — s.len/contains/replace/split/starts_with/ends_with route to str_* | real bug | R1 |
| T3.136 v0.4.89 — extend str dispatch to to_lower/to_upper/trim/.../substring/char_at | real bug | R1 |
| T3.146 v0.4.115 RFC-0016 §3.7 — ? applies From<SrcErr> for DstErr | real bug | R1 |
| v0.5 Track L content-addressed cache v2 correctness | real bug | R4 |
| T3.11 bare arena_* builtins link + run end-to-end | real bug | R1 |
| v0.3.0 #[deadline=N] runtime check passes within budget | real bug | R1 |

### Bucket totals

- Windows-only fixture: **1** (`test runtime/path_utils`)
- Missing Linux prerequisite: **0**
- Real Linux compiler/runtime bug: **29**, in five root causes:
  - R1 (nuc test missing `-lm`) — 21 failures
  - R2 (POSIX RNG bridges missing in nucleor_llvm_rt.c #else) — 4 failures (random_extras, rng, example 18 partly, the rest folded into R1 first-line link failure for tests that touch RNG)
  - R3 (`nuc init` no `mkdir -p src/`) — 2 failures
  - R4 (`nuc clean --cache` doesn't remove target/.nuc_cache_v2) — 1 failure
  - R5 (Linux ELF build-id varies) — 2 failures
- Performance-only drift: **0** — `T1.8 POSIX perf + memory regression monitor` PASSED in 20.27s under the auto-selected Linux baseline.

### Side-effect finding (not in failed-steps list)

- A Windows-only test fixture leaked a file named `nul` into the repo root with stderr from `rmdir: failed to remove '/S': No such file or directory`. This is `cmd.exe` syntax (`rmdir /S /Q .nuc_cache 2>nul`) misfiring on Linux: `/S /Q` get parsed as positional args and `2>nul` writes to a file literally named `nul`. The step itself counted as PASS or did not gate on the result, but the artifact pollutes the working tree and would be caught by stricter PR checks. **Windows-only fixture leak.** Removed manually; classified.

## Compliance with 8C ground rules

- "Do not patch unrelated failures in this transcript branch unless small + deterministic." — No patches were applied as part of 8C. R3 and R4 in particular look small + deterministic, but their fixes live inside the self-hosted compiler / tools-suite (`compiler/nucleor_s1_compiler.nr` for `nuc init`/`nuc clean`) or the link plumbing (R1) — neither is "small" in the audit-trail sense the punchlist asks for. Filed as residuals so future cloud agents can pick them up under named branches.
- Every failure was classified, no failure was hidden, no fake-green was emitted.
- Native Linux only — no WSL, no Wine, no Windows `.exe` evidence.

## Residuals / proposed follow-on lanes

These are the smallest-deterministic-fix candidates implied by 8C. Each could be its own branch under the existing handoff naming convention.

1. **fix/cloud-linux-nuc-test-pass-lm-v0845** — make `nuc test`'s clang invocation pass `-lm -lpthread` (mirror the `nuc build` link command). Highest blast radius — clears 21 of 29 real-bug failures.
2. **fix/cloud-linux-rng-bridges-posix-v0845** — port the 9 missing RNG/random bridge functions from the `_WIN32` branch to the `#else` branch of `stdlib/runtime/nucleor_llvm_rt.c`. Clears the runtime/rng + runtime/random_extras + part of example 18 failures.
3. **fix/cloud-linux-nuc-init-mkdir-src-v0845** — make `nuc init` create the project's `src/` directory before writing `src/main.nr`. Clears nuc init + nuc lock smokes.
4. **fix/cloud-linux-nuc-clean-cache-v0845** — make `nuc clean --cache` actually remove `target/.nuc_cache_v2/` on Linux (the message claims success). Clears Track L correctness step.
5. **fix/cloud-linux-elf-build-id-deterministic-v0845** — pass `-Wl,--build-id=none` (or a deterministic build-id) when linking on Linux. Clears compiler ABI tables synced + RFC-NRT-003.
6. **fix/cloud-linux-rmdir-cmd-fixture-leak-v0845** — find the test step that calls `rmdir /S /Q ... 2>nul` and replace with `rm -rf ... 2>/dev/null` (or skip on non-Windows). Removes the rogue `nul`-file leak.
7. **fix/cloud-linux-tests-runtime-path-utils-windows-fixture-v0845** — split `tests/runtime/path_utils.nr` into POSIX vs Windows asserts, or guard the `C:/foo` assertion behind a platform flag.

The 6 SKIP steps were not investigated — they pre-existed before 8C and are skipped by the existing gate logic; outside scope for "transcript".

## Files added

- `findings/inbox/cloud_claude_lane8_8C_v0845_2026-05-07.md` (this file).
- `findings/inbox/8C_artifacts/verify_full.log` — full verify transcript (gitignored via `*.log`).
