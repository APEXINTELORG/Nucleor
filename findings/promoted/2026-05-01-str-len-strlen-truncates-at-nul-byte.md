---
title: `str_len(s)` calls C `strlen` which truncates at the first NUL byte. Strings containing embedded NUL bytes report a shorter length than their actual byte content.
severity: silent-miscompute (ABI assumption — str is null-terminated)
probe_file: probes/strings/str_len_nul_byte.nr (probe-branch)
diagnostic_actual: pre-fix — embedded NUL truncates length silently
diagnostic_expected: length-tagged str type or warn-on-NUL-byte detection
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — `str` in Nucleor is null-terminated by ABI design (the i64-everywhere ABI passes str as `char *`). Embedded NULs are a known limitation. Forward-roadmap: length-tagged str ABI rewrite (significant — touches every str runtime helper). Meanwhile adopters needing binary-safe strings use `Vec<u8>` for byte content.
---

## Closure (analysis-only — no compiler change)

The Nucleor v0.6 str ABI follows C convention: `str` is a
NUL-terminated `char *`. Every str runtime helper
(`__nucleor_str_len`, `__nucleor_str_concat`,
`__nucleor_str_substring`, etc.) calls into C string functions
(`strlen`, `strcpy`, `strncpy`) that respect NUL termination.

For binary content (file bytes, network payloads, hashes,
encryption output), the str type is unsuitable. Adopters use
`Vec<u8>` for byte buffers; the runtime helpers `vec_u8_*`
operate on length-tagged byte vectors and are NUL-safe.

### Why deferred

A length-tagged str ABI requires:

1. New header struct: `{ char *data; size_t len; }`.
2. Rewrite of every `__nucleor_str_*` runtime helper (~30
   helpers).
3. Update of every str literal emission to include the length
   tag.
4. Migration of every fixture using str helpers (cross-cutting
   adopter break).

That's the kind of cross-cutting ABI change the project memory
explicitly defers as "high-risk; needs dedicated cycle." Bundled
with the v1 ABI cleanup workstream.

## Adopter migration

```nucleor
// Pre-fix (NUL truncates):
let s: str = "hello\u{0}world";    // embedded NUL
print_int(str_len(s) as i32);       // prints 5 (truncates at NUL)

// v0.6 binary-safe alternative (Vec<u8>):
let mut bytes: Vec<u8> = Vec::new();
let s: str = "hello\u{0}world";
let mut i: i64 = 0;
while i < 11 {
    vec_u8_push(bytes, str_char_at(s, i));
    i = i + 1;
};
print_int(vec_u8_len(bytes) as i32);    // 11 (full length preserved)
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
