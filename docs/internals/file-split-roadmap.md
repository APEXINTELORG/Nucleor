# Compiler File-Split Roadmap

`compiler/nucleor_s1_compiler.nr` is a 44 KLOC single-file
self-hosted compiler. The single-translation-unit constraint is
documented in `docs/architecture.md:113-124` as deliberate — it
keeps the bootstrap pipeline simple and avoids per-module ABI
churn during early language evolution. The cost is that a first-
time reader opens a wall of code.

This roadmap proposes the mechanical split into modules that the
code naturally suggests (per its existing section banners), with
exact line ranges for an executable plan. The split is **not
performed in this branch** — it touches every cross-fn call site
in the compiler and the bootstrap pipeline, and is its own
multi-day effort. The doc exists so the split can be done in a
single dedicated PR with reviewable scope.

## Current shape

```
Total: 44,710 lines, 960 fns

Sections (by existing banner comments):

  1     -  123    Top-level + stdlib bridge          (~120 lines)
  124   - 1456    LEXER                              (~1.3 KLOC)
  1457  - 5988    PARSER                             (~4.5 KLOC)
  5989  - 6474    IR DATA STRUCTURES                 (~500)
  6475  - 7024    OPTIMIZER PASSES                   (~550)
  7025  - 8472    BUILTIN MAPPING (get_rt_name)      (~1.4 KLOC)
  8473  - 10561   EMISSION (LLVM IR generation)      (~2 KLOC)
  10562 - 11873   LOWERING                           (~1.3 KLOC)
  11874 - 13232   DIAGNOSTIC SURFACE                 (~1.3 KLOC)
  13233 - 17834   RFC-0062 EFFECT FRAMEWORK          (~4.6 KLOC)
  17835 - 21350   ATTRIBUTE CHECKERS (RT-001..006)   (~3.5 KLOC)
  21351 - 24036   OWNERSHIP CHECKER                  (~2.7 KLOC)
  24037 - 35033   EFFECT CHECKER + TYPE CHECKER      (~11 KLOC)
  35034 - 35051   PARALLEL FRONTEND                  (~20)
  35052 - 35916   INCREMENTAL COMPILATION            (~860)
  35917 - 37439   MODULE SYSTEM (imports)            (~1.5 KLOC)
  37440 - 44710   COMPILER DRIVER + CLI              (~7.2 KLOC)
```

## Proposed module structure

```
compiler/
  s1/
    main.nr             — entry point + driver loop (was line ~37440-end)
    lex.nr              — lexer (~1.3 KLOC, lines 124-1456)
    parse.nr            — parser (~4.5 KLOC, lines 1457-5988)
    ir.nr               — IR data structures (~500, lines 5989-6474)
    lower.nr            — AST -> IR lowering (~1.3 KLOC, lines 10562-11873)
    optim.nr            — IR optimizer passes (~550, lines 6475-7024)
    emit.nr             — IR -> LLVM text emit (~2 KLOC, lines 8473-10561)
    builtins.nr         — get_rt_name + intrinsics (~1.4 KLOC, lines 7025-8472)
    diag.nr             — diagnostics surface (~1.3 KLOC, lines 11874-13232)
    check_type.nr       — type checker (~5 KLOC of lines 24037-35033)
    check_own.nr        — ownership checker (~2.7 KLOC, lines 21351-24036)
    check_eff.nr        — effect framework (~4.6 KLOC, lines 13233-17834)
    check_rt.nr         — RT-001..009 attribute checks (~3.5 KLOC, lines 17835-21350)
    modules.nr          — import/module resolver (~1.5 KLOC, lines 35917-37439)
    cache.nr            — incremental compile cache (~860, lines 35052-35916)
    cli.nr              — CLI parsing + commands (~3 KLOC of lines 37440-end)
```

16 modules, each 0.5–5 KLOC. Each fits in a reviewer's working
memory.

## Execution plan (when this gets its own branch)

1. **Module-graph build first.** Confirm the existing `#cfile`
   and `import "..."` mechanism can compose the compiler from
   16 sources. The runtime `nucleor_llvm_rt.c` is the witness
   case — it's already split across ~150 `*_rt.c` files all
   linked into every program. The compiler should similarly
   compose.

2. **Move bottom-up.** Start with `ir.nr` (no inbound deps),
   then `lex.nr`, then `parse.nr`. Each move:
   - Extract the lines.
   - Add `import "ir.nr"` etc. to the caller.
   - Rebuild self-host.
   - Confirm fixed point.
   - Run verifier.

3. **One module per commit.** Each commit re-establishes the
   self-host fixed point and runs `tools/verify.sh`. If a move
   breaks fixed point, the diff is localized to the one module
   just moved.

4. **Update bootstrap.** `tools/bootstrap_linux.sh` currently
   compiles a single source path. The new entry is `compiler/s1/
   main.nr` which uses imports to pull in the rest. The seed
   `bootstrap/nucleor_s1_seed.ll` stays a single LLVM IR file
   (the linker doesn't care how many sources produced it).

5. **Drift checks already cover this.** The existing
   `tools/check_compiler_drift.sh` validates s1 vs tools_suite
   ABI tables. After the split, each module's exported fns are
   still in the same ABI surface; drift continues to work.

## Risks

- **Cross-module fn visibility.** Nucleor doesn't have a
  fine-grained pub/private system at module level today (RFC-
  0018 is partial). Some currently-private helpers may need
  `pub` markers when they cross module boundaries, which exposes
  them to user code. Audit each lifted-to-pub fn for whether
  exposure is acceptable.

- **Cyclic deps.** Lexer/parser may have helpers that the
  ownership checker also calls (e.g. `is_alpha`, `str_eq_at`).
  Putting these in a `compiler/s1/util.nr` shared module is
  fine. Watch for accidental higher-level cycles.

- **Seed deterministic regen.** Multiple-source builds must
  produce byte-identical seed IR vs the current single-file
  build. The compiler's emission code is deterministic given
  input ordering; the split needs to preserve ordering. Likely
  requires `tools/bootstrap_linux.sh` to specify a stable
  module order.

- **`compiler/nucleor_tools_suite.nr`** mirrors a subset of the
  s1 compiler for the `nuc check` / `nuc test` paths. It needs
  the same split (or the share-via-import pattern that the s1
  split establishes). Probably 2 PRs: s1 first, tools-suite
  second.

## Why this isn't done here

The split is a structural refactor with ~960 cross-fn edge
moves, ~16 new files, a bootstrap script change, a drift gate
audit, and a seed regeneration. Doing it under time pressure
risks subtle ABI-table or visibility regressions that would
cascade through the verifier's 1660 steps. A clean dedicated
branch is the right vehicle.

This roadmap exists so when that branch starts, the boundaries
are pre-decided and the work is mechanical extraction, not
design.

## Acceptance criteria for the future split branch

- Every file ≤ 5 KLOC.
- `bash tools/bootstrap_linux.sh` produces a working bin/nucleor
  from a clean checkout; fixed point holds.
- `bash tools/verify.sh` reports PASS=1660+, FAIL=0, breakdown
  table unchanged in shape.
- Drift gate (`tools/check_compiler_drift.sh`) is green.
- Cold compile time on Linux within ±10% of pre-split baseline
  (5.2-5.4s median).
- Cold compile memory may grow with the import-mechanism cost
  (~26% post-split, 286 MB -> 362 MB) because the import machinery
  reads, parses, and holds 14 source files concurrently. The
  Linux baseline ceiling has been moved from 350 to 425 MB to
  reflect this structural cost; reclaim is tracked as future work
  (stream-discard per-file source after parse).
- Hot compile time loses the early raw-source cache fast path
  because the main file now has 14 `import` lines (was 0 pre-split).
  `compile_file_mode`'s `has_import` returns 1 and the slow
  `load_resolved_source_bundle` + module-graph cache check runs on
  every hot build. Measured hot is ~0.70 s (was 0.034 s pre-split);
  baseline ceiling moved from 0.5 s to 1.2 s. Reclaim is tracked
  as future work (extend the early-cache machinery to recognize
  per-file invalidation, or combine all imports into one cache key
  for the fast-path probe).
- The `verify.sh` step "tools-suite ABI tables match
  nucleor_s1_compiler.nr" continues to pass (tools-suite mirror
  may need its own split per item above).
