# Helper1 RT Determinism Closure v0842

Branch: `fix/helper1-rt-determinism-closure-v0842`

Base: helper branch was originally based on `origin/main` at
`f3bcf10407bac742fc29bf8e8155c30de1b21e49`.

Codex integration base: `origin/main` at
`819ef76c robo7: add typed kinematics pose facade`.

Assignment:
`C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_helper2_wave5_v0840\findings\_helper1_assignment_v0828_r11_qsim_auto_entangle_2026-05-06.md`

## Completed Behavior

The RT same-file transitive scanner now computes a bounded caller closure
from known allocating / panic-prone function bodies. This extends the
previous one-layer helper detection:

```text
#[no_alloc] caller -> helper -> helper -> allocating leaf
#[no_panic] caller -> helper -> helper -> panic leaf
```

Both now fail during compile with the existing RT diagnostic classes.

## Implementation

- Added `collect_same_file_callers_closure(source, seed_fns, max_depth)`.
- `enforce_no_alloc` now checks against the bounded closure of allocating
  same-file functions instead of one caller expansion.
- `enforce_no_panic` now checks against the bounded closure of panic-prone
  same-file functions instead of one caller expansion.
- Bound is `4` caller-expansion rounds. This keeps the source-level scanner
  finite and cheap while closing the next practical false-negative layer.
- Updated the RT audit info message so it no longer claims all deeper
  transitive same-file helpers escape.

## New Fixtures

- `tests/err/err_no_alloc_deep_helper_alloc.nr`
  - Expected: `error[RT-001] call to format_top() reaches same-file allocation`.

- `tests/err/err_no_panic_deep_helper_panic.nr`
  - Expected: `error[RT-002] call to guard_top() reaches same-file panic-prone code`.

- `tests/features/rt_attr_deep_clean_smoke.nr`
  - Expected: clean deeper helper chain still builds and runs with rc=0.

## Remaining Skipped Surfaces

- Cross-module callees.
- Closure values.
- Function pointers / higher-order callback flow.
- Deeper-than-bound helper chains.
- Certified WCET / deadline proof. This slice intentionally did not touch
  deadline syntax because same-file RT closure was the lower-risk real
  enforcement behavior available in the existing checker.

## Validation

```text
PASS .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _helper1_rt_s1_v0842 --no-link --no-cache
PASS tests\err\err_no_alloc_deep_helper_alloc.nr emits error[RT-001]
PASS tests\err\err_no_panic_deep_helper_panic.nr emits error[RT-002]
PASS tests\features\rt_attr_deep_clean_smoke.nr builds and target exe returns rc=0
PASS existing no_alloc/no_panic transitive negatives still emit RT-001/RT-002
PASS existing rt_transitive_clean_helper_chain_smoke.nr returns rc=0
PASS bash tools/check_self_host_md5.sh md5=ed88de1f2279c33679b6ba0e6723627b
PASS bash tools/check_compiler_drift.sh (existing RFC-0063 parser warnings only)
PASS bash tools/check_rod_void_abi.sh
PASS git diff --check
PASS pwsh -NoProfile -File tools\check_perf_regression.ps1
     cold=3.58s hot=0.45s cold_tree=362MB cold_compiler=347MB hot_tree=69MB hot_compiler=55MB
```

## Integration Notes

This branch includes promoted compiler artifacts:

- `bin/nucleor.exe`
- `bootstrap/nucleor_s1_seed.ll`

During Codex integration, the helper branch's older promoted artifacts were
discarded and regenerated from the combined current compiler source.

Additional integration validation:

```text
PASS .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _rt_s1_v0842_integration --no-cache --no-link
PASS .\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _rt_s1_v0842_integration --no-cache
PASS .\target\_rt_s1_v0842_integration.exe build tests\err\err_no_alloc_deep_helper_alloc.nr emits error[RT-001]
PASS .\target\_rt_s1_v0842_integration.exe build tests\err\err_no_panic_deep_helper_panic.nr emits error[RT-002]
PASS .\target\_rt_s1_v0842_integration.exe build tests\features\rt_attr_deep_clean_smoke.nr and target exe returns rc=0
PASS bash tools/check_self_host_md5.sh md5=e577d84c5cd5f9f769591b139f1f2712
PASS bash tools/check_compiler_drift.sh (known RFC-0063 parser warnings only)
PASS bash tools/check_rod_void_abi.sh
PASS git diff --check
PASS pwsh -NoProfile -File tools\check_perf_regression.ps1
     cold=3.41s hot=0.38s cold_tree=362MB cold_compiler=348MB hot_tree=70MB hot_compiler=55MB
```

`docs/rfcs/rod_manifest.toml` was regenerated after the drift gate correctly
caught stale rod metadata from the newly integrated ROBO-7 stdlib surface.
