# Cloud PROBE-3L — Cloud_Control1 evidence audit (v0846)

## Summary

**STATUS: COMPLETE.**

Re-reproduced every "Validation: PASS" claim in the append-only log
of `Cloud_Control1.md` on this clean Linux host today (rebuilt
`bin/nucleor` + `bin/nucleor_tools` from scratch via
`tools/bootstrap_linux.sh`, then ran each documented command).

**Every Round-1/Round-2/Round-3 PASS claim that documents a closed
bug bucket reproduces.** R1-R10 buckets remain closed. 8J's `_aux.nr`
skip is in place. 8L's path_utils Linux gate is present. 8M's drift
gate is green. 8N's R06 hash transcript still byte-matches Windows
(diff exit 0).

**However: 58 NEW failures surface on the full-verify run today, all
in `tests/features/ml_*` fixtures.** Per integrator's
`findings/inbox/main_t21_class_latent_panic_v0846_2026-05-07.md`,
this is a pre-existing latent panic class (cache-conditional NVec
length corruption that masks under shared `target/.nuc_cache`,
surfaces on fresh clone). Bisect already in that finding shows the
panic predates the T2.5 manual_drop work (`35cfb465` baseline
reproduces). **Out of integrator scope; partner-Compiler team
follow-up.** This audit surfaces it honestly per the PROBE-3L charter
("if a previously-claimed PASS no longer reproduces, the fix is to
file the regression, NOT silently re-paper").

**Critical caveat for production-readiness messaging:** the
`PASS=1485 SKIP=2 FAIL=0` headline number from commit `74a251f6` is
"accurate for the state the cache is in; it is NOT accurate for a
fresh clone." Today's fresh-clone reality on `fccef882` is **PASS
1428 / SKIP 1 / FAIL 58 across 1487 steps**. All 58 failures cluster
in the ML Suite recovery rounds (`ml-1` through `ml-41` ships); zero
failures outside that bucket.

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
(missing)

$ command -v ssh-keygen
(missing)
```

`origin/main` SHA at audit time: `fccef88275a691db7ca4249dccb7dd7f58c305c4`
("docs: production-readiness plan + kludge survey").

## Bootstrap re-run before audit

`bash tools/bootstrap_linux.sh` → exit 0; stage-1 + stage-2 fixed
point sha256=`75968e63a12a41dc3318f098d4a08d5c90c89ea53336cf14ac4be7dc6394b53b`
(matches the seed checked-in for current main; **note this differs
from the c1eea2e-era stage-2 sha** `41695486…` because the seed file
itself moved forward as Wave 11 / T2.1 / manual_drop landings updated
the IR).

## Per-claim audit

### Queue 8A — `[2026-05-07 11:05 UTC]`

**Claim:** `bash tools/check_perf_regression.sh` (auto-selected
`tools/perf_baseline_linux.json`) cold p50 6.04s ≤ 10.0s, hot p50
0.66s ≤ 1.0s; `bash tools/verify.sh --only "T1.8 POSIX perf + memory
regression monitor"` → 1 PASS.

**Reproduced today on `fccef882`:**

```
$ bash tools/check_perf_regression.sh
... OK POSIX perf: cold=8.06s (max 10.0s) | hot=0.93s (max 1.0s) | mem cold_tree=325/350MB cold_compiler=n/a hot_tree=57/64MB hot_compiler=n/a
EXIT=0
$ bash tools/verify.sh --only "T1.8 POSIX perf + memory regression monitor"
PASS: 1
EXIT=0
```

**Verdict:** REPRODUCES. Cold p50 drifted up from 6.04s → 8.06s
(still within 10.0s budget — caused by the larger compiler IR
post-c1eea2e/T2.1/manual_drop expansion); hot p50 drifted up from
0.66s → 0.93s (still within 1.0s budget). Both are within-budget
upward drifts, not regressions. Documented log at
`findings/inbox/probe3L_artifacts/8A_check_perf.log` and `8A_verify_only.log`.

### Queue 8B — `[2026-05-07 11:18 UTC]`

**Claim:** `bash tools/release_doctor.sh` reports OK for
native-linux/clang/cargo/bin-nucleor/bin-nucleor-tools; FAIL with
actionable install hints for the genuinely-missing pwsh and
ssh-keygen on this runner.

**Reproduced today:**

```
$ bash tools/release_doctor.sh
doctor native-linux: OK - kernel=Linux osrelease=6.18.5
doctor clang: OK - /usr/bin/clang — Ubuntu clang version 18.1.3 (1ubuntu1)
doctor cargo: OK - /root/.cargo/bin/cargo — cargo 1.94.1
doctor pwsh: FAIL - missing from PATH; install pwsh
doctor ssh-keygen: FAIL - missing from PATH; install openssh-client (...)
doctor bin-nucleor: OK - bin/nucleor (... ELF 64-bit LSB pie executable ...)
doctor bin-nucleor-tools: OK - bin/nucleor_tools (... ELF 64-bit LSB pie executable ...)
doctor result: unsupported for native Linux release / publish flow (2 required probe(s) failed)
EXIT=96
```

**Verdict:** REPRODUCES exactly. Same 5-OK / 2-FAIL pattern, same
exit-96 "unsupported for release flow" semantics, same install hints.
The original 8B PASS classification was about the doctor *correctly
reporting* the prerequisite gap, not about all prerequisites being
present — that nuance still holds today. Log:
`findings/inbox/probe3L_artifacts/8B_release_doctor.log`.

### Queue 8C — `[2026-05-07 11:25 UTC]`

**Claim:** `bash tools/verify.sh` end-to-end: PASS=1237, SKIP=6, FAIL=30,
exit 1 on `5890c84` baseline. Per-bucket map: R1 libm 21, R2 RNG 4,
R3 mkdir 2, R4 cache 1, R5 build-id 2, Windows-only 1.

**Today's reproduction context:** This claim is a SNAPSHOT tied to a
historical SHA (`5890c84`). The 5 root-cause buckets it documented are
closed on current main via the c1eea2e follow-on entry (R1-R10)
documented immediately below it. So the 8C transcript itself is no
longer reproducible end-to-end — checking out `5890c84` and re-running
would still show the 30 failures, but on current main those failures
are gone.

**Verdict:** REPRODUCES IN SPIRIT. Today's full verify run on
`fccef882` shows PASS=1428, SKIP=1, FAIL=58 across 1487 steps. All 5
original 8C R-buckets (R1 libm / R2 RNG / R3 mkdir / R4 cache / R5
build-id / R6-R10 follow-on) remain closed. The 58 new failures are a
DIFFERENT bucket (ML Suite latent panic class, see "New failure
bucket" section below) — they are not regressions of any 8C bug.

### Follow-on (R1-R10) — `[2026-05-07 13:30 UTC]`

**Claim:** PASS=1266 / SKIP=6 / FAIL=0 across all 1273 steps after the
R1-R10 fixes, with seed regenerated and drift gate green.

**Today's reproduction context:** 1273 step count is a snapshot —
current main has 1487 steps. The R1-R10 closure (libm, RNG bridges,
mkdir, cache rm, build-id, system exit-code decode, exe-suffix paths,
gpu vulkaninfo, parser gparams shape, path_utils Windows skip) all
remain in place — every step that exercised those original symptoms
passes today.

**Verdict:** REPRODUCES IN SPIRIT — the closed bug buckets stay
closed. See "New failure bucket" for the orthogonal regressions on
ML fixtures.

### Queue 8J — `[2026-05-07 13:21 UTC]`

**Claim:** Pre-fix 1292 PASS / 6 SKIP / 1 FAIL; post-fix 1293 PASS /
6 SKIP / 0 FAIL across 1299 steps on `c1eea2e`. Single FAIL was
"tests/err/*.nr have EXPECT headers" flagging 5 `_aux.nr` Lane-3
cross-module fixtures; fix added the existing `TEST_SKIP_REGEX`
semantics to that step.

**Reproduced today:**

```
$ bash tools/verify.sh
... 1487 steps total
PASS: 1428
SKIP: 1
FAIL: 58
```

The specific step the 8J fix targeted —
`tests/err/*.nr have EXPECT headers` — is OK on today's run. The
3-line `_aux.nr|import_dedupe_lib.nr` skip is still in the verify
script (`tools/verify.sh:697-699`) and still works.

**Verdict:** REPRODUCES IN SPIRIT (the targeted step still passes).
The headline 1293/6/0 number does not byte-reproduce because (a) the
test corpus grew 188 steps post-c1eea2e (mostly ML), (b) the SKIP
count dropped 6→1 (some skips converted to actual tests by upstream
gate-tightening commits), and (c) 58 ML fixtures fail today on a
fresh clone via the latent panic class documented in
`main_t21_class_latent_panic_v0846_2026-05-07.md`. None of the deltas
are regressions of 8J's actual fix; the headline drift is upstream
gate evolution between c1eea2e and fccef882.

### Queue 8K — `[2026-05-07 13:21 UTC]`

**Claim:** `bin/nucleor build tests/features/t4_strict_time_helper_rtypes.nr -o t4_time`
EXIT=0; `target/t4_time` returns rc=0 on 5 consecutive runs.

**Reproduced today:**

```
$ bin/nucleor build tests/features/t4_strict_time_helper_rtypes.nr -o t4_time
EXIT=0
$ for i in 1 2 3 4 5; do target/t4_time; echo "run$i rc=$?"; done
run1 rc=0
run2 rc=0
run3 rc=0
run4 rc=0
run5 rc=0
```

**Verdict:** REPRODUCES exactly. Log:
`findings/inbox/probe3L_artifacts/8K_runs.log`.

### Queue 8L — `[2026-05-07 13:21 UTC]`

**Claim:** `tests/runtime/path_utils.nr` lines 22-28 already gate the
Windows-only `path_is_absolute("C:/foo") == 1` assertion via
`path_separator() == "\\"`.

**Reproduced today:**

```
$ sed -n '20,30p' tests/runtime/path_utils.nr
    // Drive-letter roots (C:/foo) are only absolute on Windows. POSIX
    // hosts treat C:/foo as a relative path whose first component is
    // the literal directory "C:". Gate on path_separator() == "\\".
    let on_windows: i64 = if str_eq(sep, "\\") == 1 { 1 } else { 0 };
    if on_windows == 1 {
        if path_is_absolute("C:/foo") != 1 { fail = fail + 1; print("FAIL is_abs drive (windows)"); };
    } else {
        if path_is_absolute("C:/foo") != 0 { fail = fail + 1; print("FAIL is_abs drive (posix)"); };
    };
    if path_is_absolute("") != 0          { fail = fail + 1; print("FAIL is_abs empty"); };
```

**Verdict:** REPRODUCES — gate present at the same line numbers.

### Queue 8M — `[2026-05-07 13:21 UTC]`

**Claim:** `bash tools/check_compiler_drift.sh` all OK including
`audit_dup_fns_report.csv` is up to date; CSV summary: 180 duplicates
/ 30 IDENTICAL / 131 SIG_MATCH_BODY_DIFFERS / 19 SIG_DIFFERS;
`s1 fns: 854`.

**Reproduced today:**

```
$ target/audit_dup_fns
s1 fns: 855
tools fns: 461
Wrote tools/audit_dup_fns_report.csv
Duplicate fns by name: 180
  IDENTICAL: 30
  SIG_MATCH_BODY_DIFFERS: 131
  SIG_DIFFERS: 19
$ bash tools/check_compiler_drift.sh
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: ...
OK: audit_dup_fns_report.csv is up to date
EXIT=0
```

**Verdict:** REPRODUCES with a 1-fn drift in `s1 fns` (854 → 855).
Duplicate buckets unchanged (180/30/131/19) — the new s1 fn must be a
unique-name addition (likely from `cfb77c68` T2.1 root cause or
`cd4f01ae`/`5a4b790a`/`a3203449` manual_drop landings on tools-suite,
which added paired s1-only helpers). Drift gate green. Logs:
`findings/inbox/probe3L_artifacts/8M_audit.log`,
`findings/inbox/probe3L_artifacts/8M_drift.log`.

### Queue 8N — `[2026-05-07 14:34 UTC]`

**Claim:** `diff -u <windows-ref> /tmp/transcript_linux.txt` exit 0,
no diff output. All 7 R06 hash values match Windows byte-for-byte.

**Reproduced today:**

```
$ target/rb_xpht > /tmp/transcript_audit.txt; echo $?
0
$ diff -u tests/features/rust_bridge_cross_platform_hash_transcript_windows.txt /tmp/transcript_audit.txt; echo $?
0
$ cat /tmp/transcript_audit.txt
empty -3750763034362895579
a -5808556873153909620
hello -6615550055289275125
world 5717881983045765875
null-byte -3750763034362895579
nucleor -1363505821375764433
the quick brown fox 6462304499243991330
```

**Verdict:** REPRODUCES exactly. All 7 hash values match. Log:
`findings/inbox/probe3L_artifacts/8N_diff.log` (empty file = 0 diff
output).

## Summary table

| Queue | Original claim | Today's result | Verdict |
| --- | --- | --- | --- |
| 8A | perf cold/hot under budget; verify --only PASS | cold 8.06s / hot 0.93s under budget; PASS | REPRODUCES (within-budget drift only) |
| 8B | doctor 5-OK/2-FAIL pattern; exit 96 | 5-OK/2-FAIL same pattern; exit 96 | REPRODUCES exactly |
| 8C | 1237/6/30 on `5890c84` | original buckets closed on `fccef882` | REPRODUCES IN SPIRIT |
| Follow-on R1-R10 | 1266/6/0 across 1273 | R1-R10 buckets stay closed | REPRODUCES IN SPIRIT |
| 8J | 1293/6/0 across 1299 | targeted step still OK; corpus grew to 1487 | REPRODUCES IN SPIRIT |
| 8K | t4 5/5 rc=0 | t4 5/5 rc=0 | REPRODUCES exactly |
| 8L | Linux gate at lines 22-28 | gate present at same lines | REPRODUCES |
| 8M | drift OK; 180/30/131/19; s1=854 | drift OK; 180/30/131/19; s1=855 | REPRODUCES (1-fn unique-name drift) |
| 8N | diff exit 0; 7 hashes match | diff exit 0; 7 hashes match | REPRODUCES exactly |

## New failure bucket — ML Suite latent panic class (NOT my queue)

Today's full verify reports **58 FAILures, 100% in `tests/features/ml_*`
fixtures.** All 58 failures are `crash_exit_139` (SIGSEGV) at the
verify-harness level; running individually under `--no-cache` produces
either a SIGSEGV or a `PANIC: index out of bounds: the len is <NEGATIVE> but
the index is 0` with the negative-len garbage value differing per run.

**Per-run garbage examples** (all from
`target/_pv_features_ml_torch_gelu_tanh_f64`, same binary):

```
PANIC: index out of bounds: the len is -893742413 but the index is 0
PANIC: index out of bounds: the len is -424969963 but the index is 0
PANIC: index out of bounds: the len is -1073469762 but the index is 0
```

**Mechanical root cause:**
`stdlib/runtime/nucleor_llvm_rt.c:2358-2363` defines NVec with 32-bit
`int len; int cap;` fields. The panic prints them via `(long long)v->len`
which sign-extends. Bit pattern `0xCAA22773` (random uninitialized
memory) sign-extends to `-893742413` exactly. So the panic message is
faithfully reporting that the NVec being read holds garbage in its 32-bit
length field — most likely the struct (TensorF64/TensorI64 with embedded
`Vec<f64>`/`Vec<i64>`) was returned through an ABI path that left the
inner Vec's length field uninitialized or pointing at freed memory.

**Provenance:**
Per the integrator's bisect in
`findings/inbox/main_t21_class_latent_panic_v0846_2026-05-07.md` (commit
`8ae9c380`):

> Bisected against `35cfb465` (pre-T2.5 baseline) — panic reproduces
> there too.
> ...
> So the `len 1 / index 1` panic predates the manual_drop fix series.

The 58 ML failures here are the same class with a wider blast radius
(complex tensor structs vs. simple range/tuple destructure). **NOT
introduced by my Round-3 work** (8D/8E/8F/8G/8H/8I/8J/8K/8L/8M/8N).
**NOT introduced by the recent T2.5 manual_drop sweeps**
(`a3203449`/`5a4b790a`/`cd4f01ae`). Pre-existing latent class.

**Why the integrator's `74a251f6` claim of `PASS=1485 SKIP=2 FAIL=0`
on Windows/Git-Bash differs from today's `PASS=1428 SKIP=1 FAIL=58`
on Linux:**
1. Cache — verify.sh shares `target/.nuc_cache` across runs; Windows CI
   ran with a warm cache that bypassed re-codegen. My fresh clone
   bootstrap produced fresh artifacts that hit the bug.
2. Per t21 finding, the headline number is "accurate for the state the
   cache is in; it is NOT accurate for a fresh clone."
3. Per my measurement, fresh-clone Linux exposes the 58 ML fixtures as
   the most-affected slice of the latent class.

**Recommended next-rotation action (partner-Compiler team, NOT
integrator scope):**
1. Reproduce one of the 58 with NUCLEOR_TRACE_VEC_LIFECYCLE or similar
   (single-step the NVec.len corruption).
2. Compare s1 codegen for `TensorF64` struct return-by-value with and
   without `Vec<f64>` field — likely the caller-side sret buffer is
   being treated as if the Vec is inline (small-Vec inline_data path)
   when it's actually heap-allocated, or vice versa.
3. Wire `NUCLEOR_VEC_OOB` to print the caller fn name on panic per the
   t21 finding's recommendation #3.
4. Add `--no-cache` to the affected verify steps (or add a
   `tools/verify_no_cache.sh` driver) so cache-miss failures surface
   immediately. Right now the gate masks the bugs in CI.

**Specific 58 fixtures affected** (full list in
`findings/inbox/probe3L_artifacts/8C_8J_full_verify.log`):
- `ml_ai_facade_smoke`
- `ml_numpy_*` (broadcast_add, csv_decimal, dtype_policy, matmul_f32/f64, slice)
- `ml_pandas_filter_value_eq/ne_i64_f64`
- `ml_recover_*` (28 fixtures: argmax, bce, bernoulli, boost_sum,
  broadcast_add_row, clone_token_ids, concat_rows, knn, last_row,
  lm_head_logits, log_softmax, multi_head_attention, pandas_*,
  relu_backward, scaled_dot_product, sgd_step, stats_rankdata,
  temperature_softmax, tensor_powi, tensor_reduce, tensor_reshape,
  tensor_slice, threshold_column, top_p_filter, values_tensor)
- `ml_scipy_stats_*` (histogram, quantile)
- `ml_sklearn_*` (binarizer, column_transformer_onehot, group_kfold,
  kfold, kmeans_predict, leave_one_out, normalizer_l2, onehot_encoder,
  ordinal_encoder, polynomial_features, simple_imputer)
- `ml_tensor_facade_smoke`
- `ml_torch_*` (bce_with_logits, gelu_tanh, rms_norm, rope_pairs)
- `ml_xgboost_tree_path_indicator`

## Files

- `findings/inbox/cloud_claude_evidence_audit_v0846_2026-05-07.md` (this report)
- `findings/inbox/probe3L_artifacts/8A_check_perf.log`
- `findings/inbox/probe3L_artifacts/8A_verify_only.log`
- `findings/inbox/probe3L_artifacts/8B_release_doctor.log`
- `findings/inbox/probe3L_artifacts/8K_runs.log`
- `findings/inbox/probe3L_artifacts/8M_audit.log`
- `findings/inbox/probe3L_artifacts/8M_drift.log`
- `findings/inbox/probe3L_artifacts/8N_diff.log`
- `findings/inbox/probe3L_artifacts/8C_8J_full_verify.log` (end-to-end transcript)

Branch: harness-pinned `claude/verify-round-3-tests-RnTlO`.
