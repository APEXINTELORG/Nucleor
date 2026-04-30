# Findings — probe agent's inbox + history

This directory is owned end-to-end by the **probe + fix agent**
(see `PARALLEL_AGENT_PROBE_MANDATE.md`). The main agent never reads
`inbox/`; it stays on the v0.4 / v0.5 punchlist.

## Layout

```
findings/
  inbox/         <-- probe agent drops new findings here while working
  promoted/      <-- probe agent moves findings here after shipping the fix
  README.md      <-- this file
  _heartbeat.md  <-- probe agent overwrites each rebase (alive/version/sha)
  _template.md   <-- copy this when filing a new finding
```

## Contract (one-page)

### Probe agent (sole owner)
- Drops one file per finding in `inbox/` named
  `YYYY-MM-DD-<slug>.md` with the frontmatter format in
  `_template.md` (incl. `discovered_against:` and `commit:`).
- Reproduces, writes a fixture, fixes the compiler, runs all gates,
  ships `v0.4.NNN`, then **moves** the file from `inbox/` to
  `promoted/`, appending the footer:

  ```markdown
  ---
  ## Promoted

  - Fixture: `tests/err/<file>.nr`
  - Fix shipped: v0.4.NNN (commit <sha>)
  - Promoted: YYYY-MM-DD by probe agent
  ```

- If a finding turns out to be already-fixed / non-bug / dup, moves
  it to `promoted/` with `Promoted: rejected — <reason>` instead.
  Rejection still moves the file — the inbox stays clean.
- If a finding is too deep to fix in a single ship, **leaves it in
  `inbox/`** with a `## Stuck` section naming what blocked. Keeps
  probing.

### Main agent
- Reads `promoted/` only as a historical record of closed bug
  classes (optional context).
- Does NOT read `inbox/`, does NOT move files, does NOT promote.
- May read `_heartbeat.md` to confirm probe agent is alive.

### Severity priority

Probe agent fixes findings in this order. Within a tier, prefer the
cheapest fix (smallest patch) first — small ships beat big ones.

| Severity | Why it leads |
|---|---|
| compiler-meltdown | compiler itself OOMs / hangs / produces no output. Probe agent stops probing the offending main commit and fixes immediately. |
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
