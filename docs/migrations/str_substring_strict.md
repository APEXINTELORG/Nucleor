# `str_substring_strict` Migration Guide

`str_substring(s, start, end)` is the hot-path substring helper. It is fast
because it does not call `strlen(s)` on every use. It checks cheap invalid
ranges such as negative `start` and `end < start`, then copies `end - start`
bytes.

That speed matters in compiler and parser loops, but it also means callers must
prove `end <= str_len(s)` before calling it. If a port is not already carrying
that proof, use `str_substring_strict(s, start, end)` instead.

## When To Migrate

Use `str_substring_strict` when:

- `start` or `end` comes from user input, file input, network input, or a parsed
  offset that is not already range-checked.
- You are porting Rust or C++ code that expects slice bounds to trap instead of
  reading past the string terminator.
- The substring is outside a lexer/parser hot loop where the caller already has
  a local `slen` and loop invariant proving bounds.

Keep `str_substring` when:

- The caller has already computed `let slen: i64 = str_len(s);` and checked the
  selected range.
- The call sits in a hot loop over a known source buffer and each index is
  controlled by that loop.

## Mechanical Rewrite

Before:

```nr
let token: str = str_substring(line, start, end);
```

If bounds are not already proven:

```nr
let token: str = str_substring_strict(line, start, end);
```

If bounds are already proven, keep the fast helper and leave the proof close to
the call:

```nr
let slen: i64 = str_len(line);
if start < 0 || end < start || end > slen { panic("bad substring range"); };
let token: str = str_substring(line, start, end);
```

## Runtime Behavior

`str_substring_strict` returns the same bytes as `str_substring` for valid
ranges. On invalid ranges, it exits with a panic message that includes
`str_substring_strict OOB` plus the requested `start`, `end`, and string length.

This helper intentionally pays an `O(strlen(s))` check. Do not bulk-rewrite
compiler hot loops without measuring the result under the memory and compile
time gates.
