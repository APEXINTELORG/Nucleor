---
title: `#[max_depth = N]` on an impl method that recursively calls `self.method(depth + 1)` falsely fires DEPTH-001 — the static analyzer doesn't recognize self-method recursion as the bounded pattern
severity: wrong-error (false-positive / coverage gap in static analysis)
probe_file: probes/depth/depth_impl_method.nr (will be filed)
diagnostic_actual: error[DEPTH-001] "analysis cannot bound recursive path in `count`; use an explicit depth parameter, an entry guard, and recursive calls with depth + 1"
diagnostic_expected: build proceeds — the method has all 3 required ingredients (explicit depth parameter `depth: i64`, entry guard `if depth >= 3 { return ... }`, recursive call `self.count(depth + 1)`)
discovered_against: main v0.4.286 (Track I integration — RFC-0014 max_depth)
commit: probe 3cde9c0 + main c09fd93 (Track I cherry-pick)
---

## Repro

```nr
struct Tree { val: i64 }

impl Tree {
    #[max_depth = 5]
    fn count(self, depth: i64) -> i64 {
        if depth >= 3 { return depth; };
        self.count(depth + 1)
    }
}

fn main() -> i32 {
    let t: Tree = Tree { val: 0 };
    print_int(t.count(0) as i32);
    0
}
```

## Actual

```
error[DEPTH-001]: analysis cannot bound recursive path in `count`; use an explicit depth parameter, an entry guard, and recursive calls with depth + 1
  --> fn count@line 5:4
  |
5 |         if depth >= 3 { return depth; };
  |    ^
```

The fixture has all 3 advertised ingredients:
1. **Explicit depth parameter:** `depth: i64`
2. **Entry guard:** `if depth >= 3 { return depth; };`
3. **Recursive call with depth + 1:** `self.count(depth + 1)`

Yet DEPTH-001 fires.

## Free-fn equivalent works

```nr
#[max_depth = 5]
fn count(t: Tree, depth: i64) -> i64 {
    if depth >= 3 { return depth; };
    count(t, depth + 1)
}
```

This compiles and runs correctly. Difference: free-fn `count(t, ...)` is a kind-7 call; `self.count(...)` is a kind-8 method call. The static analyzer's recursion detector probably walks kind-7 callees only and matches against the free-fn name.

## Hazard tier

Wrong-error class. Adopter ports a Rust pattern with `impl Method { ... self.method(depth+1) ... }` to Nucleor with `#[max_depth = N]` and gets a confusing DEPTH-001 saying "use a depth parameter and depth + 1" — but they ALREADY have those. The actual mismatch (kind-8 method vs kind-7 free-fn in the analyzer) is invisible.

## Suspected fix area

The `#[max_depth]` static analyzer (introduced in v0.4.286 / Track I `c09fd93`). When walking the method body for recursive calls, also recognize:

- `self.<same-method-name>(...)` (kind-8) where the receiver type matches the impl block.
- `Self::<same-method-name>(...)` (kind-12 assoc fn call) — same pattern in associated-fn form.

For both, the analyzer should treat them equivalently to a kind-7 self-call and apply the same "depth + 1 in last argument position" detection.

## Workaround

Adopters can either:
1. Hoist the method to a free fn taking `Self` as the first parameter, OR
2. Drop `#[max_depth]` and rely on runtime DEPTH-003 (less safe — caught at runtime, not compile time).

## Memory-blow-up note

Not memory-related directly, but the missing static check means recursive methods can silently blow the stack until DEPTH-003 catches them at runtime. That's worse UX than the static-time bound.

## Cross-ref

- v0.4.286 / Track I cherry-pick `c09fd93` — RFC-0014 max_depth integration
- v0.4.158 — kind-8 type_expr returns Vec for chained calls; sister kind-7-vs-kind-8 dispatch hazard
- DEPTH-001..005 family

## Probe

Filed alongside this finding.

## 2026-05-01 — sister bug: Self::method assoc-fn form

The associated-fn form (`Self::count(...)` / `Node::count(...)`)
exhibits a DIFFERENT but related failure: the compiler emits IR
referencing a max_depth-mangled inner symbol that doesn't exist:

```nr
struct Node { val: i64 }

impl Node {
    #[max_depth = 5]
    fn count(depth: i64) -> i64 {
        if depth >= 3 { return depth; };
        Node::count(depth + 1)   // assoc-fn-call (kind-12)
    }
}

fn main() -> i32 { print_int(Node::count(0) as i32); 0 }
```

Compile errors at clang link with:

```
target/depth9_assoc_fn.ll:899:19: error: use of undefined value '@__nuc_md_inner_0f3d586e_0'
  899 |   %r.7 = call i64 @__nuc_md_inner_0f3d586e_0(i64 %r.6)
                          ^
```

The `__nuc_md_inner_<hash>_0` is the max_depth analyzer's inner-impl
symbol — Track I uses a wrapper/inner pattern where the public
fn does the depth-counter increment and the inner does the work.
For `Node::count` the assoc-fn-call dispatch path emits an IR
reference to the inner symbol but doesn't actually emit the inner
fn body, OR the mangling differs between the impl-block walk and
the call-site walk.

**Same root issue as the kind-8 method case above** — the
max_depth analyzer recognizes free fns (kind-7) but not impl
forms (kind-8 self-method or kind-12 Self::method). The two
cases fail differently because their lowering is different, but
they should be fixed together.

## Sister fixture

```nr
// probes/depth/depth_assoc_fn.nr — added alongside depth_impl_method.nr
```


## Promoted

- Fixture: `tests/features/rfc0014_max_depth_impl_method.nr` —
  exercises `#[max_depth = 5]` on an impl method with
  `self.count(depth + 1)` self-recursion. Exit 0, prints `3`.
- Fix shipped: v0.5.7 — two-layer fix.
  1. `md_first_param_name` (compiler/nucleor_s1_compiler.nr
     line 10798) now skips a leading `self` / `&self` / `&mut self`
     receiver and returns the next ident. The static analyzer
     was previously checking guard / increment patterns against
     `self`, never matching, and DEPTH-001 fired falsely.
  2. `expand_max_depth` wrapper-rewrite (line ~22526) detects a
     `self`-prefixed `arg_names` and emits the wrapper's call
     to the inner as `self.<inner>(<rest_args>)` (kind-8 method
     dispatch) instead of `<inner>(self, <rest>)` (kind-7 free
     fn). The inner is registered as an impl method when the
     wrapper-rewrite emits it inside the impl block, so method
     dispatch is the right shape.
- Verify gate: existing RFC-0014 step picks up the new fixture
  via the per-feature loop. 688/688 PASS env-off + env-on after
  the fix lands.
- Sister gap (kind-12 `Self::method` associated-fn recursion)
  remains: not addressed by this ship. Static analyzer's
  `md_body_contains_call` looks for `<callee>(` substring which
  would still match `Self::count(` — but the wrapper-rewrite
  doesn't know to emit `Self::<inner>(rest)`. Left to a
  follow-up if probe-agent files a focused fixture for
  associated-fn forms.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on
  origin/probe/exploration commit 7f3279c).
