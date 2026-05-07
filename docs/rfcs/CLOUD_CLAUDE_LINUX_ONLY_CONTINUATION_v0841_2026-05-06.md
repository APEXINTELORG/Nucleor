# Cloud Claude Continuation v0841: Linux-Only Proof Lane

Audience: cloud Claude on a true native Linux host.

Branch:

```text
fix/cloud-claude-linux-only-v0841
```

Start:

```bash
git fetch origin
git checkout -B fix/cloud-claude-linux-only-v0841 origin/main
git status --short --branch
git merge-base HEAD origin/main
uname -a
```

Scope is Linux-only proof/closure work after main `34d12338`.

Out of scope:

- Windows compiler semantics.
- R05 effects.
- ROBO-7 frame diagnostics.
- RFC-0063 tools-suite duplicate deletion.
- Local package-signing Windows smoke.
- WSL, Wine, Windows `.exe` artifacts, or copied Windows binaries as proof.

## Preferred Slices

Pick the highest-value still-open Linux slice and complete it end to end.

### Slice A - Linux bootstrap fixed-point recheck

The prior Linux-only report found a stale `bootstrap/nucleor_s1_seed.ll`
blocker. Main has since regenerated the seed through ROBO-7 integration.
Re-run the native Linux bootstrap/fixed-point path from current main.

Expected commands:

```bash
which clang || true
which bash || true
which sha256sum || true
which md5sum || true
file bootstrap/nucleor_s1_seed.ll
bash tools/bootstrap_linux.sh
bash tools/check_self_host_md5.sh
./bin/nucleor --version
```

If it still fails, capture exact command, stdout/stderr, tool versions, and
whether the failure is seed mismatch, missing tool, link error, or runtime
crash.

### Slice B - PKG-1 native Linux signed publish proof

Run a real signed publish proof against a throwaway registry and throwaway key
on native Linux.

Expected evidence:

```bash
which pwsh || true
which ssh-keygen || true
which clang || true
./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml --registry "$TMPDIR/nucleor-linux-signed-registry" --sign --key <throwaway-key>
./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml --registry "$TMPDIR/nucleor-linux-signed-registry" --verify-signature
```

Use current CLI spelling if the command has changed. Do not use real user keys.
If `pwsh` or `ssh-keygen` is unavailable, document the blocker and run the
preflight/dry-run path to prove no mutation.

### Slice C - R06 POSIX rust_bridge ownership proof

Re-run the POSIX harness from current main with native Linux artifacts:

```bash
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20
bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 5 --json
```

If a Rust staticlib is missing, document the exact expected path and whether it
can be built locally from the checked-in crate without network access.

### Slice D - Linux hot perf headroom probe

Only take this after A/B/C are closed or blocked. Run the native Linux perf
gate and capture top phases / flamegraph-ready evidence without changing
Windows baselines.

```bash
bash tools/check_perf_regression.sh
./bin/nucleor build compiler/nucleor_s1_compiler.nr -o _linux_perf_timepasses --no-cache --time-passes
```

Do not raise thresholds. If hot Linux remains close to the 1.0s ceiling, report
the top suspected causes and exact measurement evidence.

## Deliverable

Write:

```text
findings/inbox/cloud_claude_linux_only_v0841_2026-05-06.md
```

Include:

- branch, HEAD, base, merge-base;
- `uname -a`;
- tool paths and versions;
- exact commands run;
- exact pass/fail outputs;
- files changed, if any;
- remaining Linux-only blockers;
- whether main needs integration, docs-only cherry-pick, or no action.

If you change code or docs, push the branch. If this is pure evidence, commit
the report only. Do not run Windows-only validation in cloud.
