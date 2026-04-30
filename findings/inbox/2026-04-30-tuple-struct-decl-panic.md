---
title: tuple-struct decl `struct P(i32, i32);` produces PANIC with raw token IDs, not a user-grade diagnostic
severity: wrong-error
probe_file: probes/casts/tuple_struct_field.nr
diagnostic_actual: PANIC: error[NR020] (raw "expected token 52 got 50")
diagnostic_expected: PARSE-NNN: tuple struct syntax not supported (use brace fields), OR a clean PARSE error pointing at `(` after struct name
discovered_against: v0.4.162
commit: a99fc717079b8f7774c8ddf7aa03a4cc5e132eae
---

## Repro

```nr
struct P(i32, i32);

fn main() -> i32 {
    let p: P = P(1, 2);
    print_int(p.0);
    print_int(p.1);
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/casts/tuple_struct_field.nr -o tuple_struct_field
  source: probes/casts/tuple_struct_field.nr (112 bytes)
  mode: fast (ownership + type)
PANIC: error[NR020]: parse error at token position 8: expected token 52 got 50 — pre-fix this printed a warning and continued, producing a likely-broken binary.
```

The diagnostic:
- Begins with `PANIC:` (compiler-internal panic prefix, not a user-facing error mode).
- Refers to internal token IDs (`52`, `50`) that the user cannot interpret.
- Has no source span / `-->` line / `^` caret pointing at the offending `(` after `struct P`.
- Mentions a "pre-fix" message that doesn't apply here.

The compiler exits non-zero, so it does fail closed (no silent miscompile), but the diagnostic surface is opaque.

## Expected

A user-grade PARSE-class diagnostic, e.g.:

```
error[PARSE-NNN]: expected `{` after struct name (tuple struct syntax not yet supported)
  --> probes/casts/tuple_struct_field.nr:1:9
  |
1 | struct P(i32, i32);
  |         ^ expected `{` here
```

…OR if tuple structs are an intentional v0.5+ deferral, the message should say so explicitly.

## Suspected location

`compiler/nucleor_s1_compiler.nr:2319`:

```
cp = expect_tok(tokens, cp, 52); // {
```

Inside `parse_struct_decl`. When the post-name token is `(` (50) rather than `<` (32, generics) or `{` (52, brace fields), `expect_tok` falls through to the generic NR020 panic helper instead of raising a tuple-struct-aware diagnostic. Either:

- gate `parse_struct_decl` to recognize `(` and synthesize positional-named fields (`0`, `1`, …) — see `parse_struct_init` shorthand pattern at line 2365 for similar synthesis, OR
- emit a clean PARSE-NNN with a span before reaching `expect_tok`, naming this as a deferral if so.

Cross-check: `docs/milestones/v0.4.0.md` and `docs/rfcs/RFC-0023-pattern-matching.md` reference *tuple-style enum variants* as a deferred feature, but I could not find an explicit tuple-struct-decl deferral statement, so the status of this syntax is ambiguous.
