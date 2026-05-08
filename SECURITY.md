# Security Policy

## Supported Versions

Nucleor follows a single-track semver model. Only the latest released
version receives security updates.

| Version  | Supported          |
| -------- | ------------------ |
| 1.0.x    | :white_check_mark: |
| 0.8.x    | :white_check_mark: |
| < 0.8    | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Nucleor, please **do not
open a public GitHub issue**. Instead, report it privately so we can
investigate and ship a fix before details are disclosed.

**Contact:** open a [GitHub Security Advisory](https://github.com/APEXINTELORG/Nucleor/security/advisories/new)
on the repository, or email the maintainer directly via the address
listed in the repository's organization profile.

Please include:

- A description of the vulnerability and the impact you believe it has
- A minimal reproducer (a `.nr` file, a command line, or a sequence of
  steps) — small reproducers ship faster
- The Nucleor version (`bin/nucleor.exe --version`) and the host OS
- Any mitigation you've already identified

We aim to:

- Acknowledge receipt within **3 business days**
- Provide a preliminary assessment (severity, scope) within **7 days**
- Ship a fix within **30 days** for critical issues, longer for
  lower-severity items where a workaround exists

## Scope

In scope:

- The `nucleor` compiler (`compiler/nucleor_s1_compiler.nr`,
  `compiler/nucleor_tools_suite.nr`)
- The runtime (`stdlib/runtime/nucleor_llvm_rt.c` and the per-feature
  `*_rt.c` files under `stdlib/runtime/`)
- The standard library rods (`stdlib/rods/*.nr`)
- The build / verification toolchain (`tools/`)

Out of scope:

- Bugs that require running malicious Nucleor source code at compile
  time on a developer machine — Nucleor does not currently sandbox the
  compile process and we recommend treating untrusted `.nr` sources
  the same way you'd treat untrusted Python or Ruby code (review
  before compiling)
- Memory exhaustion via pathological compile inputs — see the
  `MEMORY_FIX_PUNCHLIST.md` track for the architectural work; the
  v0.2.161 gate enforces a 400 MB budget on the self-host but
  arbitrary user sources are not yet bounded

## Coordinated Disclosure

We follow standard 90-day coordinated disclosure. After we ship a fix,
we will publish a CVE (if applicable) and credit the reporter unless
they prefer anonymity.
