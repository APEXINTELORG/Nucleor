# Helper3 T4 Numeric Strict Verify Wiring v0842

Status: COMPLETE

Branch: `spike/helper3-t4-numeric-promote-v0842`

Base / merge-base: `3ce1ef1139af76ce5007d2bd710b6e919f245903`

## Scope

Main already contained the Helper3 numeric/f64 strict inference implementation, promoted `bin/nucleor.exe`, and refreshed `bootstrap/nucleor_s1_seed.ll` before this spike started. This spike closes the remaining gate gap by wiring `tests/features/t4_strict_remaining_helper_rtypes.nr` into `tools/verify.sh`.

## Changed Files

- `findings/inbox/helper3_t4_numeric_verify_wired_v0842_2026-05-07.md`
- `tools/verify.sh`

## Verification

All commands were run from `C:\Users\JoeWe\Desktop\Nucleor_OSS_spike_t4_numeric_promote_v0842`.

PASS:

```text
$env:NUC_STRICT_INFERENCE='1'; .\bin\nucleor.exe build tests\features\t4_strict_remaining_helper_rtypes.nr -o _t4_strict_remaining_helper_rtypes_bin_v0842 --no-cache
.\target\_t4_strict_remaining_helper_rtypes_bin_v0842.exe
```

Result: promoted `bin\nucleor.exe` compiled the fixture and runtime exit was `0`.

PASS:

```text
bash tools/verify.sh --only "v0.8 T-4 strict inference accepts numeric/f64 helper return types"
```

Result: the newly wired step passed at `[207/1262]` in the filtered run.

PASS:

```text
bash tools/check_self_host_md5.sh
```

Result:

```text
OK: self-host compiler IR fixed point holds md5=2135193392e9ac204e82099552b8ae23
OK: bootstrap seed matches current self-host IR md5=2135193392e9ac204e82099552b8ae23
```

PASS:

```text
bash tools/check_compiler_drift.sh
```

Result: exit `0`; known RFC-0063 parser divergence warnings were printed, then ABI tables, compiler version labels, manifests, release/changelog metadata, and duplicate-function audit report were all reported current.

PASS:

```text
bash tools/check_rod_void_abi.sh
```

Result:

```text
OK: rod void ABI clean (355 C void nuc_* definitions, 1275 non-void rod externs checked)
```

PASS:

```text
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Result:

```text
OK perf: cold=3.57s (max 4s) | hot=0.43s (max 1s) | mem cold_tree=362/400MB cold_compiler=347/350MB hot_tree=70/128MB hot_compiler=55/64MB
```

PASS:

```text
bash tools/verify.sh
```

Result:

```text
PASS: 1255
SKIP: 7
```

The full gate included `v0.8 T-4 strict inference accepts numeric/f64 helper return types` at `[1184/1262]`, which passed in sequence.

PASS:

```text
git diff --check
```

Result: no whitespace errors before adding this report.
