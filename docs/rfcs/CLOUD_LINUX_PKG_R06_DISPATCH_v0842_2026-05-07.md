# Cloud Linux dispatch v0842 - PKG-1 / R06 native proof

Audience: cloud/Linux agent only
Base: fetch current `origin/main`
Mode: true native Linux proof, minimal patches only, push branch, write report

This lane requires real Linux. Do not use WSL, Wine, Windows `.exe` artifacts,
or copied Windows binaries as proof. Do not edit Windows/compiler semantics,
R05, ROBO-7, RFC-0063, laws, units, or quantum lanes. No Python helpers.

## Queue 1 - PKG-1 Native Signed Publish Proof

Branch:

```text
fix/cloud-linux-pkg1-signed-publish-v0842
```

Start:

```bash
git fetch origin
git checkout -B fix/cloud-linux-pkg1-signed-publish-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
uname -a
```

Goal:

- Close PKG-1 with a native Linux transcript for `nuc publish --sign` against a
  throwaway registry/key.
- If publish signing is blocked, produce the exact blocker plus smallest patch
  needed to make the path deterministic.

Required evidence:

```bash
command -v clang || true
command -v ssh-keygen || true
command -v pwsh || true
./bin/nucleor --version || true
./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml --registry /tmp/nucleor-pkg1-v0842-registry --dry-run
```

Then run the real signed publish command appropriate to the current CLI surface
using a throwaway key and registry. Include the exact command and output.

Deliverable:

```text
findings/inbox/cloud_linux_pkg1_signed_publish_v0842_2026-05-07.md
```

Include branch, HEAD, base, merge-base, `uname -a`, tool versions, exact
commands, pass/fail output, patches if any, and residual blockers.

## Queue 2 - R06 POSIX rust_bridge Ownership Proof

Start this only after Queue 1 is pushed or explicitly blocked. Fetch current
`origin/main` and start a fresh branch.

Branch:

```text
fix/cloud-linux-r06-rust-bridge-proof-v0842
```

Start:

```bash
git fetch origin
git checkout -B fix/cloud-linux-r06-rust-bridge-proof-v0842 origin/main
git status --short --branch
git merge-base HEAD origin/main
uname -a
```

Goal:

- Run the POSIX side of the rust_bridge ownership harness on real Linux.
- Produce repeat evidence for all Rust string-returning bridge functions and
  `rust_free_str` ownership behavior.

Required survey:

```text
tools/check_rust_bridge_ownership.ps1
tools/check_rust_bridge_ownership.sh
stdlib/rods/rust.nr
stdlib/runtime/rust_bridge*
findings/inbox/helper2_r06_rust_bridge_ownership_harness_v0828_2026-05-06.md
```

Run the current POSIX harness exactly as documented. If prerequisites are
missing, install none silently; report the missing tool and provide the smallest
repo patch or docs correction needed.

Deliverable:

```text
findings/inbox/cloud_linux_r06_rust_bridge_proof_v0842_2026-05-07.md
```

Include branch, HEAD, base, merge-base, `uname -a`, tool versions, exact
commands, output, leak/ownership signal if available, and remaining R06 gaps.
