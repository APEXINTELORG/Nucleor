# Phase 2.0.3a results: 429 dup fns categorized — 57% safe-delete

**Date:** 2026-05-06
**Surfaced by:** RFC-0063 Phase 2.0.3a — wrote `tools/audit_dup_fns.nr` (a native Nucleor port-of-pattern based on `gen_releases_index.nr`) to enumerate every name-duplicate fn between `compiler/nucleor_s1_compiler.nr` and `compiler/nucleor_tools_suite.nr` and categorize by signature + body byte-equality.
**Status:** Audit complete. Hard data drives concrete Phase 2.0.3b/c/d phasing.

## Headline numbers

```
$ ./target/audit_dup_fns
s1 fns: 808
tools fns: 693
Wrote tools/audit_dup_fns_report.csv
Duplicate fns by name: 429
  IDENTICAL: 246
  SIG_MATCH_BODY_DIFFERS: 168
  SIG_DIFFERS: 15
```

| Category | Count | % | Risk to dedup |
|---|---|---|---|
| IDENTICAL | **246** | **57%** | **None** — sigs + bodies byte-identical, deletion is mechanical |
| SIG_MATCH_BODY_DIFFERS | 168 | 39% | Low — sigs match, bodies differ; replace tools_suite version with s1's (s1 has improvements, tools_suite is generally older) |
| SIG_DIFFERS | **15** | **3.5%** | **High** — call sites in tools_suite need updating to use the canonical signature |

This is much better data than the survey 2.0.1 estimate suggested. **57% of the dedup work is safe and mechanical.**

## The 15 SIG_DIFFERS (the architectural concerns)

```
parse_match_stmt          s1=4 args, tools=3 args, s1=137 lines, tools=175 lines
emit_module_ext           s1=5 args, tools=4 args, s1=129 lines, tools=9 lines
diag_emit_json            s1=1 args, tools=3 args, s1=58 lines,  tools=90 lines
check_fn                  s1=6 args, tools=8 args, s1=49 lines,  tools=71 lines
sig_entry_new             s1=4 args, tools=3 args, s1=8 lines,   tools=7 lines
sig_add                   s1=6 args, tools=5 args, s1=3 lines,   tools=3 lines
type_last_stmt            s1=10 args,tools=9 args, s1=10 lines,  tools=10 lines
type_expr                 s1=10 args,tools=9 args, s1=1739 lines,tools=230 lines  ⚠️
type_check_stmt           s1=11 args,tools=10 args,s1=634 lines, tools=123 lines  ⚠️
type_check_stmts          s1=11 args,tools=10 args,s1=13 lines,  tools=13 lines
match_bind_payloads       s1=6 args, tools=5 args, s1=29 lines,  tools=7 lines
lower_fn                  s1=18 args,tools=8 args, s1=476 lines, tools=75 lines   ⚠️
run_build_shared_command  s1=1 args, tools=5 args, s1=1 lines,   tools=57 lines
run_fix_command           s1=1 args, tools=2 args, s1=1 lines,   tools=40 lines
run_doc_command           s1=1 args, tools=2 args, s1=1 lines,   tools=3 lines
```

Two patterns emerge:

**Pattern A — s1 canonical, tools_suite stale (12 of 15):** `parse_match_stmt`, `emit_module_ext`, `diag_emit_json`, `check_fn`, `sig_entry_new`, `sig_add`, `type_last_stmt`, `type_expr` (1739 vs 230!), `type_check_stmt`, `type_check_stmts`, `match_bind_payloads`, `lower_fn` (476 vs 75!). For these, dedup means: delete tools_suite version + update tools_suite call sites to pass the extra arg(s) using whatever default makes sense.

**Pattern B — tools_suite canonical, s1 has 1-line stub (3 of 15):** `run_build_shared_command`, `run_fix_command`, `run_doc_command` — tools_suite has the real CLI implementation; s1 has a placeholder. For these, dedup means **lifting the implementation from tools_suite into s1** then deleting the tools_suite version. CLI dispatch in s1 then routes correctly.

The 3 Pattern-B fns are the only ones where tools_suite has unique IP that needs to migrate; everything else is "delete the older version."

## Updated Phase 2.0.3 phasing (driven by this data)

| Ship | Scope | Risk | Estimated effort |
|---|---|---|---|
| **2.0.3b** Wave 1 — IDENTICAL deletes + import | Delete 246 byte-identical dups from tools_suite, add `import "compiler/nucleor_s1_compiler.nr"` at top, leave the 168+15 risky ones in place (will collide initially — needed BEFORE we add the import) | High setup risk — collisions from remaining 183 dups must be handled in same ship | 1 ship; mechanical once remaining categories' approach is locked |
| **2.0.3c** Wave 2 — SIG_MATCH_BODY_DIFFERS deletes | Delete the 168 sig-match-body-differs dups from tools_suite (uses s1's via import) | Medium — bodies differ but sigs match, so call sites work without modification. Risk: tools_suite tests against tools_suite-specific behavior | 1-2 ships; verify each batch |
| **2.0.3d** Wave 3 — SIG_DIFFERS Pattern A (12 fns) | For each: delete tools_suite version + update tools_suite call sites to pass canonical s1 args (using sensible defaults like `0` for missing match_span, etc.) | High per-fn — call sites must be found and updated | 12 separate ships OR 1 large ship with thorough testing |
| **2.0.3e** Wave 4 — SIG_DIFFERS Pattern B (3 fns) | Lift `run_build_shared_command`, `run_fix_command`, `run_doc_command` implementations from tools_suite into s1 (replacing s1's stubs), then delete tools_suite versions | Medium — implementations are 40-57 lines each, surgical lift | 1 ship |

Total estimated: **5-15 ships**, depending on how aggressive the batching is. The `2.0.3b` ship is the trickiest because adding the import while not all dups are removed creates collisions; the cleanest approach is to delete ALL 429 in the same ship as adding the import, treating IDENTICAL as the "easy" subset.

Alternative ordering: **rename-then-import** — rename tools_suite's 429 dups with a `_tools_legacy` suffix (mechanical, no semantic change), then add the import (no collisions because tools_suite versions are now unique), then incrementally delete `_tools_legacy_*` versions in waves and migrate call sites to use the imported (s1) versions. This trades one big risky ship for many small low-risk ones.

## What the audit tool itself proves

`tools/audit_dup_fns.nr` is a 290-line native Nucleor program that:

- Parses two ~30K-line Nucleor source files in ~1s
- Extracts 808 + 693 fn declarations including args + body content
- Cross-references via hashmap (str → idx)
- Computes fnv1a-64 hashes for body byte-equality
- Outputs CSV (429 rows + header)

**This is the second native-Nucleor dev tool** (after `gen_releases_index.nr` from Phase 1.4). It validates the Track C migration pattern: native Nucleor tooling can replace ad-hoc bash/awk scripts at this scale cleanly.

The tool is also general-purpose — pointing it at any two `.nr` files will produce the same categorization. Useful for any future cross-file refactor.

## Files

- `tools/audit_dup_fns.nr` — the tool (290 lines)
- `tools/audit_dup_fns_report.csv` — current report (430 rows + header)

Re-run via `./bin/nucleor build tools/audit_dup_fns.nr -o audit_dup_fns && ./target/audit_dup_fns` after any compiler edit to refresh the data.

## Cross-references

- RFC-0063 Phase 2.0.3 — to be amended with the 5-15 ship phasing above
- `findings/promoted/2026-05-06-parser-unification-survey-rfc-0063-phase-2-0-1.md` — original survey that estimated 5-9 ships; this audit's better data refines to 5-15
- `findings/promoted/2026-05-06-phase-2-0-3-actual-scope-signature-mismatches.md` — earlier finding documenting the signature-mismatch class
- `findings/promoted/2026-05-06-phase-2-0-0-cross-module-import-verified.md` — Phase 2.0.0 verification that imports work
- `tools/gen_releases_index.nr` — reference pattern for native-Nucleor dev tooling
