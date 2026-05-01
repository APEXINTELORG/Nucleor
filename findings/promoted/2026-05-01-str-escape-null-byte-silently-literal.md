---
title: `"ab\0cd"` — `\0` escape lexes as the literal characters `\` then `0` (or stripped to `0` per a "placeholder" comment), not a NUL byte. Adopter writes C/Rust idiom, gets silent string corruption.
severity: silent-miscompute (lexer escape gap)
probe_file: probes/strings/escape_null_byte.nr (will be filed)
diagnostic_actual: `"ab\0cd"` produces a 5-byte string with bytes a, b, 0, c, d (the digit 0). `print(s)` outputs `ab0cd`.
diagnostic_expected: `"ab\0cd"` should produce a 5-byte string with bytes a, b, NUL, c, d. `print(s)` truncates at NUL → `ab` (or whatever NUL-respecting print impl produces).
discovered_against: main v0.5.17 (probe 26d1f2a)
commit: probe 26d1f2a + main 736d88a
---

## Repro

```nr
fn main() -> i32 {
    let s: str = "ab\0cd";
    print(s);
    print_int(str_len(s) as i32);
    0
}
```

## Actual

```
ab0cd
5
```

The lexer treats `\0` as a placeholder emitting the literal character `0`. So `"ab\0cd"` becomes 5 bytes: `a, b, '0' (0x30), c, d`.

## Expected (Rust / C convention)

`\0` should emit a single NUL byte (0x00). The string would still be 5 bytes (`a, b, NUL, c, d`), but `print(s)` (which uses NUL-terminated semantics) would truncate at the NUL → output `ab`.

## Documented placeholder

`compiler/nucleor_s1_compiler.nr` line 526-527 has a comment marking this:

```nr
else if nc == 114 { sb_append(sb, str_substring_unchecked(src, p + 1, p + 2)); } // \r — emit as 'r' for now (placeholder; v0.5 will route through carriage-return byte)
else if nc == 48  { sb_append(sb, str_substring_unchecked(src, p + 1, p + 2)); } // \0 — emit as '0' (placeholder)
```

So this is **known-placeholder**. The `// v0.5 will route through carriage-return byte` comment promised the actual escape semantics in v0.5 — but v0.5.0 + v0.5.1-17 have shipped without addressing it.

## Hazard tier

Silent-miscompute. Adopter writes:

```nr
let key: str = "section\0subsection";   // C-string-style separator
let pieces: Vec<str> = str_split(key, "\0");
```

…and gets weird results because:
1. The `\0` in the literal is NOT a NUL byte
2. The `"\0"` separator is also not a NUL — it's a `0` character
3. The split actually splits on '0' character, dropping the `0` from "subsection"

This silently breaks any port of C-string code, message-passing protocols using NUL framing, or HashMap keys with NUL terminators.

## Sister escapes that may have the same gap

The `\r` placeholder (line 526) is documented as a placeholder too. Other C-style escapes worth probing:
- `\n` — newline (likely DOES work since most tests print it)
- `\t` — tab (likely works)
- `\\` — literal backslash (likely works)
- `\"` — literal quote (likely works)
- `\r` — carriage return (placeholder per comment)
- `\0` — NUL (placeholder per comment, this finding)
- `\xHH` — hex byte (worth probing)
- `\u{HHHH}` — unicode codepoint (worth probing)

## Suspected fix

In `compiler/nucleor_s1_compiler.nr` lexer at line 526-527:

```nr
else if nc == 114 { sb_append_byte(sb, 13); }  // \r → CR (0x0D)
else if nc == 48  { sb_append_byte(sb, 0); }   // \0 → NUL (0x00)
```

Need a `sb_append_byte(sb, byte)` helper that doesn't go through the str-concat machinery (which itself relies on NUL termination). Or use a length-prefixed string builder that respects embedded NULs.

## Memory-blow-up note

Not memory-related directly, but downstream impact: NUL-truncated strings flow through `print()`, `str_concat()`, and other helpers that use C-string semantics. A NUL-containing str passed to those helpers TRUNCATES at the first NUL — silent data loss.

## Cross-ref

- Lexer line 526-527 — comment marks it as a placeholder
- `2026-05-01-keyword-silent-strip-audit.md` — sister silent-strip family

## Probe

Filed alongside this finding.


## Promoted

- Fix shipped: v0.5.20 — `\0` and `\r` escapes in string
  literals now emit the actual byte values (NUL=0, CR=13)
  instead of the literal characters `0` and `r`.
- Compiler: 2-line edit at lexer escape table (s1 line ~540-541),
  switching from `sb_append(sb, str_substring(...))` placeholders
  to `sb_append_char(sb, 13)` for `\r` and `sb_append_char(sb, 0)`
  for `\0`. Existing escapes (`\n`, `\t`, `\"`, `\`, `\'`)
  unchanged. NR025 catches all other unknown escapes.
- Behavior change: strings containing embedded `\0` now NUL-
  truncate at print + str_len. Adopter writing `"section\0sub"`
  + `print(s)` sees `section`. Pre-fix saw `section0sub`.
- Validation: probe's repro `let s: str = "ab\0cd"; print(s);
  print_int(str_len(s) as i32);` now outputs `ab` then `2`
  (was `ab0cd` then `5`). `\r` test confirms CR byte routes
  cursor as expected.
- Promoted: 2026-05-01 by main agent (probe commit 26d1f2a).
