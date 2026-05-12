# Security Policy

## Supported Versions

Nucleor follows a single supported release line. Security fixes target the
latest public v1 release.

| Version | Supported |
|---|---|
| 1.1.x | Yes |
| 1.0.x | Critical fixes only during the v1.1 transition |
| < 1.0 | No |

## Reporting A Vulnerability

Please do not open a public issue for a security vulnerability. Use GitHub
Security Advisories for this repository:

https://github.com/APEXINTELORG/Nucleor/security/advisories/new

Include:

- A clear description of the issue and expected impact.
- A minimal `.nr` reproducer or command sequence.
- Nucleor version and host OS.
- LLVM version.
- Any known mitigation.

We aim to acknowledge reports within 3 business days and provide an initial
assessment within 7 days.

## Scope

In scope:

- The self-hosted compiler.
- The runtime C files under `stdlib/runtime/`.
- The standard-library rods under `stdlib/rods/`.
- Bootstrap, launcher, package, and verification tooling.

Out of scope:

- Running untrusted Nucleor source as if it were sandboxed. Nucleor does not
  currently sandbox compilation or program execution.
- Resource exhaustion from intentionally pathological local inputs unless it
  bypasses an existing release gate or host safety cap.

## Disclosure

We follow coordinated disclosure. After a fix ships, we will publish advisory
details and credit the reporter unless they prefer anonymity.
