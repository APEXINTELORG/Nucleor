# Lane 2 / Queue 2C — Closures and function-pointer effects: design finding

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Branch:** `probe/effects-higher-order-fn-pointer-v0845`
- **Base:** `origin/main` @ `0081b779fedf446895a155e710521dbbcd6f8ace`
- **Scope:** Probe / design report only. No compiler change in this branch.

## Headline

Closure-body effect enforcement is **already covered by accident** for
the cases that matter most in practice — the closure body lives
textually inside its enclosing fn, so the existing
`enforce_requires_direct_calls` substring walk picks up both direct
builtin reach and same-file rowed-callee mismatches without seeing the
closure as a separate compilation unit.

The genuine residual is **function-pointer indirect calls** — both the
local-binding form (`let f = rowed_io; f()`) and the higher-order
parameter form (`fn h(f: fn() -> i32) { f() }`). In both, the
substring search has no name in its fn-table that matches the call
site (`f` is a binding/parameter, not a declared fn). Effect rows on
the underlying target fn are silently bypassed.

The cheap, safe fix for the **local-binding form** is a 30-50 line
textual pre-pass: when scanning a fn body, record `let <ident> =
<callee>;` patterns where `<callee>` is in the resolved-source fn
table, and rewrite the row check to consult the binding-target's row
when the body calls `<ident>(`. This closes the most common pattern
adopters trip on (storing a fn-ref before invoking it). It does **not**
close the higher-order parameter form.

The **higher-order parameter form** requires either:
- a v1.0 fail-closed advisory (warning EFF-G126) on every fn whose
  parameter type is `fn() -> ...` and whose body invokes the
  parameter — adopter discipline today is to use the `requires [...]`
  row on the receiver; the advisory makes the implicit unsoundness
  visible — or
- full AST-level type tracking in Phase 4 / RFC-0033 effect-row
  subtyping (the canonical fix).

## Empirical baseline (probes, post-Queue 2B `origin/main` @ `0081b779`)

| Probe | Body pattern | Behavior | Class |
|---|---|---|---|
| `_probe_2c/probe_closure_neg.nr` | `caller()` declares `[net]`, contains closure `\|\| { print("..."); 0 }`; closure invoked inline | **EFF-001 fires** (closure body's `print(` hits caller's body-direct walk) | covered by substring |
| `_probe_2c/probe_closure_call_rowed.nr` | Closure body calls same-file rowed fn `rowed_io()` declared `[io.write]`; caller declares `[net]` | **EFF-001 fires** (same substring path catches `rowed_io(` in caller's body) | covered by substring |
| `_probe_2c/probe_fnptr_neg.nr` | `let f = rowed_io; f()` in caller declaring `[net]`; `rowed_io` declared `[io.write]` | **silent pass** — neither `rowed_io(` nor `f(` triggers (binding `let f = rowed_io;` has no `(`; `f` not in fn table) | residual |
| `_probe_2c/probe_fnptr_param.nr` | `fn invoke_indirect(f: fn() -> i32) requires [net] { f() }` invoked with `rowed_io` | **silent pass** — `f` is a parameter, not in the fn table; the rowed-fn ref is in an argument-position, not a call site | residual |

## Current representation in s1

- **Closures.** Closures are lowered through a separate path
  (`closure_collect_capture_expr` line 24814,
  `closure_writeback_captures` line 24787,
  `lower_expr` closures handle line 25190). The closure body source
  text remains textually inline inside its enclosing fn during the
  effect pre-pass, which is why
  `enforce_requires_direct_calls`,
  `requires_transitive_missing`, and
  `restricts_transitive_check` already see the closure's calls when
  walking the enclosing fn's body. The existing
  `enforce_no_atomic_in_closure` (line 16048) is the precedent for
  closure-aware enforcement at the source-text layer.
- **Function pointers.** `op 29 = fn_ptr` (line 9313 keep-alive scan)
  is the AST/IR marker for "this fn's address has been taken." The
  IR primitives are `ir_fn_ptr(d, fn_name)` (line 5575) and
  `ir_indirect_call(d, closure_reg, args)` (line 5581). At source
  text level the patterns to recognise are:
    1. `let <ident> = <callee>;` — binding to a fn name.
    2. `fn <name>(<params>) ... { ... <ident>(<args>) ... }` where
       `<ident>` is a parameter typed `fn(...) -> T`.
    3. `async_spawn(fn_ptr, arg)` (RFC-0027 Phase 1) — the fn-ptr
       arg is a known callee at the call site.
- **`async_spawn`** (line 17263, expand_async_syntax) takes a
  fn-ptr literal as its first argument. That argument is always a
  bare ident referring to a fn declared in the same source. The
  same row-check that
  `enforce_requires_direct_calls` applies to direct `<callee>()`
  could be applied to `async_spawn(<callee>, ...)` with the spawn
  caller's row vs the spawned fn's row — a free win for v1.0.

## What effect metadata is missing

To fully close higher-order effect-row enforcement the compiler
would need:

1. **A binding→target map** for `let <ident> = <callee>;` (per fn).
   Source-text feasible, smallest change.
2. **Parameter-type effect rows.** A function pointer's type today
   is `fn(<param-types>) -> <ret>`. To track effects through
   parameters the type would need to be `fn(<param-types>) -> <ret>
   requires [...]` (RFC-0033). This is the canonical fix and lives
   in Phase 4.
3. **Fn-ptr stored in struct fields.** Same as (2) — needs the row
   in the field type.
4. **Closure capture set + body row inference.** Needed only when
   closures are returned/escaped. Currently closures are inline so
   the body row is implicit in the enclosing fn's row.
5. **Trait-object indirect dispatch.** Out of scope for v1.0
   effects-row work; Queue 5A/B/C already touches the trait surface
   for ROBO-7 frame typing.

## Smallest v1.0-safe fail-closed rule

Two-tier proposal, in order of cost:

### Tier A — local-binding form (smallest hook, ~30-50 LOC)

Add a pre-pass `collect_fn_bindings(body)` that returns a
`[binding_name, callee_name, ...]` flat vec for every same-file
`let <ident> = <fn-name>;` where `<fn-name>` matches an entry in
`collect_fn_table`. Then in
`enforce_requires_direct_calls`,
`requires_transitive_missing`, and
`restricts_transitive_check`, before the substring search:

- Walk the body, for each `<ident>(` call site whose `<ident>` is
  in the binding map, treat the callee as the binding's target
  fn-name and reuse the existing row-check loop.

This closes the local-binding silent fall-through. Visited-set
dedup keeps termination O(N). Ambiguous-name guard (Queue 2B
helper `name_has_distinct_rows_in_table`) applies as-is to the
resolved target.

### Tier B — higher-order parameter advisory (no code, ~5 LOC banner)

Add an EFF-G126 advisory to the audit banner: "function pointer
parameters do not propagate effect rows; adopters relying on
`requires [...]` for HOF receivers should treat the receiver row as
a maximum and audit the call-site fns the receiver invokes."

The advisory makes the implicit unsoundness visible without forcing
a parser change. Phase 4 / RFC-0033 effect-row subtyping in
function-pointer types is the canonical close.

### Tier C (optional) — `async_spawn` first-arg row check (~20 LOC)

Special-case `async_spawn(<fn-name>, <arg>)` — the first argument
is a bare ident referring to a same-file fn. Apply the same row
check the existing direct-call path applies. Closes the
async-spawn pattern explicitly without touching parser types.

## Recommendation

- **For v1.0 ship:** Tier A + Tier B + Tier C. Total ~60 LOC source
  text in s1 + 1 banner sentence. Closes the local-binding and
  async-spawn silent fall-throughs and discloses the residual
  HOF-parameter gap.
- **Defer to Phase 4:** parameter-type effect rows (RFC-0033),
  trait-object dispatch, fn-ptrs in struct fields, returned closures.

## Stop reason

Per handoff §Lane 2 / Queue 2C: "Do not overbuild. Produce an explicit
design finding…". This branch is probe/report only. Implementation
of Tier A + B + C, with locking fixtures, is a separate fix branch
(`fix/effects-higher-order-fn-ptr-rowcheck-v0845` recommended).

## Honest residuals (separate from the gaps above)

1. **Probes were Windows-host only.** A Linux re-run after Tier A is
   shipped should re-confirm the same baselines.
2. **Closure escape (closure returned from fn) was not probed** —
   the in-tree closures are inline. If closure escape is added in
   v1.0, the body-row inference in (4) above lands with it.
3. **No fixtures lock the silent fall-through.** Adding negative
   fixtures for the fn-ptr cases requires the Tier A or Tier C
   patch first (otherwise they'd EXPECT `error[EFF-001]` against
   current behavior that doesn't fire, breaking verify.sh).
