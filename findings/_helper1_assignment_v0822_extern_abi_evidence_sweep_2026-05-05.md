# Helper1 Assignment v0822 — Extern ABI Evidence Sweep

Date: 2026-05-05
Owner: helper1
Base: fetch current `origin/main`; merge-base with `origin/main` must equal fetched `origin/main`
Branch: `probe/helper1-extern-abi-evidence-sweep-v0822`
Mode: append-only findings lane

## Objective

Finish the cross-rod extern ABI evidence sweep without editing compiler,
runtime, rods, binaries, bootstrap, perf baselines, changelog, or release
files.

The deliverable is one new report:

`findings/inbox/helper1_extern_abi_evidence_sweep_v0822_2026-05-05.md`

Do not edit or replace the older v0821 assignment file. Treat this as the
fresh current assignment.

## Scope

Audit the Nucleor rod `extern fn` declarations against the backing C runtime
definitions/prototypes and classify findings into:

- confirmed arity mismatch,
- confirmed return-type ABI mismatch,
- confirmed pointer/value argument ABI mismatch,
- false positive caused by parser/regex limitations,
- needs manual review because the C signature is macro-generated or split
  across declarations.

Use targeted evidence. Do not rely on a single broad regex output as the final
truth.

## Guardrails

- No Python helpers. Use shell, PowerShell, `rg`, `awk`, `sed`, `git`, and
  manual source inspection.
- No compiler/runtime/rod edits in this lane.
- No committed binary, bootstrap seed, perf baseline, changelog, or release
  edits.
- Do not use WSL `/proc` as Windows `.exe` RSS evidence. This assignment does
  not require perf/RSS proof.
- If the sweep reveals a real mismatch, file it with exact source locations,
  proposed owner files, and the smallest follow-up patch scope.

## Suggested Commands

```powershell
git fetch origin
git checkout -b probe/helper1-extern-abi-evidence-sweep-v0822 origin/main
git merge-base HEAD origin/main
git status --short
```

Useful searches:

```powershell
rg -n "extern fn " stdlib compiler examples tests
rg -n "__nucleor_[A-Za-z0-9_]+\\s*\\(" stdlib\\runtime
rg -n "declare .*__nucleor_" compiler\\nucleor_s1_compiler.nr compiler\\nucleor_tools_suite.nr
```

Prefer small, named checks over one giant parser. If you use a script-shaped
one-liner, paste the exact command and summarize its known false-positive
classes in the report.

## Required Report Sections

- Summary
- Base and branch
- Commands run
- Counts by classification
- Confirmed issues, if any, with file:line evidence
- False-positive classes found
- Recommended next implementation lanes
- Validation

## Validation

Required before pushing:

```powershell
git diff --check
git status --short
```

If the report is the only changed file, push the branch and report:

```powershell
git push -u origin probe/helper1-extern-abi-evidence-sweep-v0822
```

