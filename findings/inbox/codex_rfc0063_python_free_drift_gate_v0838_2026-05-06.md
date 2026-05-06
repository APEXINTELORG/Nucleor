# Codex RFC-0063 Python-Free Drift Gate v0838

Date: 2026-05-06
Branch: `fix/codex-next-punchlist-v0838`
Base: `origin/main` at `e75bbf52`

## Scope

Closed the RFC-0063 Track C Phase 5.5 drift-gate cleanup:

- removed Python PATH probing from `tools/check_compiler_drift.sh`;
- removed `.py` generator execution from the compiler drift gate;
- made non-`.nr` drift-gated generators fail instead of silently skipping;
- updated the RFC-0063 roadmap and v1 punchlist accounting.

Python interop remains intentionally out of scope. This change does not touch
`stdlib/rods/python.nr`, `python_rt.c`, tests for the Python rod, or archived
generator references.

## Rationale

The currently drift-gated generators are native Nucleor sources:

- `tools/gen_helper_manifest.nr`
- `tools/gen_rod_manifest.nr`
- `tools/gen_releases_index.nr`
- `tools/audit_dup_fns.nr`

Keeping a generic Python execution path in the gate made a Python install look
like a supported release/toolchain prerequisite even though all live gate inputs
are native. Removing it keeps the product path tighter and avoids accidental
reintroduction of Python-backed drift checks.

## Validation

Run:

```text
git diff --check
bash tools/check_compiler_drift.sh
```

No full verification or perf gate was run because this is a shell/docs cleanup
that does not touch compiler source, bootstrap artifacts, binaries, cache paths,
or runtime code.
