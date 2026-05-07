# Local Claude — R05 Effects Compiler Dispatch v0840 findings

Date: 2026-05-06
Branch: `fix/local-claude-r05-effects-compiler-v0840`
HEAD at start: `d5b8d611` (docs: dispatch local and helper continuation lanes)
Original merge-base with `origin/main`: `d5b8d611`
Dispatch RFC:
`docs/rfcs/LOCAL_CLAUDE_R05_EFFECTS_COMPILER_DISPATCH_v0840_2026-05-06.md`

## Summary

Implemented the dispatch's preferred slice — block-form
`restricts [...] { ... }` real enforcement. The parser-level
fail-closed panic at `parse_primary` is replaced with a passthrough
parse, and a new same-file source pre-pass
`enforce_restricts_block_effects` emits `error[EFF-003]` for direct
calls inside the block whose effect overlaps the deny row. Two
callee classes are checked end-to-end: builtins listed in a small
`restricts_builtin_effect` map (print-family I/O, char-level I/O,
and `channel`) and same-file user fns whose declared
`requires [...]` row overlaps the deny row. Clean blocks (no calls
or only non-overlapping calls) compile and run normally — pre-v0840
the same source halted at parse_primary.

Added two real fixtures: a negative
(`tests/err/err_restricts_block_builtin_io.nr` — direct `putchar(65)`
under `restricts [io.write]` traps with EFF-003) and a positive
(`tests/features/restricts_block_clean_smoke.nr` — pure-arithmetic
clean block builds and exits 0). Pre-existing fail-closed companions
continue to halt the build via the new pre-pass or via the existing
`enforce_requires_direct_calls` direct-row check.

## Integration Review

Codex reviewed this branch after `origin/main` had advanced to
`0dd3bbac`, cherry-picked the slice onto current main, and normalized
the temporary compiler diagnostic/comment version placeholder to the
current compiler-version context `v0.8.323`. Focused negative/positive
effects fixtures were rerun against a freshly built s1 compiler, plus
drift, rod-ABI, whitespace, and perf gates. Integration validation
passed with `cold=3.54s`, `hot=0.50s`, `cold_tree=343MB`, and
`hot_compiler=55MB`.

## Source survey (Required Survey)

- **`requires [...]` parser/skip surfaces** in
  `compiler/nucleor_s1_compiler.nr`: `:173`, `:4184`, `:4243`,
  `:4715`, `:4879`, `:31517-31527` (audit-pass info). Real
  enforcement is the source-level pre-pass
  `enforce_requires_direct_calls:11627`, registered in the build
  pipeline at `:32196`.
- **`restricts [...]` parser surfaces:** the previous parse-time
  fail-closed panic lived at `parse_primary:2261-2268`; this dispatch
  replaces it with a passthrough parse. Other parser positions
  (`:185`, `:192`, `:221`, `:239`, `:253`, `:2269`, `:3884`) remain
  inert. The audit-pass surface is `:31520-31531`.
- **`with [...]` parser surfaces** (untouched in this slice):
  `:1232-1237` (skip_effect_clause + skip_bracket_list helper),
  `:11683-11756` (collect_headers_with_effect family),
  `:11758-...` (collect_no_alloc_fns), enforcement integrated
  upstream of `enforce_requires_direct_calls`.
- **`pure fn` enforcement entry point:** `:17012` (pure-fn audit
  block) and the audit-pass surface at `:31506-31530`.
- **Tools-suite restricts scanner** at
  `compiler/nucleor_tools_suite.nr:8642-8689`. This path is reached
  from the type-check pipeline, not the s1 build pipeline; the s1
  build pipeline now has its own pre-pass.
- **Active enforcement classification:**
  - **Parser-level fail-closed (pre-v0840):** block-form
    `restricts [...] { ... }` halted at parse_primary with
    `error[EFF-003]` and a diagnostic that the form is not yet
    enforced. This is the surface I replaced.
  - **Source-level pre-pass (already-shipped):**
    `enforce_requires_direct_calls` for direct same-file
    `requires [...]` row coverage; `enforce_pure_fn_effects` and
    siblings for `pure fn` direct/transitive effect surfaces.
  - **Source-level pre-pass (new in this slice):**
    `enforce_restricts_block_effects` for direct builtin / direct
    user-row violations inside a `restricts [DENY] { BODY }`.
- **Implemented surface:** block-form `restricts [...] { ... }`
  parses cleanly; `enforce_restricts_block_effects` emits EFF-003
  for direct builtin I/O / channel calls and direct same-file user
  fn calls whose `requires [...]` row overlaps the deny row.
- **Deliberately left open:** whole-program effect inference for
  un-rowed user fn callees reached transitively from a restricts
  block; cross-module propagation; methods, closures, higher-order
  effects; broader RFC-0033 effect-row subtyping (e.g. multi-token
  with-row covering); the RFC-0063 parser unification / duplicate
  deletion that would consolidate the s1 and tools-suite restricts
  scanners (out-of-scope per dispatch boundaries).

## Implementation

### Parser change — `compiler/nucleor_s1_compiler.nr:2261-2287`

Replaced the parse_primary fail-closed branch with passthrough parse:

```nucleor
if tt == 1 && str_eq(pkv(tokens, pos), "restricts") == 1 && pk(tokens, pos + 1) == 54 {
    let after_brackets: i64 = skip_bracket_list(tokens, pos + 1);
    return parse_passthrough_block_expr(tokens, after_brackets, pool);
};
```

The block body is parsed as a normal block expression, identical
shape to the existing `unsafe { ... }` / `wrapping { ... }` /
`saturating { ... }` block-form siblings.

### New helpers — `compiler/nucleor_s1_compiler.nr:11697-11789`

Four new helpers, each `#[manual_drop]`:

- `restricts_builtin_effect(name)` — minimum builtin → effect map.
  Covers `print`, `println`, `print_int`, `print_str`,
  `print_int64`, `putchar` → `io.write`; `getchar` → `io.read`;
  `channel` → `sync`. Returns `""` for any other identifier.
- `restricts_row_covers_effect(row, eff)` — symmetric overlap. True
  if any token in `row` either equals `eff`, is a parent of `eff`
  (`row_token + "."` prefix of `eff`), or is a child of `eff`
  (`eff + "."` prefix of `row_token`). The third arm matters: deny
  `[io.read]` must trap a callee declared `requires [io]` because
  the broader callee row could exercise io.read.
- `effect_row_intersect_first(deny_row, callee_row)` — returns the
  first effect named in `callee_row` that overlaps `deny_row`, `""`
  if none. Symmetric to the existing `effect_row_first_missing`
  used for requires propagation.
- `restricts_extract_call_names(body)` — walks `body` once after
  `strip_strings_and_line_comments` and returns identifier tokens
  that appear in call position (`IDENT(`).

### New pre-pass — `compiler/nucleor_s1_compiler.nr:11791-11933`

`enforce_restricts_block_effects(diags, source)`. Skips immediately
if `restricts` does not appear in source. Otherwise reuses the
already-defined `collect_requires_effect_rows(source)` to enumerate
same-file user fn rows, then walks the source character-by-character
skipping line comments, strings (with `\` escape handling), and
char literals. For each top-level `restricts` keyword token with a
proper word-boundary prefix and a `[` / whitespace-then-`[` follow,
it brackets-skips to the matching `]`, then locates the `{`,
brackets-skips the body, and runs `restricts_extract_call_names` on
the body. Per call:

1. Builtin effect lookup → if found, check
   `restricts_row_covers_effect(deny_row, b_eff)` and emit EFF-003
   on overlap.
2. Otherwise scan the requires-rows table for the callee → if
   found, run `effect_row_intersect_first(deny_row, row)` and emit
   EFF-003 on the first overlapping effect.

The pre-pass emits at most one EFF-003 per restricts block to
avoid diagnostic flooding on a many-call body. Un-rowed user fn
callees are deliberately not flagged here — `enforce_requires_direct_calls`
already traps the transitive class on the requires-row surface, and
conservative "fail every un-rowed callee" would block legitimate
clean helpers.

### Pipeline wiring — `compiler/nucleor_s1_compiler.nr:32197-32208`

Added `diags = enforce_restricts_block_effects(diags, max_depth_source);`
right after the existing `enforce_requires_direct_calls` call,
before `enforce_deadline_safety`.

### Audit-pass message updated — `:31530`

The `EFF-G123` audit-pass info message now states the v0840 status
("Block-form `restricts [...] { ... }` now parses cleanly and a
same-file pre-pass emits EFF-003 for direct builtin I/O / channel
calls and direct calls to user fns whose declared `requires [...]`
row overlaps the deny row...") instead of the prior "now fails
closed with EFF-003 instead of implying an unenforced guarantee"
language.

### Fixtures

New:

- `tests/err/err_restricts_block_builtin_io.nr` — direct
  `putchar(65)` under `restricts [io.write]`. Expects
  `error[EFF-003]`. Distinct from the existing
  `err_restricts_builtin_io.nr` (deny family `io`, builtin
  `print_int`) — pins the sub-effect-specific deny row plus a
  different print-family builtin to exercise the row-overlap path.
- `tests/features/restricts_block_clean_smoke.nr` — pure
  arithmetic + let-binding inside `restricts [io]`, returns 0.
  Pre-v0840 the same source halted at parse_primary; now the
  build succeeds and the program exits 0.

EXPECT header updated for honesty (build behavior unchanged):

- `tests/err/err_effect_inference.nr` — un-rowed `middle()` calls
  effectful `read_sensor()`. The new pre-pass does not flag the
  un-rowed callee inside the block (out-of-scope), but
  `enforce_requires_direct_calls` traps `middle()` calling
  `read_sensor()` (requires [io.read]) without declaring io.read.
  EXPECT changed from `error[EFF-003]` to `error[EFF-001]`.
- `tests/err/err_effect_deep_chain.nr` — same pattern at
  level4→level3→level2→leaf. `enforce_requires_direct_calls` traps
  level2 calling leaf without declaring net.connect. EXPECT changed
  from `error[EFF-003]` to `error[EFF-001]`.

### Punchlist update

`docs/rfcs/v1_PUNCHLIST.md` lines 125+ rewritten: block-form
restricts is now DONE Phase 2b first slice instead of Phase 1
fail-closed. The rewrite enumerates which fixtures fire EFF-003
under the new code, which now surface EFF-001 instead, and what
remains queued (whole-program effect inference for restricts blocks).

## Changed files

```text
compiler/nucleor_s1_compiler.nr                           (modified)
docs/rfcs/v1_PUNCHLIST.md                                 (modified)
tests/err/err_effect_deep_chain.nr                        (EXPECT updated)
tests/err/err_effect_inference.nr                         (EXPECT updated)
tests/err/err_restricts_block_builtin_io.nr               (new)
tests/features/restricts_block_clean_smoke.nr             (new)
tools/audit_dup_fns_report.csv                            (regenerated)
findings/inbox/local_claude_r05_effects_compiler_v0840_2026-05-06.md (this file)
```

## Focused validation

### S1 self-build with the checked-in compiler

```text
> .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_effects_s1_v0840 --no-cache --no-link
  source: compiler/nucleor_s1_compiler.nr (2188215 bytes)
  mode: fast (ownership + type)
  mode: llvm-only (--no-link)
cache: disabled (sha=none, size 0 MB)
  functions: 830
  strings: 6048
  optimized: 2109 instructions
  DCE: 34 of 830 fns elided as unreachable
  emitted: target/_local_claude_effects_s1_v0840.ll (11596848 bytes)
EXIT=0

> .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _local_claude_effects_s1_v0840 --no-cache
  ...
  compiled: target\_local_claude_effects_s1_v0840.exe
EXIT=0
```

### New fixtures against the new compiler

```text
> .\target\_local_claude_effects_s1_v0840.exe build tests\err\err_restricts_block_builtin_io.nr -o _v0840_neg --no-cache
error[EFF-003]: call to `putchar()` uses effect `io.write` denied by `restricts [io.write]` (audit R05-D4 v0.8.323)
EXIT=1

> .\target\_local_claude_effects_s1_v0840.exe build tests\features\restricts_block_clean_smoke.nr -o _v0840_pos --no-cache
  emitted: target/_v0840_pos.ll (41088 bytes)
  compiled: target\_v0840_pos.exe
BUILD_EXIT=0

> .\target\_v0840_pos.exe ; echo $LASTEXITCODE
RUN_EXIT=0
```

### Sweep — pre-existing effects fixtures still halt

```text
fixture                              build_exit  EFF-001  EFF-003
err_restricts_block_builtin_io.nr    1                    EFF-003   (new)
err_restricts_builtin_io.nr          1                    EFF-003
err_restricts_violation.nr           1           EFF-001  EFF-003
err_restricts_specific.nr            1           EFF-001  EFF-003
err_restricts_channel_effect.nr      1                    EFF-003
err_effect_inference.nr              1           EFF-001
err_effect_transitive.nr             1           EFF-001  EFF-003
err_effect_deep_chain.nr             1           EFF-001
err_effect_requires_direct.nr        1           EFF-001
err_requires_row_direct_call.nr      1           EFF-001

restricts_block_clean_smoke.nr       build=0  run=0       (new)
requires_row_clean_smoke.nr          build=0  run=0
effect_requires_direct_ok.nr         build=0  run=0
```

All ten existing negative fixtures still halt the build (exit 1).
The two whose EXPECT was updated (`err_effect_inference`,
`err_effect_deep_chain`) surface EFF-001 from the existing
`enforce_requires_direct_calls` instead of EFF-003 from the prior
parse-time panic — build still fails loudly.

### Drift / ABI / whitespace / perf gates

```text
> bash tools/check_compiler_drift.sh
... (parser-divergence WARNs are pre-existing RFC-0063 Phase 2.0 work) ...
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: promoted compiler version matches source (0.8.323)
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
OK: audit_dup_fns_report.csv is up to date
OK: CHANGELOG.md covers every git tag
OK: s1 compiler_version_label() matches CHANGELOG.md (0.8.323)
OK: tools_suite compiler_version_label() matches CHANGELOG.md (0.8.323)
OK: no opt-in privatization markers (pub fn) in compiler source
DRIFT_EXIT=0

> bash tools/check_rod_void_abi.sh
OK: rod void ABI clean (355 C void nuc_* definitions, 1272 non-void rod externs checked)
ABI_EXIT=0

> git diff --check
(clean — only an LF→CRLF advisory on tools/audit_dup_fns_report.csv from regeneration)
DIFF_EXIT=0

> pwsh -NoProfile -File tools\check_perf_regression.ps1
OK perf: cold=3.27s (max 4s) | hot=0.43s (max 1s) | mem cold_tree=343/400MB cold_compiler=329/350MB hot_tree=69/128MB hot_compiler=55/64MB
PERF_EXIT=0

(re-confirmed)
OK perf: cold=3.57s (max 4s) | hot=0.40s (max 1s) | mem cold_tree=343/400MB cold_compiler=329/350MB hot_tree=69/128MB hot_compiler=55/64MB

(third confirmation after audit-message edit)
OK perf: cold=3.56s (max 4s) | hot=0.41s (max 1s) | mem cold_tree=335/400MB cold_compiler=321/350MB hot_tree=69/128MB hot_compiler=55/64MB
```

Cold compile stays well under 4 s. Hot compiler peak (55 MB)
sits 9 MB under the 64 MB ceiling — the new pre-pass is the most
likely contributor (full-source character walk plus
`collect_requires_effect_rows` rerun). One first-attempt sample
crossed at 66 MB before the perf script took its 3-sample median;
all subsequent runs stayed at 55. Followup work to claw back hot
headroom (a tighter early-return that can distinguish
code-position `restricts [` from comment/string occurrences without
walking the whole source twice, or memoizing the rows table across
both effect pre-passes) is suggested but not a blocker for this
ship.

### Drift gate followup

The first run of `check_compiler_drift.sh` reported
`audit_dup_fns_report.csv is stale` because the new helpers added
five new `fn` definitions to the s1 source. Regenerated via
`./bin/nucleor.exe build tools/audit_dup_fns.nr -o audit_dup_fns &&
./target/audit_dup_fns.exe`; the second run is OK. The CSV update
is included in this branch.

### Branch hygiene note

While I was running the perf gate, the helper2 lane checked out
its own branch in the same working copy and committed
`4d78c4b2 RFC-0063 tools-suite duplicate wave 3` — leaving my
uncommitted edits sitting on top of the helper2 branch instead of
the local-claude branch. I stashed-with-untracked, switched back to
`fix/local-claude-r05-effects-compiler-v0840`, and restored the
stash cleanly (no merge conflicts because the two lanes touched
disjoint files). All edits described above land on the
local-claude branch.

## Residual R05 / RFC-0033 gap table

| Surface | Status (post-v0840) | Locked-by fixture |
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
| Block-form `restricts [...]` direct builtin I/O | DONE v0840 | `err_restricts_block_builtin_io.nr` (new), `err_restricts_builtin_io.nr` |
| Block-form `restricts [...]` direct user-row overlap | DONE v0840 | `err_restricts_violation.nr`, `err_restricts_specific.nr`, `err_effect_transitive.nr` |
| Block-form `restricts [...]` channel builtin | DONE v0840 | `err_restricts_channel_effect.nr` |
| Block-form `restricts [...]` clean compile | DONE v0840 | `restricts_block_clean_smoke.nr` (new) |
| Block-form `restricts [...]` transitive un-rowed user fn | OPEN — Phase 2b | `enforce_requires_direct_calls` keeps the build red via EFF-001 (`err_effect_inference.nr`, `err_effect_deep_chain.nr`); restricts-side EFF-003 returns when whole-program inference lands |
| Transitive `requires [...]` propagation (multi-hop) | OPEN — Phase 2b | fail-closed companions only |
| Cross-module propagation | OPEN — Phase 2b | none |
| Methods / closures / higher-order effects | OPEN — Phase 2b | none |
| Broader effect-row subtyping (multi-token, families, with) | OPEN — Phase 2b | none |
