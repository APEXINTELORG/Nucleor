# Nucleor Audit Pass 1 Production Closure Plan

Date: 2026-05-09

Working evidence lane used for this writeup:

- Audit baseline: `v1.0.0` at `e25e4266`, with the 11 recon finding documents under `docs/audit/findings/`.
- Current candidate branch inspected: `origin/claude/fix-cold-compile-perf-YIPKK` at `f85dd7f5`.
- Local verification worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_v103_verify_20260509_codex`.
- Local branch created for this planning pass: `codex/audit-closure-production-readiness-2026-05-09`.

## Executive Position

Nucleor should not be treated as production-ready because a branch claims a set of findings is closed. It is production-ready only when every original audit finding is mapped to one of three explicit states:

1. Closed by code, with the original reproducer now failing or passing as intended.
2. Closed by documented spec decision, with the audit expectation updated and an executable regression proving the chosen contract.
3. Deferred only if it is explicitly out of scope for the release train, not silently hidden inside marketing language.

For the stated goal, the operating rule is stricter: all Critical and High findings from the 11 original audit documents must reach state 1 or state 2 before the release is called complete. Medium and Low findings can ship only if they do not mask safety, correctness, or performance defects, and each one has a tracked follow-up.

Performance is not a separate final polish step. Every fix must preserve or improve the compiler's speed envelope. A correctness fix that regresses cold self-host compile past the sub-4s gate is not complete; a speed fix that weakens safety or diagnostics is not complete.

## What Is True Right Now

The original audit was aimed at `v1.0.0`. That audit found broad deficiencies across lexer/parser, type system, diagnostics, memory safety/effects, concurrency, codegen, runtime ABI, numerics, stdlib math, robotics/quantum/FFI, and examples/docs/install.

After that audit, multiple remediation branches landed or were prepared. The handoff file `C:\Users\JoeWe\Desktop\Nucleor_NEXT_AGENT_HANDOFF_2026-05-09.md` says `v1.0.3` is ready to ship from `f85dd7f5`, with 20 closures and the cold compile regression fixed.

That handoff is useful, but it is not enough evidence by itself.

Observed locally on 2026-05-09:

- `origin/claude/fix-cold-compile-perf-YIPKK` exists at `f85dd7f5`.
- No local or remote `v1.0.3` tag was present when checked.
- The source at `f85dd7f5` has `compiler_version_label()` returning `1.0.3` in both `compiler/nucleor_s1_compiler.nr` and `compiler/nucleor_tools_suite.nr`.
- The checked-in Windows binary at `bin/nucleor.exe` still reported `nucleor 1.0.1 (self-hosted, llvm backend)`.
- `git diff --check HEAD~3..HEAD` produced no whitespace errors.
- Focused Windows binary probes showed some audit-era memory-safety failures are now rejected:
  - `tests/err/err_g4_cast_uaf.nr` fails with `OWN-G4-USE-AFTER-DROP`.
  - `tests/err/err_g11_one_arm_init.nr` fails with `INIT-G11-READ-BEFORE-INIT`.
  - `tests/err/err_g3_hashmap_free_while_borrowed.nr` fails with `ALIAS-G3-HASHMAP-REHASH`.
- `tools/check_self_host_md5.sh` under local Windows/Git-Bash failed during stage1 build. That is a release-blocking validation gap on this host, not global proof that the branch is wrong. Native Linux evidence still needs to be captured separately.

Conclusion: the remediation effort is materially better than `v1.0.0`, but it is not yet at a defensible "100% fixed" checkpoint. The immediate task is to convert claims into a ledger of proven closures, then work the remaining failures in an order that protects safety and speed together.

Execution update from the `integrate/audit-complete-v1.1.0-2026-05-09` lane: the first implementation slice has converted 10 ledger rows to `proven_closed` with executable evidence: Layer 6 C-001/C-002/C-003 and Layer 4 G4/G8/G11 branch/match/loop fixtures. The promoted 1.1.0 compiler is self-host fixed-point clean and drift-gate clean, but the cold no-link self-compile is still slower than the v1.0.0 floor (`4.088s` current vs `3.203s` using the v1.0.0 binary on the same current source). This performance debt remains a release blocker under this plan.

## Non-Negotiable Definition Of Done

An audit finding is not closed until all applicable checks pass:

- The original audit reproducer is preserved or converted into a committed test.
- The test fails on `v1.0.0` or is otherwise proven to represent the original behavior.
- The test passes on the candidate branch with the expected diagnostic, runtime behavior, or generated IR.
- The fix is in both self-host source surfaces when required:
  - `compiler/nucleor_s1_compiler.nr`
  - `compiler/nucleor_tools_suite.nr`
  - `bootstrap/nucleor_s1_seed.ll`
  - generated runtime or manifest artifacts where relevant
- The fix survives self-host fixed-point validation.
- The fix survives full verify on at least the intended release host class.
- The fix does not regress cold self-host compile beyond the release gate.
- The diagnostic is specific enough that a user can correct the program without reading compiler internals.
- The finding ledger records the exact commit, test file, observed output, and gate transcript.

No finding should be closed because a warning was added while unsafe or wrong code still compiles. Warnings are acceptable only for advisory or compatibility surfaces; Critical and High false-negatives must become hard failures unless the language spec deliberately permits the behavior.

## Release Gate Stack

The repair campaign should use a layered gate stack. Fast screens run before long gates; long gates run before tagging.

### Gate 0: Repository Integrity

- Correct repository: `APEXINTELORG/Nucleor-archive`.
- Do not push to `APEXINTELORG/Nucleor`.
- `v1.0.0` remains untouched as rollback/audit baseline.
- Candidate branch has no unrelated dirty files.
- `git diff --check` is clean.
- `CHANGELOG.md`, `RELEASES.md`, compiler version labels, and tag name agree.
- Checked-in binaries, if shipped, report the same version as source.

### Gate 1: Focused Finding Repro Matrix

Create a machine-readable ledger for all original audit findings:

- finding id
- severity
- layer
- original audit file
- reproducer path
- expected diagnostic or behavior
- current candidate status
- closing commit
- validation command
- validation output summary

This must be runnable as a focused audit matrix before `tools/verify.sh`. It should be cheap enough to run after every fix slice.

### Gate 2: Self-Host And Drift

Required:

- `bash tools/check_self_host_md5.sh`
- `bash tools/check_compiler_drift.sh`
- bootstrap seed parity
- duplicate helper report parity when helper reports are regenerated

If a host cannot run these gates, the report must say so explicitly and include native Linux evidence before release.

### Gate 3: Full Verify

Required:

- `bash tools/verify.sh`
- `FAIL=0`
- negative-test gate must require both non-zero exit and expected diagnostic
- no prefix-matched or accidentally skipped `--only` runs used as proof

Windows/Git-Bash evidence and native Linux evidence must be reported separately. A green Linux transcript does not erase a Windows failure; a Windows local probe does not replace native Linux release evidence.

### Gate 4: Performance

Required:

- cold self-host compile with `--no-cache`
- hot compile/cache behavior
- targeted compile-time profile for any compiler-front-end fix
- runtime microbench for runtime ABI changes
- sub-4s cold compile gate remains active unless explicitly replaced by a stronger hardware-normalized metric

The principle is "as fast as physics allows," not "fast enough after adding checks." Safety checks should be structured, cached, linear, and placed where existing passes already have the needed information. Avoid repeated full-source scans, string-heavy O(n^2) construction, and late runtime checks when the compiler can decide statically.

### Gate 5: Adversarial Robustness

Required for parser, type, memory-safety, and runtime ABI layers:

- crash probes
- stack/depth probes
- malformed byte probes
- invalid Unicode/encoding probes
- sanitizers or equivalent runtime instrumentation for C runtime changes where available
- OOM/lenient-mode tests for allocation paths

## Execution Story

The remediation should proceed in five phases.

### Phase 0: Stabilize The Release Candidate

Purpose: stop building on uncertain release state.

Actions:

1. Reconcile `v1.0.3` version parity:
   - source labels
   - bootstrap seed
   - `bin/nucleor.exe`
   - `bin/nucleor` on POSIX
   - changelog
   - release notes
   - tag
2. Decide whether Windows parity commits `F-CONC-006` and `F-CONC-007` land before `v1.0.3` or become `v1.0.4`.
3. Produce one evidence file for current candidate status.
4. Do not tag until self-host fixed point and full verify are green on the chosen release host.

Why first: a release whose binary reports `1.0.1` while source says `1.0.3` cannot be considered production-grade, even if many fixes are real.

### Phase 1: Build The Audit Closure Ledger

Purpose: make every original audit finding accountable.

Actions:

1. Parse all 11 audit docs into a ledger.
2. Assign each finding to:
   - proven closed
   - probably closed but needs proof
   - open
   - spec decision required
   - out of release scope
3. For every Critical and High finding, create or identify a committed test.
4. Add a focused command to run only the audit closure suite.

Why second: without the ledger, agents will keep rediscovering defects, overclaiming partial fixes, and closing docs instead of behavior.

### Phase 2: Memory Safety And Effects

Purpose: protect the core safety claims.

Layer 4 is the highest-value work because these findings are about unsafe code being accepted. Even if several repros now fail locally, the whole G-1..G-11 matrix must be validated.

Priority order:

1. G-4 wrappers and projections:
   - `as` casts
   - call arguments
   - field/index projection after free
   - method-call free shape if exposed
2. G-11 definite assignment:
   - one-arm `if`
   - empty `else`
   - zero-iteration loops
   - casts and projections over uninitialized reads
3. G-3 collection invalidation:
   - `hashmap_free`
   - all mutators that can invalidate borrows
   - comment/string stripping in audit counters
4. G-1 alias and auto-drop:
   - binding-to-binding collection aliases
   - double-free through alias handles
5. G-2 multi-input lifetimes:
   - no misleading "closed" label for single-input only
   - hard failure for known unsound cases
6. G-5/G-7/G-9/G-10 opt-in cliff:
   - no whole-framework silence because attributes are absent
   - validate effect names
   - ship `ptr_is_null` remediation if diagnostics recommend it
7. G-6 recursive sendability:
   - structs containing `HashMap`
   - tuples/enums/closures as captures
8. G-8 branch divergence:
   - field projection
   - match arms
   - nested `if`
   - loops

Completion standard: every G gate has positive and negative tests, with no Critical false-negative left.

### Phase 3: Runtime ABI

Purpose: eliminate latent UB and manifest lies.

Priority order:

1. A1 NVec layout:
   - single-source the layout in one header
   - remove divergent local redeclarations
   - add static assertions
   - re-run Rust bridge and runtime tests
2. Manifest completeness:
   - public `__nucleor_*` helpers must be inventoried
   - decide and document treatment of unprefixed `nuc_*` helpers
   - add CI diff between runtime symbols and manifest
3. OOM and lenient-mode correctness:
   - `vec_push`
   - vector constructors
   - free guards
   - malloc/realloc failure contracts
4. String/process contracts:
   - sentinel ownership
   - `proc_capture_stdout` thread-local status
   - `proc_run1` shell injection replacement or hard warning
5. Concurrency runtime parity:
   - recursive mutex parity
   - condition-variable channel wait on Windows
   - atomic alignment assertions

Completion standard: runtime ABI can be consumed from default build routes without hidden layout, ownership, or manifest mismatches.

### Phase 4: Lexer, Parser, And Type System

Purpose: eliminate silent acceptance and silent miscompile at the language front door.

Layer 1 priority:

1. Unknown-byte fallthrough:
   - no silent consumption of unknown bytes
   - NUL byte must be rejected
   - BOM/zero-width/smart quotes need intentional handling
2. Parser depth:
   - explicit maximum depth
   - clean diagnostic on deep nesting
3. Expression-statement laxness:
   - no stray token dropping between statements
   - semicolon and delimiter recovery must not hide code
4. Literal hygiene:
   - invalid base prefixes
   - suffixes
   - underscores
   - float overflow
   - char literal classification
5. Import and module shape:
   - no empty or malformed imports silently accepted
   - empty/comment-only files receive frontend diagnostics

Layer 2 priority:

1. Cross-enum match miscompile.
2. Integer narrowing/widening and int-to-float implicit conversions.
3. Generic enum payload checking.
4. Generic struct field substitution and initializer checking.
5. Trait impl completeness and signature matching.
6. Recursive generic and mutually recursive struct detection.
7. Type parameter hygiene:
   - arity
   - duplicate names
   - primitive shadowing
   - unknown where-clause params
8. PANIC-to-diagnostic conversion for user-facing errors.

Completion standard: invalid source either compiles correctly because the spec allows it or fails with a deterministic diagnostic. No parser crash, stack overflow, silent byte drop, or silent type erasure bug can remain in Critical/High class.

### Phase 5: Diagnostics, Numerics, Stdlib, And Docs

Purpose: finish the user-facing and domain-surface contract.

Diagnostics:

- line/column zero defects
- parser panic locations
- `print("ERROR:")` sites without diagnostic codes
- negative-test coverage for every emitted code
- removal or explanation of ghost diagnostics

Numerics:

- preserve closed fixes for u64 codegen, narrow casts, unit conversion, bit shift bounds, and constants
- decide mixed-width arithmetic spec in an RFC and enforce it
- keep numeric performance tests close to the fix sites

Stdlib math:

- replace loud warnings with real implementations where the API promises math, especially TT-SVD and CP-ALS
- reanimate or remove dead kmeans/dt surfaces
- handle QR rank deficiency deliberately

Robotics, quantum, FFI:

- qubit-cap consistency
- qsim swap and CNOT semantics
- sparsity threshold convention
- zero-norm guards
- IK/SE(3)/TF lifecycle and semantics

Examples/docs/install:

- docs must describe the shipped language, not the aspirational language
- help aliases must be live or removed
- no dead demo surfaces

Completion standard: docs and examples become a proof surface, not a separate marketing layer.

## Performance Doctrine

The production goal is not to bolt checks onto a slow compiler. It is to make correctness cheap.

Rules:

- Prefer one-pass structured AST/type checks over repeated source-string scans.
- Carry metadata forward when a pass already knows it.
- Use interned symbols or compact ids where repeated string comparison is currently hot.
- Cache audit-derived facts by source hash when they are expensive and deterministic.
- Make debug/audit scans opt-in only when they do not enforce production safety.
- Do not use warnings to avoid implementation cost for safety findings.
- Measure cold and hot compile after every compiler-front-end slice.
- Treat any O(n^2) pass over full compiler source as suspect until profiled.

The target is physics-limited performance: predictable linear or near-linear front-end behavior, minimal redundant work, native-code runtime fast paths, and no unchecked UB hiding behind speed claims.

## Branching And Release Policy

Recommended policy:

- Use one clean integration branch for the release candidate.
- Land fixes in small layer-scoped commits.
- Each commit includes:
  - finding ids
  - tests added
  - validation commands
  - performance result if compiler/runtime path changed
- Do not tag until:
  - focused audit matrix is green
  - full verify is green
  - self-host fixed point is green
  - version parity is green
  - native Linux release evidence exists
  - Windows/Git-Bash parity is either green or explicitly scoped out with a tracked blocker

The current candidate should not be called shipped `v1.0.3` until the binary/source/tag mismatch is fixed and validation evidence is attached.

## Immediate Next Work Order

1. Create `docs/audit/audit_pass1_closure_ledger_2026-05-09.md` or a CSV/JSON equivalent from all 11 audit docs.
2. Run the focused repro matrix against:
   - `v1.0.0`
   - `f85dd7f5`
   - the next integration branch
3. Fix release parity:
   - version labels
   - bootstrap seed
   - binaries
   - changelog
   - tag readiness
4. Decide Windows parity commit placement.
5. Close Layer 4 and Layer 7 first.
6. Close Layer 1 and Layer 2 next.
7. Finish diagnostics, stdlib, docs, and examples.
8. Tag only after the gate stack is green with attached transcripts.

## Stop Conditions

Stop and do not tag if any of these are true:

- a Critical or High finding has no test or ledger row
- a claimed closure has no command output proving it
- `bin/nucleor* --version` disagrees with source labels
- self-host fixed point fails
- full verify is not `FAIL=0`
- cold compile regresses past the gate
- a runtime ABI change has no manifest/layout validation
- a Windows failure is hidden behind Linux success, or the reverse

## Bottom Line

The right story is not "v1.0.0 had issues, v1.0.3 fixed them." The right story is:

Nucleor `v1.0.0` exposed real production-readiness gaps. Later branches closed meaningful parts of the surface, including some memory-safety repros and the cold-compile regression, but the release candidate still needs a rigorous closure ledger, version parity, host-separated validation, and a disciplined fix sequence. The fastest route to 100% is to stop treating the audit as prose, turn it into an executable matrix, and then close the remaining findings in the order that protects safety first while preserving the sub-4s cold compile gate.
