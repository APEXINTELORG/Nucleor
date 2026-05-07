# Local Claude — R05 Effects Consolidation Spike v0843 findings

Date: 2026-05-07
Branch: `spike/local-claude-r05-effects-consolidation-v0843`
Base / merge-base with `origin/main`: `666c2903` (qm7 v0843 cleanup)
HEAD: `772e8ba9` (compiler: R05 effects consolidation spike)
Authorisation: user request — fold items 1, 2, 3 from the
v0842 R05 hardening plan into a fresh spike on top of the most
recent main binary. Item 4 (cross-module propagation) explicitly
deferred — it is a different layer that needs its own ship.

## Summary — what landed and what did not

| Item | Outcome | Notes |
| --- | --- | --- |
| 1. Fold `extract_with_row` + `effect_row_from_header` | DONE | `extract_keyword_row(header, keyword)` is the new single helper; both old names now delegate to it. ~35 lines of duplicated row extraction retired. |
| 1b. Unify `collect_fn_bodies` walk into one table | DONE | `collect_fn_table(source)` returns flat `[name, requires_row, body, ...]` in one walk. `enforce_restricts_block_effects` now does one walk per restricts-using build instead of two. |
| 2. Diagnostic precision in `check_effect_call_violations` | DONE | New `row_token_covering` + `source_fn_header_for_scan` thread the actual callee row token through the diagnostic. Sub-effect cases now read `requires effect 'Alloc.heap' (in the 'Alloc' family)`; flat-row cases read identically to before. |
| 3. Memoised per-fn effect summary table | DONE (partial) | The `collect_fn_table` lazy build IS the memoisation for the restricts pre-pass. Recursion in `restricts_transitive_check` is unchanged in shape but now uses one table; depth cap raised from 3 → 8 hops. Full closure-style summary (computing per-fn transitive effects up front) NOT done — would need a separate ship to balance build-time vs perf. |
| Cold compiler RSS reclaim (the v0842 follow-up's headline claim) | NOT DELIVERED | Honest: cold compiler peak went 348 → 349 MB. The new helpers cost a touch more IR than the row-extraction consolidation saved. Stable across runs, still under the 350 MB ceiling, but no headroom recovered. Reclaim would require deleting the remaining `collect_requires_effect_rows` walk in `enforce_requires_direct_calls` — that move changes runtime allocation shapes for non-restricts callers and wants its own ship. |

The spike vindicates the consolidation idea (one helper for both
keywords, one table for the restricts pre-pass, sub-effect tokens
threaded into diagnostics, deeper chains supported via the raised
cap). It does NOT vindicate the RSS reclaim sub-claim.

## Source survey (current state on `666c2903`)

- `effect_row_from_header` at `:11583` (v0840) — `requires [...]`
  row extractor, used `strip_spaces` plus a substring search for
  `requires[`.
- `extract_with_row` at `:11503` (v0842) — `with [...]` extractor;
  scanned the unstripped header for `with` as a word, optional
  whitespace, then `[`.
- `collect_requires_effect_rows` at `:11647` (v0840) — line-walk
  that captures `(name, requires_row)` for every fn with a
  non-empty row that is not a `pure fn`.
- `collect_fn_bodies` at `:11870` (v0841) — line-walk that
  captures `(name, body)` for every fn with a `{` body.
  Duplicated the line-walk skeleton from `collect_requires_effect_rows`.
- `restricts_transitive_check` at `:11941` (v0841) — recursive
  bounded check that took separate `rows` and `bodies` vectors.
- `check_effect_call_violations` at `:15663` (pre-v0843) —
  reported the queried effect family name only, not the
  callee's actual matching token.
- `rt_header_has_effect` at `:11531` (v0842) — already used
  `extract_with_row` + `restricts_row_covers_effect`, so the
  with-row enforcement already lived on the shared row-overlap
  helper.

## Implementation

### Item 1 — `extract_keyword_row`

```nucleor
fn extract_keyword_row(header: str, keyword: str) -> str { ... }
fn effect_row_from_header(header: str) -> str {
    return extract_keyword_row(header, "requires");
}
fn extract_with_row(header: str) -> str {
    return extract_keyword_row(header, "with");
}
```

The new helper scans the unstripped header for the keyword as a
word, allows optional whitespace before `[`, and extracts up to
the matching `]`. Both `effect_row_from_header` (for `requires`)
and `extract_with_row` (for `with`) become three-line delegates.

A subtle behavioural change: `effect_row_from_header` previously
matched even when the keyword was glued to a preceding identifier
(because `strip_spaces` collapsed everything). Now it requires
a real word boundary on the LHS. In practice no real fn header
has a preceding identifier ending in `requires`, so no fixture
moves. Self-build proves the change is safe.

### Item 1b — `collect_fn_table` unified walk

```nucleor
fn collect_fn_table(source: str) -> Vec<i32>;
fn lookup_fn_row_in_table(table: Vec<i32>, name: str) -> str;
fn lookup_fn_body_in_table(table: Vec<i32>, name: str) -> str;
```

`collect_fn_table` returns `[name, requires_row, body, ...]`
triples in a single line-walk.
`enforce_restricts_block_effects` now lazily builds one table on
the first code-position `restricts [` it encounters and passes
it to `restricts_transitive_check`. Pre-v0843 it built two
separate tables (rows and bodies); the duplicate walk is gone.

### Item 2 — Diagnostic precision

```nucleor
fn row_token_covering(row: str, eff: str) -> str;
fn source_fn_header_for_scan(source: str, fn_name: str) -> str;
```

`check_effect_call_violations` now extracts the callee's actual
`with [...]` row from the source at violation time and asks
`row_token_covering` for the matching token. The diagnostic
formats:

- Flat row (`with [Alloc]` callee, queried effect `Alloc`):
  `requires effect 'Alloc'` — identical to pre-v0843.
- Sub-effect row (`with [Alloc.heap]` callee, queried effect
  `Alloc`): `requires effect 'Alloc.heap' (in the 'Alloc' family)`.

Verified live against
`tests/err/err_effects_with_alloc_family_call.nr`:

```text
error[EFF-003]: call to `alloc_heap()` requires effect `Alloc.heap` (in the `Alloc` family) but `main` is declared with [no_alloc]
```

### Item 3 — Depth cap raised, table-driven recursion

`restricts_transitive_check` now takes the unified `table` instead
of the v0841 (rows, bodies) pair. Recursion shape unchanged: at
each hop, look up callee in the table, check declared row vs
deny, and only descend if the callee is un-rowed and within the
budget. Cap raised from 3 to 8 hops. Visited-by-name dedup makes
the cap purely a diagnostic-noise bound rather than a termination
guard.

A meaningful invariant change: pre-v0843 the recursion descended
when the callee was *not found* in the rows table (i.e. either
truly un-rowed or absent because the rows table only stored
rowed fns). v0843 descends only when the callee is **in the
unified table AND has an empty `requires_row`** — which is
exactly the un-rowed case. This eliminates a dead-end recursion
attempt on extern fns or fns absent from the source (the table
only contains same-file user fns with bodies).

## Validation

```text
> .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _spike_v0843 --no-cache
  ... compiled: target\_spike_v0843.exe   EXIT=0

R05 negatives (all halt with expected codes):
  err_effects_with_alloc_call            EFF-003   (regression-clean)
  err_effects_with_alloc_family_call     EFF-003   (now reads 'Alloc.heap (in the Alloc family)')
  err_effect_inference                   EFF-001 + EFF-003
  err_effect_deep_chain                  EFF-001 + EFF-003
  err_effect_transitive                  EFF-001 + EFF-003
  err_restricts_violation                EFF-001 + EFF-003
  err_restricts_specific                 EFF-001 + EFF-003
  err_restricts_channel_effect           EFF-003
  err_restricts_builtin_io               EFF-003
  err_restricts_block_builtin_io         EFF-003
  err_restricts_block_transitive_unrowed_io  EFF-001 + EFF-003
  err_restricts_block_transitive_deep_chain  EFF-001 + EFF-003
  err_effect_requires_direct             EFF-001
  err_requires_row_direct_call           EFF-001

R05 positive smokes (all build=0 run=0):
  restricts_block_clean_smoke
  restricts_block_transitive_clean_smoke
  requires_row_clean_smoke
  effect_requires_direct_ok
  effects_with_clean_smoke

Drift / ABI / whitespace / perf:
  drift                  OK (audit_dup_fns + rod_manifest regenerated and committed)
  rod-void-ABI           OK (355 nuc_* defs / 1275 externs)
  git diff --check       clean
  perf                   OK perf: cold=3.49s/4s | hot=0.46s/1s
                         | mem cold_tree=364/400MB cold_compiler=349/350MB
                         | hot_tree=70/128MB hot_compiler=55/64MB
```

## Memory delta vs v0842 baseline

| Metric | v0842 stable | v0843 spike | Delta |
| --- | --- | --- | --- |
| cold wall time | 3.65s | 3.49s | -0.16s |
| hot wall time | 0.42s | 0.46s | +0.04s |
| cold process tree | 362 MB | 364 MB | +2 MB |
| **cold compiler** | **348 MB** | **349 MB** | **+1 MB** |
| hot process tree | 70 MB | 70 MB | 0 |
| hot compiler | 55 MB | 55 MB | 0 |

The spike costs 1 MB more cold compiler peak than v0842 (still
within the 350 MB ceiling). Real RSS reclaim is queued.

## Changed files

```text
compiler/nucleor_s1_compiler.nr                                                      (modified)
docs/rfcs/rod_manifest.toml                                                          (regenerated)
findings/inbox/local_claude_r05_effects_consolidation_spike_v0843_2026-05-07.md      (this file)
```

No new fixtures — all four spike items are internal refactors
or diagnostic improvements; existing R05 fixtures cover the
behavioural surface and the diagnostic precision was verified
against `err_effects_with_alloc_family_call.nr`.

## Residual R05 / RFC-0033 gap table (post-v0843 spike)

| Surface | Status | Locked-by fixture |
| --- | --- | --- |
| `pure fn` direct + transitive (Phase 2b) | DONE | `err_pure_*.nr` family |
| Same-file direct `requires [...]` (empty / disjoint / family root) | DONE | `err_effect_requires_direct.nr`, `err_requires_row_direct_call.nr`, `requires_row_clean_smoke.nr` |
| `with [no_alloc]` calling `with [Alloc]` flat row | DONE Phase 1 | `err_effects_with_alloc_call.nr` |
| `with [no_alloc]` calling `with [Alloc.X]` family sub-effect | DONE v0842 | `err_effects_with_alloc_family_call.nr` (now with sub-token diagnostic) |
| `with [no_alloc]` clean smoke with `Alloc` ident outside row | DONE v0842 | `effects_with_clean_smoke.nr` |
| Block-form `restricts [...]` direct builtin / direct row | DONE v0840 | `err_restricts_block_builtin_io.nr`, `err_restricts_violation.nr` |
| Block-form `restricts [...]` clean compile | DONE v0840 | `restricts_block_clean_smoke.nr` |
| Block-form `restricts [...]` one-hop transitive un-rowed | DONE v0841 | `err_restricts_block_transitive_unrowed_io.nr`, `err_effect_inference.nr` |
| Block-form `restricts [...]` deep transitive chain (≤8 hops, was ≤3) | DONE v0843 spike | `err_restricts_block_transitive_deep_chain.nr`, `err_effect_deep_chain.nr` |
| Block-form `restricts [...]` clean transitive chain (positive) | DONE v0841 | `restricts_block_transitive_clean_smoke.nr` |
| Diagnostic: name actual offending row token | DONE v0843 spike | live-verified against `err_effects_with_alloc_family_call.nr` |
| **Cold compiler RSS reclaim** | **OPEN** | needs dedicated ship — fold `collect_requires_effect_rows` into `collect_fn_table` AND inline / delete remaining duplicated body-walk in `enforce_requires_direct_calls`; both moves change runtime allocation shapes for non-restricts callers and want a separate ship to bound the blast radius. |
| Block-form `restricts [...]` chains > 8 hops | OPEN — Phase 2b deeper | none — would need closure-style per-fn effect summaries (precompute transitive effects per fn) to avoid per-block recursion cost |
| Cross-module propagation (R05 item 4 from v0842 plan) | OPEN — Phase 2b | none — needs module-import scanning in s1 |
| Methods / closures / higher-order effects | OPEN — Phase 2b | none |
| Effect-aware closure capture | OPEN — Phase 2b | none |
| Multi-token row matching beyond family-cover (subset rules) | OPEN — Phase 2b deeper | none |

## Recommended next ship

Of the queued items, the **highest-leverage** next move is
**precomputed per-fn transitive effect summaries**: walk the
unified `collect_fn_table` once at the start of the restricts
pre-pass, compute the closure of effects each fn touches
(directly or via its same-file callees), store as a
`(name, computed_effects)` map alongside the table, and have
`restricts_transitive_check` query the map instead of recursing
per block. This delivers:

1. The Item 3 closure that this spike skipped.
2. A real cold compiler RSS reclaim — one closure pass replaces
   per-block recursion that currently re-walks bodies for every
   restricts site.
3. Unbounded chain depth — the closure terminates per-fn, not
   per-call-site, so the depth cap can disappear.
4. Foundation for cross-module propagation — once per-fn
   effect summaries exist, a module-graph traversal becomes the
   straightforward extension.

Estimated complexity: comparable to this spike (~150 lines new
helper + small rewrite of `restricts_transitive_check`); biggest
risk is computing the closure correctly in the presence of
cycles (visited-by-name dedup applies), and bounding the
closure size for fns with hundreds of distinct effects.

## Main integration note

Integrated on Windows after `origin/main` advanced to RFC-0063 Wave 8
(`c46ba610`). The stale branch-level `rod_manifest.toml` delta was already
present on main and did not land as part of this integration.

Main integration changed:

```text
bin/nucleor.exe
bootstrap/nucleor_s1_seed.ll
compiler/nucleor_s1_compiler.nr
docs/rfcs/v1_PUNCHLIST.md
findings/inbox/local_claude_r05_effects_consolidation_spike_v0843_2026-05-07.md
```

Additional integration validation:

```text
bash tools/check_self_host_md5.sh --seed target/nucleor_seed.ll
  OK md5=aba4ba5e159a30ba3552602fc00bad84

bash tools/check_self_host_md5.sh
  OK md5=aba4ba5e159a30ba3552602fc00bad84

Promoted bin/nucleor.exe focused slice:
  PASS err_effects_with_alloc_family_call
  PASS err_restricts_block_transitive_deep_chain
  PASS err_effect_deep_chain
  PASS requires_row_clean_smoke
  PASS effects_with_clean_smoke

bash tools/check_compiler_drift.sh
  PASS with known RFC-0063 parser drift warnings only

bash tools/check_rod_void_abi.sh
  PASS

git diff --check
  PASS

pwsh -NoProfile -File tools\check_perf_regression.ps1
  PASS cold=3.63s hot=0.42s cold_tree=346/400MB
       cold_compiler=332/350MB hot_tree=70/128MB hot_compiler=55/64MB
```
