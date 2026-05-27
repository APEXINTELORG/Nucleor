// =====================================================
// LEXER (from T29, unchanged)
// =====================================================
#[manual_drop]
fn tok_new(tt: i64, v: i64, p: i64) -> Vec<i32> {
    let mut t: Vec<i32> = Vec::with_capacity(3); t.push(tt); t.push(v); t.push(p); return t;
}
#[manual_drop]
fn tok_type(t: Vec<i32>) -> i64 { return vec_get(t, 0); }
#[manual_drop]
fn tok_val(t: Vec<i32>) -> i64 { return vec_get(t, 1); }
#[manual_drop]
fn tok_pos(t: Vec<i32>) -> i64 {
    let p: i64 = vec_get(t, 2);
    if p < 0 { return ((0 - p) - 1) / 16; };
    return p;
}
#[manual_drop]
fn tok_int_suffix_code(t: Vec<i32>) -> i64 {
    let p: i64 = vec_get(t, 2);
    if p < 0 { return ((0 - p) - 1) % 16; };
    return 0;
}
fn tok_pos_encode_int_suffix(p: i64, code: i64) -> i64 {
    if code == 0 { return p; };
    return 0 - ((p * 16) + code + 1);
}
#[manual_drop]
fn tokens_linecol_at_byte(tokens: Vec<i32>, byte_off: i64) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push(nuc_diag_line_for_byte(byte_off));
    out.push(nuc_diag_col_for_byte(byte_off));
    return out;
}
#[manual_drop]
fn int_suffix_code(suf: str) -> i64 {
    if str_eq(suf, "u64") == 1 { return 1; };
    if str_eq(suf, "usize") == 1 { return 2; };
    if str_eq(suf, "u32") == 1 { return 3; };
    if str_eq(suf, "u16") == 1 { return 4; };
    if str_eq(suf, "u8") == 1 { return 5; };
    if str_eq(suf, "i64") == 1 { return 6; };
    if str_eq(suf, "isize") == 1 { return 7; };
    if str_eq(suf, "i32") == 1 { return 8; };
    if str_eq(suf, "i16") == 1 { return 9; };
    if str_eq(suf, "i8") == 1 { return 10; };
    return 0;
}
#[manual_drop]
fn int_suffix_code_type(code: i64) -> str {
    if code == 1 { return "u64"; };
    if code == 2 { return "usize"; };
    if code == 3 { return "u32"; };
    if code == 4 { return "u16"; };
    if code == 5 { return "u8"; };
    if code == 6 { return "i64"; };
    if code == 7 { return "isize"; };
    if code == 8 { return "i32"; };
    if code == 9 { return "i16"; };
    if code == 10 { return "i8"; };
    return "i32";
}
#[manual_drop]
fn int_suffix_code_is_u64ish(code: i64) -> i64 {
    if code == 1 || code == 2 { return 1; };
    return 0;
}
#[manual_drop]
fn is_ws(c: i64) -> i64 { if c == 32 || c == 9 || c == 10 || c == 13 { return 1; }; return 0; }
#[manual_drop]
fn is_digit(c: i64) -> i64 { if c >= 48 && c <= 57 { return 1; }; return 0; }
#[manual_drop]
fn is_alpha(c: i64) -> i64 {
    if c >= 65 && c <= 90 { return 1; }; if c >= 97 && c <= 122 { return 1; };
    if c == 95 { return 1; }; return 0;
}
#[manual_drop]
fn is_alnum(c: i64) -> i64 { if is_alpha(c) == 1 || is_digit(c) == 1 { return 1; }; return 0; }
#[manual_drop]
fn classify_kw(w: str) -> i64 {
    if str_eq(w, "fn") { return 10; }; if str_eq(w, "let") { return 11; };
    if str_eq(w, "mut") { return 12; }; if str_eq(w, "if") { return 13; };
    if str_eq(w, "else") { return 14; }; if str_eq(w, "while") { return 15; };
    if str_eq(w, "return") { return 16; }; if str_eq(w, "struct") { return 17; };
    if str_eq(w, "break") { return 18; }; if str_eq(w, "continue") { return 19; };
    if str_eq(w, "extern") { return 20; };
    if str_eq(w, "for") { return 56; }; if str_eq(w, "in") { return 57; };
    if str_eq(w, "enum") { return 62; }; if str_eq(w, "match") { return 63; };
    if str_eq(w, "trait") { return 66; }; if str_eq(w, "impl") { return 67; };
    // `pure` is contextual — only a keyword when followed by `fn`.
    // Pre-v0.3.137, classifying `pure` as kw 68 unconditionally meant a user
    // fn or call site named `pure(...)` lexed to a non-identifier token,
    // parse_primary silently fell through to its `int_lit 0` default, and
    // the entire call was replaced by 0 in the IR with NO diagnostic.
    // Same hazard class as the v0.3.126 user-fn shadowing bug — silent
    // miscompute for any adopter who happens to name a fn `pure`. The
    // `pure fn` declaration form is recognised in parse_program by
    // checking `pkv == "pure" && pk(cp+1) == 10`, so the modifier still
    // works without paying the contextual-keyword tax in expression
    // position. See tests/fixtures/t411_user_fn_named_pure.nr.
    if str_eq(w, "pub") { return 72; };
    if str_eq(w, "const") { return 73; };
    if str_eq(w, "type") { return 74; };
    // `requires` is contextual — only meaningful as a fn-decl
    // annotation (`fn foo() -> T requires [<predicate>]`) per RFC-0030.
    // Pre-v0.3.139, classifying it as kw 75 unconditionally triggered the
    // same silent-miscompute trap as the v0.3.137 `pure` and v0.3.138
    // `scope`/`spawn` fixes — `parse_primary` had no branch for token 75
    // and silently fell through to its `int_lit 0` default. Any user fn
    // or call site named `requires` (e.g. auth gates `requires_admin`,
    // capability checks, type-class witness fns) collapsed to constant 0
    // in the IR with no diagnostic. The 4 `pk(...) == 75` annotation
    // checks in parse_fn_decl / parse_extern_fn / parse_trait_method /
    // parse_impl_method are rewritten to identifier-with-pkv lookahead
    // so the annotation form still works.
    // removed `restricts` kw classification. Same hazard
    // class as v0.3.137 `pure`, v0.3.138 `scope`/`spawn`, v0.3.139
    // `requires` — `restricts [...] { ... }` was a planned RFC-0030
    // contract-block form that had ZERO usage in stdlib, examples,
    // tests, or docs. The kw classification still forced the lexer
    // to refuse the name as identifier, and parse_primary's branch
    // for token 76 (skip_bracket_list + parse_passthrough_block_expr)
    // mangled `restricts(x)` call sites — bracket-list skip silently
    // returned pos unchanged when it found `(` instead of `[`, and
    // parse_passthrough_block_expr swallowed the rest of main's body
    // into a phantom block expression. Result: silent miscompute,
    // returns 0 instead of the user fn's return value.
    // `unsafe` is contextual — only meaningful as the
    // RFC-0003 `unsafe { ... }` block prefix. Pre-v0.3.149, classifying
    // it as kw 77 unconditionally meant a user fn or call site named
    // `unsafe(x)` lex'd to a non-identifier token. parse_primary's
    // tt==77 branch called parse_passthrough_block_expr which expected
    // `{`, found `(` instead, and printed two parse errors -- but the
    // build did NOT halt. Downstream codegen still emitted .ll, clang
    // still linked, and the exe returned 0 instead of the user fn's
    // result. Silent miscompute hidden behind loud-looking but
    // non-fatal parse-error output. Same hazard class as v0.3.137-v0.3.142
    // contextual-kw fixes. Now: lexer emits identifier token 1 with
    // value `"unsafe"`. parse_primary's branch checks pkv lookahead.
    // Block form `unsafe { ... }` continues to work.
    // `wrapping` and `saturating` are contextual. Pre-fix,
    // both lex'd as hard kw tokens for the RFC overflow-block forms
    // `wrapping { ... }` / `saturating { ... }` -- but parse_primary's
    // tt == 78/79 branches called parse_wrapped_block_expr, which when
    // given `(x)` instead of `{x}` parsed the inner expression as the
    // wrap target and emitted a call to __nucleor_wrap_i32. That helper
    // doesn't exist for the i64 ABI -- adopters writing
    // `fn wrapping(x) { ... }` and calling `wrapping(41)` got a clang
    // LINK error pointing at IR they didn't write. Same hazard class
    // as the v0.3.149 unsafe fix: noisy non-fatal-looking failure mode
    // that doesn't actually halt cleanly. Both names have ZERO block-form
    // usage in the codebase, same as v0.3.140 restricts.
    // removed reserved-but-unused `scope` (was 80) and
    // `spawn` (was 81) keyword classifications. Same hazard class
    // as the v0.3.137 `pure` fix — the lexer hard-classified these
    // names as keywords, but parse_primary had no branch for tokens
    // 80/81 in expression position so any user fn or call site named
    // `scope` or `spawn` collapsed to silent `int_lit 0` in the IR.
    // Both names are common in user code (RAII helpers, threading /
    // async wrappers, parser combinators) and zero `scope { … }` /
    // `spawn { … }` block-form usage exists in the entire repo —
    // the parse_stmts branch that consumed those tokens was dead.
    // Future RFCs that resurrect block-form `scope { … }` will need
    // contextual lexing (pkv lookahead) instead of hard kw mapping.
    // `loop` is contextual — only meaningful when followed
    // by `{` (the `loop { BODY }` block form, which desugars to
    // `while true { BODY }`). Pre-v0.3.141, classifying it as kw 84
    // unconditionally triggered the same silent-miscompute trap as
    // the v0.3.137 `pure` / v0.3.138 `scope`/`spawn` / v0.3.139
    // `requires` / v0.3.140 `restricts` fixes — `parse_primary` had
    // no branch for token 84 (the kw branch lived in `parse_stmts`)
    // so any `loop(x)` call site fell through to the `int_lit 0`
    // default and collapsed to a constant 0 in the IR with no
    // diagnostic. The `loop { ... }` stmt-form check in parse_stmts
    // and the top-level kw-at-module-scope rejection in parse_program
    // are rewritten to use pkv lookahead. tests/lang/loop_kw.nr still
    // exercises the canonical block form.
    // `as` is contextual — only meaningful as a postfix cast
    // operator (`x as T`), which always follows an expression. When `as`
    // appears at the start of a primary expression (e.g. `as(41)` as a
    // user fn call), it MUST be an identifier. Pre-v0.3.142, classifying
    // it as kw 86 unconditionally triggered the same silent-miscompute
    // trap as the v0.3.137 `pure` / v0.3.138 `scope`/`spawn` /
    return 1;
}
// Lane 4 / F-028: detect IEEE-754 f64 Inf/NaN bit patterns in a freshly
// parsed float literal. Pre-fix `1e400` strtod-parsed to +Inf and the
// raw bit pattern `0x7FF0000000000000` was stored silently — adopters
// got NaN/Inf in their numeric pipeline with no diagnostic.
// IEEE-754 f64 layout: sign(1) | exp(11) | mantissa(52). All-ones
// exponent indicates Inf (mantissa==0) or NaN (mantissa!=0). The
// canonical positive-Inf bits are 0x7FF0000000000000 = 9218868437227405312
// and negative-Inf bits are 0xFFF0000000000000. Cheaper than re-parsing
// strtod's output: we just compare the absolute-value bit pattern.
// Returns 1 if the bit pattern is non-finite (Inf or NaN), 0 otherwise.
// Implementation note: bitwise/shift ops are available but unused in the
// rest of the compiler self-host; we factor the check into a separate fn
// to keep the inline lex path minimal and avoid surprising the bootstrap
// IR seed with a new operator class.
#[manual_drop]
fn f64_bits_is_nonfinite(bits: i64) -> i64 {
    // Positive-Inf bit pattern as i64: 0x7FF0_0000_0000_0000.
    let pos_inf: i64 = 9218868437227405312;
    // Negative-Inf bit pattern as a signed-i64 value (sign bit set):
    // 0xFFF0_0000_0000_0000 = -4503599627370496.
    let neg_inf: i64 = 0 - 4503599627370496;
    // For positive bit patterns: bits in [pos_inf, i64::MAX] are non-finite
    // (the saturated exponent field maps to Inf or NaN).
    if bits >= pos_inf { return 1; };
    // For negative bit patterns: bits in [i64::MIN, neg_inf] are
    // non-finite. Note `bits < 0 && bits <= neg_inf` — anything more
    // negative (closer to i64::MIN) has the exponent saturated too.
    if bits < 0 && bits <= neg_inf { return 1; };
    return 0;
}

#[manual_drop]
fn lex(src: str) -> Vec<i32> {
    let mut tokens: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    // Lane 4 / F-007: reject a UTF-8 BOM (EF BB BF) at file start.
    // Accepting it creates a source-byte normalization exception where
    // the first three bytes are silently erased before the parser sees
    // the file. Keep the source contract byte-exact instead.
    if slen >= 3
        && str_char_at(src, 0) == 239
        && str_char_at(src, 1) == 187
        && str_char_at(src, 2) == 191 {
        panic("error[LEX-001]: unexpected UTF-8 BOM (0xEF 0xBB 0xBF) at byte 0. Nucleor source must be plain UTF-8 without a byte-order mark; remove the BOM so the first token is visible to the lexer.");
    };
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if is_ws(c) == 1 { p = p + 1; }
        else if c == 64 {
            // R14-D1 Phase 1 — preserve @law(...) annotations through
            // the lex skip path. The generic @attr skip below silently
            // consumes them; Phase 1 detects @law specifically and
            // emits a position + body-length record so future compiler
            // phases (and tests) can observe what was captured at lex
            // time. Phase 2b will replace this with a side-table store
            // + AST node attachment + optimizer law-rewrite pass.
            let law_at: i64 = p;
            let is_law: i64 = str_eq_at(src, p, "@law(");
            let law_body_start: i64 = if is_law == 1 { p + 5 } else { 0 };
            if p + 1 < slen && is_alnum(str_char_at(src, p + 1)) == 1 {
                // Skip attributes like @authored(...), @policy(...), @photonic[...], @hot, @const_fn.
                p = p + 1;
                while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
                if p < slen && str_char_at(src, p) == 40 {
                    let mut depth: i64 = 1;
                    p = p + 1;
                    while p < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, p);
                        if ch == 34 {
                            p = p + 1;
                            while p < slen && str_char_at(src, p) != 34 {
                                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                                else { p = p + 1; };
                            };
                            if p < slen { p = p + 1; };
                        } else {
                            if ch == 40 { depth = depth + 1; }
                            else if ch == 41 { depth = depth - 1; };
                            p = p + 1;
                        };
                    };
                } else if p < slen && str_char_at(src, p) == 91 {
                    let mut depth: i64 = 1;
                    p = p + 1;
                    while p < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, p);
                        if ch == 34 {
                            p = p + 1;
                            while p < slen && str_char_at(src, p) != 34 {
                                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                                else { p = p + 1; };
                            };
                            if p < slen { p = p + 1; };
                        } else {
                            if ch == 91 { depth = depth + 1; }
                            else if ch == 93 { depth = depth - 1; };
                            p = p + 1;
                        };
                    };
                };
            } else {
                tokens.push(tok_new(122, 0, p));
                p = p + 1;
            };
            // After the skip, p points just past the matching ')' for
            // parenthesized attrs. Emit the @law observation now.
            if is_law == 1 {
                let body_len: i64 = (p - 1) - law_body_start;
                print(str_concat(
                    str_concat("info[LAW-CAPTURE]: @law at position ", str_from_int(law_at)),
                    str_concat(", body length ", str_from_int(body_len))));
            };
        }
        else if c == 35 && p + 1 < slen && (str_char_at(src, p + 1) == 99 || str_char_at(src, p + 1) == 108)
            && ((p + 6 < slen && str_eq_at(src, p, "#cfile") == 1)
                || (p + 5 < slen && str_eq_at(src, p, "#link") == 1)
                || (p + 8 < slen && str_eq_at(src, p, "#libpath") == 1)) {
            // native-link directives
            // `#cfile "..."`, `#link <ident>`, `#link_windows "..."`,
            // `#libpath "..."`. Pre-Lane-4 the lexer's silent-skip
            // accidentally tolerated these lines (the leading `#` got
            // dropped, leaving an ident + string that the parser
            // ignored as stray top-level garbage). With Lane 4's
            // LEX-001 byte rejection, the bare `#` now produces an
            // error. extract_directives runs much later (at link time)
            // so the line is still in the source when lex walks it.
            // Skip the entire line at the lexer.
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        }
        else if c == 35 && p + 1 < slen && str_char_at(src, p + 1) == 91 {
            // Rust-style outer attribute: #[name], #[name(args)], #[name = val].
            // Lex-time skip with quoted-string + bracket-depth awareness.
            // Forward-compatible with RFC-0001/0021 attribute family; semantics
            // ship in later RFC implementation phases.
            // detect `#[cfg(...)]` and `#[cfg_attr(...)]` BEFORE the silent
            // skip and halt with a clear workaround pointer. Pre-fix, paired
            // `#[cfg(target_os="X")] fn foo() ... #[cfg(not(...))] fn foo()`
            // produced a misleading "duplicate pub fn name across modules"
            // PANIC because both branches lowered. Single `#[cfg(test)]`
            // items leaked into release builds. Cross-platform Rust
            // translation produced unbuildable Nucleor with a wrong-error
            // diagnostic. Loud halt closes the silent-drop window until full
            // cfg-evaluation lands (post-v0.6 RFC).
            if p + 6 < slen && str_eq_at(src, p + 2, "cfg") == 1 {
                let after_cfg: i64 = str_char_at(src, p + 5);
                if after_cfg == 40 || after_cfg == 95 {
                    print("ERROR: `#[cfg(...)]` and `#[cfg_attr(...)]` attributes are not yet supported in Nucleor. Pre-v0.6.25 the attribute was silently dropped at lex time, leaving all branches of a `#[cfg(...)] fn foo() ... #[cfg(not(...))] fn foo()` pair LIVE — which produced a misleading 'duplicate pub fn name' PANIC, hiding the real cause. Single `#[cfg(test)]` items leaked into release builds. Workarounds: (a) for cross-platform code, manually delete the inactive branch before building; (b) for test-only code, gate it behind a runtime flag or move it to a separate `_test.nr` file that isn't imported in release; (c) wait for the future cfg-evaluation ship that will pick the matching branch at parse time.");
                    panic("nucleor: `#[cfg(...)]` attribute not yet supported (see ERROR diagnostic above)");
                };
            };
            if p + 8 < slen && str_eq_at(src, p + 2, "inline") == 1 {
                let after_inline: i64 = str_char_at(src, p + 8);
                if after_inline == 93 || after_inline == 40 {
                    print("ERROR: `#[inline]` / `#[inline(always)]` attributes are not supported in Nucleor. Remove the attribute; the optimizer makes its own inline decisions.");
                    panic("nucleor: inline attribute not yet supported (see ERROR diagnostic above)");
                };
            };
            if p + 6 < slen && str_eq_at(src, p + 2, "cold") == 1 {
                let after_cold: i64 = str_char_at(src, p + 6);
                if after_cold == 93 || after_cold == 40 {
                    print("ERROR: `#[cold]` attribute is not yet supported in Nucleor. Workaround: remove the attribute; Nucleor does not yet feed cold-path hints to LLVM.");
                    panic("nucleor: cold attribute not yet supported (see ERROR diagnostic above)");
                };
            };
            // RFC-0021: `#[test]` is supported by `nuc test`.
            // Discovery happens in tools-suite; normal build/check paths
            // lexically consume this metadata below.
            // `#[derive(A, B, C)]` is silently dropped except for `Debug`
            // which is honored. Adopters writing `#[derive(PartialEq)]`
            // expect equality on field-wise values; Nucleor only honors
            // Debug, so `a == b` later falls through to TYP-011 ptr-compare
            // diag at the use site — a confusing distance from the derive
            // site. Print a one-line warning at lex time naming the whole
            // derive body so adopters know up front that anything other
            // than Debug is being silently dropped. Build continues
            // (warning, not error); TYP-011 still fires correctly at use
            // sites for the dropped derives.
            if p + 9 < slen && str_eq_at(src, p + 2, "derive(") == 1 {
                let derive_arg_start: i64 = p + 9;
                let mut derive_arg_end: i64 = derive_arg_start;
                while derive_arg_end < slen && str_char_at(src, derive_arg_end) != 41 {
                    derive_arg_end = derive_arg_end + 1;
                };
                if derive_arg_end < slen {
                    let derive_body: str = str_substring(src, derive_arg_start, derive_arg_end);
                    let trimmed_v060: str = str_trim(derive_body);
                    // PartialEq is now auto-generated
                    // by `expand_derive_partialeq` as the helper fn
                    // `<TypeName>__derived_eq(a, b) -> i64` (returns 1
                    // when field-wise equal, 0 otherwise). Adopters call
                    // it manually; auto-dispatch of `==`/`!=` to the
                    // helper is deferred. Suppress the DERIVE-001 warning
                    // when the only derive in the list is PartialEq, and
                    // soften the wording when PartialEq is one of several.
                    // Clone is now also auto-generated by
                    // `expand_derive_clone` as `<TypeName>__clone(a) -> <TypeName>`.
                    let mut v084_only_partial: i64 = 0;
                    if str_eq(trimmed_v060, "PartialEq") == 1 { v084_only_partial = 1; };
                    let mut v084_has_partial: i64 = 0;
                    if str_contains(trimmed_v060, "PartialEq") == 1 { v084_has_partial = 1; };
                    let mut v084_has_clone: i64 = 0;
                    if str_contains(trimmed_v060, "Clone") == 1 { v084_has_clone = 1; };
                    let mut v084_only_clone: i64 = 0;
                    if str_eq(trimmed_v060, "Clone") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "PartialEq, Clone") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Clone, PartialEq") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Clone, Debug") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Debug, Clone") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "PartialEq, Clone, Debug") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Clone, PartialEq, Debug") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Debug, Clone, PartialEq") == 1 { v084_only_clone = 1; };
                    if str_eq(trimmed_v060, "Debug, PartialEq, Clone") == 1 { v084_only_clone = 1; };
                    if v084_only_partial == 0 && v084_only_clone == 0 && str_eq(trimmed_v060, "Debug") == 0 {
                        let v084_intro: str = if v084_has_partial == 1 || v084_has_clone == 1 {
                            "warning[DERIVE-001]: only `Debug`, `PartialEq`, and `Clone` are honored from `#[derive("
                        } else {
                            "warning[DERIVE-001]: `#[derive("
                        };
                        let v084_body: str = if v084_has_partial == 1 || v084_has_clone == 1 {
                            ")]` — `PartialEq` generates `<Type>__derived_eq(a,b)->i64`; `Clone` (v0.7.64) generates `<Type>__clone(a)-><Type>`; the rest are silently dropped."
                        } else {
                            ")]` is silently dropped except for `Debug`, `PartialEq`, and `Clone` (v0.7.64). Nucleor doesn't auto-derive Eq / Hash / Default / Copy / Ord / PartialOrd / etc. — anything other than those listed above is a no-op. Use sites that depend on a dropped derive (`Default::default()`, `a.clone()`, etc.) will fail at the use site with TYP-011 / TYP-005 / TYP-006."
                        };
                        print(str_concat(v084_intro, str_concat(trimmed_v060, v084_body)));
                    };
                };
            };
            p = p + 2;
            let mut depth: i64 = 1;
            while p < slen && depth > 0 {
                let ch: i64 = str_char_at(src, p);
                if ch == 34 {
                    p = p + 1;
                    while p < slen && str_char_at(src, p) != 34 {
                        if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                        else { p = p + 1; };
                    };
                    if p < slen { p = p + 1; };
                } else {
                    if ch == 91 { depth = depth + 1; }
                    else if ch == 93 { depth = depth - 1; };
                    p = p + 1;
                };
            };
        }
        else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        }
        else if c == 92 && p + 1 < slen && str_char_at(src, p + 1) == 32 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        }
        else if is_alpha(c) == 1 {
            //  canonical
            // Rust prefix-quoted string literals `r"..."` (raw string,
            // no escapes), `b"..."` (byte string), `c"..."` (C string),
            // `r#"..."#` (raw with hashes), `br"..."` (byte raw) all pre-fix lexed as the
            // bare prefix identifier (`r` / `b` / `br`) followed by a
            // string literal — the parser then read the prefix as a
            // fn-name + the string as the call's first arg, producing
            // confusing TYP-005 "undefined function 'r'" / "'b'" /
            // "'br'". Halt at lex with a clean diag pointing at the
            // workaround.
            if c == 114 && p + 1 < slen && str_char_at(src, p + 1) == 34 {
                print("ERROR: raw string literals `r\"...\"` are not yet supported in Nucleor. Workaround: write the canonical form `\"...\"` and escape backslashes / quotes manually (`\\\\`, `\\\"`, etc.).");
                panic("nucleor: raw string `r\"...\"` not yet supported (see ERROR diagnostic above)");
            };
            if c == 114 && p + 1 < slen && str_char_at(src, p + 1) == 35 {
                print("ERROR: raw identifier prefix `r#name` (used in Rust to bind a name that collides with a keyword, e.g. `let r#type: i64 = 42;`) is not yet supported in Nucleor. Workaround: rename the binding to a non-keyword spelling — Nucleor's keyword set is small and renames are usually mechanical.");
                panic("nucleor: raw identifier `r#name` not yet supported (see ERROR diagnostic above)");
            };
            if c == 98 && p + 1 < slen && str_char_at(src, p + 1) == 34 {
                print("ERROR: byte string literals `b\"...\"` are not yet supported in Nucleor. Workaround: build a `Vec<u8>` explicitly via `let mut bs: Vec<u8> = Vec::new(); vec_u8_push(bs, 'h' as u8); ...`.");
                panic("nucleor: byte string `b\"...\"` not yet supported (see ERROR diagnostic above)");
            };
            if c == 99 && p + 1 < slen && str_char_at(src, p + 1) == 34 {
                print("ERROR: C string literals `c\"...\"` are not yet supported in Nucleor. Workaround: use a normal string literal and handle the trailing NUL explicitly at the FFI boundary, e.g. `\"hello\\0\"` when the callee expects a NUL-terminated buffer.");
                panic("nucleor: C string `c\"...\"` not yet supported (see ERROR diagnostic above)");
            };
            if c == 98 && p + 1 < slen && str_char_at(src, p + 1) == 39 {
                print("ERROR: byte literal `b'A'` (Rust u8 ASCII-value form) is not yet supported in Nucleor. Sister to the existing `b\"...\"` (byte string) halt.");
                print("       Workaround: use a regular char literal and cast — `'A' as i64` or `'A' as u8`.");
                panic("nucleor: byte literal `b'A'` not yet supported (see ERROR diagnostic above)");
            };
            if c == 99 && p + 1 < slen && str_char_at(src, p + 1) == 34 {
                print("ERROR: C string literals `c\"...\"` are not yet supported in Nucleor. Workaround: use a normal string literal and handle the trailing NUL explicitly at the FFI boundary, e.g. `\"hello\\0\"` when the callee expects a NUL-terminated buffer.");
                panic("nucleor: C string `c\"...\"` not yet supported (see ERROR diagnostic above)");
            };
            let st: i64 = p;
            while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
            let w: str = str_substring(src, st, p);
            tokens.push(tok_new(classify_kw(w), w, st));
        }
        else if is_digit(c) == 1 {
            // RFC-0015 phase 1+5: integer/float lexer with hex/oct/bin literals,
            // underscores, and type suffixes.
            //   0x... = hex   (e.g., 0xAB, 0xFFFF_FFFF)
            //   0o... = octal (e.g., 0o777)
            //   0b... = binary (e.g., 0b1010_0001)
            //   Otherwise decimal.
            // Recognised suffixes: i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128
            // usize (lexed; full type-check arrives in later phases).
            let st: i64 = p;
            let mut int_value: i64 = 0;
            let mut handled_radix: i64 = 0;
            // Detect 0x / 0o / 0b prefix
            if c == 48 && p + 1 < slen {
                let nx: i64 = str_char_at(src, p + 1);
                if nx == 120 || nx == 88 {
                    // hex -- v0.3.208: wrapping_* lets 0xFFFFFFFFFFFFFFFF
                    // (and other 64-bit-MAX-aligned literals) parse under
                    // strict-arithmetic mode. The accumulator is meant to
                    // wrap; the resulting bit pattern is what callers want.
                    p = p + 2;
                    // Lane 4 / F-021: track hex digit count, reject empty
                    // (F-016 `0x`) and overflow (>16 digits = >u64).
                    let mut v_hex_digits: i64 = 0;
                    let mut v_hex_first_us: i64 = 1;
                    let mut v_hex_last_us: i64 = 0;
                    let mut v_hex_consec_us: i64 = 0;
                    while p < slen {
                        let hc: i64 = str_char_at(src, p);
                        if hc == 95 {
                            // F-017 `0x_` — underscore at first position
                            // (no digit yet) is invalid; F-019 consecutive.
                            if v_hex_first_us == 1 {
                                panic(str_concat("error[LEX-NUM-001]: hex literal starts with `_` at byte ", str_concat(str_from_int(st), ". Underscores are digit separators; at least one hex digit is required between `0x` and the first `_`. Pre-fix `0x_` silently produced 0 with no diag.")));
                            };
                            if v_hex_last_us == 1 {
                                panic(str_concat("error[LEX-NUM-002]: consecutive `__` in hex literal at byte ", str_concat(str_from_int(p), ". Numeric underscores must separate digits, not appear consecutively. Pre-fix `0x1__2` silently produced `0x12`.")));
                            };
                            v_hex_last_us = 1;
                            v_hex_consec_us = v_hex_consec_us + 1;
                            p = p + 1;
                        }
                        else if hc >= 48 && hc <= 57 { int_value = wrapping_add(wrapping_mul(int_value, 16), hc - 48); p = p + 1; v_hex_digits = v_hex_digits + 1; v_hex_first_us = 0; v_hex_last_us = 0; }
                        else if hc >= 97 && hc <= 102 { int_value = wrapping_add(wrapping_mul(int_value, 16), hc - 87); p = p + 1; v_hex_digits = v_hex_digits + 1; v_hex_first_us = 0; v_hex_last_us = 0; }
                        else if hc >= 65 && hc <= 70 { int_value = wrapping_add(wrapping_mul(int_value, 16), hc - 55); p = p + 1; v_hex_digits = v_hex_digits + 1; v_hex_first_us = 0; v_hex_last_us = 0; }
                        else { break; };
                    };
                    // F-016 — `0x` with no digits.
                    if v_hex_digits == 0 {
                        panic(str_concat("error[LEX-NUM-003]: hex literal `0x` at byte ", str_concat(str_from_int(st), " has no hex digits. Required form: `0x<hex-digits>` (e.g. `0xAB`, `0xFF_FF`). Pre-fix this silently produced 0 with no diagnostic.")));
                    };
                    // F-018 — trailing underscore: `0x100_`.
                    if v_hex_last_us == 1 {
                        panic(str_concat("error[LEX-NUM-004]: hex literal at byte ", str_concat(str_from_int(st), " ends with `_`. Underscores must separate digits, not trail. Pre-fix `0xAB_` silently produced `0xAB` with the trailing underscore swallowed.")));
                    };
                    // F-021 — overflow: >16 hex digits = >u64. Mirrors
                    // the existing decimal NUM-021 check.
                    if v_hex_digits > 16 {
                        panic(str_concat("error[NUM-021]: hex literal at byte ", str_concat(str_from_int(st), str_concat(" has ", str_concat(str_from_int(v_hex_digits), " hex digits, exceeding u64::MAX (16 hex digits = 0xFFFFFFFFFFFFFFFF). Use a smaller literal, switch to a wide-int library, or split into multiple operations.")))));
                    };
                    handled_radix = 1;
                } else if nx == 111 || nx == 79 {
                    // octal -- v0.3.208: wrapping_* (see hex path).
                    p = p + 2;
                    let mut v_oct_digits: i64 = 0;
                    let mut v_oct_first_us: i64 = 1;
                    let mut v_oct_last_us: i64 = 0;
                    while p < slen {
                        let oc: i64 = str_char_at(src, p);
                        if oc == 95 {
                            if v_oct_first_us == 1 {
                                panic(str_concat("error[LEX-NUM-001]: octal literal starts with `_` at byte ", str_concat(str_from_int(st), ". At least one octal digit is required between `0o` and the first `_`.")));
                            };
                            if v_oct_last_us == 1 {
                                panic(str_concat("error[LEX-NUM-002]: consecutive `__` in octal literal at byte ", str_concat(str_from_int(p), ".")));
                            };
                            v_oct_last_us = 1;
                            p = p + 1;
                        }
                        else if oc >= 48 && oc <= 55 { int_value = wrapping_add(wrapping_mul(int_value, 8), oc - 48); p = p + 1; v_oct_digits = v_oct_digits + 1; v_oct_first_us = 0; v_oct_last_us = 0; }
                        else { break; };
                    };
                    if v_oct_digits == 0 {
                        panic(str_concat("error[LEX-NUM-003]: octal literal `0o` at byte ", str_concat(str_from_int(st), " has no octal digits. Required form: `0o<octal-digits>` (e.g. `0o777`).")));
                    };
                    if v_oct_last_us == 1 {
                        panic(str_concat("error[LEX-NUM-004]: octal literal at byte ", str_concat(str_from_int(st), " ends with `_`.")));
                    };
                    if v_oct_digits > 22 {
                        panic(str_concat("error[NUM-021]: octal literal at byte ", str_concat(str_from_int(st), str_concat(" has ", str_concat(str_from_int(v_oct_digits), " octal digits, exceeding u64::MAX (max 22 octal digits = 0o1777777777777777777777).")))));
                    };
                    handled_radix = 1;
                } else if nx == 98 || nx == 66 {
                    // binary -- v0.3.208: wrapping_* (see hex path).
                    p = p + 2;
                    let mut v_bin_digits: i64 = 0;
                    let mut v_bin_first_us: i64 = 1;
                    let mut v_bin_last_us: i64 = 0;
                    while p < slen {
                        let bc: i64 = str_char_at(src, p);
                        if bc == 95 {
                            if v_bin_first_us == 1 {
                                panic(str_concat("error[LEX-NUM-001]: binary literal starts with `_` at byte ", str_concat(str_from_int(st), ". At least one binary digit is required between `0b` and the first `_`.")));
                            };
                            if v_bin_last_us == 1 {
                                panic(str_concat("error[LEX-NUM-002]: consecutive `__` in binary literal at byte ", str_concat(str_from_int(p), ".")));
                            };
                            v_bin_last_us = 1;
                            p = p + 1;
                        }
                        else if bc == 48 { int_value = wrapping_mul(int_value, 2); p = p + 1; v_bin_digits = v_bin_digits + 1; v_bin_first_us = 0; v_bin_last_us = 0; }
                        else if bc == 49 { int_value = wrapping_add(wrapping_mul(int_value, 2), 1); p = p + 1; v_bin_digits = v_bin_digits + 1; v_bin_first_us = 0; v_bin_last_us = 0; }
                        else { break; };
                    };
                    if v_bin_digits == 0 {
                        panic(str_concat("error[LEX-NUM-003]: binary literal `0b` at byte ", str_concat(str_from_int(st), " has no binary digits. Required form: `0b<binary-digits>` (e.g. `0b1010`).")));
                    };
                    if v_bin_last_us == 1 {
                        panic(str_concat("error[LEX-NUM-004]: binary literal at byte ", str_concat(str_from_int(st), " ends with `_`.")));
                    };
                    if v_bin_digits > 64 {
                        panic(str_concat("error[NUM-021]: binary literal at byte ", str_concat(str_from_int(st), str_concat(" has ", str_concat(str_from_int(v_bin_digits), " binary digits, exceeding u64::MAX (max 64 binary digits).")))));
                    };
                    handled_radix = 1;
                };
            };
            let mut digit_sb: i64 = sb_new();
            if handled_radix == 0 {
                // Lane 4 / F-017/F-018/F-019/F-020: decimal underscore
                // hygiene + leading-zero rejection.
                let mut v_dec_p_track: i64 = p;
                let mut v_dec_first_char: i64 = str_char_at(src, p);
                let mut v_dec_last_was_us: i64 = 0;
                let mut v_dec_count: i64 = 0;
                while p < slen && (is_digit(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) {
                    let v_dec_ch: i64 = str_char_at(src, p);
                    if v_dec_ch == 95 {
                        if v_dec_count == 0 {
                            // Decimal can't start with `_` because that's
                            // an identifier; this branch is dead but kept
                            // for defensive symmetry.
                            panic(str_concat("error[LEX-NUM-001]: decimal literal at byte ", str_concat(str_from_int(v_dec_p_track), " starts with `_`.")));
                        };
                        if v_dec_last_was_us == 1 {
                            panic(str_concat("error[LEX-NUM-002]: consecutive `__` in decimal literal at byte ", str_concat(str_from_int(p), ". Numeric underscores must separate digits, not appear consecutively. Pre-fix `1__2` silently produced `12`.")));
                        };
                        v_dec_last_was_us = 1;
                    } else {
                        sb_append_char_at(digit_sb, src, p);
                        v_dec_count = v_dec_count + 1;
                        v_dec_last_was_us = 0;
                    };
                    p = p + 1;
                };
                // F-018: trailing underscore. We allow trailing `_` ONLY
                // if the next byte starts an integer suffix (`i`/`u`)
                // or float suffix (`f`/`.`/`e`/`E`) — that's because
                // `1_000_i64` is intentional in Rust. But bare `100_;`
                // is not. Check the next byte.
                if v_dec_last_was_us == 1 {
                    let v_dec_next: i64 = if p < slen { str_char_at(src, p) } else { 0 };
                    let v_suffix_ok_us: i64 = if v_dec_next == 105 || v_dec_next == 117 || v_dec_next == 102 || v_dec_next == 46 || v_dec_next == 101 || v_dec_next == 69 { 1 } else { 0 };
                    if v_suffix_ok_us == 0 {
                        panic(str_concat("error[LEX-NUM-004]: decimal literal at byte ", str_concat(str_from_int(v_dec_p_track), " ends with `_` (no trailing digits or suffix). Pre-fix `100_;` silently produced `100`.")));
                    };
                };
                // F-020: leading-zero rejection (`007`). C-style octal
                // doesn't exist in Nucleor; surprise hazard. The single
                // digit `0` is fine; `0.5`/`0e10`/`0u64`/`0i32` are fine
                // (the `0` followed by `.`/`e`/`u`/`i` exits this loop
                // through the float/exp/suffix paths). Reject when:
                // - first digit is `0`
                // - and there are >1 digits collected
                // - and the digit string isn't all zeros (`000` itself is
                //   ambiguous; we reject anyway since users likely meant
                //   different radix or just dropped a leading zero typo)
                if v_dec_count > 1 && v_dec_first_char == 48 {
                    panic(str_concat("error[LEX-NUM-005]: decimal literal at byte ", str_concat(str_from_int(v_dec_p_track), " has a leading zero (`007`-style). Nucleor does not support C-style octal literals; use `0o` for octal (`0o7`) or drop the leading zero (`7`). Pre-fix `007` silently lexed as decimal 7 — surprise hazard for adopters porting C/Java code.")));
                };
            };
            // digits-only e/E exponent (no fractional dot).
            // — probe's repro `let big: f64 = 1e20;` actually demonstrated
            // a LEXER bug, not the saturating-cast UB it claimed (the
            // saturating cast already works correctly per v0.3.208 et al.).
            // Pre-fix `1e20` lexed as int 1 + ident `e20`; the let-binding
            // type-coerced to f64 = 1.0. Now `<digits>e<digits>` lexes as a
            // float literal directly (Rust accepts both `1e20` and `1.0e20`).
            // The detection is gated on the CHARACTER AFTER digits being
            // 'e'/'E' followed by an optional sign + at least one digit;
            // identifier-shaped suffixes like `e_helper` still lex as
            // ident.
            let mut digits_only_exp: i64 = 0;
            if handled_radix == 0 && p < slen && (str_char_at(src, p) == 101 || str_char_at(src, p) == 69) {
                let mut probe_p: i64 = p + 1;
                if probe_p < slen {
                    let sign_ch_p: i64 = str_char_at(src, probe_p);
                    if sign_ch_p == 43 || sign_ch_p == 45 { probe_p = probe_p + 1; };
                };
                if probe_p < slen && is_digit(str_char_at(src, probe_p)) == 1 {
                    digits_only_exp = 1;
                };
            };
            if digits_only_exp == 1 {
                // Promote to f64 raw-bits path. Construct the literal text
                // as `<digits>e<+/->? <digits>` and let str_to_f64 (strtod)
                // parse it.
                let lit_st: i64 = st;
                let exp_st_p: i64 = p;
                let mut exp_p: i64 = p + 1;
                if exp_p < slen {
                    let sign_ch_e: i64 = str_char_at(src, exp_p);
                    if sign_ch_e == 43 || sign_ch_e == 45 { exp_p = exp_p + 1; };
                };
                while exp_p < slen && is_digit(str_char_at(src, exp_p)) == 1 { exp_p = exp_p + 1; };
                let lit_text: str = str_substring(src, lit_st, exp_p);
                let bits: i64 = str_to_f64(lit_text);
                // Lane 4 / F-028: Inf/NaN range check.
                if f64_bits_is_nonfinite(bits) == 1 {
                    panic(str_concat("error[LEX-NUM-FLOAT-OVERFLOW]: float literal `", str_concat(lit_text, str_concat("` at byte ", str_concat(str_from_int(lit_st), " evaluates to a non-finite value (Inf or NaN). f64 finite range is approximately ±1.7976931348623157e308; values outside this range cannot be represented as a finite f64.")))));
                };
                tokens.push(tok_new(124, bits, lit_st));
                p = exp_p;
                continue;
            };
            // Check for f64 literal: digits DOT digits
            if p < slen && str_char_at(src, p) == 46 && p + 1 < slen && is_digit(str_char_at(src, p + 1)) == 1 {
                // f64 literal — parse integer.fraction, encode as bitcast i64
                let int_part: i64 = str_to_int(sb_to_str(digit_sb));
                p = p + 1; // skip dot
                let frac_st: i64 = p;
                let mut frac_sb: i64 = sb_new();
                while p < slen && (is_digit(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) {
                    if str_char_at(src, p) != 95 {
                        sb_append_char_at(frac_sb, src, p);
                    };
                    p = p + 1;
                };
                let raw_frac_str: str = sb_to_str(frac_sb);
                // NUC-FEEDBACK-005 — truncate fractional digits to
                // the encoder's 6-digit (millionth) precision BEFORE
                // computing frac_div. The truncate path handles literals
                // where the first 6 frac digits carry meaningful value.
                // NUC-FEEDBACK-006 — for SUB-MICRO literals
                // (`0.00000001` = 1e-8 used as AdamW eps, etc.), the
                // first 6 frac digits are all '0' and truncation still
                // produces zero. Falling back to the runtime
                // `__nucleor_str_to_f64` parser via the str_to_f64
                // helper gives full IEEE-754 precision. The bit
                // pattern is stored as token kind 124 (raw-bits f64
                // literal); parse_primary emits AST kind 72 which
                // lower_expr emits as a direct const_int (no
                // f64_from_scaled divide needed since the value IS
                // already the f64 bit pattern).
                // NUC-FEEDBACK-005 corrected — the all-zero
                // gate was too narrow. Long literals with non-zero
                // first six digits like `0.7978845608028654` still
                // fell into the truncate-to-six path and silently lost
                // 10+ decimal digits of precision (the literal became
                // `0.797884` after divide-by-1e6). Promote ANY literal
                // with more than six fractional digits to the raw-bits
                // path. Short literals (≤ 6 frac digits) still use the
                // scaled-int path — frac_div is an exact power of ten,
                // so the runtime divide rounds once to the closest f64
                // (same precision an IEEE parser would give).
                // scientific notation (e/E exponent). Pre-fix
                // `1.0e30` lexed as `1.0` then identifier-`e` then int-30,
                // silently truncating the value to 1.0 and surfacing as a
                // bizarre downstream type error or as `big as i32 = 1`
                // (the user's reported f64-out-of-range repro). Adopters
                // writing canonical Rust literals (`1.0e10`, `2.5e-3`, etc.)
                // got silent miscomputes.
                // Detect e/E after fractional digits, consume optional sign
                // + digits, append to literal text, and force the raw-bits
                // path so str_to_f64 (strtod) parses with full precision.
                let mut exp_str: str = "";
                if p < slen {
                    let exp_ch: i64 = str_char_at(src, p);
                    if exp_ch == 101 || exp_ch == 69 {
                        let exp_st: i64 = p;
                        let mut exp_p: i64 = p + 1;
                        if exp_p < slen {
                            let sign_ch: i64 = str_char_at(src, exp_p);
                            if sign_ch == 43 || sign_ch == 45 { exp_p = exp_p + 1; };
                        };
                        let mut has_exp_digits: i64 = 0;
                        while exp_p < slen && is_digit(str_char_at(src, exp_p)) == 1 {
                            has_exp_digits = 1;
                            exp_p = exp_p + 1;
                        };
                        if has_exp_digits == 1 {
                            exp_str = str_substring(src, exp_st, exp_p);
                            p = exp_p;
                        };
                    };
                };
                let raw_frac_len: i64 = str_len(raw_frac_str);
                let mut use_raw_bits: i64 = 0;
                if raw_frac_len > 6 { use_raw_bits = 1; };
                if str_len(exp_str) > 0 { use_raw_bits = 1; };
                if use_raw_bits == 1 {
                    let lit_text: str = str_concat(str_from_int(int_part), str_concat(".", str_concat(raw_frac_str, exp_str)));
                    let bits: i64 = str_to_f64(lit_text);
                    // Lane 4 / F-028: Inf/NaN range check.
                    if f64_bits_is_nonfinite(bits) == 1 {
                        panic(str_concat("error[LEX-NUM-FLOAT-OVERFLOW]: float literal `", str_concat(lit_text, str_concat("` at byte ", str_concat(str_from_int(st), " evaluates to a non-finite value (Inf or NaN). f64 finite range is approximately ±1.7976931348623157e308.")))));
                    };
                    tokens.push(tok_new(124, bits, st));
                } else {
                    let frac_str: str = if raw_frac_len > 6 { str_substring(raw_frac_str, 0, 6) } else { raw_frac_str };
                    let frac_val: i64 = str_to_int(frac_str);
                    let frac_len: i64 = str_len(frac_str);
                    // Compute frac_divisor = 10^frac_len
                    let mut frac_div: i64 = 1;
                    let mut fi: i64 = 0;
                    while fi < frac_len { frac_div = frac_div * 10; fi = fi + 1; };
                    // Encode: store int_part and frac as token type 70 (f64 literal)
                    // Value = int_part * 1000000 + frac_val * (1000000 / frac_div)
                    let encoded: i64 = int_part * 1000000 + frac_val * (1000000 / frac_div);
                    tokens.push(tok_new(70, encoded, st));
                };
                // Consume optional float suffix: f32 or f64
                if p < slen && str_char_at(src, p) == 102 {
                    let suf_st: i64 = p;
                    while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
                    let suf: str = str_substring(src, suf_st, p);
                    if str_eq(suf, "f32") == 0 && str_eq(suf, "f64") == 0 {
                        // Not actually a suffix; rewind.
                        p = suf_st;
                    } else if str_eq(suf, "f32") == 1 {
                        // NUC-FEEDBACK-002 fix: rewrite the just-
                        // emitted token type from 70 (generic float) to 125
                        // (f32-typed) so the parser/lowerer can route the
                        // literal through f32_from_scaled instead of
                        // f64_from_scaled. Pre-fix the f32 suffix was
                        // consumed and discarded -> 1.0f32 silently became
                        // 1.0f64 bits, which when read back as f32 = 0.0
                        // (silent miscompute on Vec<f32> push of literals).
                        let last_tok: Vec<i32> = vec_get(tokens, vec_len(tokens) - 1);
                        vec_set(last_tok, 0, 125);
                    };
                };
                if p < slen && str_char_at(src, p) == 123 {
                    tokens.push(tok_new(83, 0, p));
                    p = p + 1;
                }
            } else {
                if handled_radix == 0 && p < slen && str_char_at(src, p) == 46 {
                    let next_after_dot: i64 = if p + 1 < slen { str_char_at(src, p + 1) } else { 0 };
                    if next_after_dot != 46 {
                        panic(str_concat("error[LEX-NUM-FLOAT-FORM]: trailing-dot float literal at byte ", str_concat(str_from_int(st), ". Nucleor requires at least one digit after the decimal point; write `1.0` instead of `1.`. Pre-fix this lexed as integer `1` followed by field-access `.`, causing wrong-class parser/type diagnostics.")));
                    };
                };
                // NUM-021 — decimal literal too wide for u64.
                // Pre-fix `let x: i64 = 99999999999999999999;` (a 20-digit
                // value > u64::MAX) silently wrapped through str_to_int's
                // wrapping_mul/add accumulator, producing
                // 7766279631452241919 — a meaningless garbage bit pattern.
                // Single sb_to_str call (consumes digit_sb), use the
                // string both for the check AND the str_to_int call.
                // Hex/oct/bin literals (handled_radix == 1) keep the
                // existing wrap behavior since their bit pattern is
                // expected.
                let dig_str: str = if handled_radix == 1 { "" } else { sb_to_str(digit_sb) };
                if handled_radix == 0 {
                    let dig_len: i64 = str_len(dig_str);
                    let mut overflow_v119: i64 = 0;
                    if dig_len > 20 { overflow_v119 = 1; };
                    if dig_len == 20 {
                        let u64_max_v119: str = "18446744073709551615";
                        let mut cmp_i: i64 = 0;
                        while cmp_i < 20 {
                            let dc_v119: i64 = str_char_at(dig_str, cmp_i);
                            let mc_v119: i64 = str_char_at(u64_max_v119, cmp_i);
                            if dc_v119 > mc_v119 { overflow_v119 = 1; cmp_i = 20; }
                            else if dc_v119 < mc_v119 { cmp_i = 20; }
                            else { cmp_i = cmp_i + 1; };
                        };
                    };
                    if overflow_v119 == 1 {
                        panic(str_concat("error[NUM-021]: integer literal `", str_concat(dig_str, "` exceeds u64::MAX (18446744073709551615). Use a smaller literal, switch to a wide-int library, or write the value as a hex literal `0x...` if you intentionally want a specific bit pattern."))));
                    };
                    //  also halt on decimal
                    // literals in (i64::MAX, u64::MAX] that lack an
                    // explicit unsigned suffix (`u8`/`u16`/`u32`/`u64`/
                    // `usize`/`u128`). Pre-fix these wrapped silently to
                    // i64::MIN-region bit patterns. The most common
                    // failure mode was `match x { 9223372036854775808
                    // => ... }` against an i64 scrutinee — the wrapped
                    // pattern never matched, producing a silent dead
                    // arm. Adopters who genuinely want the u64 bit
                    // pattern can either:
                    //   (a) add the `u64` suffix: `9223372036854775808u64`,
                    //   (b) use the hex form: `0x8000000000000000`,
                    //   (c) use the canonical signed form:
                    //       `(-9223372036854775807) - 1` for i64::MIN,
                    //       which is already supported by v0.6.49.
                    if overflow_v119 == 0 && dig_len == 19 {
                        let i64_max_v068: str = "9223372036854775807";
                        let mut over_i64_v068: i64 = 0;
                        let mut cmp_v068: i64 = 0;
                        while cmp_v068 < 19 {
                            let dc_v068: i64 = str_char_at(dig_str, cmp_v068);
                            let mc_v068: i64 = str_char_at(i64_max_v068, cmp_v068);
                            if dc_v068 > mc_v068 { over_i64_v068 = 1; cmp_v068 = 19; }
                            else if dc_v068 < mc_v068 { cmp_v068 = 19; }
                            else { cmp_v068 = cmp_v068 + 1; };
                        };
                        if over_i64_v068 == 1 {
                            // Peek for an unsigned suffix immediately
                            // after the digit string. If present, the
                            // user is explicit about u-typed semantics
                            // — accept the bit pattern.
                            let mut suf_v068_ok: i64 = 0;
                            if p < slen {
                                let nx_v068: i64 = str_char_at(src, p);
                                if nx_v068 == 117 {
                                    // 'u' — check u8/u16/u32/u64/u128/usize
                                    let mut sk_v068: i64 = p + 1;
                                    while sk_v068 < slen && is_alnum(str_char_at(src, sk_v068)) == 1 { sk_v068 = sk_v068 + 1; };
                                    let suf_v068: str = str_substring(src, p, sk_v068);
                                    if str_eq(suf_v068, "u8") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "u16") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "u32") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "u64") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "u128") == 1 { suf_v068_ok = 1; };
                                    if str_eq(suf_v068, "usize") == 1 { suf_v068_ok = 1; };
                                };
                            };
                            // also accept when the previous
                            // token is unary-minus (token kind 21).
                            // `-9223372036854775808` is the canonical
                            // Rust i64::MIN form; v0.6.49 already wires
                            // const-fold + lower-time acceptance for
                            // this case. The v0.6.68 lex-time halt
                            // regressed v0.6.43 + v0.6.49 fixtures.
                            // Restore by pre-checking the previous
                            // token: if it's `-` (token 21), the user
                            // is writing the canonical signed form,
                            // accept the literal.
                            if suf_v068_ok == 0 {
                                let tcnt: i64 = vec_len(tokens);
                                if tcnt > 0 {
                                    let prev_tok: Vec<i32> = vec_get(tokens, tcnt - 1);
                                    if tok_type(prev_tok) == 21 {
                                        suf_v068_ok = 1;
                                    };
                                };
                            };
                            if suf_v068_ok == 0 {
                                panic(str_concat("error[NUM-021]: decimal literal `", str_concat(dig_str, "` exceeds i64::MAX (9223372036854775807) and lacks an explicit unsigned suffix. Pre-v0.6.68 the value silently wrapped to a negative i64 bit pattern, producing the most-common failure mode `match x { <this> => ... }` where the arm never matches against an i64 scrutinee (silent dead arm). Workarounds: (a) add a `u64` suffix (`9223372036854775808u64`); (b) use the hex form (`0x8000000000000000`); (c) for i64::MIN specifically, use the canonical signed form `(-9223372036854775807) - 1` (already accepted as a const since v0.6.49).")));
                            };
                        };
                    };
                };
                let mut int_suffix: i64 = 0;
                // Consume optional integer suffix: i8 i16 i32 i64 u8 u16 u32 u64 usize isize
                if p < slen && (str_char_at(src, p) == 105 || str_char_at(src, p) == 117) {
                    let suf_st: i64 = p;
                    while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
                    let suf: str = str_substring(src, suf_st, p);
                    let mut is_known: i64 = 0;
                    if str_eq(suf, "i8") == 1 { is_known = 1; };
                    if str_eq(suf, "i16") == 1 { is_known = 1; };
                    if str_eq(suf, "i32") == 1 { is_known = 1; };
                    if str_eq(suf, "i64") == 1 { is_known = 1; };
                    if str_eq(suf, "i128") == 1 { is_known = 1; };
                    if str_eq(suf, "isize") == 1 { is_known = 1; };
                    if str_eq(suf, "u8") == 1 { is_known = 1; };
                    if str_eq(suf, "u16") == 1 { is_known = 1; };
                    if str_eq(suf, "u32") == 1 { is_known = 1; };
                    if str_eq(suf, "u64") == 1 { is_known = 1; };
                    if str_eq(suf, "u128") == 1 { is_known = 1; };
                    if str_eq(suf, "usize") == 1 { is_known = 1; };
                    if is_known == 0 {
                        // Lane 4 / F-023: unknown int suffix (`1i9`,
                        // `1u42`). Pre-fix this rewound to suf_st and
                        // re-lexed `i9` / `u42` as a fresh identifier
                        // — silently dropping the suffix and feeding
                        // the ident into the next-token expression-stmt
                        // silent-drop path (F-012). Now: reject.
                        panic(str_concat("error[LEX-NUM-SUFFIX]: unknown integer-literal suffix `", str_concat(suf, str_concat("` at byte ", str_concat(str_from_int(suf_st), ". Recognized suffixes: i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize. Pre-fix the suffix was silently rewound and re-lexed as an identifier, dropping the user's typed-literal intent.")))));
                    };
                    int_suffix = int_suffix_code(suf);
                };
                let int_lit_value: i64 = if handled_radix == 1 { int_value } else { str_to_int(dig_str) };
                let int_tok_pos: i64 = tok_pos_encode_int_suffix(st, int_suffix);
                let mut int_tok: Vec<i32> = tok_new(2, int_lit_value, int_tok_pos);
                tokens.push(int_tok);
                // Lane 4 / F-022: an int literal immediately followed
                // by an alphabetic byte (no `i`/`u` so the suffix branch
                // didn't take) means the user wrote something like
                // `1z42` or `1abc`. Pre-fix `z42` lexed as a fresh
                // ident which then dropped silently via the F-012
                // expression-stmt silent-drop path. Reject.
                if p < slen {
                    let v_after_int: i64 = str_char_at(src, p);
                    if (v_after_int >= 65 && v_after_int <= 90) || (v_after_int >= 97 && v_after_int <= 122) {
                        // Find the end of the suffix-shaped run for the diag.
                        let mut v_end_int: i64 = p;
                        while v_end_int < slen && is_alnum(str_char_at(src, v_end_int)) == 1 { v_end_int = v_end_int + 1; };
                        let v_bad_suffix: str = str_substring(src, p, v_end_int);
                        panic(str_concat("error[LEX-NUM-SUFFIX]: unrecognised suffix `", str_concat(v_bad_suffix, str_concat("` after integer literal at byte ", str_concat(str_from_int(p), ". Recognized integer suffixes start with `i` or `u` (i8/i16/.../i128/isize/u8/.../u128/usize); float suffixes (f32/f64) require a fractional dot (e.g. `1.0f32`, not `1f32`). Pre-fix any other alphabetic run immediately after digits was silently dropped as a stray identifier.")))));
                    };
                };
                if p < slen && str_char_at(src, p) == 123 {
                    tokens.push(tok_new(83, 0, p));
                    p = p + 1;
                }
            };
        }
        else if c == 34 {
            let st: i64 = p; p = p + 1;
            let mut sb: i64 = sb_new();
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 10 || str_char_at(src, p) == 13 {
                    panic(str_concat("error[LEX-STRING-NEWLINE]: raw newline in string literal opened at byte ", str_concat(str_from_int(st), ". Nucleor string literals must stay on one physical line; use `\\n` or `\\r\\n` escapes, or split and concatenate the string. Pre-fix raw CR/LF bytes were embedded silently in the literal.")));
                };
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    let nc: i64 = str_char_at(src, p + 1);
                    if nc == 110 { sb_append(sb, "\n"); } else if nc == 116 { sb_append(sb, "\t"); }
                    else if nc == 34 { sb_append(sb, "\""); } else if nc == 92 { sb_append(sb, "\\"); }
                    else if nc == 114 { sb_append_char(sb, 13); }                          // v0.5.20: \r → CR byte (ASCII 13)
                    else if nc == 48  { sb_append_char(sb, 0); }                           // v0.5.20: \0 → NUL byte (ASCII 0).
                    else if nc == 39  { sb_append(sb, "'"); }                              // \' — single quote
                    else {
                        // unknown escape sequence. Pre-fix the
                        // backslash was silently dropped and the next
                        // char emitted as-is — so `"a\zb"` became `"azb"`
                        // with no signal. Adopters typo'ing escapes (or
                        // pasting Rust raw-string content) got silent
                        // miscomputation. Halt cleanly. To opt out and
                        // get the literal next char, escape the
                        // backslash explicitly: `"a\\zb"`.
                        let bad_esc: str = str_substring(src, p, p + 2);
                        panic(str_concat("error[NR025]: unknown escape sequence `", str_concat(bad_esc, "` in string literal. Recognized escapes: `\\n`, `\\t`, `\\\"`, `\\\\`, `\\r`, `\\0`, `\\'`. To get a literal backslash + char, escape the backslash explicitly (e.g. `\\\\z`).")));
                    };
                    p = p + 2;
                } else if str_char_at(src, p) == 92 {
                    panic(str_concat("error[LEX-STRING-EOF]: string literal opened at byte ", str_concat(str_from_int(st), " ends with a trailing backslash before EOF. The escape sequence is incomplete; write `\\\\` for a literal backslash or close the string before EOF.")));
                } else { sb_append_char_at(sb, src, p); p = p + 1; };
            };
            if p < slen { p = p + 1; }
            else {
                panic(str_concat("error[LEX-STRING-EOF]: unterminated string literal opened at byte ", str_concat(str_from_int(st), ". Add the closing `\"` before EOF.")));
            };
            tokens.push(tok_new(3, sb_to_str(sb), st));
        }
        else if c == 45 && p + 1 < slen && str_char_at(src, p + 1) == 62 { tokens.push(tok_new(41, 0, p)); p = p + 2; }
        else if c == 61 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(30, 0, p)); p = p + 2; }
        else if c == 61 && p + 1 < slen && str_char_at(src, p + 1) == 62 { tokens.push(tok_new(64, 0, p)); p = p + 2; }
        else if c == 33 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(31, 0, p)); p = p + 2; }
        else if c == 60 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(34, 0, p)); p = p + 2; }
        else if c == 62 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(35, 0, p)); p = p + 2; }
        else if c == 38 && p + 1 < slen && str_char_at(src, p + 1) == 38 { tokens.push(tok_new(36, 0, p)); p = p + 2; }
        // bitwise compound assigns. `&=` → token 117,
        // `|=` → 118, `^=` → 119. Lexed BEFORE the bare `&`/`|`/`^`
        // single-token rules below so `&=` doesn't split as `&` `=`.
        // `<<=` and `>>=` follow the same pattern (120/121).
        else if c == 38 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(117, 0, p)); p = p + 2; }
        else if c == 38 { tokens.push(tok_new(82, 0, p)); p = p + 1; }
        else if c == 124 && p + 1 < slen && str_char_at(src, p + 1) == 124 { tokens.push(tok_new(37, 0, p)); p = p + 2; }
        else if c == 124 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(118, 0, p)); p = p + 2; }
        else if c == 124 { tokens.push(tok_new(65, 0, p)); p = p + 1; }
        // bitwise XOR `^` as token 94 — paired with the
        // `parse_bitwise` tier (tier between parse_eq and parse_and_expr)
        // and tok_to_ir mapping (94 → iop 15 = LLVM xor i64).
        else if c == 94 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(119, 0, p)); p = p + 2; }
        else if c == 94 { tokens.push(tok_new(94, 0, p)); p = p + 1; }
        // shift-left `<<` as token 115. Shift-right `>>`
        // is intentionally NOT lexed as a single token — generic
        // syntax `Vec<Vec<i64>>` ends in `>>` and the seven angle-
        // group skips would all need updating to handle the merged
        // form. Instead, parse_shift detects two adjacent `>` tokens
        // and consumes both as shift-right at parse time. `<<` has
        // no such conflict so a single token is safe here.
        else if c == 60 && p + 2 < slen && str_char_at(src, p + 1) == 60 && str_char_at(src, p + 2) == 61 { tokens.push(tok_new(120, 0, p)); p = p + 3; }
        else if c == 60 && p + 1 < slen && str_char_at(src, p + 1) == 60 { tokens.push(tok_new(115, 0, p)); p = p + 2; }
        // `>>=` lexed as a single token 121 — has no
        // conflict with generics because `>>=` (3 chars) doesn't
        // appear in any valid generic-position form.
        else if c == 62 && p + 2 < slen && str_char_at(src, p + 1) == 62 && str_char_at(src, p + 2) == 61 { tokens.push(tok_new(121, 0, p)); p = p + 3; }
        else if c == 58 && p + 1 < slen && str_char_at(src, p + 1) == 58 { tokens.push(tok_new(46, 0, p)); p = p + 2; }
        // compound-assignment tokens (`+=`, `-=`, `*=`, `/=`, `%=`).
        // Lex as single tokens kind 110-114 so the parser can desugar
        // `LHS op= RHS` to `LHS = LHS op RHS` cleanly. Without this,
        // `x += 5;` lexed as separate `+` and `=` tokens which the parser
        // dropped silently. Token kinds 110/111/112/113/114 are reserved
        // for the five compound-op forms in op-token order.
        // postfix `++` / `--` tokens (130 / 131). Must be checked
        // BEFORE the single-char `+` / `-` fallbacks. `x++` desugars to
        // `x = x + 1` in parse_stmt; same as `x += 1`. `x--` → `x = x - 1`.
        else if c == 43 && p + 1 < slen && str_char_at(src, p + 1) == 43 { tokens.push(tok_new(130, 0, p)); p = p + 2; }
        else if c == 43 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(110, 0, p)); p = p + 2; }
        else if c == 43 { tokens.push(tok_new(20, 0, p)); p = p + 1; }
        else if c == 45 && p + 1 < slen && str_char_at(src, p + 1) == 45 { tokens.push(tok_new(131, 0, p)); p = p + 2; }
        else if c == 45 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(111, 0, p)); p = p + 2; }
        else if c == 45 { tokens.push(tok_new(21, 0, p)); p = p + 1; }
        else if c == 42 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(112, 0, p)); p = p + 2; }
        else if c == 42 { tokens.push(tok_new(22, 0, p)); p = p + 1; }
        else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(113, 0, p)); p = p + 2; }
        else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 42 {
            print("ERROR: block comments `/* ... */` (and doc-block `/** ... */`) are not yet supported in Nucleor. Workaround: convert each line of the block comment to a line comment — replace `/* abc */` with `// abc`, and a multi-line block with a sequence of `// ...` lines.");
            panic("nucleor: block comment `/* ... */` not yet supported (see ERROR diagnostic above)");
        }
        else if c == 47 { tokens.push(tok_new(23, 0, p)); p = p + 1; }
        else if c == 37 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(114, 0, p)); p = p + 2; }
        else if c == 37 { tokens.push(tok_new(24, 0, p)); p = p + 1; }
        else if c == 61 { tokens.push(tok_new(40, 0, p)); p = p + 1; }
        else if c == 60 { tokens.push(tok_new(32, 0, p)); p = p + 1; }
        else if c == 62 { tokens.push(tok_new(33, 0, p)); p = p + 1; }
        else if c == 33 { tokens.push(tok_new(38, 0, p)); p = p + 1; }
        else if c == 58 { tokens.push(tok_new(42, 0, p)); p = p + 1; }
        else if c == 59 { tokens.push(tok_new(43, 0, p)); p = p + 1; }
        else if c == 44 { tokens.push(tok_new(44, 0, p)); p = p + 1; }
        else if c == 46 && p + 1 < slen && str_char_at(src, p + 1) == 46 && p + 2 < slen && str_char_at(src, p + 2) == 61 {
            // ..= inclusive range
            tokens.push(tok_new(96, 0, p));
            p = p + 3;
        }
        else if c == 46 && p + 1 < slen && str_char_at(src, p + 1) == 46 { tokens.push(tok_new(58, 0, p)); p = p + 2; }
        else if c == 46 && p + 1 < slen && is_digit(str_char_at(src, p + 1)) == 1 {
            let dot_prev: i64 = if p > 0 { str_char_at(src, p - 1) } else { 0 };
            if is_alnum(dot_prev) == 1 || dot_prev == 95 || dot_prev == 41 || dot_prev == 93 {
                tokens.push(tok_new(45, 0, p));
                p = p + 1;
            } else {
                panic(str_concat("error[LEX-NUM-FLOAT-FORM]: leading-dot float literal at byte ", str_concat(str_from_int(p), ". Nucleor requires a leading zero; write `0.5` instead of `.5`.")));
            };
        }
        else if c == 46 { tokens.push(tok_new(45, 0, p)); p = p + 1; }
        else if c == 40 { tokens.push(tok_new(50, 0, p)); p = p + 1; }
        else if c == 41 { tokens.push(tok_new(51, 0, p)); p = p + 1; }
        else if c == 123 { tokens.push(tok_new(52, 0, p)); p = p + 1; }
        else if c == 125 { tokens.push(tok_new(53, 0, p)); p = p + 1; }
        else if c == 91 { tokens.push(tok_new(54, 0, p)); p = p + 1; }
        else if c == 93 { tokens.push(tok_new(55, 0, p)); p = p + 1; }
        else if c == 63 { tokens.push(tok_new(97, 0, p)); p = p + 1; }
        else if c == 39 {
            // char literals `'X'` and escape forms
            // `'\n'`/`'\t'`/`'\r'`/`'\0'`/`'\\'`/`'\''`. Emit as int
            // literal (token kind 2 with the codepoint as the value)
            // — matches Rust semantics where `'A' as i64 == 65` and
            // matches the convention documented at the prior
            // lifetime-only branch ("chars use u8/u32 via int literals").
            // Pre-v0.3.105, `'\n'` was lexed as a malformed lifetime
            // marker and silently produced 0 at runtime, a HIGH-blast
            // miscompute for any code using char escapes (parsers,
            // I/O, ASCII manipulation). Lifetime parsing is preserved
            // as the fallback when the pattern doesn't match
            // `'<one-char>'`.
            let st: i64 = p;
            // Try to recognize a char literal first.
            let mut handled: i64 = 0;
            if p + 2 < slen {
                let n1: i64 = str_char_at(src, p + 1);
                let n2: i64 = str_char_at(src, p + 2);
                // Plain `'X'` form — single non-backslash char.
                if n1 != 92 && n1 != 39 && n2 == 39 {
                    tokens.push(tok_new(2, n1, st));
                    p = p + 3;
                    handled = 1;
                };
            };
            if handled == 0 && p + 3 < slen && str_char_at(src, p + 1) == 92 && str_char_at(src, p + 3) == 39 {
                let esc: i64 = str_char_at(src, p + 2);
                let mut val: i64 = esc;
                if esc == 110 { val = 10; };       // \n
                if esc == 116 { val = 9; };        // \t
                if esc == 114 { val = 13; };       // \r
                if esc == 48  { val = 0; };        // \0
                if esc == 92  { val = 92; };       // \\
                if esc == 39  { val = 39; };       // \'
                if esc == 34  { val = 34; };       // \"
                tokens.push(tok_new(2, val, st));
                p = p + 4;
                handled = 1;
            };
            if handled == 0 && p + 4 < slen && str_char_at(src, p + 1) == 92 && str_char_at(src, p + 2) == 117 && str_char_at(src, p + 3) == 123 {
                print("ERROR: Unicode-escape char literal `'\\u{NNNN}'` (e.g. `'\\u{0041}'`, `'\\u{1F600}'`) is not yet supported in Nucleor. Pre-v0.7.29 the char-lit lexer fell through to the lifetime-token path and the v0.7.2 loop-label halt fired with a wrong-class diagnostic about labels.");
                print("       Workaround: write the codepoint as an integer literal cast — `let c: i64 = 0x0041;` (for 'A') or `let c: i64 = 0x1F600;` (for an emoji codepoint). All Nucleor char-equivalent comparisons are integer-equivalent under the i64-everywhere ABI.");
                panic("nucleor: Unicode-escape char literal `'\\u{...}'` not yet supported (see ERROR diagnostic above)");
            };
            if handled == 0 {
                // F-025/F-026 (Lane 4): the apostrophe is followed by
                // something that's neither a one-char (or escaped) char
                // literal nor a `\u{...}` form. Pre-fix this dropped
                // through to the lifetime-token branch and v0.7.2's
                // loop-label halt fired with a wrong-class diagnostic.
                // Detect specific malformed-char-literal shapes BEFORE
                // taking the lifetime fallback.
                // Empty char `''` — token at p+1 is the closing apostrophe.
                if p + 1 < slen && str_char_at(src, p + 1) == 39 {
                    panic(str_concat("error[LEX-CHAR-EMPTY]: empty character literal `''` at byte ", str_concat(str_from_int(st), ". A char literal must contain exactly one character (or one escape sequence). Pre-fix this surfaced as the wrong-class \"loop labels not yet supported\" diagnostic.")));
                };
                // Multi-char `'ab'` / `'abc'` etc. Detect: single-byte
                // chars followed by an apostrophe within a short window
                // and no `:` (which would mark a lifetime-followed-by-
                // type-bound, e.g. `'a:`). Scan forward to the next
                // apostrophe; if found within 8 chars and the first
                // post-apos char isn't an identifier-start/colon,
                // it's a multi-char literal.
                // do not mistake lifetime lists
                // such as `<'a, 'b>` or ref types such as `&'a T` for
                // malformed char literals just because a second lifetime
                // apostrophe appears nearby.
                let mut lifetime_like: i64 = 0;
                if p + 1 < slen {
                    let lt_c1_v110: i64 = str_char_at(src, p + 1);
                    let lt_start: i64 = if (lt_c1_v110 >= 97 && lt_c1_v110 <= 122) || (lt_c1_v110 >= 65 && lt_c1_v110 <= 90) || lt_c1_v110 == 95 { 1 } else { 0 };
                    if lt_start == 1 {
                        let mut lt_end: i64 = p + 2;
                        while lt_end < slen && (is_alnum(str_char_at(src, lt_end)) == 1 || str_char_at(src, lt_end) == 95) { lt_end = lt_end + 1; };
                        if lt_end < slen {
                            let after_lt: i64 = str_char_at(src, lt_end);
                            if after_lt == 44 || after_lt == 62 || after_lt == 58 || after_lt == 43 || after_lt == 41 || after_lt == 123 || after_lt == 125 {
                                lifetime_like = 1;
                            } else if after_lt == 32 || after_lt == 9 || after_lt == 10 || after_lt == 13 {
                                let mut ws_v110: i64 = lt_end;
                                while ws_v110 < slen {
                                    let wc_v110: i64 = str_char_at(src, ws_v110);
                                    if wc_v110 != 32 && wc_v110 != 9 && wc_v110 != 10 && wc_v110 != 13 { break; };
                                    ws_v110 = ws_v110 + 1;
                                };
                                if ws_v110 >= slen || str_char_at(src, ws_v110) != 39 {
                                    lifetime_like = 1;
                                };
                            };
                        };
                    };
                };
                let mut scan_ap: i64 = p + 1;
                let mut found_close_ap: i64 = 0;
                let mut ap_chars: i64 = 0;
                while scan_ap < slen && scan_ap < p + 10 {
                    let sch: i64 = str_char_at(src, scan_ap);
                    if sch == 39 { found_close_ap = 1; break; };
                    if sch == 10 || sch == 13 { break; };
                    ap_chars = ap_chars + 1;
                    scan_ap = scan_ap + 1;
                };
                if lifetime_like == 0 && found_close_ap == 1 && ap_chars >= 2 {
                    panic(str_concat("error[LEX-CHAR-MULTI]: multi-character literal at byte ", str_concat(str_from_int(st), str_concat(": `", str_concat(str_substring(src, st, scan_ap + 1), "`. A char literal must contain exactly one character. Use a string literal `\"...\"` for multi-character text, or split into separate char literals. Pre-fix this surfaced as the wrong-class \"loop labels not yet supported\" diagnostic.")))));
                };
                // T2.5 (v0.2.351) fallback: apostrophe → lifetime token.
                p = p + 1;
                let id_st: i64 = p;
                while p < slen && (is_alnum(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) { p = p + 1; };
                let lt_name: str = str_substring(src, id_st, p);
                tokens.push(tok_new(98, lt_name, st));
            };
        }
        else {
            // Lane 4 / F-066: terminal `else { p = p + 1; };` was the
            // root-cause silent-accept path (closes F-003/004/005/007/
            // 008/009/010 in one move). Every byte that didn't match
            // any preceding lex rule was silently consumed without a
            // token, so adopters wrote `~`, `$`, BOM, smart-quotes,
            // zero-width space, RTL ident bytes, etc. and got exit=0
            // with the offending bytes deleted. Now: emit a precise
            // lex-time diagnostic at the offending byte. Special-case
            // a couple of common typos so the message is actionable.
            // F-011 (NUL byte): also caught here because preflight's
            // C-string read truncates at the first NUL. The preflight
            // check we add reports it explicitly with byte offset, but
            // keep this branch defensive in case a later code path
            // synthesises a NUL byte mid-string.
            if c == 0 {
                panic(str_concat("error[LEX-002]: NUL byte (0x00) in source at byte ", str_concat(str_from_int(p), ". Nucleor source must not contain embedded NUL bytes — pre-fix the file was silently truncated at the first NUL via C-string semantics, masking everything after it. Re-save the file as plain UTF-8 (or ASCII) without embedded NULs.")));
            };
            // F-009 (zero-width space U+200B = E2 80 8B), F-008 (smart
            // quotes “ ” = E2 80 9C / 9D), F-010 (any non-ASCII high
            // byte). Group 0xE2 prefix for the common Unicode-typography
            // class so the diag can name it. Otherwise just say
            // "unexpected byte 0xNN".
            let mut hint: str = "";
            if c == 226 && p + 2 < slen {
                let b1: i64 = str_char_at(src, p + 1);
                let b2: i64 = str_char_at(src, p + 2);
                if b1 == 128 && b2 == 139 { hint = " (looks like a U+200B zero-width space — known supply-chain attack vector; remove it)"; };
                if b1 == 128 && (b2 == 156 || b2 == 157) { hint = " (looks like a Unicode smart-quote U+201C/D — replace with a plain ASCII `\"`)"; };
                if b1 == 128 && (b2 == 152 || b2 == 153) { hint = " (looks like a Unicode smart-apostrophe U+2018/9 — replace with a plain ASCII `'`)"; };
            };
            if c == 36 { hint = " — `$` is not part of Nucleor's identifier grammar (idents are [A-Za-z_][A-Za-z0-9_]*)"; };
            if c == 96 { hint = " — backtick `` ` `` is not a Nucleor token"; };
            if c == 126 { hint = " — `~` is not a Nucleor operator (Rust uses `!` for bitwise-not; Nucleor doesn't yet have a bitwise-not op)"; };
            if c == 92 { hint = " — bare `\\` is not a Nucleor token (string-escape `\\n`/`\\t`/etc. work only inside `\"...\"`)"; };
            if c >= 128 { hint = " — non-ASCII byte; Nucleor identifiers are restricted to ASCII (RFC §1.3)"; };
            // Hex of the byte for the diag.
            let hex_chars: str = "0123456789ABCDEF";
            let hi: i64 = (c / 16) % 16;
            let lo: i64 = c % 16;
            let hex_str: str = str_concat(str_substring(hex_chars, hi, hi + 1), str_substring(hex_chars, lo, lo + 1));
            panic(str_concat("error[LEX-001]: unexpected byte 0x", str_concat(hex_str, str_concat(" at byte ", str_concat(str_from_int(p), str_concat(hint, ". Remove or replace the offending byte.")))))));
        };
    };
    tokens.push(tok_new(0, 0, slen));
    return tokens;
}
#[manual_drop]
fn tok_at(tokens: Vec<i32>, idx: i64) -> Vec<i32> {
    if idx >= vec_len(tokens) { return tok_new(0, 0, 0); }; return vec_get(tokens, idx);
}
#[manual_drop]
fn tok_type_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_type(tok_at(tokens, idx)); }
#[manual_drop]
fn tok_val_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_val(tok_at(tokens, idx)); }
