# Phase 2.0.3 actual scope: signature mismatches dominate the duplicate-fn class

**Date:** 2026-05-06
**Surfaced by:** v0.8.323 attempted Phase 2.0.3 pilot — adding `import "compiler/nucleor_s1_compiler.nr"` to `compiler/nucleor_tools_suite.nr` to scope what the unification ship actually requires.
**Status:** Phase 2.0.3-prep landed (compile_error! detector exemption); Phase 2.0.3 itself confirmed as multi-session work.

## What we tried

Two separate experiments after Phases 2.0.0-2.0.2 closed:

### Experiment 1: byte-identity check on supposedly-trivial duplicates

For 4 utility helpers (`tok_new`, `pk`, `pkv`, `str_from_i64`), diff'd s1's body against tools_suite's:

| Fn | s1 lines | tools_suite lines | Byte-identical? |
|---|---|---|---|
| `tok_new` | 3 | 3 | **NO** — `Vec::with_capacity(3)` (s1) vs `Vec::new()` (tools) |
| `pk` | 33 | 12 | NO — substantial divergence |
| `pkv` | 31 | 11 | NO — substantial divergence |
| `str_from_i64` | 38 | 19 | NO |

**Implication:** the 429 "duplicate" fns from the Phase 2.0.1 survey are *name*-duplicates, not *byte*-duplicates. Even 3-line utilities have drifted. Most differences look benign (perf optimizations in s1 that didn't propagate), but each requires per-fn review during the dedup ship.

### Experiment 2: minimal import + build

Added `import "compiler/nucleor_s1_compiler.nr"` at top of `compiler/nucleor_tools_suite.nr`, no other changes. Tried to build.

**Blocker 1 (FIXED in v0.8.323):** s1's `compile_error!(...)` text-pre-pass detector at line 30453 only exempted `nucleor_s1_compiler.nr` from self-detection. With the import, the resolved source contains s1's strings (which contain the pattern in error-message text), but the `src_path` is `nucleor_tools_suite.nr` — so the detector fires and panics:

```
ERROR: compile_error!(...) invocation in source. ...
PANIC: nucleor: compile_error! invoked in source
```

Fixed by extending the exemption: `is_compiler_src` is now true for both s1 and tools_suite paths. Bootstrap regenerated; verified the fix lands without other regressions.

**Blocker 2 (REAL Phase 2.0.3 work):** With the detector fixed, the build progresses to actual symbol resolution and immediately hits a signature mismatch:

```
error[TYP-005]: wrong number of arguments for 'emit_module_ext'
  --> fn compile_file_mode@line 31900:19
      |
31900 |     let ll: str = emit_module_ext(fns, strtab, pool, externs, source);
      |                   ^
```

tools_suite's `compile_file_mode` calls `emit_module_ext` with 5 args; s1's `emit_module_ext` has a different arg count. Both files defined this fn locally, so the duplicate-fn collision wouldn't trigger if we deleted tools_suite's version — but then ALL existing call sites in tools_suite would break.

This is exactly the kind of thing the Phase 2.0.1 survey flagged with `parse_match_stmt` (3 args in tools_suite, 4 args in s1). Confirmed: signature mismatches are not the exception — they're the dominant case across the 429 dup fns.

## Real Phase 2.0.3 requires

Per-fn workflow for each of the 429 duplicates:

1. Compare signatures. If identical, deletion is safe.
2. If signatures differ (likely most cases):
   - Identify which is canonical (usually s1's, since it's the more-evolved compiler).
   - Update all call sites in tools_suite to use the canonical signature.
   - Delete tools_suite's version.
3. Compare bodies for semantic equivalence even when signatures match (the byte-identity check above shows even 3-line fns drift).
4. Rebuild incrementally — each batch of deletions surfaces the next signature mismatch.

Estimated effort: several days to weeks at the current ship cadence. **Not session-scale.** RFC-0063 phasing should be split:

- **2.0.3a:** signature-audit pass — enumerate all 429 dup fns, categorize as (identical / sig-match-body-differs / sig-differs / behavior-differs), output an actionable spreadsheet.
- **2.0.3b–2.0.3z:** waves of dedup, batched by class. Identical fns first (lowest risk, may be 50-100). Sig-match-body-differs second. Sig-differs last.
- **2.0.4 (unchanged):** self-host integrity gate proves no regression after all dedup.

## What landed in v0.8.323

- ✅ `compile_error!` detector exemption extended to tools_suite — required prereq for any cross-module import that pulls in s1.
- ✅ This finding (Phase 2.0.3 actual scope) so the next ship cycle has a realistic plan.
- ❌ Did NOT delete any duplicate fns — that's Phase 2.0.3 proper.

## Open questions for Phase 2.0.3a (signature audit)

1. Is there an automated way to detect signature mismatches across files at scale? (probably: extract `^fn name(args) ...` lines from each, compare arg counts and types.)
2. For fns where bodies differ but signatures match, what's the test for "semantically equivalent"? (Probably: build both versions, run identical inputs, diff outputs — but only for pure fns; effectful fns need other validation.)
3. How many of the 429 are actually byte-identical? (Sample of 4 showed 0% — extrapolation suggests <10% of 429.)
4. What's the right tooling? A new `tools/audit_dup_fns.nr` script could enumerate the categorization automatically.

## Cross-references

- `findings/promoted/2026-05-06-parser-unification-survey-rfc-0063-phase-2-0-1.md` — the survey that scoped 429 dups
- `findings/promoted/2026-05-06-phase-2-0-0-cross-module-import-verified.md` — Phase 2.0.0 verified the basic import mechanism works
- RFC-0063 Phase 2.0 — needs amendment to split 2.0.3 into 2.0.3a (audit) + 2.0.3b-z (waves)
- v0.8.323 commit fixing the detector (this session)
