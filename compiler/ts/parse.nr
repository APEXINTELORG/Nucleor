// =====================================================
// PARSER (from T29, unchanged)
// =====================================================
extern fn nuc_node_kind(pool: Vec<i32>, nid: i64) -> i64;
extern fn nuc_node_field(pool: Vec<i32>, nid: i64, idx: i64) -> i64;
extern fn nuc_list_len(pool: Vec<i32>, lid: i64) -> i64;
extern fn nuc_list_get(pool: Vec<i32>, lid: i64, idx: i64) -> i64;

fn expect_tok(tokens: Vec<i32>, pos: i64, tt: i64) -> i64 {
    if pk(tokens, pos) != tt {
        // mirror s1's v0.4.78 NR020 close — was print +
        // return pos+1, silently producing a likely-broken AST.
        let tok: Vec<i32> = tok_at(tokens, pos);
        let byte_pos: i64 = vec_get(tok, 2);
        panic(str_concat("error[NR020]: parse error at token position ", str_concat(str_from_int(byte_pos), str_concat(": expected token ", str_concat(str_from_int(tt), str_concat(" got ", str_concat(str_from_int(pk(tokens, pos)), " — pre-fix this printed a warning and continued, producing a likely-broken binary."))))));
    };
    return pos + 1;
}












#[manual_drop]
fn parse_primary(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let tt: i64 = pk(tokens, pos);
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
        return pr(cp, mk3(pool, 1, pkv(tokens, pos), tok_int_suffix_code_at(tokens, pos)));
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
    if tt == 3 { return pr(pos + 1, mk2(pool, 2, pkv(tokens, pos))); };
    if tt == 52 { return parse_passthrough_block_expr(tokens, pos, pool); };
    if tt == 50 {
        let mut r: Vec<i32> = parse_expr(tokens, pos + 1, pool);
        let mut cp: i64 = pr_pos(r);
        if pk(tokens, cp) != 44 {
            return pr(expect_tok(tokens, cp, 51), pr_val(r));
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
        };
        cp = expect_tok(tokens, cp, 55);
        return pr(cp, mk2(pool, 47, mk_list(pool, items)));
    };
    // if-expression
    if tt == 13 { let mut r: Vec<i32> = parse_if(tokens, pos + 1, pool); return r; };
    if tt == 63 { let mut r: Vec<i32> = parse_match_stmt(tokens, pos + 1, pool); return r; };
    // removed dead tt==76 (restricts) parse_primary branch.
    // See compiler-side notes — kw classification was dropped to close
    // the silent-miscompute hazard for user fns named `restricts`.
    // tt == 77 (unsafe) branch is dead code since classify_kw
    // no longer maps unsafe to 77. The block form `unsafe { ... }` is
    // unused in any source the tools-suite parses.
    // dead tt == 78/79 branches removed (wrapping/saturating).
    // re-add `saturating { ... }` parse for tools_suite so
    // `nuc check`/`nuc test` over a file using saturating blocks
    // recognize the syntax (per-op lowering only fires inside this
    // block — without the parse, the block opens an ambiguous expr).
    if tt == 1 && str_eq(pkv(tokens, pos), "saturating") == 1 && pk(tokens, pos + 1) == 52 {
        return parse_wrapped_block_expr(tokens, pos + 1, pool, 2);
    };
    if tt == 1 {
        let name: i64 = pkv(tokens, pos);
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
            if pk(tokens, cp2 + 1) == 53 || (pk(tokens, cp2 + 1) == 1 && pk(tokens, cp2 + 2) == 42) {
                return parse_struct_init(tokens, pos, pool);
            };
        };
        if pk(tokens, cp2) == 46 {
            let qname: i64 = pkv(tokens, cp2 + 1);
            if pk(tokens, cp2 + 2) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, cp2 + 3, pool);
                return pr(pr_pos(ar), mk4(pool, 12, name, qname, pr_val(ar)));
            } else {
                let mut empty: Vec<i32> = Vec::new();
                return pr(cp2 + 2, mk4(pool, 12, name, qname, mk_list(pool, empty)));
            };
        };
        if pk(tokens, cp2) == 50 { let mut ar: Vec<i32> = parse_args(tokens, cp2 + 1, pool); return pr(pr_pos(ar), mk3(pool, 7, name, pr_val(ar))); };
        return pr(cp2, mk2(pool, 3, name));
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
        if pk(tokens, cp) == 52 {
            cp = expect_tok(tokens, cp, 52);
            let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(br), 53);
            return pr(cp, mk3(pool, 42, mk_list(pool, cparams), pr_val(br)));
        } else {
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(er);
            let mut rbody: Vec<i32> = Vec::new();
            rbody.push(mk2(pool, 22, pr_val(er)));
            return pr(cp, mk3(pool, 42, mk_list(pool, cparams), mk_list(pool, rbody)));
        };
    };
    return pr(pos + 1, mk2(pool, 1, 0));
}


#[manual_drop]
fn parse_unary(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    if pk(tokens, pos) == 21 { let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool); return pr(pr_pos(r), mk2(pool, 5, pr_val(r))); };
    if pk(tokens, pos) == 38 { let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool); return pr(pr_pos(r), mk2(pool, 6, pr_val(r))); };
    if pk(tokens, pos) == 22 {
        let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool);
        return pr(pr_pos(r), mk2(pool, 92, pr_val(r)));
    };
    if pk(tokens, pos) == 82 {
        let mut cp: i64 = pos + 1;
        let mut is_mut: i64 = 0;
        if pk(tokens, cp) == 12 { is_mut = 1; cp = cp + 1; };
        let mut r: Vec<i32> = parse_unary(tokens, cp, pool);
        if is_mut == 1 { return pr(pr_pos(r), mk2(pool, 91, pr_val(r))); };
        return pr(pr_pos(r), mk2(pool, 90, pr_val(r)));
    };
    let mut base: Vec<i32> = parse_postfix(tokens, pos, pool);
    let mut cp: i64 = pr_pos(base);
    let mut node: i64 = pr_val(base);
    let mut as_match: i64 = 0;
    if pk(tokens, cp) == 1 {
        if str_eq(pkv(tokens, cp), "as") == 1 { as_match = 1; };
    };
    while as_match == 1 {
        cp = cp + 1;
        let mut tr: Vec<i32> = parse_type(tokens, cp);
        cp = pr_pos(tr);
        node = mk3(pool, 99, node, pr_val(tr));
        as_match = 0;
        if pk(tokens, cp) == 1 {
            if str_eq(pkv(tokens, cp), "as") == 1 { as_match = 1; };
        };
    };
    return pr(cp, node);
}

#[manual_drop]
fn parse_cmp(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_add(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    let mut tt: i64 = pk(tokens, cp);
    while tt == 32 || tt == 33 || tt == 34 || tt == 35 {
        r = parse_add(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, tt, node, pr_val(r)); tt = pk(tokens, cp);
    };
    return pr(cp, node);
}



#[manual_drop]
fn parse_type(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    if pk(tokens, pos) == 82 {
        let mut cp: i64 = pos + 1;
        let mut prefix: str = "&";
        // T2.5 (v0.2.351): skip optional lifetime annotation `'a` after `&`.
        if pk(tokens, cp) == 98 { cp = cp + 1; };
        if pk(tokens, cp) == 12 { prefix = "&mut "; cp = cp + 1; };
        let mut tr: Vec<i32> = parse_type(tokens, cp);
        return pr(pr_pos(tr), str_concat(prefix, pr_val(tr)));
    };
    if pk(tokens, pos) == 54 {
        let mut tr: Vec<i32> = parse_type(tokens, pos + 1);
        let mut cp: i64 = expect_tok(tokens, pr_pos(tr), 43);
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
    let name: i64 = pkv(tokens, pos); let p2: i64 = pos + 1;
    if str_eq(name, "fixed") == 1 && pk(tokens, p2) == 32 {
        let mut cp: i64 = p2 + 1;
        let mut depth: i64 = 1;
        while depth > 0 && pk(tokens, cp) != 0 {
            if pk(tokens, cp) == 32 { depth = depth + 1; }
            else if pk(tokens, cp) == 33 { depth = depth - 1; };
            cp = cp + 1;
        };
        return pr(cp, "i64");
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
        // T2.5 (v0.2.351): accept lifetime args alongside type args (synced).
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
fn parse_let(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // 2026-05-07: #[manual_drop] mirrors s1::parse_let. Closes one of the
    // 28 still-divergent parse_* fns flagged by Phase 4's drift gate.
    // tools-suite's body uses two scoped `Vec<i32>` locals (`tr`, `er`)
    // that are consumed by `pr_pos`/`pr_val` immediately, so the
    // dangling-Vec class doesn't apply here in the same shape as
    // parse_match_stmt — but the s1-parity discipline is the goal.
    let mut is_mut: i64 = 0; let mut cp: i64 = pos;
    if pk(tokens, cp) == 12 { is_mut = 1; cp = cp + 1; };
    let name: i64 = pkv(tokens, cp); cp = cp + 1;
    let mut tstr: str = "";
    if pk(tokens, cp) == 42 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); tstr = pr_val(tr); };
    let mut init_id: i64 = 0 - 1;
    if pk(tokens, cp) == 40 { let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool); cp = pr_pos(er); init_id = pr_val(er); };
    cp = expect_tok(tokens, cp, 43);
    return pr(cp, mk5(pool, 20, name, is_mut, tstr, init_id));
}

#[manual_drop]
fn parse_const_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 42);
    let mut tr: Vec<i32> = parse_type(tokens, cp);
    cp = expect_tok(tokens, pr_pos(tr), 40);
    let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
    cp = pr_pos(er);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk4(pool, 50, name, pr_val(tr), pr_val(er)));
}






#[manual_drop]
fn parse_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let tt: i64 = pk(tokens, pos);
    if tt == 11 { return parse_let(tokens, pos + 1, pool); };
    if tt == 52 { let mut r: Vec<i32> = parse_passthrough_block_expr(tokens, pos, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 13 { let mut r: Vec<i32> = parse_if(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 15 { let mut r: Vec<i32> = parse_while_stmt(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 56 { let mut r: Vec<i32> = parse_for_stmt(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 63 { let mut r: Vec<i32> = parse_match_stmt(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    // removed dead tt==76 (restricts) parse_stmts branch.
    // Same dead-code pattern as the v0.3.138 scope/spawn removal.
    // removed dead `tt == 80 || tt == 81` branch — see
    // compiler-side notes (the `scope` / `spawn` kw classifications
    // were dropped to close the silent-miscompute hazard).
    if tt == 16 { return parse_return_stmt(tokens, pos + 1, pool); };
    if tt == 18 { let mut cp: i64 = pos + 1; if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, mk2(pool, 26, 0)); };
    if tt == 19 { let mut cp: i64 = pos + 1; if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, mk2(pool, 27, 0)); };
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(er);
    if pk(tokens, cp) == 40 { let mut vr: Vec<i32> = parse_expr(tokens, cp + 1, pool); cp = pr_pos(vr); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, mk3(pool, 21, pr_val(er), pr_val(vr))); };
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk2(pool, 25, pr_val(er)));
}


#[manual_drop]
fn parse_fn_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    // Optional generic params: fn name<T, U>(...)
    // Track gparams as Vec<i32> (mirrors s1::parse_fn_decl) and only
    // call mk_list once at the end; pre-fix this path was
    // `gparams = mk_list(pool, pr_val(gr))` which on Linux drove a
    // realloc(2^64 - small) panic in build-strict for any fn with a
    // generic param (T2.5 lifetime fixture being one). The
    // equivalence is preserved because mk_list iterates `items` once
    // and the s1 form does the same.
    // 2026-05-07 sister fix: #[manual_drop] mirrors s1::parse_fn_decl
    // (line 4068). Required so that `params` and the inner Vec returned
    // by parse_generic_params are not auto-dropped before mk6 reads them.
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
        let pn: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        params.push(mk3(pool, 41, pn, pr_val(tr)));
    };
    cp = cp + 1;
    let mut rtype: str = "void";
    if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
    if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "requires") == 1 { cp = skip_bracket_list(tokens, cp + 1); };
    cp = skip_where_clause(tokens, cp);
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
        let pn: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        params.push(mk3(pool, 41, pn, pr_val(tr)));
    };
    cp = cp + 1;
    let mut rtype: str = "void";
    if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
    if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "requires") == 1 { cp = skip_bracket_list(tokens, cp + 1); };
    cp = skip_where_clause(tokens, cp);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk4(pool, 32, name, mk_list(pool, params), rtype));
}


#[manual_drop]
fn parse_struct_init(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points at name, next is {
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
        let fn2: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut er: Vec<i32> = parse_expr(tokens, cp, pool); cp = pr_pos(er);
        inits.push(mk3(pool, 35, fn2, pr_val(er)));
    };
    cp = cp + 1;
    return pr(cp, mk3(pool, 34, name, mk_list(pool, inits)));
}


#[manual_drop]
fn parse_trait_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'trait', at the name
    // 2026-05-07: #[manual_drop] mirrors s1::parse_trait_decl. Sister 3 of T2.5.
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr); gparams = mk_list(pool, pr_val(gr));
    };
    cp = expect_tok(tokens, cp, 52); // {
    let mut methods: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        cp = expect_tok(tokens, cp, 10); // fn
        let mname: i64 = pkv(tokens, cp); cp = cp + 1;
        if pk(tokens, cp) == 54 { cp = skip_compile_time_params(tokens, cp); };
        cp = expect_tok(tokens, cp, 50); // (
        let mut params: Vec<i32> = Vec::new();
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if vec_len(params) > 0 { cp = expect_tok(tokens, cp, 44); };
            let pn: i64 = pkv(tokens, cp); cp = cp + 1;
            if pk(tokens, cp) == 42 {
                cp = cp + 1;
                let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
                params.push(mk3(pool, 41, pn, pr_val(tr)));
            } else {
                params.push(mk3(pool, 41, pn, "Self"));
            };
        };
        cp = cp + 1; // )
        let mut rtype: str = "void";
        if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
        if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "requires") == 1 { cp = skip_bracket_list(tokens, cp + 1); };
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
    // 2026-05-07: #[manual_drop] mirrors s1::parse_impl_block. Sister 4 of T2.5
    // (gparams pattern at line 1232 inside the per-method parse).
    // Supports both `impl Trait for Type { ... }` and `impl Type { ... }`
    let mut first_name: str = pkv(tokens, pos);
    let mut trait_name: str = "";
    let mut type_name: str = first_name;
    let mut cp: i64 = pos + 1;
    if pk(tokens, cp) == 32 {
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
    cp = expect_tok(tokens, cp, 52); // {
    let mut methods: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
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
                    params.push(mk3(pool, 41, pn, pr_val(tr)));
                };
            };
        };
        cp2 = cp2 + 1; // )
        let mut rtype: str = "void";
        if pk(tokens, cp2) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp2 + 1); cp2 = pr_pos(tr); rtype = pr_val(tr); };
        if pk(tokens, cp2) == 1 && str_eq(pkv(tokens, cp2), "requires") == 1 { cp2 = skip_bracket_list(tokens, cp2 + 1); };
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
fn parse_match_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos is after 'match', at the expression
    // 2026-05-07: #[manual_drop] mirrors s1::parse_match_stmt. Without it
    // the local `arms: Vec<i32>` accumulator (and intermediate per-arm
    // `stmts: Vec<i32>`) get auto-dropped before mk_list iterates them,
    // which surfaces as the latent T2.1-class panic ("node_field node OOB:
    // index 3, len 3" / "index out of bounds: len 1 / index 1") on
    // fixtures with 3+ match arms. Same dangling-Vec bug class as the
    // T2.5 / parse_struct_decl / parse_enum_decl / parse_trait_decl /
    // parse_impl_block fixes.
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = expect_tok(tokens, pr_pos(er), 52); // {
    let mut arms: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(arms) > 0 && pk(tokens, cp) == 44 { cp = cp + 1; };
        if pk(tokens, cp) == 53 || pk(tokens, cp) == 0 { break; };
        let att: i64 = pk(tokens, cp);
        let mut ename: str = "";
        let mut vname: str = "";
        let mut binding: str = "";
        if att == 2 {
            // T2.1 (v0.2.347): integer literal pattern with optional
            // range extension (`1..=9`, `1..10`). Synced from
            // nucleor_s1_compiler.nr — see that file for the encoding.
            let lo_val: i64 = pkv(tokens, cp);
            cp = cp + 1;
            let next_tok: i64 = pk(tokens, cp);
            if next_tok == 96 || next_tok == 58 {
                let mut inclusive: i64 = 0;
                if next_tok == 96 {
                    inclusive = 1;
                    cp = cp + 1;
                } else {
                    if pk(tokens, cp + 1) == 58 { cp = cp + 2; }
                    else { cp = cp + 1; };
                };
                if pk(tokens, cp) == 2 {
                    let hi_raw: i64 = pkv(tokens, cp);
                    cp = cp + 1;
                    let hi_norm: i64 = if inclusive == 1 { hi_raw } else { hi_raw - 1 };
                    if lo_val <= hi_norm {
                        ename = "__range";
                    } else {
                        ename = "__range_bad";
                    };
                    vname = lo_val;
                    binding = str_from_int(hi_norm);
                } else {
                    ename = "__int";
                    vname = lo_val;
                };
            } else {
                ename = "__int";
                vname = lo_val;
            };
        } else if att == 3 {
            // String literal pattern
            ename = "__str";
            vname = pkv(tokens, cp);
            cp = cp + 1;
        } else if att == 1 && str_eq(pkv(tokens, cp), "_") {
            // Wildcard pattern
            ename = "__wild";
            cp = cp + 1;
        } else if att == 1 && pk(tokens, cp + 1) == 46 {
            // Enum pattern: EnumName::Variant or EnumName::Variant(b1, b2, ...)
            // sync from nucleor_s1_compiler.nr:2110-2119.
            // Pre-sync: this site only handled a single binding -- the second
            // and later bindings cascaded into "expected token 51 got 44"
            // parse errors, so multi-payload variants like Pair(a, b) failed
            // through the harness path even though the s1 compile path was
            // already correct. The multi-bindings are encoded as a single
            // pipe-separated string ("a|b|c") which the typed-payload binder
            // (match_bind_payloads at s1:9177) already understands.
            ename = pkv(tokens, cp);
            cp = expect_tok(tokens, cp + 1, 46); // ::
            vname = pkv(tokens, cp); cp = cp + 1;
            if pk(tokens, cp) == 50 {
                cp = cp + 1;
                let mut first: i64 = 1;
                while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
                    if first == 0 { cp = expect_tok(tokens, cp, 44); };
                    let bn: str = pkv(tokens, cp); cp = cp + 1;
                    if first == 1 { binding = bn; } else { binding = str_concat(binding, str_concat("|", bn)); };
                    first = 0;
                };
                cp = expect_tok(tokens, cp, 51); // )
            } else if pk(tokens, cp) == 52 {
                let mut br: Vec<i32> = parse_match_binding_block(tokens, cp + 1);
                binding = pr_val(br);
                cp = pr_pos(br);
            };
        } else if att == 1 && pk(tokens, cp + 1) == 45 {
            // Enum pattern: EnumName.Variant { binding }
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
        } else if att == 1 && (str_eq(pkv(tokens, cp), "Some") == 1 || str_eq(pkv(tokens, cp), "None") == 1 || str_eq(pkv(tokens, cp), "Ok") == 1 || str_eq(pkv(tokens, cp), "Err") == 1) {
            vname = pkv(tokens, cp);
            if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
            else { ename = "Option"; };
            cp = cp + 1;
            if pk(tokens, cp) == 50 {
                cp = cp + 1;
                if pk(tokens, cp) != 51 { binding = pkv(tokens, cp); cp = cp + 1; };
                cp = expect_tok(tokens, cp, 51);
            } else if pk(tokens, cp) == 52 {
                let mut br: Vec<i32> = parse_match_binding_block(tokens, cp + 1);
                binding = pr_val(br);
                cp = pr_pos(br);
            };
        } else {
            // Identifier as value pattern (variable binding like wildcard)
            ename = "__wild";
            binding = pkv(tokens, cp);
            cp = cp + 1;
        };
        // s1-parity defensive halt: or-patterns (`Some(x) | None => ...`)
        // are accepted on the s1 path; the tools-suite parser rejects
        // them here with the same diagnostic shape so users get a
        // friendly error instead of a cryptic "expected `=>`" further
        // down. Tracked for unification under RFC-0063 Phase 2.0.
        if pk(tokens, cp) == 65 {
            print("ERROR: or-patterns (e.g. `Some(x) | None => body`) in match arms are not yet supported on the tools-suite parser path. Workaround: split into separate arms (`Some(x) => body, None => body`). Tracked for RFC-0063 Phase 2.0 (parser unification).");
            panic("nucleor: or-pattern in match arm not yet supported on tools-suite path");
        };
        // Optional guard: if condition
        let mut guard_nid: i64 = 0;
        if pk(tokens, cp) == 13 {
            cp = cp + 1;
            // s1-parity defensive halt: `if let PAT = expr` guards in
            // match arms are accepted on the s1 path; reject here with
            // a friendly error rather than fall into a cryptic parse
            // failure. Same tracker.
            if pk(tokens, cp) == 11 {
                print("ERROR: `if let` guard in a match arm (`x if let Some(v) = opt => ...`) is not yet supported on the tools-suite parser path. Workaround: hoist the `if let` above the `match`, or convert the guard to an explicit boolean test. Tracked for RFC-0063 Phase 2.0.");
                panic("nucleor: if-let guard in match arm not yet supported on tools-suite path");
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
            // sync from nucleor_s1_compiler.nr:2189-2207.
            // Pre-sync: arm body `return EXPR` fell into the parse_expr
            // fallback below, which left cp parked on `return`, producing
            // cascading "expected token 64 got 44/16" parse errors as the
            // next arm's pattern-parse re-entered partway through the
            // previous arm's body. Recognize Rust-style `return EXPR,` /
            // `return,` / `return X,` arm bodies as proper return stmts
            // (kind 22) so the lowering treats them as divergent.
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
            // sync from nucleor_s1_compiler.nr:2210-2215.
            // Arm body `break;` (or bare `break`).
            cp = cp + 1;
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            let mut bstmts: Vec<i32> = Vec::new();
            bstmts.push(mk2(pool, 26, 0));
            body_list = mk_list(pool, bstmts);
        } else if pk(tokens, cp) == 19 {
            // sync from nucleor_s1_compiler.nr:2217-2222.
            // Arm body `continue;` (or bare `continue`).
            cp = cp + 1;
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            let mut cstmts: Vec<i32> = Vec::new();
            cstmts.push(mk2(pool, 27, 0));
            body_list = mk_list(pool, cstmts);
        } else {
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(er);
            // s1-parity defensive halt: assignment in arm body (`pat => x = 5`)
            // is accepted on the s1 path (it lowers to a kind-21 assign stmt).
            // Reject here with a friendly error directing users to the
            // block form. Same RFC-0063 Phase 2.0 tracker.
            if pk(tokens, cp) == 40 {
                print("ERROR: assignment in a match-arm body (`pat => x = 5`) is not yet supported on the tools-suite parser path. Workaround: wrap the body in a block (`pat => { x = 5 }`). Tracked for RFC-0063 Phase 2.0.");
                panic("nucleor: assignment in match-arm body not yet supported on tools-suite path");
            };
            let mut stmts: Vec<i32> = Vec::new();
            stmts.push(mk2(pool, 25, pr_val(er)));
            body_list = mk_list(pool, stmts);
        };
        arms.push(mk6(pool, 39, ename, vname, binding, body_list, guard_nid));
    };
    cp = cp + 1;
    return pr(cp, mk3(pool, 38, pr_val(er), mk_list(pool, arms)));
}




