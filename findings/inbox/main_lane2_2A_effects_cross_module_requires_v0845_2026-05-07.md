# Lane 2 / Queue 2A — Effects cross-module `requires` propagation

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Branch:** `fix/effects-cross-module-requires-depth-bump-v0845`
- **Base:** `origin/main` @ `5890c84603bd46fc6d86b9500b2ef7cd4ae4d63c`
- **Host:** Windows 11 26200, PowerShell + bash via Git for Windows
- **Worktree:** `C:\Users\JoeWe\Desktop\Nucleor_AGENT_main_lane2_v0845`

## Scope accepted

- Lane 2 / Queue 2A — determine the smallest safe compiler hook for same-package
  cross-module `requires [...]` propagation per the v0845 handoff.

## Scope explicitly not taken

- Methods / impl effect rows (Queue 2B).
- Closures, function-pointer effect capture (Queue 2C).
- Selective `use path::{a, b}` / glob imports — explicitly not yet supported in
  the resolver (RFC-0018 phase 2). These surfaces are still outside cross-module
  effect coverage even after this change.
- Cross-module raises beyond depth=8.
- Bootstrap seed promotion + `bin/nucleor.exe` swap — integrator-owned per
  handoff §"Integration Owner Checklist" step 8.

## Headline finding

**Cross-module direct + bounded transitive `requires` / `restricts` enforcement
was already closed for the flat-namespace `import "..."` surface; a stale
documentation claim and one-line depth mismatch were the only real gaps.**

The resolved-source pre-pass (`resolve_source_with_records_active` in
`compiler/nucleor_s1_compiler.nr`) inlines imported module bodies into one
combined source string before `enforce_requires_direct_calls` and
`enforce_restricts_block_effects` run on `max_depth_source`. That makes the
existing same-file diagnostic logic cover the cross-module case for direct
rowed-callee mismatches and bounded transitive un-rowed chains.

The empirical residual: the requires transitive depth was `3` (line 11752),
while the restricts transitive depth is `8` (`restricts_transitive_check`).
A 4..=7-hop un-rowed chain (cross-module OR same-file) to a builtin or rowed
leaf fell silently through the bound. Visited-set dedup already gives O(N)
termination per chain, so raising to 8 closes the silent fall-through without
adding cost on common inputs.

## Probes (pre-edit, original `bin/nucleor.exe` v0.8.323)

| Fixture (scratch `_probe_2a/`)         | Behavior                          | Status   |
|----------------------------------------|------------------------------------|----------|
| `main_negative.nr` (cross-module direct)   | `EFF-001` on `lib_print_msg()`    | Already worked |
| `main_positive.nr` (cross-module clean)    | Build + run prints "from lib"      | Already worked |
| `main_transitive_neg.nr` (cross-module 2-hop) | `EFF-001 transitive`             | Already worked |
| `main_restricts_neg.nr` (cross-module restricts block) | `EFF-003`                | Already worked |
| `main_depth_neg.nr` (cross-module 4-hop) | **silent pass — production gap**    | **Failed**     |

The `main_depth_neg.nr` chain was `caller -> hop1 -> hop2 -> hop3 -> hop4 -> print()`
declared in an imported aux module. Build succeeded silently with no diagnostic.
Per project memory `feedback_nucleor_launch_quality.md` ("silent fall-throughs
are launch blockers") this counts as a launch blocker.

## Change

Single-line bump and stale-claim cleanup, plus locking fixtures.

### Compiler

- `compiler/nucleor_s1_compiler.nr` (line ~11752): bump
  `requires_transitive_missing(... , 3, ...)` → `... , 8, ...`. Comment
  block above the call cites the v0845 lane 2 ship and the depth-3
  silent-fall-through evidence. Audit tag `R05-D6 v0844 transitive` →
  `R05-D6 v0845 transitive` so the diagnostic regression-tracks against
  the new ship.
- `compiler/nucleor_s1_compiler.nr` EFF-G123 banner (line ~32211):
  removed the stale "cross-module propagation" entry from the open list,
  added an explicit closed-status sentence for the flat-namespace
  `import "..."` surface, and surfaced the remaining real gaps
  (depth>8 chains, methods/impl, closures, fn-pointer capture, RFC-0033
  subtyping, selective/glob imports). Banner now also calls out the
  depth-bump from 3 → 8 so adopter audits read consistent with code.

### Tests

Eight new fixtures (`_aux.nr` lib helpers are skipped from standalone
iteration via `tools/verify.sh:429 TEST_SKIP_REGEX='_aux\.nr$|...'`):

| File | Class | EXPECT |
|---|---|---|
| `tests/err/err_requires_cross_module_aux.nr` | lib helper | (skipped) |
| `tests/err/err_requires_cross_module_direct.nr` | negative | `error[EFF-001]` |
| `tests/err/err_requires_cross_module_transitive.nr` | negative | `error[EFF-001]` |
| `tests/err/err_requires_cross_module_depth.nr` | negative | `error[EFF-001]` (locks the depth=8 bump) |
| `tests/err/err_restricts_cross_module_aux.nr` | lib helper | (skipped) |
| `tests/err/err_restricts_cross_module_transitive.nr` | negative | `error[EFF-003]` |
| `tests/features/requires_cross_module_aux.nr` | lib helper | (skipped) |
| `tests/features/requires_cross_module_clean_smoke.nr` | positive | clean build + prints "aux ok" |

### Punchlist

- `docs/rfcs/v1_PUNCHLIST.md` Effects/capabilities §"Still open":
  cross-module entry replaced with a v0845 lane 2 closed-status entry
  citing the eight locking fixtures; remaining-open list now reflects
  the surfaces that genuinely remain.

## Validation transcript (Windows host, stage1 from edited source)

Stage1 build:

```
./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_s1_lane2 --no-cache
  source: compiler\nucleor_s1_compiler.nr (2214332 bytes)
  ... compiled: target\nucleor_s1_lane2.exe
real    0m3.067s
```

All four new negative fixtures emit the expected diagnostic against
`target/nucleor_s1_lane2.exe`:

```
err_requires_cross_module_direct.nr
  error[EFF-001]: call to `rowed_io_write()` requires effect `io.write`
  but `caller` does not declare that effect in `requires [...]` (audit
  R05-D3 v0.8.323)

err_requires_cross_module_transitive.nr
  error[EFF-001]: call chain from `caller()` reaches effect `io.write`
  but its `requires [...]` row does not declare that effect (audit
  R05-D6 v0845 transitive)

err_requires_cross_module_depth.nr (4-hop chain, depth=3 silent-pass case)
  error[EFF-001]: call chain from `caller()` reaches effect `io.write`
  but its `requires [...]` row does not declare that effect (audit
  R05-D6 v0845 transitive)

err_restricts_cross_module_transitive.nr
  error[EFF-003]: block uses effect `io.write` via call chain ending
  in `print()` denied by `restricts [io.write]` (audit R05-D6 v0843
  transitive)
```

Positive smoke compiles and runs:

```
tests/features/requires_cross_module_clean_smoke.nr
  emitted: target/pos_clean.ll (40670 bytes)
  compiled: target\pos_clean.exe
./target/pos_clean.exe → "aux ok" exit 0
```

Existing same-file fixtures unchanged in behavior:
- `tests/err/err_requires_row_direct_call.nr` — still fires EFF-001 on `read_data()`.
- `tests/err/err_requires_row_transitive_builtin_io.nr` — still fires
  EFF-001 transitive (now tagged v0845 — diagnostic-text-only delta).
- `tests/features/requires_row_clean_smoke.nr` — clean build.
- `tests/features/requires_row_transitive_builtin_ok.nr` — clean build.

Self-host fixed-point + bootstrap seed status:

```
bash tools/check_self_host_md5.sh
  self-host-md5: building stage1 from bin/nucleor
  self-host-md5: building stage2 from target/_self_host_md5_stage1.exe
  FAIL: bootstrap seed is stale relative to stage2 compiler IR
    stage2: target/_self_host_md5_stage2.ll md5=a80fec574b52ee427f7990e425cb751c
    seed:   bootstrap/nucleor_s1_seed.ll md5=8c6578d8e5feed0f27d86cf8db78f8a9
```

Stage1 IR md5 == Stage2 IR md5 (the script reaches the seed-staleness
branch only after the S1==S2 check passes at line 126 of
`tools/check_self_host_md5.sh`). The seed staleness is the expected
artifact of editing s1; per handoff §Integration-Owner-Checklist step 8,
seed regeneration + `bin/nucleor.exe` promotion happen on main as
integrator work, not on this feature branch.

Drift / ABI / whitespace:

```
bash tools/check_compiler_drift.sh
  ... OK: tools-suite ABI tables match nucleor_s1_compiler.nr
  ... OK: promoted compiler version matches source (0.8.323)
  ... OK: helper_manifest.toml is up to date
  ... OK: rod_manifest.toml is up to date
  ... OK: RELEASES.md is up to date
  ... OK: audit_dup_fns_report.csv is up to date
  ... OK: CHANGELOG.md covers every git tag
  ... OK: no opt-in privatization markers (pub fn) in compiler source
  (RFC-0063 12-token-id witness drift carries over from prior waves —
  not regressed by this change)

bash tools/check_rod_void_abi.sh
  OK: rod void ABI clean (355 C void nuc_* definitions, 1275 non-void rod externs checked)

git diff --check
  (clean, exit 0)
```

Perf gate (Windows):

```
pwsh -NoProfile -File tools\check_perf_regression.ps1
  OK perf: cold=3.36s (max 4s) | hot=0.4s (max 1s)
           mem cold_tree=347/400MB cold_compiler=332/350MB
           hot_tree=70/128MB hot_compiler=55/64MB
```

Full `tools/verify.sh` was NOT run on this branch — the depth-bump
relies on a stage1 binary, and the verify gate uses `bin/nucleor.exe`
directly. Verify becomes meaningful once the integrator promotes
`bin/nucleor.exe` + regenerates `bootstrap/nucleor_s1_seed.ll`.

## Files changed

```
compiler/nucleor_s1_compiler.nr                                  (2 hunks)
docs/rfcs/v1_PUNCHLIST.md                                        (1 hunk)
tests/err/err_requires_cross_module_aux.nr                       (new)
tests/err/err_requires_cross_module_direct.nr                    (new)
tests/err/err_requires_cross_module_transitive.nr                (new)
tests/err/err_requires_cross_module_depth.nr                     (new)
tests/err/err_restricts_cross_module_aux.nr                      (new)
tests/err/err_restricts_cross_module_transitive.nr               (new)
tests/features/requires_cross_module_aux.nr                      (new)
tests/features/requires_cross_module_clean_smoke.nr              (new)
findings/inbox/main_lane2_2A_effects_cross_module_requires_v0845_2026-05-07.md (this report)
```

## Honest residuals

1. **Bootstrap seed regeneration + bin/nucleor.exe promotion** — required
   before `tools/verify.sh` exercises this change. Integrator owns per
   handoff §Integration-Owner-Checklist step 8.
2. **Depth=8 ceiling** — chains of 9+ un-rowed hops still silent-pass.
   Per memory `feedback_nucleor_launch_quality.md` this remains a residual
   silent fall-through but the ceiling is now disclosed consistently in the
   EFF-G123 banner and in the punchlist. Closing it requires either an
   unbounded visited-set walk (terminates by dedup) or the deeper Phase 4
   AST-based effect-row inference. Either is broader scope than Queue 2A.
3. **Selective / glob imports** — `use path::{a, b}` and `use path::*`
   are explicitly not yet supported (resolver phase 2 / RFC-0018). Their
   cross-module effect coverage is therefore moot until the resolver phase
   lands. Adopters today must use `import "..."` flat namespace, which is
   what this lane proves.
4. **Method calls / impl blocks** — Queue 2B. Not in scope here.
5. **Closures / fn pointers** — Queue 2C. Not in scope here.
