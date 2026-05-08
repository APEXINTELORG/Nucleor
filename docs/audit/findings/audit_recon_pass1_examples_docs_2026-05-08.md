# RECON Audit — Pass 1, Layer 10: Examples + Documentation + Install Path

**Date:** 2026-05-08
**Project:** Nucleor v1.0 OSS — `Nucleor_OSS_integrate_r05_with_row_v0842`
**Binary under test:** `bin/nucleor.exe` (reports `Nucleor Compiler 1.0.0`)
**Scope:** user-facing surface — every example, README + getting-started + language-reference + architecture + benchmarks + adopter-guide docs, every `nuc` subcommand and documented flag, doc-link integrity, diagnostic-code references, version drift.
**Constraint:** read-only audit. NO FIXES. No `verify.sh` run.

---

## Executive summary

- **Examples surface is healthy.** All 28 numbered examples (`01_hello.nr`..`28_isr_tour.nr`) build and run with exit 0 against the shipped `bin/nucleor.exe`. All 5 showcase programs build and run.
- **CLI surface mostly works.** Every documented subcommand except three (`add`, `remove`, `update`) dispatches successfully on a trivial input.
- **Documentation has real drift problems.** `docs/language-reference.md` still self-identifies as v0.2 with stale version `0.2.0-v2`; `docs/benchmarks.md` numbers and framing are pre-v1.0; `docs/g1-default-flip-adopter-guide.md` describes a future flip that the README claims has already shipped. README mentions `--release` flag that doesn't exist; `architecture.md` mentions `--tier` flag that doesn't exist (both silently swallowed).
- **CRITICAL: README-promised diagnostic codes are not in `nuc explain`.** Eleven RFC-0062 G-series codes the README explicitly markets (`OWN-G4-USE-AFTER-DROP`, `OWN-G8-COND-MOVE`, `INIT-G11-...`, `BORROW-G2-...`, `ALIAS-G3-...` ×2, `SEND-G6-...` ×4, `FFI-G5-...`, `FFI-G9-...`, `UNSAFE-G7-...`, `EFFECT-G10-...` ×3) are emitted by the build path but **rejected by `nuc explain`** ("unknown error code"). README line 111 explicitly promises `nuc explain CODE` works for every diagnostic.
- **examples/README.md install snippet is wrong.** The "Build & run" example tells the user to run `./hello.exe` after `nuc build`, but the binary lands in `target/hello.exe`.
- **`nuc help` advertises three subcommand aliases that don't exist.** `add`, `remove`, `update` listed under "Aliases for install" — all return `Unknown command: …`.

---

## Methodology

1. Built every `examples/*.nr` and every `examples/showcase/*.nr` with `bin/nucleor.exe build … -o <name>`. Ran each compiled `.exe`. Captured exit code + first-line output.
2. Ran `bin/nucleor.exe --help` and `… help` (both produce the same output). Inventoried every dispatched subcommand. Built a trivial fixture `audit_scratch_user_surface/trivial.nr` and exercised every subcommand against it; for project commands (`init`, `lock`, `publish`) used a scaffolded test project.
3. Cross-referenced documentation claims (README, `docs/getting-started.md`, `docs/language-reference.md`, `docs/architecture.md`, `docs/benchmarks.md`, `docs/g1-default-flip-adopter-guide.md`, `examples/README.md`) against actual binary behaviour.
4. Verified every internal markdown link in README, getting-started, language-reference, language-tour points at an existing path.
5. Verified every diagnostic code mentioned in README/lang-ref against `nuc explain` and against codes actually emitted by `bin/nucleor.exe build` on `tests/err/err_g*.nr` fixtures.

---

## Examples build matrix

| # | Example | Build | Run | First line |
|---|---|---|---|---|
| 01 | examples/01_hello.nr | OK | rc=0 | `Hello, Nucleor!` |
| 02 | examples/02_fib.nr | OK | rc=0 | `fib_rec(10) = 55` |
| 03 | examples/03_structs.nr | OK | rc=0 | `p.x = 3` |
| 04 | examples/04_rods.nr | OK | rc=0 | `found 'Nucleor' in the greeting` |
| 05 | examples/05_quantum.nr | OK | rc=0 | `Bell state, 1024 shots:` |
| 06 | examples/06_perf_attrs.nr | OK | rc=0 | `add chain (laws-eligible) = 42` |
| 07 | examples/07_rust_interop.nr | OK | rc=0 | `regex matched a digit run in the text` |
| 08 | examples/08_linalg.nr | OK | rc=0 | `Solving Ax = b for` |
| 09 | examples/09_ode.nr | OK | rc=0 | `Solving dy/dt = -0.5*y, y(0) = 1, over [0, 2]` |
| 10 | examples/10_fft.nr | OK | rc=0 | `256-sample signal: 5 Hz + 13 Hz sinusoids` |
| 11 | examples/11_pid.nr | OK | rc=0 | `PID controller driving plant toward setpoint = 10.0` |
| 12 | examples/12_autodiff.nr | OK | rc=0 | `f(x) = sin(x²) + x  evaluated at x = 1.5` |
| 13 | examples/13_test_framework.nr | OK | rc=0 | `OK 13_test_framework` |
| 14 | examples/14_csv_summary.nr | OK | rc=0 | `=== Nucleor CSV summary demo (v0.2.x stdlib) ===` |
| 15 | examples/15_word_count.nr | OK | rc=0 | `=== Nucleor word-count demo (v0.2.x stdlib) ===` |
| 16 | examples/16_histogram.nr | OK | rc=0 | `=== Nucleor histogram demo (v0.2.x stdlib) ===` |
| 17 | examples/17_linecount.nr | OK | rc=0 | `=== Nucleor linecount demo (v0.2.x stdlib) ===` |
| 18 | examples/18_benchmark.nr | OK | rc=0 | `=== Nucleor benchmark harness (v0.2.x stdlib) ===` |
| 19 | examples/19_rt_pid.nr | OK | rc=0 | `RT-annotated PID step driving toward setpoint = 100` |
| 20 | examples/20_rt_motor_ffi.nr | OK | rc=0 | `Motor control loop with #[ffi_no_*] markers (v0.3.24/v0.3.26)` |
| 21 | examples/21_rt_state_machine.nr | OK | rc=0 | `Bounded-recursion segment walk with #[max_depth = 16]` |
| 22 | examples/22_rt_export.nr | OK | rc=0 | `Vec3 ops via #[export] (also callable from C):` |
| 23 | examples/23_rt_sensor_fusion.nr | OK | rc=0 | `Sensor fusion step (v0.3.51-63 production lock):` |
| 24 | examples/24_rt_kalman_step.nr | OK | rc=0 | `Kalman-style state update synthesis (v0.3.51-69):` |
| 25 | examples/25_patterns_tour.nr | OK | rc=0 | `OK range patterns` |
| 26 | examples/26_max_depth_tour.nr | OK | rc=0 | `OK 26_max_depth_tour: power_of_two = 256` |
| 27 | examples/27_effects_with_tour.nr | OK | rc=0 | `42` |
| 28 | examples/28_isr_tour.nr | OK | rc=0 | `OK 28_isr_tour: 3 ISR handlers parsed + type-checked` |
| – | examples/showcase/lorenz.nr | OK | rc=0 | (banner box) |
| – | examples/showcase/vqe_h2.nr | OK | rc=0 | (banner box) |
| – | examples/showcase/market_maker.nr | OK | rc=0 | (banner box) |
| – | examples/showcase/wing_simulator.nr | OK | rc=0 | (banner box) |
| – | examples/showcase/robotic_arm.nr | OK | rc=0 | `=== Nucleor Robotic Arm Showcase ===` |

**Result: 33/33 example builds + runs PASS.**

Notes on the build artifact path: every example build emits to `target/<basename>.exe` regardless of how the user spells the `-o` argument, with a path component (e.g. `-o audit_scratch_user_surface/build/01_hello`) collapsed to its basename. README, getting-started.md, and the example output line all consistently say `target\hello.exe`, and that is what actually ships. The single doc that contradicts this is `examples/README.md` (see High-2).

---

## CLI subcommand inventory

Every subcommand reachable from `nuc help` was exercised against `audit_scratch_user_surface/trivial.nr` (or a scaffolded project where applicable). Result table — V = verified working on trivial input, X = broken, ? = documented but undiscoverable from `--help` (still works), S = special (project-only, project scaffolded for the test).

| Subcommand | Status | Notes |
|---|---|---|
| `init [name]` | V | scaffolds `Nucleor.toml` + `src/main.nr` + `target/` |
| `build [file]` | V | rc=0, emits `target/<name>.exe` |
| `build-fast [file]` | V | aliases the fast core path |
| `build-strict [file]` | V | full delegated checker stack |
| `build-shared [file]` | V (errors gracefully on no-`pub fn`) | requires source w/ `pub fn` exports |
| `run [file]` | V | |
| `emit [file]` | V | LLVM-IR-only path |
| `build-wasm [file]` | V | emits `target/trivial.ll`; no WASM produced for trivial |
| `build-ptx [file]` | V | emits `.ll`, no PTX produced for trivial |
| `verify-reproducible [file]` | V | runs the twice-with-no-cache check |
| `test [file]` | V | reports "no tests found" for trivial |
| `bench [file]` | V | runs default 10 iterations |
| `perf [file]` | V | prints performance analysis |
| `bootstrap status` | V | reports stage-1 self-hosted, 28 examples |
| `stage-dump tokens\|ast\|typed\|ir\|all` | V | all five stage names work |
| `summary [file]` | V | |
| `query [file]` | V | JSON output |
| `abi [file]` (incl. `--exports --json --c-header --rust-extern`) | V | |
| `evidence [file]` | V | JSON govern report |
| `impact [file] <fn>` | V | reverse call graph works for `main` |
| `graph [file]` | V | |
| `doc [file]` (incl. `--test-list`) | V | |
| `profile run <bin>` | V | timed exec on a built binary |
| `lock [manifest]` | S | works when run inside a `nuc init` project |
| `install [alias] <pkg>` | S | works in project context |
| `add` / `remove` / `update` | **X** | help advertises these as aliases of `install`, but binary returns `Unknown command: …`. See Critical-1. |
| `publish [manifest]` | S | works in project context |
| `registry list\|search\|versions\|verify` | V | `registry list` reports empty registry on a fresh tree |
| `sage prove\|certificate\|gaps` | V | reports `Layer N missing` (Sage_NS not bundled — expected) |
| `check [file]` (incl. `--json`, `--sarif`, `--review`, `--check=<list>`) | V | SARIF includes a stale driver version (see Medium-2) |
| `explain <CODE>` | V (incomplete) | works for `OWN-001 / OWN-008 / TYP-005..008 / NUM-001 / NR031`. Does **NOT** know any RFC-0062 G-series code. See Critical-2. |
| `audit [file]` | V | |
| `policy [file] [level]` | V | |
| `certify [file]` | V | |
| `translate [file]` | V | |
| `clean` (and `clean --cache`) | V | |
| `scram` | V | aliases `clean` |
| `fix --imports\|--numeric [file]` | V | bare `nuc fix <file>` correctly errors, asking for the variant |
| `zen` | V | prints the Zen of Nucleor |
| `mco` | V | prints the Mars Climate Orbiter justification card |

**Undocumented in `--help` but functional:** `gen-headers <input.nr> [-o <out.h>]` (referenced from `examples/README.md` Tier-4 row 22 and `docs/v0.3-robotics-guide.md`-class material; works when invoked) — see Medium-3.

**Documented in `--help` but undiscoverable in code paths the user can reach:** `add`, `remove`, `update`. See Critical-1.

**Build-flag spot checks** (run on `audit_scratch_user_surface/trivial.nr`):

| Flag | Status | Behaviour |
|---|---|---|
| `-o <name>` | V | always lands in `target/<basename>.{exe,ll}` |
| `--emit llvm` | V | preserves the `.ll` |
| `--no-link` | V | "native link: skipped" message printed |
| `--no-cache` | V | "cache: disabled" message printed |
| `--cache-stats` | V | "cache stats: hits=X misses=Y" printed |
| `--time-passes` | V | per-phase `time …: NNN ms` lines printed |
| `--provenance <path>` | not exercised — needs a SLSA file fixture | (subcommand listed under `verify-reproducible`; flag accepted by `build`, no fixture available) |
| `--release` | **X (silent swallow)** | mentioned in README L130 + getting-started "Tour by example" but not in `--help`. Compiler accepts the flag without error and produces the same default-tier output. See High-3. |
| `--tier <0\|1\|2>` | **X (silent swallow)** | mentioned in `architecture.md` §"Tier system" but not in `--help`. Compiler swallows it and produces default output (no observable behavioural change). See High-3. |
| `--bogus-flag-xyz` | **X (silent swallow)** | confirmed unknown flags do not error — mask the High-3 issue. See Medium-4. |

---

## Doc-link integrity report

All internal markdown links in **README.md** point at existing files:

| Target | Resolves |
|---|---|
| docs/NUCLEOR_FEATURE_INVENTORY.md | OK |
| docs/rfcs/rod_manifest.toml | OK |
| docs/rfcs/helper_manifest.toml | OK |
| docs/rfcs/RFC-0062-effects-extension.md | OK |
| docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md | OK |
| docs/rfcs/RFC-0063-production-readiness-roadmap.md | OK |
| examples/README.md | OK |
| CONTRIBUTING.md / SECURITY.md / CHANGELOG.md / RELEASES.md / LICENSE | OK |

All internal links in **docs/getting-started.md**: `language-tour.md`, `language-reference.md` — OK.

All internal links in **docs/language-reference.md**: `language-tour.md`, `milestones/v0.4.0.md`, `UPGRADE_v0.4.239.md`, `UPGRADE_v0.4.241.md`, `migrations/v0.1-to-v0.2.md`, `milestones/v0.3.0.md`, `spec/Nucleor_Algebraic_Laws_Schema.md` — OK.

All internal links in **docs/language-tour.md** spot-check: `v0.4_FEATURE_AUDIT_2026-04-30.md`, `migrations/v0.2-to-v0.4.md` — OK.

`tools/examples.list` exists and is the single source of truth referenced by `examples/README.md`. Coverage: 27 of 28 numbered examples (07_rust_interop is intentionally added programmatically by the verify scripts, per the comment in the file).

**No broken internal links found in the user-facing doc set.**

---

## Findings

### Critical

#### Critical-1 — `nuc help` advertises three subcommands that don't exist
- **Location:** `bin/nucleor.exe --help` line "`add | remove | update         Aliases for install (RFC-0019 phase 4 ergonomics)`" — and consequently every README/doc that paraphrases the help.
- **Reality:** `bin/nucleor.exe add`, `… remove`, `… update` each return `Unknown command: …` and exit non-zero.
- **User impact:** anyone following `nuc add <pkg>` per the help text gets a flat error. This is the surface most likely to be tried first by package-using adopters.
- **Remediation:** wire `add` / `remove` / `update` to the `install` dispatcher (the RFC-0019 phase-4 ergonomic aliases). Alternative: drop the line from `nuc help` until the aliases are wired. Either fix is mechanical — almost certainly a one-line dispatch table in `compiler/nucleor_tools_suite.nr`.

#### Critical-2 — README-promised diagnostic codes are not in `nuc explain`
- **Location:** README §"Memory safety — what the language guarantees" (lines 100–111). README L111 verbatim: "Every diagnostic has a printable description: `nuc explain CODE`."
- **Reality:** the eleven RFC-0062 G-series codes the README markets (`OWN-G4-USE-AFTER-DROP`, `OWN-G8-COND-MOVE`, `INIT-G11-READ-BEFORE-INIT`, `BORROW-G2-LIFETIME`, `ALIAS-G3-VEC-OF-REFS`, `ALIAS-G3-HASHMAP-REHASH`, `SEND-G6-{HASHMAP,CLOSURE-CAPTURE,TUPLE,ENUM}`, `FFI-G5-NULL-DEREF`, `FFI-G9-MISSING-ALLOW-DIRECT-FFI`, `UNSAFE-G7-MISSING-ALLOW`, `EFFECT-G10-{UNDECLARED,MISSING-ALLOW,WRONG-ROW}`) are all emitted at compile time (verified against `tests/err/err_g*.nr` fixtures) but rejected by `nuc explain` ("unknown error code: …"). The explain database knows only the older `OWN-001 / OWN-008 / TYP-00X / NUM-001 / NR031` codes plus the legacy `NR0XX` family.
- **Mismatch:** users hit `error[ALIAS-G3-VEC-OF-REFS]: …` from `nuc build`, copy the code into `nuc explain ALIAS-G3-VEC-OF-REFS`, and get `unknown error code`. README line 111 is a broken contract.
- **Note:** the per-diagnostic fix advice IS in the build-time error message itself ("Per RFC-0062 G-3 Phase 3 (v1.0): the syntactic borrow tracker does not follow elements through `Vec<&T>` …"). So the user is not stranded — they have a hint inline. But `nuc explain` is still broken for the marketed codes.
- **Remediation:** populate `compiler/nucleor_tools_suite.nr`'s `explain` database with entries for every G-series code shipped at v1.0. Source the prose from the inline error messages — they already contain the full reason + remedy. Alternatively (and cheaper): make `nuc explain` fall through to `docs/spec/Nucleor_Error_Codes.md` and grep by the code, so any code with a docs entry resolves automatically.

### High

#### High-1 — `docs/language-reference.md` self-identifies as v0.2 in a v1.0 ship
- **Location:** L1: `# Nucleor Language Reference (v0.2)`. L3: "the self-hosted compiler … version `0.2.0-v2` plus the v0.2.x post-RC sub-chain". §13 still describes the file as a corrigendum on v0.1.5/v0.2 audits.
- **Reality:** `bin/nucleor.exe --help` reports `Nucleor Compiler 1.0.0`. README announces v1.0 as the shipping line and has been substantially extended (memory safety §, RFC-0062 G-series, ~250 rods). The language reference does not mention RFC-0062, the G-series codes, the strict-mode integer arithmetic default flip (NUM-001 / wrapping/saturating/checked blocks ARE mentioned in §1.4 — that one survived), traits/generics other than as a §13 historical corrigendum, contracts, effects on fn types, etc.
- **User impact:** anyone landing on the language reference will see the v0.2 banner and will not trust it as a v1.0 description. The help index in `nuc help` does not point at this file, but README and getting-started both link to it as the normative source.
- **Remediation:** rewrite the lang-ref header to v1.0; merge the §13 corrigenda into the body (they refer to features that have been shipping for many releases); add at minimum a §14 cross-link to `docs/rfcs/RFC-0062-effects-extension.md` and the RFC-0062 G-series codes; add the seven diagnostic codes the README markets to the §9 table.

#### High-2 — `examples/README.md` install snippet writes wrong run path
- **Location:** `examples/README.md` lines 12–14:
  ```
  bin/nucleor.exe build examples/01_hello.nr -o hello
  ./hello.exe
  ```
- **Reality:** `nuc build … -o hello` always emits to `target/hello.exe`. Running `./hello.exe` from the repo root in the line right under the build command will fail with a "file not found" error.
- **Cross-check:** the project README (line 14) and `docs/getting-started.md` (line 44) both correctly say `target\hello.exe`. So the index landing page (`examples/README.md`) is the only one out of step.
- **User impact:** the first thing an example-curious user types after `git clone` will not work, and nothing in the same paragraph explains the `target/` directory.
- **Remediation:** patch L14 to `target/hello.exe` (POSIX) or `target\hello.exe` (Windows). This file is also where the "run, confirm exit 0:" step at L137 says `./my_demo.exe; echo "exit=$?"` — same bug, same fix.

#### High-3 — README/architecture promise build flags that the binary silently swallows
- **Location:**
  - README L130 in §"Tour by example":
    ```
    nuc build [path] [--release] [-o name]
    ```
    `--release` is not in `nuc help`, and is silently swallowed by the binary (no behavioural change vs. the default tier).
  - `docs/architecture.md` §"Tier system" describes `--tier <0|1|2>` mapping to LLVM `-O0` / `-O1` / `-O3 + LTO`. `--tier` is also silently swallowed.
- **Reality:** the binary accepts arbitrary unknown flags (verified with `--bogus-flag-xyz`) without error. There is no way for the user to verify a release build was actually produced, and there is no observable difference in compile output.
- **User impact:** anyone benchmarking Nucleor with `--release` thinks they're testing optimised output; they are not. The benchmarks docs lean heavily on this.
- **Remediation (two options):**
  1. **Implement the flags.** Wire `--release` to tier 2 (`-O3 + LTO`) and `--tier <N>` to the documented map. The pipeline plumbing is in `link_native_module` / `llvm_clang_path` per `architecture.md` §"Where to look in the source".
  2. **Drop them from the docs and add a hard error.** Strip `--release` from README and `--tier` from architecture.md; replace silent-swallow with `error: unknown flag: --release` so users find out at compile time. Pair with Medium-4 below.

#### High-4 — `docs/g1-default-flip-adopter-guide.md` describes a flip the README claims has shipped
- **Location:** `docs/g1-default-flip-adopter-guide.md` L1–L20: "Status: v0.8.39 experiment — adopter validation phase. Final ship: Phase 2b-3 unconditional flip, after seed-side trace." L7–L9: "Today (v0.x): a Nucleor function only gets auto-drop semantics if it's tagged `#[auto_drop]`." L12–L14: "After Phase 2b-3 ships (v0.9.x): every function will auto-drop heap-backed locals by default."
- **Reality:** README L100 marks auto-drop as default-on and the opt-out as `#[manual_drop]`. README is the v1.0 marketing surface; this guide is internal experiment-phase prose still gated behind `NUC_AUTO_DROP_DEFAULT=1`.
- **User impact:** an adopter reading both will not know which is current. They will read this guide as live guidance and try to opt INTO a behaviour that is already on.
- **Remediation:** rewrite the adopter guide as a v1.0 retrospective (auto-drop is on; here's how to opt out with `#[manual_drop]`; here are the gotchas the adopters caught during the v0.8.x experiment), or move it to `docs/process/` and remove from the public-facing path. Cross-check whether `NUC_AUTO_DROP_DEFAULT=1` still has effect at v1.0 — if it has been promoted to default-on, the env var is dead and should be removed from the code path.

### Medium

#### Medium-1 — `docs/benchmarks.md` numbers and framing are pre-v1.0
- **Location:** `docs/benchmarks.md` L4–L5: "the v0.2 self-host bootstrap pipeline, not to compete with mature production compilers — that comparison comes after v1.0." L21–L29: numbers as of `v0.2.128 / v0.2.87 / v0.2.84` with a comparison to the "v0.1-era estimates". Stage table at L11–L15 quotes ~27 s clean self-build, ~24 s internal, sub-second IR cache + ~5 s clang link.
- **Reality:** the binary reports v1.0.0 and the README quotes a "3.5 seconds rebuild from a committed `.ll` seed" + "current: ~185 MB" peak allocation under the 400 MB budget. Numbers in benchmarks.md are from the v0.2 pipeline and don't match.
- **Remediation:** update the L11–L15 stage table to v1.0 numbers from the latest verify run; update L21–L29 to current LOC + IR + binary sizes; replace L4–L5 framing with a v1.0 one ("here are the v1.0 reproducible numbers; compiler-vs-compiler comparisons against rustc/clang are still out of scope"). Cross-link `tools/perf_baseline.json` and `tools/perf_baseline_linux.json` so readers can reproduce.

#### Medium-2 — `nuc check --sarif` reports stale driver version
- **Location:** `nuc check audit_scratch_user_surface/trivial.nr --sarif` output: `"tool":{"driver":{"name":"nucleor","version":"0.1.0", …}}`.
- **Reality:** binary is `Nucleor Compiler 1.0.0`. SARIF consumers (e.g. GitHub code-scanning) treat the driver version as the truth.
- **Remediation:** thread the actual binary version into the SARIF emitter — the version string is already available to `--help`. Search `compiler/nucleor_tools_suite.nr` for the SARIF emit call site.

#### Medium-3 — `nuc gen-headers` is not in `--help`
- **Location:** `bin/nucleor.exe gen-headers` works (`usage: nuc gen-headers <input.nr> [-o <out.h>]`). `examples/README.md` L70 mentions it ("`nuc gen-headers` produces matching C decls"). It is not listed in `bin/nucleor.exe help`.
- **User impact:** discoverability gap. Users who know about `#[export]` and want C headers may not find the verb.
- **Remediation:** add a one-liner to the "Project utilities:" section of `nuc help` (or under "Developer commands:" — it's adjacent to `abi --c-header`).

#### Medium-4 — Build subcommand silently swallows unknown flags
- **Location:** verified `bin/nucleor.exe build … --bogus-flag-xyz` produces a normal build with no warning.
- **User impact:** masks High-3 (`--release`/`--tier`) and any future flag typos. A user who types `--no-cahce` (typo) will not be told their cache is still on.
- **Remediation:** add an unknown-flag check in the dispatch path. Whitelist the valid build flags (the list is small and already in `nuc help`). Emit `warning: unknown flag '--XYZ' (ignored)` at minimum, ideally a hard error.

#### Medium-5 — `tools/verify.sh` header says "203 steps total as of v0.2.111"
- **Location:** `tools/verify.sh` L8 in the file header comment.
- **Reality:** README L155 quotes "PASS=1518 / SKIP=3 / FAIL=0" — the gate has grown by 7×.
- **Remediation:** retag the header to current step count. (Only one verify-related drift the audit looked at — the comments at L10–L26 also reference `v0.2.x` features; could use a refresh, but the labels are still useful as historical tags.)

#### Medium-6 — `nuc explain` legacy `NR031` code is described as "Borrow Safety Failure" with prose that contradicts modern G-series messages
- **Location:** `bin/nucleor.exe explain NR031` returns "Borrow Safety Failure / Ownership or borrowing rules were violated. … Typical causes are moving a borrowed value, mixing shared and mutable borrows, or using a value after move."
- **Reality:** the modern compiler emits the specific G-series codes (`OWN-G4-USE-AFTER-DROP`, `BORROW-G2-LIFETIME`, etc.) instead of `NR031`. The legacy generic code is reachable via `nuc explain` but not via the build path the user actually walks.
- **Remediation:** clean up — either purge the legacy `NR0XX` codes from `nuc explain` or annotate them as `(legacy — superseded by …)` with the modern code. Couple with Critical-2 above so the explain database is internally consistent.

### Low

#### Low-1 — README L46: launcher search-path docs have a sentence-fragment phrasing
- **Location:** README L46: "The `nuc.bat` (Windows) / `nuc` (POSIX) launcher resolves `clang.exe` from `NUCLEOR_CLANG_PATH`, then `LLVM_SYS_180_PREFIX/bin`, then `C:\Program Files\LLVM\bin`, then plain PATH."
- **Issue:** the path examples are Windows-only (`C:\Program Files\LLVM\bin`) but the launcher claim covers both. POSIX users will read this and not know whether the same fallback applies.
- **Remediation:** either drop the Windows-specific path in this sentence or add the POSIX equivalent.

#### Low-2 — `examples/05_quantum.nr` Bell-state shot output is non-deterministic across runs
- **Location:** README example output and example-tier text imply a Bell preparation. Run output: `|00> = 510 …` (ratios approx 50/50 but not fixed).
- **Issue:** not a bug — but a CI gate that asserts byte-exact stdout would flap. The verify gate appears to use the example exit code only (per `tools/examples.list` comments), so this is fine, but worth a Note for anyone tightening the gate later.
- **Remediation:** if a future verify step wants byte-exact comparison, seed the RNG via `rng_seed`. (Tier-3 demo `18_benchmark` already documents the seeded-RNG pattern.)

#### Low-3 — `docs/getting-started.md` L84 "rebuild via `nuc build compiler\nucleor_s1_compiler.nr -o bin\nucleor.exe`" doesn't note that `-o` always redirects through `target/`
- **Location:** getting-started.md L84 troubleshooting row "`bin\nucleor.exe not found`" advises a self-rebuild incantation.
- **Issue:** tested empirically (Critical/High traffic above): `-o bin\nucleor.exe` will land in `target\nucleor.exe` (the basename is preserved, the directory is not). A user who's missing the binary and follows the advice will end up with `target/nucleor.exe`, which solves their immediate problem but is not where the docs said it would go.
- **Remediation:** rewrite the row to either (a) describe the actual landing path, or (b) include a `Move-Item target\nucleor.exe bin\nucleor.exe` follow-up step. The wording here is from the era when `-o <path>` honored the directory component.

### Note

#### Note-1 — Showcase-example output box uses ANSI 256-color escape codes
- **Location:** `lorenz`, `vqe_h2`, `market_maker`, `wing_simulator` all open with `[38;5;51m+----+[0m`-style banners.
- **Observation:** the Windows Terminal renders this fine; legacy `cmd.exe` will display the raw escape sequences. Not a doc claim, just an observation for future docs that show "expected output".
- **Remediation:** none required. If the showcase READMEs ever quote literal expected stdout, they should either strip the colour codes or accompany them with a "best viewed in Windows Terminal" note.

#### Note-2 — `tools/examples.list` does not include showcase programs
- **Observation:** verify gate exercises `examples/01..28`. Showcase programs are referenced in README and getting-started but not gated. The `examples/showcase/README.md` file (referenced by `examples/README.md` L91) was not opened during this audit; if the verify gate ever wants showcase regression coverage, the list is the place.
- **Remediation:** none required for v1.0 (showcases are discovery-grade demos, not gated invariants). Worth a `tools/examples.list` extension if a future release wants showcase invariance.

#### Note-3 — `docs/architecture.md` L183 hard-codes a line number from a stale version
- **Location:** "`fn get_rt_name(name: str) -> str` (line 2004 as of v0.2.129; the long string of `__nucleor_*` mappings runs from there for several hundred lines)".
- **Observation:** line numbers will drift; the v0.2.129 anchor is stale.
- **Remediation:** drop the line number, keep the function name. Pattern repeats in the same table (line numbers / version anchors).

---

## Out-of-scope but observed

- **Install instructions on a fresh shell:** a true clean-VM walkthrough was out of scope (no fresh VM available in this audit). What was verified: `git clone` step + `bin/nucleor.exe` invocation work with the repo as-is and an LLVM 18.x install. The `setx PATH` step in getting-started.md L26 was not exercised. The `winget install LLVM.LLVM` step in L9 was not exercised. The `cargo build --release` step under `stdlib/rods/rust_bridge/` was not exercised — example 07 builds + runs cleanly, which suggests the rust_bridge artifacts are already present in the tree, but a fresh-clone Linux box would need to do this manually.
- **`docs/getting-started.md` `nuc test tests/`:** advised in L77 as a smoke step. Not exercised in this audit (would have run several thousand tests). Should be exercised in a future audit pass that has compute budget for it.
- **macOS bootstrap:** README L48 claims Linux self-build operational, macOS pending. No macOS validation in this audit.
- **`#[effect(...)]` annotations on hot-path code:** the README §"Memory safety" descriptions of effect annotations were not negated against actual fixtures beyond the err_g10 set above.

---

## Files referenced by absolute path

- Binary: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/bin/nucleor.exe`
- Examples: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/examples/`
- Showcase: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/examples/showcase/`
- README: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/README.md`
- Getting started: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/docs/getting-started.md`
- Language reference: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/docs/language-reference.md`
- Architecture: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/docs/architecture.md`
- Benchmarks: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/docs/benchmarks.md`
- G1 adopter guide: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/docs/g1-default-flip-adopter-guide.md`
- Examples index: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/examples/README.md`
- Examples list: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/tools/examples.list`
- verify.sh: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/tools/verify.sh`
- Audit scratch: `C:/Users/JoeWe/Desktop/Nucleor_OSS_integrate_r05_with_row_v0842/audit_scratch_user_surface/`
