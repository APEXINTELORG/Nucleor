# Cloud Claude Continuation v0840: Linux-Only Lane

Audience: cloud Claude running on a true Linux host.

Branch:

```text
fix/cloud-claude-linux-only-v0840
```

Start:

```bash
git fetch origin
git checkout -B fix/cloud-claude-linux-only-v0840 origin/main
git status --short --branch
git merge-base HEAD origin/main
uname -a
```

## Goal

Keep cloud Claude focused on Linux-only proof and Linux environment closure.
Do not take Windows/compiler semantics work. Do not take R05 effects,
ROBO-7 frame diagnostics, RFC-0063 helper dedup, or local package-signing
Windows smoke work.

## Allowed Scope

Pick the highest-value Linux-only slice that is still open:

- Native Linux cold/hot perf proof after `dc61411a`.
- Linux bootstrap/fixed-point blocker diagnosis, including exact command
  output and whether the stale seed is the only blocker.
- Native Linux package publish regression proof after `dc61411a`.
- POSIX `rust_bridge` ownership harness repeat proof after `dc61411a`.
- Linux environment prerequisite documentation for `pwsh`, `ssh-keygen`,
  `clang`, `cargo`, and native `bin/nucleor`.

Small Linux-only script/docs fixes are allowed if they are directly required by
the proof. Broad compiler changes are not allowed in this lane.

## Validation

Use true native Linux evidence only. Do not use WSL, Wine, Windows `.exe`
binaries, or copied Windows artifacts as POSIX proof.

Useful command set:

```bash
file bin/nucleor || true
./bin/nucleor --version
bash tools/check_compiler_drift.sh
pwsh -NoProfile -File tools/check_perf_regression.ps1
bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
```

For package proof, use a throwaway registry and throwaway signing key. Confirm
dry-run signed publish writes no signature and real signed publish writes and
verifies `Nucleor.publish.signature.json`.

## Deliverable

Push the branch and write:

```text
findings/inbox/cloud_claude_linux_only_v0840_2026-05-06.md
```

The report must include branch, HEAD, merge-base, `uname -a`, tool paths and
versions, exact commands, exact pass/fail outputs, any patch files changed, and
remaining Linux-only blockers.
