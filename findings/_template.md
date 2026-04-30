---
title: <one-line summary>
severity: compiler-meltdown|silent-miscompute|crash|wrong-error|missing-error
probe_file: probes/<theme>/<name>.nr
diagnostic_actual: <code emitted, or "none">
diagnostic_expected: <code that should fire, or "n/a">
discovered_against: v0.4.NNN
commit: <git rev-parse HEAD>
---

## Repro

```nr
// minimal .nr program, 5–15 lines
```

## Actual

What the compiler does today. Output / exit code if relevant.

## Expected

What the spec / common sense says should happen.

## Suspected location

(Optional. Skip unless obvious.)
