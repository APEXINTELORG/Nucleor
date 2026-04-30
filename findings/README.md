# Findings — probe agent's inbox + integration queue + history

This directory is owned end-to-end by the **probe + prep agent**
(see `PARALLEL_AGENT_PROBE_MANDATE.md`). The main agent reads
`staged/` at integration time and `promoted/` for context; it
never reads `inbox/`.

## Layout

```
findings/
  inbox/         <-- probe agent drops NEW findings here during probing
  staged/        <-- probe agent moves findings here once gates are green
                     and the prep is ready for main-agent integration
  promoted/      <-- main agent moves findings here at integration with
                     the v0.4.NNN ship version filled in
  README.md      <-- this file
  _heartbeat.md  <-- probe agent overwrites each rebase + per-ship-prep
                     (alive / current commit / verify counts / perf 3x /
                      ready-for-integration list)
  _template.md   <-- copy this when filing a new finding
```

## Contract (one-page)

### Probe agent (owns inbox/ + staged/)
- Drops one file per finding in `inbox/` named
  `YYYY-MM-DD-<slug>.md` with the frontmatter format in
  `_template.md` (incl. `discovered_against:` and `commit:`).
- When a finding's fix is prepped (compiler + fixture + all gates
  green on `probe/exploration`), MOVES the inbox file to
  `staged/<slug>.md` with footer:

  ```markdown
  ---
  ## Staged for promotion

  - Fixture: `tests/<dir>/<file>.nr`
  - Fix shipped: <pending — main agent fills v0.4.NNN at integration>
  - Staged: YYYY-MM-DD by probe agent
  ```

- If a finding turns out to be already-fixed / non-bug / dup, moves
  it to `staged/` with `Staged: rejected — <reason>` instead.
  Rejection still moves the file — the inbox stays clean.
- If a finding is too deep to fix, **leaves it in `inbox/`** with
  a `## Stuck` section. Keeps probing.
- **Never edits `promoted/`.** That's main-only.

### Main agent (owns promoted/ + integration)
- At each integration cycle, pulls `origin/probe/exploration`,
  reads `staged/` for queued work + `_heartbeat.md` for the
  ready-for-integration list.
- For each item in `staged/` being shipped this cycle, MOVES the
  file from `staged/` to `promoted/`, fills in the footer:

  ```markdown
  ## Promoted

  - Fixture: `tests/<dir>/<file>.nr`
  - Fix shipped: v0.4.NNN (commit <sha>)
  - Promoted: YYYY-MM-DD by main agent (from probe-agent prep)
  ```

- Splices `CHANGELOG_PROBE_QUEUE.md` entries into `CHANGELOG.md`
  with proper version + date headers.
- Tags `v0.4.NNN`, pushes `main` + tag.
- May skip a staged item if it doesn't apply to current main —
  rare; usually means the probe agent's rebase missed something.
  Files an issue back via `findings/_questions.md`.

### Severity priority

Probe agent picks findings in this order. Within a tier, prefer the
cheapest fix (smallest patch) first — small ships beat big ones.

| Severity | Why it leads |
|---|---|
| compiler-meltdown | compiler itself OOMs / hangs / SIGSEGVs. Probe agent stops probing the offending main commit and preps the fix immediately. |
| silent-miscompute | program runs, output is wrong, no user signal — worst failure mode |
| crash | program runs, then SIGSEGV/abort with no diagnostic; or runtime hangs past timeout |
| wrong-error | diagnostic fires but with wrong code/message — misleads users |
| missing-error | should reject at compile-time but doesn't; runtime may still do the right thing accidentally |

## Why this directory exists in source control

The findings directory is checked in deliberately. This means:

- The probe agent's findings are visible to anyone reading the repo.
- Promoted findings stay searchable as a historical record of "what
  silent-miscomputes did we close, and what was the original
  symptom" — useful for retro / paper / postmortem material.
- The directory is **excluded from the verify suite**. Verify runs
  what's in `tests/`, not what's in `findings/`. So this directory
  has no test-time cost.
