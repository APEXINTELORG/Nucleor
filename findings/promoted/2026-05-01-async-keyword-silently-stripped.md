---
title: `async fn` keyword is silently stripped — adopter writing canonical Rust async pattern gets immediate sync execution with no Future / no await semantics
severity: silent-miscompute (semantic mismatch with Rust async model)
probe_file: probes/async/async_fn_silently_stripped.nr (will be filed)
diagnostic_actual: build succeeds; `async fn fetch() -> i64 { 42 }` is treated as a regular sync fn. `let r = fetch();` returns 42 immediately.
diagnostic_expected: parse-time `error[ASYNC-NNN]: async fn is not supported in Nucleor v0.5; declare as a regular fn or use task/channel primitives from stdlib/rods/atomic.nr` (until real async substrate lands)
discovered_against: main v0.5.17 (probe rebased afbd8be)
commit: probe 12e613e + main 736d88a
---

## Repro 1: async fn called as sync — silently OK

```nr
async fn fetch() -> i64 { 42 }

fn main() -> i32 {
    let r: i64 = fetch();   // ← in Rust this is a Future<i64>, not i64
    print_int(r as i32);     // prints 42 immediately
    0
}
```

Output: `42`. No diagnostic.

## Repro 2: .await syntax not supported

```nr
async fn fetch() -> i64 { 42 }

fn main() -> i32 {
    let r: i64 = fetch().await;
    print_int(r as i32);
    0
}
```

Output:
```
PANIC: nucleor: cannot resolve field access .await
```

So `.await` is rejected (treated as field access on the i64 result).

## Hazard

Mixed signal:
- `async fn` declaration: silently accepted, keyword stripped
- `fetch()` call: returns the body's value directly (sync semantics)
- `.await`: panics with "field access" error

Adopter porting Rust async code:
1. Writes `async fn process()` — accepted ✓
2. Tries `await` — panics, learns "Nucleor doesn't have async"
3. Drops `.await` to make it compile — code now executes IMMEDIATELY (sync) but the `async` keyword stays in the signature, suggesting deferred semantics that don't exist
4. Tests pass (because sync execution happens to do what they expect)
5. Production: behavior depends on whether the adopter relied on async deferral semantics. If they used Tokio-style task spawning, that's silently broken.

## Sister silent-stripped keywords

Worth checking:
- `unsafe` (Rust unsafe blocks)
- `mut` patterns vs immutable patterns
- `move` closures vs borrowing closures
- `'static` lifetime markers
- `where` clause variations

Each has its own silent-strip risk if the keyword is parsed-and-ignored rather than parsed-and-rejected.

## Suspected fix

Two paths:

**A — reject at parse time**: emit `error[ASYNC-001]` at parse for any `async fn`. Diagnostic names the gap and lists current alternatives:
- For independent task scheduling: `tools/rods/atomic.nr` patterns (CAS loops, queues)
- For synchronous fn that returns later: just `fn` (no async needed in Nucleor's model)
- Tracked for v0.x.NNN when async substrate lands

**B — accept with WARNING**: emit a parse-time warning that `async` is a no-op (current behavior) so adopter has a signal. Less safe; adopter might miss the warning.

Recommended: **A**. Mirrors the `assoc-const-in-trait` rejection pattern (parse-time clean error + workaround in message + "tracked for future ship" deferral).

## Memory-blow-up note

Not memory-related.

## Cross-ref

- v0.4.33b — assoc-const-in-trait rejected at parse time (sister "feature not yet supported" pattern)
- RFC-0033 effects-as-types (v0.6+ work on origin/v06-track-effects-types) — likely the substrate where async eventually lands
- async/await is Rust async/.NET Task; both ports break silently today

## Probe

`probes/async/async_fn_silently_stripped.nr` and
`probes/async/async_await_panics.nr` filed alongside this finding.


## Promoted

- Fix shipped: v0.5.19 — ASYNC-001 warning fires for plain
  `async fn` (no RT attribute). RT-006 path for
  `#[no_alloc] async fn` etc. unchanged.
- Compiler: new `enforce_async001_warning` scanner (line ~11264)
  reads `//__NUC6X:` markers emitted by `expand_async_strip_keyword`
  for plain async fns. Mirrors RT-006's `//__NUC6T:` pattern.
- Tools-suite: 3 explain registry entries for ASYNC-001
  (title, cause, hint).
- verify.{sh,ps1}: ASYNC-001 added to cli_explain_full_smoke
  codes lists.
- docs/spec/Nucleor_Error_Codes.md: new ASYNC series with
  ASYNC-001 row (warning tier).
- Adopter behavior: warning fires once per async fn; build
  succeeds; runtime still sync (no breaking change).
- Promoted: 2026-05-01 by main agent (probe commit 12e613e).
