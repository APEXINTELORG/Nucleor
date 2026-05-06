# Helper2 Assignment v0828: R06 Phase 2 rust_bridge ownership harness

## Base and Branch

Fetch first and branch from current `origin/main`. Do not reuse the v0826
native-release branch.

```powershell
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828 fetch origin
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828 checkout -B fix/helper2-r06-rust-bridge-ownership-harness-v0828 origin/main
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828 status --short --branch
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828 merge-base HEAD origin/main
```

If that helper2 worktree does not exist yet, create it fresh from the repo
remote, then run the same fetch/checkout/merge-base checks.

Current integration base when assigned: `5ec86d7e4d965359348d33826553659157d16016`.

## Scope

Advance R06 Phase 2 without touching compiler source. R06 Phase 1 added
`rust_free_str` and deterministic hashing; Phase 2 needs a repeatable ownership
verification harness so the free path is not just a smoke fixture.

Build a standalone, non-Python tool that:

- checks whether the Rust toolchain and `stdlib/rods/rust_bridge` crate are
  available,
- builds or locates the release bridge artifact when possible,
- builds `tests/features/rust_bridge_string_free_smoke.nr`,
- runs repeated alloc/free cycles through that fixture,
- reports pass/fail and the exact reason when prerequisites are missing.

## Required Work

- Add `tools/check_rust_bridge_ownership.ps1`.
- Optional only if it stays small: add `tools/check_rust_bridge_ownership.sh`
  with equivalent `--doctor` behavior for POSIX.
- Update `tools/VERIFY_TIMING_RECIPE.md` or nearby tooling docs with how to
  run the harness manually.
- Add a report under `findings/inbox/`.

## Non-Scope

- Do not edit `compiler/`, `bin/`, `bootstrap/`, `tools/verify.sh`,
  `tools/verify.ps1`, or `tools/check_perf_regression*`.
- Do not modify Python interop or add Python helpers.
- Do not vendor Rust dependencies or fake a leak result when Rust/cargo or the
  bridge artifact is unavailable.
- Do not claim R06 Phase 2 is fully closed unless the harness actually ran
  repeated ownership cycles and produced clear pass evidence.

## Harness Contract

The PowerShell tool should support at least:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Iterations 100
```

`-Doctor` should print concise readiness: cargo present/missing, bridge crate
present/missing, expected release artifact path, compiler binary present, and
whether the focused fixture can be built on this host.

If prerequisites are missing, fail closed with a clear nonzero exit for the
normal run and a clear diagnostic for `-Doctor`. Do not silently pass.

## Performance Guardrails

This is not part of the hot compiler path. Keep it standalone and opt-in. The
normal verify/perf gates must not get slower from this assignment.

## Validation

Run at minimum:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Iterations 20
git diff --check
```

If cargo or the Rust bridge artifact is unavailable on the host, capture the
fail-closed output and run parser checks instead:

```powershell
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw tools\check_rust_bridge_ownership.ps1), [ref]$null)
git diff --check
```

## Deliverable

Commit and push the branch. Add:

`findings/inbox/helper2_r06_rust_bridge_ownership_harness_v0828_2026-05-06.md`

Report the branch, commit, merge-base with `origin/main`, exact files changed,
validation results, whether cargo/bridge prerequisites were available, and what
R06 Phase 2 work remains.

## Append-Only Continuation Queue (2026-05-06)

This section extends the same assignment document. Work top-down. If the next
scope is still a standalone opt-in bridge harness/docs change, batch it before
pushing. If it requires compiler changes, verify gate changes, vendored Rust
dependencies, or runtime ABI changes, stop at the previous green commit, write a
finding, and report the split point.

Before each continuation scope, fetch and verify the merge-base:

```powershell
git fetch origin
git status --short --branch
git merge-base HEAD origin/main
```

Do not add Python helpers.

### Scope B: R06 Phase 2b POSIX rust_bridge ownership doctor

Prerequisite: the PowerShell harness from Scope A exists and has either pass
evidence or clear fail-closed prerequisite evidence.

Add the POSIX companion if it remains small and mirrors the PowerShell contract:

- `tools/check_rust_bridge_ownership.sh`
- `--doctor` mode reports cargo, bridge crate path, expected release artifact,
  compiler binary, and focused fixture build readiness.
- `--iterations N` builds/runs the same ownership fixture repeatedly when
  prerequisites are available.
- Missing prerequisites must fail closed for normal runs and print clear doctor
  output; do not silently pass.
- Keep this opt-in. Do not wire it into normal `tools/verify.sh` or perf gates.

Validation:

```bash
bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --iterations 20
git diff --check
```

If POSIX prerequisites are unavailable, capture the exact fail-closed output in
the report and run `bash -n tools/check_rust_bridge_ownership.sh`.

### Scope C: R06 Phase 2c ownership evidence matrix and repeat fixture

Only do this if Scopes A and B stay standalone and green.

Make the bridge ownership evidence easier to review and rerun:

- Add or extend one focused fixture only if it adds real coverage beyond
  `tests/features/rust_bridge_string_free_smoke.nr`. Preferred name if needed:
  `tests/features/rust_bridge_string_free_repeat_smoke.nr`.
- Add a concise Windows/POSIX artifact matrix to the tooling docs that names the
  expected release library paths, host prerequisites, and exact harness commands.
- Run a larger iteration count when prerequisites are available. Target 100
  iterations; if unavailable, document the doctor output and do not claim closure.
- Update `docs/rfcs/v1_PUNCHLIST.md` with the exact R06 Phase 2 status and any
  remaining R06 gaps.

Keep this as test/tooling/docs only. No compiler files, no `bin/`, no
`bootstrap/`, no normal verify/perf gate changes, no Python helpers.

### Scope D: R06 Phase 3a rust_bridge hash determinism ownership fixture

Prerequisite: Scopes A/B/C are committed and pushed.

Extend the opt-in rust_bridge harness from ownership-only string-free coverage
to also cover deterministic Rust-returned string/hash behavior if the existing
rod surface supports it cleanly.

Required work:

- Inspect the existing Rust bridge API in `stdlib/rods/rust.nr`,
  `stdlib/rods/rust_bridge/src/lib.rs`, and current rust_bridge fixtures.
- If an existing deterministic hash/string-return helper is present, add one
  focused fixture:
  `tests/features/rust_bridge_hash_determinism_smoke.nr`.
- The fixture should run without leaking ownership: every Rust-owned returned
  string/path that must be freed should be freed through the existing
  `rust_free_str` convention.
- Extend `tools/check_rust_bridge_ownership.ps1` and
  `tools/check_rust_bridge_ownership.sh` with a small fixture selector:
  Windows `-Fixture string-free|hash|all`; POSIX `--fixture string-free|hash|all`.
  Default should remain the original string-free fixture so existing commands
  do not change behavior.
- Update the docs/report with exact commands and whether the hash fixture ran.

Stop condition:

- If the current rod surface does not expose a deterministic hash/string-return
  helper suitable for this fixture, do not invent runtime ABI or compiler work.
  Write a finding and stop at the green Scope C commit.

Validation:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture all -Iterations 20
bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
git diff --check
```

### Scope E: R06 Phase 3b machine-readable rust_bridge harness output

Only do this if Scope D stays standalone and green.

Add machine-readable output for CI and future release scripts without wiring the
harness into normal verify/perf gates:

- PowerShell: add `-Json` to `tools/check_rust_bridge_ownership.ps1`.
- POSIX: add `--json` to `tools/check_rust_bridge_ownership.sh`.
- JSON must include at least: schema version, host family, fixture selector,
  iterations requested, fixture executions completed, cargo path/presence,
  bridge artifact path/presence, compiler path/presence, result status, and
  failure reason when nonzero.
- Keep text output as the default.
- Add docs and report evidence showing both text and JSON modes.

Validation:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor -Json
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture all -Iterations 5 -Json
bash tools/check_rust_bridge_ownership.sh --doctor --json
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 5 --json
git diff --check
```

Keep Scope D/E as test/tooling/docs only. No compiler files, no `bin/`, no
`bootstrap/`, no normal verify/perf gate changes, no Python helpers.

## Append-Only Continuation Queue 2 (2026-05-06)

Continue from this same assignment document. Scope D/E is reported complete at
commit `c003119bc1bd9e23ccc91d31d9aa6d492c79a995`; the next batch should stay
in the opt-in Rust bridge harness lane. Batch the adjacent scopes below if they
stay script/docs/tests-only. Stop and write a finding if the work needs compiler
edits, Rust bridge ABI implementation, vendored dependencies, `bin/`,
`bootstrap/`, normal verify/perf wiring, or new Python helpers.

Before starting:

```powershell
git fetch origin
git status --short --branch
git merge-base HEAD origin/main
```

If your merge-base is not current `origin/main`, rebase first and rerun the
focused harness validation before pushing with `--force-with-lease`.

### Scope F: R06 Phase 3c rust_bridge harness JSON contract self-test

Goal: make the new machine-readable output reviewable without depending on
Cargo or a built Rust bridge artifact.

Required work:

- Add a no-build contract/self-test mode to both harnesses:
  - PowerShell: `-SelfTest`
  - POSIX: `--self-test`
- Self-test must not compile Nucleor, run Cargo, or require the bridge artifact.
- Self-test must validate:
  - supported fixture selectors: `string-free`, `hash`, `all`;
  - invalid fixture selector fails nonzero and reports a clear failure reason;
  - JSON output is syntactically valid when combined with `-Json` / `--json`;
  - JSON contains the required keys from Scope E.
- Keep normal text output as default.
- Add concise docs for self-test mode to `tools/VERIFY_TIMING_RECIPE.md` or the
  nearest existing harness documentation.

Validation:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -SelfTest
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -SelfTest -Json | ConvertFrom-Json | Out-Null
bash tools/check_rust_bridge_ownership.sh --self-test
bash tools/check_rust_bridge_ownership.sh --self-test --json
git diff --check
```

### Scope G: R06 Phase 3d fail-closed prerequisite parity audit

Goal: prove the Windows and POSIX harnesses fail closed the same way when a
required prerequisite is missing, without mutating the user's real toolchain.

Required work:

- If the existing scripts already have path override hooks, add focused
  negative checks for missing compiler / missing bridge artifact / missing cargo.
- If they do not have override hooks, add narrowly scoped test-only overrides
  using environment variables or explicit script parameters. Do not change
  default behavior.
- The negative checks must verify:
  - normal run returns nonzero;
  - doctor mode reports the missing prerequisite;
  - JSON mode sets result status to failure and includes a failure reason;
  - text and JSON behavior match on Windows and POSIX.
- Keep this as harness-only. Do not install/uninstall tools, rename real
  artifacts, or modify PATH globally.

Validation:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor -Json | ConvertFrom-Json | Out-Null
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -SelfTest -Json | ConvertFrom-Json | Out-Null
bash tools/check_rust_bridge_ownership.sh --doctor --json
bash tools/check_rust_bridge_ownership.sh --self-test --json
git diff --check
```

If a portable fail-closed simulation becomes larger than the harness itself,
stop after Scope F and write a finding with the smallest safer test seam.

### Scope H: R06 Phase 3e bridge-harness release closure report

Only do this after Scope F and, if feasible, Scope G.

Required work:

- Update `docs/rfcs/v1_PUNCHLIST.md` with exact R06 Phase 3 status:
  ownership fixture, POSIX harness, hash determinism fixture, JSON mode,
  self-test/fail-closed parity, and remaining gaps.
- Update `tools/VERIFY_TIMING_RECIPE.md` with a compact command matrix for:
  Windows text, Windows JSON, POSIX text, POSIX JSON, self-test, and doctor.
- Add a new report under `findings/inbox/`, suggested path:
  `findings/inbox/helper2_r06_rust_bridge_harness_contract_v0829_2026-05-06.md`
- Report exact validation output, current branch, commit, merge-base, files
  changed, and residual R06 work.

Do not run full verify or perf unless you changed normal verify/perf gates. Do
not add Python helpers.

### Scope I: R06 Phase 3f rust_bridge harness output stability transcript

Goal: make the harness evidence stable enough for release review and future CI
comparison.

Required work:

- Add a transcript fixture/report section that records the exact stable JSON
  field set and example output for:
  - `-Doctor -Json` / `--doctor --json`;
  - `-SelfTest -Json` / `--self-test --json`;
  - `-Fixture string-free -Iterations 1 -Json` / POSIX equivalent, when
    prerequisites are available.
- If prerequisites are unavailable, record doctor JSON and the fail-closed JSON
  instead of claiming a full run.
- Verify no timestamps, absolute temp paths, random IDs, or host-specific
  ordering make the JSON unsuitable for comparison. If unavoidable fields exist,
  document which fields must be ignored by future CI.
- Do not add a golden-file gate to normal verify.

Validation:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor -Json
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -SelfTest -Json
bash tools/check_rust_bridge_ownership.sh --doctor --json
bash tools/check_rust_bridge_ownership.sh --self-test --json
git diff --check
```

### Scope J: R06 Phase 4 candidate denylist/allowlist review

Goal: prepare the eventual v1.0 hardening step without turning it on.

Required work:

- Inventory all Rust bridge fixtures and docs that mention ownership,
  string-return, free, deterministic hash, or artifact paths.
- Add a short candidate allowlist/denylist section to the report:
  - what should be safe to run in future CI by default;
  - what should remain opt-in because it requires Cargo or built bridge libs;
  - what still lacks enough API/runtime support.
- If there is an existing machine-readable manifest for tools or verify timing,
  add only documentation references. Do not wire the bridge harness into normal
  gates.

Validation:

```powershell
rg -n "rust_bridge|rust_free_str|string_free|hash_determinism|check_rust_bridge_ownership" docs tools tests stdlib
git diff --check
```

### Scope K: R06 Phase 4 residual blocker reduction plan

Goal: leave the next mainline implementer with a concrete implementation plan,
not a vague "needs more work" note.

Required work:

- In the report, write a residual blocker table with:
  - blocker id;
  - current evidence;
  - exact smallest code surface needed;
  - expected validation command;
  - whether it is compiler, runtime ABI, Rust crate, docs, or CI.
- Include at least:
  - bridge artifact discovery on Windows and POSIX;
  - Rust-owned string/free ownership contract;
  - deterministic hash/string-return fixture coverage;
  - JSON output stability;
  - fail-closed prerequisite behavior;
  - future CI gating boundary.
- Keep this as report/docs only unless a tiny docs reference is clearly missing.

Validation:

```powershell
git diff --check
```

## Helper2 Deliverable For Queue 2

Commit and push one branch containing as many of Scopes F-K as stay cleanly
test/tooling/docs-only. Report which scopes completed, which were skipped with a
specific blocker, exact validation output, branch, commit, merge-base, and files
changed. If the queue splits, stop at the last green commit and leave the rest
as explicit remaining scope in the report.

## Continuation Queue 3: POSIX package/perf/release-gate closure pack

Appended 2026-05-06 by main agent. Keep using this same assignment document.
This queue is intentionally broader so you can keep moving after the rust bridge
ownership work without waiting for a new handoff.

Base rules:

- Fetch first and branch from current `origin/main` unless the main agent tells
  you to rebase a live branch.
- Do not add new Python helpers.
- Stay in tools/tests/docs/findings unless a tiny shell/PowerShell harness edit
  is clearly required.
- Do not claim native POSIX evidence from WSL or Windows `.exe` interop. The
  correct outcome there is fail-closed evidence and a blocker.

### Scope L: PKG-1 Linux `nuc publish --sign` prerequisite audit

Goal: turn PKG-1 from vague "needs Linux runner" into an exact runnable
checklist and, where possible, a dry-run harness.

Required work:

- Inspect current `nuc publish`, signing, package, lockfile, and bootstrap docs.
- Identify the exact commands that must run on a native Linux host.
- If a safe dry-run or doctor mode already exists, document it and add focused
  docs/report evidence.
- If no safe dry-run exists, add a report blocker with the smallest tool change
  needed. Do not wire real signing or network publishing into verify.

Validation:

```powershell
rg -n "publish|sign|package|Nucleor.lock|bootstrap_linux|PKG-1" docs tools compiler tests
git diff --check
```

### Scope M: Native POSIX perf transcript readiness

Goal: prepare R10-D3/R13 POSIX perf evidence without using WSL as fake proof.

Required work:

- Re-run the POSIX perf doctor/refusal paths available from Windows/WSL and
  capture the exact fail-closed behavior in the report.
- If you have access to a native Linux runner, run the native transcript using
  `tools/check_perf_regression.sh`; otherwise do not fabricate it.
- Update `tools/VERIFY_TIMING_RECIPE.md` only if the operator command sequence
  is missing or stale.

Validation:

```powershell
bash tools/check_perf_regression.sh --doctor
bash tools/check_perf_regression.sh --json
git diff --check
```

### Scope N: Release gate batch matrix

Goal: leave a release-operator matrix that batches the remaining gates into as
few passes as possible.

Required work:

- Build a concise matrix in the report covering:
  - full verify;
  - self-host md5;
  - compiler drift;
  - Windows perf gate;
  - POSIX perf gate;
  - rust bridge ownership harness;
  - package publish/sign dry-run;
  - native Linux bootstrap.
- For each row include command, platform, expected pass/fail-closed behavior,
  and whether it is release-blocking.
- Do not duplicate huge logs; keep exact commands and key outputs.

Validation:

```powershell
git diff --check
```

### Scope O: verify.sh / verify.ps1 parity audit for recent lanes

Goal: catch drift between Windows and Bash gates after the recent qsim, law,
rust-bridge, POSIX-perf, and package additions.

Required work:

- Compare `tools/verify.sh`, `tools/verify.ps1`, `tools/verify_fast.sh`, and
  `tools/VERIFY_TIMING_RECIPE.md` for mismatched recent gate coverage.
- Fix tiny naming/help drift if obvious and low-risk.
- If a gate intentionally exists only on one platform, document the reason in
  the report and avoid forcing false parity.

Validation:

```powershell
bash -n tools/verify.sh
bash -n tools/verify_fast.sh
[scriptblock]::Create((Get-Content -Raw tools\verify.ps1)) | Out-Null
git diff --check
```

### Scope P: TOOLCHAIN-PY-1 product-path audit (report first)

Goal: prepare the deferred "no Python in product/toolchain path" cleanup
without starting a risky compiler edit.

Required work:

- Search for Python use in compiler, router, normal user-facing commands, and
  release gates.
- Separate intentional Python interop (`stdlib/rods/python.nr` and runtime)
  from product/toolchain dependencies.
- Confirm whether `verify-reproducible` still shells out to `python -c` and
  document the exact replacement surface needed.
- Do not implement the compiler replacement in this scope unless the main
  agent explicitly redirects you.

Validation:

```powershell
rg -n "python|py -|python -c|filecmp|verify-reproducible" compiler tools docs nuc_router.ps1 stdlib tests
git diff --check
```

### Scope Q: Release blocker reduction report

Goal: synthesize the remaining non-quantum blockers into a concrete work queue.

Required work:

- Add a table covering PKG-1, POSIX perf native evidence, R06 POSIX bridge
  evidence, TOOLCHAIN-PY-1, RT deadline/WCET, ROBO-7, and effect-row Phase 2b.
- For each blocker include current evidence, smallest next code surface,
  validation command, platform, and whether helper/main should own it.
- Keep this report actionable; avoid generic "needs design" language.

Validation:

```powershell
git diff --check
```

## Helper2 Deliverable For Queue 3

Commit and push one branch containing as many of Scopes L-Q as stay cleanly
tooling/docs/report-only. Report completed scopes, skipped scopes with exact
blockers, validation output, branch, commit, merge-base, and files changed.
Full verify/perf is not required unless normal gate scripts change.

## Continuation Queue 4: release tooling, POSIX perf, package, and Python-removal prep

Append-only update, 2026-05-06. Queue 3 has landed from the helper branch
reported by the operator, and the final rust-bridge harness-contract commit has
been pulled into the integration branch. Continue from a fresh base; do not
reuse the old helper base.

Branch setup:

```powershell
git fetch origin
git switch -c fix/helper2-release-tooling-closure-v0830 origin/main
git merge-base HEAD origin/main
```

Hard constraints:

- Tooling/docs/report-first unless the edit is obviously small and isolated.
- Do not add Python helpers or new product/toolchain Python dependencies.
- Do not remove intentional Python interop rods, runtime bridge files, or
  maintenance generators in this queue; classify them clearly instead.
- Do not fake native Linux/WSL results. If the host cannot supply evidence,
  write the exact transcript blocker and continue elsewhere.
- Avoid expensive duplicate gates unless the changed files require them.

### Scope R: verify_fast / full-verify recent-gate parity

Goal: keep fast, full, Bash, and PowerShell gates coherent after recent
reproducible-build, qsim, rust-bridge, POSIX-perf, and package additions.

Required work:

- Compare `tools/verify.sh`, `tools/verify_fast.sh`, `tools/verify.ps1`, and
  `tools/VERIFY_TIMING_RECIPE.md`.
- Ensure recently added gates are either represented in the right tier or
  explicitly documented as platform-specific.
- Fix small help/naming/order drift only when the command is cheap and obvious.
- Avoid making `verify_fast` do full-release work.

Validation:

```powershell
bash -n tools/verify.sh
bash -n tools/verify_fast.sh
[scriptblock]::Create((Get-Content -Raw tools\verify.ps1)) | Out-Null
git diff --check
```

### Scope S: PKG-1 publish/sign dry-run hardening

Goal: reduce remaining package-release ambiguity without touching signing
secrets or real publishing.

Required work:

- Inspect package/release scripts and docs for dry-run behavior, overwrite
  protection, signing preflight, and artifact-path reporting.
- Add a tiny dry-run self-check or docs correction if the script already has a
  clear non-publishing mode.
- If signing/publish code is not cleanly testable, write a blocker table with
  exact commands, expected refusal text, and next file surface.

Validation:

```powershell
rg -n "publish|sign|package|dry.?run|checksum|sha256|release" tools docs bootstrap README.md
git diff --check
```

### Scope T: POSIX perf evidence closeout

Goal: make the POSIX perf gate release-readable while keeping evidence honest.

Required work:

- Recheck `tools/check_perf_regression.sh`, POSIX timing docs, and any native
  Linux transcript reports already present.
- Add missing command/help text, transcript schema notes, or blocker rows.
- If native Linux is unavailable, do not run substitute evidence; document the
  exact command the Linux host must run and the expected output fields.

Validation:

```powershell
bash -n tools/check_perf_regression.sh
rg -n "POSIX|Linux|perf|cold|hot|RSS|native" tools docs findings
git diff --check
```

### Scope U: TOOLCHAIN-PY-2 product-path removal plan

Goal: turn the deferred no-Python-helper policy into a concrete removal queue.

Required work:

- Scan compiler, router, normal CLI/tool-suite paths, release gates, and docs
  for Python requirements.
- Classify every hit as one of:
  - product/toolchain dependency to remove;
  - intentional language interop;
  - maintenance-only generator;
  - test/reference-only artifact.
- For removable product/toolchain hits, identify the smallest Nucleor/native
  replacement surface and validation command.
- Do not implement broad removals in this queue unless the change is tiny and
  cannot affect normal users.

Validation:

```powershell
rg -n "python|py -|python -c|\\.py\\b|filecmp|json.tool" compiler tools docs nuc_router.ps1 stdlib tests README.md
git diff --check
```

### Scope V: release blocker dashboard refresh

Goal: leave main with a compact, current non-quantum release queue after recent
helper landings.

Required work:

- Update the report with a matrix covering PKG-1, POSIX perf native evidence,
  rust bridge ownership, TOOLCHAIN-PY, RT deadline/WCET, ROBO-7, and effect-row
  Phase 2b.
- For each row include current evidence, next file/function surface, validation
  command, platform, and whether helper/main should own it.
- Touch `docs/rfcs/v1_PUNCHLIST.md` only for claims backed by this queue.

Validation:

```powershell
rg -n "PKG-1|POSIX|rust bridge|TOOLCHAIN-PY|WCET|ROBO-7|effect-row|Phase 2b" docs tools findings
git diff --check
```

## Helper2 Deliverable For Queue 4

Commit and push one branch containing as many Scopes R-V as stay cleanly
tooling/docs/report-first. Report completed scopes, skipped scopes with exact
blockers, validation output, branch, commit, merge-base, and files changed.
Full verify/perf is not required unless normal gate scripts or release scripts
change in a way that requires it.

## Continuation Queue 5: PKG-1 release dry-run/preflight closure pack

Append-only update, 2026-05-06. Queue 4 has landed from
`fix/helper2-release-tooling-closure-v0830` at
`f43fa3a79f73cc5d77684f749b9812d1bd1d9681`. Continue from the same helper2
worktree and keep the Queue 5 commits on top of the Queue 4 branch unless the
main agent explicitly tells you that Queue 4 has been merged to `origin/main`.

Branch setup:

```powershell
git fetch origin
git checkout fix/helper2-release-tooling-closure-v0830
git rebase origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Hard constraints:

- Do not add Python helpers or new product/toolchain Python dependencies.
- Do not touch `compiler/nucleor_s1_compiler.nr`, `bin/`, or `bootstrap/`.
- Prefer `tools/`, docs, tests, and findings. `compiler/nucleor_tools_suite.nr`
  is allowed only if the change is a clean tools-suite-only CLI dispatch/dry-run
  prep that does not require self-host compiler promotion.
- Do not run real package signing against user secrets or a remote registry.
  Use temp registries, generated throwaway keys, parser checks, and dry-run
  evidence only.
- Do not claim native POSIX evidence from WSL or Windows `.exe` interop.
- Keep cold-compile/perf overhead unchanged; do not wire new expensive checks
  into normal verify/perf gates.

### Scope W: native_release package-sign dry-run/preflight

Goal: make package signing inspectable without mutating package artifacts or
creating secret material.

Required work:

- Inspect `tools/native_release.ps1` and current package-sign/release-sign docs.
- If the script can support it cleanly, add a read-only package-sign dry-run or
  preflight mode that reports:
  - package directory;
  - manifest/export metadata path;
  - key id requested or inferred;
  - expected signature path;
  - whether the key is present;
  - whether signing would overwrite an existing signature.
- The dry-run/preflight must not create keys, write signatures, copy packages,
  or mutate registries.
- If the script shape makes this risky, do not force it. Add a blocker table
  with the exact function and smallest safe implementation surface.

Validation when implemented:

```powershell
[scriptblock]::Create((Get-Content -Raw tools\native_release.ps1)) | Out-Null
pwsh -NoProfile -File tools\native_release.ps1 -Help
git diff --check
```

Add any more focused command the script already supports for package-sign
preflight. Do not run destructive signing commands.

### Scope X: tools-suite `nuc publish --dry-run` dispatch prep

Goal: reduce PKG-1 risk by proving whether `nuc publish` can expose a
non-mutating dry-run before copying into the registry.

Required work:

- Inspect `compiler/nucleor_tools_suite.nr::run_publish_command` and nearby
  manifest/registry/signing helpers.
- If clean and tools-suite-only, add `--dry-run` parsing and a pre-copy report
  path that resolves:
  - manifest path;
  - package name/version;
  - registry package directory;
  - export manifest path;
  - checksum/signature target paths;
  - signing key id when `--sign` is present.
- Dry-run must return success only after validating the same inputs that normal
  publish would need before mutation. It must not copy, write registry metadata,
  write checksums, sign, or create keys.
- If this requires s1 compiler changes, promoted binaries, broad parser churn,
  or native release logic changes, stop and write the blocker instead.

Validation when implemented:

```powershell
rg -n "publish|dry.?run|sign|registry|package" compiler/nucleor_tools_suite.nr tools docs tests
bash -n tools/verify.sh
bash -n tools/verify_fast.sh
git diff --check
```

Run any existing focused tools-suite/publish fixture if one already exists.
Do not add broad verify-gate wiring.

### Scope Y: PKG-1 native Linux transcript checklist

Goal: leave the exact native Linux command batch the operator needs, with no
fake WSL proof.

Required work:

- Add a compact report section that lists the native Linux commands for:
  - bootstrap;
  - self-host md5;
  - compiler drift;
  - POSIX perf;
  - package publish dry-run;
  - package publish/sign with a throwaway registry/key;
  - signature verification.
- Include expected pass output shape and fail-closed refusal shape.
- Update `tools/VERIFY_TIMING_RECIPE.md` or package docs only if the command
  sequence is currently missing or stale.

Validation:

```powershell
rg -n "bootstrap_linux|publish|sign|package|registry|POSIX|perf|native Linux" docs tools findings compiler
git diff --check
```

### Scope Z: release blocker reduction matrix

Goal: make the non-quantum release queue smaller and directly actionable.

Required work:

- Add or update a report matrix covering:
  - PKG-1 dry-run/preflight;
  - PKG-1 native Linux signed publish transcript;
  - POSIX perf native transcript;
  - rust bridge ownership evidence;
  - TOOLCHAIN-PY keep-closed audit;
  - RT deadline/WCET;
  - ROBO-7 frame typing;
  - effect-row Phase 2b.
- For every row include current evidence, exact next file/function surface,
  validation command, platform, and whether helper or main should own it.
- Update `docs/rfcs/v1_PUNCHLIST.md` only for changes backed by Queue 5 work.

Validation:

```powershell
rg -n "PKG-1|POSIX perf|rust bridge|TOOLCHAIN-PY|deadline|WCET|ROBO-7|effect-row|Phase 2b" docs tools findings compiler
git diff --check
```

## Helper2 Deliverable For Queue 5

Commit and push the same helper2 branch with as many Scopes W-Z as stay clean
and non-destructive. Report completed scopes, skipped scopes with exact
blockers, validation output, branch, commit, merge-base, files changed, and any
remaining PKG-1/release blockers. Full verify/perf is not required unless you
change normal gate scripts or release scripts in a way that requires it.

---

## Queue 6 Addendum - PKG-1 closure plus hermetic tooling lane

Append-only update: 2026-05-06.

Base rule:

- If the operator has promoted the integration batch to `origin/main`, branch
  fresh from current `origin/main`.
- Otherwise branch fresh from
  `origin/fix/main-qm7-surface-code-v0827`.
- Do not base from the local Claude spike. Main owns that integration.
- You are not alone in the repo. Do not revert or overwrite edits by other
  agents. Keep this branch focused on release tooling, native-generator ports,
  tests/docs, and your report.

Guardrails:

- No new Python helper dependencies.
- Do not remove existing Python maintenance generators unless a native
  replacement is committed and the output parity is demonstrated.
- Do not run destructive publish/sign commands against a real registry.
- Prefer dry-run/preflight surfaces that validate inputs and target paths
  before mutation.
- If a change requires promoted `bin/nucleor.exe` or
  `bootstrap/nucleor_s1_seed.ll`, say so explicitly and either run the proper
  focused promotion checks or stop with a blocker.

### Scope AA: PKG-1 `nuc publish --dry-run`

Goal: add a non-mutating publish path that proves what would happen before any
registry copy/sign/write.

Required work:

- Inspect `compiler/nucleor_tools_suite.nr::run_publish_command` and the
  package graph/export/signing helpers around it.
- If clean, add `--dry-run` parsing and a pre-copy report path that resolves:
  - manifest path;
  - package name/version;
  - registry package directory;
  - export manifest path;
  - checksum target path;
  - signature target path when `--sign` is present;
  - requested/inferred key id;
  - overwrite/refusal state.
- Dry-run must validate the same inputs normal publish needs before mutation.
- Dry-run must not copy, write export files, write checksums, write registry
  metadata, sign, create keys, or create package directories.
- If this requires broad compiler/parser changes, stop and write the blocker.

Suggested validation when implemented:

```powershell
rg -n "run_publish_command|publish|dry.?run|sign|registry|package" compiler/nucleor_tools_suite.nr tools docs tests
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o _tools_suite_dryrun --no-cache
bash -n tools/verify.sh
bash -n tools/verify_fast.sh
git diff --check
```

Add a tiny focused publish dry-run fixture/script only if one can run without
mutating real registries. Use a temp directory under `target/`.

### Scope AB: `tools/native_release.ps1` package-sign preflight

Goal: let operators inspect package-sign readiness without writing signatures
or creating keys.

Required work:

- Add a read-only preflight/dry-run mode for package signing if it fits the
  current CLI shape cleanly.
- Output should include:
  - package directory;
  - `Nucleor.publish.json` path and presence;
  - signature JSON target path;
  - key id;
  - key presence;
  - overwrite/refusal state;
  - whether normal signing would need to create or overwrite anything.
- The preflight must not write signature files, generate keys, mutate trust
  stores, or change package directories.
- If current CLI shape makes this risky, file the exact blocker and smallest
  safe command shape.

Suggested validation:

```powershell
[scriptblock]::Create((Get-Content -Raw tools\native_release.ps1)) | Out-Null
pwsh -NoProfile -File tools\native_release.ps1 -Help
git diff --check
```

Run a temp-dir preflight only if it is guaranteed non-mutating.

### Scope AC: Native rod manifest generator port

Goal: start hermetic-toolchain closure by replacing `gen_rod_manifest.py` with a
native Nucleor generator or a clean blocker.

Required work:

- Inspect `tools/gen_rod_manifest.py` and current
  `docs/rfcs/rod_manifest.toml`.
- If feasible, add `tools/gen_rod_manifest.nr` or a tools-suite
  `gen-rod-manifest` dispatch, whichever matches the emerging local pattern.
- Prove output parity against the existing manifest. Do not delete the Python
  generator in this scope unless native output parity is demonstrated and the
  drift gate is updated safely.
- If Nucleor lacks a required string/path primitive, record the exact missing
  primitive rather than writing a fragile workaround.

Suggested validation:

```powershell
python tools\gen_rod_manifest.py
.\bin\nucleor.exe build tools\gen_rod_manifest.nr -o gen_rod_manifest --no-cache
.\target\gen_rod_manifest.exe
git diff -- docs\rfcs\rod_manifest.toml
git diff --check
```

### Scope AD: Native benchmark/numerics generator feasibility pack

Goal: prepare the next two hermetic-toolchain ports without rushing them into
bad native code.

Required work:

- Inspect `tools/gen_benchmark_summary.py` and `tools/gen_numerics_matrix.py`.
- For each, write a concise feasibility table:
  - inputs read;
  - outputs written;
  - regex/string/path features needed;
  - current Nucleor support or missing primitive;
  - smallest native implementation path;
  - parity test command.
- If one is clean after Scope AC, implement it; otherwise leave exact blockers.

Validation:

```powershell
rg -n "gen_benchmark_summary|gen_numerics_matrix|benchmark|numeric" tools docs tests
git diff --check
```

### Scope AE: release/hermetic blocker compression

Goal: leave main with a small, directly actionable release queue.

Required work:

- Update your report matrix covering:
  - PKG-1 publish dry-run;
  - package-sign preflight;
  - native Linux signed publish transcript;
  - POSIX perf native transcript;
  - gen_rod_manifest native port;
  - gen_benchmark_summary native port;
  - gen_numerics_matrix native port;
  - gen_helper_manifest native port;
  - Python keep-closed product-path audit.
- For each row include status, exact files/functions, validation command,
  platform, and owner suggestion.
- Update `docs/rfcs/v1_PUNCHLIST.md` only when backed by implemented work or a
  precise blocker.

## Helper2 Deliverable For Queue 6

Commit and push one branch containing as many Scopes AA-AE as stay coherent.
Report completed scopes, skipped scopes with exact blockers, validation output,
branch, commit, merge-base, files changed, and whether any normal gate needs to
be run by main before integration. Prefer one substantial branch over tiny
nibble branches.

---

## Queue 7 Addendum - Hermetic release tooling closure batch

Append-only update: 2026-05-06.

Context now landed in the integration branch:

- Queue 6 PKG-1 dry-run/preflight work has been cherry-picked into
  `origin/fix/main-qm7-surface-code-v0827`.
- Cloud/native-tooling work through `tools/gen_rod_manifest.nr` has also been
  integrated.
- The current pushed integration head after generated audit refresh is
  `6199189d`. If the remote has advanced, use the latest fetched remote head
  and record it in your report.

Start fresh:

```powershell
git fetch origin
git switch -C fix/helper2-hermetic-release-closure-v0832 origin/fix/main-qm7-surface-code-v0827
git status --short --branch
git merge-base HEAD origin/fix/main-qm7-surface-code-v0827
```

Guardrails:

- Do not base from the old Queue 6 helper branch.
- Do not revert main/integration commits, cloud commits, or other helpers'
  landed work.
- No new Python helpers and no new product/toolchain Python dependency.
- Existing Python generators may be used only as parity oracles where this doc
  explicitly says so.
- Do not delete existing Python generator files unless the native replacement
  is already integrated, the policy/docs say the one-cycle retention window is
  over, and the drift gate remains green. For this queue, default to keeping the
  Python files.
- Keep changes focused on release tooling, native generator ports, docs,
  tests/fixtures, and report artifacts. Stop with a blocker if a scope requires
  broad compiler/parser/runtime surgery.
- Prefer one substantial coherent branch over several tiny branches.

### Scope AF: PKG-1 dry-run validation and fixture lock

Goal: turn the new `nuc publish --dry-run` and
`package-sign-preflight` surfaces from implemented code into repeatable release
evidence.

Required work:

- Build or locate a temp-only package fixture under `target/` or `tests/fixtures`
  that can exercise:
  - `nuc publish <fixture> --registry <temp-registry> --dry-run`;
  - the same command with `--sign --key-id <throwaway-id>`;
  - `pwsh -NoProfile -File tools\native_release.ps1 -Root . package-sign-preflight <temp-package-dir> --json`.
- The fixture must not mutate a real registry, trust store, signing key, or
  release directory.
- Add a focused script or verify entry only if it is genuinely cheap and
  non-destructive. Otherwise record the exact manual transcript command block
  in your report and `tools/VERIFY_TIMING_RECIPE.md`.
- Confirm dry-run refuses or reports overwrite state before mutation.
- If current code cannot produce a useful temp package directory for preflight
  without a real publish, document the smallest missing command shape.

Validation:

```powershell
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o _tools_suite_pkg1_v0832 --no-cache
pwsh -NoProfile -File tools\native_release.ps1 -Help
rg -n "publish|dry.?run|package-sign-preflight|Nucleor.publish|signature" compiler tools docs tests findings
git diff --check
```

### Scope AG: Native benchmark summary generator port (Track C C4)

Goal: port `tools/gen_benchmark_summary.py` to native Nucleor if the existing
stdlib string/file surface is enough.

Required work:

- Inspect `tools/gen_benchmark_summary.py`, its inputs, and its generated
  output target.
- Add `tools/gen_benchmark_summary.nr` if the port is clean.
- Run the Python generator only as a parity oracle, then run the native
  generator and prove the output is byte-identical or intentionally equivalent
  with a documented diff.
- If the drift gate should track this output, update
  `tools/check_compiler_drift.sh` narrowly and keep WSL/Windows path handling
  consistent with existing `.nr` generator checks.
- If required primitives are missing, do not fake the port. Record the exact
  missing primitive and smallest native implementation path.

Validation:

```powershell
rg -n "gen_benchmark_summary|benchmark summary|benchmark" tools docs tests
python tools\gen_benchmark_summary.py
.\bin\nucleor.exe build tools\gen_benchmark_summary.nr -o gen_benchmark_summary --no-cache
.\target\gen_benchmark_summary.exe
git diff --check
```

### Scope AH: Native numerics matrix generator port (Track C C5)

Goal: port `tools/gen_numerics_matrix.py` or reduce it to a precise blocker.

Required work:

- Inspect `tools/gen_numerics_matrix.py`, `tools/run_numerics_matrix.*`, and
  the generated matrix output contract.
- If clean, add `tools/gen_numerics_matrix.nr` and a parity check.
- Keep output stable enough that future drift gates can compare it without
  Python.
- Do not broaden normal full verify just to run slow numerics cases. Keep this
  to generator parity unless the existing script is already cheap.
- If the port needs regex/TOML/JSON/string APIs that Nucleor lacks, document the
  exact missing primitive and the smallest native rod/compiler addition needed.

Validation:

```powershell
rg -n "gen_numerics_matrix|run_numerics_matrix|numeric|NUM-" tools docs tests
python tools\gen_numerics_matrix.py
.\bin\nucleor.exe build tools\gen_numerics_matrix.nr -o gen_numerics_matrix --no-cache
.\target\gen_numerics_matrix.exe
git diff --check
```

### Scope AI: Native helper manifest port prep (Track C C6)

Goal: prepare the hardest generator port without turning it into a fragile
rewrite.

Required work:

- Inspect `tools/gen_helper_manifest.py` and the current native generator
  patterns in `tools/gen_releases_index.nr`, `tools/gen_rod_manifest.nr`, and
  `tools/audit_dup_fns.nr`.
- Write a focused feasibility section in your report with:
  - input files read;
  - output sections emitted;
  - parsing/string features used by the Python version;
  - exact Nucleor primitives already available;
  - missing primitives if any;
  - the smallest safe first native slice.
- If one self-contained slice is clean, implement that slice only. Examples:
  output header parity, one table family, or one source-file scanner.
- Do not replace `gen_helper_manifest.py` or drift gate ownership unless parity
  is proven.

Validation:

```powershell
rg -n "gen_helper_manifest|helper_manifest|native generator|audit_dup_fns" tools docs findings
python tools\gen_helper_manifest.py
git diff -- docs\rfcs\helper_manifest.toml
git diff --check
```

### Scope AJ: release blocker compression and handoff matrix

Goal: leave main with a compact list of the remaining non-quantum release
blockers after Queue 7.

Required work:

- Update or create one report under `findings/inbox/` that summarizes:
  - PKG-1 dry-run validation;
  - package-sign preflight validation;
  - native Linux signed publish transcript remaining work;
  - POSIX perf native evidence remaining work;
  - C4/C5/C6 native generator status;
  - Python keep-closed product-path status;
  - R06 rust_bridge ownership remaining native/POSIX evidence;
  - RT deadline/WCET and effect-row Phase 2b status if touched by the scan.
- For every row include exact file/function surface, validation command,
  platform, owner suggestion, and whether it blocks the next release candidate.
- Update `docs/rfcs/v1_PUNCHLIST.md` and
  `docs/rfcs/RFC-0063-production-readiness-roadmap.md` only where backed by
  implemented work or a precise blocker.

Validation:

```powershell
rg -n "PKG-1|TOOLCHAIN-PY|gen_benchmark_summary|gen_numerics_matrix|gen_helper_manifest|POSIX perf|rust_bridge|effect-row|WCET" docs tools findings
git diff --check
```

## Helper2 Deliverable For Queue 7

Commit and push one branch containing as many Scopes AF-AJ as stay coherent.
Report completed scopes, skipped scopes with exact blockers, validation output,
branch, commit, merge-base, files changed, and whether main needs to run drift,
self-host, perf, or full verify before integration. If you change
`tools/check_compiler_drift.sh`, a normal verify script, or promoted compiler
artifacts, call that out explicitly.

---

## Queue 7.1 Update - C4 benchmark generator already landed

Append-only update: 2026-05-06.

After Queue 7 was written, the cloud-agent C4 work was integrated into
`origin/fix/main-qm7-surface-code-v0827`:

- `tools/gen_benchmark_summary.nr`
- `docs/BENCHMARK.md`

Do not reimplement Scope AG. Instead:

- fetch the latest `origin/fix/main-qm7-surface-code-v0827`;
- branch from that head;
- validate the native benchmark generator if your work touches adjacent
  hermetic tooling;
- prioritize Scopes AF, AH, AI, and AJ unless the branch has already moved
  those forward.

Suggested quick validation:

```powershell
git fetch origin
git switch -C fix/helper2-hermetic-release-closure-v0832 origin/fix/main-qm7-surface-code-v0827
.\bin\nucleor.exe build tools\gen_benchmark_summary.nr -o gen_benchmark_summary
.\target\gen_benchmark_summary.exe
git diff -- docs\BENCHMARK.md
git diff --check
```

---

## Queue 8 Update - blocker-aware external integration + hermetic tooling batch

Append-only update: 2026-05-06.

Read this before continuing. Your recent reports list real residual blockers:

- PKG-1 native Linux signed-publish transcript;
- POSIX perf native transcript;
- POSIX rust_bridge ownership proof with native cargo/compiler/artifact.

Do **not** keep re-running those native-POSIX proof lanes from Windows/WSL.
They are native-Linux-only closure items unless you are actually on a native
Linux host with native `bin/nucleor`, native `cargo`, `clang`, and ELF proof.
If your current host is Windows or WSL, mark those rows `NATIVE-LINUX-ONLY`
in your report and move to the work below.

Base from the latest integration branch that carries the cloud dispatch pack:

```powershell
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828 fetch origin
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828 switch -C fix/helper2-external-hermetic-closure-v0834 origin/fix/main-qm7-surface-code-v0827
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828 merge-base HEAD origin/fix/main-qm7-surface-code-v0827
git -C C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828 status --short --branch
```

Primary coordination doc now on GitHub:

```text
docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md
```

### Scope AK: ML-EXT-A/B/C external ML Suite visibility audit

Goal: give main/cloud agents current visibility into the external ML Suite
workspaces without importing ML Suite code into `Nucleor_OSS`.

Observed local paths on this machine:

```text
C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite
C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent
C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent_Mainline
C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\MLV_Kernel
C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Expansion_Spine_Integration_Brief_2026-05-01.md
C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\BUILD_PATH_v0.4_to_v1.3.md
```

Required work:

- Read-only inspect the ML Suite repos/workspaces above.
- For each repo: record path exists/missing, git branch, HEAD, dirty status,
  primary verify/test command if discoverable, and whether it appears to be
  canonical or superseded.
- Map evidence to ML Expansion lanes A-K from the dispatch pack:
  A evidence claims/backend dispatch, B frontend surfaces, C kernel/serve/pkg,
  D dtype claim rule, E HF metadata, F ONNX/GGUF, G vLLM serving, H
  Arrow/DLPack/tabular, I boosting, J backend manifest/accounting, K package
  manifest/lockfile/NCAP/conformance.
- Produce a gap matrix:
  - belongs in `Nucleor_OSS`;
  - remains external in ML Suite;
  - needs only docs/CLI contract;
  - blocker/unknown.
- Do **not** copy ML Suite source into `Nucleor_OSS`.
- Do **not** claim ML replacement surfaces without native execution evidence.

Output:

```text
findings/inbox/helper2_ml_suite_external_visibility_v0834_2026-05-06.md
```

Suggested commands:

```powershell
Get-ChildItem -LiteralPath C:\Users\JoeWe\Desktop\Nucleor_OSS_Files -Force -Directory | Where-Object { $_.Name -match 'ML|Translate|Suite|ParallelAgent|MLV' }
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite status --short --branch
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent_Mainline status --short --branch
rg -n "verify|test|parity|claim|evidence|ONNX|GGUF|vLLM|DLPack|boost|backend|NCAP|conformance" C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent_Mainline\docs
```

### Scope AL: TRANS-A/B Translate current-state verification and gap report

Goal: verify current `Nucleor_Translate` state and define what remains before
the future `nuc port` shim is allowed.

Observed local path:

```text
C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate
```

Required work:

- Read-only inspect current Translate branch, HEAD, dirty status.
- Find and run the cheapest documented test/verify command if safe.
- Record language matrix: completed, partial, missing.
- Check whether the spine-recorded state is still true:
  - 6 of 20 languages done;
  - 368 tests PASS;
  - compiler pin is Nucleor 0.4.5 or changed.
- Produce an adopter-readiness gap report for:
  - control-flow IR;
  - float parsing;
  - C structs;
  - any other current blockers.
- Do **not** copy Translate source into `Nucleor_OSS`.
- Do **not** wire `nuc port`.

Output:

```text
findings/inbox/helper2_translate_current_state_v0834_2026-05-06.md
```

Suggested commands:

```powershell
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate status --short --branch
git -C C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate log --oneline -5
rg -n "test|verify|PASS|language|Python|Rust|Go|TypeScript|JavaScript|control-flow|float|struct|0\\.4\\.5|nuc port|nuctranslate" C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate
```

### Scope AM: HERM-A native numerics matrix generator or precise blocker

Goal: advance Lane 10 without adding Python dependencies.

Required work:

- Inspect `tools/gen_numerics_matrix.py`, `tools/run_numerics_matrix.*`, and
  current generated outputs.
- If clean, implement `tools/gen_numerics_matrix.nr` with parity evidence.
- If not clean, write a precise blocker with missing Nucleor primitives and
  smallest safe first native slice.
- Do not broaden default full verify or add slow numerics runs.
- Do not add any new Python helper.

Validation:

```powershell
rg -n "gen_numerics_matrix|run_numerics_matrix|numerics_matrix|NUM-" tools docs tests
python tools\gen_numerics_matrix.py
.\bin\nucleor.exe build tools\gen_numerics_matrix.nr -o gen_numerics_matrix --no-cache
.\target\gen_numerics_matrix.exe
git diff --check
```

If the native file is not implemented, replace the build/run commands with the
blocker proof and report why.

### Scope AN: HERM-B helper manifest native-port feasibility or first slice

Goal: prepare `gen_helper_manifest.py` replacement without a fragile rewrite.

Required work:

- Inspect `tools/gen_helper_manifest.py`.
- Compare existing native tool patterns:
  - `tools/gen_releases_index.nr`;
  - `tools/gen_rod_manifest.nr`;
  - `tools/gen_benchmark_summary.nr`;
  - `tools/audit_dup_fns.nr`.
- Write the feasibility matrix:
  - input files read;
  - output sections emitted;
  - regex/string parsing features used by Python;
  - Nucleor primitives already available;
  - missing primitives;
  - smallest safe first native slice.
- If one slice is clearly self-contained, implement that slice only.
- Do not replace `gen_helper_manifest.py` or change drift-gate ownership
  unless parity is proven.

Validation:

```powershell
rg -n "gen_helper_manifest|helper_manifest|native generator|audit_dup_fns|gen_rod_manifest|gen_benchmark_summary" tools docs findings
python tools\gen_helper_manifest.py
git diff -- docs\rfcs\helper_manifest.toml
git diff --check
```

### Scope AO: blocker ledger normalization

Goal: compress the remaining Helper2 blockers into a current, non-redundant
handoff so main can dispatch the right environment-specific work.

Required work:

- Create or update one report under `findings/inbox/` that normalizes:
  - PKG-1 native Linux signed publish proof;
  - POSIX perf native transcript;
  - POSIX rust_bridge native ownership proof;
  - TOOLCHAIN-PY keep-closed audit;
  - HERM-A/HERM-B status;
  - ML-EXT and TRANS status if completed.
- For every blocker, include:
  - current evidence;
  - exact platform requirement;
  - exact command to close;
  - whether Helper2 can close it from current host;
  - owner recommendation.
- Update docs only where backed by new evidence.

Output:

```text
findings/inbox/helper2_blocker_ledger_v0834_2026-05-06.md
```

## Helper2 Deliverable For Queue 8

Push one branch with as many Scopes AK-AO as are coherent. It is fine if
AM/AN become blocker reports instead of code ports, but AK/AL/AO should be
finishable from Windows because they are read-only audits plus report work.

Final handoff must include:

```text
Branch:
HEAD:
Base:
Merge-base:
Completed scopes:
Skipped scopes and exact blockers:
Changed files:
Validation:
Report paths:
Whether main needs drift/self-host/perf/full verify:
```

Do not run full verify for read-only/report-only external audits. Run focused
validation for any tool or generated-output change, and `git diff --check` for
all branches.
