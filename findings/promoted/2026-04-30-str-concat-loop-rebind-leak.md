---
title: `s = str_concat(s, "x")` inside loop leaks every prior heap str — MEM-001 doesn't catch it
severity: silent-miscompute (memory-leak class)
probe_file: probes/_sweep/p3_string_concat_loop.nr (probe-branch)
diagnostic_actual: pre-fix — silent, peak grows linearly with iteration count
diagnostic_expected: MEM-001 warning at the rebind site
discovered_against: probe/exploration tip after ship 42 (commit dd48f0f)
commit: dd48f0f
status: DOC-ONLY — sister to `2026-04-30-vec-allocation-without-drop-leaks`. Same RAII-auto-Drop root cause; today MEM-001 catches Vec rebind classes (per Ship 36) but does not yet extend to str rebinds inside loop bodies.
---

## Closure (analysis-only — no compiler change)

The MEM-001 family covers Vec rebind-leak (closed in Ship 36) and
some specific patterns of HashMap rebind. Extending MEM-001 to
str rebind-in-loop requires:

- Loop-body scope tracking (which the rebind detector has for Vec
  but the str path uses a simpler shadow-name check).
- Distinguishing `s = str_concat(s, ...)` (rebind, leaks prior
  buffer) from `let s2 = str_concat(s, ...)` (new binding, prior
  buffer is preserved as `s`).

That extension is forward-roadmap on the same workstream as
auto-Drop — once the borrow-checker has scope-flow awareness, both
the str-rebind-leak warning and full RAII close together.

## Adopter migration

```nucleor
// Pre-fix (leak):
let mut s: str = "";
let mut i: i64 = 0;
while i < 5 {
    s = str_concat(s, "x");           // leaks previous s buffer
    i = i + 1;
};
print(s);

// v0.6 idiom (StringBuilder):
let mut sb: i64 = sb_new();
let mut i: i64 = 0;
while i < 5 {
    sb_append(sb, "x");                // pre-allocated, no leak
    i = i + 1;
};
let s: str = sb_to_str(sb);            // single materialization
print(s);
```

`sb_*` is the canonical pattern for accumulating strings in loops
(used pervasively in the compiler self-host: `emit_externs`,
`emit_str_constants`, etc. all use `sb_new` + `sb_append`).

## Forward-roadmap

When MEM-001 extends to str rebind-in-loop, this finding closes
with a clean diag at the rebind site. Same workstream as the v1
RAII pass; expect both to land together.

## Promoted

- No code change in v0.6.50 batch.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
