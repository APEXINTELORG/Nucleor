# Probe-agent CHANGELOG queue

Probe agent appends proposed CHANGELOG entries to this file at
ship-prep time. Main agent splices them into the canonical
`CHANGELOG.md` at integration time, rewriting the unreleased
header to a versioned + dated one.

This file is the handoff surface for narrative content; the actual
changelog lives in `CHANGELOG.md`. After integration, the entry
moves; this file empties.

Format for each entry:

```markdown
## [unreleased — probe agent proposal — <slug>] — yyyy-mm-dd

<one-line headline matching the bug class closed>

<description, repro, before/after, operating notes>

Verify: <PASS>/<FAIL>.
Perf: cold <s> | hot <s> | peak <MB> (3× variance noted in heartbeat).
```

Multiple proposals stack newest-on-top. Main agent splices in
order, assigning sequential v0.4.NNN versions.

---

<!-- (no proposals queued) -->
