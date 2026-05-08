# Lane 4 — Lexer / Parser Robustness

**Branch:** `fix/audit-lane-4-lexer-parser-2026-05-08`
**Theme:** Eliminate compiler crashes, silent-accepts, smuggling vectors at the lexer/parser entry. Close the entire Layer 1 finding set.

## In-scope findings

### Critical (6)
- **F-001** — SIGSEGV on `let x: 1 + 1 = 5;` (adversarial input crashes compiler)
- **F-002** — Parser stack overflow at ~3000-4000 nested `if`/`{`/`[` (DoS surface)
- **F-011** — NUL byte in source silently truncates compilation (smuggling vector)
- **F-021** — Hex literal > 64 bits silently wraps (decimal IS checked, hex isn't — asymmetric)
- **F-028** — `1e400` silently stores Inf bit pattern
- **F-006-related** — Silent miscompile of `1 2 3 4 5;` (top-level garbage silent-accept)

### High (18)
- F-066 root-cause finding: lexer's terminal `else { p = p + 1; }` clause at line ~1046 silently consumes any unknown byte. **Replacing with TOK_INVALID emission closes ~10 findings at once.**
- BOM/zero-width/smart-quote/non-ASCII silent consume
- `0x`/`0b`/`0o` zero-digit accept
- `0x_`/trailing-`_`/`1__2`/`007` accept
- `1z42`/`1i9`/`0xZ` rewind-and-drop
- Empty/multi-char char literal misdiag
- Missing-semicolon accept
- `}}}}`/`)))))` accept
- Missing-comma in match
- Extra-comma in args
- fn-no-return-type
- keyword-as-ident
- raw-CR line endings
- raw-newline-in-string
- closure-no-body
- import-no-quotes
- import-empty
- top-level garbage silent-accept

### Medium (12)
- Diagnostic-clarity gaps
- Wrong-class diags
- `tok_name` table missing many ops

### Low (8)
- Documentation drift between `language-reference.md` and actual lexer/keyword set

## Source-of-truth findings doc
- `docs/audit/findings/audit_recon_pass1_lexer_parser_2026-05-08.md`

## Strategy

1. **F-066 first — TOK_INVALID emission.** The terminal `else { p = p + 1; }` at line 1046 is the root cause. Replace with: emit a `TOK_INVALID` token with the unknown byte as content. Parser then refuses with diagnostic `LEX-001: unexpected byte 0xNN at line:col`. **Closes ~10 findings.**
2. **F-001 SIGSEGV.** Type position parser must reject expression-shaped input with `PARSE-TYPE-001: expected type, found expression`.
3. **F-002 stack overflow.** Add depth limit to recursive descent (e.g., 256 nested expressions). On exceed: `PARSE-DEPTH-001: nesting too deep` (diagnostic, not panic).
4. **F-011 NUL byte.** Treat embedded NUL as `LEX-002: null byte in source not permitted` (or alternatively, accept and treat as TOK_INVALID — depending on intended semantics; pick stricter).
5. **F-021 hex overflow.** Mirror the decimal overflow check for hex/bin/oct literals. Reuse `NUM-001` family or add `LEX-NUM-OVERFLOW`.
6. **F-028 1e400.** Float literal range-check — emit `LEX-NUM-FLOAT-OVERFLOW` for finite-range overflow.
7. **Top-level garbage.** Top-level expression list outside a fn body — reject with `PARSE-TOP-001`.
8. **Number literal hygiene.** `0x` requires ≥1 hex digit; underscore not at start/end/repeated; `007` reject leading-zero (or accept per spec — language ref tells us); invalid suffixes `1z42` properly diagnosed.
9. **Char literal.** Empty char `''` reject; multi-char `'ab'` reject (or accept as char-array per spec — clarify). Smart-quotes/zero-width chars rejected at LEX layer.
10. **Closing-delim recovery.** Stray `}` `)` outside a context — emit diagnostic, don't silently skip.
11. **Comma hygiene.** Match arm missing comma → diagnostic; arg list extra comma → diagnostic.
12. **Closure body required.** `|x|` without body → `PARSE-CLOSURE-NO-BODY`.
13. **Import shape.** `import "...";` only — bare `import foo;` rejected; empty `import "";` rejected.
14. **Documentation drift.** Update `language-reference.md` to match the actual keyword set + lexer behavior.

## Test mandate

For every Critical and High:
- `tests/err/lex_<finding>.nr` exit-code 1, expected diagnostic regex matches
- `tests/err/parse_<finding>.nr` similar

The 136 reproducer `.nr` files in the audit's scratch dir provide the input corpus. Lane agent should be able to reproduce findings directly and then verify the fix flips them from RC=0 to RC=1.

## Verify policy

Run `bash tools/verify.sh` ONCE at end. Re-bootstrap if compiler signature changed.

## Hard constraints

- Same as Lane 1.
- F-002 depth limit: pick a number that doesn't false-fail on legit code. 256 is safe; 1024 plenty.
- For "accept" vs "reject" calls (e.g., `007`, `'ab'`), default to language-reference.md's stated semantics; if ref is silent, default to stricter (reject) and document.

## Output

- Branch + report `docs/audit/lanes/LANE_4_REPORT.md`.
