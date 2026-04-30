---
title: `for x in v { v.push(...) }` builds clean, runs unbounded — iterator invalidation never detected
severity: silent-miscompute
probe_file: probes/vec/push_during_iter.nr
diagnostic_actual: none (compile clean, runtime grows memory unboundedly)
diagnostic_expected: OWN-NNN — "cannot mutably borrow `v` while iterating it" at compile time
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
status: CLOSED in v0.4.205 via runtime snapshot. The for-loop lowering now computes vec_len ONCE before the loop and reuses it across iterations. Pushes inside the body extend the Vec but are not visited. Memory blow-up eliminated. Regression-guard at tests/features/for_loop_push_during_iter_bounded.nr locks in 4 cases (push-during-iter, empty, readonly, multi-push). Note: this is the snapshot fix, not the canonical compile-time OWN-NNN borrow-check fix; the latter is deferred and tracked separately if needed.
---

## Repro

```nr
fn main() -> i32 {
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    for x in v {
        v.push(x + 100);
    };
    print_int(v.len() as i32);
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/vec/push_during_iter.nr -o push_during_iter
  source: probes/vec/push_during_iter.nr (190 bytes)
  mode: fast (ownership + type)
  ... (no error, no warning beyond NUM-003 on `.len() as i32`)
  compiled: target\push_during_iter.exe

$ ./target/push_during_iter.exe
[runs unbounded; killed by Run-Capped at 337 MB RSS in 5s]
```

The for-loop iterates the Vec by index. The body pushes a new element on
each iteration, which extends `v.len()`, which extends the iteration
range, which adds another push, which extends `v.len()` further, and so
on. Memory grows without bound until the OS / a wrapper kills it.

Without the Run-Capped wrapper this would exhaust system memory and
either (a) hang the user's machine or (b) trigger the OS OOM killer on
some unrelated process. This is exactly the memory-blow-up class the
project's e-stop policy exists to prevent.

## Expected

Either:
- **OWN-NNN at compile time**: `for x in v` takes a (shared/mutable)
  borrow on `v` for the duration of the loop body. `v.push(...)` inside
  the body requires a `&mut v`, which conflicts with the iterator's
  borrow. Reject at type-check.
- **RT-NNN at runtime**: the `vec_push` runtime helper checks an
  "iteration in progress" flag set by `for x in <vec>` lowering and
  panics on conflict. Cheaper than the borrow-check route; less precise.

The compile-time path is canonical for an ownership-checked language and
mirrors v0.4.154 (`String use-after-move on binding transfer`) which is
the same "use of value after a borrow conflict" pattern.

## Memory-blow-up note

This finding is the kind of pre-shipping hazard that Run-Capped exists to
catch. With my probe runs wrapped at `-EstopMB 256`, the kill was clean
in <1 s. Without the wrapper an adopter who writes this code in a real
program will see the OS pause, freeze, or OOM-kill something they care
about. **Recommend prioritizing this finding for the next ship after the
in-flight v0.4.163.**

## Suspected location

The `for ... in <vec>` lowering in `compiler/nucleor_s1_compiler.nr`
(kind-49 — same dispatch site I edited for v0.4.163's struct-iterand
reject). The lowering currently emits a counted loop that re-reads
`vec_len(v)` every iteration. Either:

1. Snapshot `vec_len` before the loop (semantic change — fixes this case
   AND aligns with Rust's `for x in v.iter().take(initial_len)` shape),
   OR
2. Detect mutation of the iterand binding within the loop body during
   ownership analysis and reject (cleaner — matches the OWN-001 /
   OWN-004 family).

(2) is more in keeping with how the existing OWN diagnostics handle
borrow-conflict patterns. (1) silently changes the iteration semantics
which adopters may have already relied on for non-mutating loops.

## Cross-ref

- v0.4.154 (OWN-001: String use-after-move on binding transfer) — same
  borrow-conflict family.
- v0.4.152 (TYP-011 ext: for over str/String/scalar/bool) — same `for`
  lowering site.
- In-flight v0.4.163 (TYP-011 reject for-on-struct) — adjacent fix.
