// =====================================================
// PARSER (from T29, unchanged)
// =====================================================
extern fn nuc_node_kind(pool: Vec<i32>, nid: i64) -> i64;
extern fn nuc_node_field(pool: Vec<i32>, nid: i64, idx: i64) -> i64;
extern fn nuc_list_len(pool: Vec<i32>, lid: i64) -> i64;
extern fn nuc_list_get(pool: Vec<i32>, lid: i64, idx: i64) -> i64;
extern fn nuc_diag_set_source(source: str) -> i64;
extern fn nuc_diag_line_for_byte(byte_off: i64) -> i64;
extern fn nuc_diag_col_for_byte(byte_off: i64) -> i64;

#[manual_drop]
fn node_add(pool: Vec<i32>, nd: Vec<i32>) -> i64 { let nid: i64 = vec_len(pool); pool.push(nd); return nid; }
#[manual_drop]
fn node_kind(pool: Vec<i32>, nid: i64) -> i64 { return nuc_node_kind(pool, nid); }
#[manual_drop]
fn node_field(pool: Vec<i32>, nid: i64, idx: i64) -> i64 { return nuc_node_field(pool, nid, idx); }
#[manual_drop]
fn node_span_sentinel() -> i64 { return 0 - 873521; }
#[manual_drop]
fn node_set_span(pool: Vec<i32>, nid: i64, byte_off: i64) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return nid; };
    if byte_off < 0 { return nid; };
    if node_kind(pool, nid) == 40 { return nid; };
    let nd: Vec<i32> = vec_get(pool, nid);
    nd.push(node_span_sentinel());
    nd.push(byte_off);
    return nid;
}
#[manual_drop]
fn node_get_span(pool: Vec<i32>, nid: i64) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0 - 1; };
    if node_kind(pool, nid) == 40 { return 0 - 1; };
    let nd: Vec<i32> = vec_get(pool, nid);
    let n: i64 = vec_len(nd);
    if n >= 3 && vec_get(nd, n - 2) == node_span_sentinel() { return vec_get(nd, n - 1); };
    return 0 - 1;
}
#[manual_drop]
fn int_lit_suffix_code(pool: Vec<i32>, nid: i64) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let nd: Vec<i32> = vec_get(pool, nid);
    if vec_len(nd) >= 3 {
        let code: i64 = vec_get(nd, 2);
        if code != node_span_sentinel() { return code; };
    };
    return 0;
}
#[manual_drop]
fn int_lit_type(pool: Vec<i32>, nid: i64) -> str {
    return int_suffix_code_type(int_lit_suffix_code(pool, nid));
}
#[manual_drop]
fn mk2(pool: Vec<i32>, k: i64, a: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(2); n.push(k); n.push(a); return node_add(pool, n); }
#[manual_drop]
fn mk3(pool: Vec<i32>, k: i64, a: i64, b: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(3); n.push(k); n.push(a); n.push(b); return node_add(pool, n); }
#[manual_drop]
fn mk4(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(4); n.push(k); n.push(a); n.push(b); n.push(c); return node_add(pool, n); }
#[manual_drop]
fn mk5(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64, d: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(5); n.push(k); n.push(a); n.push(b); n.push(c); n.push(d); return node_add(pool, n); }
#[manual_drop]
fn mk6(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64, d: i64, e: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(6); n.push(k); n.push(a); n.push(b); n.push(c); n.push(d); n.push(e); return node_add(pool, n); }
#[manual_drop]
fn mk_list(pool: Vec<i32>, items: Vec<i32>) -> i64 {
    let mut n: Vec<i32> = Vec::with_capacity(vec_len(items) + 1); n.push(40);
    let mut i: i64 = 0; while i < vec_len(items) { n.push(vec_get(items, i)); i = i + 1; };
    return node_add(pool, n);
}
#[manual_drop]
fn list_len(pool: Vec<i32>, lid: i64) -> i64 { return nuc_list_len(pool, lid); }
#[manual_drop]
fn list_get(pool: Vec<i32>, lid: i64, idx: i64) -> i64 { return nuc_list_get(pool, lid, idx); }
#[manual_drop]
fn free_token_vec(tokens: Vec<i32>) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(tokens) {
        let tok: Vec<i32> = vec_get(tokens, i);
        vec_free(tok);
        i = i + 1;
    };
    vec_free(tokens);
    return 0;
}

#[manual_drop]
fn free_node_pool(pool: Vec<i32>) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(pool) {
        let nd: Vec<i32> = vec_get(pool, i);
        vec_free(nd);
        i = i + 1;
    };
    vec_free(pool);
    return 0;
}

#[manual_drop]
fn pr(p: i64, v: i64) -> Vec<i32> { let mut r: Vec<i32> = Vec::with_capacity(2); r.push(p); r.push(v); return r; }
#[manual_drop]
fn pr_pos(r: Vec<i32>) -> i64 { return vec_get(r, 0); }
#[manual_drop]
fn pr_val(r: Vec<i32>) -> i64 { return vec_get(r, 1); }

#[manual_drop]
fn pk(tokens: Vec<i32>, pos: i64) -> i64 { return tok_type_at(tokens, pos); }
#[manual_drop]
fn pkv(tokens: Vec<i32>, pos: i64) -> i64 { return tok_val_at(tokens, pos); }
#[manual_drop]
fn tok_pos_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_pos(tok_at(tokens, idx)); }
// human-readable names for the most common NR020 tokens.
// Closes two findings (tuple-struct-decl-panic + match-on-unit-panic)
// which both surfaced as "expected token N got M" with raw IDs.
// Trimmed to the high-impact punct/keyword set to avoid bloating
// the compiler binary; less-common tokens fall back to "token N".
#[manual_drop]
fn tok_name(tt: i64) -> str {
    if tt == 0 { return "<EOF>"; };
    if tt == 1 { return "identifier"; };
    if tt == 2 { return "integer literal"; };
    if tt == 3 { return "string literal"; };
    if tt == 40 { return "`=`"; };
    if tt == 41 { return "`->`"; };
    if tt == 42 { return "`:`"; };
    if tt == 43 { return "`;`"; };
    if tt == 44 { return "`,`"; };
    if tt == 50 { return "`(`"; };
    if tt == 51 { return "`)`"; };
    if tt == 52 { return "`{`"; };
    if tt == 53 { return "`}`"; };
    if tt == 54 { return "`[`"; };
    if tt == 55 { return "`]`"; };
    if tt == 64 { return "`=>`"; };
    if tt == 70 { return "float literal"; };
    if tt == 130 { return "`++`"; };
    if tt == 131 { return "`--`"; };
    return str_concat("token ", str_from_int(tt));
}

#[manual_drop]
fn expect_tok(tokens: Vec<i32>, pos: i64, tt: i64) -> i64 {
    if pk(tokens, pos) != tt {
        // v0.4.78 NR020 — was a `print()` warning that returned `pos + 1`
        // and continued parsing. The parser produced a likely-broken AST,
        // type-check + lower happily consumed it, and codegen emitted a
        // silently-wrong binary. Triaged via the `@` binding pattern
        // probe (`x @ 1..=10`) which printed a parse error AND ran to
        // exit=0 with no output. Promoted to a hard panic — adopters
        // who hit this previously shipped broken binaries.
        // emit token-name table output instead of raw IDs.
        // Pre-fix message: "expected token 52 got 50" — opaque.
        // Post-fix: "expected `{` got `(`" — actionable.
        let tok: Vec<i32> = tok_at(tokens, pos);
        let byte_pos: i64 = tok_pos(tok);
        let lc_pos: Vec<i32> = tokens_linecol_at_byte(tokens, byte_pos);
        let line_pos: i64 = vec_get(lc_pos, 0);
        let col_pos: i64 = vec_get(lc_pos, 1);
        let got_tt: i64 = pk(tokens, pos);
        let loc_pos: str = str_concat(str_from_int(line_pos), str_concat(":", str_from_int(col_pos)));
        panic(str_concat("error[NR020]: parse error at line ", str_concat(loc_pos, str_concat(" (byte ", str_concat(str_from_int(byte_pos), str_concat("): expected ", str_concat(tok_name(tt), str_concat(", got ", tok_name(got_tt))))))));
    };
    return pos + 1;
}

#[manual_drop]
fn parse_args(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut args: Vec<i32> = Vec::new();
    let mut cp: i64 = pos;
    if pk(tokens, cp) != 51 {
        // Lane 4 / F-037: leading comma `h(,1)` silent accept. Reject.
        if pk(tokens, cp) == 44 {
            let v_args_byte_f037l: i64 = tok_pos_at(tokens, cp);
            panic(str_concat("error[PARSE-ARGS-COMMA]: leading `,` in fn-call argument list at byte ", str_concat(str_from_int(v_args_byte_f037l), ". Remove the leading comma.")));
        };
        let mut r: Vec<i32> = parse_expr(tokens, cp, pool);
        args.push(pr_val(r)); cp = pr_pos(r);
        while pk(tokens, cp) == 44 {
            if pk(tokens, cp + 1) == 51 { cp = cp + 1; }
            else if pk(tokens, cp + 1) == 44 {
                // Lane 4 / F-037: extra comma `h(1,, 2)` silent accept.
                let v_args_byte: i64 = tok_pos_at(tokens, cp + 1);
                panic(str_concat("error[PARSE-ARGS-COMMA]: extra `,` in fn-call argument list at byte ", str_concat(str_from_int(v_args_byte), ". Remove the duplicate comma.")));
            }
            else {
                r = parse_expr(tokens, cp + 1, pool); args.push(pr_val(r)); cp = pr_pos(r);
            };
        };
    };
    return pr(cp + 1, mk_list(pool, args));
}

#[manual_drop]
fn skip_bracket_list(tokens: Vec<i32>, pos: i64) -> i64 {
    let mut cp: i64 = expect_tok(tokens, pos, 54);
    let mut depth: i64 = 1;
    while depth > 0 && pk(tokens, cp) != 0 {
        if pk(tokens, cp) == 54 { depth = depth + 1; }
        else if pk(tokens, cp) == 55 { depth = depth - 1; };
        cp = cp + 1;
    };
    return cp;
}

#[manual_drop]
fn skip_effect_clause(tokens: Vec<i32>, pos: i64) -> i64 {
    if pk(tokens, pos) == 1 && str_eq(pkv(tokens, pos), "with") == 1 {
        return skip_bracket_list(tokens, pos + 1);
    };
    return pos;
}

#[manual_drop]
fn skip_compile_time_param_default(tokens: Vec<i32>, pos: i64) -> i64 {
    let mut cp: i64 = pos;
    let mut paren_depth: i64 = 0;
    let mut bracket_depth: i64 = 0;
    let mut angle_depth: i64 = 0;
    while pk(tokens, cp) != 0 {
        let tt: i64 = pk(tokens, cp);
        if paren_depth == 0 {
            if bracket_depth == 0 {
                if angle_depth == 0 {
                    if tt == 44 || tt == 55 { return cp; };
                };
            };
        };
        if tt == 50 { paren_depth = paren_depth + 1; }
        else if tt == 51 {
            if paren_depth > 0 { paren_depth = paren_depth - 1; };
        } else if tt == 54 {
            bracket_depth = bracket_depth + 1;
        } else if tt == 55 {
            if bracket_depth == 0 { return cp; };
            bracket_depth = bracket_depth - 1;
        } else if tt == 32 {
            angle_depth = angle_depth + 1;
        } else if tt == 33 {
            if angle_depth > 0 { angle_depth = angle_depth - 1; };
        };
        cp = cp + 1;
    };
    return cp;
}

#[manual_drop]
fn ct_param_type_is_unsigned(t: str) -> i64 {
    if str_eq(t, "u8") == 1 { return 1; };
    if str_eq(t, "u16") == 1 { return 1; };
    if str_eq(t, "u32") == 1 { return 1; };
    if str_eq(t, "u64") == 1 { return 1; };
    if str_eq(t, "usize") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn ct_param_default_is_negative_literal(tokens: Vec<i32>, pos: i64) -> i64 {
    if pk(tokens, pos) == 21 && pk(tokens, pos + 1) == 2 { return 1; };
    return 0;
}

#[manual_drop]
fn skip_compile_time_params(tokens: Vec<i32>, pos: i64) -> i64 {
    // RFC-0034 first-pass parser substrate. Accepts
    // `fn name<T>[N: usize, TILE: usize = 16](...)` and erases the
    // value-level compile-time params for now; semantic environments and
    // call-site specialization land in the full RFC-0034 implementation.
    if pk(tokens, pos) != 54 { return pos; };
    let mut cp: i64 = pos + 1;
    let mut seen: i64 = 0;
    while pk(tokens, cp) != 55 && pk(tokens, cp) != 0 {
        if seen > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 55 { break; };
        };
        if pk(tokens, cp) != 1 {
            panic("error[NR020]: expected compile-time parameter name in RFC-0034 `[]` parameter list");
        };
        cp = cp + 1;
        cp = expect_tok(tokens, cp, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp);
        let ct_ty: str = pr_val(tr);
        cp = pr_pos(tr);
        if pk(tokens, cp) == 40 {
            if ct_param_type_is_unsigned(ct_ty) == 1 && ct_param_default_is_negative_literal(tokens, cp + 1) == 1 {
                panic(str_concat("error[NR020]: negative default literal is invalid for unsigned RFC-0034 compile-time parameter type `", str_concat(ct_ty, "`. Use a non-negative default or change the parameter type to a signed integer.")));
            };
            cp = skip_compile_time_param_default(tokens, cp + 1);
        };
        seen = 1;
    };
    cp = expect_tok(tokens, cp, 55);
    return cp;
}

#[manual_drop]
fn skip_angle_group(tokens: Vec<i32>, pos: i64) -> i64 {
    if pk(tokens, pos) != 32 { return pos; };
    let mut cp: i64 = pos + 1;
    let mut depth: i64 = 1;
    while depth > 0 && pk(tokens, cp) != 0 {
        let tt: i64 = pk(tokens, cp);
        if depth == 1 {
            if tt == 2 || tt == 3 || tt == 40 || tt == 41 || tt == 43 || tt == 52 || tt == 53 || tt == 54 || tt == 55 || tt == 64 { return pos; };
            if tt == 30 || tt == 31 || tt == 34 || tt == 35 || tt == 36 || tt == 37 || tt == 38 || tt == 39 { return pos; };
        };
        if tt == 32 { depth = depth + 1; }
        else if tt == 33 { depth = depth - 1; };
        cp = cp + 1;
    };
    if depth != 0 { return pos; };
    if pk(tokens, cp) == 50 || pk(tokens, cp) == 52 || pk(tokens, cp) == 46 { return cp; };
    return pos;
}

// balanced <...> skipper for impl/struct/etc. generic-
// param lists where the trailing context isn't a type-position token.
// Returns the position past the closing `>`, or `pos` unchanged if no
// balanced group at this position.
#[manual_drop]
fn skip_balanced_angle(tokens: Vec<i32>, pos: i64) -> i64 {
    if pk(tokens, pos) != 32 { return pos; };
    let mut cp: i64 = pos + 1;
    let mut depth: i64 = 1;
    while depth > 0 && pk(tokens, cp) != 0 {
        let tt: i64 = pk(tokens, cp);
        if tt == 32 { depth = depth + 1; }
        else if tt == 33 { depth = depth - 1; };
        cp = cp + 1;
    };
    if depth != 0 { return pos; };
    return cp;
}

#[manual_drop]
fn skip_where_clause(tokens: Vec<i32>, pos: i64) -> i64 {
    let mut cp: i64 = pos;
    if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "where") == 1 {
        cp = cp + 1;
        while pk(tokens, cp) != 52 && pk(tokens, cp) != 43 && pk(tokens, cp) != 0 {
            cp = cp + 1;
        };
    };
    return cp;
}

#[manual_drop]
fn halt_hrtb_not_supported() -> i64 {
    print("ERROR: higher-ranked trait bounds `for<'a> ...` are not yet supported in Nucleor. Workaround: replace the HRTB with a concrete fn-pointer type or a non-higher-ranked generic bound.");
    panic("nucleor: higher-ranked trait bounds `for<'a>` not yet supported (see ERROR diagnostic above)");
    return 0;
}

// Track Y (v0.5.31) closes the inline `<T: Trait>` form by capturing
// `?Trait` markers in the gparams list at parse time. The where-clause
// form `where T: Trait` was being silently skipped via `skip_where_clause`,
// so `lower_fn`'s gparam-bound walk never saw the bound and `lower_expr`
// kind-8 method dispatch fell through to the `vec_<method>` synthesis
// path (clang-link `error[TYP-005]: undefined fn vec_<method>`).
// This helper mirrors the inline-form bound capture: walk `where T: A + B,
// U: C` and splice `?A` / `?B` into gparams immediately after T's entry,
// `?C` after U's. Lifetime entries (prefixed `'`) are preserved. Bounds on
// names that don't appear in gparams are silently dropped (no-op — caller
// param list is the authoritative shape).
#[manual_drop]
fn parse_where_clause_into_gparams(tokens: Vec<i32>, pos: i64, gparams: Vec<i32>) -> i64 {
    let mut cp: i64 = pos;
    if pk(tokens, cp) != 1 { return cp; };
    if str_eq(pkv(tokens, cp), "where") == 0 { return cp; };
    cp = cp + 1; // past 'where'
    while pk(tokens, cp) != 52 && pk(tokens, cp) != 43 && pk(tokens, cp) != 0 {
        // Param name at the head of this clause (e.g. `T` in `T: Show`).
        if pk(tokens, cp) != 1 {
            cp = cp + 1;
            continue;
        };
        let pname: str = pkv(tokens, cp);
        cp = cp + 1;
        if pk(tokens, cp) != 42 { // ':'
            // Unexpected shape; don't consume more, fall back to skip-mode.
            continue;
        };
        cp = cp + 1; // past ':'
        let mut lhs_known: i64 = 0;
        let lhs_gc: i64 = vec_len(gparams);
        let mut lhs_gi: i64 = 0;
        while lhs_gi < lhs_gc {
            let lhs_entry: str = vec_get(gparams, lhs_gi);
            if str_len(lhs_entry) > 0 && str_char_at(lhs_entry, 0) != 63
               && str_char_at(lhs_entry, 0) != 39
               && str_eq(lhs_entry, pname) == 1 {
                lhs_known = 1;
                lhs_gi = lhs_gc;
            } else {
                lhs_gi = lhs_gi + 1;
            };
        };
        if lhs_known == 0 {
            print(str_concat("error[TYP-008]: where-clause references unknown type parameter `", str_concat(pname, "`. The left-hand side of `where X: Trait` must name a type parameter declared by this item.")));
            diag_exit();
            panic(str_concat("nucleor: unknown where-clause type parameter `", str_concat(pname, "`")));
        };
        // Bounds list: walk identifiers until comma / { / ;.
        // Multi-bound (`T: A + B`) handled by the inner ident loop —
        // every kw-class ident is treated as a bound name. Operator
        // tokens (`+`, etc.) are skipped via the non-ident branch.
        while pk(tokens, cp) != 44 && pk(tokens, cp) != 52 && pk(tokens, cp) != 43 && pk(tokens, cp) != 0 {
            if pk(tokens, cp) == 56 {
                halt_hrtb_not_supported();
            };
            if pk(tokens, cp) == 1 {
                let bname: str = pkv(tokens, cp);
                if str_len(bname) > 0 {
                    // Splice `?bname` into gparams right after pname's
                    // existing position, after any `?Bound` entries
                    // already attached to pname (so multi-bound order
                    // is preserved).
                    let n_g: i64 = vec_len(gparams);
                    let mut gi: i64 = 0;
                    while gi < n_g {
                        let entry_g: str = vec_get(gparams, gi);
                        if str_eq(entry_g, pname) == 1 {
                            let mut splice_pos: i64 = gi + 1;
                            while splice_pos < vec_len(gparams) {
                                let cur_e: str = vec_get(gparams, splice_pos);
                                if str_len(cur_e) > 0 && str_char_at(cur_e, 0) == 63 {
                                    splice_pos = splice_pos + 1;
                                } else {
                                    gi = n_g; // outer break
                                    break;
                                };
                            };
                            vec_insert_at(gparams, splice_pos, str_concat("?", bname));
                            gi = n_g; // outer break
                        };
                        gi = gi + 1;
                    };
                };
            };
            cp = cp + 1;
        };
        if pk(tokens, cp) == 44 { cp = cp + 1; }; // past comma to next clause
    };
    return cp;
}

#[manual_drop]
fn parse_match_binding_block(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    let mut cp: i64 = pos;
    let mut binding: str = "";
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if str_len(binding) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
            binding = str_concat(binding, "|");
        };
        let mut name: str = pkv(tokens, cp);
        cp = cp + 1;
        if pk(tokens, cp) == 42 {
            cp = cp + 1;
            name = pkv(tokens, cp);
            cp = cp + 1;
        };
        binding = str_concat(binding, name);
    };
    cp = expect_tok(tokens, cp, 53);
    return pr(cp, binding);
}

#[manual_drop]
fn str_find_char_local(s: str, ch: i64) -> i64 {
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(s, i) == ch { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn str_before_char_local(s: str, ch: i64) -> str {
    let p: i64 = str_find_char_local(s, ch);
    if p < 0 { return s; };
    return str_substring(s, 0, p);
}

#[manual_drop]
fn str_after_char_local(s: str, ch: i64) -> str {
    let p: i64 = str_find_char_local(s, ch);
    if p < 0 { return ""; };
    return str_substring(s, p + 1, str_len(s));
}

#[manual_drop]
fn pattern_append_binding(binding: str, piece: str) -> str {
    if str_len(piece) == 0 { return binding; };
    if str_len(binding) == 0 { return piece; };
    return str_concat(binding, str_concat("|", piece));
}

#[manual_drop]
fn pattern_prepend_at_binding(binding: str, at_name: str) -> str {
    if str_len(at_name) == 0 { return binding; };
    let head: str = str_concat("@", at_name);
    if str_len(binding) == 0 { return head; };
    return str_concat(head, str_concat("|", binding));
}

#[manual_drop]
fn pattern_binding_item_name(item: str) -> str {
    if str_len(item) == 0 { return ""; };
    if str_eq(item, "_") == 1 || str_eq(item, "..") == 1 { return ""; };
    let mut s: str = item;
    if str_char_at(s, 0) == 64 { s = str_substring(s, 1, str_len(s)); };
    let colon: i64 = str_find_char_local(s, 58);
    if colon >= 0 { s = str_substring(s, colon + 1, str_len(s)); };
    if str_eq(s, "_") == 1 || str_eq(s, "..") == 1 { return ""; };
    return s;
}

#[manual_drop]
fn pattern_binding_key_from_list(binding: str) -> str {
    let blen: i64 = str_len(binding);
    let mut key: str = "";
    let mut start: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(binding, end) != 124 { end = end + 1; };
        let item: str = str_substring(binding, start, end);
        let name: str = pattern_binding_item_name(item);
        key = pattern_append_binding(key, name);
        start = end + 1;
    };
    return key;
}

#[manual_drop]
fn pattern_binding_key(ename: str, binding: str) -> str {
    if str_eq(ename, "__range") == 1 || str_eq(ename, "__range_bad") == 1 { return ""; };
    if str_eq(ename, "__range_at") == 1 || str_eq(ename, "__range_bad_at") == 1 {
        return pattern_binding_key_from_list(str_after_char_local(binding, 124));
    };
    return pattern_binding_key_from_list(binding);
}

#[manual_drop]
fn parse_match_struct_binding_block(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    let mut cp: i64 = pos;
    let mut binding: str = "";
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if str_len(binding) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
        };
        let fname: str = pkv(tokens, cp);
        let mut bname: str = fname;
        cp = cp + 1;
        if pk(tokens, cp) == 42 {
            cp = cp + 1;
            // v0.4.163 MATCH-012 — pre-fix `Point { x: 0, y: 0 } => ...` fed the
            // raw int-literal value into pkv (which returns i64) and bound it as
            // a str to `bname`, producing garbage that crashed codegen with an
            // ACCESS VIOLATION. Now: require an identifier after `:` and emit a
            // clean diagnostic if anything else appears. Field-equality literal
            // patterns (`{ field: <literal> }`) are deferred to v0.5+.
            if pk(tokens, cp) != 1 {
                // fold the dual print+panic into a single
                // panic() carrying the full diag text. Matches the
                // MATCH-013 pattern (line ~1040). Probe finding
                // 2026-04-30: pre-fix adopters saw "error[MATCH-012]:
                // ..." followed by a duplicate "PANIC: nucleor:
                // MATCH-012..." line. Single panic eliminates the
                // stutter; the leading "PANIC: " prefix from the
                // runtime helper remains (removing that requires
                // adding a `diag_halt` runtime helper that exits
                // without the prefix — deferred follow-up).
                panic("error[MATCH-012]: struct pattern field after `:` must be an identifier (rename-binding form, e.g. `Point { x: rename }`). Field-equality literal patterns like `Point { x: 0, y: 0 }` are not yet supported — match the field with a binding (`Point { x, y }`) and use a guard `if x == 0 && y == 0 => ...` instead.");
            };
            bname = pkv(tokens, cp);
            cp = cp + 1;
            //  canonical Rust
            // nested struct pattern `Outer { inner: Inner { ... }, ...
            // } => ...` pre-fix saw `{` (token 52) right after the
            // bname identifier (`Inner`) and panicked NR020 with
            // "expected ',' or '}', got '{'". Halt at the inner-`{`
            // detection with a clean diag pointing at the workaround
            // (single-level destructure + dotted field access in the
            // arm body).
            if pk(tokens, cp) == 52 {
                print(str_concat("ERROR: nested struct patterns in `match` arms (e.g. `Outer { inner: Inner { ... }, ... } => ...`) are not yet supported in Nucleor. Workaround: bind the inner struct to a name and access its fields in the arm body — `match l { Outer { inner, ... } => { let x = inner.field_x; let y = inner.field_y; ... } }`."));
                panic("nucleor: nested struct pattern not yet supported (see ERROR diagnostic above)");
            };
        };
        binding = pattern_append_binding(binding, str_concat(fname, str_concat(":", bname)));
    };
    cp = expect_tok(tokens, cp, 53);
    return pr(cp, binding);
}

#[manual_drop]
fn parse_match_list_binding(tokens: Vec<i32>, pos: i64, end_tok: i64, allow_rest: i64) -> Vec<i32> {
    let mut cp: i64 = pos;
    let mut binding: str = "";
    let mut saw_rest: i64 = 0;
    while pk(tokens, cp) != end_tok && pk(tokens, cp) != 0 {
        if str_len(binding) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == end_tok { break; };
        };
        let mut piece: str = "";
        if allow_rest == 1 && pk(tokens, cp) == 58 {
            if saw_rest == 1 {
                print("error[MATCH-009]: slice pattern contains more than one `..` rest marker");
                panic("nucleor: MATCH-009 slice pattern overlap");
            };
            piece = "..";
            saw_rest = 1;
            cp = cp + 1;
        } else if pk(tokens, cp) == 1 {
            piece = pkv(tokens, cp);
            cp = cp + 1;
        } else {
            print("error[MATCH-009]: only identifier, `_`, and `..` elements are supported in tuple/slice patterns");
            panic("nucleor: unsupported tuple/slice pattern element");
        };
        binding = pattern_append_binding(binding, piece);
    };
    cp = expect_tok(tokens, cp, end_tok);
    return pr(cp, binding);
}

#[manual_drop]
fn parse_match_one_pattern(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut cp: i64 = pos;
    let mut at_name: str = "";
    // v0.7.35 (defensive halt — Rust top-level `ref` / `ref mut` binding
    // mode in a match arm pattern: `match x { ref n => ... }`,
    // `match x { ref mut n => ... }`). Pre-fix this surfaced as wrong-
    // class `error[NR020]: expected '=>', got identifier` because the
    // pattern parser swallowed `ref` as the wildcard binding name then
    // saw the actual binding `n` where `=>` was expected. Sister to
    // v0.7.23 (`ref` inside a variant pattern). Workaround: drop `ref` —
    // Nucleor's i64-everywhere ABI already passes by value.
    if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "ref") == 1 && pk(tokens, cp + 1) == 1 {
        let mut ref_form_v735: str = "ref";
        let mut name_idx: i64 = cp + 1;
        if str_eq(pkv(tokens, cp + 1), "mut") == 1 && pk(tokens, cp + 2) == 1 {
            ref_form_v735 = "ref mut";
            name_idx = cp + 2;
        };
        let real_v735: str = pkv(tokens, name_idx);
        print(str_concat("ERROR: top-level `", str_concat(ref_form_v735, str_concat("` binding mode in a `match` arm pattern (e.g. `match x { ", str_concat(ref_form_v735, str_concat(" ", str_concat(real_v735, " => ... }`)) is not yet supported in Nucleor. Sister to v0.7.23 (`ref` inside variant pattern).")))))));
        print(str_concat("       Workaround: drop the `", str_concat(ref_form_v735, str_concat("` keyword — Nucleor's i64-everywhere ABI passes everything by value already, so `match x { ", str_concat(real_v735, " => ... }` has the same observable shape.")))));
        panic(str_concat("nucleor: top-level `", str_concat(ref_form_v735, "` binding mode in match arm not yet supported (see ERROR diagnostic above)")));
    };
    if pk(tokens, cp) == 1 && pk(tokens, cp + 1) == 122 {
        at_name = pkv(tokens, cp);
        cp = cp + 2;
    };
    let att: i64 = pk(tokens, cp);
    // reject float-literal patterns at parse time.
    // Pre-fix `match <f64> { 1.5 => ..., _ => ... }` (or any
    // float-lit pattern) crashed the compiler with ACCESS_VIOLATION
    // (Windows -1073741819 / SIGSEGV) — the parser fell through to
    // the wildcard branch (line 1034) which assigned `binding`
    // to `pkv(...)` of the float-lit token (an i64 bit pattern,
    // not a str ptr); a downstream str op then dereferenced the
    // i64 as a heap address. Float equality patterns are fragile
    // (NaN ≠ NaN; round-off drift) so this is the right intentional
    // rejection — Rust forbids float patterns since 1.0.
    // Catches at parse time so the rejection fires regardless of
    // scrutinee type (`match 1.5 { 1.5 => ... }` and `match x { 1.5
    // => ... }` both halt cleanly).
    // Tokens: 70 = f-suffix-typed lit, 124 = f64 raw-bits lit,
    // 125 = f32 lit. All three trigger the same hazard.
    if att == 70 || att == 124 || att == 125 {
        panic("error[MATCH-013]: float-literal pattern in `match` arm is not supported. Float equality is fragile (NaN ≠ NaN; round-off drift means literal-equality matches surprise-fail), so pattern-matching on `f32`/`f64` values has no defined semantics here. Use an `if`-chain (`if (x - 1.5).abs() < 0.001 { ... }`) for tolerance-based comparison, or convert via `(x * 100.0) as i32` to match on integer scaled values.");
    };
    let mut ename: str = "";
    let mut vname: str = "";
    let mut binding: str = "";
    if att == 21 && pk(tokens, cp + 1) == 2 && (pk(tokens, cp + 2) == 96 || pk(tokens, cp + 2) == 58) {
        panic("error[MATCH-014]: negative literal bounds in range patterns are not supported yet. Pattern forms like `-10..=-1` still parse as a unary-minus token followed by a literal, so the range-pattern parser cannot lower them safely. Use a guard instead, e.g. `_ if value >= -10 && value <= -1 => ...`, or shift the domain to non-negative bounds before matching.");
    } else if att == 21 && pk(tokens, cp + 1) == 2 {
        // v0.7.22 (defensive halt — bare negative-literal pattern in
        // match arm: `match x { -5 => ..., _ => ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: expected '=>', got
        // integer literal` because the pattern parser had no `-` (token
        // 21) entry — the `-` was consumed as a no-op, then `5` was
        // read as the standalone int-lit pattern, leaving the trailing
        // `=>` to land where the parser expected an expression
        // continuation. Halt cleanly with a guard workaround.
        panic("error[MATCH-015]: negative-literal patterns in match arms (e.g. `match x { -5 => ..., _ => ... }`) are not yet supported. Workaround: use a guard — `match x { n if n == -5 => { ... } _ => { ... } }` — the guard form supports negative literals natively.");
    } else if att == 2 {
        let lo_val: i64 = pkv(tokens, cp);
        cp = cp + 1;
        let next_tok: i64 = pk(tokens, cp);
        if next_tok == 96 || next_tok == 58 {
            let inclusive: i64 = if next_tok == 96 { 1 } else { 0 };
            cp = cp + 1;
            if pk(tokens, cp) == 2 {
                let hi_raw: i64 = pkv(tokens, cp);
                cp = cp + 1;
                let hi_norm: i64 = if inclusive == 1 { hi_raw } else { hi_raw - 1 };
                if lo_val <= hi_norm { ename = "__range"; } else { ename = "__range_bad"; };
                vname = lo_val;
                binding = str_from_int(hi_norm);
            } else if pk(tokens, cp) == 21 && pk(tokens, cp + 1) == 2 {
                panic("error[MATCH-014]: negative literal bounds in range patterns are not supported yet. Pattern forms like `0..=-1` still parse the upper bound as a unary-minus token followed by a literal, so the range-pattern parser cannot lower them safely. Use a guard instead, e.g. `_ if value >= 0 && value <= -1 => ...`, or shift the domain to non-negative bounds before matching.");
            } else {
                ename = "__int";
                vname = lo_val;
            };
        } else {
            ename = "__int";
            vname = lo_val;
        };
    } else if att == 3 {
        ename = "__str";
        vname = pkv(tokens, cp);
        cp = cp + 1;
    } else if att == 1 && str_eq(pkv(tokens, cp), "_") == 1 {
        ename = "__wild";
        cp = cp + 1;
    } else if att == 1 && pk(tokens, cp + 1) == 46 {
        ename = pkv(tokens, cp);
        cp = expect_tok(tokens, cp + 1, 46);
        vname = pkv(tokens, cp); cp = cp + 1;
        if pk(tokens, cp) == 50 {
            cp = cp + 1;
            let mut first: i64 = 1;
            while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
                if first == 0 { cp = expect_tok(tokens, cp, 44); };
                let bn: str = pkv(tokens, cp); cp = cp + 1;
                binding = pattern_append_binding(binding, bn);
                first = 0;
            };
            cp = expect_tok(tokens, cp, 51);
        } else if pk(tokens, cp) == 52 {
            let mut br: Vec<i32> = parse_match_binding_block(tokens, cp + 1);
            binding = pr_val(br);
            cp = pr_pos(br);
        };
    } else if att == 1 && pk(tokens, cp + 1) == 45 {
        ename = pkv(tokens, cp);
        cp = cp + 2;
        vname = pkv(tokens, cp); cp = cp + 1;
        if pk(tokens, cp) == 50 {
            cp = cp + 1;
            binding = pkv(tokens, cp); cp = cp + 1;
            cp = expect_tok(tokens, cp, 51);
        } else if pk(tokens, cp) == 52 {
            let mut br: Vec<i32> = parse_match_binding_block(tokens, cp + 1);
            binding = pr_val(br);
            cp = pr_pos(br);
        };
    } else if att == 1 && pk(tokens, cp + 1) == 52
        && str_eq(pkv(tokens, cp), "Some") == 0
        && str_eq(pkv(tokens, cp), "None") == 0
        && str_eq(pkv(tokens, cp), "Ok") == 0
        && str_eq(pkv(tokens, cp), "Err") == 0 {
        ename = "__struct";
        vname = pkv(tokens, cp);
        let mut br: Vec<i32> = parse_match_struct_binding_block(tokens, cp + 2);
        binding = pr_val(br);
        cp = pr_pos(br);
    } else if att == 50 {
        ename = "__tuple";
        let mut br: Vec<i32> = parse_match_list_binding(tokens, cp + 1, 51, 0);
        binding = pr_val(br);
        vname = str_from_int(pattern_list_value_count(binding));
        cp = pr_pos(br);
    } else if att == 54 {
        ename = "__slice";
        let mut br: Vec<i32> = parse_match_list_binding(tokens, cp + 1, 55, 1);
        binding = pr_val(br);
        vname = "slice";
        cp = pr_pos(br);
    } else if att == 1 && (str_eq(pkv(tokens, cp), "Some") == 1 || str_eq(pkv(tokens, cp), "None") == 1 || str_eq(pkv(tokens, cp), "Ok") == 1 || str_eq(pkv(tokens, cp), "Err") == 1) {
        vname = pkv(tokens, cp);
        if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
        else { ename = "Option"; };
        cp = cp + 1;
        if pk(tokens, cp) == 50 {
            cp = cp + 1;
            // v0.7.54 (defensive halt — paren-wrapped payload inside a
            // variant pattern: `Some((1))`, `Ok((x, y))`). Pre-fix this
            // surfaced as wrong-class `error[NR020]: expected ')', got
            // integer literal` because the parser fell through to
            // pkv-on-`(` (garbage binding), advanced past the inner `(`,
            // then tried to expect `)` at the inner-payload position.
            // Halt cleanly with a drop-the-extra-parens workaround.
            if pk(tokens, cp) == 50 {
                print(str_concat("ERROR: paren-wrapped payload inside a variant pattern (e.g. `", str_concat(vname, "((expr))`, `Ok((x, y))`) is not yet supported in Nucleor. Pre-v0.7.54 this surfaced as wrong-class `error[NR020]: expected ')', got integer literal` (or similar) because the parser captured the inner `(` as a binding-name fragment.")));
                print(str_concat("       Workaround: drop the extra parens — `", str_concat(vname, "(x)` is the canonical shape. Anonymous-tuple payloads (e.g. `", str_concat(vname, "((x, y))` for `Some<(i64, i64)>`) need the recursive pattern parser; bind a single name and access fields by index in the body — `", str_concat(vname, "(t) => { let a = t.0; let b = t.1; ... }`.")))));
                panic(str_concat("nucleor: paren-wrapped payload inside `", str_concat(vname, "(...)` not yet supported (see ERROR diagnostic above)")));
            };
            // v0.7.24 (defensive halt — bare negative-literal payload inside
            // a variant pattern: `Some(-5)`, `Ok(-1)`, `Err(-9)`). Pre-fix
            // this surfaced as wrong-class `error[NR020]: expected ')', got
            // integer literal` because the variant-pattern parser swallowed
            // `-` (token 21) as the binding name, then `5` landed where the
            // parser expected `)`. Sister to v0.7.22 MATCH-015 (bare negative
            // literal at outer pattern level). Workaround: use a guard.
            if pk(tokens, cp) == 21 && pk(tokens, cp + 1) == 2 {
                let neg_lit: i64 = pkv(tokens, cp + 1);
                print(str_concat("ERROR: bare negative-literal payload inside a variant pattern (e.g. `", str_concat(vname, str_concat("(-", str_concat(str_from_int(neg_lit), ")`) is not yet supported in Nucleor. Sister to v0.7.22 MATCH-015 (bare negative literal at outer pattern level).")))));
                print(str_concat("       Workaround: use a guard — `match opt { ", str_concat(vname, str_concat("(n) if n == -", str_concat(str_from_int(neg_lit), " => { ... } _ => { ... } }`.")))));
                panic(str_concat("nucleor: bare negative-literal payload inside `", str_concat(vname, "(...)` not yet supported (see ERROR diagnostic above)")));
            };
            // v0.7.51 (CRITICAL — bare integer-literal payload inside a
            // variant pattern: `Some(1)`, `Ok(0)`, `Err(42)`). Pre-fix
            // this SEGFAULTED the compiler at IR-emit time because the
            // variant-pattern parser captured the int literal's i64
            // value as the binding-name string, then downstream codegen
            // tried to emit a variable named "1" — invalid LLVM ident
            // → SIGSEGV (rc 139, no diagnostic). Sister to v0.7.22 /
            // v0.7.24 (negative-literal halts) but for the segfault
            // class. Halt cleanly with a guard workaround.
            if pk(tokens, cp) == 2 {
                let int_lit_v751: i64 = pkv(tokens, cp);
                print(str_concat("ERROR: bare integer-literal payload inside a variant pattern (e.g. `", str_concat(vname, str_concat("(", str_concat(str_from_int(int_lit_v751), ")`) is not yet supported in Nucleor. Sister to v0.7.22/v0.7.24 (negative-literal halts).")))));
                print(str_concat("       Workaround: use a guard — `match opt { ", str_concat(vname, str_concat("(n) if n == ", str_concat(str_from_int(int_lit_v751), " => { ... } _ => { ... } }`.")))));
                panic(str_concat("nucleor: bare integer-literal payload inside `", str_concat(vname, "(...)` not yet supported (see ERROR diagnostic above)")));
            };
            // v0.7.53 (CRITICAL — bare float-literal payload inside a
            // variant pattern: `Some(1.5)`, `Ok(2.0)`, etc.). Same
            // SEGFAULT class as v0.7.51 (int) — different lexer tokens.
            // Token 70 = f-suffix-typed lit, 124 = f64 raw-bits, 125 = f32.
            // Pre-fix this also crashed the compiler at IR-emit (rc=139,
            // no diagnostic). Sister to v0.7.51 (int-lit) and the
            // pre-existing v0.4.206 outer-level float-literal halt
            // (MATCH-013) which only fires at the outer match scrutinee
            // pattern level. Add a tailored MATCH-013-style message
            // pointing at float-equality fragility and offering a guard
            // workaround.
            if pk(tokens, cp) == 70 || pk(tokens, cp) == 124 || pk(tokens, cp) == 125 {
                print(str_concat("error[MATCH-013]: float-literal payload inside a variant pattern (e.g. `", str_concat(vname, "(1.5)`) is not supported. Float equality is fragile (NaN ≠ NaN; round-off drift means literal-equality matches surprise-fail), so pattern-matching on `f32`/`f64` payloads has no defined semantics in Nucleor. Sister to v0.4.206 outer-level float-pattern halt and v0.7.51 int-payload halt.")));
                print(str_concat("       Workaround: use a guard with tolerance-based comparison — `match opt { ", str_concat(vname, "(x) if (x - 1.5).abs() < 0.001 => { ... } _ => { ... } }`. Or convert via integer scale (`match (x * 100.0) as i64 { 150 => ..., _ => ... }`).")));
                panic(str_concat("nucleor: float-literal payload inside `", str_concat(vname, "(...)` is not supported (see ERROR diagnostic above)")));
            };
            if pk(tokens, cp) != 51 {
                binding = pkv(tokens, cp);
                cp = cp + 1;
                // v0.6.90 (defensive halt — canonical Rust nested
                // pattern `Some(Some(v))` / `Ok(Some(v))` / etc.):
                // pre-fix the inner `(` after the binding name surfaced
                // as the wrong-class `error[NR020]: expected ')', got
                // '('` because the pattern parser treats the binding
                // slot as a single ident and then expects `)`. Halt
                // cleanly with a 2-step destructure workaround pointer.
                // Forward-roadmap: recursive pattern parser (sister to
                // nested struct patterns at line 1364).
                if pk(tokens, cp) == 50 {
                    print(str_concat("ERROR: nested patterns in `if let` / `match` arms (e.g. `", str_concat(vname, str_concat("(Some(v))`, `", str_concat(vname, "(Ok(...))`) are not yet supported in Nucleor. Workaround: destructure in two steps — `if let ")))));
                    print(str_concat("       ", str_concat(vname, "(inner) = outer { if let Some(v) = inner { ... } }`.")));
                    panic(str_concat("nucleor: nested ctor pattern `", str_concat(vname, "(Some(...))` not yet supported (see ERROR diagnostic above)")));
                };
                // v0.7.19 (defensive halt — Rust `@` binding inside a
                // variant pattern: `Some(n @ 1..=10)`, `Ok(s @ "a")`,
                // etc.). Pre-fix this surfaced as wrong-class `error
                // [NR020]: expected ')', got token 122` (token 122 = `@`).
                // Workaround: hoist the `@` to the top-level pattern
                // (`n @ Some(_)`) or split the guard
                // (`Some(n) if (1..=10).contains(&n)`).
                if pk(tokens, cp) == 122 {
                    print(str_concat("ERROR: `@` binding inside a variant pattern (e.g. `", str_concat(vname, "(n @ 1..=10)`) is not yet supported in Nucleor. Pre-v0.7.19 this surfaced as wrong-class `error[NR020]: expected ')', got token 122`.")));
                    print(str_concat("       Workaround: hoist the `@` to the outer pattern — `n @ ", str_concat(vname, "(_) => ...` (binds the whole variant) — or split the test into a guard: `", str_concat(vname, "(n) if (1..=10).contains(&n) => ...`.")));
                    panic(str_concat("nucleor: `@` binding inside `", str_concat(vname, "(...)` not yet supported (see ERROR diagnostic above)")));
                };
                // v0.7.23 (defensive halt — Rust `ref` / `ref mut` binding
                // mode inside a variant pattern: `Some(ref v)`, `Ok(ref mut
                // s)`, etc.). The pre-Q binding-name capture above swallowed
                // `ref` as if it were the binding identifier; the next
                // token (the actual binding name) then landed where the
                // parser expected `)`, surfacing as wrong-class `error
                // [NR020]: expected ')', got identifier`. Workaround:
                // Nucleor's i64-everywhere ABI passes everything by value
                // already, so `ref` is a no-op semantically — just drop it.
                if str_eq(binding, "ref") == 1 && pk(tokens, cp) == 1 {
                    let mut ref_form: str = "ref";
                    let mut next_cp: i64 = cp;
                    if str_eq(pkv(tokens, cp), "mut") == 1 && pk(tokens, cp + 1) == 1 {
                        ref_form = "ref mut";
                        next_cp = cp + 1;
                    };
                    let real_binding: str = pkv(tokens, next_cp);
                    print(str_concat("ERROR: `", str_concat(ref_form, str_concat("` binding mode inside a variant pattern (e.g. `", str_concat(vname, str_concat("(", str_concat(ref_form, str_concat(" ", str_concat(real_binding, ")`) is not yet supported in Nucleor. Pre-v0.7.23 this surfaced as wrong-class `error[NR020]: expected ')', got identifier` because the pattern parser swallowed `ref` as the binding name.")))))))))));
                    print(str_concat("       Workaround: drop the `", str_concat(ref_form, str_concat("` keyword — Nucleor's i64-everywhere ABI passes everything by value already, so `", str_concat(vname, str_concat("(", str_concat(real_binding, ") => ...` has the same observable behavior.")))))));
                    panic(str_concat("nucleor: `", str_concat(ref_form, str_concat("` binding mode inside `", str_concat(vname, "(...)` not yet supported (see ERROR diagnostic above)")))));
                };
            };
            cp = expect_tok(tokens, cp, 51);
        } else if pk(tokens, cp) == 52 {
            let mut br: Vec<i32> = parse_match_binding_block(tokens, cp + 1);
            binding = pr_val(br);
            cp = pr_pos(br);
        };
    } else {
        // v0.7.45 (defensive halt — tuple-struct pattern in match arm:
        // `match p { P(a, b) => ... }`). Pre-fix this surfaced as wrong-
        // class `error[NR020]: expected '=>', got '('` because the
        // wildcard fallback at the end of pattern dispatch consumed `P`
        // as a binding name and left `(` for the arrow expector. Detect
        // identifier-followed-by-`(` here and halt cleanly with a
        // field-access workaround pointer (V1.1 tuple-struct decl
        // shipped v0.6.74; ctor + positional access works, only the
        // pattern-position destructure is missing).
        if att == 1 && pk(tokens, cp + 1) == 50 {
            let v745_name: str = pkv(tokens, cp);
            print(str_concat("ERROR: tuple-struct pattern `", str_concat(v745_name, "(a, b, ...)` in a `match` arm is not yet supported in Nucleor. Pre-v0.7.45 surfaced as wrong-class `error[NR020]: expected '=>', got '('` because the pattern parser consumed the struct name as a wildcard binding.")));
            print(str_concat("       Workaround: bind a single name and access fields by index in the body — `match p { x => { let a = x.0; let b = x.1; ... } }`. Tuple-struct decl + ctor + positional access is V1.1 (v0.6.74); pattern-position destructure is forward-roadmap (sister to anonymous-tuple destructure, both need recursive pattern parser).")));
            panic(str_concat("nucleor: tuple-struct pattern `", str_concat(v745_name, "(...)` in match arm not yet supported (see ERROR diagnostic above)")));
        };
        ename = "__wild";
        binding = pkv(tokens, cp);
        cp = cp + 1;
    };
    if str_len(at_name) > 0 {
        if str_eq(ename, "__range") == 1 {
            ename = "__range_at";
            binding = str_concat(binding, str_concat("|@", at_name));
        } else if str_eq(ename, "__range_bad") == 1 {
            ename = "__range_bad_at";
            binding = str_concat(binding, str_concat("|@", at_name));
        } else if str_eq(ename, "__int") == 1 || str_eq(ename, "__str") == 1 || str_eq(ename, "__wild") == 1 {
            binding = at_name;
        } else {
            binding = pattern_prepend_at_binding(binding, at_name);
        };
    };
    let mut out: Vec<i32> = Vec::new();
    out.push(cp); out.push(ename); out.push(vname); out.push(binding);
    return out;
}

#[manual_drop]
fn mk_passthrough_block_expr(pool: Vec<i32>, body: i64) -> i64 {
    return mk4(pool, 23, mk2(pool, 1, 1), body, 0 - 1);
}

#[manual_drop]
fn parse_passthrough_block_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut cp: i64 = expect_tok(tokens, pos, 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk_passthrough_block_expr(pool, pr_val(br)));
}

#[manual_drop]
fn parse_wrapped_block_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>, mode: i64) -> Vec<i32> {
    let mut cp: i64 = expect_tok(tokens, pos, 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk3(pool, 52, mode, pr_val(br)));
}

#[manual_drop]
fn parse_primary(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let tt: i64 = pk(tokens, pos);
    //  canonical Rust UFCS form
    // `<S as Foo>::f(&s)` (universal function call syntax — disambiguates
    // method dispatch when multiple traits implement the same fn name)
    // pre-fix saw `<` (token 32) at expression start and fell through
    // to the parse_primary tail with NR020 wrong-class. Halt at the
    // expression-start position with a clean diag pointing at the
    // workaround (call as a regular method or fully-qualified path).
    // Forward-roadmap: full UFCS dispatch is the v1 trait-dispatch ship.
    if tt == 32 {
        // v0.6.81 RFC V1.7 — UFCS dispatch `<Type as Trait>::method(args)`.
        // Pre-fix the `<` at expression start panicked with the v0.6.60
        // halt + workaround pointer. Now parse the canonical Rust UFCS
        // form and emit a regular kind-7 call to the type-mangled name
        // `<Type>__<method>` — Nucleor's trait-impl mangling already
        // produces this name regardless of which trait the impl came
        // through (the trait_impl_register path at ~line 25478). UFCS
        // therefore acts as a verbose surface-level alias that adopters
        // porting Rust code can paste in directly.
        // Note: when two traits provide the same method on the same
        // type, both impls register the SAME mangled name and Nucleor
        // emits the duplicate-fn-name diag at struct-emit time
        // (line ~7958, "ambiguous method") — the ambiguity is rejected
        // there, so UFCS-as-disambiguator is moot under today's
        // mangling. Per-trait mangling is the v1.x trait-dispatch
        // ship; until then UFCS is purely a translation-fidelity
        // surface. Fall through to the v0.6.60 halt for any shape we
        // can't recognise so adopter code with an unsupported UFCS
        // shape still gets a clean diag with workaround pointer.
        let mut ufcs_cp: i64 = pos + 1;
        let mut ufcs_ok: i64 = 0;
        let mut ufcs_type: str = "";
        let mut ufcs_method: str = "";
        let mut ufcs_args_pos: i64 = 0 - 1;
        if pk(tokens, ufcs_cp) == 1 {
            ufcs_type = pkv(tokens, ufcs_cp);
            ufcs_cp = ufcs_cp + 1;
            if pk(tokens, ufcs_cp) == 1 && str_eq(pkv(tokens, ufcs_cp), "as") == 1 {
                ufcs_cp = ufcs_cp + 1;
                if pk(tokens, ufcs_cp) == 1 {
                    ufcs_cp = ufcs_cp + 1; // skip trait name (advisory under today's mangling)
                    if pk(tokens, ufcs_cp) == 32 {
                        let mut ufcs_depth: i64 = 1;
                        ufcs_cp = ufcs_cp + 1;
                        while ufcs_cp < vec_len(tokens) && ufcs_depth > 0 {
                            let ufcs_tt2_v081: i64 = pk(tokens, ufcs_cp);
                            if ufcs_tt2_v081 == 32 { ufcs_depth = ufcs_depth + 1; }
                            else if ufcs_tt2_v081 == 33 { ufcs_depth = ufcs_depth - 1; };
                            if ufcs_tt2_v081 == 0 { ufcs_depth = 0; };
                            ufcs_cp = ufcs_cp + 1;
                        };
                    } else if pk(tokens, ufcs_cp) == 33 {
                        ufcs_cp = ufcs_cp + 1;
                    };
                    if pk(tokens, ufcs_cp) == 46 {
                        ufcs_cp = ufcs_cp + 1;
                        if pk(tokens, ufcs_cp) == 1 {
                            ufcs_method = pkv(tokens, ufcs_cp);
                            ufcs_cp = ufcs_cp + 1;
                            if pk(tokens, ufcs_cp) == 50 {
                                ufcs_args_pos = ufcs_cp + 1;
                                ufcs_ok = 1;
                            };
                        };
                    };
                };
            };
        };
        if ufcs_ok == 1 {
            let mut ufcs_ar: Vec<i32> = parse_args(tokens, ufcs_args_pos, pool);
            let ufcs_mangled: str = str_concat(ufcs_type, str_concat("__", ufcs_method));
            return pr(pr_pos(ufcs_ar), mk3(pool, 7, ufcs_mangled, pr_val(ufcs_ar)));
        };
        print("ERROR: UFCS form `<Type as Trait>::method(args)` parsed but did not match the supported shape. Workaround: call the trait method directly via the receiver (`s.f(...)`) when only one trait implements the method, or use the path form `Foo::f(&s)` when the trait is unambiguous.");
        panic("nucleor: UFCS expression form did not match supported shape (see ERROR diagnostic above)");
    };
    //  canonical Rust `move ||` / `move |args|`
    // closure-by-move pre-fix lexed `move` as an identifier at
    // expression start, then the parser tried to call a fn named
    // `move` on the closure args, surfacing as the clang-link error
    // `error[TYP-005]: undefined function 'move'` (or worse, `@move
    // undefined` at the link stage). Halt at parse with a clean
    // diag pointing at the workaround (drop the `move` keyword —
    // Nucleor closures capture by reference today, so move-capture
    // is the same observable behavior in v0.6).
    if tt == 1 && str_eq(pkv(tokens, pos), "move") == 1 {
        let mv_next: i64 = pk(tokens, pos + 1);
        if mv_next == 65 || mv_next == 37 {
            print("ERROR: `move` closure capture is not supported in Nucleor. Drop the `move` keyword — Nucleor closures capture the enclosing scope's bindings by value snapshot (the env stores a copy of each captured i64 at literal-evaluation time), which is the observable equivalent of `move` under the i64-everywhere ABI.");
            panic("nucleor: `move` closure form not yet supported (see ERROR diagnostic above)");
        };
    };
    if tt == 2 {
        let mut cp: i64 = pos + 1;
        if pk(tokens, cp) == 83 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 52 { depth = depth + 1; }
                else if pk(tokens, cp) == 53 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        let int_tok: Vec<i32> = tok_at(tokens, pos);
        let int_suffix: i64 = tok_int_suffix_code(int_tok);
        let int_value_v110: i64 = tok_val(int_tok);
        if int_suffix != 0 { return pr(cp, mk3(pool, 1, int_value_v110, int_suffix)); };
        return pr(cp, mk2(pool, 1, int_value_v110));
    };
    // f64 literal (token 70) — encoded as int_part*1000000 + frac_millionths
    if tt == 70 {
        let mut cp: i64 = pos + 1;
        if pk(tokens, cp) == 83 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 52 { depth = depth + 1; }
                else if pk(tokens, cp) == 53 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        return pr(cp, mk2(pool, 71, pkv(tokens, pos)));
    };
    // NUC-FEEDBACK-002: f32-typed float literal token (lexer
    // tagged it 125 because of an `f32` suffix). Same body as tt==70
    // but emits AST kind 73 instead of 71 so lower_expr routes it
    // through f32_from_scaled.
    if tt == 125 {
        let mut cp: i64 = pos + 1;
        if pk(tokens, cp) == 83 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 52 { depth = depth + 1; }
                else if pk(tokens, cp) == 53 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        return pr(cp, mk2(pool, 73, pkv(tokens, pos)));
    };
    // f64 raw-bits literal (token 124) — value IS the i64
    // bit pattern of the parsed float (via str_to_f64 at lex time).
    // Emits AST kind 72 which lower_expr handles by emitting the
    // bit pattern directly as a const_int (no scaled-int divide).
    if tt == 124 {
        let mut cp: i64 = pos + 1;
        if pk(tokens, cp) == 83 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 52 { depth = depth + 1; }
                else if pk(tokens, cp) == 53 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        return pr(cp, mk2(pool, 72, pkv(tokens, pos)));
    };
    if tt == 3 { return pr(pos + 1, mk2(pool, 2, pkv(tokens, pos))); };
    if tt == 52 { return parse_passthrough_block_expr(tokens, pos, pool); };
    if tt == 50 {
        let mut r: Vec<i32> = parse_expr(tokens, pos + 1, pool);
        let mut cp: i64 = pr_pos(r);
        // v0.7.21 (defensive halt — parenthesized range expression
        // `(start..end)` / `(start..=end)`). Pre-fix this surfaced as
        // wrong-class `error[NR020]: parse error: expected ')', got
        // token 58` (token 58 = `..`, token 96 = `..=`) because Nucleor's
        // range parser is hardcoded inside `parse_for_stmt` only —
        // ranges are NOT valid expressions in `parse_expr`. Halt cleanly
        // with a workaround pointer (use the bare for-iter form, or
        // build the iteration manually).
        if pk(tokens, cp) == 58 || pk(tokens, cp) == 96 {
            print("ERROR: parenthesized range expression `(start..end)` / `(start..=end)` (e.g. `(0..10).collect()`, `for i in (0..3) {}`, `let r = (0..N);`) is not yet supported in Nucleor. Pre-v0.7.21 surfaced as wrong-class `error[NR020]: expected ')', got token 58` because ranges are only parsed inside `for IDENT in EXPR..EXPR { ... }` heads, NOT as regular expressions.");
            print("       Workaround for `for i in (0..N) { ... }`: drop the parens — `for i in 0..N { ... }` is supported.");
            print("       Workaround for `(0..N).collect::<Vec<i64>>()`: build the Vec explicitly — `let mut v: Vec<i64> = Vec::new(); let mut i: i64 = 0; while i < N { v.push(i); i = i + 1; }`.");
            print("       Workaround for `(0..N).step_by(K).collect()`: same pattern with `i = i + K`.");
            print("       Workaround for `(0..N).rev()`: count down — `let mut i: i64 = N - 1; while i >= 0 { ... i = i - 1; }`.");
            print("       Tracked for forward-roadmap (range-as-expression needs a Range<T> type plus iterator-protocol substrate; sister to V1.4 `.iter()` chains).");
            panic("nucleor: parenthesized range expression not yet supported (see ERROR diagnostic above)");
        };
        if pk(tokens, cp) != 44 {
            let after_rparen: i64 = expect_tok(tokens, cp, 51);
            // `(expr)(args)` shape — parenthesised expression immediately
            // followed by a `(args)` call. Pre-fix this silently lowered
            // as if `(args)` were a separate parenthesised expression and
            // produced the inner expression's *value* (eg. the fn-pointer
            // address) instead of CALLING it. Adopters writing the
            // canonical Rust dispatch-table-via-struct pattern got a
            // giant address-like number where they expected the call
            // result.
            // Real fix (extend parse_postfix to accept `(args)` on any
            // callable expression + emit indirect-call IR via inttoptr +
            // call) is a substantial multi-ship change. Until that
            // ships, halt cleanly with a workaround pointer so the
            // silent-miscompute window closes.
            if pk(tokens, after_rparen) == 50 {
                let inner_kind: i64 = node_kind(pool, pr_val(r));
                if inner_kind == 9 || inner_kind == 10 || inner_kind == 8 {
                    print("ERROR: `(expr)(args)` direct-call form (e.g. `(struct.field)(arg)` for fn-pointer fields, `(vec_get(&ops, i))(arg)` for fn-pointer vectors) is not yet supported — the parser silently dropped the args and returned the function-pointer ADDRESS instead of calling it. Workaround: extract the fn-pointer to a local variable first, then call it: `let f = struct.field; f(arg)` or `let f = vec_get(&ops, i); f(arg)` — both work today and produce the expected call result.");
                    panic("nucleor: `(expr)(args)` direct-call form not implemented; see ERROR diagnostic above for workarounds");
                };
                //  extends the
                // v0.6.12 halt to three more inner-expression shapes
                // that *also* silently miscomputed (returned the inner
                // expression's *value*, e.g. fn-pointer address, instead
                // of CALLING it):
                //   - kind 42 (closure literal — IIFE: `(|x| x*2)(21)`)
                //   - kind 7 (call result — `(get_handler())(21)`)
                //   - kind 99 (`as` cast — `(p as fn(i64)->i64)(21)`)
                // Same workaround pattern (extract to a local first)
                // works for all three. Full indirect-call lowering
                // remains the multi-ship real fix.
                if inner_kind == 42 || inner_kind == 7 || inner_kind == 99 {
                    print("ERROR: `(expr)(args)` direct-call form not supported for parenthesized inner expressions (`(|x| x*2)(21)`, `(get_handler())(21)`, `(p as fn(i64)->i64)(21)`). Bind the inner expression to a name and call that: `let f = |x| x * 2; f(21)`.");
                    print("  Workaround: extract the callable to a local variable first, then call it.");
                    print("    IIFE:        let f = |x: i64| x * 2; let v = f(21);");
                    print("    Call result: let f = get_handler();    let v = f(21);");
                    print("    Cast:        let f = p as fn(i64)->i64; let v = f(21);");
                    print("  All three work today and produce the expected call result. Full indirect-call lowering for the canonical Rust direct form is forward-roadmap.");
                    panic("nucleor: `(expr)(args)` direct-call form (IIFE/call-result/cast inner) not implemented");
                };
            };
            return pr(after_rparen, pr_val(r));
        };
        let mut items: Vec<i32> = Vec::new();
        items.push(pr_val(r));
        while pk(tokens, cp) == 44 {
            r = parse_expr(tokens, cp + 1, pool);
            items.push(pr_val(r));
            cp = pr_pos(r);
        };
        cp = expect_tok(tokens, cp, 51);
        return pr(cp, mk2(pool, 48, mk_list(pool, items)));
    };
    if tt == 54 {
        let mut cp: i64 = pos + 1;
        let mut items: Vec<i32> = Vec::new();
        while pk(tokens, cp) != 55 && pk(tokens, cp) != 0 {
            if vec_len(items) > 0 { cp = expect_tok(tokens, cp, 44); };
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            items.push(pr_val(er));
            cp = pr_pos(er);
            // v0.6.77 RFC V1.11
            //  canonical
            // Rust `[VAL; N]` (e.g. `let buf: Vec<i64> = [0; 4];`)
            // pre-fix rejected at parse time with `error[NR020]: parse
            // error at byte K: expected ',', got ';'` — the `[V, V, ...]`
            // parser had no `;` branch and the `vec![V; N]` macro
            // (closed v0.6.41) requires the `vec!` prefix.
            // Now after parsing the first item, peek for `;` — if
            // present, parse N (must be a literal int) and expand to
            // an N-item kind-47 array literal (same lowering as
            // `[V, V, ..., V]` — vec_new + N pushes). Hard-cap N at
            // 1024 to keep the parse-time expansion bounded; for
            // larger / runtime-evaluated N the existing `vec![V; N]`
            // form is the path.
            if vec_len(items) == 1 && pk(tokens, cp) == 43 {
                cp = cp + 1;
                let mut nr_v077: Vec<i32> = parse_expr(tokens, cp, pool);
                cp = pr_pos(nr_v077);
                cp = expect_tok(tokens, cp, 55);
                let n_node: i64 = pr_val(nr_v077);
                let nk: i64 = node_kind(pool, n_node);
                if nk != 1 {
                    print("ERROR: `[VAL; N]` repeat-init only accepts a literal integer count today (parser-time expansion). Use `vec![VAL; N]` for a runtime-evaluated count — that form lowers to a runtime push-loop.");
                    panic("nucleor: non-literal repeat-count in `[VAL; N]`");
                };
                let n_val: i64 = node_field(pool, n_node, 1);
                if n_val < 0 || n_val > 1024 {
                    print("ERROR: `[VAL; N]` count must be in 0..=1024 (parser-time expansion bound). For larger or runtime-evaluated N use the `vec![VAL; N]` form (runtime loop).");
                    panic("nucleor: `[VAL; N]` count out of bounds");
                };
                let item_node: i64 = vec_get(items, 0);
                let mut rep_items: Vec<i32> = Vec::new();
                let mut ri_v077: i64 = 0;
                while ri_v077 < n_val {
                    rep_items.push(item_node);
                    ri_v077 = ri_v077 + 1;
                };
                return pr(cp, mk2(pool, 47, mk_list(pool, rep_items)));
            };
        };
        cp = expect_tok(tokens, cp, 55);
        return pr(cp, mk2(pool, 47, mk_list(pool, items)));
    };
    // if-expression
    if tt == 13 { let mut r: Vec<i32> = parse_if(tokens, pos + 1, pool); return r; };
    if tt == 63 { let mut r: Vec<i32> = parse_match_stmt(tokens, pos + 1, pool, tok_pos_at(tokens, pos)); return r; };
    // block-form `restricts [...] { ... }` was a
    // parse-time fail-closed halt while no real enforcement existed.
    // R05 Phase 2b first slice: the
    // block form now parses as a passthrough block expression and the
    // source-level pre-pass `enforce_restricts_block_effects`
    // (registered alongside `enforce_requires_direct_calls` in the
    // build pipeline) emits `error[EFF-003]` when a direct call inside
    // the block uses an effect named in the deny row. Two surfaces
    // are enforced in this slice: builtin print-family I/O and the
    // `channel` constructor (mapped via `restricts_builtin_effect`),
    // and same-file user fns whose declared `requires [...]` row
    // overlaps the deny row (via `effect_row_intersect_first`).
    // Clean blocks (no calls / no overlap) compile and run normally.
    // Out-of-scope per dispatch boundaries: whole-program effect
    // inference, cross-module propagation, methods/closures/higher-
    // order effects, RFC-0033 broader subtyping. The same-file
    // `requires [...]` check (`enforce_requires_direct_calls`) keeps
    // the transitive-callee class trapped on the requires-row surface
    // for un-rowed user fns reached from the block.
    if tt == 1 && str_eq(pkv(tokens, pos), "restricts") == 1 && pk(tokens, pos + 1) == 54 {
        let after_brackets: i64 = skip_bracket_list(tokens, pos + 1);
        return parse_passthrough_block_expr(tokens, after_brackets, pool);
    };
    // removed dead `tt == 76` branch (restricts) — see
    // classify_kw notes. The old token-kind branch had zero usage for
    // legitimate code; in practice it only fired on user fns named
    // `restricts` and mangled the call site into a phantom block
    // expression.
    // `unsafe` contextual block — only when followed by `{`.
    // Otherwise let the identifier path handle it (so `unsafe(x)` as
    // a user fn call works). Uses && short-circuit (now correct since
    // v0.3.148) to safely guard the pkv dereference.
    if tt == 1 && str_eq(pkv(tokens, pos), "unsafe") == 1 && pk(tokens, pos + 1) == 52 {
        return parse_passthrough_block_expr(tokens, pos + 1, pool);
    };
    // v0.7.76 (defensive halt — Rust `const { ... }` inline-const
    // block expression, used to force compile-time evaluation of
    // the body even in non-const contexts). Pre-fix `const` lexed
    // as keyword token 73 and parse_primary had no branch for it
    // at expression start, surfacing as wrong-class
    // `error[NR020]: parse_primary cannot start an expression at
    // token kind 73`. Halt cleanly when `const` is immediately
    // followed by `{`. Sister to v0.7.74 `try { ... }` halt
    // (same expr-position-block-not-supported family).
    if tt == 73 && pk(tokens, pos + 1) == 52 {
        print("ERROR: `const { ... }` inline-const block expressions (Rust 1.79+ form, used to force compile-time evaluation in non-const contexts) are not yet supported in Nucleor. Pre-v0.7.76 surfaced as wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 73` because parse_primary had no `const`-prefix branch.");
        print("       Workaround: lift the value into a module-scope `const NAME: T = ...;` declaration and reference NAME at the use site — Nucleor's existing const-folder evaluates simple arithmetic at parse time, so the observable result is the same. Sister to v0.7.74 `try { ... }` halt — same expr-position block-not-supported family.");
        panic("nucleor: `const { ... }` inline-const block not yet supported (see ERROR diagnostic above)");
    };
    // v0.7.74 (defensive halt — Rust experimental `try { ... }` block
    // expression, used to wrap fallible computation and yield a
    // `Result<T, E>` with `?` short-circuiting). Pre-fix `try` lexed
    // as an identifier and the `{ ... }` that followed parsed as
    // some other production, with the surface treating `try` as a
    // fn name and downstream emit producing a clang-link wrong-class
    // `error[TYP-005]: undefined function 'try()'`. Halt cleanly at
    // parse_primary when we see `try` immediately followed by `{`.
    // Sister to the `unsafe { ... }` / `wrapping { ... }` /
    // `saturating { ... }` block-expr branches just below; same
    // ident-then-`{` lookahead shape, but no semantic substrate yet
    // for the Result-wrapping rewrite.
    if tt == 1 && str_eq(pkv(tokens, pos), "try") == 1 && pk(tokens, pos + 1) == 52 {
        print("ERROR: `try { ... }` block expressions (Rust experimental Result-wrapping form) are not yet supported in Nucleor. Workaround: write the explicit Result construction manually — `let r: Result<T, E> = { let v = compute()?; Ok(v) };` — or match each fallible call directly.");
        panic("nucleor: `try { ... }` block expr not yet supported (see ERROR diagnostic above)");
    };
    // `wrapping { ... }` block form. Default i32/i64 arithmetic
    // already two's-complement-wraps under the i64 ABI (probe verified:
    // 2147483647 + 1 i32 = -2147483648; 100000 * 100000 i32 = 1410065408),
    // so the block is semantically a passthrough. This is the v1 close —
    // a future overflow-checked default mode would route arithmetic
    // ops inside this block back to wrapping intrinsics. Same lookahead
    // gate as `unsafe` above so user fns named `wrapping` keep working.
    if tt == 1 && str_eq(pkv(tokens, pos), "wrapping") == 1 && pk(tokens, pos + 1) == 52 {
        // route `wrapping { ... }` through the kind-52
        // mode-1 wrapped-block-expr so the lower_expr handler sets
        // sym["__arith_mode"]=1 in the body's sym before lowering
        // the contained arithmetic. Pre-fix this called the
        // passthrough parser which produces a kind-25 (or similar)
        // block with no mode flag, so __arith_mode was never set
        // and Track E's `arith_mode_explicit <= 0` precedence
        // guard at both intrinsic emit sites couldn't fire. With
        // v0.4.238's NUCLEOR_INT_STRICT_INTRIN=1 default, every
        // `wrapping { a + b }` block emitted the strict-intrinsic
        // trap path and panicked at runtime on real overflow —
        // the exact opposite of the user's intent. The wrap_i32
        // tail clamp (kind-52 mode==1 in lower_expr) was the only
        // thing keeping the block's final value pinned to i32
        // range; per-op behavior was broken pre-v0.4.238 too,
        // just invisibly because nsw doesn't trap.
        return parse_wrapped_block_expr(tokens, pos + 1, pool, 1);
    };
    // `saturating { ... }` block. Arithmetic inside the
    // block lowers per operation to saturating_add/sub/mul helpers
    // instead of clamping only the final block result (the v0.4.105
    // approach where inner arithmetic still overflowed at the i64
    // level and only the block's final value got pinned to i32 range
    // was insufficient — multi-step expressions wrapped). Same
    // lookahead gate as `unsafe`/`wrapping` above so user fns named
    // `saturating` keep working.
    if tt == 1 && str_eq(pkv(tokens, pos), "saturating") == 1 && pk(tokens, pos + 1) == 52 {
        return parse_wrapped_block_expr(tokens, pos + 1, pool, 2);
    };
    // removed dead tt == 78/79 branches (wrapping/saturating).
    // classify_kw no longer maps these to 78/79; the kw block forms had
    // zero usage anywhere in the codebase. User fns named `wrapping` or
    // `saturating` now lex/parse as normal identifiers.
    if tt == 1 {
        // v0.5 ship 7 — capture identifier byte offset for spanning
        // call expressions (kind 7) and the var-ref fallback.
        let ident_span: i64 = tok_pos_at(tokens, pos);
        let name: i64 = pkv(tokens, pos);
        // v0.7.87 (defensive halt — Rust prelude `drop(value)`).
        // Pre-fix `drop(v)` parsed as a call to undefined fn `drop`,
        // surfacing first as warning[TYP-005] and then clang-link
        // hard-fail wrong-class `error[TYP-005]: undefined function
        // 'drop'`. Adopters expect Rust's prelude `drop` (which
        // forces ownership transfer / RAII destructor); Nucleor's
        // i64-everywhere ABI manages heap via reference-tracking,
        // so `drop(v)` is informational (Nucleor frees when the
        // last reference goes out of scope). Halt cleanly with a
        // workaround pointer (just remove the `drop(v)` call —
        // the heap manages itself; for explicit Vec clear use
        // `vec_clear(v)`). Sister to v0.6.82 idiom-method halt
        // family (same Rust-prelude-not-yet-supported class).
        if str_eq(name, "drop") == 1 && pk(tokens, pos + 1) == 50 {
            print("ERROR: Rust prelude `drop(value)` is not yet supported in Nucleor. Workaround: simply remove the `drop(v)` call. Nucleor's i64-everywhere ABI manages heap via reference-tracking and frees the value automatically when the last reference goes out of scope. For explicit Vec clearing use `vec_clear(v)`; for explicit String/file/socket cleanup, the rod's own `*_free` / `*_close` helper is the canonical form.");
            panic("nucleor: Rust prelude `drop(value)` not yet supported (see ERROR diagnostic above)");
        };
        if str_eq(name, "Some") == 1 || str_eq(name, "None") == 1 || str_eq(name, "Ok") == 1 || str_eq(name, "Err") == 1 {
            let mut tname: str = "Option";
            if str_eq(name, "Ok") == 1 || str_eq(name, "Err") == 1 { tname = "Result"; };
            if pk(tokens, pos + 1) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, pos + 2, pool);
                return pr(pr_pos(ar), mk4(pool, 12, tname, name, pr_val(ar)));
            };
            let mut empty: Vec<i32> = Vec::new();
            return pr(pos + 1, mk4(pool, 12, tname, name, mk_list(pool, empty)));
        };
        let p2: i64 = pos + 1;
        let cp2: i64 = skip_angle_group(tokens, p2);
        if pk(tokens, cp2) == 52 {
            // also recognize pure-shorthand struct init —
            // `IDENT,` (multi-field shorthand) and `IDENT}` (single-
            // field shorthand). Pre-v0.3.114, only `IDENT:` (named
            // field) and `}` (empty) triggered struct-init parse.
            // Pure shorthand like `P { x, y }` (no `:`) fell through
            // to the bare identifier path; the `{ x, y }` was treated
            // as a separate block which left `@P` as an unresolved
            // global ref. Hard adoption blocker for any constructor
            // body using the canonical shorthand form
            // (`fn make(x, y) -> P { P { x, y } }`).
            // For shorthand-only patterns (`,` / `}` after IDENT, no
            // `:` to confirm field-init shape), require the TYPE
            // identifier (`name`) to start with an uppercase letter.
            // Without this guard, `if foo { bar }` and
            // `while x { y }` patterns misfire — the lowercase `foo`
            // looks like a struct name to the disambiguator and the
            // single-ident body `bar` becomes a phantom shorthand
            // field. Rust convention reserves CamelCase for types,
            // so the case check is a clean boundary.
            let name_first: i64 = if str_len(name) > 0 { str_char_at(name, 0) } else { 0 };
            let is_upper: i64 = if name_first >= 65 && name_first <= 90 { 1 } else { 0 };
            // empty struct-init `IDENT { }` now also requires
            // uppercase name. Pre-fix `match x { }` (empty match body)
            // parsed as `x { }` empty struct-init, the closing `}`
            // disappeared into the struct-init's parser, and the next
            // token (`;`) collided with parse_match_stmt's expect_tok(52)
            // for the match body's `{`. Adopters got a confusing
            // `expected backtick { backtick, got backtick ; backtick`
            // panic (after v0.4.208's token-name table; raw IDs pre-v0.4.208).
            // Same uppercase guard family as v0.3.114 for shorthand.
            // Regression: empty match body panic.
            // — the empty match body now parses correctly with zero arms,
            // surfacing later as MATCH-001 if rtype-checked or running to
            // exit cleanly with no arm matched (intentional).
            if (is_upper == 1 && pk(tokens, cp2 + 1) == 53)
               || (pk(tokens, cp2 + 1) == 1 && pk(tokens, cp2 + 2) == 42)
               || (is_upper == 1 && pk(tokens, cp2 + 1) == 1 && pk(tokens, cp2 + 2) == 44)
               || (is_upper == 1 && pk(tokens, cp2 + 1) == 1 && pk(tokens, cp2 + 2) == 53) {
                return parse_struct_init(tokens, pos, pool);
            };
        };
        // turbofish syntax `name::<TypeArgs>(args)`. Pre-
        // the `::<` after `name` was treated as `::ident` —
        // qname captured the `<` token's value (garbage), the
        // following `(` failed to match the kind-12 dispatch shape,
        // and the call lowered as an associated-fn-call with a bogus
        // qname → diagnostic + zero placeholder. Adopters reaching
        // for the canonical `Vec::<i64>::new()` / `id::<T>(x)` pattern
        // saw silent miscomputes alongside an informational error.
        // Strip `::<TypeArgs>` and re-dispatch via the regular fn-call
        // path; the type args are advisory at lower-time anyway.
        if pk(tokens, cp2) == 46 && pk(tokens, cp2 + 1) == 32 {
            let after_args: i64 = skip_angle_group(tokens, cp2 + 1);
            if pk(tokens, after_args) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, after_args + 1, pool);
                let cn1: i64 = mk3(pool, 7, name, pr_val(ar));
                node_set_span(pool, cn1, ident_span);
                return pr(pr_pos(ar), cn1);
            };
        };
        if pk(tokens, cp2) == 46 {
            let qname: i64 = pkv(tokens, cp2 + 1);
            // defensive halt: canonical Rust stdlib path
            // `std::mem::swap(...)`, `std::cmp::min(...)`,
            // `std::collections::HashMap::new()`, etc. (3+ `::`-
            // separated path components) pre-fix saw the second `::`
            // after the first qname and fell through the kind-12 path,
            // returning a partial AST that desync'd with the remaining
            // `::<rest>` tokens. The downstream parser then surfaced
            // wrong-class `NR020: parse_primary cannot start an
            // expression at token kind 46`. Halt cleanly with a
            // workaround pointer for known Rust stdlib namespaces
            // (`std`, `core`, `alloc`).
            if pk(tokens, cp2 + 2) == 46 {
                let v096_top: str = name;
                if str_eq(v096_top, "std") == 1 || str_eq(v096_top, "core") == 1 || str_eq(v096_top, "alloc") == 1 {
                    print(str_concat("ERROR: Rust stdlib namespace path `", str_concat(v096_top, str_concat("::", str_concat(qname, "::...(...)` is not yet supported in Nucleor. Workaround: most stdlib helpers have direct Nucleor equivalents — for `std::mem::swap(&mut a, &mut b)`, write the 3-line tmp swap (`let t = a; a = b; b = t;`); for `std::cmp::min/max`, use `if a < b { a } else { b }`; for collection ctors, use the unqualified Nucleor names (`Vec::new()`, `HashMap::new()`, `String::new()`).")))));
                    panic(str_concat("nucleor: Rust stdlib path `", str_concat(v096_top, str_concat("::", str_concat(qname, "::..` not yet supported (see ERROR diagnostic above)")))));
                };
            };
            if pk(tokens, cp2 + 2) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, cp2 + 3, pool);
                return pr(pr_pos(ar), mk4(pool, 12, name, qname, pr_val(ar)));
            } else if pk(tokens, cp2 + 2) == 52 && (pk(tokens, cp2 + 3) == 53 || (pk(tokens, cp2 + 3) == 1 && pk(tokens, cp2 + 4) == 42)) {
                // struct-like enum variant constructor
                // `EnumName::Variant { field: val, ... }`. Parse the
                // named fields and produce a kind-12 with values in
                // SOURCE order (field names are discarded).
                // disambiguation guard. Only fire if what's
                // inside the `{` looks like a field-init list (empty
                // `}` or IDENT followed by `:`). Without this, the
                // branch incorrectly captured the match body in
                // `match Stream::Done { Stream::More(v) => ... }`
                // because the SCRUTINEE position has `IDENT::IDENT {`
                // followed by patterns, not field initializers.
                let mut cp3: i64 = cp2 + 3;
                let mut sargs: Vec<i32> = Vec::new();
                while pk(tokens, cp3) != 53 && pk(tokens, cp3) != 0 {
                    if vec_len(sargs) > 0 { cp3 = expect_tok(tokens, cp3, 44); };
                    if pk(tokens, cp3) == 53 { break; };
                    cp3 = cp3 + 1;
                    cp3 = expect_tok(tokens, cp3, 42);
                    let mut vr: Vec<i32> = parse_expr(tokens, cp3, pool);
                    sargs.push(pr_val(vr));
                    cp3 = pr_pos(vr);
                };
                cp3 = cp3 + 1; // }
                return pr(cp3, mk4(pool, 12, name, qname, mk_list(pool, sargs)));
            } else {
                let mut empty: Vec<i32> = Vec::new();
                return pr(cp2 + 2, mk4(pool, 12, name, qname, mk_list(pool, empty)));
            };
        };
        if pk(tokens, cp2) == 50 { let mut ar: Vec<i32> = parse_args(tokens, cp2 + 1, pool); let cn2: i64 = mk3(pool, 7, name, pr_val(ar)); node_set_span(pool, cn2, ident_span); return pr(pr_pos(ar), cn2); };
        // v0.4.209 RFC-0015 phase 3a-step-3 (Option D): kind-3 var-ref
        // promoted from mk2 to mk3. Slot 2 is the width-tag for narrow-
        // typed bindings (i8/i16/u8/u16). Default 0 = untyped (i64 ABI
        // back-compat). Type-check fills it in for narrow types; codegen
        // reads it via a single node_field call (no str_concat, no
        // sym_get hash hit — the perf failure mode of v0.4.199's retry).
        // v0.5 ship 7 final: span the var-ref nid at the identifier
        // byte offset so OWN-001 (use-after-move) and other identifier-
        // anchored diagnostics caret precisely at the use site instead
        // of scanning the source text by name (which hits the FIRST
        // occurrence, not the actual use site).
        let var_nid: i64 = mk3(pool, 3, name, 0);
        node_set_span(pool, var_nid, ident_span);
        return pr(cp2, var_nid);
    };
    // Closure: |params| expr  or  |params| { stmts }  or  || expr  or  || { stmts }
    if tt == 65 || tt == 37 {
        let mut cparams: Vec<i32> = Vec::new();
        let mut cp: i64 = pos + 1;
        // tt==37 means ||, i.e. zero-param closure — skip param parsing
        if tt == 65 {
            while pk(tokens, cp) != 65 && pk(tokens, cp) != 0 {
                if vec_len(cparams) > 0 { cp = expect_tok(tokens, cp, 44); };
                let pn: i64 = pkv(tokens, cp);
                cp = cp + 1;
                if pk(tokens, cp) == 42 { cp = cp + 1; let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr); };
                cparams.push(pn);
            };
            cp = cp + 1;
        };
        // optional `-> RetType` after the closing `|`. Pre-
        // `|x: i64| -> i64 { … }` left the parser pointing
        // at `->`, which neither matched the `{ … }` block branch nor
        // parsed cleanly as an expression — the body parser then
        // produced an `@i64` global ref (clang link error
        // `use of undefined value '@i64'`). The return type is
        // advisory at lower-time anyway (closures emit i64 returns
        // by convention), so we just skip the annotation.
        if pk(tokens, cp) == 41 {
            let mut tr: Vec<i32> = parse_type(tokens, cp + 1);
            cp = pr_pos(tr);
        };
        if pk(tokens, cp) == 52 {
            cp = expect_tok(tokens, cp, 52);
            let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(br), 53);
            return pr(cp, mk3(pool, 42, mk_list(pool, cparams), pr_val(br)));
        } else {
            // Lane 4 / F-053: closure without a body — `||;`, `|x|;`,
            // `|x| )` etc. Pre-fix parse_expr fell through to
            // parse_primary on the recovery-marker token (`;`/`)`/`,`/
            // `}`/`]`/`=`/EOF) and silently produced `int_lit(0)` as
            // the closure body — no diag, hidden no-op. Reject cleanly.
            let closure_body_tok: i64 = pk(tokens, cp);
            if closure_body_tok == 0 || closure_body_tok == 40 || closure_body_tok == 41
                || closure_body_tok == 43 || closure_body_tok == 44
                || closure_body_tok == 51 || closure_body_tok == 53 || closure_body_tok == 55 {
                let closure_body_byte: i64 = tok_pos_at(tokens, cp);
                panic(str_concat("error[PARSE-CLOSURE-NO-BODY]: closure literal at byte ", str_concat(str_from_int(closure_body_byte), str_concat(" has no body — got ", str_concat(tok_name(closure_body_tok), ". Closure form is `|args| <expr>` or `|args| { <stmts> }`.")))));
            };
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(er);
            let mut rbody: Vec<i32> = Vec::new();
            rbody.push(mk2(pool, 22, pr_val(er)));
            return pr(cp, mk3(pool, 42, mk_list(pool, cparams), mk_list(pool, rbody)));
        };
    };
    // pragmatic
    // narrow-predicate approach. Pre-fix the fall-through silently
    // returned `int_lit(0)` and advanced past the unhandled token
    // for ALL tokens — including ones like `@` (binding pattern)
    // and `i:` (incomplete annotation) that adopters write
    // legitimately as Rust idioms but Nucleor doesn't yet parse.
    // Result: silent miscompute → working binary that does the
    // wrong thing.
    // v0.4.72 / v0.4.81 attempts to panic unconditionally broke
    // tests/rods/pgs_smoke (token 51 = `)` legitimately reached
    // here from macro-expanded code at byte 6571). Per change-map
    // §9 the proper fix is a `parse_primary_or_recover(allow_recovery)`
    // two-arg API — but that requires finding every recovery
    // context call site of parse_primary. For now: keep silent
    // fallback ONLY for tokens that mark expression-end /
    // recovery-context (`)` `,` `;` `}` `]` `=` `EOF`). For ANY
    // OTHER unhandled token (including `@`, raw `:`, etc.), halt
    // with NR020. This catches the silent-miscompute class while
    // preserving pgs_smoke's legit recovery.
    let fall_tt: i64 = pk(tokens, pos);
    let is_recovery_marker: i64 = if fall_tt == 0
        || fall_tt == 40  // `=`
        || fall_tt == 41  // `}`
        || fall_tt == 43  // `;`
        || fall_tt == 44  // `,`
        || fall_tt == 51  // `)`
        || fall_tt == 55  // `]`
        { 1 } else { 0 };
    // defensive halt — labeled loop: canonical Rust loop
    // labels `'outer: for ... { break 'outer; }` pre-fix surfaced
    // as wrong-class `NR020: parse_primary cannot start expression
    // at token kind 98` because token 98 is the lifetime/label
    // token and parse_primary has no `'label:` prefix branch.
    // Halt cleanly with a workaround pointer (boolean flag).
    if fall_tt == 98 {
        print("ERROR: loop labels (`'outer: for ... { break 'outer; }`, `'lbl: loop { continue 'lbl; }`) are not yet supported in Nucleor. Workaround: use a boolean flag to break out of nested loops — `let mut done: i64 = 0; for i in 0..5 { if done == 1 { break; }; for j in 0..5 { if i + j > 3 { done = 1; break; } } }`.");
        panic("nucleor: loop labels not yet supported (see ERROR diagnostic above)");
    };
    // defensive halt — range-as-expression: canonical Rust
    // `let r = 0..10;` and `(0..10).step_by(2)` patterns rely on the
    // range syntax `<lo>..<hi>` producing a `Range<T>` value at
    // expression position. Nucleor today only recognises ranges in
    // for-head context (`for i in 0..10`) — at expression position
    // the `..` (token 58) hits parse_primary's generic NR020 panic.
    // Convert to a clean halt with workaround pointer.
    if fall_tt == 58 || fall_tt == 96 {
        let v094_op: str = if fall_tt == 58 { ".." } else { "..=" };
        print(str_concat("ERROR: range expression `<lo>", str_concat(v094_op, "<hi>` at expression position is not yet supported in Nucleor. Workaround: rewrite as a `while` loop with explicit counter — `let mut i: i64 = 0; while i < 10 { ...; i = i + 1; }` (or `i = i + STEP` for step_by).")));
        panic("nucleor: range expression at expression position not yet supported (see ERROR diagnostic above)");
    };
    if is_recovery_marker == 0 {
        let fall_tok: Vec<i32> = tok_at(tokens, pos);
        let fall_byte: i64 = tok_pos(fall_tok);
        let fall_lc: Vec<i32> = tokens_linecol_at_byte(tokens, fall_byte);
        let fall_line: i64 = vec_get(fall_lc, 0);
        let fall_col: i64 = vec_get(fall_lc, 1);
        let fall_loc: str = str_concat(str_from_int(fall_line), str_concat(":", str_from_int(fall_col)));
        panic(str_concat("error[NR020]: parse_primary cannot start an expression at token kind ", str_concat(str_from_int(fall_tt), str_concat(" at line ", str_concat(fall_loc, str_concat(" (byte ", str_concat(str_from_int(fall_byte), ")")))))));
    };
    return pr(pos + 1, mk2(pool, 1, 0));
}

#[manual_drop]
fn parse_postfix(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_primary(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    // defensive halt: C/Java-idiom `x++` / `x--` post-
    // increment/decrement operators don't exist in Rust (or Nucleor).
    // Pre-fix surfaced as wrong-class `NR020: parse_primary cannot
    // start expression at token kind 20` (the second `+` after `x+`)
    // because the `+` after the primary parses as a binop, then
    // parse_primary fails on the second `+`. Detect the `++`/`--`
    // shape after a primary and halt cleanly with `x = x + 1`
    // workaround pointer.
    let node_kind_postfix: i64 = node_kind(pool, node);
    let node_lvalue_postfix: i64 = if node_kind_postfix == 3 || node_kind_postfix == 9 || node_kind_postfix == 10 { 1 } else { 0 };
    if node_lvalue_postfix == 1 && pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 20 {
        print("ERROR: post-increment `x++` is not supported in Nucleor (Rust doesn't have `++`/`--` operators). Workaround: write the explicit assignment `x = x + 1;` (or `x += 1;` if `+=` is supported in your context).");
        panic("nucleor: `x++` post-increment not supported (see ERROR diagnostic above)");
    };
    if node_lvalue_postfix == 1 && pk(tokens, cp) == 21 && pk(tokens, cp + 1) == 21 {
        print("ERROR: post-decrement `x--` is not supported in Nucleor (Rust doesn't have `++`/`--` operators). Workaround: write the explicit assignment `x = x - 1;` (or `x -= 1;` if `-=` is supported in your context).");
        panic("nucleor: `x--` post-decrement not supported (see ERROR diagnostic above)");
    };
    while pk(tokens, cp) == 45 || pk(tokens, cp) == 54 || pk(tokens, cp) == 97 {
        if pk(tokens, cp) == 97 {
            // RFC-0016 phase 1: `?` postfix — desugars at lower-time into
            // err-check + early return on Err / None. Inner expression is
            // expected to be Result<T, E> or Option<T> (compiler trusts the
            // layout: cell 0 = tag, cell 1 = payload; tag 0 = Err/None).
            cp = cp + 1;
            node = mk2(pool, 122, node);
        } else {
        if pk(tokens, cp) == 45 {
            let mut fname: str = "";
            // v0.6.74 RFC V1.1 step 3: tuple-struct positional access.
            // `p.0` / `p.1` lex as `.` + int-literal token. Synthesize
            // the synthetic field name `__<digit>` at parse time so
            // the existing field-access type-check + lower paths
            // resolve to the matching `__<digit>` field declared in
            // parse_struct_decl's paren-form path.
            if pk(tokens, cp + 1) == 2 { fname = str_concat("__", str_from_int(pkv(tokens, cp + 1))); }
            else { fname = pkv(tokens, cp + 1); };
            let p2: i64 = cp + 2;
            let mut tname: str = "";
            let mut ctor_like: i64 = 0;
            if node_kind(pool, node) == 3 {
                tname = node_field(pool, node, 1);
                if str_len(tname) > 0 && str_len(fname) > 0 && str_char_at(tname, 0) >= 65 && str_char_at(tname, 0) <= 90 && str_char_at(fname, 0) >= 65 && str_char_at(fname, 0) <= 90 {
                    ctor_like = 1;
                };
            };
            if ctor_like == 1 && pk(tokens, p2) == 52 {
                let mut qp: i64 = p2 + 1;
                let mut qargs: Vec<i32> = Vec::new();
                while pk(tokens, qp) != 53 && pk(tokens, qp) != 0 {
                    if vec_len(qargs) > 0 {
                        qp = expect_tok(tokens, qp, 44);
                        if pk(tokens, qp) == 53 { break; };
                    };
                    let _field_name: str = pkv(tokens, qp);
                    qp = expect_tok(tokens, qp + 1, 42);
                    let mut er: Vec<i32> = parse_expr(tokens, qp, pool);
                    qargs.push(pr_val(er));
                    qp = pr_pos(er);
                };
                qp = expect_tok(tokens, qp, 53);
                cp = qp;
                node = mk4(pool, 12, tname, fname, mk_list(pool, qargs));
            } else if pk(tokens, p2) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, p2 + 1, pool);
                cp = pr_pos(ar); node = mk4(pool, 8, node, fname, pr_val(ar));
            } else if pk(tokens, p2) == 46 && pk(tokens, p2 + 1) == 32 {
                // v0.6.98 RFC V1.7-ext: turbofish syntax
                // `.method::<TypeArgs>(args)`. Pre-fix surfaced as
                // wrong-class `error[NR020]: parse_primary cannot
                // start expression at token kind 46` because the
                // postfix parser had no `::<` branch. Now: skip the
                // balanced `<...>` type-args (advisory under today's
                // mangling — Nucleor monomorphises by parameter, not
                // by call-site turbofish) and parse the trailing
                // `(args)` as a regular method call.
                let v098_after_args: i64 = skip_angle_group(tokens, p2 + 1);
                if pk(tokens, v098_after_args) == 50 {
                    let mut v098_ar: Vec<i32> = parse_args(tokens, v098_after_args + 1, pool);
                    cp = pr_pos(v098_ar); node = mk4(pool, 8, node, fname, pr_val(v098_ar));
                } else {
                    print(str_concat("ERROR: turbofish form `.", str_concat(fname, "::<...>` without trailing call `(...)` is not yet supported in Nucleor. Workaround: ensure the turbofish is followed by call args (`.collect::<Vec<i64>>()`), or drop the turbofish and let inference resolve (`let v: Vec<i64> = it.collect();`).")));
                    panic("nucleor: turbofish without call args not yet supported (see ERROR diagnostic above)");
                };
            } else if ctor_like == 1 {
                let mut empty: Vec<i32> = Vec::new();
                cp = p2;
                node = mk4(pool, 12, tname, fname, mk_list(pool, empty));
            } else { cp = p2; node = mk3(pool, 9, node, fname); };
        } else {
            let mut ir: Vec<i32> = parse_expr(tokens, cp + 1, pool);
            // NUC-FEEDBACK silent-segfault guard for str/Vec
            // slice syntax. Pre-fix `s[0..5]` printed "Parse error
            // ... expected token 55 got 58" but the build silently
            // continued, producing broken IR that SIGSEGVed at runtime.
            // Slice expressions aren't yet supported in the indexer
            // surface; halt cleanly with a workaround pointing at
            // `str_substring(s, lo, hi)` (or vec_slice when shipped).
            let after_idx_tok: i64 = pk(tokens, pr_pos(ir));
            if after_idx_tok == 58 || after_idx_tok == 96 {
                print("ERROR: slice syntax `expr[lo..hi]` is not yet supported (was a silent SIGSEGV pre-v0.4.55). Workarounds: for `str` use `str_substring(s, lo, hi)`; for `Vec<T>` use an explicit element-wise loop or build a new Vec via `vec_push` over the desired range.");
                panic("nucleor: slice expression `expr[lo..hi]` not supported");
            };
            //  canonical RFC-0034 explicit
            // CT-arg call form `ct_inc[42](x)` pre-fix parsed as
            // `name[index_expr]` (kind-10 indexer) followed by `(args)`
            // call — the call lowered to invoke the indexed value as
            // a fn pointer, which produced INVALID IR and SEGFAULTed
            // at runtime (rc=139). Detect the bracket-then-paren shape
            // when the indexer's BASE is a kind-3 var-ref (typical fn-
            // name shape) and halt with a clean diag pointing at the
            // workaround (omit the `[N]` from the call site — the
            // default erases anyway in RFC-0034 first-pass).
            let idx_end: i64 = pr_pos(ir);
            let base_kind: i64 = node_kind(pool, node);
            cp = expect_tok(tokens, idx_end, 55); node = mk3(pool, 10, node, pr_val(ir));
            if pk(tokens, cp) == 50 && base_kind == 3 {
                print("ERROR: RFC-0034 explicit compile-time argument call form `name[ARGS](args)` is not yet supported in Nucleor's first-pass `[]` parser. Workaround: omit the `[N]` from the call site — RFC-0034 first-pass erases the CT-args at lower-time, so `f(args)` is observably equivalent to `f[N](args)` for the unspecialized version.");
                panic("nucleor: RFC-0034 explicit CT-arg call form not yet supported (see ERROR diagnostic above)");
            };
        };
        };
    };
    return pr(cp, node);
}

#[manual_drop]
fn parse_unary(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    if pk(tokens, pos) == 20 {
        panic(str_concat("error[PARSE-UNARY-PLUS]: unary `+` is not supported at byte ", str_concat(str_from_int(tok_pos_at(tokens, pos)), ". Remove the redundant `+` or write the numeric expression without consecutive `+` operators. Pre-fix repeated operators such as `1 + + + 2` were misdiagnosed as post-increment.")));
    };
    if pk(tokens, pos) == 21 { let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool); return pr(pr_pos(r), mk2(pool, 5, pr_val(r))); };
    if pk(tokens, pos) == 38 { let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool); return pr(pr_pos(r), mk2(pool, 6, pr_val(r))); };
    if pk(tokens, pos) == 22 {
        let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool);
        return pr(pr_pos(r), mk2(pool, 92, pr_val(r)));
    };
    if pk(tokens, pos) == 82 {
        let mut cp: i64 = pos + 1;
        let mut is_mut: i64 = 0;
        // clean halt for `&raw const` / `&raw mut` (Rust 2021 raw-ref
        // syntax). Not in V1 surface. Workaround: take a regular `&` / `&mut`.
        if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "raw") == 1 {
            print("ERROR: raw-ref syntax `&raw const` / `&raw mut` is not in the V1 language surface.");
            print("       Workaround: use `&expr` (shared ref) or `&mut expr` (mutable ref).");
            print("       Raw pointer support is tracked separately from the safe subset.");
            panic("v0.7.14: &raw ref unsupported");
        };
        if pk(tokens, cp) == 12 { is_mut = 1; cp = cp + 1; };
        let mut r: Vec<i32> = parse_unary(tokens, cp, pool);
        if is_mut == 1 { return pr(pr_pos(r), mk2(pool, 91, pr_val(r))); };
        return pr(pr_pos(r), mk2(pool, 90, pr_val(r)));
    };
    let mut base: Vec<i32> = parse_postfix(tokens, pos, pool);
    let mut cp: i64 = pr_pos(base);
    let mut node: i64 = pr_val(base);
    // RFC-0015 phase 2: postfix `as TYPE` cast. v0.3.142: `as` is now
    // a contextual identifier-keyword. Recognised here (post-primary)
    // only when the current token is identifier "as". Use nested `&&`
    // to ensure short-circuit (Nucleor's && currently lowers to bitwise
    // AND, so flat 2-operand chains call the RHS even when LHS is false
    // -- hazardous when RHS dereferences pkv on a non-pointer token).
    let mut as_match: i64 = 0;
    if pk(tokens, cp) == 1 {
        if str_eq(pkv(tokens, cp), "as") == 1 { as_match = 1; };
    };
    while as_match == 1 {
        // v0.5 ship 7 — capture the `as` token's byte offset as the
        // cast nid's span so NUM-003 (narrowing) and NUM-006 (narrow-
        // float vec read) carets land at the cast site instead of
        // the function name fallback.
        let as_span: i64 = tok_pos_at(tokens, cp);
        cp = cp + 1;
        let mut tr: Vec<i32> = parse_type(tokens, cp);
        cp = pr_pos(tr);
        // AST node kind 99 = "as cast"; field 1 = expr, field 2 = type name
        node = mk3(pool, 99, node, pr_val(tr));
        node_set_span(pool, node, as_span);
        as_match = 0;
        if pk(tokens, cp) == 1 {
            if str_eq(pkv(tokens, cp), "as") == 1 { as_match = 1; };
        };
    };
    return pr(cp, node);
}

#[manual_drop]
fn parse_mul(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_unary(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 22 || pk(tokens, cp) == 23 || pk(tokens, cp) == 24 {
        let op: i64 = pk(tokens, cp); r = parse_unary(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}
#[manual_drop]
fn parse_add(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_mul(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 20 || pk(tokens, cp) == 21 {
        let op: i64 = pk(tokens, cp); r = parse_mul(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}
// shift tier — `<<` (token 115) and `>>` (parsed as two
// adjacent `>` tokens, so generic `Vec<Vec<T>>` keeps working).
// Between parse_add and parse_bitwise, matching Rust precedence:
// `* / %` > `+ -` > `<< >>` > `& ^ |` > `< > <= >=` > `== !=` > etc.
// tok_to_ir maps 115 → iop 16 (LLVM `shl i64`); the parser
// synthesizes a virtual `>>` token (kind 116) only at lower-time
// via mk4 → iop 17 (LLVM `ashr i64`) without touching the lexer.
#[manual_drop]
fn parse_shift(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_add(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    let mut done: i64 = 0;
    while done == 0 {
        let tt: i64 = pk(tokens, cp);
        if tt == 115 {
            r = parse_add(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, 115, node, pr_val(r));
        } else if tt == 33 && pk(tokens, cp + 1) == 33 {
            r = parse_add(tokens, cp + 2, pool); cp = pr_pos(r); node = mk4(pool, 4, 116, node, pr_val(r));
        } else {
            done = 1;
        };
    };
    return pr(cp, node);
}

// bitwise tier — `&` `^` `|` between `<<>>` and `< >` so
// that `a & b == c` parses as `(a & b) == c` (Rust precedence).
// All three ops share one tier here for simplicity. tok_to_ir maps
// `&` (tok 82) → iop 13 (LLVM `and i64`), `|` (tok 65) → iop 14
// (LLVM `or i64`), and `^` (tok 94) → iop 15 (LLVM `xor i64`).
// Disambiguates from logical `&&`/`||` because the lexer emits
// distinct tokens 36/37 for those — never tt == 82/65 here.
#[manual_drop]
fn parse_bitwise(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_shift(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    let mut tt: i64 = pk(tokens, cp);
    while tt == 82 || tt == 65 || tt == 94 {
        r = parse_shift(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, tt, node, pr_val(r)); tt = pk(tokens, cp);
    };
    return pr(cp, node);
}
#[manual_drop]
fn parse_cmp(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_bitwise(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    let mut tt: i64 = pk(tokens, cp);
    while tt == 32 || tt == 33 || tt == 34 || tt == 35 {
        r = parse_bitwise(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, tt, node, pr_val(r)); tt = pk(tokens, cp);
    };
    return pr(cp, node);
}
#[manual_drop]
fn parse_eq(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_cmp(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 30 || pk(tokens, cp) == 31 {
        let op: i64 = pk(tokens, cp); r = parse_cmp(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}

#[manual_drop]
fn parse_and_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_eq(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 36 { r = parse_eq(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, 36, node, pr_val(r)); };
    return pr(cp, node);
}
#[manual_drop]
fn parse_or_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_and_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 37 { r = parse_and_expr(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, 37, node, pr_val(r)); };
    return pr(cp, node);
}

#[manual_drop]
fn parse_pipe_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_or_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r);
    let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 65 && pk(tokens, cp + 1) == 33 {
        let rp: i64 = cp + 2;
        if pk(tokens, rp) != 1 { return pr(rp, node); };
        let fname: str = pkv(tokens, rp);
        let rp2: i64 = rp + 1;
        let rp3: i64 = skip_angle_group(tokens, rp2);
        let mut piped_args: Vec<i32> = Vec::new();
        piped_args.push(node);
        if pk(tokens, rp3) == 50 {
            let mut ar: Vec<i32> = parse_args(tokens, rp3 + 1, pool);
            let alist: i64 = pr_val(ar);
            let ac: i64 = list_len(pool, alist);
            let mut ai: i64 = 0;
            while ai < ac {
                piped_args.push(list_get(pool, alist, ai));
                ai = ai + 1;
            };
            cp = pr_pos(ar);
        } else {
            cp = rp3;
        };
        node = mk3(pool, 7, fname, mk_list(pool, piped_args));
    };
    return pr(cp, node);
}

#[manual_drop]
fn parse_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // Lane 4 / F-002: recursive-descent depth limit. Pre-fix the parser
    // ran out of OS stack at ~3000-4000 nested `if`/`while`/`{`/`(`/`[`
    // levels and exited 127 (process killed) with no diagnostic. The
    // 1024 ceiling leaves generous headroom for legitimate code (no
    // hand-written program nests this deep) and bails cleanly with
    // PARSE-DEPTH-001 before the OS stack overflows. Counter is
    // tracked in a runtime-managed side table and reset at the
    // compile-file-mode driver entry.
    let v_d_pd001: i64 = __nucleor_parse_depth_inc();
    if v_d_pd001 > 1024 {
        let v_byte_pd001: i64 = tok_pos_at(tokens, pos);
        panic(str_concat("error[PARSE-DEPTH-001]: expression nesting too deep at byte ", str_concat(str_from_int(v_byte_pd001), str_concat(" (depth ", str_concat(str_from_int(v_d_pd001), " > 1024). Refactor the deeply-nested expression into helper bindings — `let t1 = a + b; let t2 = t1 + c;` — or split a large expression-tree across multiple statements.")))));
    };
    let result_pd001: Vec<i32> = parse_pipe_expr(tokens, pos, pool);
    __nucleor_parse_depth_dec();
    return result_pd001;
}

#[manual_drop]
fn parse_type(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    // Lane 4 / F-001 (Critical, SIGSEGV): pre-fix `let x: 1 + 1 = 5;`
    // hit a NULL string deref on the first call to `pkv(tokens, pos)`
    // (line `let name: i64 = pkv(tokens, pos);`) because integer-literal
    // tokens carry an i64 value, not a str pointer. Reject expression-
    // shaped input cleanly with PARSE-TYPE-001 BEFORE entering any of
    // the prefix-token branches that would also crash.
    let v_tt_pt001: i64 = pk(tokens, pos);
    let v_byte_pt001: i64 = tok_pos_at(tokens, pos);
    // Token kinds that legitimately START a type position:
    //   1   identifier  (most types)
    //   10  fn          (fn-pointer type)
    //   22  *           (raw ptr — defensive halt below)
    //   38  !           (never type — defensive halt below)
    //   50  (           (tuple/unit type)
    //   54  [           (array/slice type)
    //   56  for         (HRTB — defensive halt below)
    //   67  impl        (impl Trait — defensive halt below)
    //   73  const       (raw ptr `*const T`, surfaces via 22)
    //   82  &           (reference type)
    //   98  '           (lifetime — used after `&`, but never as the
    //                   leading token of a type itself; we still reject
    //                   for safety)
    if v_tt_pt001 != 1
        && v_tt_pt001 != 10
        && v_tt_pt001 != 22
        && v_tt_pt001 != 38
        && v_tt_pt001 != 50
        && v_tt_pt001 != 54
        && v_tt_pt001 != 56
        && v_tt_pt001 != 67
        && v_tt_pt001 != 82 {
        let v_what_pt001: str = if v_tt_pt001 == 2 { "integer literal" }
            else if v_tt_pt001 == 3 { "string literal" }
            else if v_tt_pt001 == 70 { "float literal" }
            else if v_tt_pt001 == 124 { "float literal" }
            else if v_tt_pt001 == 125 { "f32 literal" }
            else if v_tt_pt001 == 0 { "<EOF>" }
            else { tok_name(v_tt_pt001) };
        panic(str_concat("error[PARSE-TYPE-001]: expected a type, found ", str_concat(v_what_pt001, str_concat(" at byte ", str_concat(str_from_int(v_byte_pt001), ". Type positions accept type names (`i64`, `Vec<T>`, struct/enum names, etc.), not arbitrary expressions; if you meant to assign an expression, drop the type annotation: `let x: i64 = 1 + 1;` (with a real type) or `let x = 1 + 1;` (let inference fill in the type).")))));
    };
    if pk(tokens, pos) == 56 {
        halt_hrtb_not_supported();
    };
    if pk(tokens, pos) == 82 {
        let mut cp: i64 = pos + 1;
        let mut prefix: str = "&";
        // T2.5 (v0.2.351): skip optional lifetime annotation `'a` after `&`.
        // Treated as advisory — does not appear in the parsed type string.
        if pk(tokens, cp) == 98 { cp = cp + 1; };
        // clean halt for `&raw const T` / `&raw mut T` in type position.
        if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "raw") == 1 {
            print("ERROR: raw-pointer types `&raw const T` / `&raw mut T` are not in the V1 surface.");
            print("       Workaround: use `&T` or `&mut T`.");
            panic("v0.7.14: &raw type unsupported");
        };
        if pk(tokens, cp) == 12 { prefix = "&mut "; cp = cp + 1; };
        let mut tr: Vec<i32> = parse_type(tokens, cp);
        return pr(pr_pos(tr), str_concat(prefix, pr_val(tr)));
    };
    if pk(tokens, pos) == 54 {
        let mut tr: Vec<i32> = parse_type(tokens, pos + 1);
        let mut cp: i64 = pr_pos(tr);
        // v0.6.78 RFC V1.11
        //  canonical Rust slice type `&[T]` as fn-param type
        // pre-fix rejected with the wrong-class `error[NR020]: parse
        // error at byte K: expected ';', got ']'` because the array-
        // type parser only knew the `[T; N]` shape. Now accept the
        // bare `[T]` shape (no length) and resolve to `Vec<T>` —
        // Nucleor arrays are Vec internally, and `&[T]` thus resolves
        // to `&Vec<T>` which the type system already accepts. Slice
        // ABI (length-tagged base+len pair) is the v1 V1.5 ship; v0.6.78
        // is a translation-fidelity surface bridge.
        if pk(tokens, cp) == 55 {
            return pr(cp + 1, str_concat("Vec<", str_concat(pr_val(tr), ">")));
        };
        cp = expect_tok(tokens, cp, 43);
        let len_s: str = if pk(tokens, cp) == 2 { str_from_int(pkv(tokens, cp)) } else { pkv(tokens, cp) };
        cp = expect_tok(tokens, cp + 1, 55);
        return pr(cp, str_concat("[", str_concat(pr_val(tr), str_concat("; ", str_concat(len_s, "]")))));
    };
    if pk(tokens, pos) == 50 {
        let mut cp: i64 = pos + 1;
        let mut inner: str = "";
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if str_len(inner) > 0 { cp = expect_tok(tokens, cp, 44); inner = str_concat(inner, ", "); };
            let mut tr: Vec<i32> = parse_type(tokens, cp);
            cp = pr_pos(tr);
            inner = str_concat(inner, pr_val(tr));
        };
        return pr(cp + 1, str_concat("(", str_concat(inner, ")")));
    };
    // defensive halt: canonical Rust `impl Trait` return-
    // position type (`fn make_iter() -> impl Iterator<Item = i64>`)
    // pre-fix surfaced as wrong-class `error[NR020]: expected '{',
    // got identifier` because parse_type had no `impl` branch — the
    // outer fn-decl parser saw `impl Iterator<...>` after `->` and
    // expected the body's `{`. Halt cleanly with a workaround pointer
    // (use a concrete return type, or a `Box<dyn Trait>` once vtable
    // dispatch lands in v1.x).
    if pk(tokens, pos) == 67 {
        print("ERROR: `impl Trait` (return-position or argument-position trait-bound sugar) is not yet supported in Nucleor. Workaround: declare the concrete return type instead — for iterators, expose the Vec directly (`fn make_iter() -> Vec<i64>`); for closures, use a typed fn pointer (`fn cb() -> fn(i64) -> i64`); for trait-bound polymorphism, wait for vtable dispatch (v1.x trait-object substrate, sister to v0.6.91 `Box<dyn Trait>` halt).");
        panic("nucleor: `impl Trait` type position not yet supported (see ERROR diagnostic above)");
    };
    // v0.7.3 (defensive halt — raw pointer types `*const T` /
    // `*mut T`): canonical Rust raw-pointer type position
    // (`let p: *const i64 = ...;`, `fn read(p: *const i64)`)
    // pre-fix surfaced as wrong-class `NR020: parse_primary cannot
    // start expression at token kind 73` (the `const` keyword
    // following `*`) because parse_type had no `*` branch — the
    // outer parser saw `*` as the multiplication operator (token
    // 22) at type position. Halt cleanly with a workaround pointer
    // (use `&T` / `&mut T` borrow-references for safe code, or
    // store as i64 for FFI / unsafe-style transit).
    if pk(tokens, pos) == 22 {
        let v073_kind: str = if pk(tokens, pos + 1) == 73 { "const" } else if pk(tokens, pos + 1) == 12 { "mut" } else { "<expected const|mut>" };
        print(str_concat("ERROR: raw pointer type `*", str_concat(v073_kind, str_concat(" T` is not yet supported in Nucleor. Workaround: use `&T` / `&mut T` borrow-references for safe code; for FFI / unsafe transit, declare the param/binding as `i64` directly and the runtime ABI passes the pointer value through.")));
        panic(str_concat("nucleor: raw pointer type `*", str_concat(v073_kind, " T` not yet supported (see ERROR diagnostic above)")));
    };
    // defensive halt: canonical Rust never type `!`
    // (used for diverging fns `fn forever() -> !`, `panic!()`-only
    // bodies) pre-fix CRASHED the compiler with SIGSEGV (rc=139)
    // because parse_type had no token-38 (`!`) branch and fell
    // through to a name-walk that dereferenced a NULL str ptr.
    // This is a HARD crash, not a wrong-class diag — adopters
    // porting Rust code with diverging fns hit a compiler bug
    // before the fix. Halt cleanly with a workaround pointer
    // (use the unit type `()` or `i64` and `panic!()` in the body).
    if pk(tokens, pos) == 38 {
        print("ERROR: never type `!` (used for diverging fns `fn forever() -> !`, `panic!()`-only bodies, etc.) is not yet supported in Nucleor. Workaround: declare the return type as `()` (unit) or any concrete type the body never actually reaches — the body's `panic!()` / infinite loop terminates execution before the return-type contract matters. For loop-forever shape: `fn forever() -> () { loop { ... } }`.");
        panic("nucleor: never type `!` not yet supported (see ERROR diagnostic above)");
    };
    // v0.3.92/v0.4.112: trait object syntax `dyn Trait`.
    // Preserve the `dyn` marker so Box<dyn Trait> can be distinguished
    // from Box<Trait> during type checking.
    // consume any `+ Bound` / `+ 'lifetime` suffixes
    // (e.g. `dyn Write + Send`, `dyn Trait + Sync + 'static`).
    // Additional bounds are accepted and silently stripped — vtable dispatch
    // and Send/Sync enforcement are deferred to the v1.x trait-object ship.
    // Pre-fix: `&dyn Trait + Send` failed with NR020 "expected `,` got `+`".
    if pk(tokens, pos) == 1 && str_eq(pkv(tokens, pos), "dyn") == 1 {
        let mut tr: Vec<i32> = parse_type(tokens, pos + 1);
        let mut dyn_pos: i64 = pr_pos(tr);
        while pk(tokens, dyn_pos) == 20 {
            dyn_pos = dyn_pos + 1;
            if pk(tokens, dyn_pos) == 98 {
                dyn_pos = dyn_pos + 1;
            } else if pk(tokens, dyn_pos) == 1 {
                dyn_pos = dyn_pos + 1;
            };
        };
        return pr(dyn_pos, str_concat("dyn ", pr_val(tr)));
    };
    // fn-pointer type syntax `fn(T1, T2) -> R`. Nucleor stores
    // function pointers as i64, so we consume the syntactic shape and
    // return "i64" — the existing fn-pointer/closure dispatch already
    // handles i64-typed callable values. Pre-v0.3.83, `fn(i64) -> i64`
    // in a parameter type position cascaded into 26+ parse errors.
    if pk(tokens, pos) == 10 {
        let mut cp: i64 = pos + 1;
        // Expect `(`
        if pk(tokens, cp) == 50 {
            cp = cp + 1;
            // Skip args: each arg is `parse_type` (no name needed).
            // Walk paren-balanced to allow nested fn types.
            let mut depth: i64 = 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 50 { depth = depth + 1; };
                if pk(tokens, cp) == 51 { depth = depth - 1; };
                cp = cp + 1;
            };
            // Optional `-> R` return type
            if pk(tokens, cp) == 41 {
                cp = cp + 1;
                let mut tr: Vec<i32> = parse_type(tokens, cp);
                cp = pr_pos(tr);
            };
            cp = skip_effect_clause(tokens, cp);
        };
        return pr(cp, "i64");
    };
    let name: i64 = pkv(tokens, pos); let p2: i64 = pos + 1;
    if pk(tokens, p2) == 46 {
        // Rust stdlib namespace path auto-strip in type-annotation
        // position. `std::collections::HashMap<K,V>`, `core::option::Option<T>`,
        // `std::string::String`, `std::vec::Vec<T>`, `alloc::vec::Vec<T>`, etc.
        // Pre-v0.7.37: wrong-class NR020 at `::`. v0.7.37: halt + workaround.
        // Now: walk past all `Ident ::` segments to the final type name and
        // re-enter parse_type there, auto-stripping any namespace prefix depth.
        // Falls back to the v0.7.37 halt if the next segment is not an ident.
        let mut ns_pos: i64 = pos;
        while pk(tokens, ns_pos + 1) == 46 && pk(tokens, ns_pos + 2) == 1 {
            ns_pos = ns_pos + 2;
        };
        if ns_pos > pos { return parse_type(tokens, ns_pos); };
        let v0737_ns: str = name;
        print(str_concat("ERROR: Rust path type `", str_concat(v0737_ns, "::<rest>` in type-annotation position is not yet supported in Nucleor. Workaround: drop the namespace prefix and use the unqualified Nucleor type name directly — `std::collections::HashMap<K,V>` -> `HashMap<K,V>`, `std::string::String` -> `String` (or `str` for literals), `std::vec::Vec<T>` -> `Vec<T>`, `core::option::Option<T>` -> `Option<T>`, `core::result::Result<T,E>` -> `Result<T,E>`.")));
        panic(str_concat("nucleor: path type `", str_concat(v0737_ns, "::<rest>` not supported in type position (see ERROR diagnostic above)")));
    };
    let mut fixed_type_name: i64 = 0;
    if str_eq(name, "fixed") == 1 { fixed_type_name = 1; };
    if str_eq(name, "ufixed") == 1 { fixed_type_name = 1; };
    if fixed_type_name == 1 && pk(tokens, p2) == 32 {
        let mut cp: i64 = p2 + 1;
        let mut depth: i64 = 1;
        let mut inner_fixed: str = "";
        while depth > 0 && pk(tokens, cp) != 0 {
            let tt_fixed: i64 = pk(tokens, cp);
            if tt_fixed == 32 {
                depth = depth + 1;
                if depth > 1 { inner_fixed = str_concat(inner_fixed, "<"); };
            }
            else if tt_fixed == 33 {
                depth = depth - 1;
                if depth > 0 { inner_fixed = str_concat(inner_fixed, ">"); };
            }
            else if tt_fixed == 44 {
                inner_fixed = str_concat(inner_fixed, ", ");
            } else {
                let mut part_fixed: str = pkv(tokens, cp);
                if tt_fixed == 2 { part_fixed = str_from_int(pkv(tokens, cp)); };
                inner_fixed = str_concat(inner_fixed, part_fixed);
            };
            cp = cp + 1;
        };
        return pr(cp, str_concat(name, str_concat("<", str_concat(inner_fixed, ">"))));
    };
    if str_eq(name, "unit") == 1 && pk(tokens, p2) == 32 {
        let mut cp: i64 = p2 + 1;
        let mut inner: Vec<i32> = parse_type(tokens, cp);
        let base_t: str = pr_val(inner);
        cp = pr_pos(inner);
        let mut depth: i64 = 1;
        while depth > 0 && pk(tokens, cp) != 0 {
            if pk(tokens, cp) == 32 { depth = depth + 1; }
            else if pk(tokens, cp) == 33 { depth = depth - 1; };
            cp = cp + 1;
        };
        return pr(cp, base_t);
    };
    if pk(tokens, p2) == 32 {
        // Generic type: Name<T1, T2, ...>
        // T2.5 (v0.2.351): accept lifetime args alongside type args.
        // Lifetime args are skipped from the resulting type string —
        // `Vec<'a, T>` parses as `Vec<T>` since codegen doesn't see
        // lifetime info. Real lifetime threading lands in T2.5b.
        let mut cp: i64 = p2 + 1;
        let mut type_parts: Vec<i32> = Vec::new();
        let mut first_arg: i64 = 1;
        while pk(tokens, cp) != 33 && pk(tokens, cp) != 0 {
            if first_arg == 0 {
                cp = expect_tok(tokens, cp, 44);
                if pk(tokens, cp) == 33 { break; };
            };
            first_arg = 0;
            if pk(tokens, cp) == 98 {
                // Skip lifetime arg.
                cp = cp + 1;
            } else {
                let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
                type_parts.push(pr_val(tr));
            };
        };
        let n: i64 = vec_len(type_parts);
        if n == 0 { return pr(cp + 1, name); };
        let mut inner: str = vec_get(type_parts, 0);
        let mut tpi: i64 = 1;
        while tpi < n {
            inner = str_concat(inner, str_concat(", ", vec_get(type_parts, tpi)));
            tpi = tpi + 1;
        };
        return pr(cp + 1, str_concat(name, str_concat("<", str_concat(inner, ">"))));
    };
    return pr(p2, name);
}

#[manual_drop]
fn parse_generic_params(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    // pos points at '<', returns (pos_after_>, list of param name strings).
    // T2.5 (v0.2.351): accepts lifetime parameters (`'a`, `'static`, etc.)
    // alongside type parameters. Lifetime params get prepended with `'`
    // in the returned list so downstream consumers can distinguish them
    // (today no consumer does, but the marker is preserved for T2.5b).
    let mut cp: i64 = pos + 1;
    let mut params: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 33 && pk(tokens, cp) != 0 {
        if vec_len(params) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 33 { break; };
        };
        if pk(tokens, cp) == 98 {
            // Lifetime param — store as `'<name>` for traceability.
            params.push(str_concat("'", pkv(tokens, cp)));
        } else if pk(tokens, cp) == 1 {
            // Lane 1 audit fix (2026-05-08) — close F-015 (duplicate
            // type-param `<T, T>`) and F-016 (type-param shadowing a
            // primitive `<i64>`). Both pre-fix were silently accepted;
            // F-015 then bound the second occurrence shadowing the
            // first with no signal, F-016 swallowed `i64` as a
            // user-declared param and any later `i64` reference
            // resolved to it (per the substitution map) instead of
            // the primitive. Both are parse-time checks with cheap
            // O(N) lookups against the same params Vec we are about
            // to push into. Only fires for ordinary type-param tokens
            // (kind 1 identifiers); lifetime params (kind 98) are
            // namespaced by the `'` prefix above so name collision
            // with type params is structurally impossible. Cosmetic
            // const-generic params (kind 73) are halted earlier so
            // we never reach here for them.
            let v0508_pname: str = pkv(tokens, cp);
            // F-016: reject if the param name is a primitive type.
            if str_eq(v0508_pname, "i8") == 1 || str_eq(v0508_pname, "i16") == 1
               || str_eq(v0508_pname, "i32") == 1 || str_eq(v0508_pname, "i64") == 1
               || str_eq(v0508_pname, "u8") == 1 || str_eq(v0508_pname, "u16") == 1
               || str_eq(v0508_pname, "u32") == 1 || str_eq(v0508_pname, "u64") == 1
               || str_eq(v0508_pname, "usize") == 1 || str_eq(v0508_pname, "isize") == 1
               || str_eq(v0508_pname, "f16") == 1 || str_eq(v0508_pname, "f32") == 1
               || str_eq(v0508_pname, "f64") == 1 || str_eq(v0508_pname, "bf16") == 1
               || str_eq(v0508_pname, "bool") == 1 || str_eq(v0508_pname, "str") == 1
               || str_eq(v0508_pname, "char") == 1 || str_eq(v0508_pname, "void") == 1 {
                print(str_concat("error[TYP-041]: type parameter name `", str_concat(v0508_pname, "` collides with a built-in primitive type — Nucleor's monomorphic / i64-everywhere ABI substitutes type params at use-site, so a generic param shadowing `i64` (etc.) silently rebinds every later mention of the primitive within the generic's scope. Use a distinct name (convention: single uppercase letter `T`, `U`, `V`, or descriptive PascalCase like `Item`, `Key`).")));
                panic(str_concat("nucleor: type parameter shadows primitive: ", v0508_pname));
            };
            // F-015: reject if the same name is already in params.
            let mut v0508_dup_i: i64 = 0;
            while v0508_dup_i < vec_len(params) {
                let v0508_prior: str = vec_get(params, v0508_dup_i);
                if str_eq(v0508_prior, v0508_pname) == 1 {
                    print(str_concat("error[TYP-042]: duplicate type parameter name `", str_concat(v0508_pname, "` in generic parameter list. Rust E0403; Nucleor's substitution map keys on the param name so the second occurrence silently shadows the first at substitution time. Rename one of the params to a distinct identifier.")));
                    panic(str_concat("nucleor: duplicate type parameter: ", v0508_pname));
                };
                v0508_dup_i = v0508_dup_i + 1;
            };
            params.push(v0508_pname);
        } else if pk(tokens, cp) == 73 {
            // defensive halt: canonical Rust const-generic
            // params `<const N: usize>` (used in `struct Buf<const N:
            // usize> { data: [i64; N] }`, `fn id<const X: i32>() ->
            // i32 { X }`) pre-fix surfaced as wrong-class
            // `NR020: expected ',', got identifier` because
            // parse_generic_params treats `const` (token 73) as a
            // bare param name and then trips on the `:` + type that
            // follows. Halt cleanly with a workaround pointer
            // (use a regular fn-arg / a struct-decl-time const).
            print("ERROR: const-generic params `<const N: usize>` are not yet supported in Nucleor. Workaround: pass the value as a regular fn arg (`fn id(n: i32) -> i32 { n }`), or hard-code the value at the use site. For struct-level CT-params, see RFC-0034 first-pass (which uses `[N: usize]` syntax — different parser path, currently halted at v0.6.65).");
            panic("nucleor: const-generic param `<const N: ...>` not yet supported (see ERROR diagnostic above)");
        } else {
            params.push(pkv(tokens, cp));
        };
        cp = cp + 1;
        // trait-bound clause `<T: Addable>` / `<T: A + B>`.
        // Today
        // Nucleor's generics are type-passthrough — codegen emits one
        // monomorphic version regardless of bound — so the bound is
        // semantically a no-op at the IR level. Skip past `:` and
        // discard the bound expression up to the next `,` or `>`.
        // Parse-side trait-bound surface. A future bound-enforcing
        // pass would consume + record these bounds; for now they parse
        // cleanly and the binary behaves as if the bound were omitted
        // (already validated: `<T>(a: T, b: T) -> T { a + b }` works).
        if pk(tokens, cp) == 42 {
            cp = cp + 1; // skip ':'
            // capture each bound trait name as a `?<name>`
            // entry alongside the param name. Pre-v0.4.103 the bound
            // clause was an NR020 parse error; v0.4.103 parse-skipped
            // it (no signal); now we store it so a later type-check
            // pass can verify the trait exists / has at least one
            // impl. Multiple bounds (`<T: A + B>`) all get `?A`,
            // `?B` entries.
            // v0.7.69 (defensive halt — Rust opt-out trait bound
            // `?Sized`, used to relax the implicit Sized bound on
            // generic params so they accept DSTs like `str`/`[T]`).
            // Pre-fix the `?` token (97) was consumed silently by the
            // bound walker and the trailing `Sized` was stored as a
            // regular `?Sized` marker — visually identical to the
            // already-prefixed v0.4.130 storage convention but
            // semantically wrong: adopters expect Nucleor to relax
            // its Sized requirement, not silently keep it. Nucleor
            // has no DST substrate yet, so silent acceptance is a
            // wrong-class hazard. Halt cleanly and tell users the
            // bound is a no-op for now (everything is Sized).
            if pk(tokens, cp) == 97 {
                print("ERROR: opt-out trait bounds `?Sized` (and `?Trait` in general) are not yet supported in Nucleor. Workaround: drop the `?Sized` bound; Nucleor's monomorphic / i64-everywhere ABI assumes every generic param is sized today, so the bound is a no-op.");
                panic("nucleor: opt-out trait bound `?Sized` not yet supported (see ERROR diagnostic above)");
            };
            while pk(tokens, cp) != 33 && pk(tokens, cp) != 44 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 1 {
                    let bname: str = pkv(tokens, cp);
                    if str_len(bname) > 0 { params.push(str_concat("?", bname)); };
                };
                cp = cp + 1;
            };
        };
    };
    cp = cp + 1; // skip >
    return pr(cp, params);
}

#[manual_drop]
fn parse_let(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut is_mut: i64 = 0; let mut cp: i64 = pos;
    if pk(tokens, cp) == 12 { is_mut = 1; cp = cp + 1; };
    // tuple-destructuring `let (a, b) = (5, 7);`
    // is not yet supported. Pre-v0.3.81, the parser read `(` as a
    // var name and downstream code segfaulted with ACCESS_VIOLATION
    // on a garbage string offset. Detect the open-paren and emit a
    // clear diagnostic, then skip past the destructure-stmt to
    // recover so the rest of the program still parses.
    //  canonical Rust
    // `let Point { x, y } = p;` form pre-fix saw `Point` as the
    // binding name + `{ x, y }` as some unparsed garbage + `= p;`
    // as the init, surfacing as wrong-class `error[TYP-008]: binding
    // 'Point' declared without initializer (type-only)`. Halt at
    // parse-let with a clean diag pointing at the workaround (assign
    // p first, then access fields directly via `p.x`, `p.y`).
    // Detection: token kind 1 (identifier) starting with uppercase
    // followed by `{` (token 52). The simple `let foo { ... }`
    // (lowercase) shape is also caught here — no valid let-binding
    // starts with an ident-then-brace anyway.
    if pk(tokens, cp) == 1 && pk(tokens, cp + 1) == 52 {
        let lname_v651: str = pkv(tokens, cp);
        let lc0_v651: i64 = if str_len(lname_v651) > 0 { str_char_at(lname_v651, 0) } else { 0 };
        if lc0_v651 >= 65 && lc0_v651 <= 90 {
            print(str_concat("ERROR: struct destructure-in-let `let ", str_concat(lname_v651, " { ... } = expr;` is not yet supported in Nucleor. Workaround: bind the struct to a name, then access fields directly via field-access syntax — `let p: STRUCT = expr; let x: TYPE = p.x; let y: TYPE = p.y;`.")));
            panic("nucleor: struct destructure-in-let not yet supported (see ERROR diagnostic above)");
        };
    };
    if pk(tokens, cp) == 1 && pk(tokens, cp + 1) == 46 {
        let lname_v110: str = pkv(tokens, cp);
        print(str_concat("ERROR: enum or path pattern in `let` (e.g. `let ", str_concat(lname_v110, "::Variant(a, b) = expr;`) is not yet supported in Nucleor. Use `if let` or `match` to destructure enum variants. Pre-fix this reached parse_primary at `::` and surfaced as a wrong-class parser failure.")));
        diag_exit();
        panic(str_concat("nucleor: enum/path pattern-in-let `", str_concat(lname_v110, "::...` not yet supported (see ERROR diagnostic above)")));
    };
    // v0.7.81 (defensive halt — Rust array-destructure-in-let
    // `let [a, b, c] = [1, 2, 3];`). Pre-fix the parser read `[`
    // (token 54) as the binding name and the `,`-separated names
    // followed by `] = [...]` got partially recognized as an
    // assign-to-array-LHS expression. The LHS validator printed
    // "assignment to this LHS form is not supported" but the
    // build CONTINUED, emitted broken IR, and clang link failed
    // wrong-class `error[TYP-005]: undefined function 'a()'`
    // (the first array element became a phantom fn call). Halt
    // cleanly at parse-let with a workaround pointer. Sister to
    // v0.6.61 struct-destructure-in-let and v0.3.81 tuple-
    // destructure-in-let halts (same pattern-in-let family).
    if pk(tokens, cp) == 54 {
        print("ERROR: array destructure-in-let `let [a, b, c] = [1, 2, 3];` is not yet supported in Nucleor. Workaround: bind the array to a name, then index each slot — `let arr: [i64; 3] = [1, 2, 3]; let a: i64 = arr[0]; let b: i64 = arr[1]; let c: i64 = arr[2];`. Sister to v0.6.61 struct-destructure-in-let and v0.3.81 tuple-destructure-in-let halts.");
        panic("nucleor: array destructure-in-let not yet supported (see ERROR diagnostic above)");
    };
    // defensive halt: canonical Rust let-else shape
    // `let Some(v) = opt else { return; };` (Rust 1.65+) and the
    // sister ctor-pattern-in-let `let Some(v) = opt;` (no else)
    // pre-fix surfaced as wrong-class `NR020: parse_primary cannot
    // start an expression at token kind 14` (the `else` keyword)
    // OR similar errors after the parser reads `Some` as the binding
    // name and `(v)` as unparsed garbage. Halt cleanly with a
    // workaround pointer (use `if let` / `match`).
    if pk(tokens, cp) == 1 && pk(tokens, cp + 1) == 50 {
        let v095_lname: str = pkv(tokens, cp);
        if str_eq(v095_lname, "Some") == 1 || str_eq(v095_lname, "None") == 1 || str_eq(v095_lname, "Ok") == 1 || str_eq(v095_lname, "Err") == 1 {
            print(str_concat("ERROR: ctor-pattern in `let` (e.g. `let ", str_concat(v095_lname, str_concat("(v) = opt;`, `let-else: let ", str_concat(v095_lname, "(v) = opt else { ... };`)) is not yet supported in Nucleor. Workaround: use `if let` for the optional-extract pattern — `if let ")))));
            print(str_concat("       ", str_concat(v095_lname, "(v) = opt { ... } else { ... }`. For the let-else shape (early-return on None/Err), use `match`: `let v: T = match opt { ", str_concat(v095_lname, "(x) => x, _ => return ... };`.")))));
            panic(str_concat("nucleor: ctor-pattern-in-let `", str_concat(v095_lname, "(...)` not yet supported (see ERROR diagnostic above)")));
        };
    };
    if pk(tokens, cp) == 50 {
        // tuple-destructure-in-let. `let (a, b) = expr;` is
        // now accepted. Pre-v0.8.33 this panicked with a halt diagnostic
        // (v0.4.33 introduced the halt to replace the original silent-
        // miscompute where bindings never came into scope). Now: parse
        // the binding list, emit kind-85 (TupleDestructure) AST node.
        // lower_stmt kind-85 extracts each element via vec_get(rhs, i).
        // For anonymous tuple RHS `(e1, e2)` the kind-48 lowering already
        // builds a vec; for named tuple-struct or fn-return, the handle
        // is the struct vec. Both yield correct vec_get results.
        cp = cp + 1; // skip (
        let mut names_csv: str = "";
        let mut name_count85: i64 = 0;
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if name_count85 > 0 { cp = expect_tok(tokens, cp, 44); }; // skip ,
            if pk(tokens, cp) == 12 { cp = cp + 1; }; // skip mut (record-but-ignore for v0.8.33)
            let bname85: str = pkv(tokens, cp); cp = cp + 1;
            if name_count85 > 0 { names_csv = str_concat(names_csv, ","); };
            names_csv = str_concat(names_csv, bname85);
            name_count85 = name_count85 + 1;
        };
        cp = expect_tok(tokens, cp, 51); // skip )
        cp = expect_tok(tokens, cp, 40); // expect =
        let mut er85: Vec<i32> = parse_expr(tokens, cp, pool);
        cp = pr_pos(er85);
        if pk(tokens, cp) == 43 {
            cp = cp + 1;
        } else {
            let v_let_semi_byte85: i64 = tok_pos_at(tokens, cp);
            let v_let_semi_lc85: Vec<i32> = tokens_linecol_at_byte(tokens, v_let_semi_byte85);
            let v_let_semi_line85: i64 = vec_get(v_let_semi_lc85, 0);
            let v_let_semi_col85: i64 = vec_get(v_let_semi_lc85, 1);
            let v_let_semi_loc85: str = str_concat(str_from_int(v_let_semi_line85), str_concat(":", str_from_int(v_let_semi_col85)));
            panic(str_concat("error[PARSE-LET-SEMI]: expected `;` after let statement at line ", str_concat(v_let_semi_loc85, str_concat(" (byte ", str_concat(str_from_int(v_let_semi_byte85), str_concat("), got ", tok_name(pk(tokens, cp))))))));
        };
        let td_nid: i64 = mk3(pool, 85, names_csv, pr_val(er85));
        return pr(cp, td_nid);
    };
    let name_span: i64 = tok_pos_at(tokens, cp);
    // Lane 4 / F-054: keyword-as-binding silent accept. Pre-fix
    // `let fn: i64 = 5;` accepted any token kind for the binding name
    // (`pkv` reads the value field regardless of kind). For keyword
    // tokens the value field is whatever the lexer happened to put
    // there — usually 0 or a stale ptr — and the resulting let
    // binding had a garbage name. The IR emitted broken stores;
    // adopters got silent miscompiles. Reject any non-identifier
    // token at the binding-name slot.
    let v_let_name_tt: i64 = pk(tokens, cp);
    if v_let_name_tt != 1 {
        let v_let_name_byte: i64 = tok_pos_at(tokens, cp);
        let v_let_name_lc: Vec<i32> = tokens_linecol_at_byte(tokens, v_let_name_byte);
        let v_let_name_line: i64 = vec_get(v_let_name_lc, 0);
        let v_let_name_col: i64 = vec_get(v_let_name_lc, 1);
        let v_let_name_loc: str = str_concat(str_from_int(v_let_name_line), str_concat(":", str_from_int(v_let_name_col)));
        panic(str_concat("error[PARSE-LET-001]: expected identifier as `let` binding name at line ", str_concat(v_let_name_loc, str_concat(" (byte ", str_concat(str_from_int(v_let_name_byte), str_concat("), got ", tok_name(v_let_name_tt)))))));
    };
    let name: i64 = pkv(tokens, cp); cp = cp + 1;
    let mut tstr: str = "";
    if pk(tokens, cp) == 42 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); tstr = pr_val(tr); };
    // NUC-FEEDBACK-002 silent-miscompute defense.
    // `let v: Vec<f32> = …; v.push(1.0f32);` compiles cleanly today
    // but `let s: f32 = v[0]; f32_add(s, …)` produces 0 — the f32
    // bit pattern stored in the underlying i64 cell loses its type
    // tag through the vec_get → let-init chain, so the f32_add helper
    // operates on raw i64 storage. HIGH-blast for any ML/scientific
    // code reaching for narrow-float typed vectors. Real fix needs
    // expr_struct_type to propagate Vec element type through indexing
    // and let-init type propagation; until that lands, surface a hard
    // diagnostic for the broken types so adopters don't ship silently-
    // wrong tensor kernels.
    // `Vec<f64>` is intentionally NOT in the rejected set — it works
    // correctly today because i64 storage cells naturally hold f64 bit
    // patterns via direct memory load (both are 64-bit). Many existing
    // fixtures (t330-t349) depend on `Vec<f64>` and would break.
    // The narrow-float family (`f32`, `f16`, `bf16`, `f8e4m3`, `f8e5m2`)
    // are all <64-bit and need the conversion-helper round-trip.
    // Vec<f32> downgrade. Round-trip via f32_from_bits.
    // Vec<f16>/Vec<bf16>/Vec<f8e4m3>/Vec<f8e5m2> downgraded
    // -- runtime now has pack/unpack/display helpers for all narrow-
    // float types. See tests/fixtures/t463_vec_narrow_float_round_trip.nr
    // for the canonical round-trip patterns.
    let mut init_id: i64 = 0 - 1;
    if pk(tokens, cp) == 40 { let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool); cp = pr_pos(er); init_id = pr_val(er); };
    // bitwise ops (`&`, `|`, `^`) are now supported via
    // parse_bitwise (between parse_eq and parse_and_expr). The
    // v0.3.97 diag-only stub is no longer needed — parse_expr
    // consumes the full bitwise expression, so there's nothing
    // left for next_after_rhs to detect.
    if pk(tokens, cp) == 43 {
        cp = cp + 1;
    } else {
        let v_let_semi_byte: i64 = tok_pos_at(tokens, cp);
        let v_let_semi_lc: Vec<i32> = tokens_linecol_at_byte(tokens, v_let_semi_byte);
        let v_let_semi_line: i64 = vec_get(v_let_semi_lc, 0);
        let v_let_semi_col: i64 = vec_get(v_let_semi_lc, 1);
        let v_let_semi_loc: str = str_concat(str_from_int(v_let_semi_line), str_concat(":", str_from_int(v_let_semi_col)));
        panic(str_concat("error[PARSE-LET-SEMI]: expected `;` after let statement at line ", str_concat(v_let_semi_loc, str_concat(" (byte ", str_concat(str_from_int(v_let_semi_byte), str_concat("), got ", tok_name(pk(tokens, cp))))))));
    };
    let let_nid: i64 = mk5(pool, 20, name, is_mut, tstr, init_id);
    node_set_span(pool, let_nid, name_span);
    return pr(cp, let_nid);
}

#[manual_drop]
fn parse_const_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let name_span: i64 = tok_pos_at(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 42);
    let mut tr: Vec<i32> = parse_type(tokens, cp);
    cp = expect_tok(tokens, pr_pos(tr), 40);
    let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
    cp = pr_pos(er);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    let const_nid: i64 = mk4(pool, 50, name, pr_val(tr), pr_val(er));
    node_set_span(pool, const_nid, name_span);
    return pr(cp, const_nid);
}

#[manual_drop]
fn parse_type_alias_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 40);
    let mut tr: Vec<i32> = parse_type(tokens, cp);
    cp = pr_pos(tr);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk3(pool, 51, name, pr_val(tr)));
}

#[manual_drop]
fn parse_if(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // RFC-0016 sugar: `if let PATTERN = EXPR { THEN } else { ELSE }`
    // desugars to `match EXPR { PATTERN => { THEN }, _ => { ELSE } }`.
    // Supported patterns: Some(x), None, Ok(v), Err(e), EnumName::Variant[(b)].
    if pk(tokens, pos) == 11 {
        let mut ip: i64 = pos + 1;
        let mut ename: str = "";
        let mut vname: str = "";
        let mut binding: str = "";
        // v0.7.60 (defensive halt — paren-wrapped pattern in `if let` /
        // `while let`: `if let (Some(x)) = opt { ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: parse_primary cannot
        // start an expression at token kind 11`. Sister to v0.7.54
        // paren-wrapped variant-payload halt.
        if pk(tokens, ip) == 50 {
            print("ERROR: paren-wrapped pattern in `if let` / `while let` (e.g. `if let (Some(x)) = opt { ... }`) is not yet supported in Nucleor. Pre-v0.7.60 surfaced as wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 11` because the pattern dispatcher had no `(` branch.");
            print("       Workaround: drop the extra parens — `if let Some(x) = opt { ... }` is the canonical shape. Sister to v0.7.54 paren-wrapped variant-payload halt.");
            panic("nucleor: paren-wrapped pattern in if-let/while-let not yet supported (see ERROR diagnostic above)");
        };
        let pat_tt: i64 = pk(tokens, ip);
        if pat_tt == 1 && (str_eq(pkv(tokens, ip), "Some") == 1 || str_eq(pkv(tokens, ip), "None") == 1 || str_eq(pkv(tokens, ip), "Ok") == 1 || str_eq(pkv(tokens, ip), "Err") == 1) {
            vname = pkv(tokens, ip);
            if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
            else { ename = "Option"; };
            ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 {
                    binding = pkv(tokens, ip);
                    ip = ip + 1;
                    // defensive halt: nested pattern
                    // `if/while let Some(Some(v)) = opt` pre-fix
                    // surfaced as wrong-class `NR020: expected ')',
                    // got '('` because the parser reads the binding
                    // slot as a single ident.
                    if pk(tokens, ip) == 50 {
                        print(str_concat("ERROR: nested patterns in `if let` / `while let` (e.g. `if let ", str_concat(vname, str_concat("(Some(v)) = opt`) are not yet supported in Nucleor. Workaround: destructure in two steps — `if let ", str_concat(vname, "(inner) = outer { if let Some(v) = inner { ... } }`.")))));
                        panic(str_concat("nucleor: nested ctor pattern `", str_concat(vname, "(Some(...))` not yet supported (see ERROR diagnostic above)")));
                    };
                };
                ip = expect_tok(tokens, ip, 51);
            };
        } else if pat_tt == 1 && pk(tokens, ip + 1) == 46 {
            ename = pkv(tokens, ip);
            ip = expect_tok(tokens, ip + 1, 46);
            vname = pkv(tokens, ip); ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 { binding = pkv(tokens, ip); ip = ip + 1; };
                ip = expect_tok(tokens, ip, 51);
            };
        } else if pat_tt == 1 && str_eq(pkv(tokens, ip), "_") == 1 && pk(tokens, ip + 1) == 40 {
            // v0.7.80 (defensive halt — Rust wildcard pattern `_` in
            // `if let _ = expr` / `while let _ = expr`). Pre-fix the
            // `_` ident didn't match any of the recognized
            // pattern shapes (Some/None/Ok/Err, Type::Variant), the
            // if-let parser fell through with `ename` empty, and the
            // outer parser then hit `let` (token 11) at expression
            // start, surfacing as wrong-class
            // `error[NR020]: parse_primary cannot start an expression
            // at token kind 11`. Halt cleanly with a workaround
            // pointer (`let _ = expr;` already works as a discard;
            // the if-let `_` form is rare and equivalent to a plain
            // boolean `if true { ... }`). Sister to v0.7.50
            // or-pattern halt — same if-let pattern-shape family.
            print("ERROR: wildcard pattern `_` in `if let` / `while let` (e.g. `if let _ = expr { ... }`) is not yet supported in Nucleor. Pre-v0.7.80 the if-let pattern dispatcher had no `_` branch and fell through with no recognized pattern, so the outer parser then hit `let` (token 11) at expression start and emitted wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 11`.");
            print("       Workaround: this form is rare and equivalent to a plain `if true { ... }` (or `while true { ... }`); evaluate the expression on its own line via `let _ = expr;` (already supported as a discard) and then run the body unconditionally.");
            panic("nucleor: wildcard pattern `_` in if-let / while-let not yet supported (see ERROR diagnostic above)");
        };
        if str_len(ename) > 0 {
            // v0.7.50 (defensive halt — Rust or-pattern in `if let` /
            // `while let`: `if let Some(1) | Some(2) = opt`). Pre-fix
            // this surfaced as wrong-class `error[NR020]: expected '=',
            // got token 65` (token 65 = `|`) because the if-let parser
            // expects `=` immediately after the first pattern. Halt
            // cleanly with a separate-arm workaround for if-let, or use
            // a match for true or-pattern semantics.
            if pk(tokens, ip) == 65 {
                print("ERROR: or-patterns in `if let` / `while let` (e.g. `if let Some(1) | Some(2) = opt { ... }`) are not yet supported in Nucleor. Match-arm or-patterns (`match x { 1 | 2 => ... }`) already work — only the if-let / while-let form is missing.");
                print("       Workaround: use a `match` for true or-pattern semantics — `match opt { Some(1) | Some(2) => { /* hit */ }, _ => { /* miss */ } }`. Or check each variant separately — `if let Some(x) = opt { if x == 1 || x == 2 { ... } }`.");
                panic("nucleor: or-pattern in `if let` / `while let` not yet supported (see ERROR diagnostic above)");
            };
            // We have a pattern; parse `= EXPR { BODY } [else { BODY }]`
            ip = expect_tok(tokens, ip, 40); // `=`
            let v772_expr_start: i64 = ip;
            let mut sr: Vec<i32> = parse_expr(tokens, ip, pool);
            // v0.7.72 (defensive halt — Rust 2024 if-let chain:
            // `if let Some(x) = opt && cond { ... }`). Pre-fix
            // parse_expr greedily consumed `opt && cond` as a single
            // boolean expression and the desugared match scrutinee
            // referenced the pattern binding (`x`) in the chained
            // condition BEFORE the match-arm bound it — emitting an
            // undefined-name call that clang linked as wrong-class
            // `error[TYP-005]: undefined function 'x()'`. Detect by
            // scanning the consumed scrutinee tokens for `&&`
            // (token 36) — Rust 2024 if-let chains require pattern
            // + guard composition that Nucleor's desugar does not
            // yet model. Sister to v0.7.50 or-pattern halt (same
            // family of "Rust syntax tighter than Nucleor's if-let
            // desugar").
            let mut v772_scan: i64 = v772_expr_start;
            let v772_end: i64 = pr_pos(sr);
            let mut v772_has_chain: i64 = 0;
            while v772_scan < v772_end {
                if pk(tokens, v772_scan) == 36 { v772_has_chain = 1; v772_scan = v772_end; }
                else { v772_scan = v772_scan + 1; };
            };
            if v772_has_chain == 1 {
                print("ERROR: if-let / while-let chains (`if let PATTERN = EXPR && cond { ... }`) are not yet supported in Nucleor. Pre-v0.7.72 surfaced as wrong-class `error[TYP-005]: undefined function '<binding>()'` at clang link because parse_expr greedily consumed `EXPR && cond` as a single boolean scrutinee that referenced the pattern binding before the match-arm could bind it.");
                print("       Workaround: split the chain — `if let Some(x) = opt { if cond { ... } }` — or pull the condition into the existing match-arm form with a guard.");
                panic("nucleor: if-let chain (`if let ... = ... && cond`) not yet supported (see ERROR diagnostic above)");
            };
            let mut sp: i64 = expect_tok(tokens, pr_pos(sr), 52); // `{`
            let mut br: Vec<i32> = parse_stmts(tokens, sp, pool);
            sp = expect_tok(tokens, pr_pos(br), 53); // `}`
            let mut else_body: i64 = 0;
            if pk(tokens, sp) == 14 {
                sp = sp + 1;
                // v0.7.46 (defensive halt — `if let` chained `else if let`
                // / `else if`). Pre-fix `if let Some(x) = a { ... } else if
                // let Some(y) = b { ... }` surfaced as wrong-class
                // `error[NR020]: expected '{', got token 13` (token 13 =
                // `if`) because the if-let parser only knows the bare
                // `else { ... }` form. Halt cleanly with a nested-else
                // workaround pointer.
                if pk(tokens, sp) == 13 {
                    print("ERROR: `else if` (or `else if let`) chained after an `if let` is not yet supported in Nucleor. Pre-v0.7.46 surfaced as wrong-class `error[NR020]: expected '{', got token 13` (token 13 = `if`) because the if-let parser only knows the bare `else { ... }` form.");
                    print("       Workaround: nest the second `if`/`if let` inside the `else` block — `if let Some(x) = a { ... } else { if let Some(y) = b { ... } else { ... } }`. Each layer of nesting adds one `{ ... }` pair.");
                    panic("nucleor: `else if` after `if let` not yet supported (see ERROR diagnostic above)");
                };
                sp = expect_tok(tokens, sp, 52);
                let mut er: Vec<i32> = parse_stmts(tokens, sp, pool);
                sp = expect_tok(tokens, pr_pos(er), 53);
                else_body = pr_val(er);
            } else {
                let mut empty_stmts: Vec<i32> = Vec::new();
                else_body = mk_list(pool, empty_stmts);
            };
            // NUC-FEEDBACK silent-segfault guard.
            // Pre-fix `if let Some(x) = v.first()` (and .last() / .pop() /
            // vec_first / vec_last / vec_pop) silently segfaulted at
            // runtime: the helper returns a bare i64 (not Option<T>), the
            // match-arm dispatcher then called vec_get on the i64 value
            // treating it as an Option pointer, dereferencing garbage.
            // Adopters writing the canonical Rust idiom got a SIGSEGV
            // with no compile-time signal.
            // Real fix is to wrap these helpers in Option<T> at the
            // stdlib level (RFC-0024 Phase 4 territory). Until then,
            // halt the build with a clear diagnostic that names the
            // call and points to the workaround.
            if str_eq(ename, "Option") == 1 {
                let src_nid: i64 = pr_val(sr);
                let src_kind: i64 = node_kind(pool, src_nid);
                let mut bad_call: str = "";
                if src_kind == 8 {
                    let mname: str = node_field(pool, src_nid, 2);
                    if str_eq(mname, "first") == 1 || str_eq(mname, "last") == 1 || str_eq(mname, "pop") == 1 {
                        bad_call = str_concat(".", mname);
                    };
                };
                if src_kind == 7 {
                    let cname: str = node_field(pool, src_nid, 1);
                    if str_eq(cname, "vec_first") == 1 || str_eq(cname, "vec_last") == 1 || str_eq(cname, "vec_pop") == 1 {
                        bad_call = cname;
                    };
                };
                if str_len(bad_call) > 0 {
                    print(str_concat("ERROR: `if let Some(...) = ", str_concat(bad_call, "(...)` silently segfaults — the helper returns a bare i64, not Option<T>. Workaround: branch on length explicitly: `if vec_len(v) > 0 { let x: i64 = v[0]; ... } else { ... }`. Pinned for a future Option<T> wrapper ship (RFC-0024 Phase 4).")));
                    panic(str_concat("nucleor: if-let on non-Option-returning helper ", bad_call));
                };
            };
            // Build match arms: [PATTERN => then_body, _ => else_body]
            let mut arms: Vec<i32> = Vec::new();
            arms.push(mk6(pool, 39, ename, vname, binding, pr_val(br), 0));
            arms.push(mk6(pool, 39, "__wild", "", "", else_body, 0));
            return pr(sp, mk3(pool, 38, pr_val(sr), mk_list(pool, arms)));
        };
        // `let` not followed by a recognized pattern — fall through to plain if.
    };
    let mut cr: Vec<i32> = parse_expr(tokens, pos, pool);
    // same `=` vs `==` typo guard as parse_while_stmt.
    if pk(tokens, pr_pos(cr)) == 40 {
        print("ERROR: condition position has `=` (assignment) where `==` (equality) was expected. Did you mean `if x == y { ... }` instead of `if x = y { ... }`?");
        panic("nucleor: `=` in if-condition position (probably `==` typo)");
    };
    let mut cp: i64 = expect_tok(tokens, pr_pos(cr), 52);
    let mut tr: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(tr), 53);
    let mut else_id: i64 = 0 - 1;
    if pk(tokens, cp) == 14 {
        cp = cp + 1;
        if pk(tokens, cp) == 13 { cp = cp + 1;
            let mut elif: Vec<i32> = parse_if(tokens, cp, pool);
            let mut els: Vec<i32> = Vec::new(); els.push(pr_val(elif));
            else_id = mk_list(pool, els); cp = pr_pos(elif);
        } else {
            cp = expect_tok(tokens, cp, 52);
            let mut er: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(er), 53); else_id = pr_val(er);
        };
    };
    return pr(cp, mk4(pool, 23, pr_val(cr), pr_val(tr), else_id));
}

#[manual_drop]
fn parse_while_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // RFC-0016 sugar: `while let PATTERN = EXPR { BODY }` desugars to
    // `loop { match EXPR { PATTERN => { BODY }, _ => break } }`.
    // For v0.1.16: implement as a while-true with an embedded match
    // that breaks on wildcard arm.
    if pk(tokens, pos) == 11 {
        let mut ip: i64 = pos + 1;
        let mut ename: str = "";
        let mut vname: str = "";
        let mut binding: str = "";
        // v0.7.60 (defensive halt — paren-wrapped pattern in `if let` /
        // `while let`: `if let (Some(x)) = opt { ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: parse_primary cannot
        // start an expression at token kind 11`. Sister to v0.7.54
        // paren-wrapped variant-payload halt.
        if pk(tokens, ip) == 50 {
            print("ERROR: paren-wrapped pattern in `if let` / `while let` (e.g. `if let (Some(x)) = opt { ... }`) is not yet supported in Nucleor. Pre-v0.7.60 surfaced as wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 11` because the pattern dispatcher had no `(` branch.");
            print("       Workaround: drop the extra parens — `if let Some(x) = opt { ... }` is the canonical shape. Sister to v0.7.54 paren-wrapped variant-payload halt.");
            panic("nucleor: paren-wrapped pattern in if-let/while-let not yet supported (see ERROR diagnostic above)");
        };
        let pat_tt: i64 = pk(tokens, ip);
        if pat_tt == 1 && (str_eq(pkv(tokens, ip), "Some") == 1 || str_eq(pkv(tokens, ip), "None") == 1 || str_eq(pkv(tokens, ip), "Ok") == 1 || str_eq(pkv(tokens, ip), "Err") == 1) {
            vname = pkv(tokens, ip);
            if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
            else { ename = "Option"; };
            ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 {
                    binding = pkv(tokens, ip);
                    ip = ip + 1;
                    // defensive halt: nested pattern
                    // `if/while let Some(Some(v)) = opt` pre-fix
                    // surfaced as wrong-class `NR020: expected ')',
                    // got '('` because the parser reads the binding
                    // slot as a single ident.
                    if pk(tokens, ip) == 50 {
                        print(str_concat("ERROR: nested patterns in `if let` / `while let` (e.g. `if let ", str_concat(vname, str_concat("(Some(v)) = opt`) are not yet supported in Nucleor. Workaround: destructure in two steps — `if let ", str_concat(vname, "(inner) = outer { if let Some(v) = inner { ... } }`.")))));
                        panic(str_concat("nucleor: nested ctor pattern `", str_concat(vname, "(Some(...))` not yet supported (see ERROR diagnostic above)")));
                    };
                };
                ip = expect_tok(tokens, ip, 51);
            };
        } else if pat_tt == 1 && pk(tokens, ip + 1) == 46 {
            ename = pkv(tokens, ip);
            ip = expect_tok(tokens, ip + 1, 46);
            vname = pkv(tokens, ip); ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 { binding = pkv(tokens, ip); ip = ip + 1; };
                ip = expect_tok(tokens, ip, 51);
            };
        };
        if str_len(ename) > 0 {
            ip = expect_tok(tokens, ip, 40); // `=`
            let mut sr: Vec<i32> = parse_expr(tokens, ip, pool);
            let mut sp: i64 = expect_tok(tokens, pr_pos(sr), 52); // `{`
            let mut br: Vec<i32> = parse_stmts(tokens, sp, pool);
            sp = expect_tok(tokens, pr_pos(br), 53); // `}`
            // NUC-FEEDBACK silent-infinite-loop guard.
            // Pre-fix `while let Some(x) = stack.pop()` did NOT
            // segfault but DID infinite-loop printing 0s — pop()
            // returns a bare i64 (not Option), the match-arm
            // dispatcher's "Some" path always succeeded and the
            // loop never terminated. Mirrors the if-let guard at
            // line 1487+.
            if str_eq(ename, "Option") == 1 {
                let wsrc_nid: i64 = pr_val(sr);
                let wsrc_kind: i64 = node_kind(pool, wsrc_nid);
                let mut wbad: str = "";
                if wsrc_kind == 8 {
                    let wmname: str = node_field(pool, wsrc_nid, 2);
                    if str_eq(wmname, "first") == 1 || str_eq(wmname, "last") == 1 || str_eq(wmname, "pop") == 1 {
                        wbad = str_concat(".", wmname);
                    };
                };
                if wsrc_kind == 7 {
                    let wcname: str = node_field(pool, wsrc_nid, 1);
                    if str_eq(wcname, "vec_first") == 1 || str_eq(wcname, "vec_last") == 1 || str_eq(wcname, "vec_pop") == 1 {
                        wbad = wcname;
                    };
                };
                if str_len(wbad) > 0 {
                    print(str_concat("ERROR: `while let Some(...) = ", str_concat(wbad, "(...)` silently infinite-loops — the helper returns a bare i64, not Option<T>, so the Some arm always matches and the loop never terminates. Workaround: use a `while vec_len(v) > 0 { ... v.pop(); ... }` pattern. Pinned for a future Option<T> wrapper ship (RFC-0024 Phase 4).")));
                    panic(str_concat("nucleor: while-let on non-Option-returning helper ", wbad));
                };
            };
            // Build break statement (node kind 26)
            let break_stmt: i64 = mk2(pool, 26, 0);
            let mut break_stmts: Vec<i32> = Vec::new();
            break_stmts.push(break_stmt);
            // Match arms: [PATTERN => body, _ => break]
            let mut arms: Vec<i32> = Vec::new();
            arms.push(mk6(pool, 39, ename, vname, binding, pr_val(br), 0));
            arms.push(mk6(pool, 39, "__wild", "", "", mk_list(pool, break_stmts), 0));
            let match_node: i64 = mk3(pool, 38, pr_val(sr), mk_list(pool, arms));
            // Wrap match in a stmt list to be the loop body
            let mut loop_body: Vec<i32> = Vec::new();
            loop_body.push(mk3(pool, 25, match_node, 0));
            // True condition: literal 1
            let true_node: i64 = mk2(pool, 1, 1);
            return pr(sp, mk3(pool, 24, true_node, mk_list(pool, loop_body)));
        };
    };
    let mut cr: Vec<i32> = parse_expr(tokens, pos, pool);
    // NUC-FEEDBACK silent-miscompute close — detect `=` vs
    // `==` typo. Pre-fix `while x = 0 { ... }` printed a parse error
    // but silently continued, building a binary with broken IR.
    // Halt cleanly at parse time with a clear hint.
    if pk(tokens, pr_pos(cr)) == 40 {
        print("ERROR: condition position has `=` (assignment) where `==` (equality) was expected. Did you mean `while x == y { ... }` instead of `while x = y { ... }`?");
        panic("nucleor: `=` in while-condition position (probably `==` typo)");
    };
    let mut cp: i64 = expect_tok(tokens, pr_pos(cr), 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk3(pool, 24, pr_val(cr), pr_val(br)));
}

#[manual_drop]
fn parse_for_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos is after 'for', pointing at variable name
    //  canonical Rust
    // `for (k, v) in &map { ... }` and `for (i, x) in items.iter()
    // .enumerate() { ... }` pre-fix saw `(` (token 50) where the
    // parser expected an identifier, then `in` where it expected
    // some other token, surfacing as `error[NR020]: parse error at
    // byte N: expected token 57, got identifier` — wrong-class.
    // Halt at parse with a clean diag pointing at the workaround
    // (use a tuple binding via let after destructuring inside the
    // body). Forward-roadmap: full tuple-pattern parse in for-head.
    if pk(tokens, pos) == 50 {
        print("ERROR: tuple-destructuring patterns in `for` loop heads (e.g. `for (k, v) in &map { ... }`) are not yet supported in Nucleor. Workaround: bind a single name and destructure in the body — `for kv in &map { let k: KT = kv.0; let v: VT = kv.1; ... }`.");
        panic("nucleor: tuple-destructuring in `for` head not yet supported (see ERROR diagnostic above)");
    };
    // v0.7.27 (defensive halt — Rust ref-pattern in for-loop binding
    // position: `for &x in &v { ... }`, `for &mut x in &mut v { ... }`).
    // Pre-fix this surfaced as wrong-class `error[NR020]: parse error:
    // expected token 57 (`in`), got identifier` because parse_for_stmt
    // tried to read `&` as the binding name. Workaround: drop the `&`
    // — Nucleor's i64-everywhere ABI passes everything by value, so
    // `for x in &v` already binds the same observable shape.
    if pk(tokens, pos) == 82 {
        let mut ref_form: str = "&";
        if pk(tokens, pos + 1) == 12 { ref_form = "&mut "; };
        print(str_concat("ERROR: ref-pattern `", str_concat(ref_form, str_concat("<binding>` in a `for` loop binding position (e.g. `for ", str_concat(ref_form, "x in &v { ... }`) is not yet supported in Nucleor. Pre-v0.7.27 surfaced as wrong-class `error[NR020]: expected token 57 (in), got identifier` because parse_for_stmt tried to read `&` as the binding name.")))));
        print(str_concat("       Workaround: drop the `", str_concat(ref_form, "` — Nucleor's i64-everywhere ABI passes everything by value, so `for x in &v { ... }` already binds the same observable shape.")));
        panic(str_concat("nucleor: ref-pattern `", str_concat(ref_form, "<binding>` in `for` head not yet supported (see ERROR diagnostic above)")));
    };
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 57); // expect 'in'
    let mut sr: Vec<i32> = parse_expr(tokens, cp, pool);
    cp = pr_pos(sr);
    if pk(tokens, cp) == 58 {
        let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool); // end expr
        if node_kind(pool, pr_val(sr)) == 1 && node_kind(pool, pr_val(er)) == 1 {
            let rs_v110: i64 = node_field(pool, pr_val(sr), 1);
            let re_v110: i64 = node_field(pool, pr_val(er), 1);
            if rs_v110 > re_v110 {
                print(str_concat("warning[RANGE-001]: statically empty `for` range ", str_concat(str_from_int(rs_v110), str_concat("..", str_concat(str_from_int(re_v110), "`. The loop body will not execute; check the bound order or use an explicit descending loop.")))));
            };
        };
        cp = expect_tok(tokens, pr_pos(er), 52); // expect '{'
        let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
        cp = expect_tok(tokens, pr_pos(br), 53); // expect '}'
        return pr(cp, mk5(pool, 28, name, pr_val(sr), pr_val(er), pr_val(br)));
    };
    if pk(tokens, cp) == 96 {
        // ..= inclusive: synthesize end+1 expression so existing exclusive
        // for-loop codegen handles it. Wrap end in (end + 1).
        let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool);
        let one_node: i64 = mk2(pool, 1, 1);
        let plus_node: i64 = mk4(pool, 4, 20, pr_val(er), one_node);
        cp = expect_tok(tokens, pr_pos(er), 52);
        let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
        cp = expect_tok(tokens, pr_pos(br), 53);
        return pr(cp, mk5(pool, 28, name, pr_val(sr), plus_node, pr_val(br)));
    };
    cp = expect_tok(tokens, cp, 52); // expect '{'
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53); // expect '}'
    return pr(cp, mk4(pool, 49, name, pr_val(sr), pr_val(br)));
}

#[manual_drop]
fn parse_return_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    if pk(tokens, pos) == 43 { return pr(pos + 1, mk2(pool, 22, 0 - 1)); };
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(er);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk2(pool, 22, pr_val(er)));
}

#[manual_drop]
fn parse_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // Lane 4 / F-002: depth guard at statement boundary. `if a { if b
    // { ... } }` recurses through parse_stmts → parse_stmt → parse_if
    // → parse_stmts at each `if` level; the reproducer
    // `deep_if_4000.nr` exits 127 (stack overflow) without this guard.
    // Same 1024 ceiling as parse_expr; the side-table counter is shared
    // because `if cond { stmt }` consumes both expr-depth and stmt-depth
    // budget at every nest level.
    let v_d_stmt_pd001: i64 = __nucleor_parse_depth_inc();
    if v_d_stmt_pd001 > 1024 {
        let v_byte_stmt_pd001: i64 = tok_pos_at(tokens, pos);
        panic(str_concat("error[PARSE-DEPTH-001]: statement nesting too deep at byte ", str_concat(str_from_int(v_byte_stmt_pd001), str_concat(" (depth ", str_concat(str_from_int(v_d_stmt_pd001), " > 1024). Refactor deeply-nested control flow into helper fns or use a flat `match`/`if-else` chain.")))));
    };
    let result_stmt_pd001: Vec<i32> = parse_stmt_inner(tokens, pos, pool);
    __nucleor_parse_depth_dec();
    return result_stmt_pd001;
}

#[manual_drop]
fn parse_stmt_inner(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let tt: i64 = pk(tokens, pos);
    // v0.7.77 (defensive halt — Rust 1.59+ destructuring assignment
    // `(a, b) = (1, 2);` / `[a, b] = [1, 2];` to already-bound
    // bindings). Pre-fix `(a, b) = (1, 2);` parsed `(a, b)` as a
    // parenthesized tuple expression, then expected `;` or an op
    // and got `=`. The current parser silently treated this as a
    // tail expression with no-op semantics — `a` and `b` remained
    // their previous values, producing a SILENT MISCOMPUTE (probe
    // verified: rc=0 instead of expected 1020). Detect by scanning
    // ahead for `)` then `=` immediately after a `(ident, ident, ...)`
    // shape and halt with a workaround pointer (assign each binding
    // separately).
    if tt == 50 {
        let mut v777_cp: i64 = pos + 1;
        let mut v777_depth: i64 = 1;
        let mut v777_only_idents_commas: i64 = 1;
        let mut v777_comma_count: i64 = 0;
        while v777_depth > 0 && v777_cp < vec_len(tokens) && pk(tokens, v777_cp) != 0 {
            let v777_tt: i64 = pk(tokens, v777_cp);
            if v777_tt == 50 { v777_depth = v777_depth + 1; v777_only_idents_commas = 0; }
            else if v777_tt == 51 { v777_depth = v777_depth - 1; }
            else if v777_tt == 1 { v777_cp = v777_cp; }
            else if v777_tt == 44 { if v777_depth == 1 { v777_comma_count = v777_comma_count + 1; }; }
            else { v777_only_idents_commas = 0; };
            v777_cp = v777_cp + 1;
        };
        if v777_depth == 0 && v777_only_idents_commas == 1 && v777_comma_count >= 1 && pk(tokens, v777_cp) == 40 {
            print("ERROR: destructuring assignment to a tuple-LHS (e.g. `(a, b) = (1, 2);` to already-bound `mut a` / `mut b`) is not yet supported in Nucleor. Pre-v0.7.77 the `(a, b)` was parsed as a parenthesized tuple expression and the trailing `=` was silently dropped, producing a SILENT MISCOMPUTE — `a` and `b` kept their previous values without diagnostic.");
            print("       Workaround: assign each binding on its own line — `a = 1; b = 2;` — or use temporaries if the RHS values are computed and you need pre-swap semantics.");
            panic("nucleor: destructuring assignment to tuple-LHS not yet supported (see ERROR diagnostic above)");
        };
    };
    if tt == 11 { return parse_let(tokens, pos + 1, pool); };
    if tt == 52 { let mut r: Vec<i32> = parse_passthrough_block_expr(tokens, pos, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 13 { let mut r: Vec<i32> = parse_if(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 15 { let mut r: Vec<i32> = parse_while_stmt(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 1 {
        // v0.7.77 (defensive halt — Rust unstable `yield <expr>;`,
        // used in nightly generators / coroutines). Pre-fix `yield`
        // lexed as a regular ident and was parsed as a fn call to
        // `yield(<expr>)`, surfacing as wrong-class
        // `error[TYP-005]: undefined function 'yield()'` at clang
        // link. Halt cleanly when `yield` appears at statement
        // start. Sister to v0.7.71 `async fn` halt — same nightly /
        // unstable surface, same silent-strip-then-late-fail audit
        // class. Token 1 (ident) lookahead, restricted by pkv name
        // so user fns named `yield` keep working only via raw-ident
        // (which is itself halted at v0.7.75).
        if str_eq(pkv(tokens, pos), "yield") == 1 {
            print("ERROR: `yield <expr>;` (Rust nightly generator / coroutine syntax) is not yet supported in Nucleor. Workaround: model the cooperative-step pattern with explicit state (e.g., a struct holding a `step: i64` field plus a `next()` method that switches on step), or use the existing thread/queue substrate (RFC-0007 SPSC/MPSC) for true producer/consumer flow.");
            panic("nucleor: `yield` statement not yet supported (see ERROR diagnostic above)");
        };
        // `loop` is a contextual keyword. When the next token
        // is `{`, recognise the `loop { BODY }` stmt-form (which
        // desugars to `while true { BODY }`); otherwise let the
        // identifier path handle it. Use a nested if to ensure pkv is
        // only dereferenced when tt is the identifier kind.
        if str_eq(pkv(tokens, pos), "loop") == 1 {
            if pk(tokens, pos + 1) == 52 {
                let mut cp_l: i64 = expect_tok(tokens, pos + 1, 52);
                let mut br_l: Vec<i32> = parse_stmts(tokens, cp_l, pool);
                cp_l = expect_tok(tokens, pr_pos(br_l), 53);
                if pk(tokens, cp_l) == 43 { cp_l = cp_l + 1; };
                let true_node_l: i64 = mk2(pool, 1, 1);
                return pr(cp_l, mk3(pool, 24, true_node_l, pr_val(br_l)));
            };
        };
        if str_eq(pkv(tokens, pos), "import") == 1 {
            panic(str_concat("error[PARSE-IMPORT-LOCAL]: `import` directives are only valid at module scope and must use a quoted path. Local `import` at byte ", str_concat(str_from_int(tok_pos_at(tokens, pos)), " is not a statement; move it to the top level as `import \"path.nr\";`.")));
        };
    };
    if tt == 84 {
        // `loop { BODY }` legacy kw branch — kept as belt-and-suspenders
        // since classify_kw no longer produces token 84 for loop in v0.3.141,
        // this is dead code in stage B+ but harmless.
        let mut cp: i64 = expect_tok(tokens, pos + 1, 52);
        let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
        cp = expect_tok(tokens, pr_pos(br), 53);
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        let true_node: i64 = mk2(pool, 1, 1);
        return pr(cp, mk3(pool, 24, true_node, pr_val(br)));
    };
    if tt == 56 { let mut r: Vec<i32> = parse_for_stmt(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 63 { let mut r: Vec<i32> = parse_match_stmt(tokens, pos + 1, pool, tok_pos_at(tokens, pos)); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    // removed dead `tt == 76` branch (restricts) — see
    // classify_kw notes. Same dead-code pattern as the v0.3.138
    // scope/spawn removal below.
    // removed dead `tt == 80 || tt == 81` branch (the
    // `scope { … }` / `spawn { … }` passthrough-block form). The
    // surrounding kw classifications were dropped — see classify_kw
    // for the rationale (silent-miscompute hazard for user fns named
    // `scope` or `spawn`).
    if tt == 16 { return parse_return_stmt(tokens, pos + 1, pool); };
    if tt == 18 {
        let mut cp: i64 = pos + 1;
        //  canonical Rust
        // `let r = loop { break 42; };` form pre-fix silently dropped
        // the value — `break` parsed bare (no value), then `42;`
        // became a separate stmt that either tail-expr'd the loop
        // body (wrong semantics) or was dropped. Currently halts with
        // the wrong-class NR024 (`'break' outside any loop` — even
        // when the break IS inside a loop because the value-form
        // confused the lookahead). Halt at parse with a clean diag
        // pointing at the workaround. Forward-roadmap: full break-
        // with-value lowering is the v1 loop-as-expression ship.
        let next_tok: i64 = pk(tokens, cp);
        if next_tok != 43 && next_tok != 53 && next_tok != 0 && next_tok != 41 {
            print("ERROR: `break` with a value (`break <expr>;` or `break <expr>` as last stmt of a loop body) is not yet supported in Nucleor. Workaround: bind the result via a mutable outer variable (`let mut r: i64 = 0; loop { ... r = 42; break; }`); the loop-as-expression form will land in a future RFC.");
            panic("nucleor: break-with-value not yet supported (see ERROR diagnostic above)");
        };
        if next_tok == 43 { cp = cp + 1; };
        return pr(cp, mk2(pool, 26, 0));
    };
    if tt == 19 { let mut cp: i64 = pos + 1; if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, mk2(pool, 27, 0)); };
    // v0.7.47 (defensive halt — Rust local type alias `type Foo = Bar;`
    // inside a fn body). Pre-fix this surfaced as wrong-class
    // `error[NR020]: parse_primary cannot start an expression at token
    // kind 74` because parse_stmt fell through to parse_expr which has
    // no `type` branch. Nucleor supports module-level type aliases fine
    // (parse_program dispatches kind-74 to parse_type_alias_decl) but
    // the fn-body statement parser never saw the keyword.
    // Workaround: hoist the type alias to module scope (just outside
    // any fn body) — module-level `type Foo = Bar;` works cleanly.
    if tt == 74 {
        let v747_alias_name: str = if pk(tokens, pos + 1) == 1 { pkv(tokens, pos + 1) } else { "<Alias>" };
        print(str_concat("ERROR: local type alias `type ", str_concat(v747_alias_name, " = ...;` inside a fn body is not yet supported in Nucleor. Workaround: hoist the alias to module scope — place `type ")));
        print(str_concat(v747_alias_name, str_concat(" = ...;` above all fn definitions at the top level of the file; module-level type aliases work cleanly.")));
        panic("nucleor: local type alias in fn body not yet supported (see ERROR diagnostic above)");
    };
    // v0.7.55 (defensive halt — Rust local `const`/`static` inside a fn
    // body). Pre-fix `fn h() { const N: i64 = 5; ... }` surfaced as
    // wrong-class `error[NR020]: parse_primary cannot start an
    // expression at token kind 73` (or token 42 for static — different
    // tokenization paths). Module-level const/static work — Nucleor's
    // const ships, static is forward-roadmap (see v0.6.21 halt). Sister
    // to v0.7.47 local-type-alias halt.
    if tt == 73 {
        let v755_const_name: str = if pk(tokens, pos + 1) == 1 { pkv(tokens, pos + 1) } else { "<NAME>" };
        print(str_concat("ERROR: local `const ", str_concat(v755_const_name, ": T = ...;` inside a fn body is not yet supported in Nucleor. Workaround: hoist the const to module scope — place `const ")));
        print(str_concat(v755_const_name, str_concat(": T = ...;` above all fn definitions at the top level of the file; module-level consts work cleanly. Or use a regular `let` binding (`let ", str_concat(v755_const_name, ": T = ...;`) for fn-local constant values — Nucleor's let is statically-scoped and the const-vs-let distinction is mostly about top-level visibility. Sister to v0.7.47 local-type-alias halt.")))));
        panic("nucleor: local const in fn body not yet supported (see ERROR diagnostic above)");
    };
    // v0.7.56 (defensive halt — Rust local `static` inside a fn body).
    // The lexer emits `static` as a plain identifier (token 1), so this
    // catches the form `static NAME: TYPE = ...;` at stmt-start by
    // checking ident "static" followed by another ident + `:`.
    // Pre-fix this surfaced as wrong-class `error[NR020]: parse_primary
    // cannot start an expression at token kind 42` (the `:` after the
    // name) because parse_expr's identifier branch consumed `static`,
    // then saw `NAME` and tried to keep parsing. Sister to v0.7.55
    // local-const halt and v0.6.21 module-scope static halt.
    if tt == 1 && str_eq(pkv(tokens, pos), "static") == 1 && pk(tokens, pos + 1) == 1 && pk(tokens, pos + 2) == 42 {
        let v756_static_name: str = pkv(tokens, pos + 1);
        print(str_concat("ERROR: local `static ", str_concat(v756_static_name, ": T = ...;` inside a fn body is not yet supported in Nucleor. Pre-v0.7.56 surfaced as wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 42` because the lexer treats `static` as a plain identifier and parse_expr tried to continue the expression after it.")));
        print(str_concat("       Workaround: use a regular `let ", str_concat(v756_static_name, ": T = ...;` binding for fn-local mutable state. Module-level `static` items are also forward-roadmap (see v0.6.21 halt) — for shared global state today, use a top-level `const` or a Vec/Cell-based wrapper. Sister to v0.7.55 local-const halt.")));
        panic("nucleor: local static in fn body not yet supported (see ERROR diagnostic above)");
    };
    // v0.7.59 (defensive halt — Rust local fn declaration inside a fn
    // body / match arm block: `fn outer() { fn inner() { ... } ... }`).
    // Pre-fix this surfaced as wrong-class `error[NR020]: parse_primary
    // cannot start an expression at token kind 10` because parse_stmt
    // had no `fn` branch and parse_expr also has no `fn` branch.
    // Rust supports nested fn declarations (no closure-capture; just
    // a name-scoped fn), but Nucleor's parser dispatches `fn` only at
    // module scope. Sister to v0.7.47/55/56 (local-type-alias / -const
    // / -static halts).
    if tt == 10 {
        let v759_fn_name: str = if pk(tokens, pos + 1) == 1 { pkv(tokens, pos + 1) } else { "<inner>" };
        print(str_concat("ERROR: local fn declaration `fn ", str_concat(v759_fn_name, "(...) -> RetType { ... }` inside a fn body or match-arm block is not yet supported in Nucleor. Pre-v0.7.59 surfaced as wrong-class `error[NR020]: parse_primary cannot start an expression at token kind 10` because the fn-body statement parser had no `fn` branch.")));
        print(str_concat("       Workaround: hoist the fn to module scope (just outside the enclosing fn) — module-level fns work cleanly and don't capture any outer-scope bindings, which matches Rust's local-fn semantics (Rust local fns also DON'T capture; they're just name-scoped). For closure-style capture-the-environment behavior, use Nucleor's `|args| body` closure literals instead. Sister to v0.7.47 local-type-alias / v0.7.55 local-const / v0.7.56 local-static halts.")));
        panic(str_concat("nucleor: local fn declaration `fn ", str_concat(v759_fn_name, "` inside fn body / match-arm block not yet supported (see ERROR diagnostic above)")));
    };
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(er);
    if pk(tokens, cp) == 40 {
        let mut vr: Vec<i32> = parse_expr(tokens, cp + 1, pool);
        cp = pr_pos(vr);
        // reject chained assignment `a = b = c`. Nucleor (like
        // Rust) does not treat assignment as an expression that yields
        // a value, so `a = b = 5` would parse as `a = b` followed by
        // a stray `= 5` that the recovery loop silently dropped --
        // adopters got `a == 0, b == 0` instead of `a == 5, b == 5`.
        // Catch the trailing `=` after the RHS expression and panic
        // with NR023 before the broken stmt makes it into the AST.
        if pk(tokens, cp) == 40 {
            panic("error[NR023]: chained assignment `a = b = c` is not supported in Nucleor — assignment is a statement, not an expression. Workaround: split into two statements — `b = c; a = b;` — which makes the order of evaluation explicit.");
        };
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        return pr(cp, mk3(pool, 21, pr_val(er), pr_val(vr)));
    };
    // compound assignment desugar. `x += y` → `x = x + y`,
    // and likewise for `-=` (111→21), `*=` (112→22), `/=` (113→23),
    // `%=` (114→24). LHS AST node is shared between the assign LHS and
    // the desugared binop LHS; this is safe because pool nodes are
    // immutable after creation and the lowering walks each AST exactly
    // once. For LHS forms with side effects (e.g. method calls in
    // future expansions), a real Get-Modify-Set lowering would be
    // required; today only var-ref / field-access / index LHS forms
    // are syntactically allowed, all of which are pure.
    let assign_tok: i64 = pk(tokens, cp);
    if assign_tok == 110 || assign_tok == 111 || assign_tok == 112 || assign_tok == 113 || assign_tok == 114
       || assign_tok == 117 || assign_tok == 118 || assign_tok == 119 || assign_tok == 120 || assign_tok == 121 {
        let mut vr: Vec<i32> = parse_expr(tokens, cp + 1, pool);
        cp = pr_pos(vr);
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        let mut bin_op: i64 = 20;
        if assign_tok == 110 { bin_op = 20; };
        if assign_tok == 111 { bin_op = 21; };
        if assign_tok == 112 { bin_op = 22; };
        if assign_tok == 113 { bin_op = 23; };
        if assign_tok == 114 { bin_op = 24; };
        // bitwise / shift compound assigns. Map to the
        // raw binop tokens so the existing tok_to_ir + parse_*
        // tier do the right thing at lowering — `&=` → `&` (82),
        // `|=` → `|` (65), `^=` → `^` (94), `<<=` → `<<` (115),
        // `>>=` → `>>` synthesized at lower-time as token 116.
        if assign_tok == 117 { bin_op = 82; };
        if assign_tok == 118 { bin_op = 65; };
        if assign_tok == 119 { bin_op = 94; };
        if assign_tok == 120 { bin_op = 115; };
        if assign_tok == 121 { bin_op = 116; };
        let rhs_node: i64 = mk4(pool, 4, bin_op, pr_val(er), pr_val(vr));
        return pr(cp, mk3(pool, 21, pr_val(er), rhs_node));
    };
    // postfix `++` / `--` desugar. `x++;` → `x = x + 1;`
    // `x--;` → `x = x - 1;`. Token 130 = `++`, token 131 = `--`.
    // Equivalent to `x += 1` / `x -= 1` but using the C-style postfix
    // form. The return-value of postfix-increment (old value) is NOT
    // supported — only the statement form (discard result) is accepted,
    // which is the 99% use case when porting C/C++ code to Nucleor.
    if assign_tok == 130 || assign_tok == 131 {
        cp = cp + 1;
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        let inc_op: i64 = if assign_tok == 130 { 20 } else { 21 };
        let one_v846: i64 = mk2(pool, 1, 1);
        let rhs_v846: i64 = mk4(pool, 4, inc_op, pr_val(er), one_v846);
        return pr(cp, mk3(pool, 21, pr_val(er), rhs_v846));
    };
    let mut had_semi: i64 = 0;
    if pk(tokens, cp) == 43 { cp = cp + 1; had_semi = 1; }
    else if pk(tokens, cp) != 53 && pk(tokens, cp) != 51 && pk(tokens, cp) != 55 && pk(tokens, cp) != 44 && pk(tokens, cp) != 0 {
        let stmt_expr_kind: i64 = node_kind(pool, pr_val(er));
        let next_stmt_tt: i64 = pk(tokens, cp);
        let next_starts_expr: i64 = if next_stmt_tt == 1 || next_stmt_tt == 2 || next_stmt_tt == 3 || next_stmt_tt == 50 { 1 } else { 0 };
        if (stmt_expr_kind == 1 || stmt_expr_kind == 2 || stmt_expr_kind == 3 || stmt_expr_kind == 71 || stmt_expr_kind == 72 || stmt_expr_kind == 73) && next_starts_expr == 1 {
            panic(str_concat("error[PARSE-STMT-SEMI]: expected `;` between statements at byte ", str_concat(str_from_int(tok_pos_at(tokens, cp)), str_concat(", got ", tok_name(next_stmt_tt)))));
        };
    };
    return pr(cp, mk3(pool, 25, pr_val(er), had_semi));
}

#[manual_drop]
fn parse_stmts(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut items: Vec<i32> = Vec::new(); let mut cp: i64 = pos;
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        let mut r: Vec<i32> = parse_stmt(tokens, cp, pool); items.push(pr_val(r)); cp = pr_pos(r);
    };
    return pr(cp, mk_list(pool, items));
}

#[manual_drop]
fn parse_fn_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    // Optional generic params: fn name<T, U>(...)
    // track gparams as Vec<i32> through where-clause processing
    // so where-clause bounds can splice ?Trait markers into the same list
    // that lower_fn reads — closes the where-clause sister gap of v0.5.31
    // Track Y. mk_list at the end of the fn just before the return.
    let mut gparams_vec: Vec<i32> = Vec::new();
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr);
        gparams_vec = pr_val(gr);
    };
    if pk(tokens, cp) == 54 { cp = skip_compile_time_params(tokens, cp); };
    cp = expect_tok(tokens, cp, 50); // (
    let mut params: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
        if vec_len(params) > 0 { cp = expect_tok(tokens, cp, 44); };
        // v0.7.39 (defensive halt — Rust pattern-destructure in fn
        // parameter: `fn h((a, b): (i64, i64))`, `fn h(P { x, y }: P)`).
        // Pre-fix this surfaced as wrong-class `error[NR020]: expected
        // ':', got identifier` because the param parser tried to read
        // `(` (token 50) or `{` (52) as the binding name. Workaround:
        // bind a single name and destructure inside the body — sister
        // to v0.6.59 tuple-destructure-in-for-head halt.
        if pk(tokens, cp) == 50 || pk(tokens, cp) == 52 {
            print("ERROR: pattern-destructure in fn parameter (e.g. `fn h((a, b): (i64, i64))`, `fn h(P { x, y }: P)`) is not yet supported in Nucleor. Pre-v0.7.39 this surfaced as wrong-class `error[NR020]: expected ':', got identifier` because the param parser swallowed the opening `(` / `{` as the binding name.");
            print("       Workaround: bind a single name and destructure inside the body — `fn h(p: (i64, i64)) -> i64 { let a: i64 = p.0; let b: i64 = p.1; ... }` or `fn h(p: P) -> i64 { let x: i64 = p.x; let y: i64 = p.y; ... }`. Sister to v0.6.59 tuple-destructure-in-for-head halt.");
            panic("nucleor: pattern-destructure in fn parameter not yet supported (see ERROR diagnostic above)");
        };
        // v0.7.75 (defensive halt — Rust `fn f(mut x: T)` mut-binding
        // in fn parameter). Pre-fix the `mut` ident landed in the
        // pn-binding slot and the `x` that followed pushed `:` to a
        // position where `parse_type` expected one — surfacing as
        // wrong-class `error[NR020]: expected ':', got identifier`.
        // The shape is common in adopter Rust code (rebinding the
        // parameter for in-place mutation in the body); Nucleor's
        // existing `let mut x: T = arg;` body-form is the canonical
        // workaround. Caught BEFORE the binding name is read so the
        // diag is precise rather than the generic NR020.
        if pk(tokens, cp) == 12 {
            print("ERROR: `mut` qualifier on fn parameter (e.g. `fn inc(mut x: i64) -> i64 { x = x + 1; ... }`) is not yet supported in Nucleor. Workaround: rebind in the body — `fn inc(x: i64) -> i64 { let mut x: i64 = x; x = x + 1; return x; }`.");
            panic("nucleor: `mut` qualifier on fn parameter not yet supported (see ERROR diagnostic above)");
        };
        let pn_byte: i64 = tok_pos_at(tokens, cp);
        let pn: i64 = pkv(tokens, cp);
        // v0.7.49 (defensive halt — typeless default-arg form
        // `fn h(x: i64, y = 5)`). Sister to v0.7.38 (typed
        // default-arg `n: i64 = 1`); this catches the no-type variant
        // before the colon expector fires. Pre-fix this surfaced as
        // wrong-class `error[NR020]: expected ':', got '='`.
        if pk(tokens, cp + 1) == 40 {
            print(str_concat("ERROR: typeless default-value parameter `", str_concat(pn, " = <expr>` in fn signature is not supported in Nucleor (Nucleor requires explicit param types AND does not support default args). Sister to v0.7.38 (typed default-arg halt).")));
            print(str_concat("       Workaround: declare two fn overloads — one with all params, one without. Or use Option<T> as the param type with the default in the body. See v0.7.38 CHANGELOG entry for example.")));
            panic(str_concat("nucleor: typeless default-value parameter `", str_concat(pn, " = ...` not supported (see ERROR diagnostic above)")));
        };
        cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        let ptype: str = pr_val(tr);
        // detect &mut T parameter and emit a clear diagnostic.
        // Pre-v0.3.93, &mut T params silently passed by value (not by
        // reference), so any caller mutation via `*x = ...` was a no-op
        // — `add_one(&mut n)` returned without modifying caller's n.
        // Real implementation requires get/store-via-pointer codegen
        // (ptrtoint of alloca slot at call site, inttoptr+load/store
        // at deref). Until then, emit a clear error pointing at the
        // workaround.
        if str_len(ptype) >= 5 && str_eq(str_substring(ptype, 0, 5), "&mut ") == 1 {
            // only PRIMITIVE `&mut T` is broken. `&mut Struct` /
            // `&mut Enum` already works because those are heap handles
            // passed as i64 — field stores (`s.x = ...`) go through the
            // existing struct-field codegen, no ptr-deref-store needed.
            // The silent-miscompute window is `&mut <scalar>` where
            // `*x = ...` would need ptr-deref-store codegen we don't
            // emit. Pre-fix the diagnostic printed but compile continued,
            // the body was lowered as if the parameter were pass-by-value
            // (`*x = 99` dropped), and the binary silently produced wrong
            // output. Now: print the diagnostic, then hard-abort via panic
            // so adopters can't unintentionally ship the silent-miscompute
            // binary. `&mut Struct/Enum` keeps compiling cleanly.
            let inner: str = str_substring(ptype, 5, str_len(ptype));
            let is_scalar: i64 = if str_eq(inner, "i8") == 1 || str_eq(inner, "i16") == 1
                || str_eq(inner, "i32") == 1 || str_eq(inner, "i64") == 1
                || str_eq(inner, "i128") == 1 || str_eq(inner, "isize") == 1
                || str_eq(inner, "u8") == 1 || str_eq(inner, "u16") == 1
                || str_eq(inner, "u32") == 1 || str_eq(inner, "u64") == 1
                || str_eq(inner, "u128") == 1 || str_eq(inner, "usize") == 1
                || str_eq(inner, "f16") == 1 || str_eq(inner, "f32") == 1
                || str_eq(inner, "f64") == 1 || str_eq(inner, "bf16") == 1
                || str_eq(inner, "bool") == 1 || str_eq(inner, "char") == 1 { 1 } else { 0 };
            if is_scalar == 1 {
                print(str_concat("ERROR: &mut reference parameter `", str_concat(pn, str_concat(": ", str_concat(ptype, "` (scalar) in fn signature is not yet supported. Mutations via `*x = ...` would silently NOT propagate back to the caller. Workaround: return the new value (`fn foo(x: i64) -> i64 { return x + 1; }`) or use a `Vec<i64>` for shared state. `&mut Struct` works because struct fields share the heap handle. Tracked for a future ship — get/store-via-pointer codegen needed for primitives.")))));
                panic("&mut <scalar> parameter not implemented; see ERROR diagnostic above for workarounds");
            };
        };
        // NAM-001 — duplicate parameter name in fn signature.
        // Pre-fix `fn add(a: i32, a: i32)` silently shadowed the first
        // `a`. Inside the body `a + a` referenced the second `a` only,
        // so `add(3, 5)` returned 10 (5+5) instead of the naive 8 —
        // silent miscompute via lost first arg, no diagnostic. Catch
        // at parse time: every preceding param must have a different
        // name. Linear scan; param lists are small in practice.
        // Regression: duplicate fn parameter name silent shadow.
        let mut dup_check_i: i64 = 0;
        while dup_check_i < vec_len(params) {
            let prior_pid: i64 = vec_get(params, dup_check_i);
            let prior_name: str = node_field(pool, prior_pid, 1);
            if str_eq(prior_name, pn) == 1 {
                let pn_lc: Vec<i32> = tokens_linecol_at_byte(tokens, pn_byte);
                let pn_line: i64 = vec_get(pn_lc, 0);
                let pn_col: i64 = vec_get(pn_lc, 1);
                let pn_loc: str = str_concat(str_from_int(pn_line), str_concat(":", str_from_int(pn_col)));
                panic(str_concat("error[NAM-001]: identifier `", str_concat(pn, str_concat("` is bound more than once in this parameter list at line ", pn_loc))));
            };
            dup_check_i = dup_check_i + 1;
        };
        params.push(mk3(pool, 41, pn, ptype));
        // v0.7.38 (defensive halt — Rust default-arg-style fn parameter
        // `fn f(n: i64 = 1)`). Rust does NOT support default fn args
        // (Python/C++ feature), but C++/Python adopters often try this
        // syntax. Pre-fix surfaced as wrong-class `error[NR020]: parse
        // error: expected ',', got '='` because the next-iter expect_tok
        // for the param-list comma got `=` instead. Halt cleanly with
        // an overload/explicit-args workaround pointer.
        if pk(tokens, cp) == 40 {
            print(str_concat("ERROR: default-value parameter `", str_concat(pn, str_concat(": ", str_concat(ptype, " = <expr>` in fn signature is not supported in Nucleor (and is not supported in Rust either; this is a C++/Python idiom). Pre-v0.7.37 surfaced as wrong-class `error[NR020]: expected ',', got '='`.")))));
            print(str_concat("       Workaround: declare two fn overloads — one with all params, one without — and have the shorter form call the longer with the default — `fn ", str_concat(name, str_concat("_default(self) -> RetType { return self.", str_concat(name, "(<default-value>); } fn ", str_concat(name, "(self, ", str_concat(pn, str_concat(": ", str_concat(ptype, ") -> RetType { ... }`. Or use Option<T> as the param type and check for None inside the body.")))))))))));
            panic(str_concat("nucleor: default-value parameter `", str_concat(pn, " = ...` not supported (see ERROR diagnostic above)")));
        };
    };
    cp = cp + 1;
    let mut rtype: str = "void";
    if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
    cp = skip_effect_clause(tokens, cp);
    if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "requires") == 1 { cp = skip_bracket_list(tokens, cp + 1); };
    cp = skip_effect_clause(tokens, cp);
    // parse_where_clause_into_gparams replaces the old
    // skip_where_clause for parse_fn_decl. Extracts `T: Trait` bounds
    // and splices them into gparams_vec so lower_fn captures them
    // exactly like inline `<T: Trait>` bounds. Closes the where-clause
    // sister gap of Track Y (v0.5.31).
    cp = parse_where_clause_into_gparams(tokens, cp, gparams_vec);
    // v0.7.52 (defensive halt — Rust forward declaration `fn h() -> i64;`
    // at module scope without a body). Pre-fix this surfaced as wrong-
    // class `error[NR020]: expected '{', got ';'`. In Rust, a body-less
    // fn signature is valid only inside `trait { ... }` (where Nucleor
    // already supports it — `trait T { fn m(self) -> i64; }` works) or
    // inside `extern "C" { ... }` (which is also forward-roadmap, see
    // v0.7.26 halt). At module scope, the user almost always wants
    // either a body or an `extern fn` declaration.
    if pk(tokens, cp) == 43 {
        print(str_concat("ERROR: forward declaration `fn ", str_concat(name, "() -> RetType;` (no body, semicolon-terminated) is not yet supported at module scope in Nucleor. Pre-v0.7.52 surfaced as wrong-class `error[NR020]: expected '{', got ';'`.")));
        print(str_concat("       Workaround for FFI symbols: use `extern fn ", str_concat(name, "(...) -> RetType;` (the bare `extern fn` form, no `\"C\"` qualifier needed) or `extern \"C\" fn ", str_concat(name, "(...) -> RetType;` for explicit C-ABI marking.")));
        print(str_concat("       Workaround for unimplemented stubs: write a body that calls `todo!()` or `unimplemented!()` (v0.7.36 macro shipped) — `fn ", str_concat(name, "() -> RetType { todo!() }`. (Note: `todo!` returns void; in non-void fns add `; return placeholder;`.)")));
        panic(str_concat("nucleor: forward fn declaration `fn ", str_concat(name, "() -> RetType;` not supported at module scope (see ERROR diagnostic above)")));
    };
    cp = expect_tok(tokens, cp, 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    let gparams: i64 = mk_list(pool, gparams_vec);
    return pr(cp, mk6(pool, 30, name, mk_list(pool, params), rtype, pr_val(br), gparams));
}

#[manual_drop]
fn parse_extern_fn(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'extern fn', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    if pk(tokens, cp) == 54 { cp = skip_compile_time_params(tokens, cp); };
    cp = expect_tok(tokens, cp, 50);
    let mut params: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
        if vec_len(params) > 0 { cp = expect_tok(tokens, cp, 44); };
        // v0.7.47 (defensive halt — Rust C-FFI variadic syntax: `extern
        // "C" fn printf(fmt: str, ...);`). The lexer emits `...` as
        // token 58 (`..`) followed by token 45 (`.`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: expected ':', got
        // token 45` because the param parser tried to read `.` as the
        // binding name. Halt cleanly with a wrapper-fn workaround
        // pointer.
        if pk(tokens, cp) == 58 || pk(tokens, cp) == 45 {
            print(str_concat("ERROR: C-FFI variadic parameter `...` (e.g. `extern \"C\" fn ", str_concat(name, "(fmt: str, ...);`) is not yet supported in Nucleor. Pre-v0.7.47 surfaced as wrong-class `error[NR020]: expected ':', got token 45`.")));
            print(str_concat("       Workaround: declare a fixed-arity wrapper fn for each call shape you need — `extern \"C\" fn ", str_concat(name, "_1(fmt: str, a1: i64) -> i32; extern \"C\" fn ", str_concat(name, "_2(fmt: str, a1: i64, a2: i64) -> i32;` (one per arg-count). For `printf` specifically, prefer `print(format!(\"...\", args))` which has parity with the common usage.")));
            panic(str_concat("nucleor: C-FFI variadic `...` parameter in `extern \"C\" fn ", str_concat(name, "(...)` not yet supported (see ERROR diagnostic above)")));
        };
        let pn: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        params.push(mk3(pool, 41, pn, pr_val(tr)));
    };
    cp = cp + 1;
    let mut rtype: str = "void";
    if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
    cp = skip_effect_clause(tokens, cp);
    if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "requires") == 1 { cp = skip_bracket_list(tokens, cp + 1); };
    cp = skip_effect_clause(tokens, cp);
    cp = skip_where_clause(tokens, cp);
    // defensive halt: canonical Rust `extern "C" fn name() {
    // body }` (FFI-exposed fn with body) pre-fix landed here at `{`
    // and parse_extern_fn returned without consuming the body —
    // parse_program then surfaced the body as a stray top-level
    // construct, firing the wrong-class "statement-level keyword at
    // module scope" diag. Halt cleanly with a workaround pointer
    // (drop the `extern "C"` qualifier — Nucleor regular fns use
    // the C ABI by default).
    if pk(tokens, cp) == 52 {
        print(str_concat("ERROR: `extern \"C\" fn ", str_concat(name, "(...) { body }` (Rust FFI-exposed fn with body) is not yet supported in Nucleor's extern-fn parser, which only knows declaration-form (`extern fn name(...);` no body). Workaround: drop the `extern \"C\"` qualifier — Nucleor regular fns (`fn name(...) { body }`) already use the C ABI by default at the i64-everywhere runtime level, so the explicit qualifier is informational. For pure declarations of foreign symbols, use the bare `extern fn name(...);` declaration form.")));
        panic(str_concat("nucleor: `extern \"C\" fn ", str_concat(name, "(...) { body }` form not yet supported (see ERROR diagnostic above)")));
    };
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk4(pool, 32, name, mk_list(pool, params), rtype));
}

#[manual_drop]
fn parse_struct_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'struct', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    //  canonical RFC-0034 form `struct Buf[N:
    // usize] { data: Vec<i64> }` (CT-param on a struct decl) pre-fix
    // saw `[` (token 54) where the parser expected `{` or `<`,
    // surfacing as wrong-class `error[NR020]: parse error at byte
    // 10: expected '{', got '['`. The fn-decl precedent at line ~970
    // (`skip_compile_time_params`) ships, but parse_struct_decl is on
    // the legacy skipper. Halt at parse_struct_decl with a clean diag
    // pointing at the workaround (drop the `[N]` from the struct decl
    // — RFC-0034 first-pass erases CT-args at lower-time, so the
    // param has no observable effect on the unspecialized struct).
    if pk(tokens, cp) == 54 {
        print("ERROR: RFC-0034 compile-time `[]` parameters on struct declarations (e.g. `struct Buf[N: usize] { data: Vec<i64> }`) are not yet supported in Nucleor's first-pass `[]` parser. Workaround: drop the `[N]` from the struct decl (RFC-0034 first-pass erases CT-args at lower-time anyway, so the param has no observable effect on the unspecialized struct).");
        panic("nucleor: struct CT-params not yet supported (see ERROR diagnostic above)");
    };
    // Optional generic params: struct Name<T, U> { ... }
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr);
        gparams = mk_list(pool, pr_val(gr));
    };
    // canonical Rust unit-struct syntax `struct U;` (probe finding
    // 2026-05-01-unit-struct-semicolon-form-parse-fail). Pre-fix expected
    // `{` and panicked NR020 on `;` — translators porting Rust hit this
    // constantly because `struct Marker;` is the canonical form. Now both
    // `struct U;` and `struct U {}` lower to the same empty-fields decl
    // (kind 33 with empty fields list). Construction still requires
    // `U {}` value form; a follow-up will let `U` (bare ident) resolve
    // to the zero-field constructor.
    //  pre-fix `struct Wrapper<T> where T: A { … }` panicked
    // with NR020 because `expect_tok(cp, 52)` saw `where` (an ident, not
    // `{`) after the gparams. v0.6.11 wired where-clauses for fn decls
    // but explicitly noted parse_struct_decl was left on the legacy
    // skipper. Skip the where-clause here so canonical Rust struct
    // declarations parse cleanly. Bounds aren't yet wired into the
    // struct AST (forward-roadmap); skipping unblocks adopters.
    cp = skip_where_clause(tokens, cp);
    if pk(tokens, cp) == 43 {
        let unit_nid: i64 = mk4(pool, 33, name, mk_list(pool, Vec::new()), gparams);
        return pr(cp + 1, unit_nid);
    };
    //  tuple-struct declaration
    // `struct P(i64, i64);` (positional-field shape) is a canonical
    // Rust form. Pre-fix the next-token check below saw `(` (token
    // 50) instead of `{` and panicked NR020 with "expected '{', got
    // '('" — adopter sees the wrong-class error pointing at the
    // open-paren without naming the unsupported feature. Now halt
    // with a clean diag at the decl naming the workaround (named-
    // field form). Tuple-struct support is a parse-extension forward-
    // roadmap (positional field synthesis + `p.0` / `p.1` access path).
    // v0.6.73 RFC V1.1
    //  tuple-struct positional-
    // field synthesis. Pre-fix `struct P(T1, T2);` halted at parse with
    // a workaround diagnostic. Now: parse the paren-form, synthesize
    // field names `__0`, `__1`, ..., `__N` (matching Rust's positional
    // accessor naming where `p.0` resolves to the 0-th field). Struct
    // value retains kind-33 — downstream type-check + lowering use the
    // synthetic field names; constructor `P(a, b)` and field access
    // `p.0` / `p.1` are wired in subsequent commits.
    // Tuple-struct shape detection: structs with all field names
    // matching `__<digit>+` are tuple-style (used by constructor
    // detection + `.<digit>` access lowering downstream).
    let mut fields: Vec<i32> = Vec::new();
    if pk(tokens, cp) == 50 {
        cp = cp + 1; // past `(`
        let mut tup_idx: i64 = 0;
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if vec_len(fields) > 0 {
                cp = expect_tok(tokens, cp, 44);
                if pk(tokens, cp) == 51 { break; };
            };
            // Optional `pub` field-vis qualifier (matching Rust shape).
            if pk(tokens, cp) == 72 { cp = cp + 1; };
            let mut tup_tr: Vec<i32> = parse_type(tokens, cp);
            cp = pr_pos(tup_tr);
            let synth_name_v073: str = str_concat("__", str_from_int(tup_idx));
            fields.push(mk3(pool, 41, synth_name_v073, pr_val(tup_tr)));
            tup_idx = tup_idx + 1;
        };
        cp = expect_tok(tokens, cp, 51); // past `)`
        // Tuple structs end with `;`. Optional — accept brace-form
        // tail too in case adopters write `struct P(T1, T2) {}`.
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        return pr(cp, mk4(pool, 33, name, mk_list(pool, fields), gparams));
    };
    cp = expect_tok(tokens, cp, 52); // {
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(fields) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
        };
        // optional `pub` field-visibility
        // qualifier. Pre-fix the parser misread `pub x: i64` as a
        // top-level `pub` item nested inside the struct body and
        // crashed with cascading "statement-level keyword at module
        // scope" errors followed by AST corruption (segfault on
        // some hosts). Nucleor's current visibility model treats
        // all struct fields as accessible from importing modules
        // regardless of field-level pub, so the qualifier is parsed
        // and discarded for now (matching Rust shape; field-private
        // enforcement can land later without breaking existing
        // sources).
        if pk(tokens, cp) == 72 { cp = cp + 1; };
        // optional `mut` field qualifier. Nucleor's current
        // model treats fields as mutable if the owning binding is
        // `let mut`, so the field-level mut is informational only.
        // Pre-fix: `mut value: i64` was parsed as field name = "mut",
        // value field index slipped to -1, runtime vec_set panicked.
        if pk(tokens, cp) == 12 { cp = cp + 1; };
        let fn2: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        //  pre-fix `struct Node { val: i64, next: Node }`
        // (recursive type without Box/&) was accepted at parse + type-check
        // and crashed at runtime with STATUS_STACK_OVERFLOW (Windows
        // exception 0xC00000FD) on instantiation — the struct contains
        // itself directly so the size is infinite. Rust statically
        // rejects this with E0072 ("recursive type `Node` has infinite
        // size"). Mirror that at parse-time. The field type is the bare
        // struct name; reject. Fields wrapping the recursive type in
        // Box / & / & mut / Vec / Option<Box<…>> all carry distinct
        // type strings ("Box<Node>", "&Node", "Vec<Node>", "Option<Box<Node>>")
        // so the equality check below only fires on the direct-recursion
        // case.
        let field_type_v063: str = pr_val(tr);
        if str_eq(field_type_v063, name) == 1 {
            print(str_concat("error[NR036]: recursive type `", str_concat(name, str_concat("` has infinite size — field `", str_concat(fn2, str_concat("` is itself a `", str_concat(name, "` (containing itself directly).")))))));
            print("  Rust E0072: a struct that contains itself directly cannot be sized at compile time. v0.6.36 catches the recursion at parse-time.");
            print(str_concat("  Workaround: wrap the recursive field in `Box<", str_concat(name, str_concat(">` (heap-indirection, single-element list shape), or `Option<Box<", str_concat(name, str_concat(">>` (linked-list / tree shape with terminator), or `&", str_concat(name, "` (advisory until borrow lowering of recursive structs lands).")))))));
            // F-026 trailing-PANIC line
            // closure. Lane 1 staged __nucleor_diag_exit; this bootstrap
            // iteration wires the call site to suppress the PANIC: prefix
            // and exit(1) cleanly after the NR036 diagnostic.
            diag_exit();
            panic(str_concat("nucleor: recursive struct ", str_concat(name, str_concat(" contains itself directly via field ", fn2))));
        };
        //  duplicate field name in a struct decl was
        // silently accepted at decl-time; TYP-017 only fired at the init
        // site `P { x: 1, x: 2 }`. Adopters writing typo'd decls
        // (`struct Date { day: i64, day: i64 }`) got no signal until
        // construction. Mirror Rust E0124 ("field is already declared")
        // at decl-time.
        let mut dup_chk_v062: i64 = 0;
        while dup_chk_v062 < vec_len(fields) {
            let prior_v062: i64 = vec_get(fields, dup_chk_v062);
            let prior_name_v062: str = node_field(pool, prior_v062, 1);
            if str_eq(prior_name_v062, fn2) == 1 {
                print(str_concat("error[TYP-039]: field `", str_concat(fn2, str_concat("` is already declared in this struct (Rust E0124). Each field name must be unique within the decl."))));
                print(str_concat("  Two `", str_concat(fn2, "` fields parsed; the first one wins for offset / type, the second is unreachable but consumes the comma-list slot. TYP-017 catches the same family at init-site (`P { x: 1, x: 2 }`); v0.6.27 catches it earlier at the struct-decl site so adopters writing typo'd decls (`struct Date { day: i64, day: i64, month: i64 }`) get the signal at the decl, not at the first construction.")));
                print("  Workaround: rename or remove the duplicate field. If both names are wanted (different physical fields with the same logical role), pick one (`x` and `x_alt`).");
                panic(str_concat("duplicate field in struct decl: ", fn2));
            };
            dup_chk_v062 = dup_chk_v062 + 1;
        };
        fields.push(mk3(pool, 41, fn2, pr_val(tr)));
    };
    cp = cp + 1;
    return pr(cp, mk4(pool, 33, name, mk_list(pool, fields), gparams));
}

#[manual_drop]
fn parse_struct_init(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points at name, next is {
    // v0.5 (v0.4.237) — capture struct-name token byte offset for
    // span-aware diagnostics (TYP-008/012/013/017 struct-init field
    // diags). Each field-init nid (kind 35) also gets the field-
    // name token's offset so per-field diags caret to the offending
    // field, not the function name.
    let struct_name_span: i64 = tok_pos_at(tokens, pos);
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    cp = skip_angle_group(tokens, cp);
    cp = expect_tok(tokens, cp, 52);
    let mut inits: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(inits) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
        };
        // defensive halt: canonical Rust struct-update
        // syntax `Point { x: 10, ..rest }` (functional record update)
        // pre-fix surfaced as wrong-class `error[NR020]: parse error
        // at byte K: expected ':', got identifier` after the parser
        // saw `..` (token 58) and tried to read it as a field name.
        // Halt cleanly with a workaround pointer (write each field
        // explicitly).
        if pk(tokens, cp) == 58 {
            print(str_concat("ERROR: struct-update syntax `", str_concat(name, " { <field>: <val>, ..<rest> }` (Rust functional record update) is not yet supported in Nucleor. Workaround: write each field explicitly — `Point { x: 10, y: rest.y, z: rest.z }`.")));
            panic(str_concat("nucleor: struct-update `..rest` syntax not yet supported (see ERROR diagnostic above)"));
        };
        let field_span: i64 = tok_pos_at(tokens, cp);
        let fn2: i64 = pkv(tokens, cp);
        // shorthand struct init `Point { x, y }`. If the
        // next token after the field name is `,` (44) or `}` (53),
        // synthesize a var-ref expression with the same name as the
        // field (Rust shorthand `Point { x }` → `Point { x: x }`).
        // Without this, the parser called expect_tok(42) (`:`) and
        // failed when the user wrote shorthand.
        if pk(tokens, cp + 1) == 44 || pk(tokens, cp + 1) == 53 {
            let var_node: i64 = mk3(pool, 3, fn2, 0);  // v0.4.209: width slot
            cp = cp + 1;
            let init_nid: i64 = mk3(pool, 35, fn2, var_node);
            node_set_span(pool, init_nid, field_span);
            inits.push(init_nid);
        } else {
            cp = expect_tok(tokens, cp + 1, 42);
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool); cp = pr_pos(er);
            let init_nid: i64 = mk3(pool, 35, fn2, pr_val(er));
            node_set_span(pool, init_nid, field_span);
            inits.push(init_nid);
        };
    };
    cp = cp + 1;
    let struct_nid: i64 = mk3(pool, 34, name, mk_list(pool, inits));
    node_set_span(pool, struct_nid, struct_name_span);
    return pr(cp, struct_nid);
}

#[manual_drop]
fn parse_enum_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'enum', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    // Optional generic params: enum Name<T> { ... }
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr);
        gparams = mk_list(pool, pr_val(gr));
    };
    // accept `where`-clause on enum decl, sister to v0.6.46
    // struct/fn where-clause acceptance. Pre-v0.7.57 this surfaced as
    // wrong-class NR020; v0.7.57 halted cleanly; v0.7.58 promotes the
    // halt to a feature acceptance — the bound is skipped (same as
    // struct/fn where-clauses do today; bounds aren't enforced anyway
    // until the v1 trait-checker substrate lands). Adopters porting
    // canonical Rust no longer need to hoist bounds into the inline
    // generic param list as a workaround.
    cp = skip_where_clause(tokens, cp);
    cp = expect_tok(tokens, cp, 52); // {
    let mut variants: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(variants) > 0 && pk(tokens, cp) == 44 { cp = cp + 1; };
        if pk(tokens, cp) == 53 || pk(tokens, cp) == 0 { break; };
        let vname: i64 = pkv(tokens, cp); cp = cp + 1;
        //  pre-fix `enum X { A = 5 }` (canonical Rust explicit-
        // discriminant syntax) crashed the compiler with SEGFAULT inside
        // the type/ownership pass — the parser fell through `= 5` and
        // downstream passes dereferenced bad state. Halt at parse-time
        // with a clean error pointing at the workaround. Real explicit-
        // discriminant lowering is a separate ship (needs the enum AST
        // to carry per-variant i64 values + the IR-emit path to
        // propagate them to match-arm dispatch).
        if pk(tokens, cp) == 40 {
            print(str_concat("error[NR035]: explicit enum discriminants `enum ", str_concat(name, str_concat(" { ", str_concat(vname, " = N }")))));
            print("  not yet supported in v0.6 — pre-v0.6.35 this segfaulted the compiler with no diagnostic. Real explicit-discriminant lowering needs the enum AST to carry per-variant i64 values plus IR-emit propagation to match-arm dispatch (forward-roadmap).");
            print("  Workaround: drop the `= N` and rely on order-based discriminants. `enum Code { OK, WARN, ERR }` lowers to discriminants 0, 1, 2 in order (matching the most common Rust C-style enum pattern). If you need specific values for FFI / wire-protocol compatibility, build a separate const table (`const OK_CODE: i64 = 0;` etc.) until explicit-discriminant support lands.");
            panic(str_concat("nucleor: explicit enum discriminants not implemented; see ERROR diagnostic for workarounds: ", str_concat(name, str_concat("::", vname))));
        };
        let mut ptypes: Vec<i32> = Vec::new();
        if pk(tokens, cp) == 50 {
            cp = cp + 1;
            while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
                if vec_len(ptypes) > 0 {
                    cp = expect_tok(tokens, cp, 44);
                    if pk(tokens, cp) == 51 { break; };
                };
                let mut tr: Vec<i32> = parse_type(tokens, cp); ptypes.push(pr_val(tr)); cp = pr_pos(tr);
            };
            cp = cp + 1;
        } else if pk(tokens, cp) == 52 {
            cp = cp + 1;
            while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
                if vec_len(ptypes) > 0 {
                    cp = expect_tok(tokens, cp, 44);
                    if pk(tokens, cp) == 53 { break; };
                };
                let _fname: str = pkv(tokens, cp);
                cp = expect_tok(tokens, cp + 1, 42);
                let mut tr: Vec<i32> = parse_type(tokens, cp);
                ptypes.push(pr_val(tr));
                cp = pr_pos(tr);
            };
            cp = expect_tok(tokens, cp, 53);
        };
        //  `enum E { A, A, A }` was silently accepted
        // with all 3 variants kept distinct, and MATCH-001 confirmed
        // "1 arms for enum with 3 variants" — Nucleor saw them as
        // separate. Same for data variants `enum E { Foo(i64),
        // Foo(str) }`. Mirror Rust E0428 ("the name `A` is defined
        // multiple times") at decl-time.
        let mut dup_v: i64 = 0;
        while dup_v < vec_len(variants) {
            let prior_var: i64 = vec_get(variants, dup_v);
            let prior_vname: str = node_field(pool, prior_var, 1);
            if str_eq(prior_vname, vname) == 1 {
                print(str_concat("error[TYP-040]: duplicate enum variant `", str_concat(vname, str_concat("` in `enum ", str_concat(name, "` (Rust E0428)."))))));
                print("  Variant names must be unique within an enum.");
                print(str_concat("  Workaround: rename or remove the duplicate `", str_concat(vname, "`. If both shapes are needed (e.g. `Foo(i64)` and `Foo(str)`), give them distinct names (`FooInt`, `FooStr`) — Nucleor doesn't yet support trait-style overloaded variants.")));
                panic(str_concat("duplicate enum variant: ", str_concat(name, str_concat("::", vname))));
            };
            dup_v = dup_v + 1;
        };
        variants.push(mk3(pool, 37, vname, mk_list(pool, ptypes)));
    };
    cp = cp + 1;
    return pr(cp, mk4(pool, 36, name, mk_list(pool, variants), gparams));
}

#[manual_drop]
fn parse_trait_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'trait', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr); gparams = mk_list(pool, pr_val(gr));
    };
    // supertrait syntax `trait Dog: Animal { ... }` and
    // `trait Foo: Bar + Baz { ... }`. Pre-v0.3.110, the parser
    // expected `{` right after the trait name, so the canonical
    // Rust form `trait Dog: Animal { ... }` cascaded into 13+
    // parse errors. Supertrait names are accepted but not yet
    // wired into method dispatch — adopters get the syntactic
    // freedom to express the relationship; trait inheritance
    // semantics (calling super-trait default methods through the
    // sub-trait) already work because the impl block separately
    // implements both traits and method dispatch resolves through
    // the impl_table. Skip ident, optional `+ ident` repeats, and
    // the optional `where` clause until `{`.
    if pk(tokens, cp) == 42 {
        cp = cp + 1;
        cp = cp + 1; // first super-trait name
        // v0.7.62 (defensive halt — qualified path supertrait:
        // `trait Sub: super::Iterator { ... }`,
        // `trait Sub: std::fmt::Display { ... }`). Pre-fix this
        // surfaced as wrong-class `error[NR020]: expected '{', got
        // token 46` because the supertrait parser reads only a bare
        // ident, leaving `::Path` unconsumed. Halt cleanly with a
        // drop-the-namespace workaround.
        if pk(tokens, cp) == 46 {
            print(str_concat("ERROR: qualified-path supertrait `trait ", str_concat(name, ": <namespace>::SuperTrait { ... }` (e.g. `trait Sub: super::Iterator { ... }`, `trait Sub: std::fmt::Display { ... }`) is not yet supported in Nucleor. Pre-v0.7.62 surfaced as wrong-class `error[NR020]: expected '{', got token 46` because the supertrait parser reads only a bare identifier.")));
            print(str_concat("       Workaround: drop the namespace prefix and use the unqualified trait name — `trait ", str_concat(name, ": SuperTrait { ... }`. Nucleor's supertrait list accepts bare names; the prefix is informational-only at the trait-decl level today.")));
            panic(str_concat("nucleor: qualified-path supertrait in `trait ", str_concat(name, "` not yet supported (see ERROR diagnostic above)")));
        };
        // Optional generic args on supertrait `Foo<T>` — skip the angle group.
        if pk(tokens, cp) == 32 { cp = skip_angle_group(tokens, cp); };
        while pk(tokens, cp) == 20 {
            cp = cp + 1;
            cp = cp + 1; // additional super-trait name
            if pk(tokens, cp) == 32 { cp = skip_angle_group(tokens, cp); };
        };
    };
    cp = skip_where_clause(tokens, cp);
    // defensive halt: canonical Rust trait alias
    // `trait Pretty = Show;` (or `trait Foo = Bar + Baz;`) pre-fix
    // surfaced as wrong-class `NR020: parse error: expected '{',
    // got '='` because parse_trait_decl expects `{` after the name
    // (no `=` branch). Halt cleanly with a workaround pointer
    // (use a regular trait with supertraits). Trait aliases are
    // nightly-only in Rust today (RFC 1733), so low-volume but
    // worth the halt.
    if pk(tokens, cp) == 40 {
        print(str_concat("ERROR: trait alias `trait ", str_concat(name, " = <bounds>;` is not yet supported in Nucleor. Workaround: declare a regular trait that names the bounds in its supertrait list — `trait Pretty: Show + Clone {}`. Adopters who want `Pretty` to mean `Show + Clone` get the same surface via inheritance.")));
        panic(str_concat("nucleor: trait alias `trait ", str_concat(name, " = ...` not yet supported (see ERROR diagnostic above)")));
    };
    cp = expect_tok(tokens, cp, 52); // {
    let mut methods: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        // associated constants in trait bodies aren't yet
        // supported. Pre-v0.3.85 the `const NAME: T;` line cascaded
        // into 18+ parse errors as expect_tok(fn) failed and the
        // recovery walked through the rest of the trait body
        // mis-aligned. Detect `const` (token 73) and skip to the
        // next stmt boundary with a clear diagnostic.
        if pk(tokens, cp) == 73 {
            print("ERROR: associated constants in traits are not yet supported (e.g. `trait T { const MAX: i64; }`). Workaround: declare the constant at module scope (`const MAX: i64 = 100;`) or as an inherent fn that returns the value. Tracked for a future ship.");
            // pre-fix the trait body kept parsing after this
            // and the const declaration was silently dropped. Adopters
            // got a trait with missing surface and downstream impls
            // referencing the const failed at clang. Halt now.
            panic("nucleor: associated constants in traits not supported (see ERROR diagnostic above)");
            while pk(tokens, cp) != 0 && pk(tokens, cp) != 43 && pk(tokens, cp) != 53 { cp = cp + 1; };
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            continue;
        };
        // defensive halt: canonical Rust associated types in
        // traits (`type Item;`, `type Item = i64;`) pre-fix surfaced
        // as wrong-class `error[NR020]: parse error: expected token 10
        // (fn), got token 74 (type)`. Halt cleanly with a workaround
        // pointer (use a generic param `trait Container<Item>` or hand-
        // wire the concrete type per impl).
        if pk(tokens, cp) == 74 {
            print("ERROR: associated types in traits (`type Item;` or `type Item = i64;`) are not yet supported in Nucleor. Workaround: declare a generic param on the trait — `trait Container<Item> { fn get(self: &Self) -> Item; }` — and the impls instantiate it concretely (`impl Container<i64> for IntBox { fn get(self: &IntBox) -> i64 { ... } }`).");
            panic("nucleor: associated types in traits not yet supported (see ERROR diagnostic above)");
        };
        cp = expect_tok(tokens, cp, 10); // fn
        let mname: i64 = pkv(tokens, cp); cp = cp + 1;
        // skip optional generic params on trait method
        // (`fn count<T>(self)` etc.). Pre-v0.3.89 this cascaded into
        // 22+ parse errors. The generic params are accepted but
        // discarded — Nucleor's trait dispatch is monomorphic-by-
        // mangled-name, and the generic types resolve at impl time.
        if pk(tokens, cp) == 32 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 32 { depth = depth + 1; };
                if pk(tokens, cp) == 33 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        if pk(tokens, cp) == 54 { cp = skip_compile_time_params(tokens, cp); };
        cp = expect_tok(tokens, cp, 50); // (
        let mut params: Vec<i32> = Vec::new();
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if vec_len(params) > 0 { cp = expect_tok(tokens, cp, 44); };
            // `&self` / `&mut self` in trait method
            // declarations. Pre-v0.3.106 the trait parser only
            // recognized bare `self`, so the canonical Rust form
            // `fn say(&self)` cascaded into 13+ parse errors. Mirror
            // the parse_impl_block branch (line 1685) but use a
            // generic `&Self` / `&mut Self` type since no concrete
            // receiver type is known here.
            if pk(tokens, cp) == 82 {
                cp = cp + 1;
                let mut ptype: str = "&Self";
                if pk(tokens, cp) == 12 { ptype = "&mut Self"; cp = cp + 1; };
                let pn2: i64 = pkv(tokens, cp); cp = cp + 1;
                params.push(mk3(pool, 41, pn2, ptype));
            } else {
                let pn: i64 = pkv(tokens, cp); cp = cp + 1;
                if pk(tokens, cp) == 42 {
                    cp = cp + 1;
                    let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
                    params.push(mk3(pool, 41, pn, pr_val(tr)));
                } else {
                    params.push(mk3(pool, 41, pn, "Self"));
                };
            };
        };
        cp = cp + 1; // )
        let mut rtype: str = "void";
        if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
        cp = skip_effect_clause(tokens, cp);
        if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "requires") == 1 { cp = skip_bracket_list(tokens, cp + 1); };
        cp = skip_effect_clause(tokens, cp);
        cp = skip_where_clause(tokens, cp);
        if pk(tokens, cp) == 52 {
            // Default method with body
            cp = cp + 1;
            let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(br), 53);
            methods.push(mk5(pool, 44, mname, mk_list(pool, params), rtype, pr_val(br)));
        } else {
            // Required method (no body)
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            methods.push(mk5(pool, 44, mname, mk_list(pool, params), rtype, 0 - 1));
        };
    };
    cp = cp + 1; // }
    return pr(cp, mk4(pool, 43, name, mk_list(pool, methods), gparams));
}

#[manual_drop]
fn parse_impl_block(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // Supports both `impl Trait for Type { ... }` and `impl Type { ... }`
    // also `impl<T> Trait for Type<T> { ... }` (Rust generic
    // impl form). Pre-fix the `<T>` after `impl` was treated as the
    // start of a type expression, mis-classifying T as the impl target.
    // Skip the generic-param list at the head if present.
    let mut cp: i64 = pos;
    if pk(tokens, cp) == 32 {
        cp = skip_balanced_angle(tokens, cp);
    };
    let mut first_name: str = pkv(tokens, cp);
    let mut trait_name: str = "";
    let mut type_name: str = first_name;
    cp = cp + 1;
    // path-qualified trait or type name in impl block.
    // `impl fmt::Display for Status` / `impl std::fmt::Display for Status` —
    // pre-fix: parser read first segment (e.g. `fmt`) as first_name, then
    // `::` (token 46) landed where expect_tok(52) expected `{`, producing
    // wrong-class `error[NR020]: expected '{', got token 46`. Fix: walk
    // through `::` segments and keep only the final one as first_name.
    while pk(tokens, cp) == 46 {
        cp = cp + 1;
        first_name = pkv(tokens, cp);
        type_name = first_name;
        cp = cp + 1;
    };
    if pk(tokens, cp) == 32 {
        // v0.7.44 (defensive halt — impl-target type with lifetime in
        // generic args: `impl<'a> R<'a> { ... }`). The parse_type call
        // below doesn't handle lifetime tokens (98) in type-arg position;
        // pre-fix this surfaced as wrong-class `error[NR020]: expected
        // '{', got token 98`. Detect a lifetime inside the angle-bracket
        // group and halt cleanly with a drop-the-lifetime workaround.
        let mut v744_scan: i64 = cp + 1;
        let mut v744_depth: i64 = 1;
        let mut v744_has_lt: i64 = 0;
        while v744_scan < vec_len(tokens) && v744_depth > 0 {
            let v744_t: i64 = pk(tokens, v744_scan);
            if v744_t == 32 { v744_depth = v744_depth + 1; };
            if v744_t == 33 { v744_depth = v744_depth - 1; };
            if v744_t == 98 && v744_depth > 0 { v744_has_lt = 1; };
            if v744_t == 0 { v744_depth = 0; };
            v744_scan = v744_scan + 1;
        };
        if v744_has_lt == 1 {
            print(str_concat("ERROR: impl-target type `", str_concat(first_name, "<'a>` (lifetime in generic args of the impl-target type) is not yet supported in Nucleor. Pre-v0.7.44 surfaced as wrong-class `error[NR020]: expected '{', got token 98` because parse_type doesn't handle lifetime tokens in type-arg position.")));
            print(str_concat("       Workaround: drop the lifetime from the impl-target type — `impl<'a> ", str_concat(first_name, " { ... }` (the impl-head `'a` already binds the lifetime; redeclaring it on the target is purely advisory under Nucleor's i64-everywhere ABI).")));
            panic(str_concat("nucleor: impl-target `", str_concat(first_name, "<'a>` lifetime-in-generics not yet supported (see ERROR diagnostic above)")));
        };
        let mut first_tr: Vec<i32> = parse_type(tokens, pos);
        first_name = pr_val(first_tr);
        type_name = first_name;
        cp = pr_pos(first_tr);
    };
    if pk(tokens, cp) == 56 {
        trait_name = first_name;
        let mut target_tr: Vec<i32> = parse_type(tokens, cp + 1);
        type_name = pr_val(target_tr);
        cp = pr_pos(target_tr);
    };
    //  same gap as struct decls — `impl<T> Foo for T where
    // T: Show { … }` panicked NR020 because `expect_tok(cp, 52)` saw
    // `where` after the type. Skip the where-clause so canonical Rust
    // impl blocks parse cleanly. Bounds not yet wired (forward-roadmap).
    cp = skip_where_clause(tokens, cp);
    cp = expect_tok(tokens, cp, 52); // {
    let mut methods: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        // associated constants in impl bodies aren't yet
        // supported. Same diagnostic+recovery as trait body.
        if pk(tokens, cp) == 73 {
            print("ERROR: associated constants in impl blocks are not yet supported. Workaround: declare the constant at module scope or as an inherent fn that returns the value. Tracked for a future ship.");
            // same fix as the trait-body site — pre-fix the
            // const decl was silently dropped from the impl surface.
            panic("nucleor: associated constants in impl blocks not supported (see ERROR diagnostic above)");
            while pk(tokens, cp) != 0 && pk(tokens, cp) != 43 && pk(tokens, cp) != 53 { cp = cp + 1; };
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            continue;
        };
        cp = expect_tok(tokens, cp, 10); // fn
        let mname: i64 = pkv(tokens, cp);
        // Parse as fn_decl but handle self without type annotation
        let mut cp2: i64 = cp + 1;
        let mut mgparams: i64 = mk_list(pool, Vec::new());
        if pk(tokens, cp2) == 32 {
            let mut gr: Vec<i32> = parse_generic_params(tokens, cp2);
            cp2 = pr_pos(gr); mgparams = mk_list(pool, pr_val(gr));
        };
        if pk(tokens, cp2) == 54 { cp2 = skip_compile_time_params(tokens, cp2); };
        cp2 = expect_tok(tokens, cp2, 50); // (
        let mut params: Vec<i32> = Vec::new();
        while pk(tokens, cp2) != 51 && pk(tokens, cp2) != 0 {
            if vec_len(params) > 0 { cp2 = expect_tok(tokens, cp2, 44); };
            if pk(tokens, cp2) == 82 {
                cp2 = cp2 + 1;
                let mut ptype: str = str_concat("&", type_name);
                if pk(tokens, cp2) == 12 { ptype = str_concat("&mut ", type_name); cp2 = cp2 + 1; };
                let pn2: i64 = pkv(tokens, cp2); cp2 = cp2 + 1;
                params.push(mk3(pool, 41, pn2, ptype));
            } else {
                let pn: i64 = pkv(tokens, cp2); cp2 = cp2 + 1;
                if str_eq(pn, "self") && pk(tokens, cp2) != 42 {
                // self without type annotation — inject type_name
                    params.push(mk3(pool, 41, pn, type_name));
                } else {
                    cp2 = expect_tok(tokens, cp2, 42); // :
                    let mut tr: Vec<i32> = parse_type(tokens, cp2); cp2 = pr_pos(tr);
                    // v0.6.93 RFC V1.7-sister: substitute `Self` in
                    // the EXPLICIT param type form (`self: &Self`,
                    // `other: &Self`, etc.) with the impl's concrete
                    // type_name. Pre-fix only the shorthand `&self` /
                    // `self` form got Self → type_name; explicit
                    // `self: &Self` left "Self" in the param type
                    // string, so downstream `self.field` field access
                    // failed to resolve (`expr_struct_type` couldn't
                    // map "Self" to a known struct).
                    let mut v093_pt: str = pr_val(tr);
                    if str_eq(v093_pt, "Self") == 1 { v093_pt = type_name; };
                    if str_eq(v093_pt, "&Self") == 1 { v093_pt = str_concat("&", type_name); };
                    if str_eq(v093_pt, "&mut Self") == 1 { v093_pt = str_concat("&mut ", type_name); };
                    params.push(mk3(pool, 41, pn, v093_pt));
                };
            };
        };
        cp2 = cp2 + 1; // )
        let mut rtype: str = "void";
        if pk(tokens, cp2) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp2 + 1); cp2 = pr_pos(tr); rtype = pr_val(tr); };
        // substitute `Self` (and `&Self` / `&mut Self`) in
        // the return type with the impl's actual `type_name`. Pre-
        // `impl Point { fn new() -> Self { ... } }` left
        // rtype = "Self" verbatim, so the populate_fn_returns_in_sym
        // pass registered `__fnret_Point__new = "Self"`. Downstream,
        // expr_struct_type couldn't resolve "Self" to a known struct,
        // and the call result fell back to a zero placeholder. The
        // canonical Rust `fn new() -> Self` constructor pattern
        // silently miscomputed (returned 0 instead of the constructed
        // value). Param-side substitution already happens for
        // `&self` / `&mut self` at the param-loop above; this mirrors
        // it for the return slot.
        if str_eq(rtype, "Self") == 1 { rtype = type_name; };
        if str_eq(rtype, "&Self") == 1 { rtype = str_concat("&", type_name); };
        if str_eq(rtype, "&mut Self") == 1 { rtype = str_concat("&mut ", type_name); };
        cp2 = skip_effect_clause(tokens, cp2);
        if pk(tokens, cp2) == 1 && str_eq(pkv(tokens, cp2), "requires") == 1 { cp2 = skip_bracket_list(tokens, cp2 + 1); };
        cp2 = skip_effect_clause(tokens, cp2);
        cp2 = skip_where_clause(tokens, cp2);
        cp2 = expect_tok(tokens, cp2, 52); // {
        let mut br: Vec<i32> = parse_stmts(tokens, cp2, pool);
        cp2 = expect_tok(tokens, pr_pos(br), 53); // }
        methods.push(mk6(pool, 30, mname, mk_list(pool, params), rtype, pr_val(br), mgparams));
        cp = cp2;
    };
    cp = cp + 1; // }
    return pr(cp, mk4(pool, 45, trait_name, type_name, mk_list(pool, methods)));
}

#[manual_drop]
fn parse_match_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>, match_span: i64) -> Vec<i32> {
    // pos is after 'match', at the expression
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = expect_tok(tokens, pr_pos(er), 52); // {
    let mut arms: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        // Lane 4 / F-036: missing-comma between match arms silently
        // accepted. Pre-fix `_ => { 1 } 1 => { 2 }` (no `,` between
        // the two arms) parsed as two arms with the first arm's
        // body absorbing nothing extra — but adopters expected
        // a parse error per §5.1. Now: after the first arm, the
        // next token MUST be `,` or `}`.
        if vec_len(arms) > 0 {
            if pk(tokens, cp) == 44 {
                cp = cp + 1;
            } else if pk(tokens, cp) == 53 {
                // closing brace — allow trailing-comma-omitted form.
            } else {
                let v_arm_byte: i64 = tok_pos_at(tokens, cp);
                panic(str_concat("error[PARSE-MATCH-COMMA]: missing `,` between match arms at byte ", str_concat(str_from_int(v_arm_byte), str_concat(" — got ", str_concat(tok_name(pk(tokens, cp)), ". Match arms must be comma-separated (`pat => body, pat => body`). Pre-fix the missing comma was silently accepted, masking adopter typos.")))));
            };
        };
        if pk(tokens, cp) == 53 || pk(tokens, cp) == 0 { break; };
        let mut pat: Vec<i32> = parse_match_one_pattern(tokens, cp, pool);
        cp = vec_get(pat, 0);
        let ename: str = vec_get(pat, 1);
        let vname: str = vec_get(pat, 2);
        let binding: str = vec_get(pat, 3);
        // or-patterns (`A | B | C => body`). Pre-fix this
        // silently miscomputed: the parser printed parse errors but
        // continued, the build succeeded, and the match returned the
        // wildcard arm value (e.g. `match 2 { 1 | 2 => 100, _ => 0 }`
        // returned 0). Now: collect the OR'd patterns into pat_list,
        // parse the body once, and push one arm per pattern with the
        // same body + guard. Currently supports int-literal and
        // wildcard patterns (the common case for matching numeric
        // values); enum or-patterns and binding or-patterns fall
        // through to the existing parse-error path with a clear
        // diagnostic for now.
        let mut pat_list: Vec<i32> = Vec::new();
        pat_list.push(ename); pat_list.push(vname); pat_list.push(binding);
        while pk(tokens, cp) == 65 {
            cp = cp + 1;
            let mut orpat: Vec<i32> = parse_match_one_pattern(tokens, cp, pool);
            cp = vec_get(orpat, 0);
            let oren: str = vec_get(orpat, 1);
            let orvn: str = vec_get(orpat, 2);
            let orbn: str = vec_get(orpat, 3);
            if str_eq(pattern_binding_key(ename, binding), pattern_binding_key(oren, orbn)) == 0 {
                print("error[MATCH-008]: or-pattern alternatives must bind the same names");
                panic("nucleor: MATCH-008 or-pattern binding mismatch");
            };
            if str_len(oren) > 0 {
                pat_list.push(oren); pat_list.push(orvn); pat_list.push(orbn);
            };
        };
        // Optional guard: if condition
        let mut guard_nid: i64 = 0;
        if pk(tokens, cp) == 13 {
            cp = cp + 1;
            // defensive halt: `if let PATTERN = EXPR` in match guard
            // (Rust 1.77 let_chains / let-guard stabilization). Pre-v0.7.17
            // `parse_expr` was called with `let` as the first token, producing
            // wrong-class `error[NR020]: parse_primary cannot start expression
            // at token kind 11`.
            if pk(tokens, cp) == 11 {
                print("ERROR: `if let` guard in match arm (e.g. `x if let Some(v) = opt => ...`) is not yet supported in Nucleor. Workaround: hoist the `if let` above the `match` — bind the value first, then use it as a boolean guard: `if let Some(v) = opt { match x { n if v > 0 => ..., _ => ... } } else { ... }`. Alternatively, convert the guard to an explicit boolean test: `match x { n if is_some(opt) => ..., _ => ... }`.");
                panic("nucleor: `if let` guard in match arm not supported (see ERROR diagnostic above)");
            };
            let mut gr: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(gr);
            guard_nid = pr_val(gr);
        };
        cp = expect_tok(tokens, cp, 64); // =>
        let mut body_list: i64 = 0;
        if pk(tokens, cp) == 52 {
            cp = cp + 1;
            let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(br), 53); // }
            body_list = pr_val(br);
        } else if pk(tokens, cp) == 16 {
            // arm body `return EXPR` — Rust-style. Parse as a
            // return stmt (kind 22) so the lowering treats it as a
            // divergent stmt rather than an expression. Pre-v0.3.79 this
            // hit parse_expr(return ...) which failed silently and left
            // cp parked on `return`, producing the cascading "expected
            // token 64 got 44/16" parse errors as the next arm's
            // pattern-parse re-entered partway through the previous
            // arm's body.
            cp = cp + 1;
            let mut rstmts: Vec<i32> = Vec::new();
            if pk(tokens, cp) == 43 {
                rstmts.push(mk2(pool, 22, 0 - 1));
                cp = cp + 1;
            } else {
                let mut rer: Vec<i32> = parse_expr(tokens, cp, pool);
                cp = pr_pos(rer);
                rstmts.push(mk2(pool, 22, pr_val(rer)));
            };
            body_list = mk_list(pool, rstmts);
        } else if pk(tokens, cp) == 18 {
            // arm body `break;` (or bare `break`).
            cp = cp + 1;
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            let mut bstmts: Vec<i32> = Vec::new();
            bstmts.push(mk2(pool, 26, 0));
            body_list = mk_list(pool, bstmts);
        } else if pk(tokens, cp) == 19 {
            // arm body `continue;` (or bare `continue`).
            cp = cp + 1;
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            let mut cstmts: Vec<i32> = Vec::new();
            cstmts.push(mk2(pool, 27, 0));
            body_list = mk_list(pool, cstmts);
        } else {
            // detect assignment LHS = RHS in arm body. Pre-v0.3.84,
            // parse_expr stopped at `=` and the result wrapped as kind 25
            // (expression-stmt) — the `= RHS` was silently dropped, so
            // `total = v` arm bodies became no-op expression-stmts of just
            // `total`. Now: parse the LHS expression, then if next token is
            // `=` (40), parse the RHS and produce a kind 21 (assign) stmt.
            // Mirrors parse_stmt's expr-stmt-or-assign discrimination.
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(er);
            let mut stmts: Vec<i32> = Vec::new();
            if pk(tokens, cp) == 40 {
                let mut vr: Vec<i32> = parse_expr(tokens, cp + 1, pool);
                cp = pr_pos(vr);
                stmts.push(mk3(pool, 21, pr_val(er), pr_val(vr)));
            } else {
                stmts.push(mk3(pool, 25, pr_val(er), 0));
            };
            body_list = mk_list(pool, stmts);
        };
        // emit one arm per pattern in pat_list (or-patterns).
        // For the common single-pattern case pat_list has exactly one
        // triplet so this is identical to the pre-fix behavior.
        let pcount: i64 = vec_len(pat_list) / 3;
        let mut pi: i64 = 0;
        while pi < pcount {
            let pen: str = vec_get(pat_list, pi * 3);
            let pvn: str = vec_get(pat_list, pi * 3 + 1);
            let pbn: str = vec_get(pat_list, pi * 3 + 2);
            arms.push(mk6(pool, 39, pen, pvn, pbn, body_list, guard_nid));
            pi = pi + 1;
        };
    };
    cp = cp + 1;
    let match_nid: i64 = mk3(pool, 38, pr_val(er), mk_list(pool, arms));
    node_set_span(pool, match_nid, match_span);
    return pr(cp, match_nid);
}

#[manual_drop]
fn has_main_decl(pool: Vec<i32>, items: Vec<i32>) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(items) {
        let nid: i64 = vec_get(items, i);
        if node_kind(pool, nid) == 30 && str_eq(node_field(pool, nid, 1), "main") { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn remove_main_decl(pool: Vec<i32>, items: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(items) {
        let nid: i64 = vec_get(items, i);
        let mut keep: i64 = 1;
        if node_kind(pool, nid) == 30 && str_eq(node_field(pool, nid, 1), "main") { keep = 0; };
        if node_kind(pool, nid) == 46 && str_eq(node_field(pool, nid, 1), "main") { keep = 0; };
        if keep == 1 { out.push(nid); };
        i = i + 1;
    };
    return out;
}

#[manual_drop]
fn parse_program(tokens: Vec<i32>, pool: Vec<i32>) -> Vec<i32> {
    let mut items: Vec<i32> = Vec::new(); let mut cp: i64 = 0;
    // T1.5b (v0.2.341): track `pub` keyword on top-level items.
    // Previously the `pub` token was silently swallowed. Now: when
    // we see `pub`, we set `pending_pub = 1` and re-enter the loop
    // without consuming any item. The next item we successfully
    // parse gets a marker node (kind 76 = pub_marker) emitted into
    // `items` immediately before the item itself, mirroring the
    // pattern already established for `pure fn` (kind 46). The
    // marker carries the item's name so downstream tools (the
    // visibility surface in `nuc summary`, the `nuc abi --exports`
    // walker, and T1.5c's resolver-layer enforcement) can identify
    // pub items without re-walking the source text.
    let mut pending_pub: i64 = 0;
    while pk(tokens, cp) != 0 {
        if pk(tokens, cp) == 72 {
            pending_pub = 1;
            cp = cp + 1;
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 10 {
            // extern fn — never carries `pub` (extern is its own visibility).
            let mut r: Vec<i32> = parse_extern_fn(tokens, cp + 2, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 3 && pk(tokens, cp + 2) == 52 {
            // v0.7.26 (defensive halt — Rust FFI extern block form
            // `extern "C" { fn cfn(x: i64) -> i64; ... }`). Pre-fix
            // surfaced as wrong-class `error[NR020]: expected '{', got
            // ';'` because the parser only knows the single-line form
            // `extern "C" fn name(...);` (one decl, no surrounding
            // block). Halt cleanly with a workaround pointing to the
            // bare-decl form.
            print("ERROR: Rust FFI extern block form `extern \"C\" { fn cfn(x: i64) -> i64; ... }` is not yet supported in Nucleor. Pre-v0.7.26 surfaced as wrong-class `error[NR020]: expected '{', got ';'`.");
            print("       Workaround: drop the surrounding block — declare each FFI fn with the supported single-line form `extern \"C\" fn cfn(x: i64) -> i64;` (one decl per line, no `{` / `}`).");
            panic("nucleor: extern block form `extern \"C\" { ... }` not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 3 && pk(tokens, cp + 2) == 10 {
            // `extern "C" fn name(...)` (or any ABI string).
            // Pre-v0.3.112, the parser only recognized bare `extern fn`,
            // so the canonical Rust form `extern "C" fn abs(x: i64) -> i64;`
            // cascaded into 4+ parse errors. The ABI string is accepted
            // and discarded — Nucleor's only ABI today is the C calling
            // convention used by all extern declarations, so the explicit
            // marker is informational. Skip ABI literal then call into
            // parse_extern_fn at the `fn` token.
            let mut r: Vec<i32> = parse_extern_fn(tokens, cp + 3, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 73 {
            //  canonical Rust form
            // `const fn double(x: i64) -> i64 { return x * 2; }` was
            // pre-fix rejected with `error[NR020]: parse error at byte
            // 9: expected ':', got identifier` because parse_const_decl
            // (called below for the const-decl path) expects a name +
            // `:` + type after `const`. The `fn` keyword (token 10)
            // tripped the `:`-expector. Wrong-class diagnostic — adopter
            // doesn't see "const fn not yet supported" but a confusing
            // parse error pointing at byte 9. Halt at parse with a clean
            // diag.
            if pk(tokens, cp + 1) == 10 {
                print("ERROR: `const fn` declarations are not yet supported in Nucleor. Workaround: drop the `const` qualifier — Nucleor v0.6 does not yet evaluate fn bodies at compile time, so a `const fn` is informationally equivalent to a regular `fn` in this version.");
                panic("nucleor: `const fn` decl not yet supported (see ERROR diagnostic above)");
            };
            let mut r: Vec<i32> = parse_const_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 74 {
            let mut r: Vec<i32> = parse_type_alias_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 17 {
            let mut r: Vec<i32> = parse_struct_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 62 {
            let mut r: Vec<i32> = parse_enum_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 66 {
            let mut r: Vec<i32> = parse_trait_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 67 {
            // impl blocks don't carry pub (the items inside do).
            let mut r: Vec<i32> = parse_impl_block(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "pure") == 1 && pk(tokens, cp + 1) == 10 {
            // pure fn — parse as fn_decl, mark name with __pure_ prefix internally
            let mut r: Vec<i32> = parse_fn_decl(tokens, cp + 2, pool);
            let fn_nid: i64 = pr_val(r);
            if str_eq(node_field(pool, fn_nid, 1), "main") == 1 && has_main_decl(pool, items) == 1 { items = remove_main_decl(pool, items); };
            // Tag function as pure by storing a marker node (kind 46).
            items.push(mk2(pool, 46, node_field(pool, fn_nid, 1)));
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, fn_nid, 1))); pending_pub = 0; };
            items.push(fn_nid);
            cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 10 {
            let mut r: Vec<i32> = parse_fn_decl(tokens, cp + 1, pool);
            let fn_nid: i64 = pr_val(r);
            if str_eq(node_field(pool, fn_nid, 1), "main") == 1 && has_main_decl(pool, items) == 1 { items = remove_main_decl(pool, items); };
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, fn_nid, 1))); pending_pub = 0; };
            items.push(fn_nid);
            cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "async") == 1 && pk(tokens, cp + 1) == 10 {
            // v0.7.71 (defensive halt — Rust `async fn name() -> T { ... }`).
            // Pre-fix the `async` ident was silently skipped at the
            // module-item dispatch and the fn parsed normally as a
            // sync fn. Adopters writing `let r = fetch();` got the
            // value directly (rc=42 in our probe), expecting a
            // `Future<Output = i64>` to `.await`. Silent acceptance
            // is wrong-class — the Future protocol is missing entirely
            // (no executor, no `.await`, no state-machine lowering).
            // Halt cleanly at the decl. Sister to v0.6.53 `unsafe fn`
            // halt (same shape, same dispatch lookahead).
            print("ERROR: `async fn` is not yet supported in Nucleor. Workaround: drop the `async` qualifier and call the fn synchronously; for genuinely-concurrent work, use the existing thread/queue substrate (RFC-0007 SPSC/MPSC queues or Track G atomics) until the v1.x `async`/Future/executor substrate lands.");
            panic("nucleor: `async fn` decl not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "unsafe") == 1 && pk(tokens, cp + 1) == 10 {
            //  `unsafe fn dangerous() -> i64 { ... }`
            // pre-fix had the `unsafe` keyword silently stripped at
            // parse — the fn decl parsed normally without the marker.
            // Visible-as-noop for adopters auditing translated Rust
            // code. Halt at the decl with a clean diag naming the
            // forward-roadmap status (Nucleor v0.6 has no checked
            // operations to opt out of, so `unsafe fn` is informational
            // only; the silent-strip removed the visual signal).
            print("ERROR: `unsafe fn` is not yet supported in Nucleor. Workaround: drop the `unsafe` qualifier (Nucleor v0.6 has no checked operations to opt out of, so the qualifier is informational-only).");
            panic("nucleor: `unsafe fn` decl not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "unsafe") == 1 && (pk(tokens, cp + 1) == 66 || pk(tokens, cp + 1) == 67) {
            // sister halt to v0.6.53 — `unsafe trait T { ... }`
            // (token 66) and `unsafe impl T for S { ... }` (token 67)
            // were ALSO silent-stripped pre-fix (the `unsafe` ident was
            // just skipped in the dispatch). Same audit-loss as v0.6.53.
            // Halt cleanly with the same drop-qualifier workaround.
            let v761_kw: str = if pk(tokens, cp + 1) == 66 { "trait" } else { "impl" };
            print(str_concat("ERROR: `unsafe ", str_concat(v761_kw, "` (e.g. `unsafe ", str_concat(v761_kw, " T { ... }`) is not yet supported in Nucleor. Visible-as-noop for adopters auditing translated Rust code. Sister to v0.6.53 `unsafe fn` halt.")))));
            print("       Workaround: drop the `unsafe` qualifier — Nucleor v0.7 has no `unsafe`-gated operations to opt out of, so the qualifier is informational-only at the decl level (the v1 trait/impl-soundness substrate may give it meaning later).");
            panic(str_concat("nucleor: `unsafe ", str_concat(v761_kw, "` decl not yet supported (see ERROR diagnostic above)")));
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "extern") == 1 && pk(tokens, cp + 1) == 1 && str_eq(pkv(tokens, cp + 1), "crate") == 1 {
            // v0.7.73 (defensive halt — `extern crate <name>;`).
            // Pre-fix this was silently dropped at module-item
            // dispatch — the `extern` ident matched no branch, the
            // dispatcher fell through, and the trailing tokens
            // (`crate`, `<name>`, `;`) were skipped. Adopters
            // translating Rust 2015-style or workspace-style code
            // got NO signal that the dependency wasn't actually
            // pulled in; later `crate_name::path` use sites failed
            // opaquely. Halt cleanly. Sister to v0.7.71 `async fn`
            // and v0.6.53 `unsafe fn` halts (same module-item
            // silent-strip class).
            print("ERROR: `extern crate <name>;` declarations are not yet supported in Nucleor. Workaround: Nucleor's current substrate uses the `import \"path\"` form for cross-file inclusion (RFC-0018 phase 1); there is no Cargo-style external-crate dependency manager yet.");
            panic("nucleor: `extern crate ...` decl not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "macro_rules") == 1 && pk(tokens, cp + 1) == 38 {
            // v0.7.73 (defensive halt — `macro_rules! name { ... }`).
            // corrected token check from 97 (`?`) to 38 (`!`).
            // Pre-v0.8.28 the check used token kind 97 (which is `?`,
            // not `!`), so the halt NEVER fired — the `macro_rules! name
            // { ... }` block was silently swallowed at module scope as
            // before v0.7.73. v0.8.28 fixes the token constant so the
            // halt properly fires on `macro_rules` + `!` (token 38).
            print("ERROR: `macro_rules!` declarative-macro definitions are not yet supported in Nucleor. Workaround: rewrite the macro body as a regular fn (Nucleor's metaprogramming substrate is fn-call + the small set of built-in macros — `print!`, `println!`, `format!`, `vec!`, `panic!`).");
            panic("nucleor: `macro_rules!` decl not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "union") == 1 {
            //  pre-fix `union U { a: i64,
            // b: f64 }` was silently swallowed at parse time then
            // `U { a: 42 }` at use site emitted "unknown struct U" —
            // confusing late error pointing at the use site, not the
            // unsupported decl. Now halt at the decl with a clean
            // diagnostic naming the v0.6 boundary.
            print("ERROR: `union` items are not yet supported in Nucleor. Workaround: model the union shape with an `enum` (Rust-canonical for tagged unions) or a `struct` whose fields cover the largest variant if you need the raw bit-pattern reuse.");
            panic("nucleor: `union` decl at module scope not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "static") == 1 {
            // `static NAME: T = VALUE;` at module scope was silently
            // dropped — the module-item parser skipped the unknown
            // `static` token then advanced past `NAME: T = VALUE;`
            // token-by-token. Use sites of `NAME` lowered as `@NAME`
            // global references and clang link failed with the opaque
            // `error: use of undefined value '@NAME'`. Surface a clean
            // error at parse time pointing at the `const` workaround
            // (literal init) or fn-wrap (computed init).
            print("ERROR: `static` items are not yet supported in Nucleor. Workarounds: for a literal value use `const NAME: T = VALUE;` (module-scope constant, evaluated at compile time); for a computed value wrap in a fn that returns it (`fn name() -> T { return VALUE; }`).");
            panic("nucleor: `static` decl at module scope not yet supported (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 11 {
            // `let` is a statement-level binding — it cannot
            // appear at module scope. Pre-v0.3.73, the parser silently
            // skipped the entire `let NAME: T = EXPR;` token-by-token
            // and downstream codegen emitted `@NAME` references that
            // failed at clang link with "use of undefined value '@NAME'"
            // when main referenced the binding. Surface a clear
            // diagnostic with the canonical workaround (`const`) and
            // skip the let-stmt cleanly so the rest of the program
            // still parses for any other diagnostics the user needs.
            // was print + skip to `;` — silent miscompute,
            // the `let` binding was dropped from the module surface
            // and any downstream reference produced broken IR.
            print("ERROR: `let` is not allowed at module scope. Use `const NAME: T = VALUE;` for module-scope constants. (`let` is statement-only — the parser previously dropped this declaration silently and emitted broken IR.)");
            panic("nucleor: `let` at module scope not allowed (see ERROR diagnostic above)");
        }
        else if pk(tokens, cp) == 13 || pk(tokens, cp) == 15 || pk(tokens, cp) == 16 || pk(tokens, cp) == 18 || pk(tokens, cp) == 19 || pk(tokens, cp) == 56 || pk(tokens, cp) == 63 {
            // catch other statement-level keywords at module
            // scope. `if` (13), `while` (15), `return` (16), `break` (18),
            // `continue` (19), `for` (56), `match` (63) all belong inside
            // fn bodies — at module scope they have no
            // (v0.3.141: `loop` removed from this list since it became
            // a contextual identifier-keyword; the contextual form is
            // already caught at parse_stmts level. Top-level `loop {`
            // would now silently skip — accepted limitation since the
            // top-level form has zero usage in the codebase.)
            // meaning and the pre-v0.3.75 silent fall-through dropped
            // them token-by-token. Surface a clear diagnostic so the
            // user sees their malformed top-level construct named
            // explicitly. Recovery: skip to the next semicolon (43)
            // OR the next opening brace (40) — whichever comes first
            // — so block-form constructs (`if/while/loop { ... }`)
            // get cleaned up in one go rather than dribbling broken
            // body tokens through the rest of the program.
            // was print + skip-block recover — silent
            // miscompute, the stmt at module scope was dropped and
            // any reference to its bindings produced broken IR.
            print("ERROR: statement-level keyword at module scope. Only `fn`, `extern fn`, `pure fn`, `const`, `type`, `struct`, `enum`, `trait`, `impl`, and `pub` (with the above) are allowed as top-level items. Move statement-level constructs into a fn body.");
            panic("nucleor: statement-level keyword at module scope (see ERROR diagnostic above)");
        }
        else {
            // Lane 4 / F-003 / F-014: top-level garbage silent-accept.
            // Pre-fix any token that didn't match a top-level item rule
            // was silently skipped one-by-one. With F-066 lex-time
            // tightening, byte-level garbage already errors. But valid
            // tokens at the wrong scope (`;`, `}`, `)`, stray int
            // literal, etc.) still slipped through this catch-all.
            // Now: emit PARSE-TOP-001.
            let v_top_tt_pt001: i64 = pk(tokens, cp);
            // EOF (0) shouldn't reach here (the `while pk != 0` guard
            // should keep us out), but be defensive.
            if v_top_tt_pt001 == 0 { break; };
            let v_top_byte_pt001: i64 = tok_pos_at(tokens, cp);
            let v_top_lc_pt001: Vec<i32> = tokens_linecol_at_byte(tokens, v_top_byte_pt001);
            let v_top_line_pt001: i64 = vec_get(v_top_lc_pt001, 0);
            let v_top_col_pt001: i64 = vec_get(v_top_lc_pt001, 1);
            // Provide an actionable hint based on token shape.
            let v_top_hint: str = if v_top_tt_pt001 == 53 { ", possibly an extra closing `}` (F-014)" }
                else if v_top_tt_pt001 == 51 { ", possibly an extra closing `)`" }
                else if v_top_tt_pt001 == 55 { ", possibly an extra closing `]`" }
                else if v_top_tt_pt001 == 43 { ", stray `;` at module scope" }
                else if v_top_tt_pt001 == 2 { " (integer literal)" }
                else if v_top_tt_pt001 == 3 { " (string literal)" }
                else { "" };
            let v_top_loc_pt001: str = str_concat(str_from_int(v_top_line_pt001), str_concat(":", str_from_int(v_top_col_pt001)));
            panic(str_concat("error[PARSE-TOP-001]: unexpected ", str_concat(tok_name(v_top_tt_pt001), str_concat(v_top_hint, str_concat(" at line ", str_concat(v_top_loc_pt001, str_concat(" (byte ", str_concat(str_from_int(v_top_byte_pt001), ")")))))));
        };
    };
    return pr(cp, mk_list(pool, items));
}


