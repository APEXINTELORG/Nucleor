# Cloud Lane 8 / Queue 8J — Round-3 verify transcript on current main

## Summary

Native Linux `bash tools/verify.sh` end-to-end on current `origin/main` after
fresh-clone bootstrap. **All 5 root-cause buckets from 8C are now empty**, and
the Round-3 transcript drops failures from 30 → 1 (the residual is a
small/deterministic regex bug in the EXPECT-header smoke check, not a
compiler/runtime issue, and is fixed in the same commit batch).

| Run | Base SHA | Steps | PASS | SKIP | FAIL | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 8C baseline | 5890c84 | 1273 | 1237 | 6 | 30 | per `cloud_claude_lane8_8C_v0845_2026-05-07.md` |
| 8J fresh | c1eea2e | 1299 | 1292 | 6 | 1 | this report (pre-fix) |
| 8J post-fix | 82f183d4 | 1299 | 1293 | 6 | 0 | after `_aux.nr` skip applied to the EXPECT-header smoke |

26 new steps appeared between 8C and 8J (1273 → 1299) from the post-8C
Lane 2 effects, Lane 3 RT, partner Lane 6, and #[deadline] integrations.

## Host

```
$ uname -a
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

$ command -v clang && clang --version | head -1
/usr/bin/clang
Ubuntu clang version 18.1.3 (1ubuntu1)

$ command -v cargo && cargo --version
/root/.cargo/bin/cargo
cargo 1.94.1 (29ea6fb6a 2026-03-24)

$ command -v rustc && rustc --version
/root/.cargo/bin/rustc
rustc 1.94.1 (e408947bf 2026-03-25)

$ command -v pwsh
(missing — not exercised by verify)

$ command -v ssh-keygen
(missing — not exercised by verify)
```

## Bootstrap

The fresh clone shipped Windows `bin/nucleor.exe` only. Ran the Linux
bootstrap:

```
$ bash tools/bootstrap_linux.sh
==> stage-1 link: clang bootstrap/nucleor_s1_seed.ll + runtime → bin/nucleor
    stage-1 binary: 2211632 bytes
    stage-1 --version: nucleor 0.8.323 (self-hosted, llvm backend)
==> stage-2 self-rebuild: bin/nucleor build compiler/nucleor_s1_compiler.nr
==> fixed-point check: target/nucleor_s2.ll vs bootstrap/nucleor_s1_seed.ll
    fixed point: sha256=416954863b9551c0a1010cc3f136172b975bd47caf75e6ac5740e7ab9f0b5d81
==> stage-2 link (sanity): clang target/nucleor_s2.ll + runtime → bin/nucleor
    stage-2 binary: 2211632 bytes
==> bootstrap complete: bin/nucleor ready
```

Then `bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools` and
`cp target/nucleor_tools bin/nucleor_tools` to give the verify gate the
tools-suite entry point it expects.

## Round-3 8C-bucket coverage

| Bucket | 8C count | 8J count | Status |
| --- | --- | --- | --- |
| R1 — `nuc test` link missing `-lm` | 21 | 0 | CLEARED on main via c1eea2e |
| R2 — POSIX `#else` missing 9 RNG bridges | 4 | 0 | CLEARED on main via c1eea2e |
| R3 — `nuc init` no `mkdir -p src/` | 2 | 0 | CLEARED on main via c1eea2e |
| R4 — `nuc clean --cache` | 1 | 0 | CLEARED on main via c1eea2e |
| R5 — Linux ELF build-id varies | 2 | 0 | CLEARED on main via c1eea2e |
| Windows-only fixture (path_utils) | 1 | 0 | CLEARED on main via c1eea2e (8L gate) |
| **Total** | 30 | 0 | |

## New failure introduced post-8C

Single net-new failure on the Round-3 transcript:

```
[  8/1299] FAIL  tests/err/*.nr have EXPECT headers  (  0.03s)
       err tests missing EXPECT header:
         - err_no_alloc_cross_module_aux.nr
         - err_no_alloc_depth_chain_aux.nr
         - err_no_panic_cross_module_aux.nr
         - err_requires_cross_module_aux.nr
         - err_restricts_cross_module_aux.nr
```

**Classification:** verify-side regex omission. Not a compiler/runtime bug.

**Cause:** The Lane 3 cross-module no_alloc / no_panic / requires / restricts
integrations landed five auxiliary fixtures in `tests/err/`. Each one is
imported by its non-aux sibling and carries no standalone `// EXPECT:`
header by design — every `_aux.nr` file in the repo notes "Skipped from
standalone iteration via the `_aux.nr$` regex in `tools/verify.sh`
(TEST_SKIP_REGEX)" in its comment block, and the operating rules in
`Cloud_Control1.md` explicitly call out the `_aux.nr$` skip regex.

`tools/verify.sh` already defines `TEST_SKIP_REGEX='_aux\.nr$|import_dedupe_lib\.nr$'`
at line 433 and applies it at lines 438, 1344, 5656. The
`err_tests_have_expect_smoke` function (lines 685-712) was the only call
site that iterated `tests/err/*.nr` with a bash glob and skipped the
filter — pre-Lane-3 there were no `_aux.nr` fixtures in that directory,
so the gap was latent.

**Fix:** add a `case "$f" in *_aux.nr|*import_dedupe_lib.nr) continue ;; esac`
guard at the top of the loop body. Identical match semantics to the
existing TEST_SKIP_REGEX. 3-line surgical patch.

**Validation after fix:**

```
$ bash tools/verify.sh --only "tests/err/*.nr have EXPECT headers"
[  8/1299] OK    tests/err/*.nr have EXPECT headers  (  0.02s)
PASS: 1
SKIP: 289
```

The post-fix full transcript at
`findings/inbox/8J_artifacts/verify_full_v3_post_8M.log` shows
PASS=1293 / SKIP=6 / FAIL=0 across all 1299 steps.

## Residuals / open work observed

- T1.7 (bootstrap seed matches current compiler) and T1.8 (self-host
  IR fixed point) both PASSED — bootstrap chain is stable on Linux from
  the c1eea2e seed.
- Drift gate (`tools/check_compiler_drift.sh`) PASSED, including
  `audit_dup_fns_report.csv` (matches generator output for current
  source — the post-8M regeneration described in the 8M entry leaves
  this gate green).
- The `WARN: parser fn '...' diverges` lines from drift are pre-existing
  and tracked under RFC-0063 Phase 2.0 (parser unification, not in
  scope for Round 3).

## Files

- `tools/verify.sh` (3-line fix to `err_tests_have_expect_smoke`)
- `findings/inbox/cloud_claude_lane8_8J_v0845_2026-05-07.md` (this report)
- `findings/inbox/8J_artifacts/bootstrap_linux.log`
- `findings/inbox/8J_artifacts/build_tools.log`
- `findings/inbox/8J_artifacts/verify_full.log` (pre-bootstrap fail snapshot — confirms why bin/nucleor must exist before verify)
- `findings/inbox/8J_artifacts/verify_full_v2.log` (post-bootstrap, pre-fix — 1292/6/1)
- `findings/inbox/8J_artifacts/verify_full_v3_post_8M.log` (post-fix and post-8M Wave 11 rebase)

Branch: harness-pinned `claude/verify-round-3-tests-RnTlO`. Per the 8A/8B/8C
convention, individual queue commits are scoped on this single branch
for clean cherry-pick by the local integrator.
