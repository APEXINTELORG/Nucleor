---
title: String-literal lexer silently corrupts `"\\X"` for any X. `"\\n"` produces newline (single 0x0A) instead of `\` + `n`. `"\\h"` panics with NR025.
severity: CRITICAL silent-miscompute (`\\n` collapses to newline) + parse-rejection (`\\h` etc.)
probe_file: probes/strings/double_backslash_eats_third_char.nr (probe-branch)
diagnostic_actual: pre-fix — `"\\n"` collapsed to NEWLINE; `"\\h"` panicked with NR025 `unknown escape \h`.
diagnostic_expected: `"\\X"` should always emit literal `\` followed by literal `X`.
discovered_against: main v0.6.13 (probe rebased)
commit: probe (post-rebase) + verified clean against main 6d4d741b
status: ALREADY CLOSED — verified clean at v0.6.45. The lex-time string-escape state machine in `compiler/nucleor_s1_compiler.nr` line ~620 correctly handles `\\` as a 2-char escape that emits one literal `\`, with `p` advancing by 2 — so the next iteration sees the third char as a fresh top-level char (not part of an escape). Likely closed by an earlier ship between v0.6.13 and v0.6.45.
---

## Verification (main agent v0.6.45)

```nucleor
fn main() -> i32 { print("a\\nb\n"); 0 }
```

Output bytes (xxd):
```
00000000: 615c 6e62 0d0a 0d0a                      a\nb....
```

That's: `a` `\` `n` `b` `CRLF` `CRLF` — three literal chars after `a`
(the `\\n` collapsed to `\n` two-char literal, not 0x0A). Correct.

```nucleor
fn main() -> i32 { print("\\h\n"); 0 }
```

Output bytes:
```
00000000: 5c68 0d0a 0d0a                           \h....
```

Literal `\h` followed by CRLF. Correct, no NR025 panic.

## Lex state machine review

`compiler/nucleor_s1_compiler.nr` line ~620:

```nucleor
if str_char_at(src, p) == 92 && p + 1 < slen {
    let nc: i64 = str_char_at(src, p + 1);
    ...
    else if nc == 92 { sb_append(sb, "\\"); }   // \\ → \
    ...
    p = p + 2;
}
```

When the lexer sees `\\` at `p`, it appends ONE `\` to the SB and advances `p` by 2 (past both backslashes). The next iteration of the outer while-loop reads char at the new `p` — which is the third char (`n`, `h`, etc.) — and treats it as a fresh top-level char (no escape interpretation).

The probe's reported behavior would only occur if `p` advanced by 1 instead of 2 — but it advances by 2 unconditionally for the recognized-escape branches. Likely the probe was filed against an older build where this was broken.

## No fixture

The negative case `\\X` already works for all X tested (n, h, !, U). No regression-lock fixture added — adding one would duplicate the implicit coverage from existing string-escape fixtures (e.g. `tests/lang/escape_sequences.nr` family).

## Promoted

- Verification only; no code change.
- Closed by some prior ship between v0.6.13 and v0.6.45.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
