# Local Claude — R05 Same-File Transitive Effects Dispatch v0841 findings

Date: 2026-05-06; recovered/integrated from isolated worktree on 2026-05-07
Branch: `fix/local-claude-r05-transitive-effects-v0841-recovered`
Base / merge-base with `origin/main`: `f3bcf104` (docs/findings: cloud Linux PKG-1 signed publish v0842 proof)
HEAD at recovery start: `f3bcf104`
Dispatch RFC:
`docs/rfcs/LOCAL_CLAUDE_R05_EFFECTS_COMPILER_DISPATCH_v0840_2026-05-06.md`
(Continuation v0841 section)

## Summary

Implemented the dispatch's preferred v0841 target — bounded same-file
transitive effect summaries for direct user-function calls reached
from a `restricts [...] { ... }` block. The new
`restricts_transitive_check` helper walks un-rowed user-fn callees
up to depth=3 hops (block + 3 user-fn body scans) and emits
`error[EFF-003]` whenever a reachable call hits a builtin in the
print-family / channel effect map or a rowed user fn whose
`requires [...]` row overlaps the deny row. Visited-by-name dedup
prevents cycles and re-walks. The bodies table is built lazily
inside `enforce_restricts_block_effects` only when an actual code-
position `restricts [` is found, so the compiler self-build pays no
extra full-source walk over v0840.

The dispatch's concrete target shape now fails on the restricts
surface:

```text
fn read_sensor() -> i64 requires [io.read] { 1 }
fn helper() -> i64 { read_sensor() }
fn main() -> i64 {
    restricts [io] {
        helper()
    }
}
```

`error[EFF-003]: block uses effect ` ``io.read`` ` via call chain
ending in `read_sensor()` denied by `restricts [io]` (audit R05-D5
v0.8.323 transitive)`

`enforce_requires_direct_calls` continues to surface EFF-001 on the
intermediate `helper()` independently, so both diagnostics fire on
this fixture (and the EFF-001 path remains the canonical signal for
"the intermediate fn forgot its requires row").

## Source survey (Required Survey)

- **`enforce_restricts_block_effects`:**
  `compiler/nucleor_s1_compiler.nr:11855-11971` (v0840) — character-
  level main scan that locates each `restricts [DENY] { BODY }`
  site, runs `restricts_body_builtin_effect` (substring detection
  for `Vec::new` / `Box::new` alloc constructors), then walks
  direct calls in the body and checks them against the deny row
  via `restricts_builtin_effect` (builtins) and the requires-row
  table (declared user fns).
- **`collect_requires_effect_rows`:**
  `compiler/nucleor_s1_compiler.nr:11623-11652` — line-by-line scan
  via `priv_extract_fn_decl_info` that returns `[name, row,
  name, row, ...]` for every same-file user fn with a non-empty
  `requires [...]` row. Used by both
  `enforce_requires_direct_calls` and the v0840 / v0841 restricts
  scanners.
- **`enforce_requires_direct_calls`:**
  `compiler/nucleor_s1_compiler.nr:11654-11716` — direct one-hop
  same-file row coverage check. For each fn, scans body for direct
  calls to any rowed callee and emits `EFF-001` if the caller row
  does not cover the callee row. Unchanged in this slice.
- **Direct builtin effect mapping:**
  `restricts_builtin_effect` (`compiler/nucleor_s1_compiler.nr:11719-11729`)
  — print/println/print_int/print_str/print_int64/putchar →
  io.write; getchar → io.read; channel → sync. Plus
  `restricts_body_builtin_effect` (`:11790-11798`) — substring
  detection for `Vec::new` / `Box::new` (alloc) on the body text.
- **Existing fixtures pre-v0841:**
  - `tests/err/err_effect_inference.nr` — block calls un-rowed
    `middle()` which calls `read_sensor` (requires [io.read]).
    EXPECT was `EFF-001` post-v0840.
  - `tests/err/err_effect_deep_chain.nr` — block calls 4-fn chain
    `level4 → level3 → level2 → leaf` (requires [net.connect]).
    EXPECT was `EFF-001` post-v0840.
  - `tests/err/err_restricts_block_builtin_io.nr` — direct
    `putchar(65)` under `restricts [io.write]`. EXPECT EFF-003.
  - `tests/features/restricts_block_clean_smoke.nr` — pure
    arithmetic block. Builds + exits 0.
  - `tests/features/requires_row_clean_smoke.nr` — caller row
    family-root, callee row sub-effect. Builds + exits 0.
- **Surface I implemented:** bounded same-file transitive effect
  summaries for restricts blocks (depth=3 hops, lazy bodies-table
  build, visited-by-name cycle dedup).
- **Surfaces I deliberately left open:** beyond-depth-3 chains,
  cross-module propagation, methods, closures, higher-order
  effects (function references / first-class fns), effect-aware
  closure capture sets, broader RFC-0033 row subtyping (multi-
  token rows, `with`-family covering rules — queued for the
  v0842 continuation queue).

## Implementation

### New helpers — `compiler/nucleor_s1_compiler.nr` (around :11837-11949)

Four new `#[manual_drop]` helpers, each documented inline:

- `collect_fn_bodies(source) -> Vec<i32>` — flat
  `[name, body, name, body, ...]` table built by one line-by-line
  source walk reusing the existing `priv_extract_fn_decl_info`
  shape. Skips lines that do not start a fn decl. For lines that
  do, locates the next `{`, brace-counts to the matching `}`, and
  pushes the resulting body slice.
- `lookup_fn_body(bodies, name) -> str` — linear name scan; returns
  the body string or `""`.
- `name_in_vec(haystack, needle) -> i64` — generic name-list
  membership, used as the visited-set cycle guard.
- `restricts_transitive_check(deny_row, body, rows, bodies,
  depth_remaining, visited) -> str` — recursive bounded walk.
  Reuses `restricts_extract_call_names` to enumerate calls, then
  per callee:
  1. `restricts_builtin_effect` lookup → if hit, check
     `restricts_row_covers_effect(deny_row, b_eff)`; on overlap
     return ``b_eff` via call chain ending in `callee()``.
  2. Otherwise scan `rows` for the callee → on hit, check
     `effect_row_intersect_first(deny_row, row)`; on non-empty
     return the same chain-string.
  3. Otherwise (un-rowed) — if `depth_remaining > 0` and the
     callee is not in `visited`, push the name and recurse with
     the callee's body at `depth_remaining - 1`.
  At depth=0 the scan still checks builtin and direct user-row
  hits; the depth budget controls only whether un-rowed callees
  are walked further.

### Pre-pass updates — `enforce_restricts_block_effects`

The per-block call loop is replaced by one call to
`restricts_transitive_check` with `depth_remaining = 3` and an
empty visited list. The bodies table is built lazily on first
match (`bodies_built` flag) so the compiler self-build (no
code-position `restricts [`) pays nothing. The pre-existing
`restricts_body_builtin_effect` (Vec::new / Box::new) substring
gate runs first and short-circuits on hit.

### Audit-pass message updated — `:32005`

The `EFF-G123` info line now records "...AND for un-rowed user fn
callees that transitively reach a builtin or rowed callee within
depth=3 hops in the same file (... local-claude transitive ship
v0841)." with the queued open surface narrowed to "beyond depth=3
chains, cross-module propagation, method/closure/higher-order
effects...".

### Fixtures

New:

- `tests/err/err_restricts_block_transitive_unrowed_io.nr` —
  `restricts [io] { helper() }` where `helper()` (un-rowed) calls
  `read_sensor()` (requires [io.read]). One-hop transitive.
  Expects EFF-003 on the restricts surface; EFF-001 on `helper`
  also fires (independent existing path).
- `tests/err/err_restricts_block_transitive_deep_chain.nr` —
  three-hop chain `restricts [net] { l4() }` →
  `l4 → l3 → l2 → leaf (requires [net.connect])`. Pins the
  full depth=3 budget.
- `tests/features/restricts_block_transitive_clean_smoke.nr` —
  un-rowed pure-arithmetic helper chain
  (`helper → double_then_add → add_one`) inside
  `restricts [io]`; builds and exits 0. Pins the clean-chain path
  the v0841 ship newly enables.

EXPECT updated for honest documentation:

- `tests/err/err_effect_inference.nr` — moved from
  `error[EFF-001]` back to `error[EFF-003]` with a note that the
  v0841 transitive summary now traps this shape on the restricts
  surface (EFF-001 still fires on `middle` from the unchanged
  requires-row direct guard).
- `tests/err/err_effect_deep_chain.nr` — moved from
  `error[EFF-001]` back to `error[EFF-003]` for the same reason
  (EFF-001 still fires on `level2`).

### Punchlist update

`docs/rfcs/v1_PUNCHLIST.md` adds a "Block-form transitive same-file
effect summaries" entry under the E-1/2/3 trust gap section,
naming the four primary fixtures (two negatives + two positives),
and narrows the "Still open" list to beyond-depth-3 chains, cross-
module propagation, and the higher-order / closure / row-subtyping
surfaces.

## Changed files

```text
compiler/nucleor_s1_compiler.nr                              (modified)
docs/rfcs/v1_PUNCHLIST.md                                    (modified)
tests/err/err_effect_deep_chain.nr                           (EXPECT updated)
tests/err/err_effect_inference.nr                            (EXPECT updated)
tests/err/err_restricts_block_transitive_deep_chain.nr       (new)
tests/err/err_restricts_block_transitive_unrowed_io.nr       (new)
tests/features/restricts_block_transitive_clean_smoke.nr     (new)
findings/inbox/local_claude_r05_transitive_effects_v0841_2026-05-06.md (this file)
```

## Focused validation

### S1 self-build with the checked-in compiler

```text
> .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_r05_transitive_s1_v0841 --no-cache --no-link
  source: compiler/nucleor_s1_compiler.nr (~2.2 MB)
  functions: 838
  strings: 6065
  optimized: 2123 instructions
  DCE: 34 of 838 fns elided as unreachable
  emitted: target/_local_claude_r05_transitive_s1_v0841.ll (11663183 bytes)

> .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_r05_transitive_s1_v0841 --no-cache
  ... compiled: target\_local_claude_r05_transitive_s1_v0841.exe
EXIT=0
```

### New fixtures (against the new compiler)

```text
neg err_restricts_block_transitive_unrowed_io   exit=1 codes=[EFF-001 EFF-003]
neg err_restricts_block_transitive_deep_chain   exit=1 codes=[EFF-001 EFF-003]

restricts_block_transitive_clean_smoke         build=0 run=0
```

### Pre-existing effects fixtures (sweep)

```text
fixture                                build_exit  EFF-001  EFF-003
err_effect_inference                   1           EFF-001  EFF-003   (was EFF-001 post-v0840)
err_effect_deep_chain                  1           EFF-001  EFF-003   (was EFF-001 post-v0840)
err_effect_transitive                  1           EFF-001  EFF-003
err_restricts_violation                1           EFF-001  EFF-003
err_restricts_specific                 1           EFF-001  EFF-003
err_restricts_channel_effect           1                    EFF-003
err_restricts_builtin_io               1                    EFF-003
err_restricts_block_builtin_io         1                    EFF-003
err_effect_requires_direct             1           EFF-001
err_requires_row_direct_call           1           EFF-001

restricts_block_clean_smoke            build=0 run=0
requires_row_clean_smoke               build=0 run=0
effect_requires_direct_ok              build=0 run=0
```

All ten existing negative fixtures still halt the build. Two
(`err_effect_inference`, `err_effect_deep_chain`) now emit EFF-003
where they previously emitted only EFF-001 — that is the v0841
target behavior. All three positive smokes still build and run 0.

### Drift / ABI / whitespace / perf gates

```text
> bash tools/check_compiler_drift.sh
  OK: tools-suite ABI tables match nucleor_s1_compiler.nr
  OK: audit_dup_fns_report.csv is up to date
  OK: rod_manifest.toml is up to date
  OK: helper_manifest.toml is up to date
  OK: RELEASES.md is up to date
  OK: CHANGELOG.md covers every git tag
  OK: s1 compiler_version_label() matches CHANGELOG.md (0.8.323)
  OK: tools_suite compiler_version_label() matches CHANGELOG.md (0.8.323)
DRIFT_EXIT=0

> bash tools/check_rod_void_abi.sh
OK: rod void ABI clean (355 C void nuc_* definitions, 1272 non-void rod externs checked)
ABI_EXIT=0

> git diff --check
(clean)
DIFF_EXIT=0

> pwsh -NoProfile -File tools\check_perf_regression.ps1
OK perf: cold=3.68s (max 4s) | hot=0.44s (max 1s) | mem cold_tree=362/400MB cold_compiler=348/350MB hot_tree=70/128MB hot_compiler=55/64MB

(re-confirmed)
OK perf: cold=3.65s (max 4s) | hot=0.4s (max 1s) | mem cold_tree=361/400MB cold_compiler=347/350MB hot_tree=70/128MB hot_compiler=55/64MB
```

Cold compile stays under the 4 s ceiling (3.65–3.68 s).

**Cold compiler RSS sits very tight against the 350 MB ceiling**
(347–348 MB across two consecutive runs, leaving ~2 MB headroom).
The dispatch flagged this margin explicitly. The new helpers add
four functions and one moderately complex recursive helper; the
LLVM IR for the larger compiler binary appears to be the dominant
cost (the bodies table is built lazily and skipped on the
compiler self-build). The gate is green and stable, but anyone
adding compiler-source code in the next few ships should
- prefer revising / inlining within
  `enforce_restricts_block_effects` over adding more helpers,
- consider folding `collect_fn_bodies` into the existing
  `collect_requires_effect_rows` walk so user-code restricts paths
  pay one source walk instead of two, and
- if `cold_compiler_peak` does cross 350 MB, run
  `tools/check_perf_regression.ps1` with `-Update` only after a
  measured intentional improvement and not to absorb a regression.

Hot compiler peak is unchanged from v0840 at 55/64 MB.

## Performance shape — implementation choices that protected
the compiler self-build

- **Lazy bodies table.** `bodies_built` flag inside
  `enforce_restricts_block_effects` defers the
  `collect_fn_bodies(source)` call until the main scanner finds an
  actual code-position `restricts [`. The compiler self-source
  contains `restricts` only in string literals (the diagnostic
  messages) and comments, both of which the main scanner skips —
  so the bodies-table cost is paid only by user code that uses
  block-form `restricts`.
- **Visited-by-name dedup.** Per-block recursion shares one
  visited list; if the same un-rowed helper is reached twice along
  different chains, the second reach is a no-op.
- **Early returns at every layer.** `restricts_builtin_effect`,
  `restricts_row_covers_effect`, `effect_row_intersect_first` all
  return on first hit. `restricts_transitive_check` returns on the
  first effect overlap so a single block emits at most one
  EFF-003.

## Residual R05 / RFC-0033 gap table

| Surface | Status (post-v0841) | Locked-by fixture |
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
| `with [no_alloc]` calling `with [Alloc]` | DONE Phase 1 partial | `err_effects_with_alloc_call.nr` |
| Block-form `restricts [...]` direct builtin I/O | DONE v0840 | `err_restricts_block_builtin_io.nr`, `err_restricts_builtin_io.nr` |
| Block-form `restricts [...]` direct user-row overlap | DONE v0840 | `err_restricts_violation.nr`, `err_restricts_specific.nr`, `err_effect_transitive.nr` |
| Block-form `restricts [...]` channel builtin | DONE v0840 | `err_restricts_channel_effect.nr` |
| Block-form `restricts [...]` namespaced alloc constructor | DONE cloud2 v0841 delta | `err_restricts_block_alloc.nr` |
| Block-form `restricts [...]` clean compile | DONE v0840 | `restricts_block_clean_smoke.nr` |
| Block-form `restricts [...]` one-hop transitive un-rowed user fn | DONE v0841 | `err_restricts_block_transitive_unrowed_io.nr`, `err_effect_inference.nr` |
| Block-form `restricts [...]` deep transitive chain (≤3 hops) | DONE v0841 | `err_restricts_block_transitive_deep_chain.nr`, `err_effect_deep_chain.nr` |
| Block-form `restricts [...]` clean transitive chain (positive) | DONE v0841 | `restricts_block_transitive_clean_smoke.nr` |
| Block-form `restricts [...]` chains > 3 hops | OPEN — Phase 2b deeper | depth-cap may need to grow if real-world adopter chains exceed it; alternatively a memoized per-fn effect summary could replace recursion |
| Transitive `requires [...]` propagation across module boundaries | OPEN — Phase 2b | none |
| Cross-module propagation | OPEN — Phase 2b | none |
| Methods / closures / higher-order effects | OPEN — Phase 2b | none |
| Effect-aware closure capture | OPEN — Phase 2b | none |
| Broader RFC-0033 effect-row subtyping (multi-token rows, `with` family covering) | OPEN — queued for v0842 dispatch | none |

## Isolated recovery integration note

The original v0841 work was recovered from `stash@{1}` after shared worktree
contention mixed Claude1/Claude2/Claude3 edits in
`C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_helper2_wave5_v0840`.

Recovery worktree:

```text
C:\Users\JoeWe\Desktop\Nucleor_OSS_recover_claude1_r05_v0841
```

The stray Claude2 law report from the stash was removed before commit. The
branch was rebased by construction on current `origin/main` (`f3bcf104`) and
the report/punchlist were corrected to remove stale regenerated-file claims and
the `v0.8.40x` placeholder.

Final recovery validation:

```text
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_r05_transitive_s1_v0841 --no-link --no-cache
PASS

.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_r05_transitive_s1_v0841 --no-cache
PASS

new negatives:
err_restricts_block_transitive_unrowed_io.nr -> EFF-001 + EFF-003
err_restricts_block_transitive_deep_chain.nr -> EFF-001 + EFF-003

legacy updated negatives:
err_effect_inference.nr -> EFF-001 + EFF-003
err_effect_deep_chain.nr -> EFF-001 + EFF-003

positive smokes:
restricts_block_transitive_clean_smoke.nr -> build/run 0
restricts_block_clean_smoke.nr -> build/run 0
requires_row_clean_smoke.nr -> build/run 0
effect_requires_direct_ok.nr -> build/run 0

bash tools/check_self_host_md5.sh
PASS md5=68d5c3d01a274d7a1af7f8ad87638e15

bash tools/check_compiler_drift.sh
PASS with existing RFC-0063 parser warnings only

bash tools/check_rod_void_abi.sh
PASS

git diff --check
PASS

pwsh -NoProfile -File tools\check_perf_regression.ps1
PASS cold=3.49s hot=0.40s cold_tree=362MB cold_compiler=348MB
```

Perf note: cold compiler RSS remains within the gate but very close to the
350MB compiler ceiling. Future compiler-source lanes should avoid extra
source-wide scans and continue running the perf gate.
