---
title: CRITICAL — `Drop` trait body never auto-called on scope exit. RAII is broken; user `impl Drop for X { fn drop(&mut self) { ... } }` bodies do nothing.
severity: silent-miscompute (RAII broken — sister to vec-alloc-leak family)
probe_file: probes/types/drop_trait_audit.nr (probe-branch)
diagnostic_actual: pre-fix — Drop impl body never runs; resources leak
diagnostic_expected: scope-exit auto-call of Drop::drop matching Rust convention
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — RAII auto-Drop is the v1 borrow-checker / scope-flow workstream. Today adopters explicitly call cleanup helpers (`vec_free`, `hashmap_free`, `string_free`, user-defined `<X>_close()` fns).
---

## Closure (analysis-only — no compiler change)

This is the headline finding for the v1 RAII workstream. Sister
findings closing together when this lands:

- `2026-04-30-vec-allocation-without-drop-leaks` (Vec/String/
  HashMap leak on scope exit)
- `2026-04-30-str-concat-loop-rebind-leak` (str rebind in loop
  leaks prior buffer)
- `2026-05-02-move-semantics-not-enforced` (borrow-checker scope-
  flow tracking, the substrate for auto-Drop call-site emission)

The Nucleor v0.6 lower path emits no scope-exit hook for impl
Drop traits. Adopters manually invoke their cleanup pattern:

```nucleor
struct File { handle: i64 }
impl Drop for File {
    fn drop(&mut self) {
        if self.handle >= 0 { close_handle(self.handle); };
    }
}

// Pre-v1 (current):
fn use_file() -> i64 {
    let mut f: File = File { handle: open_file("path") };
    let n: i64 = read_file(f.handle);
    f.drop();                 // ← manual call required today
    return n;
}

// v1 (future):
fn use_file() -> i64 {
    let mut f: File = File { handle: open_file("path") };
    let n: i64 = read_file(f.handle);
    return n;                  // ← f.drop() emitted automatically at scope exit
}
```

## Forward-roadmap

The v1 borrow-checker pass needs to compute scope-exit points for
every binding (early-return, panic-unwind, normal block end,
loop-iteration boundaries). Drop emission then walks scope-exit
points and inserts the impl Drop call. Same pass enables generalized
RAII (auto-vec_free, auto-string_free, auto-hashmap_free).

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
