# Maintainer Release Workflow

This document codifies the two-repo workflow used to develop and ship Nucleor.
It is maintainer-facing — contributors only need [CONTRIBUTING.md](../CONTRIBUTING.md).

## The two-repo split

| Repo | Visibility | Purpose | Branches | Tags |
|------|-----------|---------|----------|------|
| `APEXINTELORG/Nucleor` (public) | public | release branch only | `main` | release tags only (`v1.0.0`, `v1.0.1`, …) |
| `APEXINTELORG/Nucleor-archive` (private) | private | full development repo | all spike / cloud-agent / experimental branches | full historical tag set |

**Rule of thumb:** if a piece of work is not yet polished enough to be a public release, it does not belong on the public repo. All iteration — including failed experiments, cloud-agent branches, and intermediate tags — lives on the archive.

## Local clone setup

A working clone has two remotes:

```
origin → https://github.com/APEXINTELORG/Nucleor-archive.git   (default push)
public → https://github.com/APEXINTELORG/Nucleor.git           (release-only)
```

Plus this config so `main` always pushes to the public repo and everything else defaults to the archive:

```
git config remote.pushDefault origin
git config branch.main.pushRemote public
git branch --set-upstream-to=public/main main
```

`git push` while on a feature branch goes to the archive. `git push` while on `main` goes to the public repo. This makes accidentally publishing experimental branches structurally impossible.

## Day-to-day development

1. Branch off `main` (or off another archive branch) — work happens locally.
2. Push the topic branch to `origin` (archive). Cloud agents, CI, and review all happen there.
3. Tag intermediate snapshots on the archive freely; they're private.
4. Iterate until the change is ready to ship.

## Promotion to public (release)

When a change (or a batch of changes) is ready to be promoted from archive to public:

1. **Land the polished change on local `main`.** Either fast-forward a green archive branch, cherry-pick the relevant commits, or squash-merge — whichever produces the cleanest single commit on `main`.

2. **Bump the version label** in both compilers:
   - `compiler/nucleor_s1_compiler.nr`
   - `compiler/nucleor_tools_suite.nr`

   Choose the bump per the change scope:
   - `1.0.0` → `1.0.1` for a bug fix or polish-only change
   - `1.0.x` → `1.1.0` for new user-visible feature work
   - `1.x.y` → `2.0.0` only for breaking changes (post-v1 we should avoid these)

3. **Add a CHANGELOG entry** under a new `## [<new-version>] — <date>` block. Keep entries factual and short — what changed, what was fixed, what's still deferred.

4. **Run the full verify gate:**
   ```
   bash tools/verify.sh
   ```
   Must end PASS=<n> SKIP=<n> FAIL=0. Any failure aborts the promotion — fix on the archive side, not by editing the release commit.

5. **Regenerate seed + bin:**
   ```
   bash tools/regen_seed.sh        # if compiler/*.nr changed
   bash tools/regen_bin.sh         # if compiler/*.nr changed
   ```
   Commit the regenerated `bootstrap/nucleor_s1_seed.ll` and `bin/nucleor.exe` as part of the release commit (or as the immediately preceding commit).

6. **Tag and push to public:**
   ```
   git tag -a v<new-version> -m "v<new-version>"
   git push public main
   git push public v<new-version>
   ```
   `main` pushes to public because of the per-branch `pushRemote = public` setting. The tag push is explicit.

7. **Mirror the release commit to the archive** so the two repos stay in sync at release boundaries:
   ```
   git push origin main
   git push origin v<new-version>
   ```

## Drift gates

The verify suite includes drift gates that enforce internal consistency. The release-relevant ones:

- **CHANGELOG ↔ tag** — most-recent CHANGELOG version must equal the most-recent tag
- **version-label ↔ CHANGELOG** — `compiler_version_label` in s1 + tools-suite must equal the most-recent CHANGELOG version
- **parser-fn parity** — s1 and tools-suite parsers must enumerate the same function set
- **helper / rod manifest** — every helper rod ABI symbol referenced by the runtime must exist; every shipped rod must be listed

If a release fails one of these, fix the underlying drift — never bypass the gate.

## What does NOT get promoted

Things to keep on the archive only:

- Cloud-agent coordination files (`Cloud_Control1.md`, `CLOUD_AGENT_*_BRIEF*.md`, `findings/inbox/*`)
- Probe-mode artifacts and experimental branches
- Intermediate `v0.x.y` tags from pre-v1.0 development
- WIP RFCs that haven't been accepted

If any of these accidentally land on local `main`, drop them before promoting. The public repo's history should read as a clean sequence of release commits, not a development log.

## Recovery

The full pre-v1.0 history is preserved in three places:

- `APEXINTELORG/Nucleor-archive` (private GitHub repo, browseable)
- `Desktop/Nucleor_PreV1Cleanup_Backup_2026-05-08/nucleor-mirror.git` (local bare clone)
- `Desktop/Nucleor_PreV1Cleanup_Backup_2026-05-08/nucleor-all-refs-2026-05-08.bundle` (single-file bundle, 206 MB)

Any branch or tag can be restored to either repo by pushing from the archive or unbundling the local file.
