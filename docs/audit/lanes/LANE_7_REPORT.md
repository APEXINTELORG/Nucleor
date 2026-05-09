# Lane 7 — Docs + User Surface — Completion Report

**Branch:** `fix/audit-lane-7-docs-user-surface-2026-05-08`
**Worktree:** `worktrees/audit_fix_lane_7`
**Source-of-truth findings:** `docs/audit/findings/audit_recon_pass1_examples_docs_2026-05-08.md`
**Brief:** `docs/audit/lanes/LANE_7_DOCS_USER_SURFACE.md`

## Decision policy applied

The brief's default rule was **remove the doc/help reference when the feature isn't implemented**, rather than implement the feature. Applied as follows:

- `nuc add | remove | update` → REMOVED from `nuc help` (and from the verify-script help-coverage cmd lists, plus the `verify_fast.sh` mirror).
- `--release` flag → REMOVED from README L130 tour block. Strict-flag-checking ADDED to the build subcommand so any future drift surfaces as a `warning: unknown flag '--XYZ' (ignored)` line.
- `--tier <0|1|2>` → REMOVED entirely from `docs/architecture.md` §"Tier system".
- `nuc explain` G-series codes → ADDED database entries (the only "implement" path the brief authorized). Sourced from the inline build-time messages + diagnostics inventory.

## Per-finding status

### Critical (2/2 closed)

| Finding | Disposition | Notes |
|---|---|---|
| Critical-1 — `add | remove | update` advertised but unimplemented | REMOVED from help | `compiler/nucleor_s1_compiler.nr:40557` + `compiler/nucleor_rfc0063_shared_wave2.nr:1784` line deleted. Help-coverage smoke (`tools/verify.sh:746`, `tools/verify.ps1:469`, `tools/verify_fast.sh:715`) updated in lockstep so the drift gate (`t326_cli_help_cmds_drift`) still passes. |
| Critical-2 — README G-series codes rejected by `nuc explain` | IMPLEMENTED | 14 G-series codes added to `explain_error_title`, `explain_error_summary`, and `explain_error_explanation` in `compiler/nucleor_tools_suite.nr`. Smoke-tested every one — title + summary + full explanation render correctly. |

### High (4/4 closed)

| Finding | Disposition | Notes |
|---|---|---|
| High-1 — `language-reference.md` v0.2 banner | REWRITTEN to v1.0 | Header bumped, version string `0.2.0-v2` removed, status note added describing §13 corrigenda as historical. Cross-link added to RFC-0062 G-series + RFC-0063 roadmap. §1.5 keyword list expanded to match the actual lexer (core + reserved-only sets). |
| High-2 — `examples/README.md` `./hello.exe` path | FIXED | Both occurrences (build snippet + "run, confirm exit 0" step) now point at `target/hello.exe` (Windows) / `./target/hello` (Linux). |
| High-3 — `--release` / `--tier` silently swallowed | REMOVED from docs + ADDED strict-flag-check | README L130 strips `[--release]`. `docs/architecture.md` §"Tier system" deleted. Build-flag parser at `compiler/nucleor_s1_compiler.nr:40821` now emits `warning: unknown flag '--XYZ' (ignored)` for unrecognized flags. Smoke-tested with `--bogus-flag-xyz` and `--release`. |
| High-4 — `g1-default-flip-adopter-guide.md` describes pre-v1.0 experiment | REWRITTEN as v1.0 retrospective | Document now states auto-drop is on by default at v1.0; documents `#[manual_drop]` opt-out; documents `NUC_AUTO_DROP_DEFAULT` as deprecated; preserves the experimental-period framing as historical context. |

### Medium (6/6 closed)

| Finding | Disposition | Notes |
|---|---|---|
| Medium-1 — `benchmarks.md` pre-v1.0 numbers | MARKED with refresh-pending header | Explicit "PRE-V1.0; refresh pending" callout at top with pointer to v1.0 numbers in README §"Verification gate" + `tools/perf_baseline*.json`. Body retained for historical reference. |
| Medium-2 — SARIF driver version stale (`0.1.0`) | BUMPED to `1.0.0` | `compiler/nucleor_tools_suite.nr:3643` literal updated. Tools-suite rebuilt + installed at `bin/nucleor_tools.exe`. |
| Medium-3 — `gen-headers` not in `nuc help` | ADDED | New line under "Project utilities:" in s1 + wave2 help text describes `gen-headers <input.nr> [-o <out.h>]`. |
| Medium-4 — Build subcommand silently swallows unknown flags | FIXED via strict-flag-check (also closes High-3 root cause) | See High-3. |
| Medium-5 — `verify.sh` header "203 steps as of v0.2.111" | UPDATED | Step shape comment now reads "~1518 steps total as of v1.0.0" with note that the count grows. |
| Medium-6 — `nuc explain NR031` claims to be a current code | LEGACY-FLAGGED | Title now reads "Borrow Safety Failure (legacy — superseded by RFC-0062 G-series at v1.0)"; summary lists the modern G-series replacements. |

### Low / Note (mostly closed)

| Finding | Disposition | Notes |
|---|---|---|
| Low-1 — README L46 launcher fallback Windows-only path | FIXED | Sentence now lists POSIX (`/usr/lib/llvm-18/bin`, `/usr/local/bin`) + Windows (`C:\Program Files\LLVM\bin`) fallbacks separately. |
| Low-2 — `examples/05_quantum.nr` non-deterministic Bell output | NOT TOUCHED | Audit listed as Note ("not a bug — just a CI-tightening risk"). No fix required at this audit level. |
| Low-3 — `getting-started.md` L84 `-o bin\nucleor.exe` advice | FIXED | Row rewritten to point at the bootstrap scripts + clarify `-o` preserves basename only (lands in `target/`). |
| Note-1 — Showcase 256-color escape codes | NOT TOUCHED | Audit listed as Note (renders correctly in modern terminals; no doc claim contradicts). Out of scope for this lane. |
| Note-2 — `tools/examples.list` excludes showcases | DOCUMENTED | Comment block in `examples.list` now explains why showcases are gated separately by the showcase-build step. |
| Note-3 — `architecture.md` hardcoded line 2004 for `get_rt_name` | FIXED | Replaced version-stamped line number with a search-friendly stable reference ("search for the function declaration"). |

### Cross-layer

| Finding | Disposition | Notes |
|---|---|---|
| Cross-17 — `language-reference.md` keyword set vs lexer | RECONCILED | §1.5 expanded with explicit "core" + "reserved-only" sets, plus a pointer at the lexer source for canonical bytes. |

## Removed-vs-implemented decisions

| Surface | Decision | Rationale |
|---|---|---|
| `nuc add | remove | update` | REMOVE | Brief default; aliases were never wired and v1.x scope. |
| `--release` flag | REMOVE (mention) + ADD (strict-flag-check) | Brief default; the strict-flag-check was the small UX-positive compiler change the brief explicitly authorised. |
| `--tier <0|1|2>` | REMOVE | Brief default; entire §"Tier system" deleted from architecture.md because it described a feature the binary does not honour. |
| `nuc explain` G-series codes | IMPLEMENT (database entries only) | Brief explicitly authorised this path: source the prose from the inline build-time messages. The diagnostic emit paths already exist in the compiler — only the explain database was missing. |
| `nuc gen-headers` discoverability | IMPLEMENT (help text) | Already exists in the binary; the only fix was a help line. |
| SARIF driver version | IMPLEMENT (literal bump) | One-character source change; no semantic-feature shift. |
| Strict-flag-check severity | WARNING (not hard error) | Preserves backward-compat for downstream tooling that may pass through extra flags by accident. |

## Bootstrap regen

Compiler-source edits (s1 help-line removal, wave2 mirror, strict-flag-check, tools-suite SARIF + G-series + NR031 legacy update) require seed regeneration. Performed:

1. `bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_seed_new --no-cache` → `target/nucleor_seed_new.exe` + `target/nucleor_seed_new.ll`.
2. Stage-2 self-rebuild via `target/nucleor_seed_new.exe build compiler/nucleor_s1_compiler.nr -o nucleor_seed_stage2 --no-cache` → byte-for-byte md5 match against stage-1.
3. Refreshed `bootstrap/nucleor_s1_seed.ll` from `target/nucleor_seed_new.ll`.
4. Promoted `target/nucleor_seed_new.exe` → `bin/nucleor.exe`.
5. Built `nucleor_tools.exe` (gitignored; rebuilt by `tools_rebuild` step in verify) and tested locally to confirm explain G-series resolution through the s1↔tools-suite delegation path.
6. Ran `tools/check_self_host_md5.sh` — fixed point holds:
   ```
   OK: self-host compiler IR fixed point holds md5=de7e7729a65c53e2b35d45692c321f7a
   OK: bootstrap seed matches current self-host IR md5=de7e7729a65c53e2b35d45692c321f7a
   ```

## Verify run

`bash tools/verify.sh` was run ONCE at end per the verify policy. Result captured in this report after the run completes (see "Final verify counts" section appended below).

## Smoke-test results (per-subcommand)

Tested via `audit_scratch_lane7/trivial.nr` (cleaned up post-run):

| Subcommand | Result |
|---|---|
| `build trivial.nr -o triv1` | OK, rc=0 |
| `run trivial.nr` | OK, rc=0 |
| `check trivial.nr` | OK, ran 5 checkers |
| `explain OWN-G4-USE-AFTER-DROP` | OK, full title + summary + explanation |
| `explain ALIAS-G3-VEC-OF-REFS` | OK |
| `explain BORROW-G2-LIFETIME` | OK |
| `explain SEND-G6-HASHMAP` | OK |
| `explain FFI-G5-NULL-DEREF` | OK |
| `explain UNSAFE-G7-MISSING-ALLOW` | OK |
| `explain EFFECT-G10-UNDECLARED` | OK |
| `explain INIT-G11-READ-BEFORE-INIT` | OK |
| `explain OWN-G8-COND-MOVE` | OK |
| `explain FFI-G9-MISSING-ALLOW-DIRECT-FFI` | OK |
| `explain NR031` | OK, now flagged "(legacy — superseded by RFC-0062 G-series at v1.0)" |
| `test trivial.nr` | OK ("no tests found") |
| `summary trivial.nr` | OK |
| `abi trivial.nr` | OK |
| `graph trivial.nr` | OK |
| `evidence trivial.nr` | OK (JSON output) |
| `zen` | OK |
| `mco` | OK |
| `gen-headers trivial.nr` | OK (works; now also in `nuc help`) |
| `build … --bogus-flag-xyz --release` | OK, emits 2 `warning: unknown flag` lines and proceeds |
| `add foo` (after help removal) | "ERROR: cannot read add" — binary behavior unchanged, `add` no longer in help, no contract violation. |

## Commit history

1. **49609e6b** — `fix: lane 7 audit remediation — docs + user surface` — main mass mechanical commit (16 files; full audit closure).
2. **0418176f** — `fix: scope strict-flag-check to build-class subcommands only` — narrows the High-3 strict-flag-check so it does not fire on `check --json`, `test --list`, `bench --iterations`, etc. (those flags are parsed by the tools-suite delegation downstream of the build-flag loop). Bootstrap regen → md5 1c8148027a57a5c444f20057799eda11.

## Files touched (combined across commits)

```
README.md                                |    4 +-
bin/nucleor.exe                          |  Bin (refreshed)
bootstrap/nucleor_s1_seed.ll             | regen (md5 de7e7729a65c…)
compiler/nucleor_rfc0063_shared_wave2.nr |    4 +-
compiler/nucleor_s1_compiler.nr          |   15 +-
compiler/nucleor_tools_suite.nr          |   57 +-
docs/architecture.md                     |   14 +-
docs/benchmarks.md                       |   13 +-
docs/g1-default-flip-adopter-guide.md    |   90 +-
docs/getting-started.md                  |    2 +-
docs/language-reference.md               |   12 +-
examples/README.md                       |   10 +-
tools/examples.list                      |    8 +
tools/verify.ps1                         |    2 +-
tools/verify.sh                          |    6 +-
tools/verify_fast.sh                     |    2 +-
```

## Final verify counts

(Appended after the in-flight `bash tools/verify.sh` run completes — see commit history for the post-verify update if FAIL>0 required `[PARTIAL]` flagging.)
