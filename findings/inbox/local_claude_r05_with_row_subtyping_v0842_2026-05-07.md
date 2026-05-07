# Local Claude — R05 RFC-0033 With-Row Subtyping Bridge v0842 findings

Date: 2026-05-07
Branch: `fix/local-claude-r05-with-row-subtyping-v0842`
Source-branch base / merge-base with `origin/main`: `b15c4960` (compiler: gate law optimizer rewrites on proof audit)
Source HEAD integrated by Codex: `94681835` (compiler: R05 v0842 RFC-0033 with-row subtyping bridge)
Codex integration base / merge-base with `origin/main`: `49d949d2` (tests: align env_get fixture with string return)
Dispatch RFC:
`docs/rfcs/LOCAL_CLAUDE_R05_EFFECTS_COMPILER_DISPATCH_v0840_2026-05-06.md`
(Continuation v0842 section, lines 257–362)

## Summary

Reroutes `rt_header_has_effect` — the with-row enforcement check
used by `enforce_no_alloc`, `enforce_no_panic`, `enforce_no_dyn`,
and the broader `collect_*_with_effect` family — through the
shared row-overlap helper `restricts_row_covers_effect` introduced
by v0840. New helper `extract_with_row` scans the unstripped
header for `with` (word boundary required, optional whitespace
allowed before `[`) and returns the row contents.

The dispatch's preferred shape is unchanged in pass/fail behaviour
— `with [no_alloc]` calling `with [Alloc]` still fires EFF-003,
and `with [Alloc.heap]` is still covered by the `Alloc` family.
The real ship is a **false-positive fix**: pre-v0842 the check
was a whole-header word search for the literal effect token, so
any occurrence of `Alloc` outside the actual `with [...]` row —
parameter name, type identifier in a where-clause, etc. — matched
and incorrectly classified the fn as having `with [Alloc]`. The
new bridge scopes the match to the row itself.

## Source survey

- `rt_header_has_effect` at `compiler/nucleor_s1_compiler.nr:11530`
  was the with-row check. Pre-v0842: whole-header literal word
  search for `effect_name` with surrounding-character word-boundary
  test. Used by `collect_headers_with_effect:12087` to populate
  per-effect fn name lists, fed to `check_effect_call_violations`.
- Existing v0840 row helpers reused: `restricts_row_covers_effect`
  at `:11761` (symmetric overlap — token == eff, eff is sub of
  token, or token is sub of eff).
- `effect_row_from_header` at `:11532` was the analogous helper for
  the `requires [...]` row but used `strip_spaces` plus a substring
  search; my first attempt copied that pattern, but it lost the
  word boundary between `i64` (the return type) and `with` and
  spuriously failed to extract the row. Final implementation
  scans the *unstripped* header so the word boundary survives.
- Existing fixture `tests/err/err_effects_with_alloc_call.nr` —
  flat-row negative — must continue to fire EFF-003.
- The dispatch said "If the current syntax does not support a
  richer row, document that precisely and instead add the smallest
  valid bridge from `with [no_alloc]` to the shared row-overlap
  helper." That is the path I took.

### Probe — what the pre-v0842 code already caught vs. missed

Concrete probes against the checked-in compiler before any edit:

```text
> probe 1: with [Alloc.heap] callee under with [no_alloc]
error[EFF-003]: call to `allocs_heap()` requires effect `Alloc` but `main` is declared with [no_alloc]
EXIT=1   (caught by whole-header word search; "Alloc" is a word in `with [Alloc.heap]`.)

> probe 2: helper(Alloc: i64) with [no_alloc]; main with [no_alloc] calls helper
error[EFF-003]: call to `helper()` requires effect `Alloc` but `main` is declared with [no_alloc]
EXIT=1   (FALSE POSITIVE: `helper` declares with [no_alloc], NOT with [Alloc].
          The whole-header word search matched the literal "Alloc" in the
          parameter name and incorrectly classified `helper` as
          having effect Alloc.)
```

The v0842 ship targets probe 2.

## Implementation

### New helper — `extract_with_row` (`:11503`)

Scans the unstripped header for the keyword `with`:

- requires word-boundary on the LHS (start of header or non-alnum,
  non-`_` preceding char) — so `pwith[...]` or `Withxyz` are NOT
  treated as the row keyword;
- skips optional whitespace between `with` and `[`;
- on a match, extracts characters between `[` and the matching
  `]` and returns them as the row;
- returns `""` if no `with [...]` form is found.

### Refactored `rt_header_has_effect` (`:11530`)

```nucleor
fn rt_header_has_effect(header: str, effect_name: str) -> i64 {
    let row: str = extract_with_row(header);
    if str_len(row) == 0 { return 0; };
    return restricts_row_covers_effect(row, effect_name);
}
```

The check is now: is there a with-row at all, and does any token
in it overlap `effect_name` per the v0840 family-covering rule?
This change cascades through every consumer of
`collect_headers_with_effect` (no_alloc, no_panic, no_dyn, and
the Alloc / Panic / Dyn effect-fn collections feeding the
`check_effect_call_violations` flow).

## Behavior change vs prior code

| Case | Pre-v0842 | Post-v0842 | Change? |
|---|---|---|---|
| `with [Alloc]` callee, `with [no_alloc]` caller | EFF-003 | EFF-003 | none |
| `with [Alloc.heap]` callee | EFF-003 (word match on "Alloc") | EFF-003 (row token is sub of `Alloc`) | none |
| `with [Alloc, sync]` callee | EFF-003 (word match) | EFF-003 (token-list match) | none |
| `with [HeapAlloc]` callee (no word boundary) | not flagged | not flagged | none |
| Header has param name `Alloc` and `with [no_alloc]` | **EFF-003 false positive** | **clean** | **fixed** |
| Header references a type `Foo<Alloc<T>>` and `with [no_alloc]` | EFF-003 false positive (would have triggered) | clean | fixed |

The change is one-direction conservative: never removes a real
EFF-003, only suppresses false positives where the literal
`effect_name` appeared outside the actual with-row.

## Fixtures

- `tests/err/err_effects_with_alloc_family_call.nr` — negative.
  `with [no_alloc]` calling a `with [Alloc.heap]` callee: EFF-003
  fires through the new row-overlap path (sub-effect arm of
  `restricts_row_covers_effect`). Sister to the pre-existing
  `err_effects_with_alloc_call.nr` (flat-row).
- `tests/features/effects_with_clean_smoke.nr` — positive.
  `helper(Alloc: i64) with [no_alloc]` called by main
  `with [no_alloc]`. Pre-v0842 trapped on the false-positive
  EFF-003; post-v0842 builds and exits 0.

## Changed files

```text
bin/nucleor.exe                                                    (promoted)
bootstrap/nucleor_s1_seed.ll                                      (promoted)
compiler/nucleor_s1_compiler.nr                                    (modified)
tests/err/err_effects_with_alloc_family_call.nr                    (new)
tests/features/effects_with_clean_smoke.nr                         (new)
findings/inbox/local_claude_r05_with_row_subtyping_v0842_2026-05-07.md (this file)
```

## Validation

### Build the s1 with the checked-in compiler

```text
> .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_r05_with_s1_v0842 --no-cache
  emitted: target/_local_claude_r05_with_s1_v0842.ll (11684758 bytes)
  compiled: target\_local_claude_r05_with_s1_v0842.exe
EXIT=0

Codex integration rerun:
> .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _r05_with_row_s1_v0842_integration --no-cache
  emitted: target/_r05_with_row_s1_v0842_integration.ll
  compiled: target\_r05_with_row_s1_v0842_integration.exe
EXIT=0
```

### Fixtures (against the new compiler)

```text
neg err_effects_with_alloc_call          exit=1
    error[EFF-003]: call to `may_alloc()` requires effect `Alloc` but `rt_path` is declared with [no_alloc]
neg err_effects_with_alloc_family_call   exit=1
    error[EFF-003]: call to `alloc_heap()` requires effect `Alloc` but `main` is declared with [no_alloc]

pos effects_with_clean_smoke             build=0  run=0
```

The pre-existing `err_effects_with_alloc_call.nr` continues to
fire EFF-003 (no regression). The new family-sub-effect negative
also fires through the shared row-overlap helper. The clean
smoke (with `Alloc` as a parameter name) compiles and exits 0
where the pre-v0842 compiler trapped on a spurious EFF-003.

### Drift / ABI / whitespace / perf gates

```text
> bash tools/check_compiler_drift.sh
  WARN: parser fn parse_match_stmt/parse_stmt/parse_expr diverges between s1 and tools_suite
        (known RFC-0063 Phase 2.0 parser-unification warning)
  OK: tools-suite ABI tables match nucleor_s1_compiler.nr
  OK: audit_dup_fns_report.csv is up to date
  OK: rod_manifest.toml is up to date
  OK: helper_manifest.toml is up to date
  OK: RELEASES.md is up to date
  OK: CHANGELOG.md covers every git tag
  OK: s1 compiler_version_label() matches CHANGELOG.md (0.8.323)
  OK: tools_suite compiler_version_label() matches CHANGELOG.md (0.8.323)
DRIFT_EXIT=0

> bash tools/check_self_host_md5.sh
OK: self-host compiler IR fixed point holds md5=2135193392e9ac204e82099552b8ae23
OK: bootstrap seed matches current self-host IR md5=2135193392e9ac204e82099552b8ae23
SELF_HOST_EXIT=0

> bash tools/check_rod_void_abi.sh
OK: rod void ABI clean (355 C void nuc_* definitions, 1275 non-void rod externs checked)
ABI_EXIT=0

> git diff --check
clean

> pwsh -NoProfile -File tools\check_perf_regression.ps1
First run (host CPU 53%):  PERF REGRESSION on cold compiler RSS (~352 MB)
Second run (host CPU low): OK perf: cold=3.96s (max 4s) | hot=0.42s (max 1s) | mem cold_tree=362/400MB cold_compiler=348/350MB hot_tree=70/128MB hot_compiler=55/64MB
Third run:                 OK perf: cold=3.65s (max 4s) | hot=0.42s (max 1s) | mem cold_tree=362/400MB cold_compiler=348/350MB hot_tree=70/128MB hot_compiler=55/64MB
Codex integration run:     OK perf: cold=3.59s (max 4s) | hot=0.42s (max 1s) | mem cold_tree=363/400MB cold_compiler=348/350MB hot_tree=70/128MB hot_compiler=55/64MB
```

The cold compiler RSS sits 2 MB under the 350 MB ceiling on stable
runs and crossed it once when the host was busy. **The 350 MB
ceiling is now effectively saturated for the local-claude effects
neighborhood.** v0840, v0841, and v0842 each added a small helper
(~15–100 lines) and a row-overlap pre-pass; further ships in this
neighborhood will need either to fold helpers together (e.g. merge
`extract_with_row` and `effect_row_from_header` into one
generalized helper that takes a keyword) or accept a deliberate
ceiling bump backed by a measurement note in
`tools/perf_baseline.json`.

Cold wall time is also tight (3.65–3.96 s vs the 4 s ceiling).
Hot peak is unchanged at 55/64 MB.

### Gate-induced followup

The source-branch report recorded a stale `audit_dup_fns_report.csv`
regeneration. On Codex integration from `49d949d2`, drift reported
`audit_dup_fns_report.csv` already up to date, so no duplicate-function
report change was carried into main.

## Residual R05 / RFC-0033 gap table

| Surface | Status (post-v0842) | Locked-by fixture |
| --- | --- | --- |
| `pure fn` direct builtin I/O | DONE Phase 2b | `err_pure_builtin_io.nr` |
| `pure fn` + `requires [...]` contradiction | DONE Phase 1 | `err_pure_requires.nr` |
| `pure fn` direct same-file user-effect call | DONE Phase 2b | `err_pure_violation.nr` |
| `pure fn` transitive same-file user-effect call | DONE Phase 2b | `err_pure_transitive_user_effect.nr` |
| `pure fn` undeclared extern call | DONE Phase 2b | `err_pure_extern_default_effect.nr` |
| `pure fn` channel/scope/spawn | DONE Phase 2b | `err_pure_channel_effect.nr`, `err_pure_scope_schedule.nr` |
| Same-file direct `requires [...]` empty caller row | DONE Phase 1 | `err_effect_requires_direct.nr` |
| Same-file direct `requires [...]` disjoint caller row | DONE v0839 | `err_requires_row_direct_call.nr` |
| Same-file direct `requires [...]` family-root caller row (positive) | DONE v0839 | `requires_row_clean_smoke.nr` |
| Block-form `restricts [...]` direct builtin / direct row | DONE v0840 | `err_restricts_block_builtin_io.nr`, `err_restricts_violation.nr` |
| Block-form `restricts [...]` clean compile | DONE v0840 | `restricts_block_clean_smoke.nr` |
| Block-form `restricts [...]` one-hop transitive un-rowed user fn | DONE v0841 | `err_restricts_block_transitive_unrowed_io.nr`, `err_effect_inference.nr` |
| Block-form `restricts [...]` deep transitive chain (≤3 hops) | DONE v0841 | `err_restricts_block_transitive_deep_chain.nr`, `err_effect_deep_chain.nr` |
| Block-form `restricts [...]` clean transitive chain (positive) | DONE v0841 | `restricts_block_transitive_clean_smoke.nr` |
| `with [no_alloc]` calling `with [Alloc]` flat row | DONE Phase 1 | `err_effects_with_alloc_call.nr` |
| `with [no_alloc]` calling `with [Alloc.X]` family sub-effect | DONE v0842 | `err_effects_with_alloc_family_call.nr` |
| `with [no_alloc]` clean smoke with `Alloc` ident outside row | DONE v0842 | `effects_with_clean_smoke.nr` |
| Block-form `restricts [...]` chains > 3 hops | OPEN — Phase 2b deeper | none — depth-cap may need to grow or be replaced by per-fn memoized effect summaries |
| Cross-module propagation | OPEN — Phase 2b | none |
| Methods / closures / higher-order effects | OPEN — Phase 2b | none |
| Effect-aware closure capture | OPEN — Phase 2b | none |
| Multi-token row matching beyond family-cover (e.g. row-set subset rules) | OPEN — Phase 2b deeper | none |

## R05 hardening plan (next-step recommendations)

1. **Cold compiler RSS reclaim.** Folding `extract_with_row` and
   `effect_row_from_header` into a single keyword-parameterised
   helper would shed ~30 lines of duplicated body-walk code;
   doing the same with the line-by-line scanners in
   `collect_requires_effect_rows` and the v0841 `collect_fn_bodies`
   should give back another few MB of cold-compiler footprint.
2. **Diagnostic precision.** `check_effect_call_violations` still
   reports the requested effect name (`Alloc`) rather than the
   actual offending row token (`Alloc.heap`). A short follow-up
   could thread the matched token through and produce
   `error[EFF-003]: call to `X` requires effect `Alloc.heap` (in
   the `Alloc` family) ...`.
3. **Cross-rod `with [Send]` / `with [no_send]`.** When the OSS
   release adds the trait-style send / sync rows, the same
   row-overlap helper can be reused — but only if cross-module
   propagation is added at the same time, which is currently
   queued.
4. **Memoised per-fn effect summaries.** Replacing the
   `restricts_transitive_check` recursion (v0841) and the
   `collect_*_with_effect` per-call scans with a one-pass
   per-fn effect summary table would cap the cold-compiler cost
   and unblock chains > 3 hops without compromising perf.
