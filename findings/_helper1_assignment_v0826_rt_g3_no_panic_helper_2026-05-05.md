# Helper1 Assignment v0826: RT-G3 same-file no_panic helper diagnostic

## Base and Branch

Fetch first and branch from current `origin/main`:

```powershell
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS fetch origin
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS checkout -B fix/helper1-rt-g3-no-panic-helper-v0826 origin/main
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS status --short --branch
```

Current integration base when assigned: `6f02115b`.

## Scope

Build a narrow RT-G3 improvement analogous to the just-landed RT-G1
`#[no_alloc]` same-file helper guard.

Today `#[no_panic]` catches direct panic-prone patterns in the annotated
function body, plus some operator warnings, but it still misses this shape:

```nucleor
fn helper(x: Option<i64>) -> i64 {
    return x.unwrap();
}

#[no_panic]
fn rt_step(x: Option<i64>) -> i64 {
    return helper(x);
}
```

Goal: `rt_step` emits `RT-002` because it directly calls a same-file helper
whose own body contains a known `no_panic_check_list()` pattern.

## Required Work

- Update `compiler/nucleor_s1_compiler.nr`.
- Add a same-file helper body classifier for `no_panic_check_list()`.
- Add a direct caller check for `#[no_panic]` / `with [no_panic]` functions
  that call those same-file panic-helper functions.
- Skip self-calls to avoid duplicating direct-body diagnostics.
- Keep the pass bounded to one-hop same-file calls. Do not attempt full call
  graph, cross-module, trait, or fn-pointer analysis in this slice.
- Add focused negative fixture:
  `tests/err/err_no_panic_transitive_same_file.nr`.
- Update `docs/rfcs/v1_PUNCHLIST.md` and the Real-Time gap analysis text with
  the new partial RT-G3 status and remaining gaps.
- Rebuild/promote `bin/nucleor.exe` and `bootstrap/nucleor_s1_seed.ll`.

## Performance Guardrails

- Do not add a whole-source N^2 scan to every build. Gate the helper scan so it
  only runs when `collect_no_panic_fns(source)` is non-empty.
- Prefer reusing `source_fn_body_for_scan()` and
  `strip_strings_and_line_comments()` instead of adding another body parser.
- No Python helpers.

## Validation

Run at minimum:

```powershell
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o nucleor_s1_probe_rt_g3 --no-cache
.\target\nucleor_s1_probe_rt_g3.exe build tests\err\err_no_panic_transitive_same_file.nr -o _rt_g3_probe --no-cache
bash tools/verify.sh --sequential-fixtures --only "negative err_no_panic_transitive_same_file"
bash tools/verify.sh --sequential-fixtures --only "negative err_no_panic_violation"
bash tools/verify.sh --sequential-fixtures --only "test lang/no_alloc_clean"
bash tools/check_self_host_md5.sh
bash tools/check_compiler_drift.sh
git diff --check
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Expected performance target remains sub-4s cold and under 400MB process-tree
RSS.

## Deliverable

Commit and push the branch. Add a report under:

`findings/inbox/helper1_rt_g3_no_panic_helper_v0826_2026-05-05.md`

Report the branch, commit, merge-base with `origin/main`, validation results,
and final perf numbers. If this is not a clean one-hop same-file diagnostic,
write the finding and stop instead of widening the scope.
