# RFC-0019 — Package Manager: `nuc.toml`, registry, resolver

| Field | Value |
|---|---|
| **Number** | 0019 |
| **Title** | Package manager — `nuc.toml`, lockfile, semver resolver, registry |
| **Status** | Implemented (partial) v0.1.33–v0.1.55 — see `docs/milestones/v0.2.0.md`; v0.2 DoD met (manifest, lockfile, install, workspace); registry / PubGrub / git deferred to v0.5.0 |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2.0 (manifest+resolver) → v0.5.0 (registry MVP) |
| **Depends on** | RFC-0018 (modules) |

---

## 1. Summary

Ship a Cargo-equivalent package manager: per-project `nuc.toml`,
a `nuc.lock` lockfile, a semver-based resolver, and a static-files
registry hosted on GitHub Pages.

```toml
# nuc.toml
[package]
name    = "my_robot"
version = "0.3.1"
edition = "2026"

[dependencies]
nucleor-ros2     = "1.2"
nucleor-mujoco   = "1.0"
serde            = { version = "1.5", features = ["derive"] }
my-private-lib   = { git = "https://github.com/me/lib", tag = "v2.0" }
local-experiment = { path = "../experiment" }

[dev-dependencies]
nucleor-proptest = "0.4"

[features]
default     = ["sim"]
sim         = ["nucleor-mujoco"]
hardware    = ["nucleor-franka"]

[profile.release]
opt-level = 3
```

```bash
nuc add toml@1.0
nuc remove serde
nuc update
nuc build --features hardware
nuc test
nuc publish
```

---

## 2. Motivation

Without a package manager: no shared libraries, no community, no
users. Single biggest blocker after numerics + Result.

Prior art: Cargo (Rust), npm (JS), pip+PyPI (Python), go modules.
**Cargo is the gold standard** — copy it.

---

## 3. Design

### 3.1 `nuc.toml`

Sections: `[package]`, `[dependencies]`, `[dev-dependencies]`,
`[build-dependencies]`, `[features]`, `[profile.*]`, `[bin]`,
`[lib]`, `[workspace]`, `[cxx]` (RFC-0011), `[bindgen]` (RFC-0012),
`[wcet]` (RFC-0009).

Mirror Cargo schema as closely as makes sense. Documented at
`docs/nuc-toml-spec.md`.

### 3.2 Dependency types

```toml
[dependencies]
foo = "1.2.3"                            # caret (>= 1.2.3, < 2.0.0)
bar = "=1.2.3"                           # exact
baz = ">=1.0, <2.0"                      # range
qux = { version = "1.0", features = ["x"] }
git = { git = "https://...", branch = "main" }
git_tag = { git = "https://...", tag = "v1.0" }
git_rev = { git = "https://...", rev = "abc123" }
local = { path = "../sibling" }
```

### 3.3 Semver resolver

Standard semver. Algorithm: PubGrub (used by Dart pub, modern
resolver design — better diagnostics than Cargo's older resolver).

### 3.4 Lockfile

`nuc.lock` records exact resolved versions + hashes:

```toml
version = 1

[[package]]
name = "nucleor-ros2"
version = "1.2.4"
source = "registry+https://nucleor.dev/registry/"
checksum = "sha256:abc..."
dependencies = ["nucleor-cdr 1.0.1"]

[[package]]
name = "nucleor-cdr"
version = "1.0.1"
source = "registry+https://nucleor.dev/registry/"
checksum = "sha256:def..."
```

Committed to source control. Reproducible builds.

### 3.5 Registry

**MVP:** static files on GitHub Pages.
- `index/<crate>` → JSON of all known versions, deps, hashes
- `crates/<crate>/<version>/<crate>-<version>.tar.gz` → source tarball
- Mirrored to S3 for durability

**Auth:** GitHub OAuth for publishing. No registration server v0.5.

**v0.7+:** maybe a real registry server with namespaces, reviews,
yank/unyank. Decide based on adoption.

### 3.6 CLI

```
nuc new <name>           Create new project
nuc init                 Init in current dir
nuc add <pkg>[@ver]      Add dep
nuc remove <pkg>         Remove dep
nuc update [<pkg>]       Update lockfile
nuc build [--release]    Build
nuc test                 Run tests
nuc check                Type-check only
nuc fmt                  Format
nuc doc                  Generate docs (RFC-0029)
nuc publish              Publish to registry
nuc search <query>       Search registry
nuc tree                 Print dep tree
nuc clean                Remove build artifacts
```

### 3.7 Workspace support

Multi-crate projects:

```toml
# top-level nuc.toml
[workspace]
members = ["crates/parser", "crates/codegen", "crates/cli"]
```

Each member has its own `nuc.toml`. Shared `nuc.lock` at workspace
root.

### 3.8 Features

Conditional compilation via `cfg(feature = "x")`. Standard.

### 3.9 Build profiles

```toml
[profile.dev]
opt-level = 0
debug     = true

[profile.release]
opt-level = 3
lto       = true

[profile.embedded]   # custom
opt-level = "s"
panic     = "abort"
strip     = true
```

Profiles plug into `--profile=<name>` build flag.

### 3.10 Diagnostics

| Code | Meaning |
|---|---|
| PKG-001 | Manifest schema error |
| PKG-002 | Version conflict — no resolution found |
| PKG-003 | Checksum mismatch (lockfile vs downloaded) |
| PKG-004 | Network error fetching package |
| PKG-005 | Unknown package / version |
| PKG-006 | Yanked version explicitly required |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| `nuc-pkg` binary (resolver, fetcher, builder coordinator) | New | ~3000 |
| TOML parser rod | `stdlib/rods/toml.nr` | ~600 |
| HTTP fetcher rod | `stdlib/rods/http.nr` | ~400 |
| Tarball + sha256 rods | `stdlib/rods/tar.nr`, `sha2.nr` | ~600 |
| `nuc` CLI integration | New subcommands | ~400 |
| Diagnostics | PKG-001…006 | ~200 |
| **Total** | | **~5200** |

Plus the registry infrastructure (separate repo).

### 4.1 Phasing

**v0.2:** manifest format + resolver + path/git deps. **No registry.**
Users can use git deps for v0.2.

**v0.5:** registry MVP via GitHub Pages.

**v0.7+:** maybe a real server with namespaces.

---

## 5. Alternatives considered

- **No package manager** — blocks ecosystem.
- **Run on top of npm/Cargo** — silly.
- **Centralized server from day one** — operational burden.
  GitHub-Pages-as-registry is enough for v0.5.
- **Use Cargo registry** — license/TOS issues; we're not Rust.

## 6. Open questions

1. Naming convention — `nucleor-ros2` vs `ros2-nuc`? Recommend
   `nucleor-` prefix for stdlib-adjacent packages.
2. Yanked packages handling — Cargo's "yank" semantics; recommend.
3. License-required field in manifest? Yes — ship `license = "..."`.
4. Crate-namespacing (`@org/pkg`-style)? Defer to v0.7.
5. Optional features without rebuilding world — Cargo's feature
   unification rules; copy.

## 7. Definition of done

- [ ] `nuc.toml` parses and validates per schema
- [ ] PubGrub resolver produces correct lockfile
- [ ] git/path/registry source types work
- [ ] All CLI commands functional
- [ ] Workspace support works
- [ ] CHANGELOG documents

## 8. Future extensions

- Vendoring (`nuc vendor`)
- Workspace inheritance of dep versions
- `cargo-edit`-style commands ported (`nuc upgrade`, etc.)
- Audit / vulnerability scanning (`nuc audit`)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~5200 fits 6+ weeks
- [ ] Phase 1 (manifest + git deps) in v0.2; phase 2 (registry) v0.5
