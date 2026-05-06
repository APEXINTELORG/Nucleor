# Helper2 Assignment v0826: PKG-1 POSIX native release prep

## Base and Branch

Fetch first and branch from current `origin/main`:

```powershell
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_posix_native_release_v0826 fetch origin
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_posix_native_release_v0826 checkout -B fix/helper2-pkg1-posix-native-release-prep-v0826 origin/main
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_posix_native_release_v0826 status --short --branch
```

Current integration base when assigned: `6f02115b`.

## Scope

Advance PKG-1 without touching the compiler. This is a tools-suite-only POSIX
native release prep slice.

PKG-1 says `nuc publish --sign` is Windows-only today because the compiler path
calls PowerShell. Do not wire the compiler in this assignment. Build the POSIX
tooling artifact that the later compiler host-guard can call.

## Required Work

- Add `tools/native_release.sh`.
- Match the intent of `tools/native_release.ps1` where practical, but keep this
  first slice narrow and auditable.
- Required CLI surface:
  - `--help`
  - `--doctor`
  - `sign`
  - `verify`
- `--doctor` must print readiness for native Linux/macOS shell, required tools,
  and signing backend availability.
- If real signing cannot be completed without a native POSIX runner or keys,
  fail closed with a clear nonzero exit and documented reason. Do not emit fake
  signatures or placeholder attestations.
- Prefer `openssl` or `ssh-keygen -Y` if available. Do not require Python.
- Update `tools/VERIFY_TIMING_RECIPE.md` or a nearby tools doc only if useful.
- Add a report under `findings/inbox/`.

## Non-Scope

- Do not edit `compiler/nucleor_s1_compiler.nr`.
- Do not rebuild/promote `bin/nucleor.exe` or `bootstrap/nucleor_s1_seed.ll`.
- Do not change Windows `tools/native_release.ps1`.
- Do not claim PKG-1 is closed. This is prep for the later compiler host guard
  plus native POSIX evidence.

## Validation

Run at minimum:

```powershell
bash -n tools/native_release.sh
bash tools/native_release.sh --help
bash tools/native_release.sh --doctor
git diff --check
```

If `--doctor` correctly refuses WSL or missing prerequisites, capture that as
expected evidence and keep the script fail-closed.

## Deliverable

Commit and push the branch. Add:

`findings/inbox/helper2_pkg1_posix_native_release_prep_v0826_2026-05-05.md`

Report the branch, commit, merge-base with `origin/main`, validation results,
and exactly which PKG-1 surfaces remain for the later compiler integration.
