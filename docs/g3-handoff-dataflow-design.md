# RFC-0062 G-3 Phase 2b — Per-fn Dataflow Handoff Detection

**Status:** Active design (started 2026-05-04)
**Companion to:** `docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md`,
`docs/g4-double-free-guard-readiness.md`
**Mandate:** Block the unconditional default-flip from
producing dangling-pointer bugs in handoff patterns.

This document specifies the per-fn dataflow analysis that
makes the unconditional default-flip safe. Without this pass,
auto-drop-on-by-default produces silent dangling pointers in
patterns like:

```nucleor
fn build_into(reg: Vec<i32>) -> i64 {
    let mut local: Vec<i32> = Vec::new();
    local.push(1);
    vec_push(reg, local);  // local handed off to reg
    return 0;
    // current: auto_drop fires on local; reg dangles
    // FIXED:   pass detects handoff; auto_drop skipped
}
```

## 1. Algorithm spec

The pass runs in `lower_fn` AFTER `auto_drop_register` (which
records all heap-backed locals + their drop helpers) but
BEFORE `auto_drop_emit_live` (which emits the actual drop calls
at fn return).

### 1.1. Inputs

- `auto_drop_*` per-binding state (vname, helper, alloca, state)
  populated by `auto_drop_register` during stmt lowering
- The fn body AST (block_list passed to `lower_fn`)
- The fn's parameter list (plist)

### 1.2. Output

For each binding in the auto_drop registration set, set
`auto_drop_state_<idx> = 0` (suppressed) if the dataflow pass
detects a handoff — meaning the binding's value was passed as
an argument to a call where the receiver is non-local.

### 1.3. Detection rule

A binding `local` is HANDED-OFF if any of:

1. **Vec push handoff:** `vec_push(<receiver>, local)` where
   `<receiver>` is one of:
   - A function parameter (the fn's `plist`)
   - A struct field access on a parameter
   - A global / static name
   - A `vec_get(<receiver>, ...)` chain whose root is a
     parameter / global

2. **Vec set handoff:** `vec_set(<receiver>, <idx>, local)`
   with same receiver-root rules as #1.

3. **HashMap insert handoff:** `hashmap_insert(<receiver>,
   <key>, local)` where `<receiver>` is non-local per #1.

4. **Direct return:** `return local` — bare-name return
   transfers ownership to caller. Already handled by
   `auto_drop_return_skip_name` in current code; G-3 dataflow
   need not duplicate.

5. **Cross-fn argument:** `<extern_fn>(local, ...)` where
   `<extern_fn>` is an `extern fn` declaration. FFI escape;
   conservatively treated as handoff (G-9 territory).

### 1.4. Algorithm

```
for each statement in fn body (in order):
    match stmt:
        ExprStmt(Call(callee, args)):
            if callee in {"vec_push", "vec_set", "hashmap_insert"}:
                receiver = args[0]
                value = args[<last>]  // last arg for push/insert
                                      // index 2 for vec_set
                if is_non_local(receiver, plist) and value is local:
                    mark_handed_off(value.binding)
            elif callee is extern fn name:
                for arg in args:
                    if arg is local:
                        mark_handed_off(arg.binding)
        Return(Call(callee, ...)):
            // recursively check the call's args for handoffs
            ...
        Let(name, init):
            // if init is itself a vec_get/etc. that returns
            // a borrowed local, propagate the handoff state
            ...
```

The pass conservatively marks any binding whose status it can't
determine as HANDED-OFF (avoids dangling-pointer false
negatives at the cost of leaving some leaks intact).

### 1.5. is_non_local determination

A symbol is non-local iff it is:
- A parameter name (in `plist`)
- A global declared at module scope
- A field-access chain rooted at the above

The check: walk the receiver expression's AST, find its root
symbol, look up in the binding scope. If root is a parameter
or unknown (likely global), it's non-local.

### 1.6. Conservative behavior

Cases the simple dataflow won't catch:

- **Aliased through let:** `let r = reg; vec_push(r, local);` —
  the `r` is a local but its VALUE is the parameter's. Need
  alias tracking to follow `r → reg`. Phase 2c work.
- **Pass-through fn call:** `forward(local)` where `forward`
  internally stores `local` into a registry. Cross-fn
  ownership analysis. Phase 2c work.
- **Closure capture:** `let f = || vec_push(reg, local);`
  invocation later. Closure flow tracking. Phase 2c.

For Phase 2b, the simple rule (direct call site, direct
parameter) catches the most common ~80% of handoff patterns.
Phase 2c (alias tracking + cross-fn + closure) closes the rest
before v1.0 cut.

## 2. Implementation plan

### 2.1. New helpers in `compiler/nucleor_s1_compiler.nr`

```nucleor
// Returns 1 iff the receiver expr is non-local (param/global/
// field-access-on-param/global).
fn handoff_is_non_local(pool: Vec<i32>, recv_nid: i64,
                        plist: i64, sym: Vec<i32>) -> i64;

// Walks the fn body, marks bindings handed off via vec_push /
// vec_set / hashmap_insert / extern fn calls. Updates
// auto_drop_state_* sym entries to 0 for handed-off bindings.
fn auto_drop_handoff_check(pool: Vec<i32>, blist: i64,
                            plist: i64, sym: Vec<i32>) -> i64;
```

### 2.2. Wire-up in `lower_fn`

```nucleor
// After all stmt lowering completes; before return paths emit
// auto_drop_emit_live.
auto_drop_handoff_check(pool, blist, plist, sym);
```

### 2.3. Estimated cost

- Per-fn AST walk: O(stmt count). Bounded by fn length.
- Per-statement: small constant (call-arg inspection).
- Total compile-time impact: ~+0.05s on seed self-host (similar
  to other Phase 2b passes per IMPLEMENTATION-PLAN §5).

## 3. Validation

### 3.1. Soundness (positive fixtures — handoff detected)

```nucleor
// fixtures/v0873_handoff_vec_push.nr
fn build_into(reg: Vec<i32>) -> i64 {
    let mut local: Vec<i32> = Vec::new();
    local.push(1);
    vec_push(reg, local);  // detected; auto_drop SKIPPED on local
    return 0;
}
fn main() -> i64 {
    let mut registry: Vec<i32> = Vec::new();
    build_into(registry);
    return vec_len(&registry);  // returns 1, not 0/garbage
}
```

Under unconditional flip + dataflow pass: rc=1 (registry has
1 element, not dangling).

### 3.2. Completeness (negative fixtures — no handoff, drop fires)

```nucleor
// fixtures/v0873_no_handoff_local_only.nr
fn use_local() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(7);
    return vec_len(&v);  // local-only use; auto_drop fires correctly
}
fn main() -> i64 { return use_local(); }
```

Under flip + pass: rc=1, no leak (auto_drop fires on `v`).

### 3.3. Cross-validation

Run `tests/features/rfc0042_auto_drop_vec.nr` (existing
opt-in fixture) — must still produce rc=0 with both
`#[auto_drop]` opt-in AND unconditional flip. Validates the
suppress mechanism stays correct.

## 4. Sequence to v1.0

```
v0.8.71  Honest readiness assessment           DONE
v0.8.72  This design doc                       DONE (this ship)
v0.8.73  Implement auto_drop_handoff_check     NEXT
v0.8.74  Test fixtures + smoke validation      after 73
v0.8.75  Run unconditional flip on attn rod    after 74
         (reproduces v0.8.65 segfault → now safe)
v0.8.76+ Iterate: identify any remaining gaps  multi-ship
v0.9.0   Phase 2b-3 final unconditional flip   when validation green
v0.9.x   Migration window — adopters opt out
         via #[manual_drop] for any remaining
         handoff patterns
v1.0     Hard error promotion                  v1.0 cut
```

## 5. Updates log

- **2026-05-04** v0.8.72: design doc drafted. Algorithm spec,
  detection rule, conservative behavior, implementation plan,
  validation fixtures, sequence to v1.0.
