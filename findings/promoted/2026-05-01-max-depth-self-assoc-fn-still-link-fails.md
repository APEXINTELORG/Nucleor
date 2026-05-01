---
title: `#[max_depth = N]` on an impl associated fn (no `self`) — v0.5.7's wrapper-rewrite layer 2 only handles `self.<inner>(...)`, not the no-self assoc-fn form. `Self::method(...)` recursion still emits an undefined `@__nuc_md_inner_<hash>_0` symbol at clang link.
severity: silent-miscompute / wrong-error (link-time, no compile-time signal)
probe_file: probes/depth/depth_assoc_fn.nr (already filed)
diagnostic_actual: clang link error[TYP-005] "use of undefined value '@__nuc_md_inner_0f3d586e_0'"
diagnostic_expected: build success (mirroring v0.5.7's success on the self.method form)
discovered_against: main v0.5.8
commit: probe 0113470 + main 2f8fda0
---

## Repro

```nr
struct Node { val: i64 }

impl Node {
    #[max_depth = 5]
    fn count(depth: i64) -> i64 {
        if depth >= 3 { return depth; };
        Node::count(depth + 1)   // ← assoc-fn-call (kind-12)
    }
}

fn main() -> i32 { print_int(Node::count(0) as i32); 0 }
```

## Actual

```
target/verify_max_depth_assoc.ll:899:19: error: use of undefined value '@__nuc_md_inner_0f3d586e_0'
  899 |   %r.7 = call i64 @__nuc_md_inner_0f3d586e_0(i64 %r.6)
      |                   ^
1 error generated.
```

## Status

Sibling case to the self.method form, which was closed by v0.5.7
(probe-agent finding `2026-05-01-max-depth-impl-method-self-recursion-not-bounded`).

The v0.5.7 changelog notes:

> **Layer 2 — wrapper-rewrite emits method dispatch for impl methods.**
> ... Now: when `arg_names` starts with `self`, the wrapper emits
> `self.<inner>(<rest_args>)` — kind-8 method dispatch — so the
> call lowers to the same Tree-mangled symbol the inner declaration
> produced.

That fix is gated on `arg_names` starting with `self`. **For an
assoc-fn (no self receiver), `arg_names` doesn't start with self —
the gate doesn't fire, and the wrapper still emits the broken
free-fn call to the missing `@__nuc_md_inner_<hash>_0` symbol.**

## Suspected fix area

Same compiler/nucleor_s1_compiler.nr `expand_max_depth` Layer 2
branch. Add a sister case for the assoc-fn form:

```nr
// Pseudocode for the fix:
if arg_names.starts_with("self") {
    // existing: self.<inner>(<rest_args>)
} else if is_assoc_fn(<context>) {
    // NEW: emit `<TypeName>::<inner>(<args>)` so the call resolves
    // to the same Type-mangled inner symbol the assoc-fn decl
    // produced.
    emit("<TypeName>::<inner>(", arg_names_joined, ")");
} else {
    // existing: <inner>(<arg_names>) — works for free fns
}
```

The detection of "is this an impl assoc-fn?" should be available
from the same impl-block context that v0.5.7's Layer 1 used to
identify the impl method case.

## Workaround

Rewrite the assoc-fn as a free-fn:

```nr
#[max_depth = 5]
fn node_count(depth: i64) -> i64 {
    if depth >= 3 { return depth; };
    node_count(depth + 1)
}
```

Loses the namespacing under the impl block.

## Cross-ref

- v0.5.7 (closed self.method form of this hazard)
- Earlier finding `2026-05-01-max-depth-impl-method-self-recursion-not-bounded.md` (parent finding; this is the residual portion)

## Probe

`probes/depth/depth_assoc_fn.nr` (existing — was filed alongside the parent finding).


## Promoted

- Fixture: `tests/features/rfc0014_max_depth_assoc_fn.nr` —
  exercises `#[max_depth = 5]` on an impl assoc-fn with
  `Node::count(depth + 1)` self-recursion. Exit 0, prints `3`.
- Fix shipped: v0.5.9 — extends v0.5.7's Layer-2 fix.
  - New helper `md_find_enclosing_impl_type` (compiler/nucleor_s1_compiler.nr
    line ~22474) backward-scans from the `#[max_depth]` line position,
    balancing braces, to find the most-recent unclosed
    `impl <Type> { ... }` or `impl Trait for <Type> { ... }`. Returns
    the receiver type name or "" if not in an impl block.
  - The wrapper-rewrite's call-emission branch (line ~22580) now
    handles three cases: (1) `arg_names` starts with `self` →
    `self.<inner>(<rest>)` (v0.5.7 path); (2) enclosing-type
    non-empty AND no self → `<Type>::<inner>(<args>)` (v0.5.9 path);
    (3) else → `<inner>(<args>)` (free-fn path). The inner
    declaration still sits inside the same impl block, so the
    `<Type>::<inner>` form resolves to the correct Type-mangled
    symbol.
- Verify gate: existing RFC-0014 step picks up the new fixture.
  689/689 + 1 (= 690) PASS env-off + env-on after the fix lands.
- Sister gap (v0.5.7 footer) closed: `Self::method(...)` itself is
  not yet supported by the compiler ("unsupported associated-fn
  call"), so the wrapper deliberately emits the explicit
  `<Type>::<inner>` form (rather than `Self::<inner>`) which IS
  supported by the existing assoc-fn dispatch path.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on
  origin/probe/exploration commit 973c4fa).
