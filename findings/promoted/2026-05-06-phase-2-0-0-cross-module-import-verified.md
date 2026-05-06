# Phase 2.0.0 verification: cross-module `pub fn` imports are viable at scale

**Date:** 2026-05-06
**Surfaced by:** RFC-0063 Phase 2.0.1 survey flagged 2.0.0 as a critical prereq blocker for Phases 2.0.2-2.0.5 — needed empirical verification that Nucleor's import system handles ~430 cross-module fn references cleanly.
**Status:** **GREEN — Phase 2.0.2 unblocked.** Three smoke tests pass; the canonical "delete duplicates + import" pattern is confirmed both viable and recommended (the compiler's own diagnostic points at it).

## Test 1 — basic cross-module fn import

```nucleor
// lib_a.nr
fn lib_add(a: i64, b: i64) -> i64 { return a + b; }
fn lib_mul(a: i64, b: i64) -> i64 { return a * b; }
fn lib_greet() -> str { return "hello from lib_a"; }
```

```nucleor
// main.nr
import "lib_a.nr"
fn main() -> i64 {
    let s: str = lib_greet();
    print(s);
    let x: i64 = lib_add(3, 4);
    let y: i64 = lib_mul(x, 5);
    print(int_to_str(y));
    return 0;
}
```

`./bin/nucleor run main.nr` → builds, links, executes, prints `hello from lib_a` and `35`. ✅

## Test 2 — complex types (`Vec<T>`) cross modules

```nucleor
// lib_b.nr
fn pool_new() -> Vec<i32> { let v: Vec<i32> = Vec::new(); return v; }
fn pool_push(p: Vec<i32>, val: i32) -> i64 { vec_push(p, val); return vec_len(p); }
fn pool_sum(p: Vec<i32>) -> i64 {
    let n: i64 = vec_len(p);
    let mut total: i64 = 0;
    let mut i: i64 = 0;
    while i < n { total = total + (vec_get(p, i) as i64); i = i + 1; };
    return total;
}
```

```nucleor
// main2.nr
import "lib_b.nr"
fn main() -> i64 {
    let p: Vec<i32> = pool_new();
    pool_push(p, 10);
    pool_push(p, 20);
    pool_push(p, 30);
    print(int_to_str(pool_sum(p)));
    return 0;
}
```

Builds, links, prints `60`. Vec<i32> survives the module boundary intact. ✅

## Test 3 — duplicate-name behavior

```nucleor
// main3.nr (imports lib_a.nr which already defines lib_add)
import "lib_a.nr"
fn lib_add(a: i64, b: i64) -> i64 { return a * 100 + b; }   // duplicate
fn main() -> i64 { print(int_to_str(lib_add(3, 4))); return 0; }
```

Compiler PANICs with the canonical diagnostic:

```
Two modules in this compile unit both declare a `pub fn` with
this name. Nucleor emits one LLVM `define @<name>` per fn and
doesn't namespace by source module, so the link fails.
Workaround: rename one of the definitions (convention
`<module>_<fn>`, e.g. `config_error_kind_to_str` /
`pipeline_error_kind_to_str`) until module-prefixed lowering
lands in a future release (RFC-NRT-004 §H).
PANIC: duplicate pub fn name across modules: lib_add
```

This **confirms Phase 2.0.3's plan**: when tools_suite imports
nucleor_s1_compiler.nr, the 429 duplicate fns must be DELETED
from tools_suite (not coexist). The compiler's own diagnostic
recommends this exact pattern. ✅

## Implications for Phase 2.0.2-2.0.5

| Phase | Status |
|---|---|
| 2.0.0 — verify viability | **GREEN** ✅ (this finding) |
| 2.0.2 — mark s1 fns importable | **UNBLOCKED**. Note: Nucleor's visibility model treats every fn as effectively `pub`, so no source change needed for visibility per se. The "expose pub fn" framing in the original RFC was a Rust-ism; the actual ship is just confirming nothing is hidden behind `priv`-class scoping (none observed). |
| 2.0.3 — delete duplicates + add import | **UNBLOCKED**. Drop the 429 duplicate fns from `nucleor_tools_suite.nr` and add `import "compiler/nucleor_s1_compiler.nr"` at the top. |
| 2.0.4 — self-host integrity | Standard fixed-point check on the unified compile. |
| 2.0.5 — remove parser-fn drift gate | Trivial removal once 2.0.4 is green. |

## Open empirical questions for the actual 2.0.3 ship

These can't be answered without doing it; flag for proactive monitoring during Phase 2.0.3:

1. **Memory pressure of importing a 38K-line file.** s1 is 38,035 lines; tools_suite's compile may peak higher than today's ~286 MB (Linux baseline). If process-tree RSS exceeds the perf gate's ceiling (350 MB cold), need to investigate.

2. **Build time of importing s1.** The lex+parse cost is paid per-import; current tools_suite compiles in ~1s on hot path. Post-import this will likely be 5-10x slower. Acceptable if hot path stays < 5s.

3. **Whether RFC-NRT-004 §H "module-prefixed lowering"** has landed since the diagnostic was written. If yes, deletes might not be strictly necessary (but still cleaner). If no, deletion of all 429 duplicates is mandatory.

4. **`stdlib/rods/python.nr` and other rods that compile via tools_suite** — make sure the import chain doesn't transitively pull in s1's own rod imports causing collisions. Survey 2.0.1 didn't trace rod-import transitive closures.

## Cross-references

- `findings/promoted/2026-05-06-parser-unification-survey-rfc-0063-phase-2-0-1.md` — the survey that flagged 2.0.0 as a blocker
- RFC-0063 Phase 2.0 (production roadmap) — this finding closes 2.0.0 and unblocks 2.0.2+
- `compiler/nucleor_s1_compiler.nr:4385` — comment "Nucleor's current visibility model treats {items} as accessible regardless of field-level pub" confirms there's no real `priv` to overcome
- `RFC-NRT-004 §H` (referenced in the duplicate-name diagnostic) — module-prefixed symbol lowering, separate forward-roadmap item
