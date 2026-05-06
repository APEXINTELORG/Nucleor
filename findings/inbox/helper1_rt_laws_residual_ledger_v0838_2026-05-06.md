# Helper1 Residual Ledger: RT + Laws v0838

| Item | Status after v0838 | Next required closure |
|---|---|---|
| RT transitive same-file checks | Improved. `#[no_alloc]` and `#[no_panic]` now catch caller -> helper -> known allocator/panic helper in the same file. | Replace source substring scanning with AST/IR call-graph traversal and fixed-point propagation. |
| RT cross-module checks | Open. This slice does not traverse imported modules. | Resolver must preserve callee origin and effect summaries across import records. |
| RT fn-pointer/closure dispatch | Open. This slice does not inspect indirect call targets. | Function types and closure lowering need effect metadata that can be consumed by RT diagnostics. |
| deadline/WCET backing | Open. Current contract is runtime deadline check plus heuristic RT-004 estimate, not certified WCET. | Implement cert-profile WCET/cost model or Heptane bridge; until then keep diagnostics/docs explicit. |
| law bounded integer generation | Improved. `distributive_over = g` now generates bounded integer checks. | Add inverse/fusion only after their arity/symbol contracts are explicit enough to check deterministically. |
| law float approximate semantics | Fail-closed. f64 law declarations and `eps`/`approximate` modifiers now emit LAW-004 under `--check-laws`. | Define tolerance semantics, equality policy, and generated cases before accepting float laws. |
| law optimizer rewrite gating | Open by design. This slice does not enable optimizer rewrites from user laws. | Rewrites must stay gated behind generated check/proof evidence and exact law metadata. |

## Validation Snapshot

- Temp s1 compiler build: PASS.
- Temp tools-suite build: PASS.
- RT transitive negative/positive fixtures: PASS.
- Laws distributive/fail-closed fixtures: PASS.
- Deadline/WCET contract fixture: PASS, emits heuristic `warning[RT-004]` containing `NOT certified WCET`.
- `bash tools/check_compiler_drift.sh`: PASS with existing parser-divergence warnings only.
- `bash -n tools/verify.sh`: PASS.
- `git diff --check`: PASS.
- `pwsh -NoProfile -File tools\check_perf_regression.ps1`: PASS, cold=3.49s, hot=0.39s, cold_tree=340MB, cold_compiler=326MB.

## Main Integration Note

This branch edits compiler/tools-suite source and verify hooks but does not
promote `bin/nucleor.exe` or bootstrap seed artifacts. Main should run its
normal compiler integration/fixed-point path after cherry-pick/merge, then run
the focused `tools/verify.sh --only` checks once the promoted binary contains
the source changes.
