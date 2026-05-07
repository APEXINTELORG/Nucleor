# Nucleor v1.0 Remaining Punchlist Agent Handoff v0845

**Date:** 2026-05-07
**Purpose:** Detailed loop-safe handoff for Claude/Codex agents closing the remaining v1.0 punchlist.
**Canonical live source:** `docs/rfcs/v1_PUNCHLIST.md`
**Supporting roadmap:** `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
**Created from main:** `5d8d1bab4b4ee9fdefe362e732c899277c38e4cd`

This document supersedes older dispatch packs for remaining-work routing.
Older packs are useful for history, but many of their estimates and open
items are stale after v0838-v0844 integration. Agents must start from
current `origin/main` and verify the live punchlist before editing.

## Executive State

The v1.0 punchlist is mostly closed. The remaining work is concentrated in
these areas:

1. RFC-0063 parser/tools-suite duplicate retirement and eventual parser
   single-source-of-truth.
2. Effects/capabilities beyond bounded same-file enforcement.
3. Real-time/determinism beyond bounded same-file helper checks.
4. Algebraic laws beyond bounded integer checks and metadata capture.
5. ROBO-7 final typed transform migration.
6. T-3/T-4 strict type-system tail.
7. UNIT-1 full dimensional type-system tail.
8. R06/FFI future ownership and unsafe/direct-FFI contract work.
9. General CI/Linux proof/polish.
10. Quantum/ML/Translate documentation tail and explicit future-work fences.

Best current completion estimate for the core v1.0 punchlist is about
88-90 percent. The remaining percentage is not evenly distributed: RFC-0063
is the largest engineering block, while several other lanes are narrower
closure or proof tasks.

## Non-Negotiable Operating Rules

### One Agent, One Worktree

Do not let multiple agents edit the same checkout. Prior attempts lost work
because several agents checked out and reset branches in one shared tree.
Every agent gets its own clone or `git worktree`.

Recommended local pattern:

```powershell
cd C:\Users\JoeWe\Desktop
git clone https://github.com/APEXINTELORG/Nucleor.git Nucleor_AGENT_<name>_<lane>_v0845
cd Nucleor_AGENT_<name>_<lane>_v0845
git fetch origin
git checkout -B <agent-branch> origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Alternative from an existing clean repo:

```powershell
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS worktree add C:\Users\JoeWe\Desktop\Nucleor_AGENT_<name>_<lane>_v0845 origin/main
cd C:\Users\JoeWe\Desktop\Nucleor_AGENT_<name>_<lane>_v0845
git checkout -B <agent-branch>
git status --short --branch
git merge-base HEAD origin/main
```

If `git status --short --branch` is not clean before starting, stop and fix
the worktree isolation problem first.

### Branch And Queue Protocol

Agents may loop through multiple queues only when the next queue does not
depend on unmerged code from their previous queue. If the next queue depends
on unmerged code, push the branch and stop for integration.

For each queue:

```bash
git fetch origin
git checkout -B <queue-branch> origin/main
git merge-base HEAD origin/main
git status --short --branch
```

After work:

```bash
git status --short --branch
git diff --check
git push origin HEAD:<queue-branch>
```

Report all of:

- Branch name.
- HEAD SHA.
- `origin/main` SHA used.
- Merge-base with `origin/main`.
- Changed files.
- Exact validation commands.
- Exact pass/fail result.
- Residual blockers.

### Report File Contract

Every queue writes one report under `findings/inbox/`:

```text
findings/inbox/<agent>_<lane>_<queue>_v0845_2026-05-07.md
```

The report must include:

- Scope accepted.
- Scope explicitly not taken.
- Base/HEAD/merge-base.
- Host OS and shell.
- Commands run.
- Validation transcript summary.
- Performance numbers if relevant.
- Files changed.
- Any honest residuals.

Do not update `findings/heartbeat.json` unless the queue explicitly owns a
heartbeat. Most closure queues should avoid heartbeat churn.

### No Python Helpers In Product Or Toolchain Paths

Do not add Python requirements or Python helper scripts to normal product,
compiler, bootstrap, release, or verification paths. Python interop in
`stdlib/rods/python.nr` and its runtime is intentional and out of scope.
Existing maintenance Python scripts can be referenced, but new closure work
should use Nucleor, shell, PowerShell, or existing repo tools.

### Performance Rule

Always keep cold compile and memory tight. Do not fixate on performance at
the expense of correctness, but every compiler/tools/cache/hot-path change
must run the perf gate:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Current Windows guard expectations:

- Cold compile must remain under 4 seconds.
- Cold process-tree RSS must remain under 400 MB.
- Cold compiler RSS must remain under 350 MB.
- Hot compile and hot RSS must remain under their gate caps.

If the compiler binary or bootstrap seed changes, regenerate through the
normal path and run self-host fixed-point:

```bash
bash tools/check_self_host_md5.sh
bash tools/check_compiler_drift.sh
```

Do not delete binary/generated artifacts just to shrink a diff. If an artifact
is meant to be promoted, regenerate and prove it.

### Linux Proof Rule

Linux proof lanes must run on true native Linux. No WSL, no Wine, no copied
Windows `.exe` artifacts, and no fake green transcript. Include:

```bash
uname -a
command -v clang
command -v pwsh
command -v ssh-keygen
command -v cargo
```

If a Linux prerequisite is missing, either install it in the cloud environment
or write a blocker with the exact missing tool and the smallest docs/tooling
patch needed.

### Full Verify Rule

`tools/verify.sh` is the canonical full gate. `tools/verify.ps1` can lag
newer bash-gate additions.

Run focused validation for every queue. Run full validation after large
batch integration, compiler promotion, or before a release/tag:

```bash
bash tools/verify.sh
```

When full verify is not run, say so plainly.

## Current High-Value Agent Split

Use this split if multiple agents are available:

| Agent | Lane | Collision Risk | Priority |
|---|---|---:|---:|
| Helper2 | RFC-0063 tools-suite unification Wave 10+ | High inside tools-suite only | 1 |
| Claude A | Effects/capabilities cross-module and methods | High with compiler lanes | 2 |
| Claude B | Real-time/determinism closure | High with compiler lanes | 3 |
| Claude C | Algebraic laws Phase 3/4 closure | Medium compiler/tools | 4 |
| Claude D | ROBO-7 typed transform migration | Medium stdlib/compiler | 5 |
| Helper3 | T-3/T-4 and UNIT-1 strict tails | Medium compiler/stdlib | 6 |
| Cloud Linux | CI/Linux proof and release validation | Low if docs/tools only | 7 |
| Optional Agent | R06/FFI future contract | Medium runtime/compiler | 8 |

Do not run two agents against the same file set unless each has its own
worktree and the integration owner is prepared to rebase/conflict-resolve.

## Lane 1 - RFC-0063 Parser/Tools-Suite Unification

### Current State

Live punchlist state after v0844 Wave 9:

- `204` duplicate function names remain.
- `44` are `IDENTICAL` safe-delete/import candidates.
- `144` are `SIG_MATCH_BODY_DIFFERS` review/replace candidates.
- `16` are `SIG_DIFFERS` per-function lift/adapter candidates.
- `compiler/nucleor_rfc0063_shared_wave1.nr` is the current shared module.
- `compiler/nucleor_tools_suite.nr` imports the shared module.
- The s1 compiler remains canonical for the moved helper batches.

Key files:

- `compiler/nucleor_tools_suite.nr`
- `compiler/nucleor_s1_compiler.nr`
- `compiler/nucleor_rfc0063_shared_wave1.nr`
- `tools/audit_dup_fns.nr`
- `tools/audit_dup_fns_report.csv`
- `tools/check_compiler_drift.sh`
- `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- `docs/rfcs/v1_PUNCHLIST.md`

### Queue 1A - Wave 10 Identical Duplicate Retirement

Branch:

```text
fix/helper2-rfc0063-tools-suite-wave10-v0845
```

Goal:

- Move or delete the remaining `IDENTICAL` duplicate candidates that are safe
  under the current import strategy.
- Prefer coherent mechanical batches over one-function commits.
- Do not touch parser core functions unless the audit proves they are in this
  batch and the compile/CLI gates remain green.

Required work:

1. Run the current audit:

   ```powershell
   .\bin\nucleor.exe build tools\audit_dup_fns.nr -o audit_dup_fns --no-cache
   .\target\audit_dup_fns.exe
   ```

2. Identify a safe set of remaining `IDENTICAL` rows.
3. Move canonical definitions into `compiler/nucleor_rfc0063_shared_wave1.nr`
   if needed, or delete raw tools-suite copies if already imported.
4. Rebuild tools suite:

   ```powershell
   .\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
   ```

5. Re-run audit and update `tools/audit_dup_fns_report.csv`.
6. Update `docs/rfcs/RFC-0063-production-readiness-roadmap.md` and
   `docs/rfcs/v1_PUNCHLIST.md`.
7. Write report under `findings/inbox/`.

Validation:

```bash
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
```

If tools-suite hot path changes materially:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Exit criteria:

- Tools-suite builds.
- Audit counts decrease.
- No stale count claims in docs.
- Branch pushed clean.

Stop condition:

- If duplicate-name import collisions require broad parser surgery, write a
  blocker instead of forcing a risky giant patch.

### Queue 1B - Same-Signature Body-Diff Review Batch

Branch:

```text
fix/helper2-rfc0063-tools-suite-wave11-v0845
```

Goal:

- Retire a reviewed subset of the `144` `SIG_MATCH_BODY_DIFFERS` candidates.
- Accept only cases where body differences are comments, formatting, dead
  legacy behavior, or a clearly obsolete tools-suite variant.

Required work:

1. Generate/review candidate rows from `tools/audit_dup_fns_report.csv`.
2. For each chosen function, record why s1 canonical behavior is valid.
3. Move to shared module or delete tools-suite copy.
4. Rebuild tools suite and re-run audit.
5. Update roadmap and punchlist counts.
6. Write report with before/after counts and candidate names.

Validation:

```bash
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
```

Plus focused tools commands if available in the current CLI surface:

```powershell
.\bin\nucleor.exe check examples\01_hello.nr
.\bin\nucleor.exe build-strict examples\01_hello.nr
.\bin\nucleor.exe abi inspect stdlib\rods\quantum.nr
```

If any of these command spellings differ, report the exact supported
replacement instead of inventing success.

### Queue 1C - SIG_DIFFERS Decision Table

Branch:

```text
probe/helper2-rfc0063-sig-differs-decision-table-v0845
```

Goal:

- Do not implement first. Produce a decision table for the `16` `SIG_DIFFERS`
  functions.
- Classify each as:
  - s1 canonical,
  - tools-suite canonical,
  - needs adapter,
  - do not merge,
  - needs design blocker.

Deliverable:

```text
findings/inbox/helper2_rfc0063_sig_differs_decision_table_v0845_2026-05-07.md
```

This can run in parallel with Queue 1A if it stays read-only except for the
report.

## Lane 2 - Effects And Capabilities

### Current State

Already closed:

- `pure fn` direct print/alloc/ambient effects.
- Pure same-file bounded transitive helpers.
- Pure calls to same-file functions declaring `requires [...]`.
- Standalone `requires [...]` direct/body/helper enforcement for known builtin
  effects.
- Block-form `restricts [...] { ... }` direct and bounded same-file helper
  enforcement up to depth 8.
- Family/sub-effect diagnostics for current matched tokens.

Still open:

- Full standalone `requires [...]` enforcement beyond bounded same-file
  direct/body/helper calls.
- Restricts chains beyond depth 8.
- Deeper transitive `requires [...]` row propagation.
- Cross-module propagation.
- Methods, closures, function pointers, higher-order effects.
- Broader RFC-0033 effect-row subtyping.

Key files:

- `compiler/nucleor_s1_compiler.nr`
- `tests/err/err_effect*.nr`
- `tests/err/err_requires*.nr`
- `tests/err/err_restricts*.nr`
- `tests/features/*requires*`
- `tests/features/*restricts*`
- `tools/verify.sh`
- `docs/rfcs/RFC-0032-effects.md`
- `docs/rfcs/RFC-0033-effects-in-function-types.md`
- `docs/rfcs/v1_PUNCHLIST.md`

### Queue 2A - Cross-Module Requires Propagation Probe

Branch:

```text
probe/effects-cross-module-requires-v0845
```

Goal:

- Determine the smallest safe compiler hook for same-package cross-module
  `requires [...]` propagation.
- Prefer a probe/report first unless the implementation is obviously small.

Required work:

1. Create two-file fixtures:
   - negative: caller module omits required row from imported callee,
   - positive: caller declares compatible row.
2. Check whether current module import/type data exposes callee source rows.
3. If yes, implement a narrow same-package check.
4. If no, write a blocker naming the missing table/API and the smallest
   compiler data structure needed.

Validation:

```powershell
.\bin\nucleor.exe build <negative-fixture> --no-cache
.\bin\nucleor.exe build <positive-fixture> -o <tmp> --no-cache
.\target\<tmp>.exe
```

If compiler changes:

```bash
bash tools/check_self_host_md5.sh
bash tools/check_compiler_drift.sh
git diff --check
```

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Stop condition:

- If cross-module effect rows require a broad import metadata redesign, write
  the finding and stop.

### Queue 2B - Method And Impl Effect Enforcement

Branch:

```text
fix/effects-method-requires-restricts-v0845
```

Goal:

- Extend current direct/body/helper checks to method calls where the callee is
  statically resolvable in the same file.

Minimum fixture set:

- negative: method body uses `print_int` under incompatible `requires [net]`.
- negative: `restricts [io.write] { obj.method(); }` reaches method I/O.
- positive: method with matching declared row.

Validation:

- Focused fixtures.
- Compiler drift.
- Self-host if compiler promoted.
- Perf gate.

### Queue 2C - Higher-Order/Fn-Pointer Finding

Branch:

```text
probe/effects-higher-order-fn-pointer-v0845
```

Goal:

- Do not overbuild. Produce an explicit design finding for closures/function
  pointers: current representation, what effect metadata is missing, and the
  smallest v1.0-safe fail-closed rule.

Recommended outcome:

- Either implement a conservative diagnostic for obvious direct fn-pointer
  calls lacking an effect row, or document why this belongs in Phase 4.

## Lane 3 - Real-Time And Determinism

### Current State

Closed:

- Bounded same-file `#[no_alloc]` and `#[no_panic]` helper-chain checks.

Still open:

- Cross-module callees.
- Closures and function pointers.
- Deeper-than-bound helper paths.
- `#[deadline]` numeric and certified-WCET backing.
- Broader RT attribute enforcement audit.

Key files:

- `compiler/nucleor_s1_compiler.nr`
- `docs/rfcs/RFC-0001-rt-attributes.md`
- `tests/err/err_no_alloc*.nr`
- `tests/err/err_no_panic*.nr`
- `tests/features/no_alloc*.nr`
- `tools/verify.sh`

### Queue 3A - Cross-Module no_alloc/no_panic Probe

Branch:

```text
probe/rt-cross-module-noalloc-nopanic-v0845
```

Goal:

- Determine if imported functions expose enough body/attribute metadata to
  enforce `#[no_alloc]` / `#[no_panic]` across modules.

Deliverable:

- If small: implement same-package static imported helper check.
- If not: report exact missing metadata and a Phase 4 implementation plan.

Minimum fixtures:

- negative imported helper allocates under `#[no_alloc]`.
- negative imported helper panics under `#[no_panic]`.
- positive imported helper is clean.

Validation:

- Focused fixtures.
- Drift/self-host/perf if compiler changes.

### Queue 3B - Deadline Syntax And Numeric Bound Audit

Branch:

```text
probe/rt-deadline-numeric-wcet-audit-v0845
```

Goal:

- Audit current `#[deadline]` syntax, parse path, storage, and enforcement.
- Produce a concrete closure path for numeric validation and certified-WCET
  backing.

Do not fabricate WCET. If no certified routine-cost table exists, write the
blocker and specify the table shape.

### Queue 3C - RT Deep Bound Policy

Branch:

```text
fix/rt-depth-bound-disclosure-v0845
```

Goal:

- Align diagnostics/docs/tests around the exact bounded depth currently
  enforced.
- Add a fixture that proves one past the bound remains documented future work,
  or fail closed if the compiler can cheaply raise the bound without perf
  regression.

## Lane 4 - Algebraic Laws

### Current State

Closed:

- `@law(...)` lex capture.
- Metadata-only optimizer scaffold.
- Bounded `nuc test --check-laws` integer checks for low-risk forms.
- Fail-closed unsupported canonical forms/aliases.
- Some optimizer identity eligibility wiring.

Still open:

- Arbitrary-driven broad property tests.
- `distributive_over`, `inverse`, `fusion` generation.
- Float `eps` / approximate semantics.
- Optimizer rewrite gating.
- Cert-profile SMT/proof obligations and float-law safeguards.

Key files:

- `compiler/nucleor_s1_compiler.nr`
- `compiler/nucleor_tools_suite.nr`
- `docs/rfcs/RFC-0042-algebraic-laws.md`
- `tests/features/*law*.nr`
- `tests/err/*law*.nr`
- `tools/verify.sh`

### Queue 4A - Law Optimizer Rewrite Gate

Branch:

```text
fix/laws-optimizer-rewrite-gate-v0845
```

Goal:

- Make any optimizer rewrite gated by successful law validation metadata.
- If rewrite execution is not currently active, add a fail-closed guard and
  fixture proving unvalidated laws do not enable rewrites.

Validation:

- Existing law fixtures.
- New negative/positive optimizer-gate fixture.
- Drift/perf if compiler changes.

### Queue 4B - Inverse/Fusion Property Pack

Branch:

```text
fix/laws-inverse-fusion-property-pack-v0845
```

Goal:

- Add bounded integer property-generation support for `inverse` and `fusion`
  only if the syntax and semantics are already documented enough.
- Otherwise write a finding defining required syntax and examples.

Do not accept ambiguous law syntax silently.

### Queue 4C - Float Approx Semantics Finding

Branch:

```text
probe/laws-float-approx-semantics-v0845
```

Goal:

- Produce a design report for `eps` / approximate law semantics.
- Must include why exact float laws are unsafe, which diagnostics should fire,
  and what small v1.0 profile is acceptable.

## Lane 5 - ROBO-7 Typed Transform Migration

### Current State

Closed:

- `Frame_*` marker structs.
- `Pose<Frame_X>` mismatch diagnostics across many sites.
- `kinematics.nr` typed-pose facade and transform helpers.

Still open:

- Migrate remaining raw `tf.nr` and `se3.nr` surfaces from integer frame IDs
  and pointer tuples to typed transform wrappers.
- Define `Transform<From, To>`.
- Add FRAME-002/FRAME-003 diagnostics if needed.
- Deprecate `Frame_Unknown` for v1.0 hard-error posture.

Key files:

- `stdlib/rods/kinematics_frame.nr`
- `stdlib/rods/kinematics.nr`
- `stdlib/rods/tf.nr`
- `stdlib/rods/se3.nr`
- `compiler/nucleor_s1_compiler.nr`
- `tests/features/robo7*.nr`
- `tests/err/err_robo7*.nr`

### Queue 5A - Transform<From, To> Facade

Branch:

```text
fix/robo7-typed-transform-facade-v0845
```

Goal:

- Add a zero-cost `Transform<From, To>` facade compatible with existing
  transform handles.
- Add helpers for construction, inversion, and composition that preserve
  frame order.

Minimum fixtures:

- positive: compose base->camera with camera->tool gives base->tool.
- positive: invert base->camera gives camera->base.
- negative: incompatible composition fails with FRAME diagnostic if compiler
  support exists; otherwise write blocker and add runtime preflight fixture.

### Queue 5B - tf.nr Migration Layer

Branch:

```text
fix/robo7-tf-typed-wrapper-v0845
```

Goal:

- Add typed wrappers over the existing `tf.nr` timestamped lookup path.
- Preserve existing raw APIs for compatibility but document them as migration
  surfaces.

Validation:

- Existing TF timestamped fixture.
- New typed lookup fixture.
- Existing ROBO-7 frame fixtures.

### Queue 5C - se3.nr Migration Layer

Branch:

```text
fix/robo7-se3-typed-wrapper-v0845
```

Goal:

- Add typed wrappers over `se3.nr` transform construction/composition.
- Do not break existing raw `se3` users.

Stop condition:

- If compiler generic/frame diagnostics need broad changes, stop after facade
  plus finding rather than merging unsafe behavior.

## Lane 6 - T-3/T-4 And UNIT-1 Strict Type Tail

### Current State

T-3/T-4 closed:

- Const-foldable invalid char casts now emit `TYP-026`.
- Strict inference knows many core, IO/path, format/string, numeric/f64 helper
  return types.

T-3/T-4 open:

- Runtime/IR char distinctness.
- Non-constant char-cast proof.
- Strict empty-type compatibility beyond covered helper returns.

UNIT-1 closed:

- Fail-closed archive guard for major erased-storage hazards.
- Positive `UnitDistance` / `UnitVelocity` API partial.

UNIT-1 open:

- Full parser/type-checker dimension algebra for `unit<T, dim>`.
- UNIT-001..005 semantic diagnostics.
- 7-vector lowering.
- Literal suffix support.
- Broader positive typed-unit API coverage.

### Queue 6A - Non-Constant Char Cast Proof

Branch:

```text
fix/t3-nonconstant-char-cast-proof-v0845
```

Goal:

- Add diagnostics for non-constant `as char` when the compiler cannot prove
  the value is in Unicode scalar range.
- Prefer fail-closed for uncertain values if the RFC requires safety.

Fixtures:

- negative: variable-derived invalid or unproven char cast.
- positive: range-guarded value if current compiler can prove it.
- positive: existing valid constant path remains green.

### Queue 6B - T-4 Strict Remaining Helper Return Sweep

Branch:

```text
fix/t4-strict-helper-return-sweep-v0845
```

Goal:

- Audit remaining helper calls that still infer empty/unknown types under
  strict mode.
- Add return-type entries and focused positive fixture batches.

Validation:

- Focused strict fixtures.
- Drift/self-host/perf if compiler changes.

### Queue 6C - UNIT Positive API Expansion

Branch:

```text
fix/unit1-positive-api-expansion-v0845
```

Goal:

- Expand nominal unit APIs without attempting full parser/type algebra.
- Add acceleration/time/mass or dimension-safe helpers only if they preserve
  the current zero-surprise contract.

Validation:

- Existing `err_unit_*` negatives.
- Existing positive unit smokes.
- New positive coverage.

### Queue 6D - UNIT Full Algebra Design Blocker

Branch:

```text
probe/unit1-full-dimension-algebra-design-v0845
```

Goal:

- Write the implementation plan for `unit<T, dim>`, diagnostics,
  7-vector lowering, and literal suffixes.
- Do not start broad parser surgery unless separately assigned.

## Lane 7 - R06 / FFI Contract

### Current State

Closed:

- POSIX `rust_bridge` ownership proof on native Linux.
- Harness covers all seven Rust string-returning bridge functions.
- 70,000 alloc/free cycles through `rust_free_str`.
- Valgrind evidence shows no definite/indirect leaks for targeted fixtures.

Still open:

- Cross-platform hash byte transcript pairing Windows + POSIX.
- RFC-0062 Phase 2b/4 `unsafe` / `#[allow(direct_ffi)]` enforcement.
- Concurrent ownership stress.
- Broader cross-boundary ownership contract for Python/shared-library FFI.

### Queue 7A - Windows/POSIX Hash Transcript Pairing

Branch:

```text
fix/r06-cross-platform-hash-transcript-v0845
```

Goal:

- Produce a paired transcript format proving Windows and POSIX bridge outputs
  match byte-for-byte for hash/control fixtures.
- If Linux execution is required, leave Windows-side patch plus cloud handoff.

### Queue 7B - direct_ffi Allowance Enforcement Probe

Branch:

```text
probe/r06-direct-ffi-allowance-enforcement-v0845
```

Goal:

- Audit how direct FFI calls are represented in the compiler.
- Add a conservative diagnostic only if the hook is clear.
- Otherwise write a finding with exact parser/type-check hook needed.

### Queue 7C - Concurrent rust_bridge Stress

Branch:

```text
fix/r06-rust-bridge-concurrent-stress-v0845
```

Goal:

- Add opt-in stress coverage for concurrent string return/free behavior.
- Keep it out of default verify if it is slow or environment-sensitive.

## Lane 8 - Linux / CI / Release Proof

This lane is best for cloud agents on native Linux.

### Queue 8A - Platform-Aware POSIX Perf Baseline Selection

Branch:

```text
fix/linux-perf-platform-baseline-select-v0845
```

Goal:

- `tools/check_perf_regression.sh` should select
  `tools/perf_baseline_linux.json` by default on true Linux where appropriate.
- It must continue refusing WSL/Wine/Windows `.exe` RSS evidence.

Validation:

```bash
uname -a
bash tools/check_perf_regression.sh
bash tools/verify.sh --only "POSIX cold/hot perf regression"
```

### Queue 8B - Linux Prerequisite Doctor

Branch:

```text
fix/linux-release-prereq-doctor-v0845
```

Goal:

- Add a small shell/PowerShell doctor or docs section for Linux release
  prerequisites: `pwsh`, `ssh-keygen`, clang, cargo, `bin/nucleor`,
  `bin/nucleor_tools`.
- No Python helper.

### Queue 8C - Full Native Linux Verify Transcript

Branch:

```text
probe/linux-full-verify-transcript-v0845
```

Goal:

- Run full `bash tools/verify.sh` on native Linux from current main.
- If it fails, file one report with exact failures and classify:
  - Windows-only fixture,
  - missing Linux prerequisite,
  - real compiler/runtime bug,
  - performance-only drift.

Do not patch unrelated failures in the transcript branch unless the fix is
small and deterministic.

## Lane 9 - Quantum Tail / Future-Work Fences

### Current State

QM-7 has deterministic Clifford tests, rotated Surface-17 d=3, bounded
weight-enumerator helpers, bounded property micro-suite, OpenQASM 2.0 emit,
and minimal deterministic parser round-trip.

Still open:

- Optional citation-backed external published weight-enumerator parity row if
  launch docs require it.
- General foreign-source OpenQASM 2.0 import remains future work.
- QM-6 true external-sink/callback streaming is future work.
- Several quantum rods have documented future native/backend gaps.

### Queue 9A - Citation-Backed QM-7 Enumerator Row

Branch:

```text
fix/qm7-enumerator-citation-row-v0845
```

Goal:

- Add a documentation/evidence row tying the in-tree bounded enumerator to a
  citation-backed external source if a reliable source is already in docs or
  can be cleanly cited.
- Do not change runtime math unless a real mismatch is found.

### Queue 9B - Quantum Future-Work Fence Audit

Branch:

```text
probe/quantum-future-work-fence-audit-v0845
```

Goal:

- Audit quantum docs and fixtures for overclaims.
- Ensure foreign OpenQASM import, density-matrix/Kraus backend, backend
  scheduler, hardware target lowering, and per-graph handles are clearly
  future work where not implemented.

## Lane 10 - External ML Suite / Translate Visibility

### Current State

The external ML Suite and Nucleor Translate are acknowledged as adjacent work.
They are not to be imported wholesale into `Nucleor_OSS`. The current rule is:

- ML Suite code remains external.
- Nucleor Translate is pull-in gated on completion plus revalidation before
  any `nuc port` shim.

### Queue 10A - External ML Suite Status Audit

Branch:

```text
probe/external-ml-suite-status-audit-v0845
```

Goal:

- Identify the current canonical ML Suite repo(s) on disk.
- Produce a status matrix mapping external ML Suite surfaces to Nucleor OSS
  substrate needs.
- Do not import code into Nucleor OSS.

Report:

```text
findings/inbox/external_ml_suite_status_audit_v0845_2026-05-07.md
```

### Queue 10B - Translate Integration Gate

Branch:

```text
probe/nucleor-translate-integration-gate-v0845
```

Goal:

- Identify what validation Nucleor Translate must pass before any OSS shim is
  accepted.
- Produce a gate checklist, not implementation.

## Suggested Loop Assignments

If several agents are available, dispatch like this:

### Helper2

1. Queue 1A - RFC-0063 Wave 10 identical duplicate retirement.
2. Queue 1B - RFC-0063 Wave 11 reviewed same-signature body-diff batch.
3. Queue 1C - SIG_DIFFERS decision table if implementation queues block.

### Local Claude 1

1. Queue 2A - effects cross-module requires propagation probe.
2. Queue 2B - method/impl effect enforcement.
3. Queue 2C - higher-order/fn-pointer finding.

### Local Claude 2

1. Queue 3A - RT cross-module no_alloc/no_panic probe.
2. Queue 3B - deadline numeric/WCET audit.
3. Queue 3C - RT deep-bound policy.

### Local Claude 3

1. Queue 4A - law optimizer rewrite gate.
2. Queue 4B - inverse/fusion property pack.
3. Queue 4C - float approximate semantics finding.

### Helper3

1. Queue 6A - non-constant char-cast proof.
2. Queue 6B - T-4 strict helper return sweep.
3. Queue 6C - UNIT positive API expansion.
4. Queue 6D - UNIT full algebra design blocker.

### Optional Local Agent

1. Queue 5A - ROBO-7 Transform facade.
2. Queue 5B - typed `tf.nr` wrapper.
3. Queue 5C - typed `se3.nr` wrapper.

### Cloud Linux Agent

1. Queue 8A - platform-aware POSIX perf baseline selection.
2. Queue 8B - Linux prerequisite doctor.
3. Queue 8C - full native Linux verify transcript.

### Optional FFI Agent

1. Queue 7A - Windows/POSIX hash transcript pairing.
2. Queue 7B - direct FFI allowance enforcement probe.
3. Queue 7C - concurrent rust_bridge stress.

### Documentation/Research Agent

1. Queue 9A - QM-7 citation-backed enumerator row.
2. Queue 9B - quantum future-work fence audit.
3. Queue 10A - external ML Suite status audit.
4. Queue 10B - Translate integration gate.

## Integration Owner Checklist

Before merging or cherry-picking any returned branch:

1. Confirm branch base:

   ```bash
   git fetch origin
   git merge-base <branch> origin/main
   git log --oneline --decorate -5 <branch>
   ```

2. Confirm changed files are in the assigned write scope.
3. Read the report under `findings/inbox/`.
4. Reject or rework stale branches that revert newer main work.
5. For compiler branches:

   ```bash
   bash tools/check_self_host_md5.sh
   bash tools/check_compiler_drift.sh
   bash tools/check_rod_void_abi.sh
   git diff --check
   ```

   ```powershell
   pwsh -NoProfile -File tools\check_perf_regression.ps1
   ```

6. For tools-suite branches:

   ```powershell
   .\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
   ```

   Then run the focused CLI smoke for the touched command surface.

7. For stdlib/runtime branches, run focused fixture builds and any ABI checks
   for touched rods.
8. Promote `bin/nucleor.exe` and `bootstrap/nucleor_s1_seed.ll` only after
   building and proving the compiler change.
9. Run full `bash tools/verify.sh` after a large batch or before tagging.
10. Push main only from a clean worktree.

## Current Prioritized Next Moves

1. RFC-0063 Wave 10+ is the best immediate high-leverage work. It reduces
   duplicate compiler/tooling surface and may help perf/maintenance.
2. Effects cross-module/method enforcement is the highest trust-gap closure.
3. RT cross-module and deadline audit are next for launch confidence.
4. Laws optimizer gate and remaining property forms are next best compiler
   correctness work.
5. ROBO-7 typed transform migration is the remaining prominent safety story.
6. T-3/T-4 and UNIT tails are important but can proceed after or alongside
   the above if isolated.
7. Linux CI/proof work should stay on cloud/native Linux.

## What Not To Do

- Do not stack broad compiler semantic branches on top of unmerged branches
  unless the integration owner explicitly asks for it.
- Do not share a checkout between agents.
- Do not rebase by force over another agent's uncommitted work.
- Do not add Python helper dependencies to product/toolchain paths.
- Do not claim Linux evidence from WSL/Wine/Windows artifacts.
- Do not silently drop binary/bootstrap artifacts when they are required.
- Do not broaden a lane into unrelated refactors.
- Do not leave fake placeholders, stale counts, or overclaiming docs.

## Final Handoff Sentence For Agents

Start from current `origin/main`, use your own isolated worktree, take only
your assigned queue, produce a pushed branch plus `findings/inbox/` report,
run the lane gates exactly, and stop with a concrete blocker instead of
guessing if the implementation crosses into another lane.
