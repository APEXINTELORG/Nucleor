# bin/

Pre-built compiler binaries that ship with the repo.

## What belongs here

Exactly **one** file is committed in `bin/`:

- **`bin/nucleor.exe`** — the Windows x86_64 self-hosted compiler
  binary. Identifies as `Nucleor Compiler 0.2.0-v2` and rebuilds
  itself from `compiler/nucleor_s1_compiler.nr` on every verify
  gate run.

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
