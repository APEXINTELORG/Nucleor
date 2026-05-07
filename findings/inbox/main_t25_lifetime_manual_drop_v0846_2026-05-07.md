# T2.5 lifetime `nuc test` heap-corruption — root cause + fix

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Branch:** `fix/t25-lifetime-tools-suite-manual-drop-v0846`
- **Base:** `origin/main` @ `1d2e5e1a`
- **Audit source:** `findings/inbox/codex_qa_orchestrator_audit_v0846_2026-05-07.md` Finding #2

## Headline

`nuc test tests/smoke/t25_lifetime_params.nr` failed on Windows/Git-Bash with a silent
RC=127 (heap corruption surfaced as `PANIC: node_kind pool OOB: index 2287092358768,
len 83` under `NUCLEOR_VERBOSE=1`). Cloud's earlier landing `5a263b02 tools-suite:
mirror s1's parse_fn_decl gparams shape (R9: T2.5 OOM)` fixed the gparams
construction shape but the **inner fix was a sister gap, not the root cause** — the
whole-fn auto-drop on `parse_generic_params` and `parse_fn_decl` was still freeing
the inner params Vec before mk_list could iterate it.

Fix is two `#[manual_drop]` annotations mirroring s1::parse_generic_params (line 3185)
and s1::parse_fn_decl (line 4068). Closes T2.5 verify step + the larger class of
"silent fn-drop on any fn with `<...>` generic / lifetime params via `nuc test`".

## Reproduction (pre-fix)

Minimal:

```nr
// tests/smoke/_t25_repro_min.nr (now removed; reproduced via T2.5 fixture)
fn f_one_lt<'a>(x: i64) -> i64 { return x; }
fn test_one() { assert_eq(f_one_lt(7), 7); }
```

```bash
bin/nucleor.exe test tests/smoke/_t25_repro_min.nr
# RC=127, no error message

NUCLEOR_VERBOSE=1 target/nucleor_tools.exe test tests/smoke/_t25_repro_min.nr
# PANIC: node_kind pool OOB: index 2287092358768, len 83
# RC=1
```

Verbose output also shows `functions: 2` instead of the expected 3 (f_one_lt is
silently dropped; the LL emits `call @f_one_lt` but no matching `define`, and
clang link errors with `use of undefined value '@f_one_lt'`).

## Localization

1. The fixture compiles + runs cleanly through `nuc build` (which uses the s1
   compiler `compiler/nucleor_s1_compiler.nr`):

   ```bash
   bin/nucleor.exe build target/_t25_repro_min-test__test_harness.nr -o foo --no-cache
   target/foo.exe   # exits 0, all 4 tests PASS
   ```

   So the language handles `<'a>` correctly. The bug is in the tools-suite path used
   by `nuc test` (and `nuc bench / check / audit / policy / certify / translate` —
   all dispatched via `compiler/nucleor_s1_compiler.nr:38211 run_external_tool`).

2. `bin/nucleor_tools.exe` rebuilt fresh from current source still reproduces the
   crash. So this is a real source-side bug, not bin-staleness.

3. `target/nucleor_tools.exe build target/_t25_repro_min-test__test_harness.nr`
   (build, NOT test) succeeds with `functions: 3`. So the bug is **inside the
   `nuc test` dispatch path** (`run_test_command` → `compile_file_mode`), not the
   build path. Same `compile_file_mode` function in both — the difference must be
   the surrounding state (allocator pressure, intermediate Vecs alive at call
   time).

4. Comparing s1 vs tools-suite:

   ```text
   s1::parse_generic_params (line 3185): #[manual_drop]   ← present
   s1::parse_fn_decl        (line 4068): #[manual_drop]   ← present
   tools::parse_generic_params (line 820): (no annotation)
   tools::parse_fn_decl     (line 974):    (no annotation)
   ```

   That is the difference. Without `#[manual_drop]`, the auto-drop pass at
   end-of-scope inside `parse_generic_params` frees the local
   `params: Vec<i32>`. The returned `pr(cp, params)` Vec stores the heap pointer
   of `params` as its second element, so `pr_val(gr)` reads through that
   now-dangling pointer; `gparams_vec = pr_val(gr)` carries the dangling pointer
   forward; `mk_list(pool, gparams_vec)` iterates whatever bytes happen to live at
   the freed address, pushes garbage values into `pool`, and one of them ends up
   used as a node_kind pool index → OOB panic on the lookup.

5. The 5a263b02 fix moved `mk_list` to the end of parse_fn_decl, which is correct
   in isolation, but the inner Vec lifetime issue dominates. On Linux the
   allocator happened to leave the freed memory readable as zeros and the OOB
   often landed inside the legal pool range, surfacing as the
   `realloc(2^64-N)` cited in the 5a263b02 commit message — a different
   allocation-pattern symptom of the same dangling-pointer cause. On
   Windows/Git-Bash the freed memory was reused with a pointer-shaped value and
   the OOB hit hard.

## Fix

Two `#[manual_drop]` annotations on the two parser fns in
`compiler/nucleor_tools_suite.nr` mirroring the s1 source. No semantic change to
the parse contract; the inner Vec is now reaped only after all callers have
consumed pr_val.

```diff
+#[manual_drop]
 fn parse_generic_params(tokens: Vec<i32>, pos: i64) -> Vec<i32> {

+#[manual_drop]
 fn parse_fn_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
```

Plus an in-source comment block documenting the dangling-pointer cause and
naming the s1 line numbers we mirror, so the next investigator doesn't have to
rederive it.

## Validation

| Gate | Result |
| --- | --- |
| `bin/nucleor.exe test tests/smoke/_t25_repro_min.nr` (post-fix repro) | RC=0, `test result: PASS (1 test)` |
| `bin/nucleor.exe test tests/smoke/t25_lifetime_params.nr` (full T2.5 fixture) | RC=0, all 4 tests PASS |
| `bash tools/verify.sh --only "T2.5 lifetime parameters parse cleanly (advisory metadata)"` | OK (1.07s, was FAIL pre-fix) |
| `bash tools/check_compiler_drift.sh` | OK after regenerating `tools/audit_dup_fns_report.csv` |
| `bash tools/check_self_host_md5.sh` | OK, md5=85fc0d224d19ee3c480ed6bb27ac1c37 — UNCHANGED (s1 was not edited) |
| `pwsh -NoProfile -File tools/check_perf_regression.ps1` | OK cold=3.67s/4s, hot=0.42s/1s, mem all within caps |

Self-host md5 unchanged means no `bootstrap/nucleor_s1_seed.ll` refresh is needed
and `bin/nucleor.exe` does not need a promoted-binary commit. Only the
tools-suite source fix and the regenerated audit CSV ship.

## Honest residuals

1. **Sister: `parse_struct_decl` line 1043 carries the same pre-5a263b02 pattern**
   (`gparams = mk_list(pool, pr_val(gr))`) AND lacks `#[manual_drop]`. Any fixture
   that defines a struct with `<T>` or `<'a>` and then exercises the test path
   may trip a similar (or different-shape) auto-drop bug. Did not include in this
   patch because: (a) the user explicitly said "T2.5 first, sweep sisters in a
   follow-on", (b) the existing struct-generic test corpus on main passes today,
   so the latent bug is opaque. **Recommended follow-on:** add a struct-generic
   regression smoke and apply the same two-annotation fix to
   `parse_struct_decl` + `parse_enum_decl` if the audit shows the same s1/tools
   `#[manual_drop]` divergence.

2. **The fix does not mass-audit other tools_suite parse fns for the same
   divergence.** A complete sweep should compare every `^fn parse_*` in
   `compiler/nucleor_tools_suite.nr` against its s1 counterpart and ensure
   `#[manual_drop]` parity. That is RFC-0063 Phase 2 territory and a candidate
   for the next agent rotation.

3. **`bin/nucleor_tools.exe` is gitignored.** The fix commits the source and the
   regenerated audit; downstream consumers (cloud verify, fresh clones) will
   rebuild `nucleor_tools.exe` automatically the first time `nuc test` (or any
   tools-suite-routed command) is invoked. No bin promotion needed.

4. **Cloud Linux verify pre-fix already showed T2.5 OK** (per 8M's
   1293 PASS / 6 SKIP / 0 FAIL row in `Cloud_Control1.md`). That was a
   real-but-partial improvement — the 5a263b02 work fixed the Linux-specific
   `realloc(2^64-N)` symptom by reshaping the gparams construction order,
   masking the underlying dangling-Vec problem. Linux verify will continue to
   pass; this fix is additive, closes the Windows half, and removes the
   allocator-luck dependency on the Linux side.

## Files changed in this branch

```
compiler/nucleor_tools_suite.nr  (2 #[manual_drop] additions, 13 lines net of comment)
tools/audit_dup_fns_report.csv   (regenerated; 4 lines reflow due to source line-number shifts)
findings/inbox/main_t25_lifetime_manual_drop_v0846_2026-05-07.md  (this report)
```

## Stop reason

T2.5 closed; sister parse_struct_decl/parse_enum_decl audit deferred per the
"T2.5 first, sweep sisters next" directive.
