# RFC-0014 — `#[max_depth = N]` Bounded Recursion

| Field | Value |
|---|---|
| **Number** | 0014 |
| **Title** | `#[max_depth = N]` — bounded recursion attribute |
| **Status** | Implemented for v0.5 Track I, extended in the v0.6 max-depth analyzer pass. Both `#[max_depth = N]` and `#[max_depth(N)]` syntaxes parse on fn declarations; the compiler performs conservative structural depth analysis, preserves the RT-008 `#[deadline]` opt-out behavior, emits DEPTH-001..005 diagnostics, and rewrites accepted fns through a runtime depth counter that aborts with `error[DEPTH-003]` when the declared bound is exceeded. |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.5.0 ("Production Robotics") |
| **Depends on** | RFC-0001 (RT attributes) |

---

## 1. Summary

Add `#[max_depth = N]` attribute that asserts (and the compiler
verifies) a function's recursion depth is bounded by `N`. Required
for `#[deadline]` static-WCET analysis (RFC-0009) on recursive
functions; also unblocks `#[no_alloc]` for stack-only recursive code.

```nucleor
#[max_depth = 16]
#[no_alloc, no_panic]
fn rrt_search(node: &TreeNode, depth: u32) -> Option<Path> {
    if depth >= 16 { return None; }
    if node.is_goal() { return Some(node.path()); }
    for child in node.children() {
        if let Some(p) = rrt_search(child, depth + 1) {
            return Some(p);
        }
    }
    None
}
```

Without `max_depth`, RFC-0009 (Heptane WCET) cannot bound recursive
functions. **This RFC unblocks the static-WCET path for tree-search
robotics algorithms (RRT, A\*, behavior-tree dispatch).**

---

## 2. Motivation

Recursion is unbounded by default; static analysis (WCET, stack-
size, `#[no_alloc]`-stack-frame check) all fail. Three options:
1. Forbid recursion — too restrictive (tree-search algorithms
   essential to robotics).
2. Annotate the bound — pragmatic; user-asserted, compiler-verified.
3. Infer the bound — research-grade, often imprecise.

Option 2 is the right level for v0.5.

Prior art:
- Ada/SPARK — `pragma Restrictions (Max_Entry_Queue_Length)` and
  similar; `#[max_depth]` is the analogous fn-level construct.
- Rust — no first-class equivalent; `#[recursion_limit]` is for
  macros only.
- WCET tools — typically require user-supplied loop and recursion
  bounds.

---

## 3. Design

### 3.1 Attribute syntax

```nucleor
#[max_depth = 16]
fn recursive_search(...) { ... }

#[max_depth = "f(n) = 2*n + 1"]
fn complexity_bound(n: u32) { ... }   // not for v0.5
```

For v0.5, only literal-integer bounds are supported.

### 3.2 Semantics

The function asserts: any execution path reaches recursion depth at
most `N`. Compiler enforces by:

1. **Static check** — analyzes the function's call graph. If the
   function's body contains a recursive call without a depth-counter
   parameter or guard, the compiler emits a warning that runtime
   verification is required.
2. **Runtime check (debug profile)** — inserts a depth counter at
   function entry; aborts if exceeded.
3. **Static check (cert profile)** — refuses to compile unless the
   bound is statically provable from the body's structure.

### 3.3 Idiomatic pattern: explicit depth parameter

The cleanest way to satisfy `#[max_depth]`:

```nucleor
#[max_depth = N]
fn search(node: &Node, depth: u32) -> Result {
    #[assume(depth <= N)]
    if depth >= N { return failure(); }
    // ... recursive call passes `depth + 1` ...
    search(child, depth + 1)
}
```

The compiler can verify that any recursive call passes
`depth + 1` (or some monotonically increasing argument) and that
the entry guard short-circuits at `N`. This is decidable in many
practical cases.

The v0.6 extension pass recognizes these additional conservative
forms:

- the counter may be any integer-like parameter, not just the first
  parameter or a parameter named `depth`
- recursive calls may pass `counter + k` for any positive integer
  literal `k`
- countdown counters using `counter - 1` with `counter <= 0` /
  `counter < 1` guards are accepted
- simple helper predicates such as `done(counter, 16)` are inlined
  when the helper body proves `counter >= limit`
- function-pointer callback parameters must be marked
  `#[no_recurse]` at the parameter site before calls through them
  are accepted inside a `#[max_depth]` region

### 3.4 Mutual recursion

```nucleor
#[max_depth = 8]
fn a(d: u32) { if d > 0 { b(d - 1); } }

#[max_depth = 8]
fn b(d: u32) { if d > 0 { a(d - 1); } }
```

Compiler analyzes the strongly-connected components in the call
graph. All functions in an SCC must have compatible bounds and each
cycle edge must visibly advance a proven counter.

### 3.5 Stack frame budget

Each function has a known maximum stack frame from codegen. Total
stack usage of a `#[max_depth = N]` chain:

```
total_stack <= sum_over_chain( N_i * frame_size_i )
```

Must be less than the configured stack budget. Diagnostic if not.

### 3.6 Composition with `#[no_alloc]`

Recursion eats stack, not heap. `#[no_alloc]` is unaffected by
recursion *per se*, but `#[no_alloc, max_depth = N]` together let the
compiler bound total stack usage statically — useful for embedded
targets where stack is precious.

### 3.7 Composition with `#[deadline]` (RFC-0001) and Heptane (RFC-0009)

`#[max_depth = N]` is **required** for Heptane to bound recursive
functions in `--profile=cert`. Without it, WCET-005 fires.

### 3.8 Diagnostics

| Code | Meaning |
|---|---|
| DEPTH-001 | Max-depth analysis cannot bound a recursive path |
| DEPTH-002 | Static analysis proves a bounded depth that exceeds `#[max_depth = N]` |
| DEPTH-003 | Mutually-recursive SCC has incompatible/unproven bounds; runtime depth-check overrun also reports this code |
| DEPTH-004 | Invalid `#[max_depth]` placement or non-positive/non-literal bound |
| DEPTH-005 | Total stack budget exceeded by `#[max_depth]`-annotated chain |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `#[max_depth = N]` | ~50 |
| Type checker | SCC analysis, bound propagation | ~300 |
| Codegen (debug) | Depth counter insertion | ~80 |
| Diagnostics | DEPTH-001…005 | ~150 |
| **Total** | | **~580** |

---

## 5. Alternatives considered

- Forbid recursion in RT code — too restrictive.
- Infer bound automatically — research-grade; defer.
- Convert recursion to iteration via CPS transform — possible but
  changes user code semantics. Better to just bound.

## 6. Open questions

1. Tail-call optimization should make tail-recursive `#[max_depth]`
   trivially zero-stack — recommend yes when the optimizer can prove.
2. Bound parameterized by argument (`#[max_depth = "depth_param"]`)?
   Defer to v0.7 (full design-by-contract).
3. Should iterative-stacking (DIY tree search with explicit `Vec`
   stack) be auto-detected and `#[max_depth]` inferred? No, too
   complex.
4. Default for unannotated recursive functions in `--profile=cert`?
   Refuse to compile — must annotate.

## 7. Definition of done

- [x] `#[max_depth = N]` parses and is enforced
- [x] Mutual-recursion SCC analysis correct for visible fn-to-fn cycles
- [x] Stack-budget calculation works for annotated chains using conservative frame estimates
- [x] Existing `#[deadline]` RT-008 analysis consumes the bound
- [ ] Heptane profile consumes the bound directly
- [ ] CHANGELOG documents bounded-recursion model

## 8. Future extensions

- Argument-parameterized bounds (`max_depth = "n + 1"`)
- Symbolic bound inference (research)
- Co-recursive analysis for streams (v0.8+ if streams land)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.5 schedule
- [ ] LOC budget ~580 fits
- [ ] Pitch survives ("bounded recursion as first-class language
      feature, unlocks WCET on tree-search algorithms")
