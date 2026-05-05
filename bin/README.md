# bin/

Pre-built compiler binaries that ship with the repo.

## What belongs here

R13-D1 Phase 1 update (v0.8.280, audit 2026-05-05): the live `bin/`
contains five committed binaries. The pre-v0.8.280 doc claimed
"exactly one file" + "Nucleor Compiler 0.2.0-v2"; actual identity
is **`nucleor 0.4.180 (self-hosted, llvm backend)`** as of
v0.8.279, with multiple support binaries shipping alongside.
(Note: the `0.4.180` build-internal version reported by the binary
predates the v0.5+ milestone tags and continues to be reported
verbatim; the canonical "current release" is the latest git tag
on `main`.)

| Artifact | Role | Class |
|---|---|---|
| `bin/nucleor.exe` | Windows x86_64 self-hosted compiler. Rebuilds itself from `compiler/nucleor_s1_compiler.nr` on every verify gate. The single load-bearing artifact. | committed, version-locked |
| `bin/nucleor_tools.exe` | Tools-suite binary built from `compiler/nucleor_tools_suite.nr`. Powers `nuc explain`, `nuc audit`, `nuc check`, etc. | committed, regenerated when tools-suite source changes |
| `bin/nucleor-lsp.exe` | V1.16 LSP server (v0.8.153). Editor-integration daemon over stdin/stdout. | committed, regenerated when LSP source changes |
| `bin/nucleor_O2.exe` | -O2 release build snapshot (April 2026 lineage). Optional perf-comparison artifact. | committed, snapshot-class — may rotate without notice |
| `bin/nucleor_s1_backup.exe` | s1 fixed-point recovery backup (April 2026 lineage). Manual fallback if the primary `nucleor.exe` self-host gate breaks mid-development. | committed, backup-class — read-only safety net |

**One-binary policy** is no longer the design — the policy is now
"one load-bearing primary (`nucleor.exe`) + intentional support
binaries with documented roles." Phase 2 may add an artifact
manifest under `bin/manifest.toml` listing each binary's
provenance, build commit, and SHA256.

When `v0.3.0` ships (Linux/macOS bootstrap — see
[`docs/milestones/v0.3.0.md`](../docs/milestones/v0.3.0.md)),
this directory will also contain:

- **`bin/nucleor`** (Linux x86_64 ELF)
- **`bin/nucleor`** (macOS arm64 Mach-O)

…possibly under platform-suffixed names depending on the
distribution policy decision in v0.3 phase 4.

## What does NOT belong here

Build scratch artifacts from local development. Specifically:

- **`bin/nucleor_vNNN.exe`** — snapshots from self-host
  fixed-point checks during a release. The chain pattern through
  the v0.2.x release line was:

  ```bash
  ./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr \
      -o bin/nucleor_vNNN.exe
  ./bin/nucleor_vNNN.exe build compiler/nucleor_s1_compiler.nr \
      -o bin/nucleor_v(NNN+1).exe
  diff -q target/nucleor_vNNN.ll target/nucleor_v(NNN+1).ll
  ```

  These should ideally be written to `target/` (which
  `.gitignore` already covers fully). Since v0.2.63 the
  `.gitignore` explicitly excludes `bin/nucleor_v*.exe` so they
  never accidentally land in a commit.

- **`bin/nucleor_tools.exe`** — the tools-suite binary built
  alongside the compiler. Also git-ignored.

If you see these files in your local `bin/` after running the
verify gate, they're safe to delete:

```bash
rm -f bin/nucleor_v*.exe bin/nucleor_tools.exe
```

## Why pre-built?

Nucleor is self-hosted: the compiler is written in Nucleor
source. Without a pre-built binary, a fresh clone has no way to
compile the compiler from scratch on first use. The committed
`bin/nucleor.exe` resolves that bootstrap chicken-and-egg via
the well-established "compiler binaries land in the repo"
pattern (cf. Rust's stage0, OCaml's `boot/`, Nim's `csources_v2`).

The bootstrap binary is **always** the result of running a
previous version of `nuc build compiler/nucleor_s1_compiler.nr`
through itself — the self-host LLVM IR fixed point is verified
on every release. See `tools/verify.sh` step "self-host rebuild
closes" and `docs/milestones/v0.2.0.md` for the full story.
