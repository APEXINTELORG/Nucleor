---
title: `SpscQueue<str>` returns `Option<str>` from `spsc_pop`, but the `Some(s)` match-arm binding `s` is typed as i64 — `print(s)` then halts with TYP-006 "argument 0 must be str"
severity: silent-miscompute / wrong-error (generic type propagation)
probe_file: probes/atomic/spsc_string_payload.nr (will be filed)
diagnostic_actual: TYP-006 on `print(s)` even though `s` is the destructure binding from `Some(s)` in a `Option<str>` match
diagnostic_expected: `s: str` to be inferred from the SpscQueue<str>'s T parameter; print(s) compiles
discovered_against: main v0.4.274 (Track H lock-free queues LIVE)
commit: probe e27ee0a + main 2c7e310
---

## Repro

```nr
import "stdlib/rods/spsc_queue.nr"

fn main() -> i32 {
    let mut q: SpscQueue<str> = spsc_new::<str>(2);
    spsc_push(&mut q, "hello");
    spsc_push(&mut q, "world");
    let r1 = spsc_pop(&mut q);   // r1: Option<str>
    match r1 {
        Some(s) => print(s),       // ← TYP-006 fires here
        None => print("none"),
    };
    0
}
```

## Actual

```
error[TYP-006]: argument 0 of 'print' must be str (runtime helper)
  --> fn main@line 304:27
    |
304 |     match r1 { Some(s) => print(s), None => print("none") };
    |                           ^
```

The destructure binding `s` from `Some(s)` doesn't inherit `str` from `SpscQueue<str>::pop`'s return type `Option<str>`. The type-checker treats `s` as `i64` (the i64-everywhere ABI default), so `print(s)` (which only accepts str) rejects.

## Why this matters

Adopter writes the canonical Rust pattern over a `SpscQueue<str>`:
1. Construct queue: works.
2. Push str values: works.
3. Pop into Option<str>: works (the Option has correct payload at runtime).
4. Destructure Some(s) and use `s` as a str: FAILS at type-check.

The runtime payload IS a str pointer (i64-everywhere ABI). The type system loses the T = str information through the SpscQueue<str>::pop → Option<str> → match-arm binding chain.

## Comparison: Option<i64> works

```nr
let mut q: SpscQueue<i64> = spsc_new::<i64>(2);
spsc_push(&mut q, 100);
let r1 = spsc_pop(&mut q);
match r1 { Some(v) => print_int(v as i32), None => ... };  // works
```

This compiles + runs. Difference: print_int accepts i64 (everything from the i64-ABI), so even if `v`'s type isn't precisely tracked, the call type-checks. With `print(s)`, the str-only requirement exposes the dropped T.

## Suspected fix area

The generic-T-propagation chain that needs to thread T = str:

1. `spsc_pop(&mut q: SpscQueue<str>)` → return `Option<str>` (already works at the runtime level, since the buffer holds Option<str>).
2. Match-arm binding `Some(s)` → `s: str`. **This step drops T.**

Likely root: kind-39 (match arm) binding type-inference for `Some(<binding>)` patterns falls back to the bare `Option`'s inferred T (which is `i64` if no annotation), rather than reading T from the matched expr's type `Option<str>`.

Probe-side workaround: explicit type annotation in the binding. Try `Some(s: str)` (probably not legal syntax) or hoist the destructure: `let r1 = spsc_pop(&mut q); let s: str = ...`.

Actual workaround if not solvable here: cast through `as str` (won't work since `as` doesn't allow i64→str), or use the runtime helper directly:

```nr
match r1 {
    Some(s) => {
        let s_typed: str = s;   // does this hoist the type? probably not
        print(s_typed);
    },
    None => print("none"),
};
```

## Hazard tier

Wrong-error class with silent-miscompute risk if the i64 ever gets reinterpreted at runtime (would be a SIGSEGV via `print`-with-i64-pointer pattern that earlier ships closed). Currently halted at compile time, but with a misleading message: the user sees "must be str" pointing at `s` and doesn't realize the destructure is the issue.

## Cross-ref

- v0.4.274 — Track H queues LIVE; the queue stdlib uses `<T>` generics correctly internally
- v0.4.158 — kind-8 type_expr returns Vec for clone/sort/etc.; sister type-flow fix at the chained-call layer
- The Option<T> destructure path is in the kind-39 (match arm) handler in compiler/nucleor_s1_compiler.nr

## Probe

`probes/atomic/spsc_string_payload.nr` — minimal repro (file path TBD; lives next to the other Track G/H probes).

## 2026-05-01 — narrowed scope (post-filing, after isolating)

The bug is NOT specific to SpscQueue or Track H — it's the
**generic-fn-return-type-inference path** for ANY generic fn
returning `Option<T>` / `Result<T, E>` / etc. when the call-site
binding has no explicit type annotation.

**Minimal repro (no Track H needed):**

```nr
struct Wrap<T> { val: T }

fn unwrap<T>(w: Wrap<T>) -> Option<T> {
    Some(w.val)
}

fn main() -> i32 {
    let w: Wrap<str> = Wrap { val: "wrapped" };
    let r = unwrap(w);                         // ← INFERRED
    match r { Some(s) => print(s), None => print("none") };
    //                       ^ TYP-006: must be str
    0
}
```

**Working with annotation:**

```nr
let r: Option<str> = unwrap(w);   // explicit
match r { Some(s) => print(s), None => print("none") };  // works
```

**Working without generics:**

```nr
fn unwrap_str(w: Wrap<str>) -> Option<str> { Some(w.val) }
let r = unwrap_str(w);   // inferred — works because monomorphic
```

The interaction is: **generic fn instantiation + inferred let
binding**. The inference path doesn't propagate T = str from
the call-site argument's type back to the return type of the
generic fn.

## Workaround for adopters

Add an explicit `Option<T>` annotation on the binding:

```nr
let r: Option<str> = spsc_pop(&mut q);   // not `let r = ...`
```

## Suspected fix area

The kind-7 (call) type_expr generic-fn-return inference path. When
the callee is a generic fn (`__closure_argc_<callee>` not set, but
sig with non-empty `gparams`), the return type contains `T`/`E`/etc.
The inference resolver should:
1. Look at the call-site argument types
2. Match them against the generic fn's parameter list to bind T → str
3. Substitute T in the return type before returning to the let-stmt

Currently step 3 likely returns the unsubstituted "Option<T>" or
"Option" (default) — the let-stmt then types `r` as Option<i64>
fallback. The match-arm Some(s) binds `s` as the inferred Option's
T, which is i64.

When the user adds `let r: Option<str> = ...`, the let-stmt's
explicit type ann gives the type-checker the answer it would have
otherwise had to infer.

## Cross-ref

- v0.4.158 — kind-8 type_expr returns Vec for clone/sort/etc.;
  sister type-flow fix at the chained-call layer.
- v0.4.244+ generic substrate (RFC-0024) — this is the gap on top.


## Promoted

- Fixture: `tests/features/rfc0024_generic_t_propagation.nr` —
  exercises the inferred-let-binding chain
  `let r = spsc_pop(&mut q)` where `q: SpscQueue<str>`, plus the
  Some/None match-arm with print on the str payload. Exit 0,
  prints "hello", "world", "OK".
- Fix shipped: v0.5.13 — call-site rtype inference now
  substitutes gparam bindings extracted from arg types.
  - **New helper `gparam_extract_binding`**
    (`compiler/nucleor_s1_compiler.nr` line ~7491). Aligns one
    (expected, actual) param pair and returns the binding for
    a named gparam. Handles `T` direct, `Wrap<T>`, `&Wrap<T>`,
    `&mut Wrap<T>`, and nested generic args via recursion through
    `type_first_arg`/`type_base_name`.
  - **New helper `substitute_gparam_in_rtype`** (line ~7522).
    Whole-word-aware substitution of a gparam name with its
    concrete binding in a type string. Bounded by non-identifier
    chars so `T` doesn't match inside `MyT` or `T_helper`.
  - **Call-site loop** (`type_expr` kind-7, line ~14415): walks
    args alongside the existing trait-bound check, accumulates
    [name, concrete-type] bindings into a fresh
    `gparam_bindings_v513` vec (first-binding-wins to keep the
    path simple).
  - **Return path** (line ~14443): substitutes each binding into
    the literal rtype before returning. Falls through to the
    literal rtype if no bindings were inferred (non-generic fn
    or gparams not inferable from the arg shapes).
- Verify gate: existing per-feature loop picks up the new
  fixture. 696/696 PASS env-off + env-on.
- Conservative scope: covers the common shapes (T direct,
  Wrap<T>, &Wrap<T>, &mut Wrap<T>; nested via recursion). Does
  NOT yet handle:
  - Multi-gparam fns where one gparam appears only in the rtype
    and is inferred from a non-arg context (no such case in
    Nucleor stdlib today).
  - Bindings disagreeing across multiple args (first-binding
    wins; later-arg disagreement falls through silently to the
    earlier binding's substitution).
  Both are tracked as future-ship improvements if probe-agent
  finds counter-examples in stdlib code.
- Sister gap (sister finding
  `2026-05-01-generic-T-trait-bound-method-dispatch.md` — kind-8
  method dispatch in generic-fn body uses Vec<T> fallback)
  remains open. That's a different code path
  (lower-time, not type-check-time) and a separate ship cycle.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on
  origin/probe/exploration commit e27ee0a).
