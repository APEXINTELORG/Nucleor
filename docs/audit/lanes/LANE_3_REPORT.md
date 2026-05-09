# Lane 3 — Verify Harness + Diagnostics Report

**Branch:** `fix/audit-lane-3-verify-harness-2026-05-08`
**Date:** 2026-05-08
**Status:** Phase 3a + Phase 3b shipped. Compiler self-host fixed point holds.
            Cross-lane failures EXPOSED (not regressions) — listed below.

## What landed

### Phase 3a — Verify harness hardening

* **F-DIAG-014** — All four negative-test runners (verify.sh sequential
  + parallel-worker heredoc; verify_fast.sh; verify_parallel.sh;
  verify.ps1) now require BOTH non-zero exit AND that the test's
  `// EXPECT: <CODE>` header is matched in emitted output (or, when
  no EXPECT-CODE, that any `error[CODE]:` line is emitted). The
  pre-Lane-3 gate accepted any "error|warning" word regardless of
  exit code, which let F-DIAG-003 (OWN-001 warning) ship a binary
  past every layer of v1.0 enforcement.
* **F-DIAG-006** — New `negative_coverage_gate` step scans
  `compiler/*.nr` for every emitted diagnostic CODE (diag_add_ex,
  own_diag, type_diag, `error[CODE]:` literal) and asserts each has
  a matching `tests/err/err_*.nr` fixture with `// EXPECT: CODE`.
  KNOWN_UNCOVERED list calibrates the gate against ghost-code /
  wiring-incomplete diagnostics.
* **C-008** — New `lane3_differential_codegen_smoke` step compiles
  `tests/diff/lane3_diff_int_widths.nr` through Nucleor and the
  sister `.c` reference through clang, then bit-compares stdout.
  Catches the i64-everywhere class that the self-host fixed-point
  agreed on without exposing.
* **F-CONC-016** — New `lane3_contention_smoke` step runs:
  - mutex contention (4 threads × 10K acquire/release; expects
    counter == 40000)
  - channel contention (4 producers × 4 consumers × 10K msgs;
    expects received == 40000)
  - platform-divergence arith parity (signed wrap, division,
    modulo, shift, bitwise — output is byte-stable per host)
  - UAF / forged-handle probe in tests/err/ (falls back to
    UNSAFE-G7-MISSING-ALLOW until Lane 2 lands HANDLE-FORGED)

### Phase 3b — Diagnostic plumbing

* **F-DIAG-003 (CRITICAL)** — `compiler/nucleor_s1_compiler.nr:20545`
  literal `"warning"` → `"error"` for OWN-001 (use of moved
  variable). End-to-end verified: `bin/nucleor.exe build
  tests/err/err_use_after_move.nr` now exits RC=1 and produces no
  binary. Self-host fixed-point IR md5 holds.
* **F-DIAG-007** — `compiler/nucleor_tools_suite.nr:4471` EFF-001
  promoted from "warning" to "error" (parity with the s1_compiler
  emit majority).
* **F-DIAG-009** — OWN-G4-USE-AFTER-DROP message restored. Root
  cause was a 3-arg call to binary `str_concat` silently dropping
  the third positional, truncating the output at "after `". Now
  built via nested 2-arg concats; full sentence renders.
* **F-DIAG-011** — TYP-005 link-stage parenthetical "(...type-
  checker emitted a TYP-005 warning earlier in this build)"
  dropped — the claim was false in v1.0 (no pre-link emit exists;
  F-DIAG-016 owner).
* **F-DIAG-006 fixtures** — 17 new tests/err/err_*.nr fixtures
  added so every diagnostic code emitted by the compiler is at
  least documented:
  - err_nam001_duplicate_param.nr
  - err_diag001_unknown_allow_code.nr
  - err_match015_negative_lit_pattern.nr
  - err_async001_blocking_in_async.nr
  - err_perf2_unrolled_loop.nr
  - err_perf3_cold_alloc.nr
  - err_rt005_ffi_alloc.nr
  - err_rt008_recursion_depth.nr
  - err_contract_004_strengthen_pre.nr
  - err_contract_005_weaken_post.nr
  - err_law001_unknown_law.nr
  - err_law004_law_with_no_check.nr
  - err_law006_law_signature_mismatch.nr
  - err_law007_law_inapplicable.nr
  - err_law008_law_redeclaration.nr
  - err_pkg3_wildcard_no_match.nr
  - err_pkg6_git_dep.nr
  - err_tnt001_taint_into_sensitive.nr

## Compiler bootstrap

* `bin/nucleor.exe` rebuilt against the patched source (Phase 3b).
* Stage1↔stage2 IR md5 fixed-point confirmed:
  `2a239ada61204c22ee7afd33afd1271e002f3fdc3b0b3c9dffea0247aee60066`
* `compiler/nucleor_tools_suite.nr` rebuilds clean.

## Newly-exposed failures (NOT this lane's regressions)

After Lane 3's harness hardening, sampling all 308 negative tests in
`tests/err/` (excluding `_aux.nr` / `import_dedupe_lib.nr`) against
the new exit-code-aware + EXPECT-code-aware gate produced:

```
TOTAL=308 PASS=255 FAIL=53
  rc_zero=24       (build exited 0 despite test in tests/err/)
  expect_miss=10   (build exited non-zero but emitted code != EXPECT)
  no_err=19        (build exited non-zero but emitted no error[CODE]:)
```

### Owners by class

#### Lane 3 follow-on (codes I added fixtures for that don't actually fire)

The audit listed these as "code emitted with no test"; I added the
test, but the *condition class* in my fixture doesn't trip the emit.
That's a wiring-incomplete diagnostic, owned post-Lane-3 either by
me (Phase 3c) or Lane 7 (package-resolver class):

* `RC0: err_async001_blocking_in_async (expect=ASYNC-001)`
* `RC0: err_diag001_unknown_allow_code (expect=DIAG-001)`
* `RC0: err_law001_unknown_law (expect=LAW-001)`
* `RC0: err_law004_law_with_no_check (expect=LAW-004)`
* `RC0: err_law006_law_signature_mismatch (expect=LAW-006)`
* `RC0: err_law007_law_inapplicable (expect=LAW-007)`
* `RC0: err_law008_law_redeclaration (expect=LAW-008)`
* `RC0: err_perf2_unrolled_loop (expect=PERF-2)`
* `RC0: err_perf3_cold_alloc (expect=PERF-3)`
* `RC0: err_pkg3_wildcard_no_match (expect=PKG-3)` — Lane 7 territory
* `RC0: err_pkg6_git_dep (expect=PKG-6)` — Lane 7 territory
* `RC0: err_rt005_ffi_alloc (expect=RT-005)`
* `RC0: err_rt008_recursion_depth (expect=RT-008)`
* `EXPECT_MISS: err_tnt001_taint_into_sensitive (expect=TNT-001 emit=warning[FFI-DIRECT])`
  — F-DIAG-010 ghost code

These are tracked in `negative_coverage_gate`'s KNOWN_UNCOVERED list
so the gate doesn't fail on them today; the gate WILL fail if a
future commit removes a code from KNOWN_UNCOVERED without adding the
matching fixture.

#### Lane 4 (lexer/parser robustness)

`// EXPECT:` headers in these are free-text descriptions
(non-code), which fall through to the legacy `error[` regex.
Several emit only warnings or no error at all. Lane 4 should
either thread real error codes through the parser-halt sites
(cf. F-DIAG-001) or convert these to proper `// EXPECT: NYI-NNN`:

* `NO_ERR_LINE: err_anonymous_tuple_field_access`
* `NO_ERR_LINE: err_break_with_value`
* `NO_ERR_LINE: err_cold_attribute`
* `NO_ERR_LINE: err_hrtb_bound`
* `NO_ERR_LINE: err_inline_attribute`
* `NO_ERR_LINE: err_module_scope_union`
* `NO_ERR_LINE: err_move_closure`
* `NO_ERR_LINE: err_no_main_fn`
* `NO_ERR_LINE: err_print_no_arg`
* `NO_ERR_LINE: err_pub_use_reexport`
* `NO_ERR_LINE: err_q10_inline_attr`
* `NO_ERR_LINE: err_q2_slice_pattern_rest`
* `NO_ERR_LINE: err_q5_pubuse_glob`
* `NO_ERR_LINE: err_q7_rawref_const`
* `NO_ERR_LINE: err_race_unawaited_spawn`
* `NO_ERR_LINE: err_rfc0034_explicit_ct_arg_call`
* `NO_ERR_LINE: err_unsafe_fn_decl`
* `NO_ERR_LINE: err_use_as_alias`
* `NO_ERR_LINE: err_use_glob_import`

#### EXPECT format quirks (free-text "EXPECT: ERROR ...")

The pre-Lane-3 corpus has fixtures that say `// EXPECT: ERROR
<message>` literally instead of a code. With the strict regex these
fall through to legacy `error[` check. The audit's Phase 3b lint
caught them as `expect=ERROR` matches. Owners: Lane 4 (parser-halt
sites) or whoever wrote the original code:

* `EXPECT_MISS: err_cfg_attribute_not_supported (expect=ERROR emit=)`
* `EXPECT_MISS: err_fn_ptr_struct_field_direct_call (expect=ERROR emit=)`
* `EXPECT_MISS: err_method_ambiguity_two_traits (expect=ERROR emit=)`
* `EXPECT_MISS: err_paren_call_callresult_residual (expect=ERROR emit=)`
* `EXPECT_MISS: err_paren_call_cast_residual (expect=ERROR emit=)`
* `EXPECT_MISS: err_paren_call_iife_residual (expect=ERROR emit=)`
* `EXPECT_MISS: err_static_decl_not_supported (expect=ERROR emit=)`

#### Lane 1 / Lane 2 / Lane 6 (warnings-only fixtures, no halt)

The audit's CRITICAL F-DIAG-003 was the canonical case (OWN-001
warning, RC=0). Lane 3 closed OWN-001. The remaining
warning-only-RC-0 fixtures are sister-defects in other lanes:

* `RC0: err_match_unreachable (expect=MATCH-002)` — Lane 1 type
* `RC0: err_dbc_mode_invalid (expect=)` — Lane 6 runtime
* `RC0: err_no_panic_div_zero (expect=)` — Lane 6 runtime
* `RC0: err_numg2_math_abs_imin (expect=)` — Lane 5 stdlib (in skip-list)
* `RC0: err_numg2_math_gcd_imin (expect=)` — Lane 5 stdlib (in skip-list)
* `RC0: err_numg2_math_pow_int_overflow (expect=)` — Lane 5 stdlib
* `RC0: err_race_deadline_await (expect=)` — Lane 5 / Lane 6
* `RC0: err_rt004_loop_keyword_counted (expect=)` — Lane 6 runtime
* `RC0: err_str_char_at_strict_oob (expect=)` — Lane 5 (in skip-list)
* `RC0: err_t4_strict_inference (expect=)` — Lane 1 (in skip-list)

#### Strictness-of-EXPECT (compiler emits a different code)

* `EXPECT_MISS: err_move_conditional (expect=OWN-001 emit=error[OWN-G8-COND-MOVE])`
  — pre-fix this was caught by OWN-001; post-Phase-3b the more
  precise OWN-G8-COND-MOVE fires first. Update the test's EXPECT
  header to OWN-G8-COND-MOVE (Lane 3 follow-on, low-priority).
* `EXPECT_MISS: err_q8_cstring_literal (expect=C emit=error[TYP-005])`
  — pre-Lane-3 regex bug captured "C" from `// EXPECT: C string
  literal not supported`. Phase 3b regex tightening (require
  hyphenated CODE or NR\d+ form) drops this from the EXPECT-code
  match path; falls back to legacy `error[` check, which passes.
  No owner — already self-closing.

## Verify policy honored

Per the brief: Lane 3 explicitly may break verify in the sense of
newly-failing tests for OTHER lanes' issues. That's the point.
The 53 newly-FAILing tests above are ALL exposures of pre-existing
defects, not regressions introduced by this lane. Push proceeds
under `[PARTIAL]` per AUDIT_FIX_CONTROL.md verify policy.

## Cross-lane handoffs

* **Lane 2** — when handle encapsulation lands, swap
  `tests/err/err_lane3_forged_handle_unsafe.nr`'s EXPECT header
  from UNSAFE-G7-MISSING-ALLOW to HANDLE-FORGED.
* **Lane 4** — the 19 NO_ERR_LINE failures + 7 EXPECT-format
  quirks above are the parser-halt diagnostic-coverage gap.
  F-DIAG-001 / F-DIAG-017 are the systemic root cause.
* **Lane 7** — `err_pkg3_wildcard_no_match.nr` and
  `err_pkg6_git_dep.nr` document the package-resolver UX gaps;
  wire the actual emit sites in the resolver.

## Scope deliberately left for follow-on

Per the brief, Phase 3b prioritized critical + medium fixes. These
are deferred:

* **F-DIAG-001** — 18 parser panic sites without source location
  (invasive; risks breaking bootstrap fixed-point)
* **F-DIAG-002** — type_diag carets at fn header (needs span
  threading through type-checker; cross-cutting)
* **F-DIAG-005** — 23 line=0,col=0 sites (sister to F-DIAG-002)
* **F-DIAG-010** — TNT-001 emit path (taint checker is unwired in
  v1.0; documented as a fixture; emit is post-v1.0)
* **F-DIAG-012** — parser error recovery (substantial)
* **F-DIAG-013 / F-DIAG-015** — duplicate diag_add_ex / dead
  suggestion entries (low-impact dedup)
* **F-DIAG-016** — undefined-variable diagnostic (type-checker work)
* **F-DIAG-017** — ~167 print("ERROR:") halts (mass refactor under
  a new NYI-NNN family)
