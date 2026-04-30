# Findings — probe-agent inbox

This directory is the handoff surface between the **probe agent**
(see `PARALLEL_AGENT_PROBE_MANDATE.md`) and the **main agent**
(running v0.4 closeout / v0.5 punchlist).

## Layout

```
findings/
  inbox/         <-- probe agent drops new findings here
  promoted/      <-- main agent moves findings here after fixturing + fixing
  README.md      <-- this file
```

## Contract (one-page)

### Probe agent
- Drops one file per finding in `inbox/` named
  `YYYY-MM-DD-<slug>.md` with the frontmatter format described in
  `PARALLEL_AGENT_PROBE_MANDATE.md`.
- Never moves or deletes files. Never edits files in `promoted/`.
- May leave open questions for the main agent in
  `inbox/_questions.md` — append-only.

### Main agent
- Reads `inbox/` between every ship.
- For each finding, in priority order
  (`silent-miscompute > crash > wrong-error > missing-error`):
  1. Reproduces locally against current main.
  2. Writes a permanent fixture in `tests/err/` /
     `tests/features/` / `tests/fixtures/`.
  3. Fixes the root cause in `compiler/*.nr` (mirroring tools_suite
     when the dispatch is shared).
  4. Ships as its own micro-version.
  5. **Moves** the finding file from `inbox/` to `promoted/`,
     appending a footer:

     ```markdown
     ---
     ## Promoted

     - Fixture: `tests/err/<file>.nr`
     - Fix shipped: v0.4.NNN (commit <sha>)
     - Promoted: YYYY-MM-DD by main agent
     ```

- If a finding turns out to be a duplicate or non-bug, moves it to
  `promoted/` with a `Promoted: rejected — <reason>` footer instead.
  Rejection is not silent; the file still moves so the inbox stays
  empty between sweeps.

### Severity priority

| Severity | Why it leads |
|---|---|
| compiler-meltdown | compiler OOMs / hangs / produces no output — main agent shipped a regression that's actively unusable; jumps to TOP regardless |
| silent-miscompute | program runs, output is wrong, no user signal — worst possible failure mode |
| crash | program runs, then SIGSEGV/abort with no diagnostic; or runtime hangs past timeout |
| wrong-error | diagnostic fires but with wrong code/message — misleads users |
| missing-error | should reject at compile-time but doesn't; runtime may still do the right thing accidentally |

Within a severity tier, age in the inbox breaks ties.

## Why this directory exists in source control

The findings directory is checked in deliberately. This means:

- The probe agent's findings are visible to anyone reading the repo.
- Promoted findings stay searchable as a historical record of "what
  silent-miscomputes did we close, and what was the original
  symptom" — useful for retro / paper / postmortem material.
- The directory is **excluded from the verify suite**. Verify runs
  what's in `tests/`, not what's in `findings/`. So this directory
  has no test-time cost.
