# Nucleor Version And Audit Synthesis

Date: 2026-05-09

Purpose: evaluate the actual version line, evaluate the 11 audit documents as problem evidence rather than blindly accepting their proposed fixes, and define the coherent release target for getting Nucleor to 100 percent audit closure while preserving maximum practical speed.

## One-Line Recommendation

Do not treat `v1.0.3` as the completion release. Treat it as a performance recovery checkpoint. The coherent "all audit issues fixed to completion" target should be a new integration branch and release line, recommended as `v1.1.0`, because the remaining work changes language acceptance rules, type-system enforcement, runtime ABI guarantees, and production verification policy.

If the project must stay on a patch-version line for external reasons, call the final target `v1.0.4`. Technically and semantically, `v1.1.0` is the cleaner name.

## Version Facts Observed

Repository inspected:

- `origin`: `https://github.com/APEXINTELORG/Nucleor-archive.git`
- `public`: `https://github.com/APEXINTELORG/Nucleor.git`

Important refs:

| Ref | Commit | Meaning |
| --- | --- | --- |
| `v1.0.0` | `e25e4266` | Original audited baseline. The 11 recon docs target this version. |
| `v1.0.1` | `8a5e52d8` | First hardening release tag after lane integration. Contains many fixes but also explicit partials. |
| `v1.0.2` | `296ab6c4` | Annotated tag on a commit whose subject says `v1.0.1 ship`. Changelog describes it as tag-only/no source delta from v1.0.1. |
| `origin/claude/fix-cold-compile-perf-YIPKK` | `f85dd7f5` | Perf branch after `v1.0.2`; includes `ce73deef`, `0d93c66c`, `e6a328eb`, and a handoff doc commit. |
| `origin/fix/integrator-local-windows-parity-2026-05-09` | `4c1da4ce` | Windows parity branch for F-CONC-006/F-CONC-007. Forks from `v1.0.1`, not from `v1.0.2` or the perf branch. |

Merge-base facts:

- `merge-base(v1.0.2, perf branch)` is `296ab6c4`.
- `merge-base(v1.0.2, Windows parity branch)` is `8a5e52d8`.
- `merge-base(perf branch, Windows parity branch)` is `8a5e52d8`.

Implication: the Windows parity branch is not included in the perf branch. It must be explicitly cherry-picked or reimplemented.

## Current Versioning Assessment

### v1.0.0

`v1.0.0` is the correct audit baseline and rollback anchor. It should not be modified. It is useful because the audit docs can be validated against it.

It should not be used as a production-readiness claim because the audit invalidated broad safety, correctness, diagnostics, runtime, and docs claims made at that tag.

### v1.0.1

`v1.0.1` is a large hardening tag. It appears to integrate many lane fixes:

- Lane 1 type flow and codegen, with explicit partials.
- Lane 2 memory safety and handle encapsulation, with explicit partials.
- Lane 3 verify harness and diagnostics.
- Lane 4 lexer/parser robustness, with explicit partials.
- Lane 5 stdlib correctness.
- Lane 6 runtime ABI and RT enforcement.
- Lane 7 docs and user surface.

However, `v1.0.1` is not a complete audit closure. Its own changelog carries residuals:

- Type-system partials: cross-enum match, numeric narrowing strictness, generic enum payload, duplicate impl/panic cleanup.
- Memory-safety partials: branch/loop/match move-state joins and struct-field sendability recursion.
- Lexer/parser partials: NUL source smuggling, adjacent-token miscompile, semicolon/recovery semantics, and several parsing/doc-comment/import surfaces.
- Concurrency partials: Windows mutex/channel parity not integrated.
- Numerics mixed-width arithmetic left to RFC decision.

Conclusion: `v1.0.1` is better than `v1.0.0`, but not the target.

### v1.0.2

`v1.0.2` is a confusing version. It is an annotated tag on `296ab6c4`, but that commit subject says `v1.0.1 ship`. The current changelog describes `v1.0.2` as tag-only with no source delta from `v1.0.1`.

This is acceptable only as a historical reference point. It should not be treated as a meaningful fix release.

Conclusion: `v1.0.2` is a marker, not a product-quality milestone.

### Proposed v1.0.3 Perf Branch

The perf branch is valuable. It identifies a real bad fix: adding `strlen(s)` to the default `__nucleor_str_substring` path turned a hot path into an input-length walk and caused a cold compile regression from roughly 4 seconds to roughly 22-26 seconds depending on host.

The branch fixes the performance regression by removing that default `strlen` walk and retaining strict behavior in an opt-in strict helper. That is the right direction, but it also teaches the key lesson for the whole closure campaign:

Safety cannot be implemented by adding expensive whole-string or whole-source scans to hot runtime helpers. Nucleor needs length-aware source/string representations and compiler-owned invariants, not repeated C `strlen` checks in hot paths.

Release blockers observed or implied:

- No remote `v1.0.3` tag was present when checked.
- Local `bin/nucleor.exe` in the inspected worktree reported `nucleor 1.0.1` while source labels reported `1.0.3`.
- The branch does not include Windows parity F-CONC-006/F-CONC-007.
- The branch's own verify evidence distinguishes maintainer/Linux/perf-host assumptions. That evidence must be normalized before release.

Conclusion: this branch is a good base input, not the final target.

### Windows Parity Branch

The Windows parity branch addresses real concurrency runtime problems:

- F-CONC-006: POSIX mutex semantics differed from Windows recursive semantics.
- F-CONC-007: Windows channels used 100ms polling instead of condition-variable waits.

Because this branch forks from `v1.0.1`, not from `v1.0.2` or the perf branch, it needs explicit integration. It should be cherry-picked into the final integration branch before the final release target.

## Evaluation Of The Audit Documents

The audits are useful and mostly high-signal, but they are not a normalized execution plan. Treat each finding as evidence of a violated invariant, not as a required implementation recipe.

### Strong Parts Of The Audits

- They found real compiler crashes, hangs, silent accepts, and silent miscompiles.
- They included concrete reproducers and expected behavior for many findings.
- They covered multiple layers instead of only syntax or unit tests.
- They exposed verify-harness weaknesses, not just product-code bugs.
- They separated Critical/High from lower-severity doc and polish issues.

### Weak Parts Of The Audits

- Many findings are symptoms of shared root causes and should not be fixed one by one.
- Some suggested fixes would hurt performance or only paper over the symptom.
- Some severity labels are too low for production language guarantees.
- Some "closed" lane claims are partial by their own reports.
- Cross-layer dependencies are under-modeled: parser bugs often become type bugs, runtime bugs often invalidate compiler safety claims, and diagnostics bugs can hide real semantic failures.
- The audits underweight release engineering: version parity, binary provenance, tag/changelog consistency, and host-specific evidence are first-class production risks.

## Root-Cause Consolidation

The fastest path is not 244 independent fixes. It is root-cause closure.

### Root Cause 1: Silent Token Or Byte Acceptance

Audit surface:

- Lexer/parser F-003 through F-014 family.
- NUL truncation F-011.
- BOM/zero-width/smart quotes/unknown bytes.
- Adjacent expression statements dropping tokens.
- Import and delimiter recovery accepting malformed code.

Production invariant:

No byte, token, delimiter, or statement boundary may disappear silently.

Better fix:

- Length-aware source buffer from file read through lexing.
- Invalid-byte token or immediate lex diagnostic with location.
- Strict statement-boundary parser rules.
- Recovery only after an error has been recorded.
- Fuzz the lexer/parser with malformed bytes and deep nesting.

Avoid:

- Ad hoc special cases for every bad byte.
- `strlen` in hot compiler source paths.
- Parser recovery that hides code to keep examples compiling.

### Root Cause 2: Type Erasure Without Enforced Contracts

Audit surface:

- Cross-enum match.
- Generic enum payload type unchecked.
- Generic struct substitution failures.
- Trait impl coverage/signature gaps.
- Ambiguous inference.
- Numeric narrowing/widening drift.

Production invariant:

If the syntax exposes type parameters, enum variants, trait methods, or numeric widths, the checker must enforce those contracts before IR generation.

Better fix:

- Build a canonical type representation, not string-only approximations.
- Perform substitution at construction, field access, match, and call sites.
- Enforce trait impl completeness and exact signatures.
- Decide numeric coercion policy once and encode it in both spec and checker.
- Treat "type-erased generics" as a tracked limitation only if the public language explicitly says so.

Avoid:

- Fixing only the repro syntax while leaving the same erasure path for neighboring AST forms.
- Calling generic soundness findings "notes" if the language claims real generics.

### Root Cause 3: Ownership, Borrow, And Effects Are Partly Textual

Audit surface:

- G-1 alias double-free.
- G-2 multi-input lifetimes.
- G-3 invalidation under free/mutators.
- G-4 use-after-free through wrappers/projections.
- G-5/G-7/G-9/G-10 opt-in cliffs.
- G-8 conditional divergence.
- G-11 definite assignment.

Production invariant:

Safety gates must be structural, default-on, and flow-aware for all stable language surfaces.

Better fix:

- Track ownership and initialization over AST/CFG facts, not source substrings.
- Treat collection handles and concurrency handles as typed capabilities, not forgeable `i64`.
- Make effect/lifetime checks default-on for stable unsafe surfaces.
- Preserve precise negative fixtures for each shape: cast, call arg, field access, index access, branch, loop, match, nested branch.

Avoid:

- "Info" diagnostics as closure for Critical false-negatives.
- Opt-in checks for safety properties the language advertises as default.
- One-arm-only fixes that leave match/loop/projection equivalents open.

### Root Cause 4: Runtime ABI Has No Single Source Of Truth

Audit surface:

- NVec layout divergence.
- Helper manifest gaps.
- Mismatched ownership and proof obligations.
- OOM lenient-mode NULL derefs.
- `proc_*` thread-safety and shell injection.
- Const char sentinel ownership confusion.

Production invariant:

Every stable runtime helper must have one canonical ABI, one manifest row, one ownership contract, one effect contract, and tests that exercise default and failure paths.

Better fix:

- Generate manifest from runtime symbols and fail CI on drift.
- Single-source shared layouts in headers with static assertions.
- Test OOM/lenient paths, not just happy paths.
- Use argv-based process APIs instead of shell-string APIs where possible.
- Make "internal helper" a documented manifest class, not an untracked escape hatch.

Avoid:

- Local struct redeclarations in C files.
- Runtime helpers that are public by symbol but private by documentation.

### Root Cause 5: Verification Was Not Measuring The Real Release Contract

Audit surface:

- Negative tests accepted regex without nonzero exit.
- Some hosts show FAIL=0 while others show rust bridge or error-format failures.
- Version labels, checked-in binaries, tags, and changelog can disagree.
- Performance regression escaped because verify checked functional smoke only.

Production invariant:

Release validation must prove behavior, provenance, and performance on the intended host classes.

Better fix:

- Audit closure matrix for all original findings.
- Host-separated transcripts: Windows/Git-Bash, native Linux, and any release container.
- Version parity gate: tag, changelog, source labels, seed IR, binaries, release notes.
- Performance budget gate on cold and hot self-host compile.
- Sanitizer/fuzzer lanes for parser and runtime.

Avoid:

- Calling a branch green because one host's verify is green.
- Counting skipped or environment-missing tests as proof.
- Shipping binaries that report stale versions.

## Additional Issues To Add Beyond The Audit

The 11 docs are not enough for final production readiness. Add these explicit lanes:

1. Version and artifact provenance:
   - reproducible source -> seed -> binary chain
   - binary version equals source label
   - tags are annotated and pushed
   - changelog covers every tag
2. Performance regression gate:
   - cold self-host compile
   - hot compile/cache
   - per-phase attribution
   - runtime microbench for hot helpers changed by safety fixes
3. Parser/lexer fuzzing:
   - bytes, Unicode, NULs, delimiters, nesting, long identifiers, malformed literals
4. Runtime sanitizer lane:
   - ASAN/UBSAN where available
   - OOM/lenient-mode tests
   - process/thread/channel stress tests
5. Cross-platform parity:
   - Windows native
   - Windows Git-Bash/MSYS behavior
   - native Linux
   - WSL explicitly marked as non-release evidence unless chosen
6. Security threat model:
   - FFI nullability
   - process invocation
   - path/import handling
   - unsafe block/effect enforcement
7. Spec conformance:
   - every behavior is either implemented or documented as unsupported
   - no "docs say yes, compiler silently ignores" gaps

## Recommended Final Release Target

Create a new branch:

`integrate/audit-complete-v1.1.0-2026-05-09`

Base:

`origin/claude/fix-cold-compile-perf-YIPKK` at `f85dd7f5`, or the code commit `e6a328eb` if the handoff doc should not be part of the product branch.

First integration:

- Cherry-pick the Windows parity code commit `e6f3fd68`.
- Include or rewrite the stale-step-count docs commit only if it remains accurate after integration.
- Fix source/binary/version parity.
- Decide whether to retain `v1.0.3` as a perf-only internal checkpoint. If retained, tag it only after parity and fixed-point evidence. If not retained, skip straight to `v1.1.0-rc1`.

Final target:

- `v1.1.0-rc1` after ledger and first full closure pass.
- `v1.1.0` after all Critical/High findings are closed or spec-resolved, all gates are green, and performance budget holds.

Why `v1.1.0`:

- The final work changes accepted/rejected program behavior.
- It clarifies or changes semantics for numerics, parsing, effects, type checking, and runtime ABI.
- It is a production-readiness milestone, not only a patch.

## Execution Path To 100 Percent

### Stage A: Make The Truth Table

Deliverable:

- `docs/audit/audit_pass1_closure_ledger_2026-05-09.csv` or `.md`

Columns:

- audit doc
- finding id
- severity
- root-cause bucket
- original behavior
- desired invariant
- reproducer path
- status on `v1.0.0`
- status on current candidate
- status after final fix
- closing commit
- validation command
- validation output
- performance impact

No Critical or High can be "closed" without a ledger row and a command.

### Stage B: Stabilize Version And Evidence

Deliverables:

- version parity gate
- binary provenance note
- clean branch from chosen base
- Windows parity integrated
- `git diff --check` clean
- source labels/changelog/tag plan aligned

This comes before deep fixes because otherwise every later proof is attached to a moving, ambiguous target.

### Stage C: Close Safety And ABI

Order:

1. Layer 4 memory safety/effects.
2. Layer 7 runtime ABI.
3. Layer 5 concurrency/runtime parity.

Reason:

These define whether compiled Nucleor programs can corrupt memory, forge handles, race, or call runtime helpers under false contracts. They are more important than docs and most diagnostics.

### Stage D: Close Front-End Correctness

Order:

1. Layer 1 lexer/parser/AST.
2. Layer 2 type system.
3. Layer 6 codegen residuals.
4. Layer 8 numerics policy.

Reason:

The front end decides what program exists. Silent accept and silent miscompile defects must become impossible before user-facing polish is meaningful.

### Stage E: Close User Surface And Domain Libraries

Order:

1. Diagnostics.
2. Stdlib math.
3. Robotics/quantum/FFI.
4. Examples/docs/install.

Reason:

Once core language and runtime contracts are stable, diagnostics and domain libraries can be made exact without chasing moving compiler behavior.

### Stage F: Release Candidate Gate

Required before `v1.1.0-rc1`:

- audit closure ledger complete for all Critical/High
- focused audit matrix green
- `tools/check_self_host_md5.sh` green
- `tools/check_compiler_drift.sh` green
- `tools/check_nvec_layout.sh` green
- `tools/verify.sh` green on release host
- host-specific failures documented, not hidden
- cold self-host compile under budget
- binaries report final version

Required before final `v1.1.0`:

- native Linux transcript
- Windows/Git-Bash transcript
- release artifact provenance
- tag/changelog/release notes parity
- no Critical/High unclosed ledger rows

## What Not To Do

- Do not rename partial fixes as complete.
- Do not ship a tag whose binary reports an older version.
- Do not let perf fixes remove safety without replacing it structurally.
- Do not accept "warning emitted" as closure for unsafe code acceptance.
- Do not use one host's verify output as universal evidence.
- Do not chase 244 individual patches when 10 root causes will close most of the set.
- Do not preserve docs or examples that describe aspirational behavior.

## Bottom Line

The other agent's handoff is directionally useful, especially for the perf regression, but it is framed as a next-step release handoff. The correct controller story is broader:

1. `v1.0.0` is the audited baseline.
2. `v1.0.1` is a serious but partial hardening release.
3. `v1.0.2` is a tag-only historical marker.
4. The proposed `v1.0.3` branch is a perf recovery branch, not the final production-readiness release.
5. The final coherent target should be `v1.1.0`, built from the perf branch plus Windows parity plus a full audit-closure ledger.
6. The audits should be normalized by invariant and root cause, not followed mechanically.
7. The final claim is only valid when every Critical/High finding is executable-proof closed, version/artifact provenance is clean, and speed remains inside the cold/hot compile budget.

