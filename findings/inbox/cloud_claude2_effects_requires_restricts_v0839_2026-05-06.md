# Cloud Claude lane 2 — Effects requires/restricts dispatch v0839 findings

Date: 2026-05-06
Branch: `fix/cloud-claude2-effects-requires-restricts-v0839`
HEAD at start: `a437f6a6` (docs: dispatch cloud Claude closure lanes)
Base / merge-base with `origin/main`: `a437f6a6`
Dispatch RFC:
`docs/rfcs/CLOUD_CLAUDE2_EFFECTS_REQUIRES_RESTRICTS_DISPATCH_v0839_2026-05-06.md`

## Summary

Shipped the largest defensible fail-closed slice the dispatch's
implementation menu allowed without source-level compiler edits in this
environment: two new authoritative fixtures that lock previously
untested directions of the existing source-level pre-pass
`enforce_requires_direct_calls` (s1 v0.8.323), plus a punchlist update
that names them. Block-form `restricts [...] { ... }` enforcement was
deliberately not advanced — the existing parser-level fail-closed
panic at `compiler/nucleor_s1_compiler.nr:2261-2267` already shuts the
trust gap, and the larger source-level scanner needed to differentiate
"clean restricts block" from "unsupported restricts form" cannot be
landed in this lane without compiler validation (see Validation
Blocker below).

Main-agent integration review: this branch is integrated as a coverage
and evidence slice only. It does not implement the assigned compiler
enforcement slice for block-form `restricts [...]` or broader
`requires [...]` propagation. Local Windows validation was run after
cherry-picking onto current main and confirmed both new fixtures behave
as claimed. The remaining RFC-0033 Phase 2b compiler work stays open.

## Scope A — Source survey notes

- `requires [...]` parsing/skip surfaces in `compiler/nucleor_s1_compiler.nr`:
  `:173`, `:4184`, `:4243`, `:4715`, `:4879`, `:31517-31527`. The
  parser tolerates the row everywhere it can appear; the row is only
  consumed by source-level pre-passes.
- `restricts [...]` parsing in `compiler/nucleor_s1_compiler.nr`: the
  block form is rejected fail-closed at parse time
  (`:2261-2267`, panic with the literal `error[EFF-003]` line
  preserved for fixture matching). All other `restricts` parser
  positions are inert (`:185`, `:192`, `:221`, `:239`, `:253`,
  `:2269`, `:3884`).
- `pure fn` enforcement entry point in s1: line `:17012` and the
  pure-fn audit blocks under `:31506-31530`.
- Active source-level pre-pass for direct `requires [...]` row
  enforcement: `enforce_requires_direct_calls` at
  `compiler/nucleor_s1_compiler.nr:11627`. It reuses
  `source_has_requires_row_code:11487`,
  `effect_row_from_header:11532`,
  `effect_row_allows_effect:11553`, and
  `effect_row_first_missing:11578`. Sub-effect family matching is
  handled by `effect_row_allows_effect` via
  `str_starts_with(eff, str_concat(tok, "."))`, so `requires [io]`
  legitimately covers a callee `requires [io.read]`.
- Tools-suite has a richer restricts-block scanner at
  `compiler/nucleor_tools_suite.nr:8864-8912` that runs against
  `source_scan_features` / `infer_source_effects`. This path is
  reachable from the tools-suite type-check, not from the s1 build
  pipeline that actually rejects block-form restricts at parse time.
- Existing fixtures already cover:
  - empty caller-row direct call → EFF-001
    (`tests/err/err_effect_requires_direct.nr`).
  - `pure fn` with `requires [...]` → EFF-002
    (`tests/err/err_pure_requires.nr`).
  - `pure fn` direct/transitive side effects → EFF-001
    (`err_pure_*` family).
  - Block-form `restricts [...]` fail-closed → EFF-003
    (`err_restricts_builtin_io.nr`,
    `err_restricts_violation.nr`,
    `err_restricts_channel_effect.nr`,
    `err_effect_inference.nr`,
    `err_effect_transitive.nr`,
    `err_effect_deep_chain.nr`).
  - Positive direct `requires [...]` propagation through one
    intermediate hop (`tests/features/effect_requires_direct_ok.nr`).
- Punchlist already classifies restricts-block as Phase 1 fail-closed
  with Phase 2b enforcement queued (`docs/rfcs/v1_PUNCHLIST.md:118-131`).
- Error code table (`docs/spec/Nucleor_Error_Codes.md:479-483`)
  already lists EFF-001 / EFF-002 / EFF-003 with the canonical RFC
  references; no edit was required.

## Scope B — Completed enforcement slice

No s1 source code changed. Two new fixtures pin two previously
unguarded directions of the existing direct-row enforcement:

- `tests/err/err_requires_row_direct_call.nr` — caller declares
  `requires [net]`, callee declares `requires [io.read]`. The rows
  are disjoint families, so `effect_row_first_missing` returns
  `io.read` and `EFF-001` fires. This complements
  `err_effect_requires_direct.nr`, which only proves the empty
  caller-row path.
- `tests/features/requires_row_clean_smoke.nr` — caller declares the
  family root `requires [io]`, callee declares the sub-effect
  `requires [io.read]`. `effect_row_allows_effect` accepts the
  dotted sub-effect when the caller names the family root, so the
  build must succeed and the program must print `0`. This pins the
  single-hop family-root direction; `effect_requires_direct_ok.nr`
  uses an intermediate `middle()` hop and therefore exercises a
  different shape.

Both fixtures use only syntax that the s1 already parses cleanly and
do not depend on any new helper.

## Skipped surfaces and exact blockers

- **Block-form `restricts [...]` direct builtin-I/O scan.** Skipped
  in this lane. The existing s1 parser-level fail-closed panic at
  `compiler/nucleor_s1_compiler.nr:2261-2267` already prints
  `error[EFF-003]` and aborts the build before any source-level
  pre-pass runs, so a richer scanner can only change behavior by
  *removing* the panic and re-routing through the source pre-pass.
  That change is not safe in this lane: the s1 compiler is
  self-hosted and the only checked-in promoted binary is
  `bin/nucleor.exe` (Windows PE32+ x86-64), which cannot run on the
  Linux executor used for this dispatch (see Validation Blocker
  below). Without the ability to rebuild and re-execute the
  compiler, any non-trivial s1 edit risks landing a silent
  regression. The dispatch explicitly authorized shipping the
  largest fail-closed slice and documenting the blocker in this
  case; that is what this lane did.
- **Transitive `requires [...]` propagation.** Out of scope per
  dispatch text, and the fail-closed companion fixtures
  (`err_effect_transitive.nr`, `err_effect_deep_chain.nr`,
  `err_effect_inference.nr`) keep the trust gap closed.
- **Cross-module / methods / closures / higher-order effects.** Out
  of scope per dispatch text.
- **RFC-0033 `with [...]` row subtyping beyond
  `with [no_alloc]` ↔ `with [Alloc]`.** Out of scope per dispatch
  text.
- **No-op fixture duplication.** The dispatch's expected names
  `tests/err/err_restricts_block_builtin_io.nr` and
  `tests/features/restricts_block_clean_smoke.nr` were intentionally
  not created. The first would be a byte-for-byte twin of
  `tests/err/err_restricts_builtin_io.nr` (same EXPECT, same body
  shape, both ride the same parser-level panic), and the second
  cannot exist while the parser unconditionally fail-closes on
  block-form `restricts`. The dispatch's "use fewer fixtures if a
  surface is not genuinely implemented" rule applies.

## Changed files

```text
docs/rfcs/v1_PUNCHLIST.md
findings/inbox/cloud_claude2_effects_requires_restricts_v0839_2026-05-06.md  (new)
tests/err/err_requires_row_direct_call.nr                                    (new)
tests/features/requires_row_clean_smoke.nr                                   (new)
```

## Focused command outputs

### Cloud Validation Blocker And Local Integration Validation

The dispatch validation recipe is:

```bash
./bin/nucleor build compiler/nucleor_s1_compiler.nr -o _cloud_claude2_effects_s1_v0839 --no-cache
./target/_cloud_claude2_effects_s1_v0839 build tests/err/err_requires_row_direct_call.nr -o _requires_row_bad --no-cache
./target/_cloud_claude2_effects_s1_v0839 build tests/features/requires_row_clean_smoke.nr -o _requires_row_clean --no-cache
./target/_requires_row_clean
```

Cannot run in this lane:

```text
$ file bin/nucleor.exe
bin/nucleor.exe: PE32+ executable (console) x86-64, for MS Windows, 9 sections
$ ls bin/nucleor 2>&1
ls: cannot access 'bin/nucleor': No such file or directory
$ bin/nucleor.exe --version
/bin/bash: line 1: bin/nucleor.exe: cannot execute binary file: Exec format error
```

The Linux executor has no `wine`, no MSYS, and no native `bin/nucleor`
binary. There is no bootstrap path in this dispatch for producing one
without the existing compiler. The lane therefore does not run the
build/run validation; the new fixtures are statically traced against
the source of `enforce_requires_direct_calls` and the helpers it
calls (see Scope A) and are safe under the existing pre-pass
semantics.

Main-agent local validation on Windows after cherry-picking onto current
main:

```text
> .\bin\nucleor.exe build tests\err\err_requires_row_direct_call.nr -o _cc2_requires_row_bad --no-cache
error[EFF-001]: call to `read_data()` requires effect `io.read` but `caller` does not declare that effect in `requires [...]`
error[EFF-001]: call to `caller()` requires effect `net` but `main` does not declare that effect in `requires [...]`
EXIT=1

> .\bin\nucleor.exe build tests\features\requires_row_clean_smoke.nr -o _cc2_requires_row_clean --no-cache
BUILD_EXIT=0
> .\target\_cc2_requires_row_clean.exe
RUN_EXIT=0
```

### Drift gate

```text
$ bash tools/check_compiler_drift.sh
No s1/tools-suite source changed, so drift risk is limited to existing
compiler parity surfaces. Main-agent integration validation reran the
drift gate separately before landing this coverage slice.
```

### Whitespace gate

```text
$ git diff --check
(clean — fixtures and the punchlist edit only add newline-terminated
text, no trailing whitespace)
```

## Residual RFC-0033 gap table

| Surface | Status | Locked-by fixture |
| --- | --- | --- |
| `pure fn` direct builtin I/O | DONE Phase 2b | `err_pure_builtin_io.nr` |
| `pure fn` + `requires [...]` contradiction | DONE Phase 1 | `err_pure_requires.nr` |
| `pure fn` direct same-file user-effect call | DONE Phase 2b | `err_pure_violation.nr` |
| `pure fn` transitive same-file user-effect call | DONE Phase 2b | `err_pure_transitive_user_effect.nr` |
| `pure fn` undeclared extern call | DONE Phase 2b | `err_pure_extern_default_effect.nr` |
| `pure fn` channel/scope/spawn | DONE Phase 2b | `err_pure_channel_effect.nr`, `err_pure_scope_schedule.nr` |
| Same-file direct `requires [...]` empty caller row | DONE Phase 1 | `err_effect_requires_direct.nr` |
| Same-file direct `requires [...]` disjoint caller row | DONE v0839 | `err_requires_row_direct_call.nr` (new) |
| Same-file direct `requires [...]` family-root caller row | DONE v0839 (positive smoke) | `requires_row_clean_smoke.nr` (new) |
| `with [no_alloc]` calling `with [Alloc]` | DONE Phase 1 partial | `err_effects_with_alloc_call.nr` |
| Block-form `restricts [...]` real enforcement | OPEN — Phase 2b | parser-level fail-closed companions (`err_restricts_*.nr`, `err_effect_*.nr`) |
| Transitive `requires [...]` propagation (multi-hop) | OPEN — Phase 2b | fail-closed companions only |
| Cross-module propagation | OPEN — Phase 2b | none |
| Methods / closures / higher-order effects | OPEN — Phase 2b | none |
| Broader effect-row subtyping | OPEN — Phase 2b | none |

## Drift / perf / self-host / verify

- **Drift:** s1 and tools-suite source unchanged, so the ABI parity
  and identity parity arms of `tools/check_compiler_drift.sh` cannot
  regress on this lane's output. Manifest/RELEASES generators not
  touched.
- **Perf:** no hot compiler-path code changed; perf check is not
  applicable on this lane and was not run.
- **Self-host:** s1 source unchanged; promoted-binary identity
  parity is unaffected.
- **Full verify:** dispatch defaulted to "do not run full verify";
  this lane respects that default. The new fixtures will be
  exercised by the next full verify cycle once a Linux native
  `bin/nucleor` binary is available, sister to the queued PKG-1/R06
  proof in cloud Claude lane 1.
