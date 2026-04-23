# Contributing to Nucleor

Thanks for your interest in contributing. This doc covers how to
build, test, file issues, and submit PRs. The intended audience is
both first-time contributors and seasoned compiler engineers.

## Quick start

```bash
git clone https://github.com/APEXINTELORG/Nucleor
cd Nucleor

# Windows:
.\tools\verify.ps1

# Linux / macOS (POSIX gate ships in v0.2; native Linux/macOS
# bin/nucleor binaries land in v0.3.0):
./tools/verify.sh
```

Verify gate green (203 steps as of v0.2.91, grew from 101 at
v0.1.8 through CLI surface coverage, JSON smoke, mojibake check,
and other audit-pattern hardening) means your environment is
ready.

## Code organization

```
Nucleor/
├── bin/                    Pre-built nucleor.exe + nucleor_tools.exe
├── compiler/               Self-hosted compiler source (.nr)
│   └── nucleor_s1_compiler.nr     The whole compiler in one file
├── stdlib/
│   ├── rods/              .nr wrappers (the user-visible stdlib)
│   └── runtime/           C runtime backing the rods
├── tests/                 Verify-gate corpus
│   ├── lang/              Language-feature positive tests
│   ├── attrs/             Attribute tests
│   ├── runtime/           Runtime tests
│   ├── rods/              Rod-specific tests
│   ├── features/          Ported V1 feature tests
│   └── err/               Negative tests
├── examples/              Showcase programs
├── docs/
│   ├── rfcs/              Design RFCs (RFC-0001 through RFC-0032)
│   └── process/           Process docs (this file, semver, etc.)
├── tools/
│   ├── verify.ps1         Verify gate (Windows)
│   └── verify.sh          Verify gate (POSIX, post-v0.2)
└── CHANGELOG.md
```

## Building from source

The compiler is **self-hosted**: `bin/nucleor.exe` rebuilds itself
from `compiler/nucleor_s1_compiler.nr`. To make a compiler change:

1. Edit `compiler/nucleor_s1_compiler.nr`.
2. Run `nuc build compiler/nucleor_s1_compiler.nr -o nucleor_new`.
3. Test the new compiler by replacing `bin/nucleor.exe`.
4. Re-run `verify.ps1` with the new compiler.

Self-host fixed-point: the new compiler must be byte-identical to a
compiler built by itself. Verify this with the self-host loop in
`verify.ps1` (the final "self-host rebuild closes" step). For a
stronger 2-iteration fixed-point check, see the recipe in
[`NUCLEOR_BOOTSTRAP_CONTRACT.md`](../../NUCLEOR_BOOTSTRAP_CONTRACT.md)
(used for v0.2.84 and v0.2.87 compiler source changes — both
preserved byte-identical IR across iterations).

## Filing issues

Use GitHub Issues. Please include:
- Nucleor version (`nuc version`)
- Platform (OS, arch)
- Minimal reproduction code
- Expected vs actual behavior

For compiler crashes, attach the LLVM IR if available
(`nuc build --emit=ll`).

## Submitting PRs

1. Fork + branch.
2. Make the change. Keep PRs focused — one logical change per PR.
3. Run `verify.ps1` (or `verify.sh`); ensure green.
4. Add tests for new functionality (`tests/lang/`, `tests/features/`,
   etc.).
5. Update CHANGELOG.md under "Unreleased".
6. Open the PR with a description of what + why.

CI runs the verify gate on Windows x86_64 today (the v0.2 target).
Linux + macOS + Windows ARM matrix lands with the v0.3.0 cross-
build (see [`docs/milestones/v0.3.0.md`](../milestones/v0.3.0.md)).
PRs that don't pass CI cannot merge.

## RFC process

Major changes (new language features, breaking changes, large
runtime additions) require an RFC. See `docs/rfcs/README.md` for the
template.

RFC review takes 1–4 weeks. Once accepted, implementation can
proceed. RFCs that don't get accepted within ~6 months are closed
and may be reopened later.

## Testing

| Test type | Where | Run via |
|---|---|---|
| Language positive | `tests/lang/` | `verify.ps1` |
| Attribute | `tests/attrs/` | `verify.ps1` |
| Runtime | `tests/runtime/` | `verify.ps1` |
| Rod | `tests/rods/` | `verify.ps1` |
| Feature (V1 ports) | `tests/features/` | `verify.ps1` |
| Negative | `tests/err/` | `verify.ps1` |
| Quarantined | `tests/{err,features}/_unimplemented/` | manual |

After RFC-0021 (test framework, v0.2): use `nuc test` instead of
`verify.ps1` for most cases.

## Coding style

- Format: `nuc fmt` (post v0.4 when fmt ships; for now follow
  surrounding code).
- Naming: `snake_case` for fns/vars, `UpperCamelCase` for types,
  `SCREAMING_SNAKE` for consts.
- Comments: prefer no comment unless the WHY is non-obvious.
- Tests: name like the thing they test (`add_works`, `index_panics_on_oob`).

## Code of Conduct

Be excellent to each other. Standard contributor covenant applies.
File CoC issues to coc@nucleor.dev.

## License

Apache 2.0. By contributing, you agree your work is licensed under
Apache 2.0.
