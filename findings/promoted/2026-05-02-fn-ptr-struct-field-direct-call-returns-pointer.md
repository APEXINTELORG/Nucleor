---
title: `(struct.field)(args)` where `field` is a fn-pointer silently returned the pointer address instead of calling it. Workaround: extract the field to a local variable first, then call. Adopters writing canonical Rust dispatch-table-via-struct pattern hit this immediately.
severity: silent-miscompute (canonical Rust idiom returned pointer address instead of call result)
probe_file: probes/types/fn_ptr_struct_field.nr (probe-branch)
diagnostic_actual: pre-fix — build + run succeeded; `(o.f)(21)` outputted a fn-pointer memory address instead of `42` (the result of `dbl(21)`).
diagnostic_expected: clean halt at parse time with workaround pointer (extract fn-pointer to local), or — eventual real fix — parse `(expr)(args)` as an indirect-call expression and emit inttoptr + call IR.
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main f78d922
status: PARTIAL — clean halt with workaround pointer shipped v0.6.12. Real indirect-call lowering deferred to a follow-on RFC ship.
---

## v0.6.12 closure shape

The probe-branch finding documents three failing shapes:

| Shape | Pre-v0.6.12 | Post-v0.6.12 |
|---|---|---|
| `(struct.field)(args)` | ❌ silent address-output | ✅ clean halt with workaround |
| `(vec_get(&ops, i))(args)` | ❌ silent address-output | ✅ clean halt with workaround |
| `(arr[i])(args)` (presumed) | ❌ silent address-output | ✅ clean halt with workaround |

All three lower to the same underlying parse path — a parenthesized
expression of kind-9 (field), kind-10 (index), or kind-8 (method-call)
followed by a `(args)` postfix. v0.6.12 detects the shape at parse time
and panics with a clear diagnostic + workaround pointer.

## Repro (now halts)

```nr
struct Op { f: fn(i64) -> i64 }
fn dbl(x: i64) -> i64 { return x * 2; }

fn main() -> i32 {
    let o: Op = Op { f: dbl };
    print_int((o.f)(21) as i32);  // halts at parse time with workaround
    return 0;
}
```

## Workaround that always worked

```nr
let o: Op = Op { f: dbl };
let f: fn(i64) -> i64 = o.f;
print_int(f(21) as i32);  // 42 ✓
```

## Closure (main agent v0.6.12)

`compiler/nucleor_s1_compiler.nr` — at the `tt == 50` branch of
`parse_primary`, after consuming the inner expression and the closing
`)`, check whether the next token is `(`. If so AND the inner expression
is one of kind-9 / kind-10 / kind-8, emit a clean ERROR diagnostic
naming the pattern + the working workaround, then panic. Closes the
silent-miscompute window.

## Real fix — deferred

The complete fix requires:

1. **Parser extension:** allow `(args)` postfix in `parse_postfix` on
   any callable-typed expression (not just identifier-prefixed direct
   calls).
2. **AST shape:** introduce an indirect-call kind whose callee is a
   pool-id (rather than the current kind-7 string-name shape), or
   extend kind-7 with an alternative encoding for indirect callees.
3. **Codegen:** for an indirect-call kind, lower the callee expression
   to an i64 register, `inttoptr i64 %r to ptr`, then emit
   `call i64 %r.fp(<args>)`.
4. **Type-check:** verify the callee expression's type is a fn-pointer
   matching the args/return shape.

All four parts are forward-roadmap; a follow-on ship will close the
indirect-call shape end-to-end. Until then, the halt + workaround
keeps adopters out of the silent-miscompute window.

## Cross-ref

- Original probe finding (probe-branch inbox): same slug.
- Sister findings: `2026-05-02-print-fn-adds-newline-macro-does-not.md`
  (fn-form vs other-form mismatch family).

## Promoted

- Fixture: `tests/err/err_fn_ptr_struct_field_direct_call.nr` (negative).
- Fix shipped: v0.6.12 (clean halt). Real indirect-call lowering: deferred.
- Promoted: 2026-05-02 PM by main agent (probe commit `c4a76e2` on
  `origin/probe/exploration`).
