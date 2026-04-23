# Nucleor — SemVer and Release Process

**Last updated:** 2026-04-23 (post-v0.2.129)

## 1. Versioning policy

Nucleor uses **Semantic Versioning** (semver.org) with project-
specific clarifications below.

```
MAJOR.MINOR.PATCH

0.x.y    Pre-1.0 — breaking changes allowed at MINOR bumps
1.x.y    Stable — breaking only at MAJOR bumps
```

### 1.1 During v0.x

Breaking changes (source-incompatible) are allowed at MINOR bumps
(e.g., v0.2.0). Patch bumps (e.g., v0.2.1) are bug fixes only.

The v0.2.0 release **shipped 2026-04-22 fully backwards-compatible
with v0.1.x** despite originally being scoped as a breaking
numeric refactor (RFC-0015). The phase 5 stdlib audit and phase 7
strict-mode flip were deferred to v0.4 alongside the type-lattice
IR work, so v0.2.0 ended up additive — see
[`docs/migrations/v0.1-to-v0.2.md`](../migrations/v0.1-to-v0.2.md)
for the upgrade path. The v0.2.x sub-chain (through v0.2.129 as of
this update) has been strictly additive on top of v0.2.0; no
existing program semantics changed.

v0.3.0 (Linux/macOS bootstrap) may break programs that depend on
Windows-specific runtime quirks; **migration tools ship at every
breaking release** (`nuc fix --<topic>`).

### 1.2 At v1.0 and beyond

Breaking changes only at MAJOR bumps. Six-month deprecation window
minimum for any breaking removal.

### 1.3 What counts as breaking

- Removing or renaming a public item
- Changing a public item's signature in a non-additive way
- Changing observable behavior of a documented API
- Tightening trait bounds
- Changing the layout of a `#[repr(C)]` type
- Removing a build target tier
- Changing the wire format of a generated artifact (JSON, MCAP,
  etc.)

### 1.4 What is NOT breaking

- Adding a new public item
- Adding a new feature flag (default off)
- Bug fixes that align behavior with documentation
- Performance improvements
- Adding a default-implementation method to a trait (Rust calls this
  "minor breaking" — we follow Rust's stance)
- Loosening trait bounds
- Adding a new diagnostic

## 2. Release schedule

| Cadence | Release type |
|---|---|
| Every 6–10 weeks | MINOR (or MAJOR pre-1.0) |
| Ad-hoc | PATCH for critical bugs |

The v0.2.0 → v0.7.0 schedule (per `Nucleor_Decisions_2026-04-22.md`):

| Release | Target | Months |
|---|---|---|
| v0.2.0 | 2026-06 (shipped early on 2026-04-22) | 1–2 |
| v0.3.0 | 2026-Q3 | 3–4 |
| v0.4.0 | 2026-11 | 5–7 |
| v0.5.0 | 2027-02 | 8–10 |
| v0.6.0 | 2027-05 | 11–13 |
| v0.7.0 | 2027-09 | 14–18 |
| v0.8.0 | 2028-03 | 19–24 |

## 3. Release process

### 3.1 Pre-release (the day before)

1. Verify gate green on all Tier-1 platforms (Linux + macOS +
   Windows × Intel + ARM).
2. CHANGELOG.md updated with the new version's entry.
3. All quarantined tests reviewed; any newly-implementable moved out.
4. Migration tool tested on a corpus of v(N-1) projects.
5. Doc generation passes; new APIs documented.

### 3.2 Release day

1. Tag in git: `git tag -s v0.N.0 -m "v0.N.0"`
2. Push tag: `git push origin v0.N.0`
3. CI builds binaries for all Tier-1 platforms.
4. Upload binaries to GitHub Releases.
5. Update `nucleor.dev/install.sh` to point at new version.
6. Publish stdlib crates to the registry (post v0.5).
7. Announce: GitHub Discussions, /r/rust adjacent forums, blog post.

### 3.3 Post-release

1. Bump version in `Cargo.toml`-equivalent to `v0.N+1.0-dev`.
2. Open a tracking issue for the next release's roadmap.
3. Watch for regression reports; PATCH within a week if needed.

## 4. Release branches

Release-N maintained on `release/v0.N` branch for PATCH-only fixes.
Main branch tracks unreleased N+1 work.

A PATCH (v0.N.x where x>0) can be released without sweeping the main
branch — only the release branch is rebuilt and tagged.

## 5. Yanking

Severe bugs / security issues: yank the version from the registry.
Yanked versions remain downloadable for users with `Nucleor.lock` already
pinning them, but `nuc add` skips them.

`nuc yank --version 0.3.1 --reason "OOB write in parser"` (post v0.5
when registry exists).

## 6. Security disclosure

Vulnerabilities reported to security@nucleor.dev (post-launch).
30-day disclosure window. CVEs assigned for impactful bugs. Releases
on the affected branch within 30 days minimum.

## 7. Breaking-change RFC discipline

Any breaking change requires:
1. An RFC (per the RFC template) describing the change and migration
   path
2. The RFC accepted by maintainer before code merges
3. A migration tool (`nuc fix --<topic>`) where mechanical translation
   is possible
4. CHANGELOG entry in the **Breaking changes** section, ordered by
   severity

## 8. Deprecation policy

To remove a feature:
1. Mark `#[deprecated(since = "0.N", note = "use X instead")]` in
   release N.
2. Wait two MINOR releases (N+1, N+2) before removal.
3. Remove in N+3 with a CHANGELOG note.

Compiler warning: "deprecated; will be removed in v0.N+3".

## 9. Edition mechanism (post-1.0)

When v1.0 ships, an "edition" mechanism (mirror Rust 2018/2021/2024)
allows breaking syntax/semantics changes without breaking older
crates. Each crate declares `edition = "2027"` in `Nucleor.toml`. Crates
of different editions interoperate at the API level. Withhold for
1.0+; not relevant during v0.x.
