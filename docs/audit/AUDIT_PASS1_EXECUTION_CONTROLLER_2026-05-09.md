# Nucleor Audit Pass 1 Execution Controller

Date: 2026-05-09

This is the operational plan for turning the audit findings and version synthesis into a complete repair campaign.

Companion documents:

- `docs/audit/AUDIT_PASS1_PRODUCTION_CLOSURE_PLAN_2026-05-09.md`
- `docs/audit/NUCLEOR_VERSION_AUDIT_SYNTHESIS_2026-05-09.md`

## Current Execution Checkpoint

Checkpoint from `integrate/audit-complete-v1.1.0-2026-05-09` after the first implementation slice:

- Promoted compiler and tools binaries both report `nucleor 1.1.0 (self-hosted, llvm backend)`.
- Self-host fixed point is green: `tools/check_self_host_md5.sh` reports `md5=268c5a0885aadd34da3a75fe981ea4e0` and the bootstrap seed matches.
- Compiler drift gate is green after regenerating `tools/audit_dup_fns_report.csv`, with the existing RFC-0063 parser-unification/manual-drop warnings only.
- Closed-only audit matrix is green: `SUMMARY total=10 pass=10 fail=0 todo=0`.
- Closure ledger count is now `proven_closed=10`, `open=142`.
- Newly proven closures cover Layer 6 C-001/C-002/C-003 u64 compare/shift/div-rem semantics, including direct suffixed literals, and Layer 4 G4/G8/G11 branch/match/loop safety fixtures.
- Current performance is not yet at the desired release gate: promoted 1.1.0 no-link self-compile measured `4.088s`; the v1.0.0 binary compiling the same current source measured `3.203s`; current `--time-passes` shows ownership at `2078ms`. Treat this as an open performance debt before final release, not as acceptable drift.

## Mission

Get Nucleor to a release state where all original audit-pass-1 Critical and High issues are closed by executable proof or resolved by an explicit, tested spec decision, while preserving the performance goal: no safety or correctness fix is acceptable if it makes the compiler slow by construction.

## Recommended Target

Branch:

`integrate/audit-complete-v1.1.0-2026-05-09`

Release target:

`v1.1.0-rc1` after all Critical/High rows are green in the closure ledger.

`v1.1.0` after full release gates pass on native Linux and Windows/Git-Bash with artifact provenance.

Rationale:

- `v1.0.0` is the audited baseline.
- `v1.0.1` is useful but partial.
- `v1.0.2` is tag-only/no source delta from `v1.0.1`.
- Proposed `v1.0.3` is a perf recovery checkpoint, not a complete production-readiness release.
- The remaining work changes language enforcement and runtime contracts, so `v1.1.0` is the coherent version target.

## Starting Point

Use the perf branch as the base input because it restores the cold-compile envelope:

`origin/claude/fix-cold-compile-perf-YIPKK` at `f85dd7f5`

Then integrate Windows parity:

- cherry-pick `e6f3fd68` from `origin/fix/integrator-local-windows-parity-2026-05-09`
- include the docs commit `4c1da4ce` only after checking its stale step-count sweep is still accurate

Before any deeper fixes, repair version/artifact parity:

- `compiler_version_label()` in both compiler sources
- `bootstrap/nucleor_s1_seed.ll`
- checked-in binaries, if shipped
- `CHANGELOG.md`
- `RELEASES.md`
- tag plan
- release notes

## Worktree Policy

Use a fresh isolated worktree for the integration branch. Do not mutate the historical `v1.0.0` worktree. Do not use the dirty `fix/perf-regression-2026-05-09` worktree as the controller lane.

Suggested setup:

```bash
git fetch --all --tags --prune
git worktree add C:/Users/JoeWe/Desktop/Nucleor_OSS_audit_complete_v110_20260509 origin/claude/fix-cold-compile-perf-YIPKK
cd C:/Users/JoeWe/Desktop/Nucleor_OSS_audit_complete_v110_20260509
git switch -c integrate/audit-complete-v1.1.0-2026-05-09
git cherry-pick e6f3fd68
```

If the cherry-pick conflicts, resolve in favor of the newer perf branch for version/perf files and in favor of Windows parity for the runtime concurrency implementation.

## Proof Ledger

Create:

`docs/audit/audit_pass1_closure_ledger_2026-05-09.csv`

Required columns:

```text
layer,finding_id,severity,root_cause_bucket,audit_doc,original_reproducer,expected_invariant,status_v100,status_candidate,status_final,closing_commit,validation_command,validation_result,perf_result,notes
```

Allowed statuses:

- `open`
- `proven_closed`
- `claimed_closed_needs_proof`
- `partial`
- `spec_decision_needed`
- `out_of_scope_release_blocker`
- `not_a_defect_after_review`

Rules:

- Critical and High rows cannot remain `partial`, `claimed_closed_needs_proof`, or `open` at final release.
- `not_a_defect_after_review` requires a spec citation and a regression test proving the intended behavior.
- `spec_decision_needed` must be resolved before `v1.1.0-rc1`.
- A warning-only change cannot close a Critical false-negative.
- Every row needs a validation command, even if the command is a focused script rather than full verify.

## Audit Logic Pass

Before fixing code, normalize the 11 audit docs into invariant buckets.

Use these root-cause buckets:

1. `source_bytes_and_lexer`
2. `parser_recovery_and_statement_boundaries`
3. `type_contracts_and_substitution`
4. `numeric_semantics`
5. `ownership_borrow_init_flow`
6. `effects_and_unsafe_defaults`
7. `runtime_abi_and_layout`
8. `concurrency_and_rt`
9. `diagnostic_contract`
10. `stdlib_domain_correctness`
11. `docs_and_release_surface`
12. `verification_and_provenance`

The audit docs are evidence, not commandments. Merge duplicate symptoms into root-cause fixes. Reject proposed fixes that create hot-path performance debt or only satisfy the wording while leaving the invariant broken.

## Fix Queue

### Queue 0: Release Truth And Version Parity

Goal: create a trustworthy base for every later proof.

Tasks:

1. Create the new integration worktree and branch.
2. Integrate Windows parity.
3. Set target version to `1.1.0-rc1` while in the repair lane, or use `1.1.0-dev` until the first green candidate.
4. Rebuild seed and binaries from source.
5. Ensure `bin/nucleor* --version` agrees with source labels.
6. Run:
   - `git diff --check`
   - `bash tools/check_compiler_drift.sh`
   - `bash tools/check_self_host_md5.sh`

Stop if version/source/binary parity is not clean.

### Queue 1: Closure Ledger And Focused Audit Matrix

Goal: convert all audit claims into executable tests.

Tasks:

1. Add the ledger file.
2. For each original Critical/High finding:
   - locate existing test or add focused repro
   - confirm expected failure on `v1.0.0` when practical
   - run on current candidate
   - classify status
3. Add `tools/run_audit_pass1_matrix.sh` or equivalent.
4. Make the matrix cheap enough to run after each queue.

Exit criteria:

- All Critical/High findings are represented.
- All rows have a status and command.
- No row is closed solely by prose.

### Queue 2: Memory Safety, Borrow, Effects

Goal: all G-1..G-11 Critical/High rows hard-fail unsafe code or become explicit spec decisions.

Fix order:

1. G-4 and G-11 wrapper/projection coverage:
   - `as` casts
   - call args
   - field/index access
   - method-call free forms
2. G-3 invalidation:
   - `hashmap_free`
   - vec/hashmap mutator set
   - comments/strings do not affect audit scans
3. G-1 alias and auto-drop double-free:
   - collection handle assignment
   - explicit free plus auto-drop interaction
4. G-8 branch divergence:
   - match
   - nested if
   - loop
   - projection reads
5. G-2 lifetime enforcement:
   - multi-input lifetimes
   - let-binding alias chains
6. G-5/G-7/G-9/G-10:
   - no silent opt-in cliff
   - known effect names only
   - `ptr_is_null` remediation works
   - direct FFI surfaces are enforced or explicitly marked unsafe
7. G-6 sendability recursion:
   - struct fields
   - tuple/enum payloads
   - closure captures

Required gates:

- focused G-series matrix
- `tools/check_self_host_md5.sh`
- cold compile timing

### Queue 3: Runtime ABI And Concurrency

Goal: every runtime helper has a real ABI contract and no hidden UB path.

Fix order:

1. NVec single-source and drift gate.
2. Runtime symbol manifest generation and CI diff.
3. OOM/lenient-mode allocation paths.
4. String ownership/sentinel cleanup.
5. Process API safety:
   - prefer argv-based APIs
   - shell-string APIs explicit unsafe or strongly quoted
6. Thread/process status storage:
   - no shared global races
7. Mutex/channel parity:
   - Windows condition variables
   - POSIX recursive policy or explicit non-recursive spec
8. Atomic/concurrency handle capability model:
   - no raw-handle forging
   - generation table if needed

Required gates:

- runtime ABI matrix
- `tools/check_nvec_layout.sh`
- sanitizer lane where available
- Windows/Git-Bash concurrency smoke
- native Linux concurrency smoke

### Queue 4: Lexer, Parser, AST

Goal: no silent source mutation, no parser crash, no stack overflow, no hidden token loss.

Fix order:

1. Length-aware file/source read to fully close NUL smuggling.
2. Unknown-byte handling.
3. Parser depth guard.
4. Statement-boundary rules and adjacent-token rejection.
5. Delimiter recovery only after diagnostic.
6. Literal grammar:
   - base prefixes
   - suffixes
   - underscores
   - char literals
   - float overflow
7. Import grammar and empty/comment-only source handling.

Required gates:

- parser/lexer audit matrix
- malformed-byte fuzz smoke
- deep nesting probe
- cold compile timing

### Queue 5: Type System And Numeric Semantics

Goal: no silent type contract violations.

Fix order:

1. Cross-enum match.
2. Generic enum payload substitution.
3. Generic struct field substitution.
4. Generic initializer checking.
5. Trait impl completeness/signature/extra method policy.
6. Recursive struct/generic cycle detection.
7. Type parameter hygiene:
   - arity
   - duplicate names
   - primitive shadowing
   - unknown where parameters
8. Numeric coercion policy:
   - explicit rule for widening/narrowing
   - int-to-float
   - mixed-width arithmetic
   - strict mode removed or promoted to default, depending on spec decision

Required gates:

- type-system audit matrix
- numeric matrix
- codegen differential tests
- self-host fixed point

### Queue 6: Diagnostics And Harness

Goal: diagnostics become part of the contract, not an afterthought.

Fix order:

1. Parser errors use diagnostic exits with source locations.
2. No `line=0 col=0` for real source findings.
3. Every emitted diagnostic code has a negative test.
4. No ghost code in explain database.
5. `ERROR:`/`PANIC:` print paths become coded diagnostics or known fatal internals.
6. Negative-test harness requires:
   - nonzero exit
   - expected code
   - no accidental skip

Required gates:

- diagnostic coverage gate
- negative test sweep
- full verify

### Queue 7: Stdlib Domain Correctness

Goal: stdlib APIs either compute correctly, fail loudly, or are explicitly unsupported.

Fix order:

1. Math wrong-results:
   - TT-SVD
   - CP-ALS
   - QR rank deficiency
   - kmeans/dt predict surfaces
2. Robotics:
   - URDF
   - IK quaternion short arc
   - joint-limit lifecycle
   - SE(3) units/weights
   - TF timestamp extrapolation semantics
3. Quantum:
   - qubit caps
   - qsim swap
   - CNOT entanglement semantics
   - zero-norm measure
   - sparsity threshold
4. FFI:
   - ownership of returned strings
   - rust bridge frees
   - dependency pinning

Required gates:

- differential tests against reference implementations where practical
- rod smoke tests
- memory leak checks where available

### Queue 8: Docs, Examples, Install Surface

Goal: docs describe exactly what ships.

Fix order:

1. Help lists only implemented commands.
2. `nuc explain` covers shipped diagnostics.
3. README and language reference match the compiler.
4. Examples build and run from documented paths.
5. Unsupported flags are rejected or warned, never silently swallowed.
6. Benchmark docs distinguish old data from current data.
7. Install/bootstrap docs include platform reality.

Required gates:

- docs link/inventory check
- examples smoke
- help coverage
- version parity

## Performance Rules During Fixes

Every queue that touches compiler or runtime hot paths must record:

- cold self-host compile
- hot compile/cache behavior
- affected phase timing if available
- before/after runtime microbench if a runtime helper is changed

Do not add:

- repeated full-source scans in hot paths
- C `strlen` over compiler source hot paths
- O(n^2) string accumulation over compiler-sized inputs
- broad source substring scanners when AST facts already exist

Prefer:

- length-carrying buffers
- interned ids
- single-pass structured checks
- cached source-hash facts
- generated manifests
- static assertions
- default-fast plus explicitly strict APIs only when the spec permits both

## Gate Commands

Baseline identity:

```bash
git status --short --branch
git rev-parse HEAD
git describe --tags --always --dirty
git diff --check
```

Version parity:

```bash
bin/nucleor --version || bin/nucleor.exe --version
rg -n "compiler_version_label|## \\[1\\.1\\.0" compiler CHANGELOG.md RELEASES.md
```

Core drift:

```bash
bash tools/check_compiler_drift.sh
bash tools/check_self_host_md5.sh
bash tools/check_nvec_layout.sh
```

Focused audit:

```bash
bash tools/run_audit_pass1_matrix.sh
```

Full verify:

```bash
bash tools/verify.sh
```

Cold compile:

```bash
time bin/nucleor build compiler/nucleor_s1_compiler.nr --no-cache -o /tmp/nucleor_s1_check
```

On Windows native PowerShell, use the checked-in `.exe` and capture stopwatch timing if POSIX `time` is unavailable.

## Stop Conditions

Stop the release train if any of these occur:

- Critical/High audit row has no test.
- Critical/High row remains open or partial.
- Version labels disagree with binary output.
- `v1.1.0` tag would point at a dirty or unverified tree.
- `check_self_host_md5.sh` fails.
- `verify.sh` is not `FAIL=0` on the release host.
- Cold compile exceeds the active budget without an accepted replacement budget.
- Windows and Linux evidence are collapsed into one claim.
- A safety fix relies on a warning where an error is required.
- A runtime ABI change lacks manifest/layout proof.

## First Concrete Implementation Slice

When execution begins, do this slice first:

1. Create the new `integrate/audit-complete-v1.1.0-2026-05-09` worktree.
2. Cherry-pick Windows parity.
3. Change version labels to `1.1.0-dev` or `1.1.0-rc1` depending on whether the branch will immediately run release gates.
4. Rebuild seed and binaries.
5. Add the closure ledger file.
6. Add the focused matrix runner skeleton.
7. Populate the ledger with all Critical/High rows from the 11 audit docs.
8. Run a small proving subset:
   - one lexer/parser repro
   - one type-system repro
   - one G-series repro
   - one runtime ABI repro
   - one concurrency repro
   - one diagnostics repro
9. Commit only after that subset proves the harness works.

After that, proceed queue by queue. Each queue should end with a green focused matrix subset, self-host/drift gates if compiler code changed, and a short evidence note.
