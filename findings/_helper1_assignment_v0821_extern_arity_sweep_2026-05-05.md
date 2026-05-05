# Helper1 Assignment - Cross-Rod Extern ABI Arity Sweep

Created: 2026-05-05
Owner: helper1
Base: fetch current `origin/main` before branching

## Branch Setup

```powershell
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS fetch origin
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS worktree add `
  C:\Users\JoeWe\Nucleor_OSS_helper1_extern_arity_sweep_v0821 `
  -b probe/helper1-extern-arity-sweep-v0821 origin/main
cd C:\Users\JoeWe\Nucleor_OSS_helper1_extern_arity_sweep_v0821
git merge-base HEAD origin/main
```

The merge-base must equal fetched `origin/main`.

## Primary Task

Run a findings-only sweep for the ML-1 / kv_cache class of rod/runtime ABI
drift:

- For every `extern fn nuc_*` declaration in `stdlib/rods/*.nr`, compare the
  matching C runtime function signature in `stdlib/runtime/*_rt.c`.
- Confirm argument count first.
- Confirm obvious type class second:
  - `i64` should correspond to `long long`.
  - `str` should correspond to `const char *` / `char *`.
- Write one finding per confirmed mismatch to:
  `findings/inbox/extern_arity_drift_<rod-or-symbol>_2026-05-05.md`.

Use the standard finding style: source lines, C lines, impact, suggested fix,
and validation command/evidence.

## Important Filtering

Do not trust a first-pass regex blindly. Manually confirm each candidate.
Known false-positive classes:

- C comments inside multi-line signatures can add fake comma-separated args.
- `const char *` return types can make a naive signature regex miss string
  return functions.
- C files may contain prototypes and definitions for the same symbol; if
  their arity matches, that is not a mismatch.
- Internal C helper calls are not rod ABI issues unless there is an exported
  `extern fn nuc_*` declaration in a rod.

## Severity

- **CRITICAL:** rod declares fewer args than C definition. C reads garbage
  argument/register state.
- **HIGH:** rod declares more args than C definition. Extra caller args are
  ignored, but the wrapper may be semantically wrong.
- **MEDIUM:** count matches but string/pointer/integer type class is clearly
  inconsistent.

## Hard Boundaries

Do not edit:

- `compiler/`
- `stdlib/runtime/`
- `stdlib/rods/`
- `bin/`
- `bootstrap/`
- `tools/perf_baseline.json`
- `CHANGELOG.md`
- `RELEASES.md`

This is findings-only. Main ships fixes in version cadence.

Do not add Python helpers or Python runtime dependencies. Use shell,
PowerShell, `rg`, or manual review.

## WSL / Linux Note

If any validation touches memory/RSS, do not use WSL `/proc` as evidence for
Windows `bin\nucleor.exe`. WSL sees only the interop bridge process, not the
real Windows compiler/clang process tree. Use PowerShell RSS tools for Windows
`.exe` runs, or a native Linux compiler binary for POSIX `/proc` evidence.

This assignment should not require RSS validation.

## Validation

Minimum:

```powershell
git diff --check
git status --short
```

If you write JSON or generated tables, validate them with native tooling.

No full verify or perf gate is needed for findings-only output.

## Completion

Commit and push only the finding files and any small text report you create.

```powershell
git push origin probe/helper1-extern-arity-sweep-v0821
```

Then report:

- branch
- HEAD
- merge-base
- number of rod externs swept
- number of confirmed findings
- paths of findings written
- any caveats / false-positive classes
