# Recon Audit Pass 1 — Layer 1: Lexer / Parser / AST

**Date:** 2026-05-08
**Compiler:** Nucleor v1.0.0 (`bin/nucleor.exe`)
**Scope:** lexer, parser, AST integrity only
**Methodology:** systematic enumeration + 7-axis coverage + minimal-reproducer test cases

## Summary

| Severity | Count |
|---|---|
| Critical | 6 |
| High | 18 |
| Medium | 12 |
| Low | 8 |
| Note | 4 |

(Critical = compiler crash/hang/silent miscompile; High = wrong diagnostic, accepted-when-shouldn't, rejected-when-shouldn't; Medium = poor diagnostic quality but correct accept/reject; Low = cosmetic / documentation gap; Note = observation, not a defect)

## Coverage Map

| Axis | Items checked | Items skipped | Reason for skip |
|---|---|---|---|
| Functional | All operator/punct tokens (kinds 2,3,20-24,30-46,50-58,64,82,94,96,97,110-122,124,125,130,131); core productions: fn/let/if/while/for/return/match/struct/enum/extern/import/closure/struct-init/generic-params/type/expr-precedence chain | trait/impl decls, attribute parser internals, pure-fn keyword path | tangential to lex/parse integrity, downstream coverage; surface-area only check via reading parse_trait_decl/parse_impl_block didn't reveal extra bugs at this pass |
| Edge | Empty input, whitespace-only, comment-only, no-trailing-newline, near-max int literals (i64/u64 boundaries, 10000-digit), 10K-char ident, 1MB string, 10K let-bindings, deep paren/block/if/index/turbofish | Identifier max-length test (no documented cap; tested at 10K chars and worked) | n/a |
| Adversarial | Unbal `{`/`(`, extra `}`/`)`, garbage at top level (`@#$%^&*~`), tilde, dollar, bare backslash, NUL byte mid-source, BOM, smart quotes, zero-width space, RTL ident, combining char, mid-token EOF, all common bad escape forms (`\v`, `\x`, `\u`, `\<eof>`), unterminated string at EOF, unterminated string with newline, leading-zero int (`007`), `0x`/`0b`/`0o` no digits, `0x_`, `0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF`, `1__2`, `100_`, `_100`, `.5`, `1.`, `1z42`, `1i9`, `0xZ`, `1e400` (overflow), char `''`, char `'ab'`, three apostrophes, mismatched quotes, raw newline in string, raw CR in string, `}}}` extra closes, `(((` `)))`, `;;;;`, `1 2 3 4 5;`, `let x: i64 = 1` with no semicolon, `(a, b) = (...)`, `==== `, `1 + + + + + 2`, missing-comma in match arms, `h(1,, 2)`, `h(,1)`, `let x: 1 + 1 = 5`, `let x:` then EOF, `let x: ;`, `import "<<<>>>"`, `import` w/o quotes, `import ""`, `extern fn foo() -> i64 { body }`, top-level `return 0;`/`break;`, `r#name`/`r"..."`/`b"..."`/`c"..."`/`b'A'` (caught by halts), `'\u{...}'`, `||;`, deep closure | Path-traversal in import strings (out of scope this pass) | n/a |
| Attack Surface | Stack overflow via deep nested if (>3000 levels), deep blocks (>3000), deep paren/index nesting, large hex literal overflow, malicious file size (5MB single comment, 1MB string), NUL byte truncation, malformed UTF-8 bytes via unknown-byte fall-through, segfault on `let x: <expr> = ...` (NULL deref), pathological generic depth | DoS via recursive include cycles (cross-layer; needs module resolver), regex/pattern bombs (no backtracking parser to attack) | OOS or no surface |
| Diagnostic | Token-name table for NR020 (kinds 21, 30, 45, 64, 115, 122 etc), unterm-string byte position, malformed-let position, range-EOF position, unknown-escape position, char-literal misclassification | Multi-line span emission, line/col vs byte | not enough surface in lex/parse to differentiate |
| Unicode | UTF-8 idents (Latin-extended, Hebrew, Japanese), UTF-8 strings, BOM, smart quotes, zero-width space, combining marks, RTL text, NUL byte, emoji in string, mixed scripts | Normalization (NFC/NFD), Unicode-version pinning | spec says ASCII idents only — those should reject |
| Source variations | LF, CRLF, CR-only, mixed, no-trailing-newline, leading whitespace, tab vs spaces (lexed as `is_ws`), trailing whitespace, BOM | Form-feed (`\f`), vertical-tab (`\v`) as whitespace | `is_ws` enumeration not yet inspected, tested behaviorally instead |

## Findings

### F-001 [Critical] [Crash] Compiler segfaults on expression in type position
**Reproducer:** `audit_scratch_lexer_parser/expr_type.nr`
```nr
fn main() -> i32 { let x: 1 + 1 = 5; return 0; }
```
**Command:** `bin/nucleor.exe build audit_scratch_lexer_parser/expr_type.nr -o /tmp/x.exe`
**Observed:** `Segmentation fault` (exit 139). Output: only "  source: ... (50 bytes)\n  mode: fast (ownership + type)" then SIGSEGV.
**Expected:** A clean parse error pointing at byte 26 (the `1` after `:`) saying "expected type, got integer literal". Per language reference §3 every parameter has a type annotation; types are spelled out (e.g. `i64`, `Vec<T>`, struct names, etc.).
**Notes:** Reproducible on cache-hit too. NULL deref in parse_type when fed an expression token. Pure adversarial `.nr` input crashes the compiler.

### F-002 [Critical] [Stack overflow] Deep `if` nesting hangs/crashes parser around 4000 levels
**Reproducer:** `audit_scratch_lexer_parser/deep_if_4000.nr` (100KB, 4000 nested `if 1==1 { ... };` blocks)
**Command:** `./bin/nucleor.exe build audit_scratch_lexer_parser/deep_if_4000.nr -o ...`
**Observed:** Exit 127 (process killed, stack overflow). 3000-level passes; 4000-level fails.
**Expected:** Either parse cleanly, or emit a clean depth-exceeded diagnostic with line/byte info.
**Notes:** Sister cases: `deep_block_5000.nr` (5000 nested `{ ... };`) and `deep_index_2000.nr` (`a[0][0]...` 2000-deep) both exit 127 with same symptom. Adversarial `.nr` input < 100KB DOSes the compiler. The recursive descent parser has no depth guard.

### F-003 [Critical] [Silent accept] Stray top-level garbage characters silently accepted
**Reproducer:** `audit_scratch_lexer_parser/garbage_top.nr`
```nr
@#$%^&*~`
fn main() -> i32 { return 0; }
```
**Command:** `./bin/nucleor.exe build audit_scratch_lexer_parser/garbage_top.nr -o ...`
**Observed:** Exit 0. Compiles cleanly, runs cleanly.
**Expected:** A lex-time diagnostic for unknown bytes (e.g. `~`, `` ` ``, `$`). Per language reference §1.6 the operator set is enumerated; anything else should be a NR0xx diag.
**Notes:** Root cause: lexer line 1046 — `else { p = p + 1; };` — every unknown byte is silently consumed with no token emission. This is the central enabling bug for many other findings (F-004 through F-014). Single-byte unknowns: `~`, `$`, ``\`` (alone), `` ` ``, smart quotes (`“”`), zero-width space, BOM, every byte of any non-ASCII identifier, etc.

### F-004 [High] [Silent accept] Bare `~` (tilde) silently dropped in expression position
**Reproducer:** `audit_scratch_lexer_parser/tilde.nr` — `let x: i64 = ~5;`
**Observed:** Exit 0; IR shows `r.1 = 5`. The `~` is dropped, leaving `let x: i64 = 5;`.
**Expected:** Lex error or NR020 parse error (Rust uses `!` for bitwise-not; Nucleor doesn't define `~`).
**Notes:** Same root cause as F-003. Hazardous for translators porting from C/C++ (where `~` is bitwise NOT).

### F-005 [High] [Silent accept] Bare `$` silently dropped in identifier position
**Reproducer:** `audit_scratch_lexer_parser/dollar.nr` — `let $x: i64 = 5;`
**Observed:** Exit 0. The `$` is dropped, `let x: i64 = 5;` is produced.
**Expected:** Lex error. Per language reference §1.3, ident grammar is `[A-Za-z_][A-Za-z0-9_]*`; `$` is not in either.

### F-006 [High] [Silent accept] Bare `\` (backslash) silently dropped
**Reproducer:** `audit_scratch_lexer_parser/backslash_alone.nr` — `let x: i64 = 1 \ 2;`
**Observed:** Exit 0. IR shows just `1` (the `\ 2` is silently dropped because the lexer's `\\` continuation rule (line 437–439) only triggers when followed by ` ` (space) AND consumes through `\n`. With `1 \ 2;` the `\<space>` matches, scans to next newline — silently consuming the rest of the let body.
**Expected:** Reject `\` as unknown lexeme.
**Notes:** Worse than F-003: line 437 has `else if c == 92 && p + 1 < slen && str_char_at(src, p + 1) == 32 { while p < slen && str_char_at(src, p) != 10 { p = p + 1; }; }` — this is an undocumented "line-continuation" syntax that swallows everything to next newline. Not in language reference. Easy footgun: `1 \ 2 + 3;` silently drops `2 + 3`.

### F-007 [High] [Silent accept] BOM byte (UTF-8 EF BB BF) silently consumed at file start
**Reproducer:** `audit_scratch_lexer_parser/bom.nr` (UTF-8 BOM + `fn main() -> i32 { return 0; }`)
**Observed:** Exit 0. The 3 BOM bytes consumed via fall-through unknown-byte skip. File reports 34 bytes (31 source + 3 BOM).
**Expected:** Either explicitly recognize+skip BOM, or emit a hint that BOMs are not part of the language. Currently it works "by accident" through the unknown-byte fall-through; if any of the BOM bytes had been a punct lookalike (e.g. `0xFF`) the behavior would have differed.

### F-008 [High] [Silent accept] Smart quotes silently dropped (no diagnostic)
**Reproducer:** `audit_scratch_lexer_parser/curly_q.nr` — `“fn main() -> i32 { return 0; }”`
**Observed:** Exit 0. The smart quotes' UTF-8 bytes (3 bytes each) are consumed via fall-through.
**Expected:** Either lex error (reject UTF-8 bytes outside identifier scope) or hint that ASCII straight quotes are required.
**Notes:** Common copy-from-docs failure mode.

### F-009 [High] [Silent accept] Zero-width space inside keyword silently consumed
**Reproducer:** `audit_scratch_lexer_parser/zero_width.nr` — `fn​main() -> i32 { return 0; }` (U+200B between `fn` and `main`)
**Observed:** Exit 0. The 3 ZWSP bytes silently dropped. Source reads 34 bytes.
**Expected:** Lex error. ZWSP is invisible and security-relevant (homograph/spoofing attacks).
**Notes:** Known supply-chain attack vector (Trojan Source CVE-2021-42574 family).

### F-010 [High] [Wrong-class] Non-ASCII identifier characters silently consumed mid-source
**Reproducer:** `audit_scratch_lexer_parser/rtl_text.nr` — `let עברית: i64 = 1;`
**Observed:** Exit 1, but with wrong-class diag `error[OWN-008]: cannot assign to immutable binding 'i64'`. The Hebrew bytes were consumed via fall-through, leaving `let : i64 = 1;` in the token stream — which the parser misread as `let` with empty name and `i64` as the type expression.
**Expected:** Lex error citing the non-ASCII bytes against §1.3 ident grammar. Or, if §1.3 is to be relaxed, emit the bytes as part of the identifier and lex it as a single ident.
**Notes:** Spec says identifiers are ASCII (`[A-Za-z_][A-Za-z0-9_]*`). Current behavior is "silently swallow each high-bit byte then misparse the rest" — pure footgun.

### F-011 [Critical] [Silent miscompile + corruption] NUL byte mid-source truncates compilation silently
**Reproducer:** `audit_scratch_lexer_parser/null_byte_mid.nr` — `fn main() -> i32 { let x: i64 = 1; <NUL> return 0; }` (49 bytes on disk)
**Command:** `./bin/nucleor.exe build audit_scratch_lexer_parser/null_byte_mid.nr -o ...`
**Observed:** Compiler reports "source: ... (36 bytes)" — i.e. it read up to the NUL and stopped. Then PANIC: NR020 "expected `}`, got <EOF>".
**Expected:** Either read the full file (49 bytes) and treat NUL as unknown lex byte, or emit a clear "NUL byte at offset N — Nucleor source must not contain NUL" diagnostic. The current behavior silently truncates source — if a malicious adversary inserted a NUL after a `}` of one fn but before another, the second fn would never compile, and the resulting PANIC at EOF misdirects the diagnostic.
**Notes:** This is a smuggling vector. Probably caused by `str_len` using `strlen` on the source buffer (C-string semantics) instead of byte-count. Search for `read_file`/`fs_read`/source buffer init to confirm.

### F-012 [Critical] [Silent miscompile] `let x: i64 = 1 2 3 4 5;` silently parses, drops 2/3/4
**Reproducer:** `audit_scratch_lexer_parser/adjacent_tokens.nr`
```nr
fn main() -> i32 {
    let x: i64 = 1 2 3 4 5;
    return 0;
}
```
**Observed:** Exit 0. IR shows `r.1 = 1`. The `2 3 4` are parsed as zero-effect expression statements (each consumed by `parse_stmt`'s expression-stmt branch with no `;` required for single-token exprs); `5;` consumes the trailing `;`.
**Expected:** Either NR020 ("expected `;`, got integer literal") OR reject expression-statements that have no side effect (like Rust's `unused_must_use` for hot path). Currently any sequence of integer/string/ident literals between statements is silently swallowed.
**Notes:** This is a high-risk gap. Cross-cousin: `let x = 1 ` (no `;`) followed by `let y = 2;` is also accepted (F-013).

### F-013 [High] [Silent accept] Missing semicolon after `let` statement silently accepted
**Reproducer:** `audit_scratch_lexer_parser/no_semi.nr`
```nr
fn main() -> i32 {
    let x: i64 = 1
    let y: i64 = 2
    return 0;
}
```
**Observed:** Exit 0. Both lets compile.
**Expected:** Either explicit "trailing `;` required" diag, or document that `;` is optional after `let` (currently it's optional per `parse_let` line 3391).
**Notes:** Language reference §3 examples all show `;`. Silent acceptance creates inconsistency: if user writes `let x = 1 + 2 \n let y = 3;`, the parser may eat `let y` as the RHS of `let x` (depending on whitespace + lookahead) — confusion vs. silent-accept depends on token sequence.

### F-014 [High] [Silent accept] Extra closing braces `}}}}` at module scope silently accepted
**Reproducer:** `audit_scratch_lexer_parser/extra_close_brace.nr`
```nr
fn main() -> i32 {
    return 0;
}}
```
**Observed:** Exit 0.
**Expected:** NR020 "unexpected `}` at module scope" or similar.
**Notes:** Sister: `extra_close_brace2.nr` adds `}}}}` and a `fn never_compiled() -> i64 { return BOGUS_IDENT; }` — `never_compiled` IS parsed but DCE'd before TYP-check, so `BOGUS_IDENT` (an undefined identifier) never gets diagnosed. (F-015.) `extra_close_paren.nr` `)))))` at module scope — same silent-accept.

### F-015 [Medium] [Cross-layer / silent miscompile] Unreachable fns DCE'd before TYP name resolution runs
**Reproducer:** `audit_scratch_lexer_parser/extra_close_brace3.nr` — fn with `BOGUS_IDENT` use is DCE'd silently.
**Observed:** Exit 0 even though the body references an undefined identifier.
**Expected:** Name resolution should run before DCE; or DCE should still emit an info note about elided fns, especially ones with use-of-undefined references.
**Notes:** Cross-layer with type-checker; flagged here because it lets the F-014 silent-accept escape into "compile cleanly when extra fns get pushed off the parse path".

### F-016 [High] [Silent accept] `0x`, `0b`, `0o` with no digits silently produce literal `0`
**Reproducer:** `audit_scratch_lexer_parser/hex_no_digit.nr` (and `bin_no_digit.nr`, `oct_no_digit.nr`) — `let x: i64 = 0x;`
**Observed:** Exit 0. IR has `r.1 = 0`.
**Expected:** Lex error: "hex literal `0x` requires at least one digit". Rust rejects this. Same for `0b` and `0o`.

### F-017 [High] [Silent accept] `0x_` (underscore-only digit body) silently produces 0
**Reproducer:** `audit_scratch_lexer_parser/hex_us_only.nr` — `let x: i64 = 0x_;`
**Observed:** Exit 0; value=0.
**Expected:** Reject — at least one digit required.

### F-018 [High] [Silent accept] Trailing underscore in integer literal silently accepted
**Reproducer:** `audit_scratch_lexer_parser/trail_us_int.nr` — `let x: i64 = 100_;`
**Observed:** Exit 0; value=100.
**Expected:** Reject (Rust rejects). Underscores must be between digits.

### F-019 [High] [Silent accept] Double underscore `1__2` silently accepted in numeric literal
**Reproducer:** `audit_scratch_lexer_parser/double_us_int.nr` — `let x: i64 = 1__2;`
**Observed:** Exit 0; value=12.
**Expected:** Reject (Rust rejects more than one consecutive `_`).

### F-020 [High] [Silent accept] Leading zeros (`007`) silently accepted as decimal
**Reproducer:** `audit_scratch_lexer_parser/lead_zero.nr` — `let x: i64 = 007;`
**Observed:** Exit 0; value=7.
**Expected:** Either explicit warn (this looks like C-style octal, which Nucleor doesn't have — surprise hazard) or reject. Many languages diagnose this.

### F-021 [Critical] [Silent miscompile] Hex literal > 64 bits silently wraps with no diagnostic
**Reproducer:** `audit_scratch_lexer_parser/hex_overflow.nr` — `let x: i64 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF;`
**Observed:** Exit 0. The lexer uses `wrapping_mul`/`wrapping_add` and folds the overflowing value silently.
**Expected:** NUM-021-style diagnostic for hex (mirroring the existing decimal-overflow check at line 740–757). The lexer source comment at line 523–525 explicitly acknowledges the overflow path is intentional, but the bound should be checked first — adopters can opt-in to wraparound via an explicit `wrapping {}` block.
**Notes:** Decimal overflow IS caught (NUM-021). Same protection should apply to hex.

### F-022 [High] [Silent accept] Unknown integer suffix (`1z42`) drops suffix silently as adjacent ident
**Reproducer:** `audit_scratch_lexer_parser/bad_suffix.nr` — `let x: i64 = 1z42;`
**Observed:** Exit 0; IR shows `r.1 = 1`. The `z42` is lexed as a separate ident which the parser then accepts as an expr-statement (via F-012 mechanism).
**Expected:** Either ident-attached-to-int suffix is a hard lex error, or emit a NUM-xxx diag for "unknown numeric suffix".

### F-023 [High] [Silent accept] Unknown int suffix `1i9` silently rewinds and drops `i9`
**Reproducer:** `audit_scratch_lexer_parser/bad_int_suffix.nr` — `let x: i64 = 1i9;`
**Observed:** Exit 0. The int-suffix consumer rewinds because `i9` isn't in the known list, so `i9` lexes as an ident and joins the silent-drop path.
**Expected:** Reject `1i9` as malformed numeric suffix.
**Notes:** Lexer line 836–857 has an `is_known` set; on miss it rewinds to ident. This rewind path is exactly the silent-drop hazard.

### F-024 [High] [Silent accept] `0xZ` invalid hex digit silently consumed as ident
**Reproducer:** `audit_scratch_lexer_parser/bad_hex.nr` — `let x: i64 = 0xZ;`
**Observed:** Exit 0; the `0x` consumed (no digits — see F-016), then `Z` lexed as separate ident.
**Expected:** Reject "invalid hex digit `Z`".

### F-025 [Critical] [Wrong-class diagnostic] Empty char literal `''` reports "loop labels not yet supported"
**Reproducer:** `audit_scratch_lexer_parser/empty_char.nr` — `let x: i64 = '';`
**Observed:** Exit 1 with `ERROR: loop labels (...) are not yet supported in Nucleor.`
**Expected:** Lex/parse error "empty char literal" — what the user wrote is a quote-quote, not a label.
**Notes:** Lexer falls through to lifetime-token branch, then v0.7.2 "loop labels" halt fires with completely off-topic message. Severely misleading. Sister cases: `bare_apos.nr` (just `'`), `weird_apos.nr` (`'''`), `two_char.nr` (`'ab'`).

### F-026 [High] [Wrong-class diagnostic] `'ab'` (multi-char char literal) gives "loop labels" error
**Reproducer:** `audit_scratch_lexer_parser/two_char.nr` — `let x: i64 = 'ab';`
**Observed:** Same misleading "loop labels" diagnostic as F-025.
**Expected:** "char literal must contain exactly one char" or similar.

### F-027 [High] [Silent accept] Three apostrophes `'''` silently lex to lifetime token + something
**Reproducer:** `audit_scratch_lexer_parser/weird_apos.nr` — `let x: i64 = ''';`
**Observed:** Exit 0. IR says `optimized: 0 instructions`. Apparently the parser silently produces a no-op.
**Expected:** Lex/parse error.

### F-028 [Critical] [Silent miscompile] Float literals that overflow (`1e400`) silently produce Inf
**Reproducer:** `audit_scratch_lexer_parser/huge_float.nr` — `let x: f64 = 1e400;`
**Observed:** Exit 0. `str_to_f64` (strtod) returns Inf; bit pattern is `0x7FF0000000000000` and stored.
**Expected:** Diagnostic when literal value is non-finite (Inf/NaN). Sister: `neg_huge_float.nr` (1e-400 → 0.0 silently).
**Notes:** Cousin to NUM-021 for ints; floats need similar protection.

### F-029 [High] [Silent accept] Multi-line string literals (raw newline inside `"..."`)
**Reproducer:** `audit_scratch_lexer_parser/multiline_string.nr` — `let s: str = "line1\nline2";` where `\n` is a real LF byte in the source.
**Observed:** Exit 0. The LF is included in the string verbatim.
**Expected:** Either: (a) reject raw newlines in string literals with a "use `\n` escape" hint (Rust rejects), OR (b) document explicitly that multi-line strings are allowed. Currently undocumented.

### F-030 [High] [Silent accept] Back-to-back string literals `"a""b"` accepted as two strings
**Reproducer:** `audit_scratch_lexer_parser/back_to_back_str.nr` — `let s: str = "a""b";`
**Observed:** Exit 0; "strings: 2" in the build summary. The let only takes `"a"`; `"b"` becomes a stray expr-stmt (F-012 mechanism).
**Expected:** NR020 "expected `;`/operator after string literal" OR adopt C-style adjacent-string concatenation explicitly.

### F-031 [Critical] [Silent accept + dropped tokens] Stray garbage between tokens silently dropped
**Reproducer:** `audit_scratch_lexer_parser/lone_semi.nr` — `;;;;`
**Observed:** Exit 0; treated as empty statements.
**Expected:** Same expr-stmt-laxness as F-012; document that the parser allows lone `;`.

### F-032 [High] [Wrong-class diagnostic] `.5` (leading-dot float) gives "parse_primary cannot start an expression at token kind 45"
**Reproducer:** `audit_scratch_lexer_parser/dot_float.nr` — `let x: f64 = .5;`
**Observed:** NR020 with "token kind 45" (raw token id) — the diagnostic doesn't mention "leading dot" or hint at the user's intent.
**Expected:** Either accept `.5` as Rust does (`0.5`), OR emit a clean "leading-dot float not supported; write 0.5" hint.

### F-033 [High] [Wrong-class diagnostic] `1.` (trailing-dot float) reads as `1` then field-access `.`
**Reproducer:** `audit_scratch_lexer_parser/trail_dot_float.nr` — `let x: f64 = 1.;`
**Observed:** `ERROR: cannot resolve field access type for .` — the parser saw `1` as int-lit and `.` as field-access operator on it.
**Expected:** Lex `1.` as a complete float literal (Rust does this) OR emit "trailing-dot floats unsupported, write 1.0".

### F-034 [Medium] [Diagnostic gap] NR020 messages report raw token kinds (e.g. "token kind 21", "token 21") for tokens missing from `tok_name` table
**Reproducer:** `audit_scratch_lexer_parser/split_arrow.nr` — `fn main() -\n> i32 { ... }`
**Observed:** `expected `{`, got token 21.` — token 21 is `-` but the table at `tok_name` (lines 1158-1179) doesn't list arithmetic op tokens (kinds 20-24, 30-38, etc.).
**Expected:** Extend `tok_name` to cover arithmetic, comparison, logical, bitwise op tokens; lifetime; ident; etc. The existing v0.4.208 effort only covered a handful of common puncts.
**Notes:** Affects many findings here. Also: token kind 122 (the `@` "attr token"), 30 (`==`), 64 (`=>`), 115 (`<<`), 45 (`.`) all show as raw IDs.

### F-035 [High] [Wrong-class diagnostic] `1 + + + + + 2` mis-diagnosed as "post-increment"
**Reproducer:** `audit_scratch_lexer_parser/many_ops.nr` — `let x: i64 = 1 + + + + + 2;`
**Observed:** `ERROR: post-increment 'x++' is not supported.`
**Expected:** "consecutive `+` operators not allowed" or similar. The `++` halt fires because the lexer collapses `+` + `+` into the postfix `++` token (kind 130) BEFORE the parser sees them — but in expression-binary position they're not postfix at all.

### F-036 [High] [Silent accept] Missing comma between match arms silently accepted
**Reproducer:** `audit_scratch_lexer_parser/match_no_comma.nr` — `match x { _ => { 1 } 1 => { 2 } };`
**Observed:** Exit 0.
**Expected:** Per language reference §5.1 arms are comma-separated; missing `,` should be NR020.

### F-037 [High] [Silent accept] Extra commas in fn-call args silently dropped
**Reproducer:** `audit_scratch_lexer_parser/call_extra_comma.nr` — `h(1,, 2)`
**Observed:** Exit 0.
**Expected:** NR020 "missing argument expression after `,`".
**Notes:** `args_lead_comma.nr` (`h(,1)`) is similarly silently accepted.

### F-038 [High] [Silent accept] Missing `;` at end of trailing-comma struct decl silently accepted; struct empty bodies, enum empty bodies all accepted
**Reproducer:** `audit_scratch_lexer_parser/struct_empty.nr`, `enum_empty.nr`
**Observed:** Exit 0 for both.
**Expected:** Likely intentional (Rust allows empty structs/enums) but undocumented in language reference §4/§5. **Note** rather than defect.

### F-039 [High] [Silent accept] `for i in 5..1` (descending/empty range) silently accepted
**Reproducer:** `audit_scratch_lexer_parser/range_neg.nr` — `for i in 5..1 { }`
**Observed:** Exit 0; the loop body never runs.
**Expected:** At least an UNREACH-001-style warning ("range is empty: lower > upper").

### F-040 [Medium] [Diagnostic gap] `0...5` (typo for `..` or `..=`) gives confusing NR020 about token kind 45
**Reproducer:** `audit_scratch_lexer_parser/range_3dot.nr` — `for i in 0...5`
**Observed:** NR020 "cannot start expression at token kind 45". Lexer parses as `0..` (kind 58, `..`) then `.5` — and `.5` (F-032) fails with kind 45.
**Expected:** Detect 3-dot pattern in lexer and either accept (Rust deprecated) or emit "did you mean `..=`?".

### F-041 [High] [Silent accept] Missing return type on fn declaration silently accepted
**Reproducer:** `audit_scratch_lexer_parser/no_return_ty.nr` — `fn helper() { }`
**Observed:** Exit 0.
**Expected:** Per language reference §3 "Every function requires a return type." Either reject, or update spec.
**Notes:** Documentation drift: the spec is normative for v0.2 but the parser at v1.0 is more permissive.

### F-042 [Medium] [Diagnostic gap] `fn helper(,)` reports "expected `:`, got `)`" — confusing
**Reproducer:** `audit_scratch_lexer_parser/fn_extra_comma.nr` — `fn helper(,) -> i32 { return 0; }`
**Observed:** `expected `:`, got `)``.
**Expected:** "expected parameter name or `)`, got `,`".

### F-043 [Medium] [Diagnostic gap] `let x:` then EOF reports "expected `}`, got <EOF> at byte 0"
**Reproducer:** `audit_scratch_lexer_parser/colon_eof.nr` — `fn main() -> i32 { let x:`
**Observed:** Byte position reports 0, not the actual EOF offset.
**Expected:** Correct byte position; ideally "expected type expression, got <EOF>".

### F-044 [Medium] [Diagnostic gap] `for i in 0..` then EOF — wrong byte position 0
**Reproducer:** `audit_scratch_lexer_parser/range_eof.nr` — `for i in 0..`
**Observed:** Byte position reports 0.
**Expected:** Correct byte position.

### F-045 [Medium] [Diagnostic gap] Unterminated string at EOF reports byte position of the `}`/EOF, not the string opening `"`
**Reproducer:** `audit_scratch_lexer_parser/unterm_string_eof.nr` — `fn main() -> i32 { let s: str = "hello`
**Observed:** `parse error at byte 39: expected `}`, got <EOF>`.
**Expected:** Lex-time diagnostic pointing to the opening `"` saying "unterminated string literal".
**Notes:** The lexer (line 864–891) silently consumes to EOF if the closing `"` is missing, then commits a string token and falls through. Easy to spot: line 890 `if p < slen { p = p + 1; };` — the closing-quote consumption is conditional, with no error path.

### F-046 [High] [Silent accept] CR-only line endings (`\r` between statements, no `\n`) silently parsed as if they were spaces
**Reproducer:** `audit_scratch_lexer_parser/cr_only.nr` — file uses CR (0x0D) as the only line terminator.
**Observed:** Exit 0.
**Expected:** Per language reference §1.1: "Line endings may be `\n` or `\r\n`." Bare CR is not accepted by spec — should be lex error or normalization warning. (Note also: the line-comment lexer at line 434–435 scans until `\n`, so a CR-terminated `// comment` would swallow the rest of the file.)
**Notes:** Sister hazard: a file using mixed CR-only line endings, with `// foo`, would silently swallow everything from `// foo` through to the next `\n`-terminated line — potentially deleting whole functions.

### F-047 [High] [Silent accept] CRLF inside string literal preserved as-is (CR + LF in resulting str)
**Reproducer:** `audit_scratch_lexer_parser/cr_in_str.nr` — `let s: str = "a<CR>b";`
**Observed:** Exit 0. Byte CR is preserved in the string verbatim.
**Expected:** Document or warn about embedded CR/LF in string literals.

### F-048 [High] [Wrong-class diagnostic] `let x: ;` reports OWN-008 about binding `i64` instead of NR020 missing-type
**Reproducer:** `audit_scratch_lexer_parser/type_bare_colon.nr` — `let x: ;`
**Observed:** `error[TYP-008]: binding 'x' declared without initializer (type-only)...`
**Expected:** NR020-class "expected type expression, got `;`".

### F-049 [Medium] [Wrong-class diagnostic] `extern fn name() { body }` claims user wrote `extern "C"`
**Reproducer:** `audit_scratch_lexer_parser/extern_with_body.nr` — `extern fn foo(a: i64) -> i64 { return a; }`
**Observed:** Diagnostic message starts: ``ERROR: `extern "C" fn foo(...) { body }` (Rust FFI-exposed fn with body)`` — but the source has no `"C"`.
**Expected:** Diag should match user input ("extern fn name() { body }") not paraphrase as `extern "C"`.

### F-050 [High] [Silent accept] `import` without quotes silently accepted
**Reproducer:** `audit_scratch_lexer_parser/import_no_q.nr` — `import stdlib/rods/strings.nr`
**Observed:** Exit 0.
**Expected:** Per language reference §7, paths are string-quoted. Bare paths should be NR020.

### F-051 [High] [Silent accept] `import ""` (empty path) silently accepted
**Reproducer:** `audit_scratch_lexer_parser/import_empty.nr`
**Observed:** Exit 0; the empty import is dropped.
**Expected:** Reject empty path.

### F-052 [Medium] [Silent accept] `import "<<<>>>"` (path with no resolvable file) silently accepted
**Reproducer:** `audit_scratch_lexer_parser/weird_import.nr`
**Observed:** Exit 0; path silently dropped (probably resolved to "no file matches → ignored").
**Expected:** Cross-layer with module resolver. Should emit "import path does not exist" diagnostic.

### F-053 [High] [Silent accept] `||;` (closure with no body) silently accepted
**Reproducer:** `audit_scratch_lexer_parser/closure_empty.nr` — `let f: i64 = || ;`
**Observed:** Exit 0. The closure body is missing entirely.
**Expected:** NR020 "expected expression after `||`".

### F-054 [High] [Silent accept] `let fn: i64 = 5;` (keyword as binding name) silently accepted
**Reproducer:** `audit_scratch_lexer_parser/kw_as_ident.nr` — `let fn: i64 = 5;`
**Observed:** Exit 0. IR has `store i64 %r.1, ptr %r.0` (uninitialized `r.1`).
**Expected:** Reject — `fn`, `let`, `return`, etc. are reserved words (§1.5). Currently `parse_let` calls `pkv(tokens, cp)` to extract the name regardless of token kind, accepting any keyword token.
**Notes:** Sister: `kw_as_ident_let.nr`, `kw_as_ident_return.nr` — same silent-accept.

### F-055 [Medium] [Wrong-class diagnostic] `1 ==== 1` (4 equals) reports "cannot start an expression at token kind 30"
**Reproducer:** `audit_scratch_lexer_parser/quad_eq.nr` — `if 1 ==== 1 { ... }`
**Observed:** Lexer collapses `==` + `==` into two `==` tokens (kind 30); parser sees `1 == == 1`, fails at the second `==`. Diag uses raw kind ID.
**Expected:** Either lex-time hint ("did you mean `==`?") or token-name table fix per F-034.

### F-056 [High] [Silent accept] `(-5)` and `- - 5` (multi-unary-minus) silently accepted (probably correct, but verify edge)
**Reproducer:** `audit_scratch_lexer_parser/triple_neg.nr` — `let x: i64 = - - - 5;`
**Observed:** Exit 0.
**Expected:** Probably correct — chained unary minus is mathematically valid. **Note** rather than defect.

### F-057 [High] [Silent accept] `import` etc. directives accepting non-keyword positions
**Notes:** Not retested here — flagging as gap for further audit.

### F-058 [High] [Silent accept] Block comments `/* ... */` rejected — but with full halt instead of attempt-to-skip; halt diag itself is correct, but **doc-comments `///` and `/** */`** were not tested in this pass.
**Notes:** Cross-layer; future audit.

### F-059 [Medium] [Silent accept] Trailing comma in struct field decl accepted (`struct P { x: i64, y: i64, }`)
**Reproducer:** `audit_scratch_lexer_parser/struct_trail_comma.nr`
**Observed:** Exit 0.
**Expected:** Probably intentional — Rust accepts. **Note** rather than defect.

### F-060 [High] [Silent accept] String escape `\<bare-eof>` (file ends mid-escape) — diag emitted but wraps newline char in "unknown escape"
**Reproducer:** `audit_scratch_lexer_parser/str_backslash_eof.nr` — `"abc\` then EOF
**Observed:** ``error[NR025]: unknown escape sequence `\<LF>` in string literal.`` (the `\` consumed the trailing LF as the escape char).
**Expected:** Special-case "unterminated string + trailing backslash" — currently the diagnostic reports a `\<LF>` escape, missing the unterminated-string root cause.

### F-061 [Medium] [Silent accept] `huge_comment.nr` (5 MB single-line comment) compiled fine — good defensive resilience
**Notes:** Resilience confirmed; **not a defect, just confirming hardening.**

### F-062 [Note] [Coverage gap] Block-comment `/* ... */` halt suppresses the actual `/` parser error; user gets a clear (but rejection-style) message. Adopters porting Rust code can't compile until they manually convert; documented in halt message.
**Notes:** Working as intended per design comments at line 957. **Note** rather than defect.

### F-063 [High] [Silent accept] Whitespace-only and comment-only files lex/parse cleanly but fail with cryptic linker error
**Reproducer:** `audit_scratch_lexer_parser/whitespace_only.nr` (just blank lines)
**Observed:** Build phases succeed; final step `lld-link: error: subsystem must be defined` (the linker discovers no `main`).
**Expected:** Frontend-level "no `main` function defined" diagnostic before reaching the linker. Currently the parse phase happily produces 0 functions; the type/codegen phases pass through; only the linker complains, with a tooling-level message.

### F-064 [Medium] [Diagnostic gap] Empty file gives "cannot read" — misleading
**Reproducer:** `audit_scratch_lexer_parser/empty.nr` (0 bytes)
**Observed:** `ERROR: cannot read audit_scratch_lexer_parser/empty.nr` exit 1.
**Expected:** Either "source file is empty" OR "no `main` function defined". The current error wrongly suggests an I/O failure.

### F-065 [Note] [Coverage gap] `loop_label`-style detection for *invalid* lifetime token (kind 98) catches MANY unrelated cases
**Notes:** F-025/F-026/`bare_apos.nr` all surface as "loop labels not yet supported". The kind-98 token is overloaded for both lifetimes AND mis-tokenized chars. The halt should differentiate based on source position content (single-char `'X'` vs multi-char vs `'<ident>:`).

### F-066 [Note] [Hardening request] Unknown-byte fall-through (`else { p = p + 1; };` at lexer end) is the root cause for many silent-accept findings
**Notes:** Replace with: emit a TOK_INVALID token (or a one-line lex-time diagnostic) recording the offending byte. Downstream parser then reports it consistently. This single change would close F-003, F-004, F-005, F-007, F-008, F-009, F-010 in one move.

### F-067 [Medium] [Diagnostic gap] `let mut x: i64 = ; ` (no init expression) was not directly tested but suspected to fall into similar TYP-008 misclass
**Notes:** Future probe target.

### F-068 [Note] [Hardening request] No depth guard in recursive-descent parsers
**Notes:** Add a `MAX_PARSE_DEPTH` constant and bail with NR0xx "expression nesting too deep" when exceeded — closes F-002.

### F-069 [Low] [Documentation gap] Language reference §1.4 "string escape sequences" lists `\n`, `\r`, `\t`, `\\`, `\"` — but lexer also accepts `\0`, `\'`. Spec drift.
**Notes:** Update spec OR remove `\0`/`\'` from lexer. Currently inconsistent.

### F-070 [Low] [Documentation gap] Language reference §1.6 lists no bitwise operators, but lexer supports `&`, `|`, `^`, `<<`, `>>`, `~` (ish), and compound `&=`, `|=`, `^=`, `<<=`, `>>=`. §6 lists `++`, `--` postfix not in spec either.
**Notes:** Update §1.6.

### F-071 [Low] [Documentation gap] Language reference §1.5 keyword list omits: `mut`, `for`, `in`, `break`, `continue`, `trait`, `impl`, `where`, `as`, `loop`, `const`, `type`. The implementation supports all of these.
**Notes:** Spec out-of-date — adopter cannot rely on §1.5 to know the reserved word set.

### F-072 [Low] [Documentation gap] Underscore-prefixed identifiers (`_foo`) accepted as idents but spec §1.3 grammar `[A-Za-z_][...]` allows it; `_` alone (single underscore as ident, common in Rust as discard) was not tested.
**Notes:** Future probe target.

### F-073 [Note] [Confirmed working] CRLF line endings (`\r\n`) work correctly throughout
**Notes:** No defect — confirmation.

### F-074 [Note] [Confirmed working] 1MB string literals, 10K-char identifiers, 10K let-bindings all compile in reasonable time
**Notes:** No defect — confirmation. Lexer scales.

### F-075 [High] [Silent accept] `fn helper() { }` accepted with no `-> ReturnType`; spec §3 requires return type
**Notes:** Already covered by F-041. Listed separately for index search.

### F-076 [High] [Silent accept] `1z42` (and `1abc`, etc.) parsed silently because lexer rewinds on unknown int suffix and produces ident token
**Notes:** Same as F-022/F-023.

### F-077 [Medium] [Diagnostic gap] `at_alone.nr` (`= @;`) reports "token kind 122 (byte position 36)" — kind 122 is the `@` attr token that was emitted only when not followed by alnum
**Notes:** Lexer line 303 emits token 122 unconditionally for stray `@`. The diag is honest but raw-kind. Add `@` to `tok_name` per F-034.

### F-078 [High] [Silent accept] Many tokens consumed as expression-statements when between statements, with no diagnostic — the underlying enabling condition for most F-012-cousin findings
**Notes:** Closing this single behavior (e.g., warn on side-effect-free expression statements like `42;` or `"hello";`) would significantly tighten the parse contract.

## Cross-layer observations (out of scope this pass)

- DCE elides functions before name-resolution runs (F-015). Cross-layer with TYP/IR.
- Module resolver silently ignores unresolvable import paths (F-052).
- Linker-level "subsystem must be defined" for missing main (F-063) — should be a frontend diag.
- `let x: <expr>` segfault root cause (F-001) is in `parse_type` calling NULL-pool path.
- `RFC-0062 G-8` info note ("match expressions in build: 1") is auto-emitted on every match-using build — noise on small probes; cross-layer with diagnostics-policy layer.

## Output

- Full reproducer files: `audit_scratch_lexer_parser/*.nr` (≈100 files)
- Per-test compile output: `audit_scratch_lexer_parser/_out_*.txt`
- This document: single source of truth for findings.
