---
title: All str RUNTIME helpers (`str_len`, `str_concat`, `str_substring`, etc.) reject the `&s` form with TYP-006 "must be str (runtime helper)" — only the bare `s` form is accepted. The new v0.6.15 NUCLEOR-SIDE wrapper `str_substring_strict` accepts BOTH `s` and `&s`. Adopters porting from Rust (where `&str` is the canonical form) hit TYP-006 on every str-helper call site and have to mechanically strip `&` everywhere.
severity: translation-fidelity (ergonomic — affects every adopter porting Rust str code)
probe_file: probes/strings/str_runtime_helper_ref_inconsistency.nr (probe-branch)
diagnostic_actual: pre-fix — TYP-006 on every `&s` argument to `str_len`/`str_concat`/`str_substring`/`print`/etc.
diagnostic_expected: parity — both `s` and `&s` accepted, since `&s` lowers identically to `s` in the IR.
discovered_against: main v0.6.15 (probe rebased)
commit: probe (post-rebase) + main 1224b2f
status: CLOSED in v0.6.48 — TYP-006 arg-0 and arg-1 checks now also accept `&str`. The IR side was already a pass-through for kind-90 unary-ref.
---

## Closure (main agent v0.6.48)

`compiler/nucleor_s1_compiler.nr` lines ~16765 and ~16823. The
TYP-006 emitter previously fired when the argument type was not
`str` and not `_`. Now it also exempts `&str`:

```nucleor
if str_len(arg0_t) > 0
    && str_eq(arg0_t, "str") == 0
    && str_eq(arg0_t, "&str") == 0   // <-- v0.6.48 added
    && str_eq(arg0_t, "_") == 0 {
    type_diag(diags, source, fn_name, callee, "TYP-006", ...);
};
```

Same change applied to the arg-1 check that covers `str_eq`,
`str_concat`, `str_contains`, `str_starts_with`, `str_ends_with`,
`str_index_of`, `str_split`, `str_replace`.

The lower side already handled both forms identically: `kind == 90`
in `lower_expr` (line ~19462) is a pass-through that returns the
inner expression unchanged, so `&s` and `s` produce the same IR
register and the runtime helper sees the same i64 string pointer.

## Adopter migration

```nucleor
let s: str = "hello";

// Both forms now compile:
print_int(str_len(s) as i32);    // 5
print_int(str_len(&s) as i32);   // 5

let a: str = str_concat(s, " world");   // works
let b: str = str_concat(&s, " world");  // works (was TYP-006)

print(s);    // works
print(&s);   // works (was TYP-006)
```

Adopters porting Rust code where `&str` is canonical no longer have
to mechanically strip `&` from every helper call site.

## Forward-roadmap

This widens the accept set for str runtime helpers; symmetric
ergonomic gaps in `str_to_int_strict`, `str_substring_strict`, etc.
were already accepting both forms by virtue of being off the
diag's allow-list. v0.6.48 brings the rest into parity.

Future ships could extend the same parity to all i64-pointer-shaped
runtime helpers (Vec helpers, HashMap helpers, etc.) where
borrow-vs-owned distinction is purely syntactic at this ABI layer.

## Promoted

- New fixture: `tests/fixtures/v0648_str_helper_amp_accepted.nr`.
- New verify step: `v0648_str_helper_amp_accepted` (asserts
  `str_len(&s) == 5`, `str_concat(&a, &b)` and `print(&s)` work).
- Fix shipped: v0.6.48.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
