# Codex QA Orchestrator Audit v0846 - 2026-05-07

## Scope

This audit reviews the current Nucleor OSS mainline after the recent
multi-agent batch landed under local Claude orchestration.

Repository:

- Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_r05_with_row_v0842`
- Current branch: `integrate/local-claude-r05-with-row-v0842`
- Current HEAD / `origin/main`: `c7a81390476272dd1d293e92a705786606d9460b`
- Prior Codex handoff baseline used for range QA: `4e69c1d3e9596323cc03a2e909375e8dc3f0d553`
- Audited range: `4e69c1d3..c7a81390`

The goal was not to continue feature work. The goal was to assess whether
the work landed in my absence is technically sound, whether the language is
still tracking the punchlist, and whether the repo is currently safe to treat
as green.

## Executive Verdict

The project is still moving in the right direction. The recent batch contains
real fixes, real validation, and mostly honest reporting. The work is not
paper progress.

However, current main is not clean enough to call release-ready from this
Windows/Git-Bash host. Two local verify steps still fail, and the integration
range has a `git diff --check` hygiene failure:

1. `T2.5 lifetime parameters parse cleanly (advisory metadata)` still fails
   through `nuc test` locally. Direct repro exits with Windows heap-corruption
   status `-1073740940` after discovering the four tests.
2. `T3.146 v0.4.115 RFC-0016...` fails through `tools/verify.sh`, even though
   direct builds/runs show the language behavior itself is correct. This is
   likely a harness portability bug caused by `.exe` executable-bit checks.
3. `git diff --check 4e69c1d3..HEAD` fails on `Cloud_Control1.md:233` due to
   a blank line at EOF.

So the honest status is:

- Linux cloud transcript: green according to `Cloud_Control1.md`.
- Local Windows/Git-Bash full verify: not green.
- Core compiler gates: mostly green.
- Release posture: on track, but do not declare final green until the two
  local verify failures and diff-check issue are closed.

## Validation Matrix

Commands run during this audit:

| Check | Result | Notes |
| --- | --- | --- |
| `git status --short --branch` | PASS | Clean worktree tracking `origin/main`. |
| `git log --oneline --decorate -20` | PASS | Confirmed current main at `c7a81390`. |
| `git diff --check 4e69c1d3e9596323cc03a2e909375e8dc3f0d553..HEAD` | FAIL | `Cloud_Control1.md:233: new blank line at EOF.` |
| `bash tools/check_compiler_drift.sh` | PASS | Drift gate green; expected RFC-0063 parser divergence warnings remain. |
| `bash tools/check_rod_void_abi.sh` | PASS | `355 C void nuc_* definitions`, `1275 non-void rod externs checked`. |
| `bash tools/check_self_host_md5.sh` | PASS | `md5=85fc0d224d19ee3c480ed6bb27ac1c37`; seed matches. |
| `pwsh -NoProfile -File tools\check_perf_regression.ps1` | PASS | cold `3.54s`, hot `0.44s`, cold tree `349/400MB`, cold compiler `334/350MB`. |
| `bash tools/verify.sh` | FAIL | Earlier local full run: `PASS: 1301`, `SKIP: 2`, `FAIL: 2`. |
| `bash tools/verify.sh --only "T2.5 lifetime parameters parse cleanly (advisory metadata)"` | FAIL | Exact targeted rerun confirms the step still fails. |
| `bash tools/verify.sh --only "T3.146 v0.4.115 RFC-0016 ..."` | FAIL | Exact targeted rerun confirms harness step still fails. |

The `--only` matcher is exact-string based. Shorter prefix attempts skipped
every step, which is a minor UX trap for agents doing focused retests.

## What Landed Since The Handoff

The recent mainline history shows substantial work across these lanes:

- Cloud Linux release/platform lane:
  - Linux release prerequisite doctor.
  - Linux perf baseline default selection.
  - Native Linux full verify failure classification and fixes.
  - POSIX system exit-code decoding.
  - POSIX `nuc init`, `nuc clean`, link flags, build-id determinism, RNG bridges.
  - R06 cross-platform hash transcript Linux pairing.

- RFC-0063 tools-suite consolidation:
  - Wave 10 retired 18 more duplicates.
  - Wave 11 retired 13 reviewed body-diff helpers.
  - Current documented audit count: `180 duplicates / 30 IDENTICAL / 131 SIG_MATCH_BODY_DIFFERS / 19 SIG_DIFFERS`.

- R05 effects / requires / restricts:
  - Cross-module propagation closed for the flat `import "..."` surface.
  - Same-file method effect enforcement closed for unique-name methods.
  - Requires/restricts transitive depth raised to 8 in the relevant paths.
  - Function-pointer / higher-order residuals documented.

- Real-time / determinism:
  - Cross-module `#[no_alloc]` / `#[no_panic]` reach closed for flat imports.
  - Transitive depth bumped from 4 to 8.
  - Deadline syntax / numeric-bound / WCET audit documented.

- Algebraic laws:
  - Explicit IR-level law optimizer proof gate added.
  - Inverse-law evidence improved.
  - Fusion and float-law issues documented as residual design work.

- Robotics / R06 / Unit / Quantum / ML integration planning:
  - Typed `Transform<From, To>` facade and typed tf/se3 wrappers.
  - R06 hash transcript and FFI lane combined ship.
  - UNIT-1 positive API expansion.
  - QM-7 weight-enumerator citation row.
  - External ML Suite and Translate integration status audits.

The work is broad and mostly coherent. It matches the punchlist structure
rather than drifting into unrelated features.

## High-Priority Findings

### 1. Current main is not locally full-verify green

Local `bash tools/verify.sh` fails two steps:

- `T2.5 lifetime parameters parse cleanly (advisory metadata)`
- `T3.146 v0.4.115 RFC-0016 §3.7 - ? applies From<SrcErr> for DstErr conversion; explicit Into<T> parses`

The cloud Linux control doc reports a full Linux green run:

- `Cloud_Control1.md:189` reports `1293 PASS / 6 SKIP / 0 FAIL`.
- `Cloud_Control1.md:220` reports the same after Wave 11 rebase.

That is useful evidence, but it is not enough. Windows/Git-Bash is still part
of the supported developer surface, and this host currently fails.

Recommended immediate action:

- Stop treating the batch as fully green until both local failures are fixed.
- Require a local Windows/Git-Bash full verify after the fix, not only Linux.

### 2. T2.5 lifetime `nuc test` still crashes locally

Exact targeted verify:

```text
bash tools/verify.sh --only "T2.5 lifetime parameters parse cleanly (advisory metadata)"
...
[ 75/1305] FAIL  T2.5 lifetime parameters parse cleanly (advisory metadata)
PASS: 0
SKIP: 290
FAIL: 1
```

Direct repro:

```text
./bin/nucleor.exe test tests/smoke/t25_lifetime_params.nr
RC=-1073740940
  discovered tests: 4
    test_no_lifetime_baseline
    test_single_lifetime
    test_two_lifetimes
    test_mixed_lifetime_and_type_param
  source: target/t25_lifetime_params-test__test_harness.nr (2132 bytes)
```

Cloud documentation says the Linux T2.5 issue was rooted in tools-suite
`parse_fn_decl` building `gparams` with the wrong list construction pattern
and that this was fixed in `5a263b02`. The local failure means one of these is
still true:

- The tools-suite fix was Linux-specific or incomplete.
- Another lifetime/generic parser path still uses the bad ownership/list
  pattern.
- `nuc test` is dispatching through a stale or divergent tool path on Windows.
- The generated test harness path triggers a different heap corruption than
  the Linux `realloc(2^64-N)` diagnosis.

This is a real issue. It is not just a shell harness false negative.

Recommended immediate action:

- Assign one compiler/tool-suite agent to reproduce only:
  `bin/nucleor.exe test tests/smoke/t25_lifetime_params.nr`
- Compare tools-suite lifetime/generic parsing against s1 beyond
  `parse_fn_decl`, especially paths around generic parameter lists,
  lifetime args, test harness generation, and auto-drop/ownership of borrowed
  parser vectors.
- Do not widen scope until this one fixture exits cleanly and full verify
  no longer fails it.

### 3. T3.146 appears to be a verify harness bug, not a language bug

Exact targeted verify:

```text
bash tools/verify.sh --only "T3.146 v0.4.115 RFC-0016 §3.7 - ? applies From<SrcErr> for DstErr conversion; explicit Into<T> parses"
...
[222/1305] FAIL  T3.146 v0.4.115 RFC-0016 ...
PASS: 0
SKIP: 290
FAIL: 1
```

Direct behavior is correct:

```text
./bin/nucleor.exe build tests/fixtures/repro_question_from_conversion.nr -o _qa_t460_question_from --no-cache
./target/_qa_t460_question_from.exe
RUN_RC1=107

./bin/nucleor.exe build tests/fixtures/repro_into_explicit.nr -o _qa_t460_into_explicit --no-cache
./target/_qa_t460_into_explicit.exe
RUN_RC2=12

./bin/nucleor.exe build tests/err/err_question_missing_from_conversion.nr -o _qa_t460_missing_from --no-cache
BUILD_RC3=1
ERROR: error[TRAIT-001]: missing From<ParseErr> for AppErr conversion required by `?`
```

The suspicious harness lines are:

- `tools/verify.sh:2305`
- `tools/verify.sh:2310`
- `tools/verify.sh:3067`
- `tools/verify.sh:3084`
- `tools/verify.sh:3097`

They still use this pattern:

```sh
[ -x target/foo.exe ] && target/foo.exe || target/foo
```

On Windows/Git-Bash, a file can exist and be runnable via `./target/foo.exe`
while the POSIX executable bit check is not reliable. If `-x` is false, the
harness tries the no-suffix path and fails the step.

Recommended immediate action:

- Replace these with a host-aware helper or use `-f target/foo.exe` before
  trying the no-suffix path.
- Add a small verify self-check or grep gate that prevents this pattern from
  returning.
- Rerun `T3.146` and the three nearby string-method fixtures after the harness
  patch.

### 4. Integration range fails whitespace hygiene

Command:

```text
git diff --check 4e69c1d3e9596323cc03a2e909375e8dc3f0d553..HEAD
```

Result:

```text
Cloud_Control1.md:233: new blank line at EOF.
```

This is mechanically small but important because the project has relied on
`git diff --check` as a fast integration gate.

Recommended immediate action:

- Remove the extra EOF blank line in `Cloud_Control1.md`.
- Rerun the range diff check.

## Medium-Priority Findings

### 5. RFC-0063 is progressing, but remains the largest structural risk

The duplicate audit is much better than earlier waves, but it is not close to
finished:

```text
180 duplicate function names
30 IDENTICAL
131 SIG_MATCH_BODY_DIFFERS
19 SIG_DIFFERS
```

The drift gate still reports parser divergence warnings for major parser
functions. That is currently tolerated, but the T2.5 local failure is exactly
the sort of symptom RFC-0063 was meant to eliminate.

Quality assessment:

- The duplicate retirement work is careful and not sweeping behavior under the
  rug.
- The staged shared-module import pattern is reasonable.
- But parser parity remains a product risk, not just cleanup.

Recommended next action:

- Prioritize parser/test-command unification over more low-risk helper
  deletions until T2.5 is green on both Windows and Linux.
- Treat remaining parser divergences as correctness debt, not just aesthetics.

### 6. Effect-system progress is real, but some paths intentionally fail open

The R05 lane is substantially better:

- Cross-module direct row mismatches now surface for flat imports.
- Bounded transitive helper chains now go to depth 8.
- Unique-name method calls now participate in effect row checking.

The reports are honest about residuals:

- Ambiguous same-name methods fail open.
- Function-pointer indirect calls silently pass.
- Higher-order effect propagation needs AST-level call resolution or effectful
  function types.

This is acceptable only if the punchlist continues to label these as residual
and not as fully closed production semantics.

Recommended next action:

- Keep the unique-name method work.
- Do not mark R05 fully closed until indirect calls and ambiguous receiver
  resolution are either enforced or explicitly outside the v1 launch contract.

### 7. Cloud Linux work is high-value, but validation split is now visible

The Linux work is meaningful:

- It found and fixed real POSIX-only defects: missing `-lm`, missing RNG
  bridges, `mkdir` path separators, `rmdir /S /Q`, ELF build-id determinism,
  POSIX wait-status decoding, hardcoded `target\name.exe`, and path-utils
  Windows assertions.
- It produced full verify transcripts and follow-on reports.
- The R06 Linux transcript paired against the Windows reference.

But current local Windows/Git-Bash gate still fails. This means the
orchestration must require a two-host answer:

- Native Linux cloud full verify.
- Windows/Git-Bash local full verify.

Recommended next action:

- Add an explicit "two-host green" checkbox to `Cloud_Control1.md` or the
  active orchestration doc.
- Any "green" claim should name the host and exact command.

### 8. Performance remains inside target but headroom is tight

Latest perf gate from this audit:

```text
cold 3.54s
hot 0.44s
cold_tree 349/400MB
cold_compiler 334/350MB
hot_tree 58/128MB
hot_compiler 43/64MB
```

This is within the sub-4s cold target and within memory caps. It is also close
enough to the compiler RSS cap that broad compiler changes need perf checking.

Quality assessment:

- Recent work did not blow the cold compile target.
- The caps are doing useful work.
- Future RFC-0063/parser work should look for memory wins while fixing
  correctness, especially if parser unification reduces duplicate IR.

Recommended next action:

- Keep perf gate mandatory for compiler/tool-suite edits.
- Avoid raising the local Windows compiler RSS cap unless there is a
  documented, temporary reason.

### 9. Python helper policy appears respected in the product path

I scanned for Python usage after the prior "no Python helpers" guidance.
Current product/toolchain path does not appear to have added a new required
Python helper dependency for Nucleor itself.

The punchlist now explicitly says:

- Product/toolchain Python compare dependency is done.
- Python interop rod remains intentional.
- Maintenance `tools/*.py` can remain for now.

That matches the user's stated policy: Python interop is fine; Python as a
required helper for running Nucleor is not.

## Workstream Quality Assessment

### Cloud_Control1 / Linux Orchestration

Quality: good, with one hygiene failure.

The control document is useful and concrete. It records host, branch, base,
tools, files, validation, residuals, and reports. It does not just say "done."

Weaknesses:

- It currently has a diff-check EOF blank-line failure.
- It can make the project look greener than it is if read without the local
  Windows/Git-Bash verify result.

### RFC-0063 Tools-Suite Dedup

Quality: cautiously good, but still risky.

The agents are deleting/importing reviewed sets, not blindly deleting every
duplicate. The reports note disjoint sets and structural conflicts honestly.

Weaknesses:

- Remaining duplicate count is still high.
- Parser divergence remains.
- T2.5 crash suggests the tools-suite/parser boundary is still fragile.

### Effects / Requires / Restricts

Quality: good progress, honest residuals.

The work materially expands enforcement and added fixtures for direct,
transitive, cross-module, and method cases.

Weaknesses:

- Ambiguous method names fail open.
- Function-pointer/higher-order paths still silently pass.
- This is not yet a complete effect-system story.

### RT / Determinism

Quality: solid bounded closure.

Cross-module and depth-bump work is the right shape: small compiler changes,
focused negative fixtures, and punchlist updates.

Weaknesses:

- Deadline numeric/certified WCET remains design/proof work.
- Closure/fn-pointer escape paths overlap with the R05 residuals.

### Algebraic Laws

Quality: safer than before.

The IR-level law-opt proof gate is the right direction because it prevents
metadata-only law capture from being mistaken for optimizer behavior.

Weaknesses:

- Fusion and float epsilon semantics remain open by design.
- The current law system should be described as bounded/proof-gated, not
  general algebraic rewriting.

### Robotics / Quantum / Units / R06

Quality: generally good.

The stdlib/API expansions are conservative and fixture-backed. The quantum
work is careful about citation boundaries. R06 hash transcript moved from
platform hope to byte-transcript evidence.

Weaknesses:

- ROBO-7 generic phantom unification is still a blocker for fully typed
  frame algebra.
- UNIT full dimension algebra is still a design blocker.
- QASM import and external enumerator parity are future work unless launch
  artifacts explicitly require them.

## Are We Still Tracking The Punchlist?

Yes, directionally. The agents are mostly working on the right lanes:

- RFC-0063 production readiness
- R05 effects / requires / restricts
- RT determinism
- Laws
- PKG / Linux release proof
- R06 Rust/FFI proof
- ROBO-7 typed frame work
- UNIT/QM/ML/Translate audit closures

The issue is not drift away from the punchlist. The issue is gate discipline:
some workstreams are being marked green from a host-specific validation lane
while another supported host still fails.

The punchlist should be updated or interpreted with this rule:

> A lane is not globally green until both the Linux cloud path and the local
> Windows/Git-Bash path are green, or until the lane explicitly states it is
> host-specific.

## Immediate Repair Queue

Recommended ordering:

1. Fix `tools/verify.sh` executable selection for Windows/Git-Bash:
   replace the five remaining `[ -x target/*.exe ] && ... || target/no-suffix`
   patterns.
2. Rerun:
   `bash tools/verify.sh --only "T3.146 v0.4.115 RFC-0016 §3.7 - ? applies From<SrcErr> for DstErr conversion; explicit Into<T> parses"`
3. Fix the T2.5 `nuc test` crash:
   focus on tools-suite parser/generic/lifetime/test-harness paths.
4. Rerun:
   `bash tools/verify.sh --only "T2.5 lifetime parameters parse cleanly (advisory metadata)"`
5. Remove the extra blank line at EOF in `Cloud_Control1.md`.
6. Rerun:
   `git diff --check 4e69c1d3e9596323cc03a2e909375e8dc3f0d553..HEAD`
7. Rerun full:
   `bash tools/verify.sh`
8. Rerun core gates:
   `bash tools/check_compiler_drift.sh`
   `bash tools/check_rod_void_abi.sh`
   `bash tools/check_self_host_md5.sh`
   `pwsh -NoProfile -File tools\check_perf_regression.ps1`

Do not batch new feature work into this repair branch. Keep it a small
verification-closure patch.

## Assignment Recommendations

If Claude remains the local orchestrator:

### Agent A - Local harness repair

Scope:

- `tools/verify.sh`
- optionally `tools/verify_fast.sh` if the same pattern is present there

Tasks:

- Add a helper for running generated target binaries.
- Replace all remaining `.exe` executable-bit fallbacks.
- Add a grep/smoke guard so the bad pattern cannot come back.
- Validate T3.146 and the three string-method fixtures around lines 3067,
  3084, and 3097.

### Agent B - T2.5 tools-suite parser crash

Scope:

- `compiler/nucleor_tools_suite.nr`
- generated `target/t25_lifetime_params-test__test_harness.nr` inspection
- compare against `compiler/nucleor_s1_compiler.nr`

Tasks:

- Reproduce `bin/nucleor.exe test tests/smoke/t25_lifetime_params.nr`.
- Identify whether crash is parser, generated harness, auto-drop, or tools
  dispatch.
- Patch the smallest divergence.
- Validate T2.5 directly and through `tools/verify.sh --only`.
- Run drift, self-host, and perf if compiler/tool-suite source changes.

### Agent C - Orchestration hygiene

Scope:

- `Cloud_Control1.md`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/v1_REMAINING_PUNCHLIST_AGENT_HANDOFF_v0845_2026-05-07.md`

Tasks:

- Fix EOF whitespace.
- Add explicit local Windows/Git-Bash gate status.
- Mark local full verify as not green until T2.5/T3.146 are closed.
- Preserve Linux green evidence without overclaiming global green.

### Agent D - RFC-0063 parser risk audit

Scope:

- Parser functions still reported as divergent by drift gate.
- Duplicate report `tools/audit_dup_fns_report.csv`.
- RFC-0063 roadmap status.

Tasks:

- Do not retire more random low-risk duplicates first.
- Identify parser divergences most likely to affect `nuc test`,
  generics/lifetimes, and error recovery.
- Produce a short prioritized parser-unification queue.

## Final Assessment

The recent work is mostly high quality. The language is not wandering off
course; it is converging on the punchlist. The Linux lane especially did real
work by converting platform failures into specific patches and a green Linux
transcript.

But the repo should not be called clean right now. The correct engineering
stance is:

- Continue, but pause broad feature merges.
- Fix the two local verify failures.
- Fix diff-check hygiene.
- Then re-run full local verification and compare with the Linux cloud green
  transcript.

Once those are closed, the batch becomes much more credible as a stable
forward point.
