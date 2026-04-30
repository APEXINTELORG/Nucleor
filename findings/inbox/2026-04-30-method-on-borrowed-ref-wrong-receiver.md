---
title: method-style call on `&S` receiver lowers via Vec catch-all and reports wrong receiver type
severity: wrong-error
probe_file: probes/borrows/method_on_ref.nr
diagnostic_actual: "error[TYP-005]: receiver type `Vec<T>` has no method `.S_get()`. (Internal symbol: `vec_S_get`. The kind-8 method-dispatch catch-all lowered the call to a synthetic helper that doesn't exist.)"
diagnostic_expected: either (a) successful dispatch — `r.S_get()` resolves to `S_get(r)` since `r: &S` and `S_get` takes `self: &S`, OR (b) a clean diagnostic naming the actual receiver type (`&S`) and explaining method dispatch on borrowed references is not yet supported
discovered_against: v0.4.162
commit: a99fc717079b8f7774c8ddf7aa03a4cc5e132eae
---

## Repro

```nr
struct S { x: i32 }

fn S_get(self: &S) -> i32 { self.x }

fn main() -> i32 {
    let s: S = S { x: 7 };
    let r: &S = &s;
    print_int(r.S_get());
    print_int((&s).S_get());
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/borrows/method_on_ref.nr -o method_on_ref
  source: probes/borrows/method_on_ref.nr (188 bytes)
  mode: fast (ownership + type)
  functions: 2
  strings: 0
  optimized: 0 instructions
  DCE: 1 of 2 fns elided as unreachable
  emitted: target/method_on_ref.ll (38071 bytes)
error[TYP-005]: receiver type `Vec<T>` has no method `.S_get()`. (Internal symbol:
                `vec_S_get`. The kind-8 method-dispatch catch-all lowered the call
                to a synthetic helper that doesn't exist.)
                Supported Vec method families: push, pop, len, get, set, first, ...
  COMPILE FAILED (clang exit 1)
```

Two distinct things go wrong:

1. **Wrong receiver type in the diagnostic.** The receiver `r` is `&S`, not `Vec<T>`. The user is told their type is something it isn't.
2. **Method dispatch on `&S` is silently routed through the Vec catch-all.** The kind-8 method-dispatch path synthesizes `vec_S_get` instead of either (a) auto-deref-ing `&S` → `S` and calling `S_get(r)`, or (b) raising a "method dispatch on borrowed ref unsupported" error.

Note: field access through the same `&S` works fine — `tests/features/borrow_basic.nr` does `print_int(r.x)` for `r: &Point`. So the type system clearly knows `r: &S`. The method-dispatch path just throws the receiver-type information away.

The compiler exits non-zero, so no silent miscompile. But adopters seeing "receiver type `Vec<T>`" on a `&S` will be very confused — this is a misleading diagnostic.

## Expected

If borrow-method dispatch is intended to work in v0.4 (free fns with `self: &T` receiver), the call should compile and the program should print `7\n7`.

If it's a deferred feature, the diagnostic should:
- name the actual receiver type (`&S`),
- not invent a synthetic `vec_S_get` symbol,
- not list "Supported Vec method families" (the receiver isn't a Vec),
- ideally point at the deferral RFC.

## Suspected location

The diagnostic mentions a "kind-8 method-dispatch catch-all". `grep` in `compiler/nucleor_s1_compiler.nr` for that path — when receiver kind doesn't match any known dispatch table, it appears to fall through to the Vec lowering and synthesize `vec_<method>` regardless of actual type. The fix is probably to:

1. Detect kind = borrow (`&T`) before the Vec catch-all.
2. Either auto-deref to T's method set, or raise a typed error saying "method dispatch on `&T` not yet supported" with the actual `&T` printed.

I did not chase the exact line — the Vec catch-all is likely a single early-exit branch easy to find by grepping `vec_` in the dispatch lowering.
