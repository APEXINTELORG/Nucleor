// =====================================================
// RFC-0062 G-10 Phase 2b — #[effect(...)] / #[allow_effect(...)] framework
// =====================================================
// Source-text framework that lays the groundwork for richer effect-row
// reasoning. The R05 `requires [...]` row is for adopter-defined effect
// vocabulary; G-10 ships a fixed compiler-known vocabulary so the type
// checker can reason about a small set of dangerous primitives without
// adopters opting into the full requires/restricts machinery.
// Initial vocabulary (R3 ships, R4 extends leaf inference):
//   frees           — fn (or its callees) frees a heap allocation
//   borrows_mut     — fn (or its callees) takes a &mut borrow
//   may_return_null — fn may return a null/None sentinel
//   direct_ffi      — fn (or its callees) reaches a raw FFI surface
// Two attributes:
//   #[effect(E1, E2, ...)]       declares the fn produces these effects
//   #[allow_effect(E1, E2, ...)] silences EFFECT-G10-* on this fn for
//                                the listed effects (escape hatch)
// Three diagnostics: EFFECT-G10-UNDECLARED, EFFECT-G10-MISSING-ALLOW,
// EFFECT-G10-WRONG-ROW. See is_error_code for the per-code rationale.
// Inference is conservative one-hop:
//   Pass A — leaf builtins: vec_free / hashmap_free / str_free → frees
//   Pass B — call propagation: callee with `#[effect(E)]` contributes E
// R4 will extend Pass A for direct_ffi (extern "C" call sites),
// may_return_null (raw-pointer return sites), borrows_mut (`&mut` arg
// at the call site).

#[manual_drop]
fn g10_attr_known_effect(name: str) -> i64 {
    if str_eq(name, "frees") == 1 { return 1; };
    if str_eq(name, "borrows_mut") == 1 { return 1; };
    if str_eq(name, "may_return_null") == 1 { return 1; };
    if str_eq(name, "direct_ffi") == 1 { return 1; };
    // RFC-0062 G-7 (R4) — `unsafe` block usage in fn body.
    if str_eq(name, "unsafe") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn g10_builtin_leaf_effect(callee: str) -> str {
    if str_eq(callee, "vec_free") == 1 { return "frees"; };
    if str_eq(callee, "hashmap_free") == 1 { return "frees"; };
    if str_eq(callee, "str_free") == 1 { return "frees"; };
    return "";
}

// Source-text scanner: find `#[<attr_name>(<args>)] [other-attrs/ws]* fn NAME`
// pairs. Returns flat Vec of (fn_name, effect_name) entries — each declared
// effect produces one entry, so `#[effect(frees, direct_ffi)]` on `fn foo`
// yields {("foo","frees"),("foo","direct_ffi")}. Skips `// ...` line comments
// and `"..."` string literals to avoid matching the attribute syntax inside
// quoted strings or commented-out code.
#[manual_drop]
fn g10_collect_attr_pairs(source: str, attr_name: str) -> Vec<i32> {
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let head: str = str_concat("#[", str_concat(attr_name, "("));
    let hlen: i64 = str_len(head);
    let mut p: i64 = 0;
    while p + hlen <= slen {
        let c0: i64 = str_char_at(source, p);
        if c0 == 47 && p + 1 < slen && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            if p < slen { p = p + 1; };
            continue;
        };
        if c0 == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < hlen {
            if str_char_at(source, p + k) != str_char_at(head, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 0 { p = p + 1; continue; };
        let arg_start: i64 = p + hlen;
        let mut arg_end: i64 = arg_start;
        while arg_end < slen && str_char_at(source, arg_end) != 41 { arg_end = arg_end + 1; };
        if arg_end >= slen { p = p + hlen; continue; };
        let arg_text: str = str_substring(source, arg_start, arg_end);
        let mut r: i64 = arg_end + 1;
        if r < slen && str_char_at(source, r) == 93 { r = r + 1; };
        // Walk forward past whitespace, line-comments, and other attributes
        // until we land on the fn-decl token sequence.
        let mut walking: i64 = 1;
        while walking == 1 && r < slen {
            let cc: i64 = str_char_at(source, r);
            if cc == 32 || cc == 9 || cc == 10 || cc == 13 { r = r + 1; }
            else if cc == 47 && r + 1 < slen && str_char_at(source, r + 1) == 47 {
                while r < slen && str_char_at(source, r) != 10 { r = r + 1; };
            }
            else if cc == 35 && r + 1 < slen && str_char_at(source, r + 1) == 91 {
                r = r + 2;
                let mut depth: i64 = 1;
                while r < slen && depth > 0 {
                    let dc: i64 = str_char_at(source, r);
                    if dc == 91 { depth = depth + 1; }
                    else if dc == 93 { depth = depth - 1; };
                    r = r + 1;
                };
            }
            else { walking = 0; };
        };
        // Skip optional `pub `
        if r + 4 <= slen && str_eq_at_len(source, r, "pub", 3) == 1 {
            let after_pub: i64 = if r + 3 < slen { str_char_at(source, r + 3) } else { 0 };
            if after_pub == 32 || after_pub == 9 || after_pub == 10 || after_pub == 13 {
                r = r + 3;
                while r < slen {
                    let wc: i64 = str_char_at(source, r);
                    if wc == 32 || wc == 9 || wc == 10 || wc == 13 { r = r + 1; }
                    else { break; };
                };
            };
        };
        // Skip optional `pure `
        if r + 5 <= slen && str_eq_at_len(source, r, "pure", 4) == 1 {
            let after_pure: i64 = if r + 4 < slen { str_char_at(source, r + 4) } else { 0 };
            if after_pure == 32 || after_pure == 9 || after_pure == 10 || after_pure == 13 {
                r = r + 4;
                while r < slen {
                    let wc2: i64 = str_char_at(source, r);
                    if wc2 == 32 || wc2 == 9 || wc2 == 10 || wc2 == 13 { r = r + 1; }
                    else { break; };
                };
            };
        };
        if r + 3 <= slen && str_eq_at_len(source, r, "fn", 2) == 1 {
            let after_fn: i64 = if r + 2 < slen { str_char_at(source, r + 2) } else { 0 };
            if after_fn == 32 || after_fn == 9 || after_fn == 10 || after_fn == 13 {
                r = r + 2;
                while r < slen {
                    let wc3: i64 = str_char_at(source, r);
                    if wc3 == 32 || wc3 == 9 || wc3 == 10 || wc3 == 13 { r = r + 1; }
                    else { break; };
                };
                let name_start: i64 = r;
                while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
                    r = r + 1;
                };
                if r > name_start {
                    let fname: str = str_substring(source, name_start, r);
                    let alen: i64 = str_len(arg_text);
                    let mut s: i64 = 0;
                    let mut q: i64 = 0;
                    while q <= alen {
                        let at_end: i64 = if q == alen { 1 } else { 0 };
                        let at_comma: i64 = if at_end == 0 && str_char_at(arg_text, q) == 44 { 1 } else { 0 };
                        if at_end == 1 || at_comma == 1 {
                            let raw: str = str_substring(arg_text, s, q);
                            let tok: str = strip_spaces(raw);
                            if str_len(tok) > 0 {
                                entries.push(fname);
                                entries.push(tok);
                            };
                            s = q + 1;
                        };
                        q = q + 1;
                    };
                };
            };
        };
        p = arg_end + 1;
    };
    return entries;
}

#[manual_drop]
fn g10_pairs_has(pairs: Vec<i32>, fn_name: str, eff: str) -> i64 {
    let n: i64 = vec_len(pairs);
    let mut i: i64 = 0;
    while i + 1 < n {
        if str_eq(vec_get(pairs, i), fn_name) == 1 && str_eq(vec_get(pairs, i + 1), eff) == 1 { return 1; };
        i = i + 2;
    };
    return 0;
}

#[manual_drop]
fn g10_fn_has_decl(pairs: Vec<i32>, fn_name: str) -> i64 {
    let n: i64 = vec_len(pairs);
    let mut i: i64 = 0;
    while i + 1 < n {
        if str_eq(vec_get(pairs, i), fn_name) == 1 { return 1; };
        i = i + 2;
    };
    return 0;
}

// =====================================================
// RFC-0062 G-5 + G-7 + G-9 Phase 4 — R4 FFI specializations
// =====================================================
// R4 extends R3's effect framework with three extra leaf-effect
// sources and three specialized diagnostics:
//   - extern fn call → `direct_ffi`. Specialized diag:
//     `FFI-G9-MISSING-ALLOW-DIRECT-FFI` (better message than the
//     generic EFFECT-G10-UNDECLARED — names the extern fn called).
//   - extern fn returning *const T / *mut T → `may_return_null`.
//     Specialized diag: `FFI-G5-NULL-DEREF`, fired only when the
//     adopter actually DEREFERENCES the return without a
//     `ptr_is_null(<vname>)` guard (real dataflow, not just a
//     declaration scan).
//   - `unsafe { }` block in fn body → `unsafe`. Specialized diag:
//     `UNSAFE-G7-MISSING-ALLOW`.
// Severity: error (Phase 4 hard-fail). The opt-in gate (R3) keeps
// existing rod surfaces — which call extern fns extensively without
// any G-10 attribute — unaffected. Adopters opt their file in by
// adding any `#[effect(...)]` or `#[allow_effect(...)]` attribute.

// Source-text scanner: collect every `extern fn NAME(...) -> RTYPE;`
// declaration. Returns flat Vec where each entry is a triple
// (extern_name, returns_ptr_flag_str, return_type_for_message).
// returns_ptr_flag_str = "1" if any of:
//   - the declared return type contains `*const ` or `*mut `;
//   - the decl is preceded (on prior lines, ignoring whitespace and
//     other attributes) by `#[effect(may_return_null)]`,
//     `#[effect(... , may_return_null , ...)]`, or `#[may_return_null]`.
// The attribute form is the practical opt-in for current Nucleor
// source: the `*const T` / `*mut T` syntax is gated behind a
// defensive parser halt today, so adopters use `i64` return types
// and annotate the decl with the null-return contract explicitly.
#[manual_drop]
fn g10_extern_name_may_return_null_by_default(name: str) -> i64 {
    if str_contains(name, "_alloc") == 1 { return 1; };
    if str_contains(name, "_open") == 1 { return 1; };
    if str_contains(name, "_find") == 1 { return 1; };
    if str_contains(name, "_load") == 1 { return 1; };
    if str_contains(name, "_get") == 1 { return 1; };
    if str_contains(name, "_new") == 1 { return 1; };
    if str_contains(name, "_create") == 1 { return 1; };
    if str_contains(name, "_init") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn g10_collect_extern_fn_table(source: str) -> Vec<i32> {
    let mut table: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let head: str = "extern fn ";
    let hlen: i64 = str_len(head);
    let mut p: i64 = 0;
    while p + hlen <= slen {
        let c0: i64 = str_char_at(source, p);
        if c0 == 47 && p + 1 < slen && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            if p < slen { p = p + 1; };
            continue;
        };
        if c0 == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < hlen {
            if str_char_at(source, p + k) != str_char_at(head, k) { m = 0; break; };
            k = k + 1;
        };
        let preceding_ok: i64 = if p == 0 { 1 } else {
            let pc: i64 = str_char_at(source, p - 1);
            if pc == 10 || pc == 32 || pc == 9 { 1 } else { 0 }
        };
        if m == 0 || preceding_ok == 0 { p = p + 1; continue; };
        let name_start: i64 = p + hlen;
        let mut r: i64 = name_start;
        while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
            r = r + 1;
        };
        if r == name_start { p = p + 1; continue; };
        let extern_name: str = str_substring(source, name_start, r);
        let mut e: i64 = r;
        while e < slen && str_char_at(source, e) != 59 && str_char_at(source, e) != 10 { e = e + 1; };
        let decl: str = str_substring(source, r, e);
        let mut returns_ptr: str = if str_contains(decl, "*const ") == 1 || str_contains(decl, "*mut ") == 1 { "1" } else { "0" };
        // Attribute opt-in: scan backwards from the `extern` token
        // (skipping whitespace and other attributes) and check for an
        // `#[effect(...)]` / `#[may_return_null]` annotation that names
        // the may_return_null effect.
        if str_eq(returns_ptr, "0") == 1 {
            let mut bp: i64 = p - 1;
            while bp >= 0 {
                let bc: i64 = str_char_at(source, bp);
                if bc == 32 || bc == 9 || bc == 10 || bc == 13 { bp = bp - 1; }
                else if bc == 93 {
                    // close-bracket of an attribute — walk left to its `[`
                    let attr_end: i64 = bp;
                    let mut depth: i64 = 1;
                    bp = bp - 1;
                    while bp >= 0 && depth > 0 {
                        let dc: i64 = str_char_at(source, bp);
                        if dc == 93 { depth = depth + 1; }
                        else if dc == 91 { depth = depth - 1; };
                        if depth > 0 { bp = bp - 1; };
                    };
                    if bp >= 1 && str_char_at(source, bp - 1) == 35 {
                        let attr_text: str = str_substring(source, bp + 1, attr_end);
                        if str_contains(attr_text, "may_return_null") == 1 {
                            returns_ptr = "1";
                            bp = 0 - 1;
                        } else {
                            bp = bp - 2;
                        };
                    } else {
                        bp = 0 - 1;
                    };
                }
                else { bp = 0 - 1; };
            };
        };
        let mut rtype: str = "";
        let arrow_at: i64 = str_index_of(decl, "->");
        if arrow_at >= 0 {
            let dlen: i64 = str_len(decl);
            let rt_raw: str = str_substring(decl, arrow_at + 2, dlen);
            rtype = str_trim(rt_raw);
        };
        if str_eq(returns_ptr, "0") == 1 && str_eq(rtype, "i64") == 1 && g10_extern_name_may_return_null_by_default(extern_name) == 1 {
            returns_ptr = "1";
        };
        table.push(extern_name);
        table.push(returns_ptr);
        table.push(rtype);
        p = e;
    };
    return table;
}

#[manual_drop]
fn g10_extern_lookup_returns_ptr(table: Vec<i32>, name: str) -> i64 {
    let n: i64 = vec_len(table);
    let mut i: i64 = 0;
    while i + 2 < n {
        if str_eq(vec_get(table, i), name) == 1 {
            if str_eq(vec_get(table, i + 1), "1") == 1 { return 1; };
            return 0;
        };
        i = i + 3;
    };
    return 0 - 1;
}

#[manual_drop]
fn g10_extern_is_known(table: Vec<i32>, name: str) -> i64 {
    let n: i64 = vec_len(table);
    let mut i: i64 = 0;
    while i + 2 < n {
        if str_eq(vec_get(table, i), name) == 1 { return 1; };
        i = i + 3;
    };
    return 0;
}

// True when the body contains an `unsafe {` block (not the bare
// keyword on its own — only the block prefix). Skip line comments
// and string literals so commented-out `unsafe { }` markers don't
// match.
#[manual_drop]
fn g10_body_has_unsafe_block(body: str) -> i64 {
    let slen: i64 = str_len(body);
    let pat: str = "unsafe ";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen + 1 <= slen {
        let c0: i64 = str_char_at(body, p);
        if c0 == 47 && p + 1 < slen && str_char_at(body, p + 1) == 47 {
            while p < slen && str_char_at(body, p) != 10 { p = p + 1; };
            if p < slen { p = p + 1; };
            continue;
        };
        if c0 == 34 {
            p = p + 1;
            while p < slen && str_char_at(body, p) != 34 {
                if str_char_at(body, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(body, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let preceding_ok: i64 = if p == 0 { 1 } else {
                let pc: i64 = str_char_at(body, p - 1);
                if is_alnum(pc) == 0 && pc != 95 { 1 } else { 0 }
            };
            if preceding_ok == 1 {
                let after: i64 = p + plen;
                if after < slen && str_char_at(body, after) == 123 { return 1; };
            };
        };
        p = p + 1;
    };
    return 0;
}

// First extern fn the body calls (returning its name), or "" if
// none. Used to name the offending callee in the diagnostic message.
#[manual_drop]
fn g10_body_first_extern_call(body: str, extern_table: Vec<i32>) -> str {
    let calls: Vec<i32> = restricts_extract_call_names(body);
    let cn: i64 = vec_len(calls);
    let mut ci: i64 = 0;
    while ci < cn {
        let callee: str = vec_get(calls, ci);
        if g10_extern_is_known(extern_table, callee) == 1 { return callee; };
        ci = ci + 1;
    };
    return "";
}

// First extern fn returning a raw ptr that the body calls. Used by
// the G-5 deref dataflow check.
#[manual_drop]
fn g10_body_first_extern_ptr_call(body: str, extern_table: Vec<i32>) -> str {
    let calls: Vec<i32> = restricts_extract_call_names(body);
    let cn: i64 = vec_len(calls);
    let mut ci: i64 = 0;
    while ci < cn {
        let callee: str = vec_get(calls, ci);
        if g10_extern_lookup_returns_ptr(extern_table, callee) == 1 { return callee; };
        ci = ci + 1;
    };
    return "";
}

// True when `name` appears as a standalone identifier token starting
// at offset `pos` in `s` — preceded and followed by non-identifier
// characters. Used by the G-5 violation walker to ignore substring
// hits inside a longer identifier.
#[manual_drop]
fn g10_ident_at(s: str, pos: i64, name: str) -> i64 {
    let slen: i64 = str_len(s);
    let nlen: i64 = str_len(name);
    if pos < 0 || pos + nlen > slen { return 0; };
    let mut k: i64 = 0;
    while k < nlen {
        if str_char_at(s, pos + k) != str_char_at(name, k) { return 0; };
        k = k + 1;
    };
    let before_ok: i64 = if pos == 0 { 1 } else {
        let bc: i64 = str_char_at(s, pos - 1);
        if is_alnum(bc) == 0 && bc != 95 { 1 } else { 0 }
    };
    if before_ok == 0 { return 0; };
    let after_pos: i64 = pos + nlen;
    if after_pos >= slen { return 1; };
    let ac: i64 = str_char_at(s, after_pos);
    if is_alnum(ac) == 1 || ac == 95 { return 0; };
    return 1;
}

// Find the first standalone occurrence of identifier `name` in `s`
// at or after `from`. Returns the byte offset, or -1 if none.
#[manual_drop]
fn g10_find_ident_from(s: str, from: i64, name: str) -> i64 {
    let slen: i64 = str_len(s);
    let nlen: i64 = str_len(name);
    if nlen == 0 || from + nlen > slen { return 0 - 1; };
    let mut p: i64 = if from < 0 { 0 } else { from };
    while p + nlen <= slen {
        if g10_ident_at(s, p, name) == 1 { return p; };
        p = p + 1;
    };
    return 0 - 1;
}

// G-5 deref dataflow: source-text scan for the canonical pattern
//   let <vname>: ... = <extern_returning_ptr>(...);
// followed by ANY use of `<vname>` (deref, pass-through to another
// FFI call, etc.) without a preceding `ptr_is_null(<vname>)` guard
// in the same fn body. Returns the offending binding name, or "" if
// the body is clean.
// Note on Nucleor pragmatics: raw-pointer deref syntax (`*p`) is not
// currently a user-source feature (parser halts on `*const T` /
// `*mut T` outside extern decls). The convention is i64 handles
// returned by extern fns, then passed through to other extern fns.
// "Use without guard" therefore covers both the canonical Rust
// pattern (`*p` deref) AND the i64-handle pass-through pattern
// (`other_extern(p)`). False negatives: deref reached via an alias
// of <vname>. False positives: guard expressed via `<vname> != 0`
// rather than `ptr_is_null(<vname>)`. Both forms are documented in
// the diagnostic message so adopters can switch.
#[manual_drop]
fn g10_g5_first_violation(body: str, extern_table: Vec<i32>) -> str {
    let stripped: str = strip_strings_and_line_comments(body);
    let slen: i64 = str_len(stripped);
    let mut p: i64 = 0;
    while p < slen {
        if p + 4 <= slen && str_eq_at_len(stripped, p, "let ", 4) == 1 {
            let preceding_ok: i64 = if p == 0 { 1 } else {
                let pc: i64 = str_char_at(stripped, p - 1);
                if is_alnum(pc) == 0 && pc != 95 { 1 } else { 0 }
            };
            if preceding_ok == 1 {
                let mut q: i64 = p + 4;
                if q + 4 <= slen && str_eq_at_len(stripped, q, "mut ", 4) == 1 { q = q + 4; };
                while q < slen && (str_char_at(stripped, q) == 32 || str_char_at(stripped, q) == 9) { q = q + 1; };
                let name_start: i64 = q;
                while q < slen && (is_alnum(str_char_at(stripped, q)) == 1 || str_char_at(stripped, q) == 95) { q = q + 1; };
                if q > name_start {
                    let vname: str = str_substring(stripped, name_start, q);
                    let mut eq_p: i64 = q;
                    while eq_p < slen && str_char_at(stripped, eq_p) != 61 && str_char_at(stripped, eq_p) != 59 && str_char_at(stripped, eq_p) != 10 { eq_p = eq_p + 1; };
                    if eq_p < slen && str_char_at(stripped, eq_p) == 61 {
                        let mut rhs: i64 = eq_p + 1;
                        while rhs < slen && (str_char_at(stripped, rhs) == 32 || str_char_at(stripped, rhs) == 9) { rhs = rhs + 1; };
                        let ce_start: i64 = rhs;
                        while rhs < slen && (is_alnum(str_char_at(stripped, rhs)) == 1 || str_char_at(stripped, rhs) == 95) { rhs = rhs + 1; };
                        if rhs > ce_start && rhs < slen && str_char_at(stripped, rhs) == 40 {
                            let callee: str = str_substring(stripped, ce_start, rhs);
                            if g10_extern_lookup_returns_ptr(extern_table, callee) == 1 {
                                let mut stmt_end: i64 = rhs;
                                while stmt_end < slen && str_char_at(stripped, stmt_end) != 59 { stmt_end = stmt_end + 1; };
                                let remainder_start: i64 = stmt_end + 1;
                                let guard_pat: str = str_concat("ptr_is_null(", vname);
                                let mut scan: i64 = remainder_start;
                                while scan < slen {
                                    let use_at: i64 = g10_find_ident_from(stripped, scan, vname);
                                    if use_at < 0 { scan = slen; }
                                    else {
                                        let pre_text: str = str_substring(stripped, remainder_start, use_at);
                                        if str_contains(pre_text, guard_pat) == 1 {
                                            scan = slen;
                                        } else {
                                            // Skip the use that's inside `ptr_is_null(<vname>)` itself
                                            // (i.e. the guard's argument position). Detect that by
                                            // checking the 12 chars preceding the use.
                                            let look_back: i64 = if use_at - 12 < 0 { 0 } else { use_at - 12 };
                                            let lb_text: str = str_substring(stripped, look_back, use_at);
                                            if str_contains(lb_text, "ptr_is_null(") == 1 {
                                                scan = use_at + str_len(vname);
                                            } else {
                                                return vname;
                                            };
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
        p = p + 1;
    };
    return "";
}

// Compute the set of G-10 effects this fn body produces. Pass A is leaf
// builtins (fixed table); Pass B propagates declared effects of called
// fns (one-hop; transitive enrichment is a follow-up). Returns a Vec
// of unique effect-name strings.
#[manual_drop]
fn g10_compute_body_effects(body: str, decls: Vec<i32>, extern_table: Vec<i32>) -> Vec<i32> {
    let mut produced: Vec<i32> = Vec::new();
    let calls: Vec<i32> = restricts_extract_call_names(body);
    let cn: i64 = vec_len(calls);
    let mut ci: i64 = 0;
    while ci < cn {
        let callee: str = vec_get(calls, ci);
        let leaf: str = g10_builtin_leaf_effect(callee);
        if str_len(leaf) > 0 && name_in_vec(produced, leaf) == 0 {
            produced.push(leaf);
        };
        // R4 leaf-effect extensions: extern fn calls produce
        // `direct_ffi`, plus `may_return_null` if the callee returns
        // a raw ptr.
        if g10_extern_is_known(extern_table, callee) == 1 {
            if name_in_vec(produced, "direct_ffi") == 0 { produced.push("direct_ffi"); };
            if g10_extern_lookup_returns_ptr(extern_table, callee) == 1 {
                if name_in_vec(produced, "may_return_null") == 0 { produced.push("may_return_null"); };
            };
        };
        let dn: i64 = vec_len(decls);
        let mut di: i64 = 0;
        while di + 1 < dn {
            if str_eq(vec_get(decls, di), callee) == 1 {
                let eff: str = vec_get(decls, di + 1);
                if g10_attr_known_effect(eff) == 1 && name_in_vec(produced, eff) == 0 {
                    produced.push(eff);
                };
            };
            di = di + 2;
        };
        ci = ci + 1;
    };
    // R4 leaf-effect extension: `unsafe { }` block in body produces
    // `unsafe` effect.
    if g10_body_has_unsafe_block(body) == 1 {
        if name_in_vec(produced, "unsafe") == 0 { produced.push("unsafe"); };
    };
    return produced;
}

#[manual_drop]
fn enforce_g10_effects(diags: Vec<i32>, source: str) -> Vec<i32> {
    // Cheap textual gate: skip the full per-fn analysis when neither
    // attribute syntax appears anywhere in the source. The dominant
    // case is "no opt-in" so this keeps the existing verify budget
    // intact.
    // Pre-fix the silent
    // early-return left adopters with `gates off` as the implicit
    // default for unannotated source — the headline claim
    // "RFC-0062 closed all 11 G-gates at hard-error severity in
    // v1.0" was structurally honest only for files that opted in.
    // Now: when no opt-in attribute exists BUT the source has at
    // least one extern fn or unsafe block, surface a warning-level
    // disclosure that the framework is inactive for this TU. This
    // is the Phase A remediation from the audit (info diag), at
    // warning severity so adopters cannot miss it; Phase B is the
    // `#[file_effects(default_on)]` outer-attribute opt-in for
    // file-level enable, scheduled post-v1.0.
    if str_contains(source, "#[effect(") == 0 && str_contains(source, "#[allow_effect(") == 0 {
        let stripped_g10_cliff: str = strip_strings_and_line_comments(source);
        if str_contains(stripped_g10_cliff, "extern fn ") == 1 || str_contains(stripped_g10_cliff, "unsafe {") == 1 {
            diag_add_ex(diags, "info", "effect", "EFFECT-G10-OPT-IN-CLIFF", "this translation unit has no `#[effect(...)]` / `#[allow_effect(...)]` attributes; per RFC-0062 G-10 the effect-tracking framework (G-5 may_return_null / G-7 unsafe / G-9 direct_ffi / G-10 wrong-row) is INACTIVE for this file. Pre-v1.0 silent-default-off behavior is now disclosed at info severity whenever an extern or unsafe surface is present. To activate the framework, add `#[effect(<E>)]` rows to fns that produce effects (vocabulary: `frees`, `borrows_mut`, `may_return_null`, `direct_ffi`, `unsafe`), or `#[allow_effect(<E>)]` to silence intentional uses. Phase B (post-v1.0) will add `#[file_effects(default_on)]` for file-level enable.", "<file>", 1, 1, "");
        };
        return diags;
    };
    let decls: Vec<i32> = g10_collect_attr_pairs(source, "effect");
    let allows: Vec<i32> = g10_collect_attr_pairs(source, "allow_effect");
    // Real-attribute gate: g10_collect_attr_pairs skips `// ...` line
    // comments and `"..."` string literals. If both pair sets are empty
    // the textual hits were comments / docs (the compiler self-source
    // documents the attribute family in is_error_code) — bail out so
    // unrelated fns don't trip on their leaf vec_free / hashmap_free
    // calls.
    if vec_len(decls) == 0 && vec_len(allows) == 0 { return diags; };
    // Unknown effect-name detection.
    // Pre-fix, `#[effect(frees, banana)]` silently dropped `banana`
    // because the per-fn loops gated on `g10_attr_known_effect(eff)
    // == 1`. Typos like `may_retrun_null` were lost — the runtime
    // never received the intended constraint. Walk both pair sets
    // and emit EFFECT-G10-UNKNOWN-NAME (error severity) for each
    // unknown name, with the closed list of known effects in the
    // diagnostic text.
    let mut g10u_di: i64 = 0;
    while g10u_di + 1 < vec_len(decls) {
        let g10u_fn: str = vec_get(decls, g10u_di);
        let g10u_eff: str = vec_get(decls, g10u_di + 1);
        if g10_attr_known_effect(g10u_eff) == 0 {
            let g10u_lc: Vec<i32> = find_linecol_in_source(source, g10u_fn, g10u_fn);
            let g10u_lcl: i64 = vec_get(g10u_lc, 0);
            let g10u_lcc: i64 = vec_get(g10u_lc, 1);
            let g10u_msg: str = str_concat("unknown effect name `", str_concat(g10u_eff, str_concat("` in #[effect(...)] on function `", str_concat(g10u_fn, "`. Per RFC-0062 G-10 Phase 4 (v1.0): the closed list of known effects is `frees`, `borrows_mut`, `may_return_null`, `direct_ffi`, `unsafe`. Pre-v1.0 unknown names were silently ignored, so typos like `may_retrun_null` lost the intended constraint. Either fix the spelling or remove the entry."))));
            diag_add_ex(diags, "error", "effect", "EFFECT-G10-UNKNOWN-NAME", g10u_msg, g10u_fn, g10u_lcl, g10u_lcc, "");
        };
        g10u_di = g10u_di + 2;
    };
    let mut g10u_ai: i64 = 0;
    while g10u_ai + 1 < vec_len(allows) {
        let g10u_afn: str = vec_get(allows, g10u_ai);
        let g10u_aeff: str = vec_get(allows, g10u_ai + 1);
        if g10_attr_known_effect(g10u_aeff) == 0 {
            let g10u_alc: Vec<i32> = find_linecol_in_source(source, g10u_afn, g10u_afn);
            let g10u_alcl: i64 = vec_get(g10u_alc, 0);
            let g10u_alcc: i64 = vec_get(g10u_alc, 1);
            let g10u_amsg: str = str_concat("unknown effect name `", str_concat(g10u_aeff, str_concat("` in #[allow_effect(...)] on function `", str_concat(g10u_afn, "`. Per RFC-0062 G-10 Phase 4 (v1.0): the closed list of known effects is `frees`, `borrows_mut`, `may_return_null`, `direct_ffi`, `unsafe`. Pre-v1.0 unknown names were silently ignored. Either fix the spelling or remove the entry."))));
            diag_add_ex(diags, "error", "effect", "EFFECT-G10-UNKNOWN-NAME", g10u_amsg, g10u_afn, g10u_alcl, g10u_alcc, "");
        };
        g10u_ai = g10u_ai + 2;
    };
    let extern_table: Vec<i32> = g10_collect_extern_fn_table(source);
    let table: Vec<i32> = collect_fn_table(source);
    let tn: i64 = vec_len(table);
    let mut ti: i64 = 0;
    while ti + 2 < tn {
        let fn_name: str = vec_get(table, ti);
        let body_raw: str = vec_get(table, ti + 2);
        let body: str = strip_strings_and_line_comments(body_raw);
        let produced: Vec<i32> = g10_compute_body_effects(body, decls, extern_table);
        let has_decl: i64 = g10_fn_has_decl(decls, fn_name);
        let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
        let lcl: i64 = vec_get(lc, 0);
        let lcc: i64 = vec_get(lc, 1);
        // Pass 1: every produced effect must be declared OR allowed.
        // R4 specialization: when the unhandled effect is direct_ffi
        // / unsafe / may_return_null, fire the specialized R4 code
        // instead of the generic EFFECT-G10-UNDECLARED.
        let pn: i64 = vec_len(produced);
        let mut pi: i64 = 0;
        while pi < pn {
            let eff: str = vec_get(produced, pi);
            if g10_attr_known_effect(eff) == 1 {
                let declared: i64 = g10_pairs_has(decls, fn_name, eff);
                let allowed: i64 = g10_pairs_has(allows, fn_name, eff);
                if declared == 0 && allowed == 0 {
                    let is_g9: i64 = if str_eq(eff, "direct_ffi") == 1 { 1 } else { 0 };
                    let is_g7: i64 = if str_eq(eff, "unsafe") == 1 { 1 } else { 0 };
                    let is_g5: i64 = if str_eq(eff, "may_return_null") == 1 { 1 } else { 0 };
                    if is_g9 == 1 {
                        let extern_called: str = g10_body_first_extern_call(body, extern_table);
                        let g9_a: str = str_concat("function `", fn_name);
                        let g9_b: str = str_concat(g9_a, "` calls extern fn `");
                        let g9_c: str = str_concat(g9_b, extern_called);
                        let g9: str = str_concat(g9_c, "` (direct FFI surface) but carries no #[effect(direct_ffi)] declaration and no #[allow_effect(direct_ffi)] silencer. Per RFC-0062 G-9 (Phase 4), every fn that crosses the FFI boundary must declare the `direct_ffi` effect or explicitly allow it.");
                        diag_add_ex(diags, "error", "effect", "FFI-G9-MISSING-ALLOW-DIRECT-FFI", g9, fn_name, lcl, lcc, "");
                    } else if is_g7 == 1 {
                        let g7_a: str = str_concat("function `", fn_name);
                        let g7: str = str_concat(g7_a, "` contains an `unsafe { }` block but carries no #[effect(unsafe)] declaration and no #[allow_effect(unsafe)] silencer. Per RFC-0062 G-7 (Phase 4), every fn with an unsafe block must declare the `unsafe` effect or explicitly allow it.");
                        diag_add_ex(diags, "error", "effect", "UNSAFE-G7-MISSING-ALLOW", g7, fn_name, lcl, lcc, "");
                    } else if is_g5 == 1 {
                        // G-5 does not fire as missing-allow; instead
                        // the deref-after-call dataflow (below)
                        // emits FFI-G5-NULL-DEREF only on actual
                        // unguarded deref. Skipping here also avoids
                        // a noise emit from the generic EFFECT-G10-*
                        // path.
                    } else if has_decl == 0 {
                        let m1a: str = str_concat("function `", fn_name);
                        let m1b: str = str_concat(m1a, "` produces effect `");
                        let m1c: str = str_concat(m1b, eff);
                        let m1: str = str_concat(m1c, "` (per RFC-0062 G-10) but carries no #[effect(...)] declaration. Declare the effect on the fn header, or add #[allow_effect(<E>)] when intentional.");
                        diag_add_ex(diags, "error", "effect", "EFFECT-G10-UNDECLARED", m1, fn_name, lcl, lcc, "");
                    } else {
                        let m2a: str = str_concat("function `", fn_name);
                        let m2b: str = str_concat(m2a, "` produces effect `");
                        let m2c: str = str_concat(m2b, eff);
                        let m2: str = str_concat(m2c, "` which is missing from the #[effect(...)] row (per RFC-0062 G-10). Add it to the row, or silence with #[allow_effect(<E>)] when intentional.");
                        diag_add_ex(diags, "error", "effect", "EFFECT-G10-MISSING-ALLOW", m2, fn_name, lcl, lcc, "");
                    };
                };
            };
            pi = pi + 1;
        };
        // Pass 2: declared effects must be produced (over-decl detector)
        if has_decl == 1 {
            let dn: i64 = vec_len(decls);
            let mut di: i64 = 0;
            while di + 1 < dn {
                if str_eq(vec_get(decls, di), fn_name) == 1 {
                    let eff: str = vec_get(decls, di + 1);
                    if g10_attr_known_effect(eff) == 1 && name_in_vec(produced, eff) == 0 {
                        let m3a: str = str_concat("function `", fn_name);
                        let m3b: str = str_concat(m3a, "` declares effect `");
                        let m3c: str = str_concat(m3b, eff);
                        let m3: str = str_concat(m3c, "` in #[effect(...)] but the body produces no operation that yields that effect (per RFC-0062 G-10 wrong-row check). Remove the effect from the row, or add the operation that justifies it.");
                        diag_add_ex(diags, "error", "effect", "EFFECT-G10-WRONG-ROW", m3, fn_name, lcl, lcc, "");
                    };
                };
                di = di + 2;
            };
        };
        // Pass 3 (R4): G-5 deref-after-extern-call dataflow check.
        // Runs only when the fn body actually called an extern fn
        // with a raw-ptr return type — otherwise nothing to check.
        // The check fires regardless of whether the fn has an
        // #[allow_effect(may_return_null)] silencer because the
        // null-deref bug is a sound dataflow violation, not a
        // declaration discipline issue. Adopters who genuinely want
        // to bypass the guard for an audited unsafe-but-non-null
        // path can use #[allow_effect(may_return_null)] on the fn
        // PLUS structure the call so the deref happens inside an
        // `unsafe { }` block (the unsafe check then asks for its own
        // allow_effect). The check is limited to one violation per
        // fn to avoid diagnostic-storm on repeated patterns.
        let g5_vname: str = g10_g5_first_violation(body, extern_table);
        if str_len(g5_vname) > 0 {
            let g5_allow_g5: i64 = g10_pairs_has(allows, fn_name, "may_return_null");
            if g5_allow_g5 == 0 {
                let extern_called5: str = g10_body_first_extern_ptr_call(body, extern_table);
                let g5_a: str = str_concat("function `", fn_name);
                let g5_b: str = str_concat(g5_a, "` dereferences `");
                let g5_c: str = str_concat(g5_b, g5_vname);
                let g5_d: str = str_concat(g5_c, "` (returned from extern fn `");
                let g5_e: str = str_concat(g5_d, extern_called5);
                let g5: str = str_concat(g5_e, "`) without a dominating `ptr_is_null(<binding>)` guard. Per RFC-0062 G-5 (Phase 4), raw-pointer returns from extern fns may be NULL on failure; the deref must be preceded by `if ptr_is_null(p) { panic(...); }` on the same control-flow path.");
                diag_add_ex(diags, "error", "effect", "FFI-G5-NULL-DEREF", g5, fn_name, lcl, lcc, "");
            };
        };
        ti = ti + 3;
    };
    return diags;
}

// R05 Phase 2b first slice. Minimum
// builtin → effect map for direct restricts-block enforcement.
// Covers the print-family I/O surface (io.write), the byte input
// builtin (io.read), and the channel constructor (sync). Returns
// the empty string for any other identifier so the caller can fall
// through to the requires-row table or treat the call as outside
// the enforced subset. Future expansion (file/network builtins,
// thread spawn, ambient time/random) is a Phase 2b table grow.
#[manual_drop]
fn restricts_builtin_effect(name: str) -> str {
    if str_eq(name, "print") == 1 { return "io.write"; };
    if str_eq(name, "println") == 1 { return "io.write"; };
    if str_eq(name, "print_int") == 1 { return "io.write"; };
    if str_eq(name, "print_str") == 1 { return "io.write"; };
    if str_eq(name, "print_int64") == 1 { return "io.write"; };
    if str_eq(name, "putchar") == 1 { return "io.write"; };
    if str_eq(name, "getchar") == 1 { return "io.read"; };
    if str_eq(name, "channel") == 1 { return "sync"; };
    return "";
}

// True iff any token in `row` overlaps `eff`. "Overlap" is symmetric
// covering: row_token == eff, or eff is a sub-effect of row_token
// (`row_token + "." + ...` prefix), or row_token is a sub-effect of
// eff. The third arm matters for restricts: deny [io.read] must trap
// a callee declared `requires [io]` because the broader callee row
// could exercise io.read.
#[manual_drop]
fn restricts_row_covers_effect(row: str, eff: str) -> i64 {
    let rlen: i64 = str_len(row);
    let elen: i64 = str_len(eff);
    if rlen == 0 || elen == 0 { return 0; };
    let mut start: i64 = 0;
    let mut p: i64 = 0;
    while p <= rlen {
        let at_end: i64 = if p == rlen { 1 } else { 0 };
        let at_comma: i64 = if at_end == 0 && str_char_at(row, p) == 44 { 1 } else { 0 };
        if at_end == 1 || at_comma == 1 {
            let tok: str = strip_spaces(str_substring(row, start, p));
            let tlen: i64 = str_len(tok);
            if tlen > 0 {
                if str_eq(tok, eff) == 1 { return 1; };
                if elen > tlen && str_starts_with(eff, str_concat(tok, ".")) == 1 { return 1; };
                if tlen > elen && str_starts_with(tok, str_concat(eff, ".")) == 1 { return 1; };
            };
            start = p + 1;
        };
        p = p + 1;
    };
    return 0;
}

// Returns the first effect named in `callee_row` that overlaps the
// `deny_row`, or "" if none. Symmetric to `effect_row_first_missing`
// (used for requires propagation) but inverted: requires asks "what
// did the caller forget to declare?", restricts asks "what does the
// callee touch that the deny list forbids?"
#[manual_drop]
fn effect_row_intersect_first(deny_row: str, callee_row: str) -> str {
    let clen: i64 = str_len(callee_row);
    let mut start: i64 = 0;
    let mut p: i64 = 0;
    while p <= clen {
        let at_end: i64 = if p == clen { 1 } else { 0 };
        let at_comma: i64 = if at_end == 0 && str_char_at(callee_row, p) == 44 { 1 } else { 0 };
        if at_end == 1 || at_comma == 1 {
            let eff: str = strip_spaces(str_substring(callee_row, start, p));
            if str_len(eff) > 0 && restricts_row_covers_effect(deny_row, eff) == 1 { return eff; };
            start = p + 1;
        };
        p = p + 1;
    };
    return "";
}

// Namespaced constructors such as `Vec::new()` are not visible to
// `restricts_extract_call_names` as `Vec::new`; that scanner sees
// the suffix `new`. Keep this body-level builtin table small and
// fixture-backed.
#[manual_drop]
fn restricts_body_builtin_effect(deny_row: str, body: str) -> str {
    if str_len(body) == 0 { return ""; };
    let stripped: str = strip_strings_and_line_comments(body);
    if restricts_row_covers_effect(deny_row, "alloc") == 1 || restricts_row_covers_effect(deny_row, "Alloc") == 1 {
        if str_index_of(stripped, "Vec::new") >= 0 { return "alloc"; };
        if str_index_of(stripped, "Box::new") >= 0 { return "alloc"; };
    };
    return "";
}

// Walks `body` once and returns the list of identifiers that appear
// in call position (`IDENT(`). Strings and `//` line comments are
// stripped first to avoid matching identifiers inside string literals
// or commented-out code. Every appearance is recorded — the caller
// is responsible for de-duplication if needed. Identifier tokens
// followed only by whitespace before the open paren still count.
#[manual_drop]
fn restricts_extract_call_names(body: str) -> Vec<i32> {
    let mut names: Vec<i32> = Vec::new();
    let stripped: str = strip_strings_and_line_comments(body);
    let slen: i64 = str_len(stripped);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(stripped, p);
        let at_word_start: i64 = if is_alpha(c) == 1 || c == 95 {
            if p == 0 { 1 } else {
                let b: i64 = str_char_at(stripped, p - 1);
                if is_alnum(b) == 0 && b != 95 { 1 } else { 0 }
            }
        } else { 0 };
        if at_word_start == 1 {
            let name_start: i64 = p;
            let mut q: i64 = p;
            while q < slen && (is_alnum(str_char_at(stripped, q)) == 1 || str_char_at(stripped, q) == 95) { q = q + 1; };
            let mut r: i64 = q;
            while r < slen && is_ws(str_char_at(stripped, r)) == 1 { r = r + 1; };
            if r < slen && str_char_at(stripped, r) == 40 {
                names.push(str_substring(stripped, name_start, q));
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return names;
}

// v0843 R05 consolidation spike: one source-walk that captures every
// same-file user fn's name + declared `requires [...]` row + body in
// a single pass, returning a flat [name, requires_row, body, ...]
// table. Replaces the v0840+v0841 split where
// `collect_requires_effect_rows` + `collect_fn_bodies` walked the
// source independently. Pre-v0843 the restricts-block enforcement
// paid for two full line-by-line walks per `restricts [...]` block
// detected in code; post-v0843 it pays for one. `pure fn` decls
// receive an empty requires-row entry so the requires-row enforcement
// never picks them up. The lazy build inside
// `enforce_restricts_block_effects` keeps the compiler self-build
// (where all `restricts` mentions sit in strings or comments) from
// paying this cost at all.
#[manual_drop]
fn collect_fn_table(source: str) -> Vec<i32> {
    let mut table: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            let compact_line: str = strip_spaces(line);
            let is_pure_decl: i64 = if str_starts_with(compact_line, "purefn") == 1 { 1 } else { if str_starts_with(compact_line, "pubpurefn") == 1 { 1 } else { 0 } };
            let mut h: i64 = p;
            while h < slen && str_char_at(source, h) != 123 && str_char_at(source, h) != 59 { h = h + 1; };
            let header: str = str_substring(source, p, h);
            let req_row: str = if is_pure_decl == 1 { "" } else { extract_keyword_row(header, "requires") };
            if h < slen && str_char_at(source, h) == 123 {
                let body_start: i64 = h + 1;
                let mut q: i64 = h + 1;
                let mut depth: i64 = 1;
                while q < slen && depth > 0 {
                    let cc: i64 = str_char_at(source, q);
                    if cc == 123 { depth = depth + 1; };
                    if cc == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body: str = str_substring(source, body_start, q - 1);
                table.push(fn_name);
                table.push(req_row);
                table.push(body);
                p = q;
            } else {
                p = eol + 1;
            };
        } else {
            p = eol + 1;
        };
    };
    return table;
}

#[manual_drop]
fn lookup_fn_row_in_table(table: Vec<i32>, name: str) -> str {
    let n: i64 = vec_len(table);
    let mut i: i64 = 0;
    while i + 2 < n {
        if str_eq(vec_get(table, i), name) == 1 { return vec_get(table, i + 1); };
        i = i + 3;
    };
    return "";
}

// Returns 1 iff multiple table entries share
// `name` AND have distinct `requires [...]` rows. Source-text effect
// enforcement walks the resolved single source via substring match
// (`callee(`), which catches `obj.method(...)` call sites accidentally
// because `.method(` contains `method(`. That accidental coverage made
// same-file method/impl effect enforcement empirically work for the
// unique-method-name cases (method-effect fixture set:
// row mismatch, body builtin transitive, restricts block reaching
// method I/O — all already fire EFF-001/EFF-003).
// The accidental coverage breaks down when two `impl` blocks define
// methods with the SAME unqualified name and DIFFERENT rows: the
// substring search matches every same-name body call regardless of
// receiver type, and the row check uses whichever row was iterated
// first (or the broadest in the loop). Without AST-level receiver
// resolution, the source-text path cannot pick the correct impl.
// Two outcomes are possible:
//   - keep current behavior → false-positive EFF-001 on the un-rowed
//     impl when an unrelated rowed impl shares the name (blocks valid
//     adopter code);
//   - skip enforcement when names collide on rows → false-negative on
//     the genuinely-violating call (silent fall-through, but only for
//     this narrow ambiguity surface).
// Per project posture (`feedback_nucleor_launch_quality.md`) blocking
// valid adopter code is the worse failure mode; receiver-type-aware
// resolution is Phase 4 / RFC-0033 broader effect-row subtyping. This
// helper lets callers fail-OPEN cleanly: enforcement skips ambiguous
// names, and the EFF-G123 banner discloses the surface so adopters
// have a knob (rename methods, or wait for Phase 4).
// Returns 0 (no ambiguity) when:
//   - the name appears once,
//   - the name appears multiple times but every entry has the same row.
// Returns 1 only when at least two entries share the name AND have
// requires-rows whose textual contents differ.
#[manual_drop]
fn name_has_distinct_rows_in_table(table: Vec<i32>, name: str) -> i64 {
    let n: i64 = vec_len(table);
    let mut first_row: str = "";
    let mut found_first: i64 = 0;
    let mut i: i64 = 0;
    while i + 2 < n {
        if str_eq(vec_get(table, i), name) == 1 {
            let row: str = vec_get(table, i + 1);
            if found_first == 0 {
                first_row = row;
                found_first = 1;
            } else {
                if str_eq(first_row, row) == 0 { return 1; };
            };
        };
        i = i + 3;
    };
    return 0;
}

#[manual_drop]
fn lookup_fn_body_in_table(table: Vec<i32>, name: str) -> str {
    let n: i64 = vec_len(table);
    let mut i: i64 = 0;
    while i + 2 < n {
        if str_eq(vec_get(table, i), name) == 1 { return vec_get(table, i + 2); };
        i = i + 3;
    };
    return "";
}

#[manual_drop]
fn name_in_vec(haystack: Vec<i32>, needle: str) -> i64 {
    let n: i64 = vec_len(haystack);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(haystack, i), needle) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

// Bounded same-file transitive scan: returns the first effect found
// in `body` (directly or via a same-file user-fn body within
// `depth_remaining` hops) that overlaps `deny_row`, or "" if none.
// Visited-by-name dedup prevents cycles and re-walks.
// v0843: takes a unified `table` of [name, requires_row, body, ...]
// triples (built once via `collect_fn_table`) instead of separate
// rows + bodies vectors — same observable behaviour at half the
// per-build source-walk cost. The depth cap is raised to 8 because
// visited-by-name dedup already guarantees termination in O(N) per
// chain; 8 hops covers practical deep chains while still bounding
// diagnostic noise on pathological inputs.
#[manual_drop]
fn restricts_transitive_check(deny_row: str, body: str, table: Vec<i32>, depth_remaining: i64, visited: Vec<i32>) -> str {
    let calls: Vec<i32> = restricts_extract_call_names(body);
    let cn: i64 = vec_len(calls);
    let mut ci: i64 = 0;
    while ci < cn {
        let callee: str = vec_get(calls, ci);
        let b_eff: str = restricts_builtin_effect(callee);
        if str_len(b_eff) > 0 {
            if restricts_row_covers_effect(deny_row, b_eff) == 1 {
                return str_concat(b_eff, str_concat("` via call chain ending in `", str_concat(callee, "()`")));
            };
        } else {
            let n: i64 = vec_len(table);
            let mut ri: i64 = 0;
            let mut callee_in_table: i64 = 0;
            let mut callee_row: str = "";
            let mut callee_body: str = "";
            while ri + 2 < n && callee_in_table == 0 {
                if str_eq(vec_get(table, ri), callee) == 1 {
                    callee_in_table = 1;
                    callee_row = vec_get(table, ri + 1);
                    callee_body = vec_get(table, ri + 2);
                };
                ri = ri + 3;
            };
            if callee_in_table == 1 {
                // When the callee name is shared by
                // multiple impls/fns with distinct rows, the substring-search
                // approach can't pick which impl a receiver-typed call site
                // resolves to. Fail-open on the row check (skip the
                // intersect) but still walk the body transitively when an
                // un-rowed entry was picked first — preserves restricts
                // depth=8 reach while avoiding false-positive EFF-003.
                let callee_ambig: i64 = name_has_distinct_rows_in_table(table, callee);
                if str_len(callee_row) > 0 && callee_ambig == 0 {
                    let h: str = effect_row_intersect_first(deny_row, callee_row);
                    if str_len(h) > 0 {
                        return str_concat(h, str_concat("` via call chain ending in `", str_concat(callee, "()`")));
                    };
                } else {
                    if depth_remaining > 0 && name_in_vec(visited, callee) == 0 && str_len(callee_body) > 0 {
                        visited.push(callee);
                        let nested: str = restricts_transitive_check(deny_row, callee_body, table, depth_remaining - 1, visited);
                        if str_len(nested) > 0 { return nested; };
                    };
                };
            };
        };
        ci = ci + 1;
    };
    return "";
}

// Source-level pre-pass for block-form `restricts [...] { ... }`
// real enforcement. v0840 (R05 Phase 2b first slice) handled direct
// builtin / direct user-row violations only. v0841 adds bounded
// same-file transitive enforcement: for each direct call inside a
// `restricts [DENY] { BODY }` whose callee is an un-rowed user fn,
// the scanner walks the callee's body up to depth=3 hops and
// emits `error[EFF-003]` if any reachable call hits a builtin
// effect or rowed user-fn whose row overlaps DENY. The existing
// substring-level `restricts_body_builtin_effect` (Vec::new /
// Box::new alloc detection) still runs first.
// Two callee classes are checked at every depth:
//   1. Builtins listed in `restricts_builtin_effect` — print-family
//      I/O, char-level I/O, and `channel`.
//   2. Same-file user fns declared with a `requires [...]` row, via
//      `collect_requires_effect_rows` + `effect_row_intersect_first`.
// Un-rowed user fn callees are walked one hop deeper subject to the
// depth budget. Whole-program inference across module boundaries,
// methods, closures, and higher-order effects stay queued.
// Performance shape: the bodies table is built lazily only when an
// actual code-position `restricts [` is found, so the compiler
// self-build (where all `restricts` mentions live in strings or
// comments) pays nothing extra over v0840.
// Whole-program inference, cross-module propagation, methods,
// closures, and higher-order effects stay queued for Phase 2b.
#[manual_drop]
fn enforce_restricts_block_effects(diags: Vec<i32>, source: str) -> Vec<i32> {
    if str_index_of(source, "restricts") < 0 { return diags; };
    let mut table: Vec<i32> = Vec::new();
    let mut table_built: i64 = 0;
    let slen: i64 = str_len(source);
    let kw: str = "restricts";
    let klen: i64 = str_len(kw);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(source, p);
        if c == 47 && p + 1 < slen && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            if p < slen { p = p + 1; };
            continue;
        };
        if c == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        if c == 39 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 39 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        if p + klen <= slen && str_eq_at_len(source, p, kw, klen) == 1 {
            let before_ok: i64 = if p == 0 { 1 } else {
                let b: i64 = str_char_at(source, p - 1);
                if is_alnum(b) == 0 && b != 95 { 1 } else { 0 }
            };
            let mut q: i64 = p + klen;
            while q < slen && is_ws(str_char_at(source, q)) == 1 { q = q + 1; };
            if before_ok == 1 && q < slen && str_char_at(source, q) == 91 {
                let deny_start: i64 = q + 1;
                let mut deny_end: i64 = deny_start;
                let mut bd: i64 = 1;
                while deny_end < slen && bd > 0 {
                    let cc: i64 = str_char_at(source, deny_end);
                    if cc == 91 { bd = bd + 1; }
                    else if cc == 93 { bd = bd - 1; };
                    if bd > 0 { deny_end = deny_end + 1; };
                };
                if deny_end < slen {
                    let deny_row: str = strip_spaces(str_substring(source, deny_start, deny_end));
                    let mut bp: i64 = deny_end + 1;
                    while bp < slen && is_ws(str_char_at(source, bp)) == 1 { bp = bp + 1; };
                    if bp < slen && str_char_at(source, bp) == 123 {
                        let body_start: i64 = bp + 1;
                        let mut be: i64 = bp + 1;
                        let mut bdepth: i64 = 1;
                        while be < slen && bdepth > 0 {
                            let cc: i64 = str_char_at(source, be);
                            if cc == 123 { bdepth = bdepth + 1; }
                            else if cc == 125 { bdepth = bdepth - 1; };
                            if bdepth > 0 { be = be + 1; };
                        };
                        if be < slen {
                            let body: str = str_substring(source, body_start, be);
                            let mut emitted: i64 = 0;
                            let body_eff: str = restricts_body_builtin_effect(deny_row, body);
                            if str_len(body_eff) > 0 {
                                let msg: str = str_concat("block body uses builtin effect `", str_concat(body_eff, str_concat("` denied by `restricts [", str_concat(deny_row, "]`"))));
                                let lc: Vec<i32> = find_linecol_in_source(source, "restricts", "restricts");
                                diag_add_ex(diags, "error", "effect", "EFF-003", msg, "restricts", vec_get(lc, 0), vec_get(lc, 1), "");
                                emitted = 1;
                            };
                            if emitted == 0 {
                                if table_built == 0 {
                                    table = collect_fn_table(source);
                                    table_built = 1;
                                };
                                let mut visited: Vec<i32> = Vec::new();
                                let trans_hit: str = restricts_transitive_check(deny_row, body, table, 8, visited);
                                if str_len(trans_hit) > 0 {
                                    let msg: str = str_concat("block uses effect `", str_concat(trans_hit, str_concat(" denied by `restricts [", str_concat(deny_row, "]`"))));
                                    let lc: Vec<i32> = find_linecol_in_source(source, "restricts", "restricts");
                                    diag_add_ex(diags, "error", "effect", "EFF-003", msg, "restricts", vec_get(lc, 0), vec_get(lc, 1), "");
                                    emitted = 1;
                                };
                            };
                            p = be + 1;
                            continue;
                        };
                    };
                };
            };
        };
        p = p + 1;
    };
    return diags;
}

#[manual_drop]
fn collect_headers_with_effect(source: str, effect_name: str, pat: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    if str_contains(source, "with") == 0 { return fns; };
    let slen: i64 = str_len(source);
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 39 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 39 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        if str_eq_at_len(source, p, pat, plen) == 1 {
            let is_extern_fn: i64 = if str_eq(pat, "fn ") == 1 && p >= 7 && str_eq_at(source, p - 7, "extern ") == 1 { 1 } else { 0 };
            if is_extern_fn == 1 {
                p = p + plen;
            } else {
                let mut q: i64 = p + plen;
                let name_start: i64 = q;
                while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
                if q > name_start {
                    let name: str = str_substring(source, name_start, q);
                    let mut h: i64 = q;
                    while h < slen && str_char_at(source, h) != 123 && str_char_at(source, h) != 59 { h = h + 1; };
                    if h > p {
                        let header: str = str_substring(source, p, h);
                        if rt_header_has_effect(header, effect_name) == 1 {
                            fns.push(name);
                        } else {
                            str_free(name);
                        };
                        str_free(header);
                    };
                    p = h + 1;
                } else {
                    p = p + 1;
                };
            };
        } else {
            p = p + 1;
        };
    };
    return fns;
}

#[manual_drop]
fn collect_fns_with_effect(source: str, effect_name: str) -> Vec<i32> {
    return collect_headers_with_effect(source, effect_name, "fn ");
}

#[manual_drop]
fn collect_externs_with_effect(source: str, effect_name: str) -> Vec<i32> {
    return collect_headers_with_effect(source, effect_name, "extern fn ");
}

#[manual_drop]
fn collect_no_alloc_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[no_alloc]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        // Skip the rest of any line that starts with `//` so the
        // pattern in a comment (including this comment when the
        // s1 compiles itself) doesn't get treated as a real
        // attribute. Doc comments above the next fn would
        // otherwise collide with their own subject.
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        // Skip string literals — `let pat: str = "#[no_alloc]"`
        // would otherwise be matched as a real attribute. Walk
        // through escape sequences (`\"` is not the closing
        // quote). The s1 itself contains the literal `#[no_alloc]`
        // in a string for use by this scanner; without this guard
        // the s1 false-positives on its own helper fn.
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            // Skip whitespace until we hit the next 'fn '.
            while q + 3 <= slen {
                let c0: i64 = str_char_at(source, q);
                let c1: i64 = str_char_at(source, q + 1);
                let c2: i64 = str_char_at(source, q + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    // 'fn ' — read the name identifier.
                    q = q + 3;
                    let name_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                        q = q + 1;
                    };
                    if q > name_start {
                        let name: str = str_substring(source, name_start, q);
                        fns.push(name);
                    };
                    p = q;
                    break;
                };
                q = q + 1;
            };
            if q + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    rt_string_vec_append(fns, collect_fns_with_effect(source, "no_alloc"));
    return fns;
}

// v0.4.244 RFC-0006 substrate — `#[require(EXPR)]` source-text
// scanner. Mirrors `collect_no_alloc_fns` shape: scans the source
// for the literal pattern, walks paren-balanced expression text,
// captures the next `fn NAME` identifier, and stores a flat
// (fn_name, expr_text) pair in the result Vec. Lex-time the `#[
// require(...)]` is discarded as an unknown attribute, so the
// parser never sees it; this side-channel scanner recovers the
// information.
// Returns a flat Vec of alternating (fn_name, expr_text) entries:
//   [name0, expr0, name1, expr1, ...]
// String-literal and `//` comment skipping mirror the no_alloc
// pattern so the s1 compiler doesn't false-positive on the literal
// pattern strings inside its own scanner code.
#[manual_drop]
fn collect_fn_requires(source: str) -> Vec<i32> {
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[require(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            // p points at `#`. p + plen points at the first byte of the
            // expression (just past the `(`). Walk paren-balanced text
            // to find the closing `)` of the require expression.
            let expr_start: i64 = p + plen;
            let mut q: i64 = expr_start;
            let mut paren_depth: i64 = 1;
            while q < slen && paren_depth > 0 {
                let cc: i64 = str_char_at(source, q);
                if cc == 34 {
                    q = q + 1;
                    while q < slen && str_char_at(source, q) != 34 {
                        if str_char_at(source, q) == 92 && q + 1 < slen { q = q + 2; }
                        else { q = q + 1; };
                    };
                    if q < slen { q = q + 1; };
                    continue;
                };
                if cc == 40 { paren_depth = paren_depth + 1; }
                else if cc == 41 { paren_depth = paren_depth - 1; if paren_depth == 0 { break; }; };
                q = q + 1;
            };
            let expr_end: i64 = q;
            // Skip past the `)]` and any whitespace, then look for `fn `.
            let mut r: i64 = expr_end + 1;
            if r < slen && str_char_at(source, r) == 93 { r = r + 1; };
            while r + 3 <= slen {
                let c0: i64 = str_char_at(source, r);
                let c1: i64 = str_char_at(source, r + 1);
                let c2: i64 = str_char_at(source, r + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    r = r + 3;
                    let name_start: i64 = r;
                    while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
                        r = r + 1;
                    };
                    if r > name_start && expr_end > expr_start {
                        let fname: str = str_substring(source, name_start, r);
                        let etext: str = str_substring(source, expr_start, expr_end);
                        entries.push(fname);
                        entries.push(etext);
                    };
                    // advance p past the closing `]` of
                    // this attribute (not past the fn name) so a
                    // subsequent #[require(...)] before the same
                    // fn still gets captured by the outer loop.
                    p = expr_end + 2;
                    break;
                };
                r = r + 1;
            };
            if r + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return entries;
}

// Look up the `#[require(...)]` expression text for a given fn
// name. Returns "" if no require attribute was attached. Linear
// scan; the require list is small in practice.
#[manual_drop]
fn lookup_fn_require_expr(requires: Vec<i32>, fn_name: str) -> str {
    let n: i64 = vec_len(requires);
    let mut i: i64 = 0;
    while i + 1 < n {
        let nm: str = vec_get(requires, i);
        if str_eq(nm, fn_name) == 1 { return vec_get(requires, i + 1); };
        i = i + 2;
    };
    return "";
}

// v0.4.246 RFC-0006 substrate — `#[ensure(EXPR)]` source-text
// scanner. Mirror of collect_fn_requires but for the ensure
// attribute (postcondition checked at fn exit).
#[manual_drop]
fn collect_fn_ensures(source: str) -> Vec<i32> {
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[ensure(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let expr_start: i64 = p + plen;
            let mut q: i64 = expr_start;
            let mut paren_depth: i64 = 1;
            while q < slen && paren_depth > 0 {
                let cc: i64 = str_char_at(source, q);
                if cc == 34 {
                    q = q + 1;
                    while q < slen && str_char_at(source, q) != 34 {
                        if str_char_at(source, q) == 92 && q + 1 < slen { q = q + 2; }
                        else { q = q + 1; };
                    };
                    if q < slen { q = q + 1; };
                    continue;
                };
                if cc == 40 { paren_depth = paren_depth + 1; }
                else if cc == 41 { paren_depth = paren_depth - 1; if paren_depth == 0 { break; }; };
                q = q + 1;
            };
            let expr_end: i64 = q;
            let mut r: i64 = expr_end + 1;
            if r < slen && str_char_at(source, r) == 93 { r = r + 1; };
            while r + 3 <= slen {
                let c0: i64 = str_char_at(source, r);
                let c1: i64 = str_char_at(source, r + 1);
                let c2: i64 = str_char_at(source, r + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    r = r + 3;
                    let name_start: i64 = r;
                    while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
                        r = r + 1;
                    };
                    if r > name_start && expr_end > expr_start {
                        let fname: str = str_substring(source, name_start, r);
                        let etext: str = str_substring(source, expr_start, expr_end);
                        entries.push(fname);
                        entries.push(etext);
                    };
                    // same multiple-attr support as
                    // collect_fn_requires.
                    p = expr_end + 2;
                    break;
                };
                r = r + 1;
            };
            if r + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return entries;
}

// v0.4.251 RFC-0006 — `old(expr)` snapshot text rewriter.
// Walks the ensure expression's TEXT, finds every `old(...)`
// pattern (paren-balanced, string-literal aware), and rewrites
// each to a synthesized binding name `__old_<fn_name>_<idx>`.
// The inner expression text per `old(...)` is captured separately.
// Returns a flat Vec encoding [rewritten_text, n, synth0, inner0,
// synth1, inner1, ...] where n is the number of olds.
// At lower-time, the pre-pass lex+parses each inner into the AST
// pool, and lower_fn pre-evaluates each inner at fn entry storing
// to an alloca. The rewritten ensure expression's `__old_*`
// var-refs then resolve to loads from those allocas.
#[manual_drop]
fn rewrite_old_in_ensure(ens_text: str, fn_name: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(ens_text);
    let mut sb: i64 = sb_new();
    let mut inners: Vec<i32> = Vec::new();
    let mut idx_counter: i64 = 0;
    let mut p: i64 = 0;
    while p < slen {
        // Skip string literals — never rewrite inside.
        if str_char_at(ens_text, p) == 34 {
            sb_append_char_at(sb, ens_text, p);
            p = p + 1;
            while p < slen && str_char_at(ens_text, p) != 34 {
                if str_char_at(ens_text, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, ens_text, p); sb_append_char_at(sb, ens_text, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, ens_text, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append_char_at(sb, ens_text, p); p = p + 1; };
            continue;
        };
        // Detect `old(` only when preceded by non-identifier
        // (so e.g. `old_value` is NOT matched). Check prev char.
        let mut is_id_boundary: i64 = 1;
        if p > 0 {
            let prev: i64 = str_char_at(ens_text, p - 1);
            if is_alnum(prev) == 1 || prev == 95 { is_id_boundary = 0; };
        };
        if is_id_boundary == 1 && p + 4 <= slen
            && str_char_at(ens_text, p) == 111
            && str_char_at(ens_text, p + 1) == 108
            && str_char_at(ens_text, p + 2) == 100
            && str_char_at(ens_text, p + 3) == 40 {
            // Found `old(`. Walk paren-balanced inner.
            let inner_start: i64 = p + 4;
            let mut q: i64 = inner_start;
            let mut paren_depth: i64 = 1;
            while q < slen && paren_depth > 0 {
                let cc: i64 = str_char_at(ens_text, q);
                if cc == 34 {
                    q = q + 1;
                    while q < slen && str_char_at(ens_text, q) != 34 {
                        if str_char_at(ens_text, q) == 92 && q + 1 < slen { q = q + 2; }
                        else { q = q + 1; };
                    };
                    if q < slen { q = q + 1; };
                    continue;
                };
                if cc == 40 { paren_depth = paren_depth + 1; }
                else if cc == 41 { paren_depth = paren_depth - 1; if paren_depth == 0 { break; }; };
                q = q + 1;
            };
            let inner_end: i64 = q;
            let inner_text: str = str_substring(ens_text, inner_start, inner_end);
            let synth: str = str_concat("__old_", str_concat(fn_name, str_concat("_", str_from_int(idx_counter))));
            sb_append(sb, synth);
            inners.push(synth);
            inners.push(inner_text);
            idx_counter = idx_counter + 1;
            p = inner_end + 1;
        } else {
            sb_append_char_at(sb, ens_text, p);
            p = p + 1;
        };
    };
    out.push(sb_to_str(sb));
    out.push(str_from_int(idx_counter));
    let mut ki: i64 = 0;
    while ki + 1 < vec_len(inners) {
        out.push(vec_get(inners, ki));
        out.push(vec_get(inners, ki + 1));
        ki = ki + 2;
    };
    return out;
}

#[manual_drop]
fn lookup_fn_ensure_expr(ensures: Vec<i32>, fn_name: str) -> str {
    let n: i64 = vec_len(ensures);
    let mut i: i64 = 0;
    while i + 1 < n {
        let nm: str = vec_get(ensures, i);
        if str_eq(nm, fn_name) == 1 { return vec_get(ensures, i + 1); };
        i = i + 2;
    };
    return "";
}

// v0.4.248 RFC-0006 substrate — `#[invariant(EXPR)]` source-text
// scanner. Matches inherent impl blocks: `#[invariant(EXPR)] impl
// <Type> { ... }`. Trait-impl form (`impl Trait for Type`) is
// recognized by walking past the trait identifier and the `for`
// keyword to find the receiver type. Returns flat (type_name,
// expr_text) pairs.
#[manual_drop]
fn collect_impl_invariants(source: str) -> Vec<i32> {
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[invariant(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let expr_start: i64 = p + plen;
            let mut q: i64 = expr_start;
            let mut paren_depth: i64 = 1;
            while q < slen && paren_depth > 0 {
                let cc: i64 = str_char_at(source, q);
                if cc == 34 {
                    q = q + 1;
                    while q < slen && str_char_at(source, q) != 34 {
                        if str_char_at(source, q) == 92 && q + 1 < slen { q = q + 2; }
                        else { q = q + 1; };
                    };
                    if q < slen { q = q + 1; };
                    continue;
                };
                if cc == 40 { paren_depth = paren_depth + 1; }
                else if cc == 41 { paren_depth = paren_depth - 1; if paren_depth == 0 { break; }; };
                q = q + 1;
            };
            let expr_end: i64 = q;
            let mut r: i64 = expr_end + 1;
            if r < slen && str_char_at(source, r) == 93 { r = r + 1; };
            // Walk forward to find `impl ` keyword.
            while r + 5 <= slen {
                let c0: i64 = str_char_at(source, r);
                let c1: i64 = str_char_at(source, r + 1);
                let c2: i64 = str_char_at(source, r + 2);
                let c3: i64 = str_char_at(source, r + 3);
                let c4: i64 = str_char_at(source, r + 4);
                if c0 == 105 && c1 == 109 && c2 == 112 && c3 == 108 && c4 == 32 {
                    // `impl `. Read first identifier.
                    r = r + 5;
                    let id1_start: i64 = r;
                    while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
                        r = r + 1;
                    };
                    let id1: str = str_substring(source, id1_start, r);
                    // Skip whitespace.
                    while r < slen && (str_char_at(source, r) == 32 || str_char_at(source, r) == 9) { r = r + 1; };
                    // Optional `for <Type>` for trait impl form.
                    let mut tname: str = id1;
                    if r + 4 <= slen
                        && str_char_at(source, r) == 102
                        && str_char_at(source, r + 1) == 111
                        && str_char_at(source, r + 2) == 114
                        && str_char_at(source, r + 3) == 32 {
                        r = r + 4;
                        let id2_start: i64 = r;
                        while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
                            r = r + 1;
                        };
                        tname = str_substring(source, id2_start, r);
                    };
                    if str_len(tname) > 0 && expr_end > expr_start {
                        let etext: str = str_substring(source, expr_start, expr_end);
                        entries.push(tname);
                        entries.push(etext);
                    };
                    p = r;
                    break;
                };
                r = r + 1;
            };
            if r + 5 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return entries;
}

#[manual_drop]
fn lookup_type_invariant_expr(invariants: Vec<i32>, type_name: str) -> str {
    let n: i64 = vec_len(invariants);
    let mut i: i64 = 0;
    while i + 1 < n {
        let nm: str = vec_get(invariants, i);
        if str_eq(nm, type_name) == 1 { return vec_get(invariants, i + 1); };
        i = i + 2;
    };
    return "";
}

// v0.4.258 RFC-0006 — `#[no_check]` per-fn opt-out scanner.
// Returns flat Vec of fn names that carry the `#[no_check]`
// attribute; the require/ensure pre-passes skip these so the
// contract emit-sites produce no runtime checks. Useful for
// hot-path fns where the contract is documentation-only.
// `#[no_check]` does NOT take an expression — marker attr only.
// Pattern: `#[no_check]` followed by whitespace and `fn NAME`.
#[manual_drop]
fn collect_no_check_fns(source: str) -> Vec<i32> {
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[no_check]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut r: i64 = p + plen;
            while r + 3 <= slen {
                let c0: i64 = str_char_at(source, r);
                let c1: i64 = str_char_at(source, r + 1);
                let c2: i64 = str_char_at(source, r + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    r = r + 3;
                    let name_start: i64 = r;
                    while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
                        r = r + 1;
                    };
                    if r > name_start {
                        let fname: str = str_substring(source, name_start, r);
                        entries.push(fname);
                    };
                    p = r;
                    break;
                };
                r = r + 1;
            };
            if r + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return entries;
}

#[manual_drop]
fn name_in_no_check(no_check: Vec<i32>, fn_name: str) -> i64 {
    let n: i64 = vec_len(no_check);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(no_check, i), fn_name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

// RFC-0042 first cut — opt-in auto-drop scanner.
// Mirrors the #[no_check] marker scanner: source text is the least
// invasive way to add function-level attributes without perturbing
// the parser's AST layout. Pattern: `#[auto_drop]` followed by
// whitespace/comments/other attrs and then `fn NAME`.
#[manual_drop]
fn collect_auto_drop_fns(source: str) -> Vec<i32> {
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = str_concat("#[auto_", "drop]");
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut r: i64 = p + plen;
            while r + 3 <= slen {
                if r + 1 < slen && str_char_at(source, r) == 47 && str_char_at(source, r + 1) == 47 {
                    while r < slen && str_char_at(source, r) != 10 { r = r + 1; };
                };
                let c0: i64 = str_char_at(source, r);
                let c1: i64 = str_char_at(source, r + 1);
                let c2: i64 = str_char_at(source, r + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    r = r + 3;
                    let name_start: i64 = r;
                    while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
                        r = r + 1;
                    };
                    if r > name_start {
                        let fname: str = str_substring(source, name_start, r);
                        entries.push(fname);
                    };
                    p = r;
                    break;
                };
                r = r + 1;
            };
            if r + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return entries;
}

#[manual_drop]
fn name_in_auto_drop(auto_drop: Vec<i32>, fn_name: str) -> i64 {
    let n: i64 = vec_len(auto_drop);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(auto_drop, i), fn_name) == 1 { return 1; };
        i = i + 1;
    };
    // v0.8.75 RFC-0062 G-1 Phase 2b-3 FINAL — unconditional
    // default-flip. Auto-drop is now ON BY DEFAULT for every fn.
    // Safe path validated:
    //   - v0.8.31/32  #[manual_drop] suppress mechanism
    //   - v0.8.35     safety audit (89 candidates classified)
    //   - v0.8.41/42  13 fns annotated #[manual_drop]
    //   - v0.8.64     cache-key correctness fix
    //   - v0.8.68/69  sentinel double-free guard (opt-in)
    //   - v0.8.73     handoff-risk warning under flip
    //   - v0.8.74     proper dataflow handoff suppression at
    //                 ExprStmt lowering (catches vec_push /
    //                 vec_set / hashmap_insert patterns and
    //                 suppresses auto-drop on the local that
    //                 was handed off)
    // v0.8.65 ATTEMPTED unconditional flip and segfaulted on
    // attention2.nr import because the static heuristic missed
    // rod-side handoffs. v0.8.74 closes that gap by detecting
    // handoffs at lowering time and suppressing immediately.
    // Re-test confirmed v0.8.75 ready: attention2.nr import
    // compiles cleanly under flip ON. The dataflow detection
    // is conservative (over-suppresses some local-only cases
    // → leaks instead of dropping; never dangling pointer).
    // Phase 2c will refine via receiver-locality + alias
    // tracking for tighter coverage. Phase 3 deny-by-default
    // for misuse. Phase 4 hard-error promotion at v1.0 cut.
    return 1;
}

// v0.8.32 RFC-0062 G-1 Phase 2b-2 — collect `#[manual_drop]`
// fn names. Sister of collect_auto_drop_fns. Phase 2b-2: when
// a fn is in BOTH lists, manual_drop suppresses the auto-drop.
// Phase 2b-3 (default-flip): every fn gets auto-drop unless
// in this list.
#[manual_drop]
fn collect_manual_drop_fns(source: str) -> Vec<i32> {
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = str_concat("#[manual_", "drop]");
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut r: i64 = p + plen;
            while r + 3 <= slen {
                if r + 1 < slen && str_char_at(source, r) == 47 && str_char_at(source, r + 1) == 47 {
                    while r < slen && str_char_at(source, r) != 10 { r = r + 1; };
                };
                let c0: i64 = str_char_at(source, r);
                let c1: i64 = str_char_at(source, r + 1);
                let c2: i64 = str_char_at(source, r + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    r = r + 3;
                    let name_start: i64 = r;
                    while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) {
                        r = r + 1;
                    };
                    if r > name_start {
                        let fname: str = str_substring(source, name_start, r);
                        entries.push(fname);
                    };
                    p = r;
                    break;
                };
                r = r + 1;
            };
            if r + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return entries;
}

#[manual_drop]
fn name_in_manual_drop(manual_drop: Vec<i32>, fn_name: str) -> i64 {
    let n: i64 = vec_len(manual_drop);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(manual_drop, i), fn_name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

// v0.4.271 RFC-0006 — heap-aliased type detection for `old()` reject.
// The i64-everywhere ABI represents Vec/String/HashMap/HashSet/
// BTreeMap/BTreeSet/VecDeque/Box as a single i64 pointer to heap
// storage. Snapshotting the i64 captures the POINTER, not the
// buffer contents — so `old(v)` for `v: Vec<T>` aliases the post-
// mutation pointer and gives wrong ensure semantics. Reject at
// compile time with CONTRACT-006.
#[manual_drop]
fn is_heap_aliased_type(ty: str) -> i64 {
    if str_starts_with(ty, "Vec<") == 1 { return 1; };
    if str_eq(ty, "String") == 1 { return 1; };
    if str_starts_with(ty, "String<") == 1 { return 1; };
    if str_starts_with(ty, "HashMap<") == 1 { return 1; };
    if str_starts_with(ty, "HashSet<") == 1 { return 1; };
    if str_starts_with(ty, "BTreeMap<") == 1 { return 1; };
    if str_starts_with(ty, "BTreeSet<") == 1 { return 1; };
    if str_starts_with(ty, "VecDeque<") == 1 { return 1; };
    if str_starts_with(ty, "Box<") == 1 { return 1; };
    return 0;
}

// v0.4.271 RFC-0006 — text-level lookup of a fn's named param type.
// Finds `fn FNAME(...)`, scans the param list with paren/angle-
// bracket depth tracking so `Vec<HashMap<i64, str>>` parses correctly,
// and returns the type-text of the param matching PNAME. Returns ""
// on miss. Used by the old() heap-aliased reject; matching pattern
// shape with the no_check / require / ensure scanners (text-level
// pre-pass before the AST is built).
#[manual_drop]
fn fn_param_type(source: str, fn_name: str, param_name: str) -> str {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let pat_pos: i64 = str_index_of(source, needle);
    if pat_pos < 0 { return ""; };
    let params_start: i64 = pat_pos + str_len(needle);
    let n: i64 = str_len(source);
    let mut depth: i64 = 1;
    let mut p: i64 = params_start;
    let mut params_end: i64 = 0 - 1;
    while p < n {
        let ch: str = str_substring(source, p, p + 1);
        if str_eq(ch, "(") == 1 { depth = depth + 1; };
        if str_eq(ch, ")") == 1 {
            depth = depth - 1;
            if depth == 0 { params_end = p; p = n; };
        };
        p = p + 1;
    };
    if params_end < 0 { return ""; };
    // Walk params: split on comma at depth 0 (angle-bracket / paren depth).
    let mut q: i64 = params_start;
    let mut start: i64 = params_start;
    let mut adepth: i64 = 0;
    let mut pdepth: i64 = 0;
    while q <= params_end {
        let at_end: i64 = if q >= params_end { 1 } else { 0 };
        let cch: str = if at_end == 1 { "," } else { str_substring(source, q, q + 1) };
        if str_eq(cch, "<") == 1 { adepth = adepth + 1; };
        if str_eq(cch, ">") == 1 { adepth = adepth - 1; };
        if str_eq(cch, "(") == 1 { pdepth = pdepth + 1; };
        if str_eq(cch, ")") == 1 { pdepth = pdepth - 1; };
        let comma_at_depth_zero: i64 = if str_eq(cch, ",") == 1 { if adepth == 0 { if pdepth == 0 { 1 } else { 0 } } else { 0 } } else { 0 };
        if comma_at_depth_zero == 1 || at_end == 1 {
            let param_text: str = str_substring(source, start, q);
            let colon_pos: i64 = str_index_of(param_text, ":");
            if colon_pos > 0 {
                let lhs: str = str_trim(str_substring(param_text, 0, colon_pos));
                let rhs: str = str_trim(str_substring(param_text, colon_pos + 1, str_len(param_text)));
                let lhs2: str = if str_starts_with(lhs, "mut ") == 1 { str_trim(str_substring(lhs, 4, str_len(lhs))) } else { lhs };
                if str_eq(lhs2, param_name) == 1 { return rhs; };
            };
            start = q + 1;
        };
        q = q + 1;
    };
    return "";
}

// fn_param_type by INDEX. Used by
// OWN-001 sig-aware move-skip — when the callee's idx-th param is
// `&Type` / `&mut Type`, the arg passing is a borrow not a move and
// OWN-001 should NOT mark the caller's binding moved.
fn fn_param_type_at_index(source: str, fn_name: str, idx: i64) -> str {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let pat_pos: i64 = str_index_of(source, needle);
    if pat_pos < 0 {
        // generic form `fn FNAME<...>(...)`
        let generic_needle: str = str_concat("fn ", str_concat(fn_name, "<"));
        let generic_pat_pos: i64 = str_index_of(source, generic_needle);
        if generic_pat_pos < 0 { return ""; };
        // skip the generic-params block to land before `(`
        let mut q_pos: i64 = generic_pat_pos + str_len(generic_needle);
        let n_g: i64 = str_len(source);
        let mut g_depth: i64 = 1;
        while q_pos < n_g && g_depth > 0 {
            let ch: i64 = str_char_at(source, q_pos);
            if ch == 60 { g_depth = g_depth + 1; };
            if ch == 62 { g_depth = g_depth - 1; };
            q_pos = q_pos + 1;
        };
        // expect `(` after the closing `>`
        if q_pos >= n_g || str_char_at(source, q_pos) != 40 { return ""; };
        return fn_param_type_at_index_from_open(source, q_pos + 1, idx);
    };
    let params_start: i64 = pat_pos + str_len(needle);
    let n: i64 = str_len(source);
    let mut depth: i64 = 1;
    let mut p: i64 = params_start;
    let mut params_end: i64 = 0 - 1;
    while p < n {
        let ch: str = str_substring(source, p, p + 1);
        if str_eq(ch, "(") == 1 { depth = depth + 1; };
        if str_eq(ch, ")") == 1 {
            depth = depth - 1;
            if depth == 0 { params_end = p; p = n; };
        };
        p = p + 1;
    };
    if params_end < 0 { return ""; };
    let mut q: i64 = params_start;
    let mut start: i64 = params_start;
    let mut adepth: i64 = 0;
    let mut pdepth: i64 = 0;
    let mut at_idx: i64 = 0;
    while q <= params_end {
        let at_end: i64 = if q >= params_end { 1 } else { 0 };
        let cch: str = if at_end == 1 { "," } else { str_substring(source, q, q + 1) };
        if str_eq(cch, "<") == 1 { adepth = adepth + 1; };
        if str_eq(cch, ">") == 1 { adepth = adepth - 1; };
        if str_eq(cch, "(") == 1 { pdepth = pdepth + 1; };
        if str_eq(cch, ")") == 1 { pdepth = pdepth - 1; };
        let comma_at_depth_zero: i64 = if str_eq(cch, ",") == 1 { if adepth == 0 { if pdepth == 0 { 1 } else { 0 } } else { 0 } } else { 0 };
        if comma_at_depth_zero == 1 || at_end == 1 {
            if at_idx == idx {
                let param_text: str = str_substring(source, start, q);
                let colon_pos: i64 = str_index_of(param_text, ":");
                if colon_pos > 0 {
                    let rhs: str = str_trim(str_substring(param_text, colon_pos + 1, str_len(param_text)));
                    return rhs;
                };
                return "";
            };
            at_idx = at_idx + 1;
            start = q + 1;
        };
        q = q + 1;
    };
    return "";
}

// walk param list starting AT
// params_start (just past the opening `(`), return the type of the
// idx-th param. Shared between the bare-fn and generic-fn entry paths.
fn fn_param_type_at_index_from_open(source: str, params_start: i64, idx: i64) -> str {
    let n: i64 = str_len(source);
    let mut depth: i64 = 1;
    let mut p: i64 = params_start;
    let mut params_end: i64 = 0 - 1;
    while p < n {
        let ch: str = str_substring(source, p, p + 1);
        if str_eq(ch, "(") == 1 { depth = depth + 1; };
        if str_eq(ch, ")") == 1 {
            depth = depth - 1;
            if depth == 0 { params_end = p; p = n; };
        };
        p = p + 1;
    };
    if params_end < 0 { return ""; };
    let mut q: i64 = params_start;
    let mut start: i64 = params_start;
    let mut adepth: i64 = 0;
    let mut pdepth: i64 = 0;
    let mut at_idx: i64 = 0;
    while q <= params_end {
        let at_end: i64 = if q >= params_end { 1 } else { 0 };
        let cch: str = if at_end == 1 { "," } else { str_substring(source, q, q + 1) };
        if str_eq(cch, "<") == 1 { adepth = adepth + 1; };
        if str_eq(cch, ">") == 1 { adepth = adepth - 1; };
        if str_eq(cch, "(") == 1 { pdepth = pdepth + 1; };
        if str_eq(cch, ")") == 1 { pdepth = pdepth - 1; };
        let comma_at_depth_zero: i64 = if str_eq(cch, ",") == 1 { if adepth == 0 { if pdepth == 0 { 1 } else { 0 } } else { 0 } } else { 0 };
        if comma_at_depth_zero == 1 || at_end == 1 {
            if at_idx == idx {
                let param_text: str = str_substring(source, start, q);
                let colon_pos: i64 = str_index_of(param_text, ":");
                if colon_pos > 0 {
                    let rhs: str = str_trim(str_substring(param_text, colon_pos + 1, str_len(param_text)));
                    return rhs;
                };
                return "";
            };
            at_idx = at_idx + 1;
            start = q + 1;
        };
        q = q + 1;
    };
    return "";
}

// predicate "callee's idx-th param
// is a borrow type" (`&T` or `&mut T`). Used in check_expr kind-7 to
// suppress the OWN-001 move-marking when the call passes-by-reference.
fn fn_callee_param_is_borrow(source: str, fn_name: str, idx: i64) -> i64 {
    let pty: str = fn_param_type_at_index(source, fn_name, idx);
    if str_len(pty) == 0 { return 0; };
    if str_starts_with(pty, "&") == 1 { return 1; };
    return 0;
}

// v0.4.272 RFC-0006 — text-level lookup of a fn's return type.
// Finds `fn FNAME(...)`, walks past the param list with paren
// depth tracking, then returns the text between `->` and `{`
// trimmed. Returns "" if the fn has no return arrow (i.e. void
// return type). Used by the void-fn-result-ref reject.
#[manual_drop]
fn fn_return_type(source: str, fn_name: str) -> str {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let pat_pos: i64 = str_index_of(source, needle);
    if pat_pos < 0 { return ""; };
    let params_start: i64 = pat_pos + str_len(needle);
    let n: i64 = str_len(source);
    let mut depth: i64 = 1;
    let mut p: i64 = params_start;
    let mut params_end: i64 = 0 - 1;
    while p < n {
        let ch: str = str_substring(source, p, p + 1);
        if str_eq(ch, "(") == 1 { depth = depth + 1; };
        if str_eq(ch, ")") == 1 {
            depth = depth - 1;
            if depth == 0 { params_end = p; p = n; };
        };
        p = p + 1;
    };
    if params_end < 0 { return ""; };
    // Walk past `)` to find `->` or `{`.
    let mut q: i64 = params_end + 1;
    while q < n - 1 {
        let c2: str = str_substring(source, q, q + 2);
        let c1: str = str_substring(source, q, q + 1);
        if str_eq(c2, "->") == 1 {
            // Find the next `{` or `;` after the arrow.
            let mut r: i64 = q + 2;
            while r < n {
                let cr: str = str_substring(source, r, r + 1);
                if str_eq(cr, "{") == 1 { break; };
                if str_eq(cr, ";") == 1 { break; };
                r = r + 1;
            };
            if r > q + 2 {
                return str_trim(str_substring(source, q + 2, r));
            };
            return "";
        };
        if str_eq(c1, "{") == 1 { return ""; };
        if str_eq(c1, ";") == 1 { return ""; };
        q = q + 1;
    };
    return "";
}

// RFC-0008 first pass — `#[isr]` source-level attribute substrate.
// Keep this scanner in the same family as the RT attribute scanners:
// the lexer/parser intentionally discard unknown `#[...]` lines, so
// function-level attributes are recovered from resolved source text.
// Returns flat pairs: [fn_name0, attr_text0, fn_name1, attr_text1, ...].
#[manual_drop]
fn collect_isr_entries(source: str) -> Vec<i32> {
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[isr";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let after: i64 = if p + plen < slen { str_char_at(source, p + plen) } else { 0 };
            let attr_boundary: i64 = if after == 93 || after == 40 || is_ws(after) == 1 { 1 } else { 0 };
            if attr_boundary == 0 {
                p = p + 1;
                continue;
            };
            let mut attr_end: i64 = p + plen;
            let mut depth: i64 = 1;
            while attr_end < slen && depth > 0 {
                let ac: i64 = str_char_at(source, attr_end);
                if ac == 34 {
                    attr_end = attr_end + 1;
                    while attr_end < slen && str_char_at(source, attr_end) != 34 {
                        if str_char_at(source, attr_end) == 92 && attr_end + 1 < slen { attr_end = attr_end + 2; }
                        else { attr_end = attr_end + 1; };
                    };
                } else if ac == 91 { depth = depth + 1; }
                else if ac == 93 { depth = depth - 1; };
                attr_end = attr_end + 1;
            };
            let attr_text: str = str_substring(source, p, attr_end);
            let mut r: i64 = attr_end;
            while r + 3 <= slen {
                if r + 1 < slen && str_char_at(source, r) == 47 && str_char_at(source, r + 1) == 47 {
                    while r < slen && str_char_at(source, r) != 10 { r = r + 1; };
                };
                let c0: i64 = str_char_at(source, r);
                let c1: i64 = str_char_at(source, r + 1);
                let c2: i64 = str_char_at(source, r + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    r = r + 3;
                    let name_start: i64 = r;
                    while r < slen && (is_alnum(str_char_at(source, r)) == 1 || str_char_at(source, r) == 95) { r = r + 1; };
                    if r > name_start {
                        entries.push(str_substring(source, name_start, r));
                        entries.push(attr_text);
                    };
                    p = r;
                    break;
                };
                r = r + 1;
            };
            if r + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return entries;
}

#[manual_drop]
fn collect_isr_fns(source: str) -> Vec<i32> {
    let entries: Vec<i32> = collect_isr_entries(source);
    let mut fns: Vec<i32> = Vec::new();
    let n: i64 = vec_len(entries);
    let mut i: i64 = 0;
    while i + 1 < n {
        fns.push(vec_get(entries, i));
        i = i + 2;
    };
    return fns;
}

#[manual_drop]
fn name_in_isr_entries(entries: Vec<i32>, fn_name: str) -> i64 {
    let n: i64 = vec_len(entries);
    let mut i: i64 = 0;
    while i + 1 < n {
        if str_eq(vec_get(entries, i), fn_name) == 1 { return 1; };
        i = i + 2;
    };
    return 0;
}

#[manual_drop]
fn isr_target_for_compile() -> str {
    let t: str = getenv("NUCLEOR_ISR_TARGET");
    if str_len(t) == 0 { return "cortex-m4f"; };
    return t;
}

#[manual_drop]
fn isr_target_supported(target: str) -> i64 {
    if str_eq(target, "cortex-m4f") == 1 { return 1; };
    if str_eq(target, "cortex_m4f") == 1 { return 1; };
    if str_eq(target, "rv32imac") == 1 { return 1; };
    if str_eq(target, "rv32-imac") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn isr_attr_requests_unsupported_target(attr_text: str) -> i64 {
    if str_contains(attr_text, "target = \"host\"") == 1 { return 1; };
    if str_contains(attr_text, "target=\"host\"") == 1 { return 1; };
    if str_contains(attr_text, "target = \"native\"") == 1 { return 1; };
    if str_contains(attr_text, "target=\"native\"") == 1 { return 1; };
    if str_contains(attr_text, "target = \"x86_64\"") == 1 { return 1; };
    if str_contains(attr_text, "target=\"x86_64\"") == 1 { return 1; };
    if str_contains(attr_text, "target = \"unsupported\"") == 1 { return 1; };
    if str_contains(attr_text, "target=\"unsupported\"") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn fn_param_decl_text(source: str, fn_name: str) -> str {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let pat_pos: i64 = str_index_of(source, needle);
    if pat_pos < 0 { return ""; };
    let params_start: i64 = pat_pos + str_len(needle);
    let n: i64 = str_len(source);
    let mut depth: i64 = 1;
    let mut p: i64 = params_start;
    while p < n {
        let ch: i64 = str_char_at(source, p);
        if ch == 40 { depth = depth + 1; };
        if ch == 41 {
            depth = depth - 1;
            if depth == 0 { return str_substring(source, params_start, p); };
        };
        p = p + 1;
    };
    return "";
}

//  was silently dropped on that item AND leaked
// to the next fn in the file, producing a misleading ISR-001 diag
// pointing at that next fn (`main` in the typical repro). Adopters
// removing or fixing the suspect fn would just see the diag shift to
// the next fn down — the actual misplaced attribute (the struct) was
// never named.
// This pass scans for every `#[isr` occurrence and walks forward
// looking for the next item-keyword. If the first item-keyword found
// is anything other than `fn`, emit ISR-008 at the attribute's own
// source line so the adopter can find and delete the misplaced
// attribute.
#[manual_drop]
fn enforce_isr_placement(diags: Vec<i32>, source: str) -> Vec<i32> {
    let slen: i64 = str_len(source);
    let pat: str = "#[isr";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        // Skip line comments and string literals (mirror collect_isr_entries logic).
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        if str_eq_at_len(source, p, pat, plen) == 0 { p = p + 1; continue; };
        let after: i64 = if p + plen < slen { str_char_at(source, p + plen) } else { 0 };
        let attr_boundary_isr31: i64 = if after == 93 || after == 40 || is_ws(after) == 1 { 1 } else { 0 };
        if attr_boundary_isr31 == 0 { p = p + 1; continue; };
        let attr_start_isr31: i64 = p;
        // Walk past the attribute body to its closing `]`.
        let mut ae_isr31: i64 = p + plen;
        let mut depth_isr31: i64 = 1;
        while ae_isr31 < slen && depth_isr31 > 0 {
            let ac_isr31: i64 = str_char_at(source, ae_isr31);
            if ac_isr31 == 34 {
                ae_isr31 = ae_isr31 + 1;
                while ae_isr31 < slen && str_char_at(source, ae_isr31) != 34 {
                    if str_char_at(source, ae_isr31) == 92 && ae_isr31 + 1 < slen { ae_isr31 = ae_isr31 + 2; }
                    else { ae_isr31 = ae_isr31 + 1; };
                };
            } else if ac_isr31 == 91 { depth_isr31 = depth_isr31 + 1; }
            else if ac_isr31 == 93 { depth_isr31 = depth_isr31 - 1; };
            ae_isr31 = ae_isr31 + 1;
        };
        // Now walk forward from ae_isr31 looking for the next item-keyword
        // at a fresh whitespace boundary. Skip over comments, attrs, `pub`,
        // and the modifier set Rust allows between attributes and items.
        let mut r_isr31: i64 = ae_isr31;
        let mut next_item_kind_isr31: str = "";
        while r_isr31 < slen {
            // Skip line comments.
            if r_isr31 + 1 < slen && str_char_at(source, r_isr31) == 47 && str_char_at(source, r_isr31 + 1) == 47 {
                while r_isr31 < slen && str_char_at(source, r_isr31) != 10 { r_isr31 = r_isr31 + 1; };
                continue;
            };
            // Skip whitespace.
            if r_isr31 < slen && is_ws(str_char_at(source, r_isr31)) == 1 { r_isr31 = r_isr31 + 1; continue; };
            // Skip nested attributes (e.g. `#[isr]\n#[no_panic]\nfn …`).
            if r_isr31 < slen && str_char_at(source, r_isr31) == 35 {
                while r_isr31 < slen && str_char_at(source, r_isr31) != 93 { r_isr31 = r_isr31 + 1; };
                if r_isr31 < slen { r_isr31 = r_isr31 + 1; };
                continue;
            };
            // Identify the next item-keyword.
            if str_eq_at(source, r_isr31, "pub ") == 1 { r_isr31 = r_isr31 + 4; continue; };
            if str_eq_at(source, r_isr31, "pub(") == 1 {
                while r_isr31 < slen && str_char_at(source, r_isr31) != 41 { r_isr31 = r_isr31 + 1; };
                if r_isr31 < slen { r_isr31 = r_isr31 + 1; };
                continue;
            };
            if str_eq_at(source, r_isr31, "fn ") == 1 { next_item_kind_isr31 = "fn"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "struct ") == 1 { next_item_kind_isr31 = "struct"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "enum ") == 1 { next_item_kind_isr31 = "enum"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "impl ") == 1 { next_item_kind_isr31 = "impl"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "trait ") == 1 { next_item_kind_isr31 = "trait"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "mod ") == 1 { next_item_kind_isr31 = "mod"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "use ") == 1 { next_item_kind_isr31 = "use"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "const ") == 1 { next_item_kind_isr31 = "const"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "static ") == 1 { next_item_kind_isr31 = "static"; r_isr31 = slen; }
            else if str_eq_at(source, r_isr31, "type ") == 1 { next_item_kind_isr31 = "type"; r_isr31 = slen; }
            else { r_isr31 = r_isr31 + 1; };
        };
        if str_len(next_item_kind_isr31) > 0 && str_eq(next_item_kind_isr31, "fn") == 0 {
            let line_isr31: i64 = byte_to_line(source, attr_start_isr31);
            let msg4: str = str_concat("`#[isr]` may only be applied to fn items; found `", str_concat(next_item_kind_isr31, "` after the attribute. Workaround: remove this `#[isr]` (it has no effect on a non-fn item) or move it to the actual handler fn."));
            diag_add_ex(diags, "error", "isr", "ISR-008", msg4, "", line_isr31, 1, "");
        };
        p = ae_isr31;
    };
    return diags;
}

//  the `prio` named attribute inside `#[isr(prio = X)]` was
// silently accepted for X = negative-int (`-1`), string-literal
// (`"high"`), or missing entirely (`#[isr(prio)]`). None of these
// match the documented `prio = N` non-negative integer-literal shape.
// Adopters writing `#[isr(prio = "1")]` (typo'd quotes) shipped to
// embedded target with no priority set — hard-to-diagnose runtime
// priority-inversion bugs followed.
// Scans attr_text for `prio`, validates the next non-ws token is
// `=` followed by a non-negative integer literal. Emits ISR-007 at
// the attribute's source line for any other shape.
#[manual_drop]
fn validate_isr_prio(diags: Vec<i32>, fn_name: str, attr_text: str, line: i64, col: i64) -> Vec<i32> {
    let alen: i64 = str_len(attr_text);
    if alen < 5 { return diags; };
    // Scan attr_text for `prio` ident — must be preceded by `(` or
    // `,` or whitespace and followed by `=` / `,` / `)` / whitespace.
    let mut q: i64 = 0;
    let mut prio_at: i64 = 0 - 1;
    while q + 4 <= alen {
        if str_eq_at(attr_text, q, "prio") == 1 {
            let pre_ok: i64 = if q == 0 { 0 } else {
                let pc_v062: i64 = str_char_at(attr_text, q - 1);
                if pc_v062 == 40 || pc_v062 == 44 || is_ws(pc_v062) == 1 { 1 } else { 0 }
            };
            let post_ok: i64 = if q + 4 >= alen { 1 } else {
                let nc_v062: i64 = str_char_at(attr_text, q + 4);
                if nc_v062 == 61 || nc_v062 == 44 || nc_v062 == 41 || is_ws(nc_v062) == 1 { 1 } else { 0 }
            };
            if pre_ok == 1 && post_ok == 1 { prio_at = q; q = alen; }
            else { q = q + 1; };
        } else { q = q + 1; };
    };
    if prio_at < 0 { return diags; };
    // Walk past `prio` and any whitespace.
    let mut r: i64 = prio_at + 4;
    while r < alen && is_ws(str_char_at(attr_text, r)) == 1 { r = r + 1; };
    // Gap (d) — bare `prio` (no value).
    if r >= alen || str_char_at(attr_text, r) == 44 || str_char_at(attr_text, r) == 41 {
        diag_add_ex(diags, "error", "isr", "ISR-007", "`#[isr(prio)]` is missing a value: prio requires a non-negative integer literal (e.g. `#[isr(prio = 3)]`). Pre-v0.6.32 the bare ident was silently accepted and the priority defaulted with no diag.", fn_name, line, col, "");
        return diags;
    };
    // Expect `=`.
    if str_char_at(attr_text, r) != 61 {
        diag_add_ex(diags, "error", "isr", "ISR-007", "`#[isr(prio ...)]` malformed: expected `prio = N` with non-negative integer literal N.", fn_name, line, col, "");
        return diags;
    };
    r = r + 1;
    while r < alen && is_ws(str_char_at(attr_text, r)) == 1 { r = r + 1; };
    if r >= alen { return diags; };
    let firstc: i64 = str_char_at(attr_text, r);
    // Gap (c) — string literal.
    if firstc == 34 {
        diag_add_ex(diags, "error", "isr", "ISR-007", "`#[isr(prio = \"...\")]` rejected: prio must be a non-negative integer literal, not a string. Pre-v0.6.32 the string was silently ignored.", fn_name, line, col, "");
        return diags;
    };
    // Gap (b) — negative integer.
    if firstc == 45 {
        diag_add_ex(diags, "error", "isr", "ISR-007", "`#[isr(prio = -N)]` rejected: prio must be NON-NEGATIVE (NVIC priorities are unsigned 0..255; PLIC unsigned 1..7). Pre-v0.6.32 negative integers were silently accepted with undefined effect on the target.", fn_name, line, col, "");
        return diags;
    };
    // Verify rest of the value up to `,)` or ws is all digits.
    while r < alen {
        let vc: i64 = str_char_at(attr_text, r);
        if vc == 44 || vc == 41 || is_ws(vc) == 1 { r = alen; }
        else if vc < 48 || vc > 57 {
            diag_add_ex(diags, "error", "isr", "ISR-007", "`#[isr(prio = ...)]` rejected: prio must be a plain non-negative integer literal (e.g. `prio = 3`). Pre-v0.6.32 non-digit values were silently accepted.", fn_name, line, col, "");
            return diags;
        }
        else { r = r + 1; };
    };
    return diags;
}

#[manual_drop]
fn enforce_isr_contracts(diags: Vec<i32>, source: str) -> Vec<i32> {
    diags = enforce_isr_placement(diags, source);
    let entries: Vec<i32> = collect_isr_entries(source);
    let target: str = isr_target_for_compile();
    let target_ok: i64 = isr_target_supported(target);
    let n: i64 = vec_len(entries);
    let mut i: i64 = 0;
    while i + 1 < n {
        let fn_name: str = vec_get(entries, i);
        let attr_text: str = vec_get(entries, i + 1);
        let params: str = str_trim(fn_param_decl_text(source, fn_name));
        let ret_type: str = fn_return_type(source, fn_name);
        let mut lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
        let mut bad_sig: i64 = 0;
        if str_len(params) > 0 { bad_sig = 1; };
        if str_len(ret_type) > 0 && str_eq(ret_type, "void") == 0 { bad_sig = 1; };
        if bad_sig == 1 {
            let msg1: str = str_concat("`#[isr]` function `", str_concat(fn_name, "` must have signature `fn() -> void` (no params, no return value)"));
            diag_add_ex(diags, "error", "isr", "ISR-001", msg1, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
        };
        if str_starts_with(fn_name, "__nuc_dl_inner_") == 1 {
            let msg2: str = "`#[isr]` cannot be combined with `#[deadline]`; ISR latency is target interrupt timing, not wall-time deadline wrapping";
            diag_add_ex(diags, "error", "isr", "ISR-002", msg2, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
        };
        if target_ok == 0 || isr_attr_requests_unsupported_target(attr_text) == 1 {
            let msg3: str = str_concat("target `", str_concat(target, "` does not support `#[isr]` yet (supported first-pass targets: cortex-m4f, rv32imac)"));
            diag_add_ex(diags, "error", "isr", "ISR-003", msg3, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
        };
        check_no_alloc_violations(diags, source, fn_name);
        check_no_panic_violations(diags, source, fn_name);
        // RFC-0008 §3.0 says
        // `#[isr]` implies `#[atomic]`. Pre-fix the implication was
        // enforced for alloc / panic / dyn but not for blocking. An
        // ISR locking a mutex on an embedded target deadlocks the
        // whole system; surface the diagnostic at compile time.
        check_atomic_contract_violations(diags, source, fn_name);
        //  validate `prio = N` named attribute shape.
        diags = validate_isr_prio(diags, fn_name, attr_text, vec_get(lc, 0), vec_get(lc, 1));
        i = i + 2;
    };
    return diags;
}

// RFC-0035 first pass — actor declarations are contextual source
// syntax, not a hard lexer keyword. Rewriting only `actor Name {`
// declaration sites preserves user identifiers named `actor` while
// letting the existing struct parser/lowerer carry field-only actors.
#[manual_drop]
fn sendable_actor_decl_name_at(src: str, pos: i64) -> str {
    // original called `str_len(src)` (C `strlen`)
    // on the full 1.5MB source EVERY call. Called once per character
    // position from `sendable_source_has_actor_decl` → O(slen²) total.
    // Reuses the fast-fail at str_eq_at first; only computes slen when
    // we actually need to read past pos. Same v0.3.205 strlen-in-
    // substring pattern that the parser helpers must avoid.
    if str_eq_at(src, pos, "actor") == 0 { return ""; };
    let slen: i64 = str_len(src);
    if pos + 5 > slen { return ""; };
    let prev_ok: i64 = if pos == 0 { 1 } else {
        let pc: i64 = str_char_at(src, pos - 1);
        if is_alnum(pc) == 0 { if pc != 95 { 1 } else { 0 } } else { 0 }
    };
    if prev_ok == 0 { return ""; };
    let mut q: i64 = pos + 5;
    if q >= slen || is_ws(str_char_at(src, q)) == 0 { return ""; };
    while q < slen && is_ws(str_char_at(src, q)) == 1 { q = q + 1; };
    let ns: i64 = q;
    while q < slen && (is_alnum(str_char_at(src, q)) == 1 || str_char_at(src, q) == 95) { q = q + 1; };
    if q <= ns { return ""; };
    let name: str = str_substring(src, ns, q);
    while q < slen && is_ws(str_char_at(src, q)) == 1 { q = q + 1; };
    if q < slen && str_char_at(src, q) == 123 { return name; };
    return "";
}

#[manual_drop]
fn sendable_source_has_actor_decl(src: str) -> i64 {
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        } else if c == 34 || c == 39 {
            let quote: i64 = c;
            p = p + 1;
            while p < slen && str_char_at(src, p) != quote {
                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
        } else {
            if str_len(sendable_actor_decl_name_at(src, p)) > 0 { return 1; };
            p = p + 1;
        };
    };
    return 0;
}

// v0.6.84 RFC V1.4
//  row): canonical Rust
// `#[derive(PartialEq)] struct Point { x: i64, y: i64 }` pre-fix
// emitted only the v0.6.26 `warning[DERIVE-001]` and the derive was
// silently a no-op. Adopters writing `if a == b { ... }` later got
// the v0.4.147 TYP-011 ptr-compare diag with workaround pointer
// "write a helper fn that does the field walk" — but the helper
// wasn't auto-generated.
// This pass walks the source, finds `#[derive(...PartialEq...)]`
// attribute lines followed by a `struct NAME { ... }` or `struct
// NAME(...);` decl, and APPENDS a generated helper fn at end of
// source: `fn <NAME>__derived_eq(a: <NAME>, b: <NAME>) -> i64 {
//     if a.<f1> != b.<f1> { return 0; };
//     ...
//     return 1;
// }`. Adopters can call the generated fn directly; auto-dispatch
// of `==`/`!=` to the helper is deferred to a follow-on V1.4 ship
// (needs lower_expr binop kind-4 routing + side-table threading).
// Conservative scope: skip generic structs (`struct Pair<T>`),
// skip where-clauses, skip empty unit structs. For named struct
// fields, walk to the next top-level comma or `}` (depth-tracked
// for `<>`/`()`/`[]` so generic field types parse correctly). For
// tuple structs, count types and synthesize `__0`/`__1` names
// matching the V1.1 (v0.6.74) tuple-struct positional-field
// synthesis.
// `!=` on a struct field today does pointer-compare for nested
// structs (silent miscompute); the per-field helper still works
// for primitive-typed fields. Document the limitation in CHANGELOG.
#[manual_drop]
fn expand_derive_partialeq(src: str) -> str {
    let slen: i64 = str_len(src);
    // Cheap pre-check: bail if source has no `#[derive(` at all.
    let mut has_derive: i64 = 0;
    let mut prep: i64 = 0;
    while prep + 9 <= slen {
        if str_eq_at(src, prep, "#[derive(") == 1 { has_derive = 1; prep = slen; };
        prep = prep + 1;
    };
    if has_derive == 0 { return src; };
    let mut helpers: i64 = sb_new();
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        // Skip line comments.
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
            continue;
        };
        // Skip string literals.
        if c == 34 {
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        if c == 39 {
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        if c != 35 || p + 9 > slen || str_eq_at(src, p, "#[derive(") == 0 {
            p = p + 1;
            continue;
        };
        // Found #[derive( at p. Walk to closing ].
        let attr_start: i64 = p;
        let mut q: i64 = p + 9;
        let mut depth_a: i64 = 1;
        while q < slen && depth_a > 0 {
            let cc: i64 = str_char_at(src, q);
            if cc == 91 { depth_a = depth_a + 1; }
            else if cc == 93 { depth_a = depth_a - 1; };
            q = q + 1;
        };
        let attr_text: str = str_substring(src, attr_start, q);
        let has_partialeq: i64 = if str_contains(attr_text, "PartialEq") == 1 { 1 } else { 0 };
        p = q;
        if has_partialeq == 0 { continue; };
        // Skip whitespace and any subsequent attributes / line comments.
        let mut sp: i64 = p;
        let mut keep_looking: i64 = 1;
        while keep_looking == 1 && sp < slen {
            let sc: i64 = str_char_at(src, sp);
            if sc == 32 || sc == 9 || sc == 10 || sc == 13 { sp = sp + 1; }
            else if sc == 47 && sp + 1 < slen && str_char_at(src, sp + 1) == 47 {
                while sp < slen && str_char_at(src, sp) != 10 { sp = sp + 1; };
            }
            else if sc == 35 && sp + 1 < slen && str_char_at(src, sp + 1) == 91 {
                let mut da: i64 = 1;
                sp = sp + 2;
                while sp < slen && da > 0 {
                    let dc: i64 = str_char_at(src, sp);
                    if dc == 91 { da = da + 1; }
                    else if dc == 93 { da = da - 1; };
                    sp = sp + 1;
                };
            }
            else if sc == 116 || sc == 112 {
                // Skip `pub ` modifier.
                if sp + 4 <= slen && str_eq_at(src, sp, "pub ") == 1 { sp = sp + 4; }
                else { keep_looking = 0; };
            }
            else { keep_looking = 0; };
        };
        if sp + 7 > slen || str_eq_at(src, sp, "struct ") == 0 { continue; };
        sp = sp + 7;
        // Skip ws.
        let mut ws_done: i64 = 0;
        while sp < slen && ws_done == 0 {
            let wc: i64 = str_char_at(src, sp);
            if wc == 32 || wc == 9 { sp = sp + 1; }
            else { ws_done = 1; };
        };
        // Capture name.
        let name_start: i64 = sp;
        let mut name_done: i64 = 0;
        while sp < slen && name_done == 0 {
            let nc: i64 = str_char_at(src, sp);
            if is_alnum(nc) == 1 || nc == 95 { sp = sp + 1; }
            else { name_done = 1; };
        };
        let name: str = str_substring(src, name_start, sp);
        if str_len(name) == 0 { continue; };
        // Skip ws.
        let mut ws2_done: i64 = 0;
        while sp < slen && ws2_done == 0 {
            let wc2: i64 = str_char_at(src, sp);
            if wc2 == 32 || wc2 == 9 || wc2 == 10 || wc2 == 13 { sp = sp + 1; }
            else { ws2_done = 1; };
        };
        if sp >= slen { continue; };
        let mut next_c: i64 = str_char_at(src, sp);
        // capture generic params if present.
        // `<T, U>` after the struct name. Walk balanced angles, store
        // the param list (raw substring) so the helper signature can
        // re-emit it. Field types in the body stay verbatim — the
        // helper's `!= a.<f> != b.<f>` lower-time auto-dispatch picks
        // the right runtime helper per concrete instantiation.
        let mut v089_gparams: str = "";
        if next_c == 60 {
            let v089_g_start: i64 = sp;
            let mut v089_g_depth: i64 = 1;
            sp = sp + 1;
            while sp < slen && v089_g_depth > 0 {
                let v089_gc: i64 = str_char_at(src, sp);
                if v089_gc == 60 { v089_g_depth = v089_g_depth + 1; }
                else if v089_gc == 62 { v089_g_depth = v089_g_depth - 1; };
                sp = sp + 1;
            };
            v089_gparams = str_substring(src, v089_g_start, sp);
            // Skip ws.
            let mut v089_ws_done: i64 = 0;
            while sp < slen && v089_ws_done == 0 {
                let v089_wc: i64 = str_char_at(src, sp);
                if v089_wc == 32 || v089_wc == 9 || v089_wc == 10 || v089_wc == 13 { sp = sp + 1; }
                else { v089_ws_done = 1; };
            };
            if sp >= slen { continue; };
            next_c = str_char_at(src, sp);
        };
        // Named struct: `{ field: type, ... }`.
        if next_c == 123 {
            let mut fb: i64 = sb_new();
            sb_append(fb, "\nfn ");
            sb_append(fb, name);
            sb_append(fb, "__derived_eq");
            // Re-emit generic params on the helper fn signature.
            if str_len(v089_gparams) > 0 { sb_append(fb, v089_gparams); };
            sb_append(fb, "(a: ");
            sb_append(fb, name);
            if str_len(v089_gparams) > 0 { sb_append(fb, v089_gparams); };
            sb_append(fb, ", b: ");
            sb_append(fb, name);
            if str_len(v089_gparams) > 0 { sb_append(fb, v089_gparams); };
            sb_append(fb, ") -> i64 {\n");
            sp = sp + 1;
            let mut field_count: i64 = 0;
            let mut keep_fields: i64 = 1;
            while keep_fields == 1 && sp < slen {
                // Skip ws + commas + line comments.
                let mut skipped: i64 = 1;
                while skipped == 1 && sp < slen {
                    skipped = 0;
                    let fc1: i64 = str_char_at(src, sp);
                    if fc1 == 32 || fc1 == 9 || fc1 == 10 || fc1 == 13 || fc1 == 44 { sp = sp + 1; skipped = 1; }
                    else if fc1 == 47 && sp + 1 < slen && str_char_at(src, sp + 1) == 47 {
                        while sp < slen && str_char_at(src, sp) != 10 { sp = sp + 1; };
                        skipped = 1;
                    };
                };
                if sp >= slen { keep_fields = 0; }
                else if str_char_at(src, sp) == 125 { sp = sp + 1; keep_fields = 0; }
                else {
                    // Skip pub modifier.
                    if sp + 4 <= slen && str_eq_at(src, sp, "pub ") == 1 { sp = sp + 4; };
                    // Skip ws.
                    let mut fws_done: i64 = 0;
                    while sp < slen && fws_done == 0 {
                        let fc2: i64 = str_char_at(src, sp);
                        if fc2 == 32 || fc2 == 9 { sp = sp + 1; }
                        else { fws_done = 1; };
                    };
                    // Capture field name.
                    let f_start: i64 = sp;
                    let mut fn_done: i64 = 0;
                    while sp < slen && fn_done == 0 {
                        let fnc: i64 = str_char_at(src, sp);
                        if is_alnum(fnc) == 1 || fnc == 95 { sp = sp + 1; }
                        else { fn_done = 1; };
                    };
                    let fname: str = str_substring(src, f_start, sp);
                    // Skip ws.
                    let mut fws3_done: i64 = 0;
                    while sp < slen && fws3_done == 0 {
                        let fc3: i64 = str_char_at(src, sp);
                        if fc3 == 32 || fc3 == 9 { sp = sp + 1; }
                        else { fws3_done = 1; };
                    };
                    // Expect `:`.
                    if sp < slen && str_char_at(src, sp) == 58 {
                        sp = sp + 1;
                        // Walk type to next top-level `,` or `}`.
                        let mut td: i64 = 0;
                        let mut type_done: i64 = 0;
                        while sp < slen && type_done == 0 {
                            let tc: i64 = str_char_at(src, sp);
                            if tc == 60 || tc == 40 || tc == 91 { td = td + 1; sp = sp + 1; }
                            else if tc == 62 || tc == 41 || tc == 93 { td = td - 1; sp = sp + 1; }
                            else if (tc == 44 || tc == 125) && td == 0 { type_done = 1; }
                            else if tc == 34 {
                                sp = sp + 1;
                                while sp < slen && str_char_at(src, sp) != 34 {
                                    if str_char_at(src, sp) == 92 && sp + 1 < slen { sp = sp + 2; }
                                    else { sp = sp + 1; };
                                };
                                if sp < slen { sp = sp + 1; };
                            }
                            else { sp = sp + 1; };
                        };
                        if str_len(fname) > 0 {
                            sb_append(fb, "    if a.");
                            sb_append(fb, fname);
                            sb_append(fb, " != b.");
                            sb_append(fb, fname);
                            sb_append(fb, " { return 0; };\n");
                            field_count = field_count + 1;
                        };
                    } else {
                        keep_fields = 0;
                    };
                };
            };
            sb_append(fb, "    return 1;\n}\n");
            if field_count > 0 { sb_append(helpers, sb_to_str(fb)); };
            p = sp;
            continue;
        };
        // Tuple struct: `( type, type, ... );`.
        if next_c == 40 {
            sp = sp + 1;
            let mut count: i64 = 0;
            let mut td2: i64 = 1;
            let mut had_content: i64 = 0;
            while sp < slen && td2 > 0 {
                let tc2: i64 = str_char_at(src, sp);
                if tc2 == 40 || tc2 == 60 || tc2 == 91 || tc2 == 123 { td2 = td2 + 1; had_content = 1; }
                else if tc2 == 41 || tc2 == 62 || tc2 == 93 || tc2 == 125 {
                    td2 = td2 - 1;
                    if td2 == 0 && had_content == 1 { count = count + 1; };
                }
                else if tc2 == 44 && td2 == 1 { count = count + 1; }
                else if is_ws(tc2) == 0 { had_content = 1; };
                sp = sp + 1;
            };
            if count > 0 {
                let mut fb2: i64 = sb_new();
                sb_append(fb2, "\nfn ");
                sb_append(fb2, name);
                sb_append(fb2, "__derived_eq");
                if str_len(v089_gparams) > 0 { sb_append(fb2, v089_gparams); };
                sb_append(fb2, "(a: ");
                sb_append(fb2, name);
                if str_len(v089_gparams) > 0 { sb_append(fb2, v089_gparams); };
                sb_append(fb2, ", b: ");
                sb_append(fb2, name);
                if str_len(v089_gparams) > 0 { sb_append(fb2, v089_gparams); };
                sb_append(fb2, ") -> i64 {\n");
                let mut i: i64 = 0;
                while i < count {
                    let fname2: str = str_concat("__", str_from_int(i));
                    sb_append(fb2, "    if a.");
                    sb_append(fb2, fname2);
                    sb_append(fb2, " != b.");
                    sb_append(fb2, fname2);
                    sb_append(fb2, " { return 0; };\n");
                    i = i + 1;
                };
                sb_append(fb2, "    return 1;\n}\n");
                sb_append(helpers, sb_to_str(fb2));
            };
            p = sp;
            continue;
        };
    };
    let helpers_str: str = sb_to_str(helpers);
    if str_len(helpers_str) == 0 { return src; };
    return str_concat(src, str_concat("\n", helpers_str));
}

// mirrors expand_derive_partialeq for Clone.
// Scans for `#[derive(... Clone ...)]` + following struct decl, emits
// `fn <Name>__clone(a: <Name>) -> <Name> { return <Name> { f: a.f, … }; }`
// (named struct) or `fn <Name>__clone(a: <Name>) -> <Name> { return <Name>(a.__0, …); }`
// (tuple struct). The helper is picked up by the existing v0.3.123
// user-method dispatch path — no new dispatch code required.
#[manual_drop]
fn expand_derive_clone(src: str) -> str {
    let slen: i64 = str_len(src);
    // Cheap pre-check: bail if source has no `#[derive(` at all.
    let mut has_derive: i64 = 0;
    let mut prep: i64 = 0;
    while prep + 9 <= slen {
        if str_eq_at(src, prep, "#[derive(") == 1 { has_derive = 1; prep = slen; };
        prep = prep + 1;
    };
    if has_derive == 0 { return src; };
    let mut helpers: i64 = sb_new();
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        // Skip line comments.
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
            continue;
        };
        // Skip string literals.
        if c == 34 {
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        if c == 39 {
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
            continue;
        };
        if c != 35 || p + 9 > slen || str_eq_at(src, p, "#[derive(") == 0 {
            p = p + 1;
            continue;
        };
        // Found #[derive( at p. Walk to closing ].
        let attr_start: i64 = p;
        let mut q: i64 = p + 9;
        let mut depth_a: i64 = 1;
        while q < slen && depth_a > 0 {
            let cc: i64 = str_char_at(src, q);
            if cc == 91 { depth_a = depth_a + 1; }
            else if cc == 93 { depth_a = depth_a - 1; };
            q = q + 1;
        };
        let attr_text: str = str_substring(src, attr_start, q);
        let has_clone: i64 = if str_contains(attr_text, "Clone") == 1 { 1 } else { 0 };
        p = q;
        if has_clone == 0 { continue; };
        // Skip whitespace and any subsequent attributes / line comments.
        let mut sp: i64 = p;
        let mut keep_looking: i64 = 1;
        while keep_looking == 1 && sp < slen {
            let sc: i64 = str_char_at(src, sp);
            if sc == 32 || sc == 9 || sc == 10 || sc == 13 { sp = sp + 1; }
            else if sc == 47 && sp + 1 < slen && str_char_at(src, sp + 1) == 47 {
                while sp < slen && str_char_at(src, sp) != 10 { sp = sp + 1; };
            }
            else if sc == 35 && sp + 1 < slen && str_char_at(src, sp + 1) == 91 {
                let mut da: i64 = 1;
                sp = sp + 2;
                while sp < slen && da > 0 {
                    let dc: i64 = str_char_at(src, sp);
                    if dc == 91 { da = da + 1; }
                    else if dc == 93 { da = da - 1; };
                    sp = sp + 1;
                };
            }
            else if sc == 116 || sc == 112 {
                // Skip `pub ` modifier.
                if sp + 4 <= slen && str_eq_at(src, sp, "pub ") == 1 { sp = sp + 4; }
                else { keep_looking = 0; };
            }
            else { keep_looking = 0; };
        };
        if sp + 7 > slen || str_eq_at(src, sp, "struct ") == 0 { continue; };
        sp = sp + 7;
        // Skip ws.
        let mut ws_done: i64 = 0;
        while sp < slen && ws_done == 0 {
            let wc: i64 = str_char_at(src, sp);
            if wc == 32 || wc == 9 { sp = sp + 1; }
            else { ws_done = 1; };
        };
        // Capture name.
        let name_start: i64 = sp;
        let mut name_done: i64 = 0;
        while sp < slen && name_done == 0 {
            let nc: i64 = str_char_at(src, sp);
            if is_alnum(nc) == 1 || nc == 95 { sp = sp + 1; }
            else { name_done = 1; };
        };
        let name: str = str_substring(src, name_start, sp);
        if str_len(name) == 0 { continue; };
        // Skip ws.
        let mut ws2_done: i64 = 0;
        while sp < slen && ws2_done == 0 {
            let wc2: i64 = str_char_at(src, sp);
            if wc2 == 32 || wc2 == 9 || wc2 == 10 || wc2 == 13 { sp = sp + 1; }
            else { ws2_done = 1; };
        };
        if sp >= slen { continue; };
        let mut next_c: i64 = str_char_at(src, sp);
        // Capture generic params if present.
        let mut v764_gparams: str = "";
        if next_c == 60 {
            let v764_g_start: i64 = sp;
            let mut v764_g_depth: i64 = 1;
            sp = sp + 1;
            while sp < slen && v764_g_depth > 0 {
                let v764_gc: i64 = str_char_at(src, sp);
                if v764_gc == 60 { v764_g_depth = v764_g_depth + 1; }
                else if v764_gc == 62 { v764_g_depth = v764_g_depth - 1; };
                sp = sp + 1;
            };
            v764_gparams = str_substring(src, v764_g_start, sp);
            // Skip ws.
            let mut v764_ws_done: i64 = 0;
            while sp < slen && v764_ws_done == 0 {
                let v764_wc: i64 = str_char_at(src, sp);
                if v764_wc == 32 || v764_wc == 9 || v764_wc == 10 || v764_wc == 13 { sp = sp + 1; }
                else { v764_ws_done = 1; };
            };
            if sp >= slen { continue; };
            next_c = str_char_at(src, sp);
        };
        // Named struct: `{ field: type, ... }`.
        if next_c == 123 {
            let mut fb: i64 = sb_new();
            sb_append(fb, "\nfn ");
            sb_append(fb, name);
            sb_append(fb, "__clone");
            if str_len(v764_gparams) > 0 { sb_append(fb, v764_gparams); };
            sb_append(fb, "(a: ");
            sb_append(fb, name);
            if str_len(v764_gparams) > 0 { sb_append(fb, v764_gparams); };
            sb_append(fb, ") -> ");
            sb_append(fb, name);
            if str_len(v764_gparams) > 0 { sb_append(fb, v764_gparams); };
            sb_append(fb, " {\n    return ");
            sb_append(fb, name);
            sb_append(fb, " {\n");
            sp = sp + 1;
            let mut field_count: i64 = 0;
            let mut keep_fields: i64 = 1;
            while keep_fields == 1 && sp < slen {
                // Skip ws + commas + line comments.
                let mut skipped: i64 = 1;
                while skipped == 1 && sp < slen {
                    skipped = 0;
                    let fc1: i64 = str_char_at(src, sp);
                    if fc1 == 32 || fc1 == 9 || fc1 == 10 || fc1 == 13 || fc1 == 44 { sp = sp + 1; skipped = 1; }
                    else if fc1 == 47 && sp + 1 < slen && str_char_at(src, sp + 1) == 47 {
                        while sp < slen && str_char_at(src, sp) != 10 { sp = sp + 1; };
                        skipped = 1;
                    };
                };
                if sp >= slen { keep_fields = 0; }
                else if str_char_at(src, sp) == 125 { sp = sp + 1; keep_fields = 0; }
                else {
                    // Skip pub modifier.
                    if sp + 4 <= slen && str_eq_at(src, sp, "pub ") == 1 { sp = sp + 4; };
                    // Skip ws.
                    let mut fws_done: i64 = 0;
                    while sp < slen && fws_done == 0 {
                        let fc2: i64 = str_char_at(src, sp);
                        if fc2 == 32 || fc2 == 9 { sp = sp + 1; }
                        else { fws_done = 1; };
                    };
                    // Capture field name.
                    let f_start: i64 = sp;
                    let mut fn_done: i64 = 0;
                    while sp < slen && fn_done == 0 {
                        let fnc: i64 = str_char_at(src, sp);
                        if is_alnum(fnc) == 1 || fnc == 95 { sp = sp + 1; }
                        else { fn_done = 1; };
                    };
                    let fname: str = str_substring(src, f_start, sp);
                    // Skip ws.
                    let mut fws3_done: i64 = 0;
                    while sp < slen && fws3_done == 0 {
                        let fc3: i64 = str_char_at(src, sp);
                        if fc3 == 32 || fc3 == 9 { sp = sp + 1; }
                        else { fws3_done = 1; };
                    };
                    // Expect `:`.
                    if sp < slen && str_char_at(src, sp) == 58 {
                        sp = sp + 1;
                        // Walk type to next top-level `,` or `}`.
                        let mut td: i64 = 0;
                        let mut type_done: i64 = 0;
                        while sp < slen && type_done == 0 {
                            let tc: i64 = str_char_at(src, sp);
                            if tc == 60 || tc == 40 || tc == 91 { td = td + 1; sp = sp + 1; }
                            else if tc == 62 || tc == 41 || tc == 93 { td = td - 1; sp = sp + 1; }
                            else if (tc == 44 || tc == 125) && td == 0 { type_done = 1; }
                            else if tc == 34 {
                                sp = sp + 1;
                                while sp < slen && str_char_at(src, sp) != 34 {
                                    if str_char_at(src, sp) == 92 && sp + 1 < slen { sp = sp + 2; }
                                    else { sp = sp + 1; };
                                };
                                if sp < slen { sp = sp + 1; };
                            }
                            else { sp = sp + 1; };
                        };
                        if str_len(fname) > 0 {
                            sb_append(fb, "        ");
                            sb_append(fb, fname);
                            sb_append(fb, ": a.");
                            sb_append(fb, fname);
                            sb_append(fb, ",\n");
                            field_count = field_count + 1;
                        };
                    } else {
                        keep_fields = 0;
                    };
                };
            };
            sb_append(fb, "    };\n}\n");
            if field_count > 0 { sb_append(helpers, sb_to_str(fb)); };
            p = sp;
            continue;
        };
        // Tuple struct: `( type, type, ... );`.
        if next_c == 40 {
            sp = sp + 1;
            let mut count: i64 = 0;
            let mut td2: i64 = 1;
            let mut had_content: i64 = 0;
            while sp < slen && td2 > 0 {
                let tc2: i64 = str_char_at(src, sp);
                if tc2 == 40 || tc2 == 60 || tc2 == 91 || tc2 == 123 { td2 = td2 + 1; had_content = 1; }
                else if tc2 == 41 || tc2 == 62 || tc2 == 93 || tc2 == 125 {
                    td2 = td2 - 1;
                    if td2 == 0 && had_content == 1 { count = count + 1; };
                }
                else if tc2 == 44 && td2 == 1 { count = count + 1; }
                else if is_ws(tc2) == 0 { had_content = 1; };
                sp = sp + 1;
            };
            if count > 0 {
                let mut fb2: i64 = sb_new();
                sb_append(fb2, "\nfn ");
                sb_append(fb2, name);
                sb_append(fb2, "__clone");
                if str_len(v764_gparams) > 0 { sb_append(fb2, v764_gparams); };
                sb_append(fb2, "(a: ");
                sb_append(fb2, name);
                if str_len(v764_gparams) > 0 { sb_append(fb2, v764_gparams); };
                sb_append(fb2, ") -> ");
                sb_append(fb2, name);
                if str_len(v764_gparams) > 0 { sb_append(fb2, v764_gparams); };
                sb_append(fb2, " {\n    return ");
                sb_append(fb2, name);
                sb_append(fb2, "(");
                let mut i: i64 = 0;
                while i < count {
                    if i > 0 { sb_append(fb2, ", "); };
                    sb_append(fb2, "a.");
                    sb_append(fb2, str_concat("__", str_from_int(i)));
                    i = i + 1;
                };
                sb_append(fb2, ");\n}\n");
                sb_append(helpers, sb_to_str(fb2));
            };
            p = sp;
            continue;
        };
    };
    let helpers_str2: str = sb_to_str(helpers);
    if str_len(helpers_str2) == 0 { return src; };
    return str_concat(src, str_concat("\n", helpers_str2));
}

#[manual_drop]
fn expand_actor_decl_keyword(src: str) -> str {
    if sendable_source_has_actor_decl(src) == 0 { return src; };
    let mut sb: i64 = sb_new();
    let mut actors: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append_char_at(sb, src, p);
                p = p + 1;
            };
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
        } else if c == 39 {
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
        } else {
            let actor_name: str = sendable_actor_decl_name_at(src, p);
            if str_len(actor_name) > 0 {
                sb_append(sb, "struct");
                actors.push(actor_name);
                p = p + 5;
            } else {
                sb_append_char_at(sb, src, p);
                p = p + 1;
            };
        };
    };
    if vec_len(actors) > 0 {
        sb_append(sb, "\n");
        let mut i: i64 = 0;
        while i < vec_len(actors) {
            sb_append(sb, "//__NUC35A:");
            sb_append(sb, vec_get(actors, i));
            sb_append(sb, "\n");
            i = i + 1;
        };
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn sendable_source_has_spawn_call(src: str) -> i64 {
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        } else if c == 34 || c == 39 {
            let quote: i64 = c;
            p = p + 1;
            while p < slen && str_char_at(src, p) != quote {
                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
        } else {
            if str_eq_at(src, p, "async_spawn(") == 1 { return 1; };
            if str_eq_at(src, p, "thread_spawn(") == 1 { return 1; };
            if str_eq_at(src, p, "conc_spawn(") == 1 { return 1; };
            p = p + 1;
        };
    };
    return 0;
}

#[manual_drop]
fn sendable_is_bare_ident(text: str) -> i64 {
    let t: str = str_trim(text);
    let n: i64 = str_len(t);
    if n == 0 { return 0; };
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(t, i);
        if i == 0 {
            if is_alpha(c) == 0 { if c != 95 { return 0; }; };
        } else {
            if is_alnum(c) == 0 { if c != 95 { return 0; }; };
        };
        i = i + 1;
    };
    return 1;
}

#[manual_drop]
fn sendable_second_type(t: str) -> str {
    let n: i64 = str_len(t);
    let mut p: i64 = 0;
    while p < n && str_char_at(t, p) != 60 { p = p + 1; };
    if p >= n { return ""; };
    p = p + 1;
    let mut depth: i64 = 1;
    let mut comma: i64 = 0 - 1;
    while p < n && comma < 0 {
        let c: i64 = str_char_at(t, p);
        if c == 60 { depth = depth + 1; }
        else if c == 62 { depth = depth - 1; }
        else if c == 44 && depth == 1 { comma = p; };
        p = p + 1;
    };
    if comma < 0 { return ""; };
    let start: i64 = comma + 1;
    let mut q: i64 = start;
    depth = 1;
    while q < n {
        let c2: i64 = str_char_at(t, q);
        if c2 == 60 { depth = depth + 1; }
        else if c2 == 62 {
            depth = depth - 1;
            if depth == 0 { return str_trim(str_substring(t, start, q)); };
        };
        q = q + 1;
    };
    return "";
}

#[manual_drop]
fn sendable_type_forced_not(source: str, typ: str) -> i64 {
    // original loop allocated a `str_substring(source, p, slen)`
    // of size (slen - p) on every iteration before passing to str_index_of —
    // O(slen²) per call, the v0.3.205 strlen-in-substring class. Replaced with
    // a single linear scan using str_eq_at (O(slen × pat_len) per call).
    let base: str = type_base_name(str_trim(typ));
    if str_len(base) == 0 { return 0; };
    let pat: str = "#[not_sendable]";
    let plen: i64 = str_len(pat);
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i + plen <= slen {
        if str_eq_at_len(source, i, pat, plen) == 1 {
            let mut j: i64 = i + plen;
            while j + 7 <= slen && str_eq_at(source, j, "struct ") == 0 {
                j = j + 1;
            };
            if j + 7 > slen { return 0; };
            j = j + 7;
            while j < slen && is_ws(str_char_at(source, j)) == 1 { j = j + 1; };
            let ns: i64 = j;
            while j < slen && (is_alnum(str_char_at(source, j)) == 1 || str_char_at(source, j) == 95) { j = j + 1; };
            if j > ns && str_eq(str_substring(source, ns, j), base) == 1 { return 1; };
            i = j;
        } else {
            i = i + 1;
        };
    };
    return 0;
}

#[manual_drop]
fn sendable_type_has_impl(source: str, typ: str) -> i64 {
    let base: str = type_base_name(str_trim(typ));
    if str_len(base) == 0 { return 0; };
    let pat: str = str_concat("impl Sendable for ", base);
    if str_index_of(source, pat) >= 0 { return 1; };
    return 0;
}

#[manual_drop]
fn sendable_type_ok(source: str, typ: str) -> i64 {
    let t: str = str_trim(typ);
    if str_len(t) == 0 { return 1; };
    if str_starts_with(t, "&mut ") == 1 { return 0; };
    if str_starts_with(t, "&") == 1 {
        return sendable_type_ok(source, str_trim(str_substring(t, 1, str_len(t))));
    };
    let base: str = type_base_name(t);
    if sendable_type_forced_not(source, base) == 1 { return 0; };
    if str_eq(base, "i8") == 1 { return 1; };
    if str_eq(base, "i16") == 1 { return 1; };
    if str_eq(base, "i32") == 1 { return 1; };
    if str_eq(base, "i64") == 1 { return 1; };
    if str_eq(base, "isize") == 1 { return 1; };
    if str_eq(base, "u8") == 1 { return 1; };
    if str_eq(base, "u16") == 1 { return 1; };
    if str_eq(base, "u32") == 1 { return 1; };
    if str_eq(base, "u64") == 1 { return 1; };
    if str_eq(base, "usize") == 1 { return 1; };
    if str_eq(base, "bool") == 1 { return 1; };
    if str_eq(base, "char") == 1 { return 1; };
    if str_eq(base, "f32") == 1 { return 1; };
    if str_eq(base, "f64") == 1 { return 1; };
    if str_eq(base, "str") == 1 { return 1; };
    if str_eq(base, "String") == 1 { return 1; };
    if sendable_type_has_impl(source, base) == 1 { return 1; };
    if str_eq(base, "Vec") == 1 { return sendable_type_ok(source, type_first_arg(t)); };
    if str_eq(base, "Option") == 1 { return sendable_type_ok(source, type_first_arg(t)); };
    if str_eq(base, "Box") == 1 { return sendable_type_ok(source, type_first_arg(t)); };
    if str_eq(base, "Arc") == 1 { return sendable_type_ok(source, type_first_arg(t)); };
    if str_eq(base, "Result") == 1 {
        if sendable_type_ok(source, type_first_arg(t)) == 0 { return 0; };
        return sendable_type_ok(source, sendable_second_type(t));
    };
    return 0;
}

#[manual_drop]
fn sendable_binding_type(source: str, var_name: str) -> str {
    let pat1: str = str_concat("let ", str_concat(var_name, ":"));
    let pat2: str = str_concat("let mut ", str_concat(var_name, ":"));
    let mut p: i64 = str_index_of(source, pat1);
    let mut start: i64 = 0;
    if p >= 0 { start = p + str_len(pat1); }
    else {
        p = str_index_of(source, pat2);
        if p < 0 { return ""; };
        start = p + str_len(pat2);
    };
    let slen: i64 = str_len(source);
    let mut q: i64 = start;
    while q < slen {
        let c: i64 = str_char_at(source, q);
        if c == 61 || c == 59 || c == 10 || c == 13 { return str_trim(str_substring(source, start, q)); };
        q = q + 1;
    };
    return str_trim(str_substring(source, start, q));
}

#[manual_drop]
fn sendable_find_matching_paren(text: str, open_pos: i64) -> i64 {
    let n: i64 = str_len(text);
    let mut depth: i64 = 1;
    let mut p: i64 = open_pos + 1;
    while p < n {
        let c: i64 = str_char_at(text, p);
        if c == 34 {
            p = p + 1;
            while p < n && str_char_at(text, p) != 34 {
                if str_char_at(text, p) == 92 && p + 1 < n { p = p + 2; }
                else { p = p + 1; };
            };
        } else if c == 40 { depth = depth + 1; }
        else if c == 41 {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn sendable_find_top_comma(text: str, start: i64, end: i64) -> i64 {
    let mut depth: i64 = 0;
    let mut p: i64 = start;
    while p < end {
        let c: i64 = str_char_at(text, p);
        if c == 40 || c == 60 || c == 91 { depth = depth + 1; }
        else if c == 41 || c == 62 || c == 93 { if depth > 0 { depth = depth - 1; }; }
        else if c == 44 && depth == 0 { return p; };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn enforce_sendable_spawn_name(diags: Vec<i32>, source: str, call_name: str) -> i64 {
    // same O(slen²) class as sendable_type_forced_not /
    // sendable_actor_vars — original scanned a fresh `str_substring(source, p, slen)`
    // per iteration. Replaced with linear str_eq_at scan.
    let pat: str = str_concat(call_name, "(");
    let plen: i64 = str_len(pat);
    let slen: i64 = str_len(source);
    let mut added: i64 = 0;
    let mut i: i64 = 0;
    while i + plen <= slen {
        if str_eq_at_len(source, i, pat, plen) == 0 { i = i + 1; continue; };
        let hit: i64 = i;
        let open_pos: i64 = hit + plen - 1;
        let close_pos: i64 = sendable_find_matching_paren(source, open_pos);
        if close_pos < 0 { return added; };
        let comma: i64 = sendable_find_top_comma(source, open_pos + 1, close_pos);
        if comma > 0 {
            let mut arg_start_byte: i64 = comma + 1;
            while arg_start_byte < close_pos && is_ws(str_char_at(source, arg_start_byte)) == 1 { arg_start_byte = arg_start_byte + 1; };
            let arg: str = str_trim(str_substring(source, comma + 1, close_pos));
            let mut code: str = "";
            let mut msg: str = "";
            if str_starts_with(arg, "&mut ") == 1 {
                code = "RACE-005";
                msg = str_concat("`&mut` argument `", str_concat(arg, "` crosses a thread boundary"));
            } else if str_starts_with(arg, "&") == 0 && sendable_is_bare_ident(arg) == 1 {
                let ty: str = sendable_binding_type(source, arg);
                if str_len(ty) > 0 {
                    if sendable_type_forced_not(source, ty) == 1 {
                        code = "RACE-008";
                        msg = str_concat("`#[not_sendable]` type `", str_concat(type_base_name(ty), "` used where Sendable is required"));
                    } else if sendable_type_ok(source, ty) == 0 {
                        code = "RACE-001";
                        msg = str_concat("non-Sendable value `", str_concat(arg, str_concat("` of type `", str_concat(ty, "` crosses a thread boundary"))));
                    };
                };
            };
            if str_len(code) > 0 {
                let mut lc: Vec<i32> = diag_linecol_at_byte(source, arg_start_byte);
                diag_add_ex(diags, "error", "race", code, msg, call_name, vec_get(lc, 0), vec_get(lc, 1), "");
                added = added + 1;
            };
        };
        i = close_pos + 1;
    };
    return added;
}

#[manual_drop]
fn sendable_collect_actor_names(source: str) -> Vec<i32> {
    // O(slen²) → O(slen × pat_len) via str_eq_at scan.
    let mut out: Vec<i32> = Vec::new();
    let pat: str = "//__NUC35A:";
    let plen: i64 = str_len(pat);
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i + plen <= slen {
        if str_eq_at_len(source, i, pat, plen) == 1 {
            let mut q: i64 = i + plen;
            let ns: i64 = q;
            while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
            if q > ns { out.push(str_substring(source, ns, q)); };
            i = q;
        } else {
            i = i + 1;
        };
    };
    return out;
}

#[manual_drop]
fn sendable_find_matching_brace(text: str, open_pos: i64) -> i64 {
    let n: i64 = str_len(text);
    let mut depth: i64 = 1;
    let mut p: i64 = open_pos + 1;
    while p < n {
        let c: i64 = str_char_at(text, p);
        if c == 123 { depth = depth + 1; }
        else if c == 125 {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn sendable_actor_fields(source: str, actor_name: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let pat: str = str_concat("struct ", str_concat(actor_name, " {"));
    let p: i64 = str_index_of(source, pat);
    if p < 0 { return out; };
    let open_pos: i64 = p + str_len(pat) - 1;
    let close_pos: i64 = sendable_find_matching_brace(source, open_pos);
    if close_pos < 0 { return out; };
    let mut q: i64 = open_pos + 1;
    while q < close_pos {
        while q < close_pos && (is_ws(str_char_at(source, q)) == 1 || str_char_at(source, q) == 44) { q = q + 1; };
        let ns: i64 = q;
        while q < close_pos && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
        if q > ns {
            let name: str = str_substring(source, ns, q);
            while q < close_pos && is_ws(str_char_at(source, q)) == 1 { q = q + 1; };
            if q < close_pos && str_char_at(source, q) == 58 { out.push(name); };
        };
        while q < close_pos && str_char_at(source, q) != 44 && str_char_at(source, q) != 10 && str_char_at(source, q) != 13 { q = q + 1; };
        q = q + 1;
    };
    return out;
}

#[manual_drop]
fn sendable_actor_vars(source: str, actor_name: str) -> Vec<i32> {
    // original loop allocated `str_substring(source, p, slen)`
    // per iteration before str_index_of — same O(slen²) class as
    // sendable_type_forced_not. Replaced with single linear scan using
    // str_eq_at to find each `let ` / `let mut ` position directly.
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i + 4 <= slen {
        if str_eq_at(source, i, "let ") == 1 {
            let mut q: i64 = i + 4;
            if q + 4 <= slen && str_eq_at(source, q, "mut ") == 1 { q = q + 4; };
            let ns: i64 = q;
            while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
            if q > ns {
                let vname: str = str_substring(source, ns, q);
                while q < slen && is_ws(str_char_at(source, q)) == 1 { q = q + 1; };
                if q < slen && str_char_at(source, q) == 58 {
                    q = q + 1;
                    let ts: i64 = q;
                    while q < slen && str_char_at(source, q) != 61 && str_char_at(source, q) != 59 && str_char_at(source, q) != 10 { q = q + 1; };
                    let ty: str = type_base_name(str_trim(str_substring(source, ts, q)));
                    if str_eq(ty, actor_name) == 1 { out.push(vname); };
                };
            };
            i = q + 1;
        } else {
            i = i + 1;
        };
    };
    return out;
}

#[manual_drop]
fn enforce_sendable_actor_fields(diags: Vec<i32>, source: str) -> i64 {
    let actors: Vec<i32> = sendable_collect_actor_names(source);
    let mut added: i64 = 0;
    let mut ai: i64 = 0;
    while ai < vec_len(actors) {
        let actor_name: str = vec_get(actors, ai);
        let fields: Vec<i32> = sendable_actor_fields(source, actor_name);
        let vars: Vec<i32> = sendable_actor_vars(source, actor_name);
        let mut vi: i64 = 0;
        while vi < vec_len(vars) {
            let vname: str = vec_get(vars, vi);
            let mut fi: i64 = 0;
            while fi < vec_len(fields) {
                let field: str = vec_get(fields, fi);
                let pat: str = str_concat(vname, str_concat(".", field));
                if str_index_of(source, pat) >= 0 {
                    let msg: str = str_concat("actor `", str_concat(actor_name, str_concat("` field `", str_concat(field, "` cannot be accessed directly outside actor isolation"))));
                    let mut lc: Vec<i32> = find_linecol_in_source(source, pat, pat);
                    diag_add_ex(diags, "error", "race", "RACE-003", msg, actor_name, vec_get(lc, 0), vec_get(lc, 1), "");
                    added = added + 1;
                    fi = vec_len(fields);
                };
                fi = fi + 1;
            };
            vi = vi + 1;
        };
        ai = ai + 1;
    };
    return added;
}

#[manual_drop]
fn enforce_sendable_contracts(diags: Vec<i32>, source: str) -> Vec<i32> {
    let has_spawn: i64 = sendable_source_has_spawn_call(source);
    let has_actor: i64 = if str_index_of(source, "//__NUC35A:") >= 0 { 1 } else { 0 };
    if has_spawn == 0 && has_actor == 0 { return diags; };
    if has_spawn == 1 {
        enforce_sendable_spawn_name(diags, source, "async_spawn");
        enforce_sendable_spawn_name(diags, source, "thread_spawn");
        enforce_sendable_spawn_name(diags, source, "conc_spawn");
    };
    if has_actor == 1 { enforce_sendable_actor_fields(diags, source); };
    return diags;
}

// v0.4.277 RFC-0006 — scan a contract-predicate text for `old(`
// pseudo-call. Same word-boundary technique as
// `ensure_text_uses_result`: `old` must be preceded by start-of-
// text or non-ident char (so `older` / `bold(...)` don't match)
// and followed by `(`. Used to reject `#[require(old(...) ...)]`
// at compile time.
#[manual_drop]
fn contract_text_uses_old(text: str) -> i64 {
    let needle: str = "old";
    let nlen: i64 = str_len(needle);
    let tlen: i64 = str_len(text);
    let mut i: i64 = 0;
    while i + nlen + 1 <= tlen {
        let win: str = str_substring(text, i, i + nlen);
        if str_eq(win, needle) == 1 {
            let prev_ok: i64 = if i == 0 { 1 } else {
                let pc: str = str_substring(text, i - 1, i);
                let p_alpha: i64 = if str_index_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", pc) >= 0 { 1 } else { 0 };
                let p_digit: i64 = if str_index_of("0123456789", pc) >= 0 { 1 } else { 0 };
                if p_alpha == 0 { if p_digit == 0 { 1 } else { 0 } } else { 0 }
            };
            let next_paren: i64 = if str_eq(str_substring(text, i + nlen, i + nlen + 1), "(") == 1 { 1 } else { 0 };
            if prev_ok == 1 { if next_paren == 1 { return 1; }; };
        };
        i = i + 1;
    };
    return 0;
}

// v0.4.283 RFC-0006 — scan a contract-predicate text for any
// identifier that doesn't resolve to a fn parameter, a DbC
// keyword (result / old / self / true / false / None / Some /
// Ok / Err / null), a CamelCase type or enum variant (first
// char uppercase), an ALL_CAPS const (all chars uppercase /
// digits / underscores), or a fn-call site (followed by `(`).
// Returns the unbound ident name on first match, or "" if all
// idents resolve. Conservative: we'd rather miss a real
// undefined-ident (false negative — adopter sees the existing
// clang-link error) than reject a valid identifier.
// Regression fixed in v0.4.283: pre-fix,
// `#[require(undefined_var > 0)]` surfaced a misleading clang-
// link "undefined function `undefined_var()`" error. CONTRACT-011
// halts at parse time with the actual unbound ident named.
#[manual_drop]
fn find_unbound_ident_in_contract(source: str, fn_name: str, predicate: str) -> str {
    let n: i64 = str_len(predicate);
    let mut i: i64 = 0;
    while i < n {
        let c: str = str_substring(predicate, i, i + 1);
        // Find start of an identifier: [A-Za-z_]
        let is_ident_start: i64 = if str_index_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", c) >= 0 { 1 } else { 0 };
        if is_ident_start == 0 { i = i + 1; continue; };
        // Walk to end of ident.
        let start: i64 = i;
        let mut end: i64 = i;
        let mut keep_going: i64 = 1;
        while end < n && keep_going == 1 {
            let ch: str = str_substring(predicate, end, end + 1);
            let alpha: i64 = if str_index_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", ch) >= 0 { 1 } else { 0 };
            let digit: i64 = if str_index_of("0123456789", ch) >= 0 { 1 } else { 0 };
            if alpha == 0 {
                if digit == 0 { keep_going = 0; }
                else { end = end + 1; };
            } else {
                end = end + 1;
            };
        };
        i = end;
        let ident: str = str_substring(predicate, start, end);
        // Skip if followed by `(` (fn call site) — also accepts whitespace.
        let mut k: i64 = end;
        while k < n {
            let kc: str = str_substring(predicate, k, k + 1);
            if str_eq(kc, " ") == 1 || str_eq(kc, "\t") == 1 || str_eq(kc, "\n") == 1 { k = k + 1; continue; };
            break;
        };
        let next_char: str = if k >= n { "" } else { str_substring(predicate, k, k + 1) };
        let next_two: str = if k + 1 >= n { next_char } else { str_substring(predicate, k, k + 2) };
        // Skip if preceded by `.` (field/method access) — scan back through whitespace.
        let mut j: i64 = start;
        while j > 0 {
            let jc: str = str_substring(predicate, j - 1, j);
            if str_eq(jc, " ") == 1 || str_eq(jc, "\t") == 1 || str_eq(jc, "\n") == 1 { j = j - 1; continue; };
            break;
        };
        let prev_char: str = if j == 0 { "" } else { str_substring(predicate, j - 1, j) };
        let prev_two: str = if j < 2 { prev_char } else { str_substring(predicate, j - 2, j) };
        // === Skip rules (any one matches → not unbound) ===
        // Followed by `(` — fn call site.
        if str_eq(next_char, "(") == 1 { continue; };
        // Followed by `::` — path syntax.
        if str_eq(next_two, "::") == 1 { continue; };
        // Followed by `[` — index expr (caller chose this form).
        if str_eq(next_char, "[") == 1 { continue; };
        // Followed by `{` — struct-init expr.
        if str_eq(next_char, "{") == 1 { continue; };
        // Preceded by `.` — field/method access.
        if str_eq(prev_char, ".") == 1 { continue; };
        // Preceded by `::` — path tail (already-resolved variant).
        if str_eq(prev_two, "::") == 1 { continue; };
        // DbC keyword allowlist.
        if str_eq(ident, "result") == 1 { continue; };
        if str_eq(ident, "old") == 1 { continue; };
        if str_eq(ident, "self") == 1 { continue; };
        if str_eq(ident, "true") == 1 { continue; };
        if str_eq(ident, "false") == 1 { continue; };
        if str_eq(ident, "None") == 1 { continue; };
        if str_eq(ident, "Some") == 1 { continue; };
        if str_eq(ident, "Ok") == 1 { continue; };
        if str_eq(ident, "Err") == 1 { continue; };
        if str_eq(ident, "null") == 1 { continue; };
        // CamelCase first char (Type / Variant / Module name).
        let first_char: str = str_substring(ident, 0, 1);
        if str_index_of("ABCDEFGHIJKLMNOPQRSTUVWXYZ", first_char) >= 0 { continue; };
        // Fn parameter.
        let pty: str = fn_param_type(source, fn_name, ident);
        if str_len(pty) > 0 { continue; };
        // Looks unbound — return it.
        return ident;
    };
    return "";
}

// v0.4.272 RFC-0006 — scan an ensure-predicate text for a bare
// `result` identifier reference. Walks the text, tracking word
// boundaries: a hit must be preceded by start-of-text or non-
// ident char, and followed by end-of-text or non-ident char.
// Used to reject `#[ensure(result ...)]` on void fns.
#[manual_drop]
fn ensure_text_uses_result(text: str) -> i64 {
    let needle: str = "result";
    let nlen: i64 = str_len(needle);
    let tlen: i64 = str_len(text);
    let mut i: i64 = 0;
    while i + nlen <= tlen {
        let win: str = str_substring(text, i, i + nlen);
        if str_eq(win, needle) == 1 {
            let prev_ok: i64 = if i == 0 { 1 } else {
                let pc: str = str_substring(text, i - 1, i);
                let p_alpha: i64 = if str_index_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", pc) >= 0 { 1 } else { 0 };
                let p_digit: i64 = if str_index_of("0123456789", pc) >= 0 { 1 } else { 0 };
                if p_alpha == 0 { if p_digit == 0 { 1 } else { 0 } } else { 0 }
            };
            let next_ok: i64 = if i + nlen >= tlen { 1 } else {
                let nc: str = str_substring(text, i + nlen, i + nlen + 1);
                let n_alpha: i64 = if str_index_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", nc) >= 0 { 1 } else { 0 };
                let n_digit: i64 = if str_index_of("0123456789", nc) >= 0 { 1 } else { 0 };
                if n_alpha == 0 { if n_digit == 0 { 1 } else { 0 } } else { 0 }
            };
            if prev_ok == 1 { if next_ok == 1 { return 1; }; };
        };
        i = i + 1;
    };
    return 0;
}

// v0.4.271 RFC-0006 — quick check whether `text` is a bare identifier
// (only `[A-Za-z_][A-Za-z0-9_]*`, no whitespace / punctuation /
// operators). Conservative: complex `old()` expressions like
// `old(self.field)` or `old(get_vec())` skip the heap-aliased
// reject (false negative is preferred over false positive — the
// runtime panic still surfaces in those edge cases).
#[manual_drop]
fn is_bare_ident(text: str) -> i64 {
    let t: str = str_trim(text);
    let n: i64 = str_len(t);
    if n == 0 { return 0; };
    let mut i: i64 = 0;
    while i < n {
        let c: str = str_substring(t, i, i + 1);
        let is_alpha: i64 = if str_index_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", c) >= 0 { 1 } else { 0 };
        let is_digit: i64 = if str_index_of("0123456789", c) >= 0 { 1 } else { 0 };
        if i == 0 {
            if is_alpha == 0 { return 0; };
        } else {
            if is_alpha == 0 {
                if is_digit == 0 { return 0; };
            };
        };
        i = i + 1;
    };
    return 1;
}

// v0.4.257 RFC-0006 Liskov substrate — count #[require] and
// #[ensure] attributes per trait method declaration. Returns flat
// Vec of (trait_name, method_name, req_count, ens_count) tuples
// where the count fields are stored as decimal strings (the flat
// Vec<i32> representation forces all entries to be the same shape).
// Walking heuristic: scan source for `trait NAME {` blocks; track
// brace depth so nested decls don't escape; within the trait,
// scan for `fn METHOD(`; before each fn, scan back/forward for
// preceding `#[require(...)]` / `#[ensure(...)]` attributes
// (those that fall between the previous statement boundary and
// the fn keyword).
#[manual_drop]
fn collect_trait_method_attrs(source: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let trait_pat: str = "trait ";
    let tplen: i64 = str_len(trait_pat);
    let mut p: i64 = 0;
    while p + tplen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        // Match "trait " only at identifier boundary.
        let mut at_boundary: i64 = 1;
        if p > 0 {
            let prev: i64 = str_char_at(source, p - 1);
            if is_alnum(prev) == 1 || prev == 95 { at_boundary = 0; };
        };
        let mut tm: i64 = at_boundary;
        if tm == 1 {
            let mut k: i64 = 0;
            while k < tplen {
                if str_char_at(source, p + k) != str_char_at(trait_pat, k) { tm = 0; break; };
                k = k + 1;
            };
        };
        if tm == 1 {
            let n_start: i64 = p + tplen;
            let mut q: i64 = n_start;
            while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                q = q + 1;
            };
            let trait_name: str = str_substring(source, n_start, q);
            // Skip whitespace to find `{`.
            while q < slen && str_char_at(source, q) != 123 && str_char_at(source, q) != 59 { q = q + 1; };
            if q >= slen || str_char_at(source, q) == 59 {
                p = q + 1;
                continue;
            };
            // q points at `{`. Walk brace-balanced trait body.
            q = q + 1;
            let mut brace_depth: i64 = 1;
            let mut last_attr_end: i64 = q;
            while q < slen && brace_depth > 0 {
                let cc: i64 = str_char_at(source, q);
                if cc == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                    continue;
                };
                if cc == 34 {
                    q = q + 1;
                    while q < slen && str_char_at(source, q) != 34 {
                        if str_char_at(source, q) == 92 && q + 1 < slen { q = q + 2; }
                        else { q = q + 1; };
                    };
                    if q < slen { q = q + 1; };
                    continue;
                };
                if cc == 123 { brace_depth = brace_depth + 1; q = q + 1; continue; };
                if cc == 125 { brace_depth = brace_depth - 1; q = q + 1; continue; };
                // Within the trait body, look for `fn METHOD(`.
                if brace_depth == 1 && cc == 102 && q + 3 < slen
                    && str_char_at(source, q + 1) == 110 && str_char_at(source, q + 2) == 32 {
                    let mut at_fn_boundary: i64 = 1;
                    if q > 0 {
                        let prev_fn: i64 = str_char_at(source, q - 1);
                        if is_alnum(prev_fn) == 1 || prev_fn == 95 { at_fn_boundary = 0; };
                    };
                    if at_fn_boundary == 1 {
                        let m_start: i64 = q + 3;
                        let mut mq: i64 = m_start;
                        while mq < slen && (is_alnum(str_char_at(source, mq)) == 1 || str_char_at(source, mq) == 95) {
                            mq = mq + 1;
                        };
                        let method_name: str = str_substring(source, m_start, mq);
                        // Count #[require( and #[ensure( in the
                        // window [last_attr_end, q).
                        let mut req_n: i64 = 0;
                        let mut ens_n: i64 = 0;
                        let mut wp: i64 = last_attr_end;
                        let req_pat: str = "#[require(";
                        let req_plen: i64 = str_len(req_pat);
                        let ens_pat: str = "#[ensure(";
                        let ens_plen: i64 = str_len(ens_pat);
                        while wp < q {
                            if wp + req_plen <= q {
                                let mut mr: i64 = 1;
                                let mut kk: i64 = 0;
                                while kk < req_plen {
                                    if str_char_at(source, wp + kk) != str_char_at(req_pat, kk) { mr = 0; break; };
                                    kk = kk + 1;
                                };
                                if mr == 1 { req_n = req_n + 1; wp = wp + req_plen; continue; };
                            };
                            if wp + ens_plen <= q {
                                let mut me: i64 = 1;
                                let mut kk2: i64 = 0;
                                while kk2 < ens_plen {
                                    if str_char_at(source, wp + kk2) != str_char_at(ens_pat, kk2) { me = 0; break; };
                                    kk2 = kk2 + 1;
                                };
                                if me == 1 { ens_n = ens_n + 1; wp = wp + ens_plen; continue; };
                            };
                            wp = wp + 1;
                        };
                        out.push(trait_name);
                        out.push(method_name);
                        out.push(str_from_int(req_n));
                        out.push(str_from_int(ens_n));
                        // Walk past the fn signature + body to set
                        // last_attr_end = position after fn's `;` or `}`.
                        // Simplest: continue from current q; the next
                        // attribute search will start after the fn line.
                        q = mq;
                        last_attr_end = mq;
                        continue;
                    };
                };
                q = q + 1;
            };
            p = q;
            continue;
        };
        p = p + 1;
    };
    return out;
}

// v0.4.257 RFC-0006 Liskov substrate — count #[require] and
// #[ensure] attributes per impl-trait method definition. Returns
// flat Vec of (trait_name, type_name, method_name, req_count,
// ens_count) tuples. Only trait impls (the `impl Trait for Type`
// form) are captured; inherent impls (`impl Type`) are skipped.
#[manual_drop]
fn collect_impl_trait_method_attrs(source: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let impl_pat: str = "impl ";
    let iplen: i64 = str_len(impl_pat);
    let mut p: i64 = 0;
    while p + iplen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut at_boundary: i64 = 1;
        if p > 0 {
            let prev: i64 = str_char_at(source, p - 1);
            if is_alnum(prev) == 1 || prev == 95 { at_boundary = 0; };
        };
        let mut im: i64 = at_boundary;
        if im == 1 {
            let mut k: i64 = 0;
            while k < iplen {
                if str_char_at(source, p + k) != str_char_at(impl_pat, k) { im = 0; break; };
                k = k + 1;
            };
        };
        if im == 1 {
            let id1_start: i64 = p + iplen;
            let mut q: i64 = id1_start;
            while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                q = q + 1;
            };
            let id1: str = str_substring(source, id1_start, q);
            // Skip whitespace.
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) { q = q + 1; };
            // Look for `for ` to confirm trait-impl form.
            if q + 4 > slen
                || str_char_at(source, q) != 102
                || str_char_at(source, q + 1) != 111
                || str_char_at(source, q + 2) != 114
                || str_char_at(source, q + 3) != 32 {
                p = q;
                continue;
            };
            q = q + 4;
            let id2_start: i64 = q;
            while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                q = q + 1;
            };
            let id2: str = str_substring(source, id2_start, q);
            // Skip to `{`.
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            if q >= slen { p = q; continue; };
            q = q + 1;
            let mut brace_depth: i64 = 1;
            let mut last_attr_end: i64 = q;
            while q < slen && brace_depth > 0 {
                let cc: i64 = str_char_at(source, q);
                if cc == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                    continue;
                };
                if cc == 34 {
                    q = q + 1;
                    while q < slen && str_char_at(source, q) != 34 {
                        if str_char_at(source, q) == 92 && q + 1 < slen { q = q + 2; }
                        else { q = q + 1; };
                    };
                    if q < slen { q = q + 1; };
                    continue;
                };
                if cc == 123 { brace_depth = brace_depth + 1; q = q + 1; continue; };
                if cc == 125 { brace_depth = brace_depth - 1; q = q + 1; continue; };
                if brace_depth == 1 && cc == 102 && q + 3 < slen
                    && str_char_at(source, q + 1) == 110 && str_char_at(source, q + 2) == 32 {
                    let mut at_fn_b: i64 = 1;
                    if q > 0 {
                        let prev_fn: i64 = str_char_at(source, q - 1);
                        if is_alnum(prev_fn) == 1 || prev_fn == 95 { at_fn_b = 0; };
                    };
                    if at_fn_b == 1 {
                        let m_start: i64 = q + 3;
                        let mut mq: i64 = m_start;
                        while mq < slen && (is_alnum(str_char_at(source, mq)) == 1 || str_char_at(source, mq) == 95) {
                            mq = mq + 1;
                        };
                        let method_name: str = str_substring(source, m_start, mq);
                        let mut req_n: i64 = 0;
                        let mut ens_n: i64 = 0;
                        let mut wp: i64 = last_attr_end;
                        let req_pat: str = "#[require(";
                        let req_plen: i64 = str_len(req_pat);
                        let ens_pat: str = "#[ensure(";
                        let ens_plen: i64 = str_len(ens_pat);
                        while wp < q {
                            if wp + req_plen <= q {
                                let mut mr: i64 = 1;
                                let mut kk: i64 = 0;
                                while kk < req_plen {
                                    if str_char_at(source, wp + kk) != str_char_at(req_pat, kk) { mr = 0; break; };
                                    kk = kk + 1;
                                };
                                if mr == 1 { req_n = req_n + 1; wp = wp + req_plen; continue; };
                            };
                            if wp + ens_plen <= q {
                                let mut me: i64 = 1;
                                let mut kk2: i64 = 0;
                                while kk2 < ens_plen {
                                    if str_char_at(source, wp + kk2) != str_char_at(ens_pat, kk2) { me = 0; break; };
                                    kk2 = kk2 + 1;
                                };
                                if me == 1 { ens_n = ens_n + 1; wp = wp + ens_plen; continue; };
                            };
                            wp = wp + 1;
                        };
                        out.push(id1);
                        out.push(id2);
                        out.push(method_name);
                        out.push(str_from_int(req_n));
                        out.push(str_from_int(ens_n));
                        q = mq;
                        last_attr_end = mq;
                        continue;
                    };
                };
                q = q + 1;
            };
            p = q;
            continue;
        };
        p = p + 1;
    };
    return out;
}

// Look up (req_count, ens_count) for a trait method. Returns
// `(0 - 1, 0 - 1)` if not found.
#[manual_drop]
fn lookup_trait_method_counts(attrs: Vec<i32>, trait_name: str, method_name: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let n: i64 = vec_len(attrs);
    let mut i: i64 = 0;
    while i + 3 < n {
        if str_eq(vec_get(attrs, i), trait_name) == 1
            && str_eq(vec_get(attrs, i + 1), method_name) == 1 {
            out.push(str_to_int(vec_get(attrs, i + 2)));
            out.push(str_to_int(vec_get(attrs, i + 3)));
            return out;
        };
        i = i + 4;
    };
    out.push(0 - 1);
    out.push(0 - 1);
    return out;
}

// For a given fn_name marked #[no_alloc], scan its body text for
// literal `<alloc_call>(` patterns and emit RT-001 diags into
// `diags` for each match.
#[manual_drop]
fn check_no_alloc_violations(diags: Vec<i32>, source: str, fn_name: str) {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            // Walk to the body's opening '{'.
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            if q < slen {
                let body_start: i64 = q + 1;
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                // T3.7 (v0.3.6): strip `"..."` strings and `// ...`
                // line comments before scanning so a `"Vec::new"` or
                // `// uses vec_push` text doesn't false-positive.
                let body: str = strip_strings_and_line_comments(body_raw);
                // Walk every alloc-builtin name and check str_contains
                // for `<name>(` in the body. Each match becomes one
                // diag; we don't dedup, so two `vec_push(...)` calls
                // produce two RT-001 entries.
                let alloc_names: Vec<i32> = no_alloc_check_list();
                let mut ai: i64 = 0;
                while ai < vec_len(alloc_names) {
                    let n: str = vec_get(alloc_names, ai);
                    // For dot-prefixed method-call sugar (e.g. `.push`)
                    // the `(` separator is already implied; for the
                    // bare names append `(` to anchor the match.
                    let pat: str = str_concat(n, "(");
                    if str_contains(body, pat) == 1 {
                        let msg: str = str_concat("`", str_concat(n, str_concat("` allocates but `", str_concat(fn_name, "` is marked #[no_alloc]"))));
                        diag_add_fn_site(diags, "error", "rt", "RT-001", msg, source, fn_name);
                    };
                    ai = ai + 1;
                };
            };
            return;
        };
        p = p + 1;
    };
}

// The list of allocator-call patterns to scan for in a #[no_alloc]
// body. Each entry is matched as a literal substring with `(`
// appended (so `vec_push` matches `vec_push(` but not `vec_pushy`),
// EXCEPT entries already containing `(` or `::` are matched verbatim
// so they can encode method-call / constructor forms.
// Includes both the underlying builtin names (rare in user code) and
// the user-facing forms (`Vec::new(`, `.push(`, etc.) that the s1
// lowers to those builtins. The dot-prefixed forms catch the method-
// call sugar; this is the only way the source-level v1 check can see
// `vec.push(x)` without an AST.
#[manual_drop]
fn no_alloc_check_list() -> Vec<i32> {
    let mut v: Vec<i32> = Vec::new();
    // Vec — constructor + method calls
    v.push("Vec::new");
    // RFC-listed canonical
    // patterns previously missed — capacity-form Vec construction
    // and Box::new (heap allocation under any name).
    v.push("Vec::with_capacity");
    v.push(".with_capacity");
    v.push("Box::new");
    v.push("HashMap::new"); v.push("HashSet::new");
    v.push("BTreeMap::new"); v.push("BTreeSet::new");
    v.push("String::new"); v.push("String::with_capacity");
    v.push(".push");
    v.push(".pop");
    v.push(".extend");
    v.push(".insert_at");
    v.push(".remove_at");
    // Vec — builtin names (in case user reaches past the sugar)
    v.push("vec_new"); v.push("vec_with_capacity");
    v.push("vec_push"); v.push("vec_pop");
    v.push("vec_extend"); v.push("vec_insert_at"); v.push("vec_remove_at");
    // String builder
    v.push("sb_new"); v.push("sb_append");
    // String allocators
    v.push("str_concat"); v.push("str_substring"); v.push("str_repeat");
    v.push("str_pad_left"); v.push("str_pad_right");
    v.push("str_center"); v.push("str_join");
    // Format-string helpers (every one mallocs)
    v.push("format_i64"); v.push("format_str"); v.push("format_f64");
    v.push("format_hex"); v.push("format_bool");
    v.push("format2_ii"); v.push("format2_si"); v.push("format2_ss");
    v.push("format2_is"); v.push("format2_ff");
    v.push("format3_iii"); v.push("format3_sii"); v.push("format3_iss"); v.push("format3_sss");
    v.push("format3_ssi"); v.push("format3_sis");
    v.push("format3_iis"); v.push("format3_isi");
    v.push("format3_iif"); v.push("format3_iff"); v.push("format3_sff");
    v.push("format3_ssf"); v.push("format3_sif"); v.push("format3_isf");
    // Number-to-string
    v.push("int_to_str"); v.push("f64_to_str"); v.push("bool_to_str");
    // Bare arena builtins (RFC-0002 phase 1) — also alloc
    v.push("arena_new"); v.push("arena_alloc");
    // Lane 6 / F-CONC-004: Hashmap insert / btreemap insert allocate
    // a new slot / node on grow.
    v.push("hashmap_insert"); v.push("hashmap_new"); v.push("hashmap_with_capacity");
    v.push("hashset_insert"); v.push("hashset_new");
    v.push("btreemap_insert"); v.push("btreemap_new");
    v.push("btreeset_insert"); v.push("btreeset_new");
    return v;
}

#[manual_drop]
fn no_alloc_body_has_alloc_pattern(source: str, fn_name: str) -> i64 {
    let body_raw: str = source_fn_body_for_scan(source, fn_name);
    if str_len(body_raw) == 0 { return 0; };
    let body: str = strip_strings_and_line_comments(body_raw);
    let alloc_names: Vec<i32> = no_alloc_check_list();
    let mut ai: i64 = 0;
    while ai < vec_len(alloc_names) {
        let n: str = vec_get(alloc_names, ai);
        let pat: str = str_concat(n, "(");
        if str_contains(body, pat) == 1 { return 1; };
        ai = ai + 1;
    };
    return 0;
}

#[manual_drop]
fn rt_same_file_fn_body_calls_any(source: str, fn_name: str, target_fns: Vec<i32>) -> i64 {
    if vec_len(target_fns) == 0 { return 0; };
    let body_raw: str = source_fn_body_for_scan(source, fn_name);
    if str_len(body_raw) == 0 { return 0; };
    let body: str = strip_strings_and_line_comments(body_raw);
    let mut i: i64 = 0;
    while i < vec_len(target_fns) {
        let callee: str = vec_get(target_fns, i);
        if str_eq(callee, fn_name) == 0 {
            let pat: str = str_concat(callee, "(");
            if str_contains(body, pat) == 1 { return 1; };
        };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn collect_same_file_fns_calling_any(source: str, target_fns: Vec<i32>) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    if vec_len(target_fns) == 0 { return fns; };
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            if rt_same_file_fn_body_calls_any(source, fn_name, target_fns) == 1 {
                priv_string_vec_push_unique(fns, fn_name);
            };
        };
        p = eol + 1;
    };
    return fns;
}

#[manual_drop]
fn collect_same_file_callers_closure(source: str, seed_fns: Vec<i32>, max_depth: i64) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    rt_string_vec_append_unique(out, seed_fns);
    if vec_len(seed_fns) == 0 || max_depth <= 0 { return out; };

    let mut frontier: Vec<i32> = seed_fns;
    let mut depth: i64 = 0;
    while depth < max_depth && vec_len(frontier) > 0 {
        let callers: Vec<i32> = collect_same_file_fns_calling_any(source, frontier);
        if vec_len(callers) == 0 { break; };
        rt_string_vec_append_unique(out, callers);
        frontier = callers;
        depth = depth + 1;
    };
    return out;
}

#[manual_drop]
fn collect_allocating_same_file_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            if no_alloc_body_has_alloc_pattern(source, fn_name) == 1 {
                priv_string_vec_push_unique(fns, fn_name);
            };
        };
        p = eol + 1;
    };
    return fns;
}

#[manual_drop]
fn check_no_alloc_transitive_call_violations(diags: Vec<i32>, source: str, fn_name: str, alloc_fns: Vec<i32>) -> i64 {
    if vec_len(alloc_fns) == 0 { return 0; };
    let body_raw: str = source_fn_body_for_scan(source, fn_name);
    if str_len(body_raw) == 0 { return 0; };
    let body: str = strip_strings_and_line_comments(body_raw);
    let mut emitted: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(alloc_fns) {
        let callee: str = vec_get(alloc_fns, i);
        if str_eq(callee, fn_name) == 0 {
            let pat: str = str_concat(callee, "(");
            if str_contains(body, pat) == 1 {
                let msg: str = str_concat("call to `", str_concat(callee, str_concat("()` reaches same-file allocation but `", str_concat(fn_name, "` is marked #[no_alloc]"))));
                diag_add_fn_site(diags, "error", "rt", "RT-001", msg, source, fn_name);
                emitted = emitted + 1;
            };
        };
        i = i + 1;
    };
    return emitted;
}

#[manual_drop]
fn enforce_no_alloc(diags: Vec<i32>, source: str) -> Vec<i32> {
    let no_alloc_fns: Vec<i32> = collect_no_alloc_fns(source);
    if vec_len(no_alloc_fns) == 0 { return diags; };
    let alloc_effect_fns: Vec<i32> = collect_fns_with_effect(source, "Alloc");
    let alloc_body_fns: Vec<i32> = collect_allocating_same_file_fns(source);
    // Bump caller-closure depth from 4 to 8
    // to match `restricts_transitive_check` and the v0845 lane 2
    // requires-row depth. `collect_same_file_callers_closure` uses
    // BFS with `rt_string_vec_append_unique` dedup, so termination is
    // O(N) per chain (each fn added at most once). The wider hop
    // budget closes the silent fall-through where 5..=7-hop chains
    // through the resolved-source path (cross-module or same-file)
    // reached an allocating leaf without an RT-001.
    let alloc_reachable_fns: Vec<i32> = collect_same_file_callers_closure(source, alloc_body_fns, 8);
    let mut i: i64 = 0;
    while i < vec_len(no_alloc_fns) {
        let fn_name: str = vec_get(no_alloc_fns, i);
        check_no_alloc_violations(diags, source, fn_name);
        check_effect_call_violations(diags, source, fn_name, alloc_effect_fns, "Alloc", "no_alloc");
        check_no_alloc_transitive_call_violations(diags, source, fn_name, alloc_reachable_fns);
        i = i + 1;
    };
    return diags;
}

// === T3.2 (v0.3.1): #[no_panic] enforcement (RT-002) ===
// Mirror of the #[no_alloc] source-level scanner. Walks for the
// `#[no_panic]` attribute, associates each with the next fn,
// then scans the fn body for panic-prone call patterns and emits
// RT-002 per violation.
// What "can panic" includes:
//   - `panic("...")`         — explicit panic builtin
//   - `assert_eq` / `assert_ne` — abort on failure
//   - `unwrap` / `.unwrap()`  — Option/Result unwrap (panics on None/Err)
//   - `expect` / `.expect()`  — same with custom message
//   - `dbg!`                  — convention: panics on assertion fail
// Same v1 limitations as #[no_alloc]:
//   - Source-level only (no AST, bounded same-file call-graph chase)
//   - String/comment-aware skip
//   - Per-file scope

#[manual_drop]
fn collect_no_panic_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[no_panic]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q + 3 <= slen {
                let c0: i64 = str_char_at(source, q);
                let c1: i64 = str_char_at(source, q + 1);
                let c2: i64 = str_char_at(source, q + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    q = q + 3;
                    let name_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                        q = q + 1;
                    };
                    if q > name_start {
                        let name: str = str_substring(source, name_start, q);
                        fns.push(name);
                    };
                    p = q;
                    break;
                };
                q = q + 1;
            };
            if q + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    rt_string_vec_append(fns, collect_fns_with_effect(source, "no_panic"));
    return fns;
}

#[manual_drop]
fn no_panic_check_list() -> Vec<i32> {
    // Call patterns to flag inside #[no_panic] fns. Each entry is
    // a literal substring search; the body MUST contain `<entry>(`
    // (or `.unwrap`/`.expect` for method-call form). Same approach
    // as no_alloc_check_list — easy to extend as new panic-prone
    // primitives ship.
    let mut v: Vec<i32> = Vec::new();
    v.push("panic");
    v.push("assert_eq");
    v.push("assert_ne");
    v.push("unwrap");
    v.push("expect");
    v.push(".unwrap");
    v.push(".expect");
    return v;
}

#[manual_drop]
fn no_panic_body_has_panic_pattern(source: str, fn_name: str) -> i64 {
    let body_raw: str = source_fn_body_for_scan(source, fn_name);
    if str_len(body_raw) == 0 { return 0; };
    let body: str = strip_strings_and_line_comments(body_raw);
    let panic_names: Vec<i32> = no_panic_check_list();
    let mut ai: i64 = 0;
    while ai < vec_len(panic_names) {
        let n: str = vec_get(panic_names, ai);
        let pat: str = str_concat(n, "(");
        if str_contains(body, pat) == 1 { return 1; };
        ai = ai + 1;
    };
    return 0;
}

#[manual_drop]
fn collect_panicking_same_file_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            if no_panic_body_has_panic_pattern(source, fn_name) == 1 {
                priv_string_vec_push_unique(fns, fn_name);
            };
        };
        p = eol + 1;
    };
    return fns;
}

#[manual_drop]
fn check_no_panic_violations(diags: Vec<i32>, source: str, fn_name: str) {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            if q < slen {
                let body_start: i64 = q + 1;
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                let body: str = strip_strings_and_line_comments(body_raw);
                let panic_names: Vec<i32> = no_panic_check_list();
                let mut ai: i64 = 0;
                while ai < vec_len(panic_names) {
                    let n: str = vec_get(panic_names, ai);
                    let pat: str = str_concat(n, "(");
                    if str_contains(body, pat) == 1 {
                        let msg: str = str_concat("`", str_concat(n, str_concat("` can panic but `", str_concat(fn_name, "` is marked #[no_panic]"))));
                        diag_add_fn_site(diags, "error", "rt", "RT-002", msg, source, fn_name);
                    };
                    ai = ai + 1;
                };
                // Implicit panic sources. Integer `/` and `%` panic on
                // divide-by-zero. Adopters annotate `#[no_panic]` and
                // expect the compiler to flag these. Phase 1 emits
                // warning[RT-009] (warning not error because the
                // estimator can't prove the divisor is non-zero —
                // adopter uses #[allow_fn(RT-009)] when verified safe).
                // Phase 2 will add IR-level non-zero divisor proof.
                let blen: i64 = str_len(body);
                let mut bp: i64 = 0;
                let mut div_found: i64 = 0;
                let mut mod_found: i64 = 0;
                while bp < blen {
                    let bc: i64 = str_char_at(body, bp);
                    if bc == 47 {
                        let next_c: i64 = if bp + 1 < blen { str_char_at(body, bp + 1) } else { 32 };
                        if next_c != 61 && next_c != 47 && next_c != 42 { div_found = 1; };
                    };
                    if bc == 37 {
                        let next_m: i64 = if bp + 1 < blen { str_char_at(body, bp + 1) } else { 32 };
                        if next_m != 61 { mod_found = 1; };
                    };
                    bp = bp + 1;
                };
                if div_found == 1 {
                    let msg_div: str = str_concat("integer `/` divide can panic on divisor=0; `", str_concat(fn_name, "` is marked #[no_panic] (use `checked_div` for explicit handling, or `#[allow_fn(RT-009)]` when divisor is provably non-zero)"));
                    diag_add_fn_site(diags, "warning", "rt", "RT-009", msg_div, source, fn_name);
                };
                if mod_found == 1 {
                    let msg_mod: str = str_concat("integer `%` modulo can panic on divisor=0; `", str_concat(fn_name, "` is marked #[no_panic] (use `checked_rem` for explicit handling, or `#[allow_fn(RT-009)]` when divisor is provably non-zero)"));
                    diag_add_fn_site(diags, "warning", "rt", "RT-009", msg_mod, source, fn_name);
                };
            };
            return;
        };
        p = p + 1;
    };
}

#[manual_drop]
fn check_no_panic_transitive_call_violations(diags: Vec<i32>, source: str, fn_name: str, panic_fns: Vec<i32>) -> i64 {
    if vec_len(panic_fns) == 0 { return 0; };
    let body_raw: str = source_fn_body_for_scan(source, fn_name);
    if str_len(body_raw) == 0 { return 0; };
    let body: str = strip_strings_and_line_comments(body_raw);
    let mut emitted: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(panic_fns) {
        let callee: str = vec_get(panic_fns, i);
        if str_eq(callee, fn_name) == 0 {
            let pat: str = str_concat(callee, "(");
            if str_contains(body, pat) == 1 {
                let msg: str = str_concat("call to `", str_concat(callee, str_concat("()` reaches same-file panic-prone code but `", str_concat(fn_name, "` is marked #[no_panic]"))));
                diag_add_fn_site(diags, "error", "rt", "RT-002", msg, source, fn_name);
                emitted = emitted + 1;
            };
        };
        i = i + 1;
    };
    return emitted;
}

#[manual_drop]
fn enforce_no_panic(diags: Vec<i32>, source: str) -> Vec<i32> {
    let no_panic_fns: Vec<i32> = collect_no_panic_fns(source);
    if vec_len(no_panic_fns) == 0 { return diags; };
    let panic_effect_fns: Vec<i32> = collect_fns_with_effect(source, "Panic");
    let panic_body_fns: Vec<i32> = collect_panicking_same_file_fns(source);
    // Same depth bump as `enforce_no_alloc`.
    // 4 → 8 hops via the same BFS+dedup machinery; closes the
    // 5..=7-hop silent fall-through on the panic-reachability scan.
    let panic_reachable_fns: Vec<i32> = collect_same_file_callers_closure(source, panic_body_fns, 8);
    let mut i: i64 = 0;
    while i < vec_len(no_panic_fns) {
        let fn_name: str = vec_get(no_panic_fns, i);
        check_no_panic_violations(diags, source, fn_name);
        check_effect_call_violations(diags, source, fn_name, panic_effect_fns, "Panic", "no_panic");
        check_no_panic_transitive_call_violations(diags, source, fn_name, panic_reachable_fns);
        i = i + 1;
    };
    return diags;
}

#[manual_drop]
fn collect_atomic_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[atomic]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q + 3 <= slen {
                let c0: i64 = str_char_at(source, q);
                let c1: i64 = str_char_at(source, q + 1);
                let c2: i64 = str_char_at(source, q + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    q = q + 3;
                    let name_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                        q = q + 1;
                    };
                    if q > name_start { fns.push(str_substring(source, name_start, q)); };
                    p = q;
                    break;
                };
                q = q + 1;
            };
            if q + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return fns;
}

#[manual_drop]
fn source_fn_body_for_scan(source: str, fn_name: str) -> str {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            if q < slen {
                let body_start: i64 = q + 1;
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                return str_substring(source, body_start, q - 1);
            };
            return "";
        };
        p = p + 1;
    };
    return "";
}

// v0843 R05 consolidation: paired with `source_fn_body_for_scan`.
// Returns the callee's header substring (everything from `fn NAME(`
// up to but not including the opening `{` or terminating `;`), or
// "" if not found. Used by `check_effect_call_violations` to find
// the callee's actual `with [...]` row so the diagnostic can name
// the offending sub-effect token rather than just the family root.
#[manual_drop]
fn source_fn_header_for_scan(source: str, fn_name: str) -> str {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(source, p, needle, nlen) == 1 {
            let mut h: i64 = p;
            while h < slen && str_char_at(source, h) != 123 && str_char_at(source, h) != 59 { h = h + 1; };
            return str_substring(source, p, h);
        };
        p = p + 1;
    };
    return "";
}

// v0843 R05 consolidation: returns the first token in `row` that
// covers `eff` under the symmetric family rule (token == eff, eff
// is sub of token, or token is sub of eff), or "" if none.
// `restricts_row_covers_effect` answers yes/no; this returns the
// actual matching token for use in diagnostics.
#[manual_drop]
fn row_token_covering(row: str, eff: str) -> str {
    let rlen: i64 = str_len(row);
    let elen: i64 = str_len(eff);
    if rlen == 0 || elen == 0 { return ""; };
    let mut start: i64 = 0;
    let mut p: i64 = 0;
    while p <= rlen {
        let at_end: i64 = if p == rlen { 1 } else { 0 };
        let at_comma: i64 = if at_end == 0 && str_char_at(row, p) == 44 { 1 } else { 0 };
        if at_end == 1 || at_comma == 1 {
            let tok: str = strip_spaces(str_substring(row, start, p));
            let tlen: i64 = str_len(tok);
            if tlen > 0 {
                if str_eq(tok, eff) == 1 { return tok; };
                if elen > tlen && str_starts_with(eff, str_concat(tok, ".")) == 1 { return tok; };
                if tlen > elen && str_starts_with(tok, str_concat(eff, ".")) == 1 { return tok; };
            };
            start = p + 1;
        };
        p = p + 1;
    };
    return "";
}

#[manual_drop]
fn check_effect_call_violations(diags: Vec<i32>, source: str, fn_name: str, effect_fns: Vec<i32>, effect_name: str, contract_name: str) -> i64 {
    if vec_len(effect_fns) == 0 { return 0; };
    let body_raw: str = source_fn_body_for_scan(source, fn_name);
    if str_len(body_raw) == 0 { return 0; };
    let body: str = strip_strings_and_line_comments(body_raw);
    let mut emitted: i64 = 0;
    let n: i64 = vec_len(effect_fns);
    let mut i: i64 = 0;
    while i < n {
        let callee: str = vec_get(effect_fns, i);
        if str_eq(callee, fn_name) == 0 {
            let pat: str = str_concat(callee, "(");
            if str_contains(body, pat) == 1 {
                let callee_header: str = source_fn_header_for_scan(source, callee);
                let callee_with_row: str = extract_keyword_row(callee_header, "with");
                let matched: str = row_token_covering(callee_with_row, effect_name);
                let effect_phrase: str = if str_len(matched) == 0 || str_eq(matched, effect_name) == 1 {
                    str_concat("`", str_concat(effect_name, "`"))
                } else {
                    str_concat("`", str_concat(matched, str_concat("` (in the `", str_concat(effect_name, "` family)"))))
                };
                let msg: str = str_concat("call to `", str_concat(callee, str_concat("()` requires effect ", str_concat(effect_phrase, str_concat(" but `", str_concat(fn_name, str_concat("` is declared with [", str_concat(contract_name, "]"))))))));
                diag_add_fn_site(diags, "error", "effect", "EFF-003", msg, source, fn_name);
                emitted = emitted + 1;
            };
        };
        i = i + 1;
    };
    return emitted;
}

#[manual_drop]
fn atomic_blocking_check_list() -> Vec<i32> {
    let mut v: Vec<i32> = Vec::new();
    v.push("mutex_lock"); v.push(".lock"); v.push("rwlock_read"); v.push("rwlock_write");
    v.push(".read"); v.push(".write"); v.push("channel_recv"); v.push(".recv");
    v.push("sleep_ms"); v.push("sleep_us"); v.push("system"); v.push("process_spawn");
    v.push("socket_accept"); v.push("file_read_string");
    // Friendly rod-level
    // wrappers around the underlying blocking primitives. Pre-fix the
    // single-hop substring check missed every call shape that went
    // through a wrapper named differently from the underlying
    // primitive. Adding the canonical wrapper names defends the
    // common case without needing full transitive call-graph
    // analysis. Remaining wrappers (user-defined, third-party rod)
    // are still caught by the depth-bounded transitive scan in
    // `enforce_no_alloc` / `enforce_no_panic` patterns when wired
    // through Lane 2 / Phase 2 (full call-graph closure for blocking
    // detection).
    v.push("conc_lock"); v.push("conc_unlock");
    v.push("conc_recv"); v.push("conc_send");
    v.push("conc_try_recv"); v.push("conc_try_send");
    v.push("conc_mutex_lock"); v.push("conc_mutex_unlock");
    v.push("conc_channel_recv"); v.push("conc_channel_send");
    v.push("thread_join"); v.push("thread_barrier_wait");
    v.push("cond_wait");
    v.push("proc_run"); v.push("proc_run1");
    v.push("proc_capture_stdout"); v.push("proc_capture_with_status");
    return v;
}

#[manual_drop]
fn atomic_cell_check_list() -> Vec<i32> {
    let mut v: Vec<i32> = Vec::new();
    v.push("Cell<"); v.push("RefCell<"); v.push("Cell::"); v.push("RefCell::");
    v.push("cell_new"); v.push("refcell_new");
    return v;
}

#[manual_drop]
fn check_atomic_contract_violations(diags: Vec<i32>, source: str, fn_name: str) {
    let body_raw: str = source_fn_body_for_scan(source, fn_name);
    if str_len(body_raw) == 0 { return; };
    let body: str = strip_strings_and_line_comments(body_raw);
    let blocking: Vec<i32> = atomic_blocking_check_list();
    let mut i: i64 = 0;
    while i < vec_len(blocking) {
        let n: str = vec_get(blocking, i);
        let pat: str = str_concat(n, "(");
        if str_contains(body, pat) == 1 {
            let msg: str = str_concat("`", str_concat(n, str_concat("` may block but `", str_concat(fn_name, "` is marked #[atomic]"))));
            diag_add_symbol_site(diags, "error", "atomic", "ATOMIC-001", msg, source, fn_name, n);
        };
        i = i + 1;
    };
    let allocs: Vec<i32> = no_alloc_check_list();
    i = 0;
    while i < vec_len(allocs) {
        let n2: str = vec_get(allocs, i);
        let pat2: str = str_concat(n2, "(");
        if str_contains(body, pat2) == 1 {
            let msg2: str = str_concat("`", str_concat(n2, str_concat("` allocates but `", str_concat(fn_name, "` is marked #[atomic]"))));
            diag_add_symbol_site(diags, "error", "atomic", "ATOMIC-002", msg2, source, fn_name, n2);
        };
        i = i + 1;
    };
    let cells: Vec<i32> = atomic_cell_check_list();
    i = 0;
    while i < vec_len(cells) {
        let n3: str = vec_get(cells, i);
        if str_contains(body, n3) == 1 {
            let msg3: str = str_concat("`", str_concat(n3, "` is interior mutability with runtime borrow state and is forbidden inside #[atomic]"));
            diag_add_symbol_site(diags, "error", "atomic", "ATOMIC-003", msg3, source, fn_name, n3);
        };
        i = i + 1;
    };
}

#[manual_drop]
fn atomic_find_pattern_from(text: str, pat: str, start: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let plen: i64 = str_len(pat);
    if plen == 0 || tlen < plen { return 0 - 1; };
    let mut p: i64 = start;
    while p + plen <= tlen {
        if str_eq_at_len(text, p, pat, plen) == 1 { return p; };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn atomic_find_call_end(text: str, open_pos: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let mut p: i64 = open_pos;
    let mut depth: i64 = 0;
    while p < tlen {
        let c: i64 = str_char_at(text, p);
        if c == 40 { depth = depth + 1; }
        else if c == 41 {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn atomic_order_code_at(call: str, p: i64) -> i64 {
    if str_eq_at(call, p, "MemOrder::Relaxed") == 1 { return 0; };
    if str_eq_at(call, p, "MemOrder::Acquire") == 1 { return 1; };
    if str_eq_at(call, p, "MemOrder::Release") == 1 { return 2; };
    if str_eq_at(call, p, "MemOrder::AcqRel") == 1 { return 3; };
    if str_eq_at(call, p, "MemOrder::SeqCst") == 1 { return 4; };
    return 0 - 1;
}

#[manual_drop]
fn atomic_nth_order_code(call: str, nth: i64) -> i64 {
    let mut p: i64 = 0;
    let mut seen: i64 = 0;
    while p >= 0 {
        p = atomic_find_pattern_from(call, "MemOrder::", p);
        if p < 0 { return 0 - 1; };
        seen = seen + 1;
        if seen == nth { return atomic_order_code_at(call, p); };
        p = p + 10;
    };
    return 0 - 1;
}

#[manual_drop]
fn atomic_cmpxchg_orders_valid(success: i64, failure: i64) -> i64 {
    if failure == 2 || failure == 3 { return 0; };
    if success == 0 { if failure == 0 { return 1; }; return 0; };
    if success == 1 { if failure == 0 || failure == 1 { return 1; }; return 0; };
    if success == 2 { if failure == 0 { return 1; }; return 0; };
    if success == 3 { if failure == 0 || failure == 1 { return 1; }; return 0; };
    if success == 4 { if failure == 0 || failure == 1 || failure == 4 { return 1; }; return 0; };
    return 0;
}

#[manual_drop]
fn atomic_scan_call_invalid_order(diags: Vec<i32>, code_text: str, callee_pat: str, bad_a: str, bad_b: str, code: str, message: str) -> i64 {
    let plen: i64 = str_len(callee_pat);
    let mut p: i64 = 0;
    let mut emitted: i64 = 0;
    while p >= 0 {
        p = atomic_find_pattern_from(code_text, callee_pat, p);
        if p < 0 { return emitted; };
        let endp: i64 = atomic_find_call_end(code_text, p + plen - 1);
        if endp > p {
            let call: str = str_substring(code_text, p, endp + 1);
            let mut bad_order: i64 = 0;
            if str_contains(call, bad_a) == 1 { bad_order = 1; };
            if str_len(bad_b) > 0 && str_contains(call, bad_b) == 1 { bad_order = 1; };
            if bad_order == 1 {
                let loc_atomic_order: Vec<i32> = diag_find_global_linecol(code_text, callee_pat);
                diag_add_ex(diags, "error", "atomic", code, message, "main", vec_get(loc_atomic_order, 0), vec_get(loc_atomic_order, 1), "");
                emitted = emitted + 1;
            };
            p = endp + 1;
        } else {
            p = p + plen;
        };
    };
    return emitted;
}

// closure-body atomic call detection (ATOMIC-006).
// Regression fixed in v0.4.280: closures whose body calls
// `atomic_*` helpers crash the compiler with `vec_get OOB`
// because the closure-lowering path doesn't inherit the
// parent fn's enum-variant etag entries — `MemOrder::SeqCst`
// dispatches to the unsupported-associated-fn-call branch
// which panics with bad state. Real fix is sym-table inheritance
// in closure lowering — multi-cycle. This temporary halt catches
// the dangerous pattern at parse-time and emits a clean diag
// instead of letting the meltdown surface. Adopters get a
// useful "closures + atomics not yet supported" message.
#[manual_drop]
fn enforce_no_atomic_in_closure(source: str) -> i64 {
    let code: str = strip_strings_and_line_comments(source);
    let n: i64 = str_len(code);
    // Conservative scan: find the zero-arg closure literal token,
    // then look ahead up to 200 chars for an atomic helper substring
    // before hitting `}` or `;` (closure body terminator).
    let mut p: i64 = 0;
    while p + 1 < n {
        if str_char_at(code, p) == 124 && str_char_at(code, p + 1) == 124 {
            let mut prev: i64 = p - 1;
            while prev >= 0 && is_ws(str_char_at(code, prev)) == 1 { prev = prev - 1; };
            let mut closure_literal: i64 = 0;
            if prev < 0 { closure_literal = 1; }
            else {
                let pc: i64 = str_char_at(code, prev);
                if pc == 40 || pc == 44 || pc == 61 || pc == 91 || pc == 123 { closure_literal = 1; };
            };
            if closure_literal == 0 { p = p + 1; continue; };
            // Found zero-arg closure literal. Look ahead.
            let look_end: i64 = if p + 200 < n { p + 200 } else { n };
            let mut q: i64 = p + 2;
            while q + 7 <= look_end {
                if str_char_at(code, q) == 97 && str_eq_at(code, q, "atomic_") == 1 {
                    return 1;
                };
                let ch1: i64 = str_char_at(code, q);
                if ch1 == 59 || ch1 == 125 { q = look_end; };
                q = q + 1;
            };
        };
        p = p + 1;
    };
    return 0;
}

#[manual_drop]
fn enforce_atomic_ordering(diags: Vec<i32>, source: str) -> Vec<i32> {
    let code: str = strip_strings_and_line_comments(source);
    atomic_scan_call_invalid_order(diags, code, "atomic_load(", "MemOrder::Release", "MemOrder::AcqRel", "ATOMIC-005", "atomic_load only accepts Relaxed, Acquire, or SeqCst memory ordering");
    atomic_scan_call_invalid_order(diags, code, "atomic_store(", "MemOrder::Acquire", "MemOrder::AcqRel", "ATOMIC-005", "atomic_store only accepts Relaxed, Release, or SeqCst memory ordering");
    let callee_pat: str = "atomic_compare_exchange(";
    let plen: i64 = str_len(callee_pat);
    let mut p: i64 = 0;
    while p >= 0 {
        p = atomic_find_pattern_from(code, callee_pat, p);
        if p < 0 { return diags; };
        let endp: i64 = atomic_find_call_end(code, p + plen - 1);
        if endp > p {
            let call: str = str_substring(code, p, endp + 1);
            let success: i64 = atomic_nth_order_code(call, 1);
            let failure: i64 = atomic_nth_order_code(call, 2);
            if success >= 0 && failure >= 0 && atomic_cmpxchg_orders_valid(success, failure) == 0 {
                let loc_cmpxchg: Vec<i32> = diag_find_global_linecol(code, callee_pat);
                diag_add_ex(diags, "error", "atomic", "ATOMIC-004", "compare_exchange failure ordering must not be Release/AcqRel and must not be stronger than success ordering", "main", vec_get(loc_cmpxchg, 0), vec_get(loc_cmpxchg, 1), "");
            };
            p = endp + 1;
        } else {
            p = p + plen;
        };
    };
    return diags;
}

#[manual_drop]
fn enforce_atomic_contracts(diags: Vec<i32>, source: str) -> Vec<i32> {
    let atomic_fns: Vec<i32> = collect_atomic_fns(source);
    let mut i: i64 = 0;
    while i < vec_len(atomic_fns) {
        check_atomic_contract_violations(diags, source, vec_get(atomic_fns, i));
        i = i + 1;
    };
    return enforce_atomic_ordering(diags, source);
}

// === T3.6 (v0.3.5): #[no_dyn] enforcement (RT-003) ===
// Forbids dynamic dispatch in the marked fn — `Box<dyn Trait>`,
// `&dyn Trait`, `&mut dyn Trait`, and bare `dyn Trait` types.
// Matches the v1 source-level pattern of #[no_alloc] / #[no_panic]:
// scan the resolved source for `#[no_dyn]\nfn NAME(...)` pairs,
// then walk each fn body for the literal substring `dyn ` (a
// trailing space rules out identifiers like `dyn_var`). The same
// comment-and-string skip the other RT scanners use guards against
// false positives on the `let pat: str = "#[no_dyn]"` literal in
// this very compiler.

#[manual_drop]
fn collect_no_dyn_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[no_dyn]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q + 3 <= slen {
                let c0: i64 = str_char_at(source, q);
                let c1: i64 = str_char_at(source, q + 1);
                let c2: i64 = str_char_at(source, q + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    q = q + 3;
                    let name_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                        q = q + 1;
                    };
                    if q > name_start {
                        let name: str = str_substring(source, name_start, q);
                        fns.push(name);
                    };
                    p = q;
                    break;
                };
                q = q + 1;
            };
            if q + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    rt_string_vec_append(fns, collect_fns_with_effect(source, "no_dyn"));
    return fns;
}

#[manual_drop]
fn check_no_dyn_violations(diags: Vec<i32>, source: str, fn_name: str) {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            // Scan the SIGNATURE (between fn_name and `{`) AND the
            // body (between matching braces). dyn Trait can appear in
            // either parameters or local bindings.
            let mut sig_q: i64 = p + nlen;
            let sig_start: i64 = sig_q;
            while sig_q < slen && str_char_at(source, sig_q) != 123 { sig_q = sig_q + 1; };
            let sig_text: str = str_substring(source, sig_start, sig_q);
            if sig_q < slen {
                let body_start: i64 = sig_q + 1;
                let mut depth: i64 = 1;
                let mut q: i64 = body_start;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                let body: str = strip_strings_and_line_comments(body_raw);
                // The signature itself contains the user-facing type
                // names (`&dyn Trait` etc.) — we want to KEEP those
                // matches, so only the body gets the strip pass. (A
                // `dyn` inside a signature-level string literal is a
                // pathological edge case; not worth slowing v1 for.)
                let combined: str = str_concat(sig_text, str_concat(" ", body));
                if str_contains(combined, "dyn ") == 1 {
                    let msg: str = str_concat("dynamic dispatch (`dyn`) used but `", str_concat(fn_name, "` is marked #[no_dyn]"));
                    diag_add_fn_site(diags, "error", "rt", "RT-003", msg, source, fn_name);
                };
            };
            return;
        };
        p = p + 1;
    };
}

#[manual_drop]
fn enforce_no_dyn(diags: Vec<i32>, source: str) -> Vec<i32> {
    let no_dyn_fns: Vec<i32> = collect_no_dyn_fns(source);
    let mut i: i64 = 0;
    while i < vec_len(no_dyn_fns) {
        let fn_name: str = vec_get(no_dyn_fns, i);
        check_no_dyn_violations(diags, source, fn_name);
        i = i + 1;
    };
    return diags;
}

// === T3.9 (v0.3.8): RT-005 — FFI call in RT-marked fn ===
// `extern fn` declarations are unknown to the compiler and may
// allocate, panic, take indeterminate time, or do IO. Calling
// one from inside a #[no_alloc] / #[no_panic] / #[deadline] fn
// breaks every RT contract. Until ffi annotations like
// #[ffi_no_alloc] ship (deferred to v0.4), every extern fn call
// from an RT body fires `warning[RT-005]`. Suppressible via
// `#[allow(RT-005)]`.

#[manual_drop]
fn collect_extern_fn_names(source: str) -> Vec<i32> {
    let mut names: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "extern fn ";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            let nm_start: i64 = q;
            while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
            if q > nm_start {
                let nm: str = str_substring(source, nm_start, q);
                let mut already: i64 = 0;
                let mut j: i64 = 0;
                while j < vec_len(names) && already == 0 {
                    if str_eq(vec_get(names, j), nm) == 1 { already = 1; };
                    j = j + 1;
                };
                if already == 0 { names.push(nm); };
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return names;
}

#[manual_drop]
fn check_no_ffi_violations(diags: Vec<i32>, source: str, fn_name: str, externs: Vec<i32>, attr_label: str) {
    if vec_len(externs) == 0 { return; };
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            if q < slen {
                let body_start: i64 = q + 1;
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                let body: str = strip_strings_and_line_comments(body_raw);
                let mut ei: i64 = 0;
                let en: i64 = vec_len(externs);
                while ei < en {
                    let ext_name: str = vec_get(externs, ei);
                    let pat: str = str_concat(ext_name, "(");
                    if str_contains(body, pat) == 1 {
                        let msg: str = str_concat("FFI call '", str_concat(ext_name, str_concat("' from ", str_concat(attr_label, str_concat(" fn '", str_concat(fn_name, "' -- extern fns may allocate, panic, or block (mark the extern with #[ffi_no_alloc] / #[ffi_no_panic] for per-symbol opt-out, or #[allow(RT-005)] for file-wide)"))))));
                        diag_add_fn_site(diags, "warning", "rt", "RT-005", msg, source, fn_name);
                    };
                    ei = ei + 1;
                };
            };
            return;
        };
        p = p + 1;
    };
}

// T3.15: per-symbol FFI safety markers. An `extern fn`
// declaration prefixed with `#[ffi_no_alloc]` tells the RT-005
// check that this particular FFI symbol is known not to allocate;
// `#[ffi_no_panic]` does the same for panic-prone behaviour.
// The two markers can stack on the same extern declaration. RT
// fns calling an annotated-safe extern stay clean; RT fns calling
// an UNannotated extern still fire RT-005 (the conservative
// default — we don't know what the C side does).
#[manual_drop]
fn collect_externs_with_marker(source: str, marker_pat: str) -> Vec<i32> {
    let mut names: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let plen: i64 = str_len(marker_pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(marker_pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            // Walk forward past blanks/`///`/other-attribute lines for `extern fn NAME(`.
            let mut q: i64 = p + plen;
            while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
            if q < slen { q = q + 1; };
            let mut found: i64 = 0;
            while q + 10 <= slen && found == 0 {
                while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9 || str_char_at(source, q) == 10 || str_char_at(source, q) == 13) {
                    q = q + 1;
                };
                if q + 10 > slen { found = 0 - 1; }
                else if str_char_at(source, q) == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 35 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_eq_at(source, q, "extern fn ") == 1 {
                    q = q + 10;
                    let nm_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
                    if q > nm_start {
                        let nm: str = str_substring(source, nm_start, q);
                        names.push(nm);
                        found = 1;
                    } else {
                        found = 0 - 1;
                    };
                } else {
                    found = 0 - 1;
                };
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return names;
}

// Set difference: returns elements of `all` that are NOT in
// `removed`. Used to filter FFI symbols safe for a given RT
// contract out of the "RT-005 fires" list.
#[manual_drop]
fn filter_externs_keep_unsafe(all: Vec<i32>, safe: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let an: i64 = vec_len(all);
    let sn: i64 = vec_len(safe);
    let mut i: i64 = 0;
    while i < an {
        let nm: str = vec_get(all, i);
        let mut is_safe: i64 = 0;
        let mut j: i64 = 0;
        while j < sn && is_safe == 0 {
            if str_eq(vec_get(safe, j), nm) == 1 { is_safe = 1; };
            j = j + 1;
        };
        if is_safe == 0 { out.push(nm); };
        i = i + 1;
    };
    return out;
}

#[manual_drop]
fn enforce_rt005_ffi(diags: Vec<i32>, source: str) -> Vec<i32> {
    let externs: Vec<i32> = collect_extern_fn_names(source);
    if vec_len(externs) == 0 { return diags; };
    // per-RT-attr safe extern lists. #[no_alloc] body
    // calls are clean iff the extern carries #[ffi_no_alloc];
    // #[no_panic] body iff #[ffi_no_panic]; #[deadline] needs
    // BOTH (deadline determinism subsumes both no-* contracts).
    let mut ffi_no_alloc_safe: Vec<i32> = collect_externs_with_marker(source, "#[ffi_no_alloc]");
    let mut ffi_no_panic_safe: Vec<i32> = collect_externs_with_marker(source, "#[ffi_no_panic]");
    rt_string_vec_append(ffi_no_alloc_safe, collect_externs_with_effect(source, "no_alloc"));
    rt_string_vec_append(ffi_no_panic_safe, collect_externs_with_effect(source, "no_panic"));
    let no_alloc_unsafe_externs: Vec<i32> = filter_externs_keep_unsafe(externs, ffi_no_alloc_safe);
    let no_panic_unsafe_externs: Vec<i32> = filter_externs_keep_unsafe(externs, ffi_no_panic_safe);
    // Deadline-safe = intersection; build it as: drop from `externs`
    // any name that is in BOTH safe lists.
    let mut dl_safe: Vec<i32> = Vec::new();
    let an2: i64 = vec_len(ffi_no_alloc_safe);
    let pn2: i64 = vec_len(ffi_no_panic_safe);
    let mut ii: i64 = 0;
    while ii < an2 {
        let nm2: str = vec_get(ffi_no_alloc_safe, ii);
        let mut in_panic: i64 = 0;
        let mut jj: i64 = 0;
        while jj < pn2 && in_panic == 0 {
            if str_eq(vec_get(ffi_no_panic_safe, jj), nm2) == 1 { in_panic = 1; };
            jj = jj + 1;
        };
        if in_panic == 1 { dl_safe.push(nm2); };
        ii = ii + 1;
    };
    let dl_unsafe_externs: Vec<i32> = filter_externs_keep_unsafe(externs, dl_safe);
    let no_alloc_fns: Vec<i32> = collect_no_alloc_fns(source);
    let mut i: i64 = 0;
    while i < vec_len(no_alloc_fns) {
        check_no_ffi_violations(diags, source, vec_get(no_alloc_fns, i), no_alloc_unsafe_externs, "#[no_alloc]");
        i = i + 1;
    };
    let no_panic_fns: Vec<i32> = collect_no_panic_fns(source);
    i = 0;
    while i < vec_len(no_panic_fns) {
        check_no_ffi_violations(diags, source, vec_get(no_panic_fns, i), no_panic_unsafe_externs, "#[no_panic]");
        i = i + 1;
    };
    // Deadline fns live as the wcet inner pair after T3.1 expansion.
    let dl_entries: Vec<i32> = wcet_collect_deadline_fns(source);
    let n: i64 = vec_len(dl_entries);
    let mut k: i64 = 0;
    while k + 1 < n {
        check_no_ffi_violations(diags, source, vec_get(dl_entries, k), dl_unsafe_externs, "#[deadline]");
        k = k + 2;
    };
    return diags;
}

// === T3.10 (v0.3.9): RT-008 — direct recursion in #[deadline] fn ===
// Recursion blows the deadline budget unless the call depth is
// bounded. We detect *direct* self-recursion: the inner fn's
// body contains a literal call to the original (wrapper) name.
// `#[max_depth = N]` opts out — bounded recursion is fine if
// the user has declared a static bound that fits in the budget.
// Indirect recursion (A→B→A) requires a call graph and is left
// for the v2 AST-based check.

#[manual_drop]
fn dl_get_wrapper_name(source: str, inner_name: str) -> str {
    // The T3.1 expander emits the inner fn first, then a blank,
    // then the wrapper fn whose body calls deadline_check. Walk
    // forward from the inner's brace-balanced body close, skip
    // whitespace, and read the next `fn NAME(` identifier.
    let needle: str = str_concat("fn ", str_concat(inner_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut found_at: i64 = 0 - 1;
    while p + nlen <= slen && found_at < 0 {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && m == 1 {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; };
            k = k + 1;
        };
        if m == 1 { found_at = p; }
        else { p = p + 1; };
    };
    if found_at < 0 { return ""; };
    let mut q: i64 = found_at + nlen;
    while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
    if q >= slen { return ""; };
    q = q + 1;
    let mut depth: i64 = 1;
    while q < slen && depth > 0 {
        let c: i64 = str_char_at(source, q);
        if c == 123 { depth = depth + 1; };
        if c == 125 { depth = depth - 1; };
        q = q + 1;
    };
    while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9 || str_char_at(source, q) == 10 || str_char_at(source, q) == 13) {
        q = q + 1;
    };
    if q + 3 > slen { return ""; };
    if str_char_at(source, q) != 102 || str_char_at(source, q + 1) != 110 || str_char_at(source, q + 2) != 32 {
        return "";
    };
    q = q + 3;
    let nm_start: i64 = q;
    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
    if q == nm_start { return ""; };
    return str_substring(source, nm_start, q);
}

#[manual_drop]
fn md_extract_int_value(line: str) -> i64 {
    let compact: str = strip_spaces(line);
    let needle: str = "#[max_depth";
    let pos: i64 = source_find(compact, needle);
    if pos < 0 { return 0 - 1; };
    let clen: i64 = str_len(compact);
    let mut p: i64 = pos + str_len(needle);
    if p >= clen { return 0 - 1; };
    if str_char_at(compact, p) == 61 {
        p = p + 1;
        let ns: i64 = p;
        while p < clen && is_digit(str_char_at(compact, p)) == 1 { p = p + 1; };
        if p == ns { return 0 - 1; };
        let v: i64 = str_to_int(str_substring(compact, ns, p));
        if v <= 0 { return 0 - 1; };
        return v;
    };
    if str_char_at(compact, p) == 40 {
        p = p + 1;
        let ns2: i64 = p;
        while p < clen && is_digit(str_char_at(compact, p)) == 1 { p = p + 1; };
        if p == ns2 { return 0 - 1; };
        let v2: i64 = str_to_int(str_substring(compact, ns2, p));
        if v2 <= 0 { return 0 - 1; };
        return v2;
    };
    return 0 - 1;
}

#[manual_drop]
fn md_first_param_name(params_text: str) -> str {
    // when the recursion-bounding
    // analyzer scans `fn count(self, depth: i64)`, the first identifier is
    // `self` — a self-receiver, not a depth parameter. Treat the receiver
    // (`self`, or a leading reference form `&self`) as a skip token and
    // return the FIRST non-receiver identifier so the guard / increment
    // patterns are checked against the real depth parameter.
    let plen: i64 = str_len(params_text);
    let mut p: i64 = 0;
    let mut tries: i64 = 0;
    // Loop through up to two leading idents; the first may be `self` (or
    // `&self`), in which case we step over the comma and pull the next.
    while tries < 2 {
        // Skip whitespace.
        while p < plen && (str_char_at(params_text, p) == 32 || str_char_at(params_text, p) == 9 || str_char_at(params_text, p) == 10 || str_char_at(params_text, p) == 13) { p = p + 1; };
        // Skip a leading `&` (and optional whitespace + `mut`) so `&self` /
        // `&mut self` resolve to ident `self`.
        if p < plen && str_char_at(params_text, p) == 38 {
            p = p + 1;
            while p < plen && (str_char_at(params_text, p) == 32 || str_char_at(params_text, p) == 9) { p = p + 1; };
            if p + 3 <= plen && str_eq_at(params_text, p, "mut") == 1
               && (p + 3 == plen || str_char_at(params_text, p + 3) == 32 || str_char_at(params_text, p + 3) == 9) {
                p = p + 3;
                while p < plen && (str_char_at(params_text, p) == 32 || str_char_at(params_text, p) == 9) { p = p + 1; };
            };
        };
        let ns: i64 = p;
        while p < plen && (is_alnum(str_char_at(params_text, p)) == 1 || str_char_at(params_text, p) == 95) { p = p + 1; };
        if p == ns { return ""; };
        let ident: str = str_substring(params_text, ns, p);
        if str_eq(ident, "self") == 0 {
            return ident;
        };
        // Receiver: skip the rest of this param up to the next comma at
        // top-level (depth-0). Type annotation `self: T` may include
        // arbitrary characters; conservatively scan for the next `,` at
        // bracket-depth zero.
        let mut depth: i64 = 0;
        while p < plen {
            let c: i64 = str_char_at(params_text, p);
            if depth == 0 && c == 44 { p = p + 1; break; };
            if c == 60 || c == 40 || c == 91 || c == 123 { depth = depth + 1; };
            if c == 62 || c == 41 || c == 93 || c == 125 { if depth > 0 { depth = depth - 1; }; };
            p = p + 1;
        };
        tries = tries + 1;
    };
    return "";
}

#[manual_drop]
fn md_first_ident_in_param_segment(seg: str) -> str {
    let slen: i64 = str_len(seg);
    let mut p: i64 = 0;
    while p < slen {
        while p < slen && (str_char_at(seg, p) == 32 || str_char_at(seg, p) == 9 || str_char_at(seg, p) == 10 || str_char_at(seg, p) == 13) { p = p + 1; };
        if p + 1 < slen && str_char_at(seg, p) == 35 && str_char_at(seg, p + 1) == 91 {
            p = p + 2;
            let mut depth: i64 = 1;
            while p < slen && depth > 0 {
                let c: i64 = str_char_at(seg, p);
                if c == 91 { depth = depth + 1; }
                else if c == 93 { depth = depth - 1; };
                p = p + 1;
            };
        } else {
            break;
        };
    };
    while p < slen && (str_char_at(seg, p) == 32 || str_char_at(seg, p) == 9 || str_char_at(seg, p) == 10 || str_char_at(seg, p) == 13) { p = p + 1; };
    if p < slen && str_char_at(seg, p) == 38 {
        p = p + 1;
        while p < slen && (str_char_at(seg, p) == 32 || str_char_at(seg, p) == 9) { p = p + 1; };
    };
    if p + 3 <= slen && str_eq_at(seg, p, "mut") == 1
       && (p + 3 == slen || str_char_at(seg, p + 3) == 32 || str_char_at(seg, p + 3) == 9) {
        p = p + 3;
        while p < slen && (str_char_at(seg, p) == 32 || str_char_at(seg, p) == 9) { p = p + 1; };
    };
    let ns: i64 = p;
    while p < slen && (is_alnum(str_char_at(seg, p)) == 1 || str_char_at(seg, p) == 95) { p = p + 1; };
    if p == ns { return ""; };
    return str_substring(seg, ns, p);
}

#[manual_drop]
fn md_param_names(params_text: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let plen: i64 = str_len(params_text);
    let mut p: i64 = 0;
    while p < plen {
        while p < plen && (str_char_at(params_text, p) == 32 || str_char_at(params_text, p) == 9 || str_char_at(params_text, p) == 10 || str_char_at(params_text, p) == 13 || str_char_at(params_text, p) == 44) { p = p + 1; };
        if p >= plen { break; };
        let seg_start: i64 = p;
        let mut q: i64 = p;
        let mut depth: i64 = 0;
        while q < plen {
            let c: i64 = str_char_at(params_text, q);
            if c == 40 || c == 60 || c == 91 || c == 123 { depth = depth + 1; }
            else if c == 41 || c == 62 || c == 93 || c == 125 { if depth > 0 { depth = depth - 1; }; }
            else if c == 44 && depth == 0 { break; };
            q = q + 1;
        };
        let seg: str = str_substring(params_text, seg_start, q);
        let name: str = md_first_ident_in_param_segment(seg);
        if str_len(name) > 0 && str_eq(name, "self") == 0 { out.push(name); };
        p = q + 1;
    };
    return out;
}

#[manual_drop]
fn md_parse_digits_at(s: str, p0: i64) -> i64 {
    let slen: i64 = str_len(s);
    let mut p: i64 = p0;
    let ns: i64 = p;
    while p < slen && is_digit(str_char_at(s, p)) == 1 { p = p + 1; };
    if p == ns { return 0 - 1; };
    return str_to_int(str_substring(s, ns, p));
}

#[manual_drop]
fn md_guard_limit(body: str, param_name: str) -> i64 {
    let compact: str = strip_spaces(body);
    let ge_pat: str = str_concat(param_name, ">=");
    let ge_pos: i64 = source_find(compact, ge_pat);
    if ge_pos >= 0 {
        let v: i64 = md_parse_digits_at(compact, ge_pos + str_len(ge_pat));
        if v >= 0 { return v; };
    };
    let gt_pat: str = str_concat(param_name, ">");
    let gt_pos: i64 = source_find(compact, gt_pat);
    if gt_pos >= 0 {
        let v2: i64 = md_parse_digits_at(compact, gt_pos + str_len(gt_pat));
        if v2 >= 0 { return v2 + 1; };
    };
    return 0 - 1;
}

#[manual_drop]
fn md_has_positive_increment(compact: str, param_name: str) -> i64 {
    let slen: i64 = str_len(compact);
    let right_pat: str = str_concat(param_name, "+");
    let rlen: i64 = str_len(right_pat);
    let mut p: i64 = 0;
    while p + rlen <= slen {
        if str_eq_at(compact, p, right_pat) == 1 {
            let v: i64 = md_parse_digits_at(compact, p + rlen);
            if v > 0 { return 1; };
        };
        p = p + 1;
    };
    let left_pat: str = str_concat("+", param_name);
    let llen: i64 = str_len(left_pat);
    p = 0;
    while p + llen <= slen {
        if str_eq_at(compact, p, left_pat) == 1 && p > 0 {
            let mut ds: i64 = p - 1;
            while ds >= 0 && is_digit(str_char_at(compact, ds)) == 1 { ds = ds - 1; };
            let start: i64 = ds + 1;
            if start < p {
                let v2: i64 = str_to_int(str_substring(compact, start, p));
                if v2 > 0 { return 1; };
            };
        };
        p = p + 1;
    };
    return 0;
}

#[manual_drop]
fn md_find_fn_pos(source: str, fn_name: str) -> i64 {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    return source_find(source, needle);
}

#[manual_drop]
fn md_helper_proves_guard(source: str, helper_name: str) -> i64 {
    let fn_pos: i64 = md_find_fn_pos(source, helper_name);
    if fn_pos < 0 { return 0; };
    let info: Vec<i32> = dl_parse_fn_signature(source, fn_pos, str_len(source));
    if vec_len(info) == 0 { return 0; };
    let params_text: str = vec_get(info, 1);
    let body_open: i64 = vec_get(info, 4);
    let body_end: i64 = vec_get(info, 5);
    let names: Vec<i32> = md_param_names(params_text);
    if vec_len(names) == 0 { return 0; };
    let first: str = vec_get(names, 0);
    let body_raw: str = str_substring(source, body_open + 1, body_end - 1);
    let compact: str = strip_spaces(strip_strings_and_line_comments(body_raw));
    if md_guard_limit(compact, first) >= 0 { return 1; };
    if vec_len(names) >= 2 {
        let second: str = vec_get(names, 1);
        let ge_pat: str = str_concat(first, str_concat(">=", second));
        let gt_pat: str = str_concat(first, str_concat(">", second));
        if str_contains(compact, ge_pat) == 1 || str_contains(compact, gt_pat) == 1 { return 1; };
    };
    return 0;
}

#[manual_drop]
fn md_guard_limit_with_helpers(source: str, body_compact: str, param_name: str) -> i64 {
    let direct: i64 = md_guard_limit(body_compact, param_name);
    if direct >= 0 { return direct; };
    let arg_pat: str = str_concat("(", str_concat(param_name, ","));
    let alen: i64 = str_len(arg_pat);
    let blen: i64 = str_len(body_compact);
    let mut p: i64 = 0;
    while p + alen <= blen {
        if str_eq_at_len(body_compact, p, arg_pat, alen) == 1 {
            let v: i64 = md_parse_digits_at(body_compact, p + alen);
            if v >= 0 {
                let mut ns: i64 = p - 1;
                while ns >= 0 && (is_alnum(str_char_at(body_compact, ns)) == 1 || str_char_at(body_compact, ns) == 95) { ns = ns - 1; };
                let mut helper_name: str = str_substring(body_compact, ns + 1, p);
                if str_starts_with(helper_name, "if") == 1 && str_len(helper_name) > 2 {
                    let trimmed_helper: str = str_substring(helper_name, 2, str_len(helper_name));
                    if md_helper_proves_guard(source, trimmed_helper) == 1 { helper_name = trimmed_helper; };
                };
                if str_len(helper_name) > 0 && md_helper_proves_guard(source, helper_name) == 1 { return v; };
            };
        };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn md_body_contains_call(body_raw: str, callee: str) -> i64 {
    if str_len(callee) == 0 { return 0; };
    let body: str = strip_strings_and_line_comments(body_raw);
    let pat: str = str_concat(callee, "(");
    return str_contains(body, pat);
}

#[manual_drop]
fn md_unproven_callback_param(body_raw: str, params_text: str) -> str {
    let body: str = strip_strings_and_line_comments(body_raw);
    let compact: str = strip_spaces(body);
    let plen: i64 = str_len(params_text);
    let mut p: i64 = 0;
    while p < plen {
        while p < plen && (str_char_at(params_text, p) == 32 || str_char_at(params_text, p) == 9 || str_char_at(params_text, p) == 10 || str_char_at(params_text, p) == 13 || str_char_at(params_text, p) == 44) { p = p + 1; };
        if p >= plen { break; };
        let seg_start: i64 = p;
        let mut q: i64 = p;
        let mut depth: i64 = 0;
        while q < plen {
            let c: i64 = str_char_at(params_text, q);
            if c == 40 || c == 60 || c == 91 || c == 123 { depth = depth + 1; }
            else if c == 41 || c == 62 || c == 93 || c == 125 { if depth > 0 { depth = depth - 1; }; }
            else if c == 44 && depth == 0 { break; };
            q = q + 1;
        };
        let seg: str = str_substring(params_text, seg_start, q);
        let seg_compact: str = strip_spaces(seg);
        if str_contains(seg_compact, "fn(") == 1 {
            let name: str = md_first_ident_in_param_segment(seg);
            let call_pat: str = str_concat(name, "(");
            if str_len(name) > 0 && str_contains(compact, call_pat) == 1 && str_contains(seg_compact, "#[no_recurse]") == 0 {
                return name;
            };
        };
        p = q + 1;
    };
    return "";
}

#[manual_drop]
fn md_proven_limit(source: str, body_raw: str, params_text: str, callee: str) -> i64 {
    let body: str = strip_strings_and_line_comments(body_raw);
    let compact: str = strip_spaces(body);
    let call_pat: str = str_concat(callee, "(");
    if str_contains(compact, call_pat) == 0 { return 0 - 1; };
    let params: Vec<i32> = md_param_names(params_text);
    let mut i: i64 = 0;
    while i < vec_len(params) {
        let param: str = vec_get(params, i);
        let guard: i64 = md_guard_limit_with_helpers(source, compact, param);
        if guard >= 0 && md_has_positive_increment(compact, param) == 1 {
            return guard;
        };
        let dec_a: str = str_concat(param, "-1");
        let le_zero: str = str_concat(param, "<=0");
        let lt_one: str = str_concat(param, "<1");
        if str_contains(compact, dec_a) == 1
           && (str_contains(compact, le_zero) == 1 || str_contains(compact, lt_one) == 1) {
            return 1;
        };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn md_entry_count(entries: Vec<i32>) -> i64 {
    return vec_len(entries) / 5;
}

#[manual_drop]
fn md_entry_name(entries: Vec<i32>, idx: i64) -> str {
    return vec_get(entries, idx * 5 + 1);
}

#[manual_drop]
fn md_entry_bound(entries: Vec<i32>, idx: i64) -> i64 {
    return vec_get(entries, idx * 5 + 2);
}

#[manual_drop]
fn md_entry_body(entries: Vec<i32>, idx: i64) -> str {
    return vec_get(entries, idx * 5 + 3);
}

#[manual_drop]
fn md_entry_params(entries: Vec<i32>, idx: i64) -> str {
    return vec_get(entries, idx * 5 + 4);
}

#[manual_drop]
fn md_edge_raw(entries: Vec<i32>, from_idx: i64, to_idx: i64) -> i64 {
    return md_body_contains_call(md_entry_body(entries, from_idx), md_entry_name(entries, to_idx));
}

#[manual_drop]
fn md_edge_proven(source: str, entries: Vec<i32>, from_idx: i64, to_idx: i64) -> i64 {
    if md_entry_bound(entries, from_idx) != md_entry_bound(entries, to_idx) { return 0; };
    let proven: i64 = md_proven_limit(source, md_entry_body(entries, from_idx), md_entry_params(entries, from_idx), md_entry_name(entries, to_idx));
    if proven < 0 || proven > md_entry_bound(entries, from_idx) { return 0; };
    return 1;
}

// Ownership heuristic flagged possible transfer due to
// vec_set/vec_push patterns. Review confirmed `seen` and
// `queue` are LOCAL BFS scratch — no handoff to caller-owned
// container. Annotating with #[manual_drop] as a defensive
// guardrail; auto-drop on return would be SAFE here, but we
// preserve v0.x semantics until the unconditional flip ships.
#[manual_drop]
fn md_path_exists(entries: Vec<i32>, from_idx: i64, target_idx: i64, proven_only: i64, source: str) -> i64 {
    let count: i64 = md_entry_count(entries);
    let mut seen: Vec<i32> = Vec::new();
    let mut queue: Vec<i32> = Vec::new();
    let mut si: i64 = 0;
    while si < count { seen.push(0); si = si + 1; };
    queue.push(from_idx);
    vec_set(seen, from_idx, 1);
    let mut qi: i64 = 0;
    while qi < vec_len(queue) {
        let cur: i64 = vec_get(queue, qi);
        let mut ni: i64 = 0;
        while ni < count {
            let has_edge: i64 = if proven_only == 1 { md_edge_proven(source, entries, cur, ni) } else { md_edge_raw(entries, cur, ni) };
            if has_edge == 1 {
                if ni == target_idx { return 1; };
                if vec_get(seen, ni) == 0 {
                    vec_set(seen, ni, 1);
                    queue.push(ni);
                };
            };
            ni = ni + 1;
        };
        qi = qi + 1;
    };
    return 0;
}

#[manual_drop]
fn md_estimate_frame_bytes(body_raw: str) -> i64 {
    let body: str = strip_strings_and_line_comments(body_raw);
    let blen: i64 = str_len(body);
    let mut p: i64 = 0;
    let mut stmts: i64 = 0;
    while p < blen {
        if str_char_at(body, p) == 59 { stmts = stmts + 1; };
        p = p + 1;
    };
    if stmts < 1 { stmts = 1; };
    return stmts * 64;
}

#[manual_drop]
fn source_has_max_depth_attr_line(source: str) -> i64 {
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut q: i64 = p;
        while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) { q = q + 1; };
        if str_eq_at(source, q, "#[max_depth") == 1 { return 1; };
        while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
        p = p + 1;
    };
    return 0;
}

#[manual_drop]
fn collect_max_depth_entries(diags: Vec<i32>, source: str) -> Vec<i32> {
    // Alternating records:
    // [fn_name, public_call_name, bound, body_raw, params_text, ...].
    // `fn_name` is the function carrying the attribute after the
    // deadline rewrite; `public_call_name` is the recursive callee that
    // appears in the user's body.
    let mut entries: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let compact_line: str = strip_spaces(line);
        if str_starts_with(compact_line, "#[max_depth") == 1 {
            let bound: i64 = md_extract_int_value(line);
            let mut probe: i64 = eol + 1;
            let mut found_fn: i64 = 0 - 1;
            let mut gave_up: i64 = 0;
            while probe < slen && found_fn < 0 && gave_up == 0 {
                let mut peol: i64 = probe;
                while peol < slen && str_char_at(source, peol) != 10 { peol = peol + 1; };
                let pline: str = str_substring(source, probe, peol);
                let mut lp: i64 = 0;
                let llen: i64 = str_len(pline);
                while lp < llen && (str_char_at(pline, lp) == 32 || str_char_at(pline, lp) == 9) { lp = lp + 1; };
                let ptrim: str = strip_spaces(pline);
                if str_len(ptrim) == 0 {
                    probe = peol + 1;
                } else if str_starts_with(ptrim, "///") == 1 {
                    probe = peol + 1;
                } else if str_eq_at(pline, lp, "fn ") == 1 {
                    found_fn = probe + lp;
                } else if str_eq_at(pline, lp, "pub fn ") == 1 {
                    found_fn = probe + lp + 4;
                } else if lp < llen && str_char_at(pline, lp) == 35 {
                    probe = peol + 1;
                } else {
                    gave_up = 1;
                };
            };
            if bound <= 0 || found_fn < 0 {
                let msg4: str = "`#[max_depth = N]` must use a positive integer literal and apply directly to a fn declaration";
                let mut lc4: Vec<i32> = find_linecol_in_source(source, "max_depth", "max_depth");
                diag_add_ex(diags, "error", "rt", "DEPTH-004", msg4, "max_depth", vec_get(lc4, 0), vec_get(lc4, 1), "");
            } else {
                let info: Vec<i32> = dl_parse_fn_signature(source, found_fn, slen);
                if vec_len(info) == 0 {
                    let msg4b: str = "`#[max_depth = N]` could not parse the following fn declaration";
                    let mut lc4b: Vec<i32> = find_linecol_in_source(source, "max_depth", "max_depth");
                    diag_add_ex(diags, "error", "rt", "DEPTH-004", msg4b, "max_depth", vec_get(lc4b, 0), vec_get(lc4b, 1), "");
                } else {
                    let fn_name: str = vec_get(info, 0);
                    let params_text: str = vec_get(info, 1);
                    let body_open: i64 = vec_get(info, 4);
                    let body_end: i64 = vec_get(info, 5);
                    let mut public_name: str = fn_name;
                    if str_starts_with(fn_name, "__nuc_dl_inner_") == 1 {
                        let wname: str = dl_get_wrapper_name(source, fn_name);
                        if str_len(wname) > 0 { public_name = wname; };
                    };
                    let body_raw: str = str_substring(source, body_open + 1, body_end - 1);
                    entries.push(fn_name);
                    entries.push(public_name);
                    entries.push(bound);
                    entries.push(body_raw);
                    entries.push(params_text);
                };
            };
        };
        p = eol + 1;
    };
    return entries;
}

#[manual_drop]
fn enforce_max_depth_static(diags: Vec<i32>, source: str) -> Vec<i32> {
    if source_has_max_depth_attr_line(source) == 0 { return diags; };
    let entries: Vec<i32> = collect_max_depth_entries(diags, source);
    let n: i64 = vec_len(entries);
    let stack_budget: i64 = 8192;
    let mut i: i64 = 0;
    while i + 4 < n {
        let fn_name: str = vec_get(entries, i);
        let public_name: str = vec_get(entries, i + 1);
        let bound: i64 = vec_get(entries, i + 2);
        let body_raw: str = vec_get(entries, i + 3);
        let params_text: str = vec_get(entries, i + 4);
        let callback_name: str = md_unproven_callback_param(body_raw, params_text);
        if str_len(callback_name) > 0 {
            let msg_cb: str = str_concat("analysis cannot bound callback or function-pointer path `", str_concat(callback_name, "`; mark the callback parameter #[no_recurse] only when it cannot recurse into this max_depth region"));
            let mut lc_cb: Vec<i32> = find_linecol_in_source(source, public_name, callback_name);
            diag_add_ex(diags, "error", "rt", "DEPTH-001", msg_cb, callback_name, vec_get(lc_cb, 0), vec_get(lc_cb, 1), "");
        };
        if md_body_contains_call(body_raw, public_name) == 1 {
            let proven: i64 = md_proven_limit(source, body_raw, params_text, public_name);
            if proven < 0 {
                let msg1: str = str_concat("analysis cannot bound recursive path in `", str_concat(public_name, "`; use a visible counter parameter, an entry guard, and recursive calls with a positive counter increment"));
                let mut lc1: Vec<i32> = find_linecol_in_source(source, public_name, public_name);
                diag_add_ex(diags, "error", "rt", "DEPTH-001", msg1, public_name, vec_get(lc1, 0), vec_get(lc1, 1), "");
            } else if proven > bound {
                let msg2: str = str_concat("static recursion depth ", str_concat(str_from_int(proven), str_concat(" exceeds #[max_depth = ", str_concat(str_from_int(bound), "]"))));
                let mut lc2: Vec<i32> = find_linecol_in_source(source, public_name, public_name);
                diag_add_ex(diags, "error", "rt", "DEPTH-002", msg2, public_name, vec_get(lc2, 0), vec_get(lc2, 1), "");
            };
        };
        let frame_bytes: i64 = md_estimate_frame_bytes(body_raw);
        if frame_bytes * bound > stack_budget {
            let msg5: str = str_concat("estimated stack use ", str_concat(str_from_int(frame_bytes * bound), str_concat(" bytes exceeds #[max_depth] stack budget ", str_from_int(stack_budget))));
            let mut lc5: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
            diag_add_ex(diags, "error", "rt", "DEPTH-005", msg5, fn_name, vec_get(lc5, 0), vec_get(lc5, 1), "");
        };
        i = i + 5;
    };
    i = 0;
    while i + 4 < n {
        let a_name: str = vec_get(entries, i + 1);
        let a_bound: i64 = vec_get(entries, i + 2);
        let a_body: str = vec_get(entries, i + 3);
        let a_params: str = vec_get(entries, i + 4);
        let mut j: i64 = i + 5;
        while j + 4 < n {
            let b_name: str = vec_get(entries, j + 1);
            let b_bound: i64 = vec_get(entries, j + 2);
            let b_body: str = vec_get(entries, j + 3);
            let b_params: str = vec_get(entries, j + 4);
            if md_body_contains_call(a_body, b_name) == 1 && md_body_contains_call(b_body, a_name) == 1 {
                let a_proven: i64 = md_proven_limit(source, a_body, a_params, b_name);
                let b_proven: i64 = md_proven_limit(source, b_body, b_params, a_name);
                if a_bound != b_bound || a_proven < 0 || b_proven < 0 || a_proven > a_bound || b_proven > b_bound {
                    let msg3: str = str_concat("mutually recursive cycle `", str_concat(a_name, str_concat(" <-> ", str_concat(b_name, "` has incompatible or unproven #[max_depth] bounds"))));
                    let mut lc3: Vec<i32> = find_linecol_in_source(source, a_name, a_name);
                    diag_add_ex(diags, "error", "rt", "DEPTH-003", msg3, a_name, vec_get(lc3, 0), vec_get(lc3, 1), "");
                };
            };
            j = j + 5;
        };
        i = i + 5;
    };
    let count: i64 = md_entry_count(entries);
    let mut from_idx: i64 = 0;
    while from_idx < count {
        let mut to_idx: i64 = 0;
        while to_idx < count {
            if from_idx != to_idx && md_edge_raw(entries, from_idx, to_idx) == 1 {
                if md_path_exists(entries, to_idx, from_idx, 0, source) == 1
                   && (md_edge_proven(source, entries, from_idx, to_idx) == 0
                       || md_path_exists(entries, to_idx, from_idx, 1, source) == 0) {
                    let cyc_a: str = md_entry_name(entries, from_idx);
                    let cyc_b: str = md_entry_name(entries, to_idx);
                    let msg_scc: str = str_concat("recursive SCC containing `", str_concat(cyc_a, str_concat(" -> ", str_concat(cyc_b, "` has incompatible or unproven #[max_depth] bounds"))));
                    let mut lc_scc: Vec<i32> = find_linecol_in_source(source, cyc_a, cyc_a);
                    diag_add_ex(diags, "error", "rt", "DEPTH-003", msg_scc, cyc_a, vec_get(lc_scc, 0), vec_get(lc_scc, 1), "");
                };
            };
            to_idx = to_idx + 1;
        };
        from_idx = from_idx + 1;
    };
    return diags;
}

#[manual_drop]
fn enforce_rt008_recursion(diags: Vec<i32>, source: str) -> Vec<i32> {
    let dl_entries: Vec<i32> = wcet_collect_deadline_fns(source);
    let n: i64 = vec_len(dl_entries);
    if n == 0 { return diags; };
    let max_depth_entries: Vec<i32> = collect_max_depth_entries(diags, source);
    let mut k: i64 = 0;
    while k + 1 < n {
        let inner_name: str = vec_get(dl_entries, k);
        let wrapper_name: str = dl_get_wrapper_name(source, inner_name);
        if str_len(wrapper_name) > 0 {
            // Is the inner (the one carrying the user's #[max_depth]
            // attribute after T3.1 preserves it) opted out?
            let mut bounded: i64 = 0;
            let mut j: i64 = 0;
            let mn: i64 = vec_len(max_depth_entries);
            while j + 4 < mn && bounded == 0 {
                if str_eq(vec_get(max_depth_entries, j), inner_name) == 1 { bounded = 1; };
                j = j + 5;
            };
            if bounded == 0 {
                // Scan the inner body (stripped) for `<wrapper>(`.
                let needle: str = str_concat("fn ", str_concat(inner_name, "("));
                let nlen: i64 = str_len(needle);
                let slen: i64 = str_len(source);
                let mut p: i64 = 0;
                while p + nlen <= slen {
                    let mut m: i64 = 1;
                    let mut q: i64 = 0;
                    while q < nlen && m == 1 {
                        if str_char_at(source, p + q) != str_char_at(needle, q) { m = 0; };
                        q = q + 1;
                    };
                    if m == 1 { break; };
                    p = p + 1;
                };
                if p + nlen <= slen {
                    let mut bp: i64 = p + nlen;
                    while bp < slen && str_char_at(source, bp) != 123 { bp = bp + 1; };
                    if bp < slen {
                        let body_start: i64 = bp + 1;
                        let mut depth: i64 = 1;
                        bp = bp + 1;
                        while bp < slen && depth > 0 {
                            let c: i64 = str_char_at(source, bp);
                            if c == 123 { depth = depth + 1; };
                            if c == 125 { depth = depth - 1; };
                            bp = bp + 1;
                        };
                        let body_raw: str = str_substring(source, body_start, bp - 1);
                        let body: str = strip_strings_and_line_comments(body_raw);
                        let call_pat: str = str_concat(wrapper_name, "(");
                        if str_contains(body, call_pat) == 1 {
                            let msg: str = str_concat("'", str_concat(wrapper_name, "' has #[deadline] and recursively calls itself; add #[max_depth = N] to opt out (recursion can blow the deadline budget)"));
                            diag_add_fn_site(diags, "warning", "rt", "RT-008", msg, source, wrapper_name);
                        };
                    };
                };
            };
        };
        k = k + 2;
    };
    return diags;
}

// === T3.8 (v0.3.7): RT-006 — RT attribute on async fn ===
// expand_async_strip_keyword (in the resolver-level expanders)
// drops the `async` keyword for good. To still detect "an RT
// attribute was attached to an `async fn`", that pass leaves
// behind a marker comment line at column 0 for every offender.
// The marker prefix is intentionally short and weird so the
// exact byte sequence (with leading newline) does not appear
// elsewhere in the s1 compiler source — without that, the
// scanner would self-match on its own needle.
// Per the RFC: async is non-deterministic by design (thread
// scheduling, IO wakeups, etc.) and cannot satisfy any RT
// guarantee. The two have to be mutually exclusive.

#[manual_drop]
fn enforce_rt006_async(diags: Vec<i32>, source: str) -> Vec<i32> {
    // Match \n + "//__NUC6T:" — leading newline ensures we only
    // hit markers that the expander emitted at column 0, not
    // string-literal contents (preceded by ") or mid-line prose.
    let needle: str = "\n//__NUC6T:";
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let nm_start: i64 = p + nlen;
            let mut q: i64 = nm_start;
            while q < slen && str_char_at(source, q) != 10 && str_char_at(source, q) != 13 { q = q + 1; };
            let fn_name: str = str_substring(source, nm_start, q);
            let msg: str = str_concat("RT attribute (e.g. #[no_alloc] / #[no_panic] / #[no_dyn] / #[deadline]) on async fn '", str_concat(fn_name, "' -- async is non-deterministic by design and cannot satisfy real-time guarantees"));
            diag_add_fn_site(diags, "error", "rt", "RT-006", msg, source, fn_name);
            p = q;
        } else {
            p = p + 1;
        };
    };
    return diags;
}

// async keyword cannot be silently stripped.
// Sister scanner to enforce_rt006_async — picks up the
// `//__NUC6X:<fn_name>` markers that expand_async_strip_keyword emits
// for plain `async fn` (no RT attribute). Pre-fix the keyword was
// silently dropped — adopters writing the canonical Rust async pattern
// got immediate sync execution with no signal. The fn still runs (no
// halt), but the warning points adopters at the actual threading
// primitives (`async_spawn(fn_ptr, arg)` + `async_await(handle)`,
// RFC-0027 phase 1).
#[manual_drop]
fn enforce_async001_warning(diags: Vec<i32>, source: str) -> Vec<i32> {
    let needle: str = "\n//__NUC6X:";
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let nm_start: i64 = p + nlen;
            let mut q: i64 = nm_start;
            while q < slen && str_char_at(source, q) != 10 && str_char_at(source, q) != 13 { q = q + 1; };
            let fn_name: str = str_substring(source, nm_start, q);
            let msg: str = str_concat("`async` keyword on fn `", str_concat(fn_name, "` is silently stripped — Nucleor v0.5 has no Future / no .await polling. Adopters writing the canonical Rust pattern get immediate sync execution. Use `async_spawn(fn_ptr, arg)` to run on a real OS thread (returns a handle) + `async_await(handle)` to join (RFC-0027 phase 1, see stdlib/rods/async.nr). Or drop the `async` keyword if sync execution was intended."));
            diag_add_fn_site(diags, "warning", "async", "ASYNC-001", msg, source, fn_name);
            p = q;
        } else {
            p = p + 1;
        };
    };
    return diags;
}

// === T3.3 (v0.3.2): heuristic deadline estimate (RT-004, NOT certified WCET) ===
// This estimator is NOT certified WCET — it is a fast, conservative
// heuristic that triggers a warning
// when a function looks expensive relative to its declared deadline.
// Pre-v0.8.289 wording said "static WCET" and "v1 estimator", which
// reasonably reads as a real WCET model — clarified here, in the
// emitted diagnostic, and in RFC-0001 to call this out as heuristic.
// A certified WCET / cost-table contract is Phase 2 (RFC-0001 §WCET).
// What this pass does:
// Parses every `#[deadline = N]` fn, estimates its worst-case
// execution time via a simple statement counter, and emits a
// compile-time RT-004 warning when the estimate exceeds the
// declared deadline.
// Heuristic (conservative, prone to false positives + false
// negatives — both documented so adopters use `#[allow(RT-004)]`
// or `#[allow_fn(RT-004)]` to suppress when the estimator is
// demonstrably wrong for the body in question):
//   - Each `;` (statement terminator) = 1 unit = 0.1 µs
//   - Each `while` keyword multiplies the inner unit count by a
//     coarse multiplier (1, 100, 1000, 10000 for 0/1/2/3+ whiles)
//   - Hard cap at 1e6 units to prevent runaway
//   - No call-target costing (callees are NOT inlined into the
//     estimate; an `O(n)` helper inside a tight loop is invisible
//     to this pass)
//   - No backend / ISA / cache / branch-prediction modeling
//   - String-literal `;` and comment-`while` are NOT skipped —
//     accepted v1 false-positive surface
// Conversion: estimated_us = ceil(units / 10).
// Ship shape: warning-level diagnostic (not error) because the
// estimator is deliberately crude. A certified WCET / cost-table
// pass is future work; the heuristic remains
// available alongside it as a fast / opt-in early signal.

#[manual_drop]
fn wcet_collect_deadline_fns(source: str) -> Vec<i32> {
    // Returns alternating [inner_name1, limit1_us, ...].
    // Scans for `deadline_check(__nuc_dl_start, N)` which the
    // T3.1 expander emits in every wrapper, then walks back up to
    // 1024 bytes for the matching `__nuc_dl_inner_<...>` ident.
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let needle: str = "deadline_check(__nuc_dl_start,";
    let nlen: i64 = str_len(needle);
    let inner_pat: str = "__nuc_dl_inner_";
    let ipl: i64 = str_len(inner_pat);
    let mut p: i64 = 0;
    let max_outer_iters: i64 = 1000000;  // safety bound
    let mut outer_iters: i64 = 0;
    while p + nlen <= slen && outer_iters < max_outer_iters {
        outer_iters = outer_iters + 1;
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && m == 1 {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + nlen;
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) { q = q + 1; };
            let num_start: i64 = q;
            while q < slen && is_digit(str_char_at(source, q)) == 1 { q = q + 1; };
            if q > num_start {
                let limit_us: i64 = str_to_int(str_substring(source, num_start, q));
                let scan_floor: i64 = if p > 1024 { p - 1024 } else { 0 };
                let mut bp: i64 = p;
                let mut found: i64 = 0;
                while bp > scan_floor && found == 0 {
                    if bp + ipl <= slen {
                        let mut im: i64 = 1;
                        let mut ik: i64 = 0;
                        while ik < ipl && im == 1 {
                            if str_char_at(source, bp + ik) != str_char_at(inner_pat, ik) { im = 0; };
                            ik = ik + 1;
                        };
                        if im == 1 {
                            let mut np: i64 = bp + ipl;
                            while np < slen && (is_alnum(str_char_at(source, np)) == 1 || str_char_at(source, np) == 95) {
                                np = np + 1;
                            };
                            let inner_name: str = str_substring(source, bp, np);
                            out.push(inner_name);
                            out.push(limit_us);
                            found = 1;
                        };
                    };
                    if found == 0 { bp = bp - 1; };
                };
            };
            p = q + 1;
        } else {
            p = p + 1;
        };
    };
    return out;
}

#[manual_drop]
fn wcet_estimate_fn_units(source: str, fn_name: str) -> i64 {
    // Counts `;` (statements) inside the named fn body, separately
    // counts `while` keywords, applies a coarse multiplier ladder
    // (1, 100, 1000, 10000 for 0/1/2/3+ loops). Hard-capped at 1e6
    // units.
    // R03-D3 Phase 1.5 (v0.8.291): the scan now SKIPS content inside
    // `"` string literals (with `\"` escape) and `//` line comments.
    // Pre-v0.8.291 a body containing `print(";a;b;c;")` over-counted
    // 4 spurious statements; the line-comment skip removes a similar
    // false-positive on `// while (...)` text.
    // R03-D3 Phase 1.6 (v0.8.292): `loop { ... }` (Nucleor's
    // unbounded-loop form, desugars to `while true`, see s1 lex
    // around line 3843) is now counted toward `while_count` so it
    // participates in the multiplier ladder. Pre-v0.8.292 a `pure fn
    // { loop { ...; ...; }}` tallied while_count=0 → multiplier=1 →
    // severe under-estimate. Closes a real false-NEGATIVE.
    // Callee-cost aggregation + constant-bound loop bounds are still
    // Phase 2 work.
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut found_at: i64 = 0 - 1;
    while p + nlen <= slen && found_at < 0 {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && m == 1 {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; };
            k = k + 1;
        };
        if m == 1 { found_at = p; }
        else { p = p + 1; };
    };
    if found_at < 0 { return 0; };
    let mut q: i64 = found_at + nlen;
    while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
    if q >= slen { return 0; };
    q = q + 1;
    let mut depth: i64 = 1;
    let mut stmt_count: i64 = 0;
    let mut while_count: i64 = 0;
    let stmt_cap: i64 = 1000000;
    let mut in_string: i64 = 0;
    let mut in_line_comment: i64 = 0;
    while q < slen && depth > 0 && stmt_count < stmt_cap {
        let c: i64 = str_char_at(source, q);
        if in_line_comment == 1 {
            if c == 10 { in_line_comment = 0; };
            q = q + 1;
        } else {
            if in_string == 1 {
                if c == 92 && q + 1 < slen { q = q + 2; }
                else {
                    if c == 34 { in_string = 0; };
                    q = q + 1;
                };
            } else {
                if c == 34 { in_string = 1; q = q + 1; }
                else {
                    if c == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                        in_line_comment = 1;
                        q = q + 2;
                    } else {
                        if c == 123 { depth = depth + 1; };
                        if c == 125 { depth = depth - 1; };
                        if c == 59 { stmt_count = stmt_count + 1; };
                        if c == 119 && q + 5 <= slen {
                            if str_char_at(source, q + 1) == 104 && str_char_at(source, q + 2) == 105
                                && str_char_at(source, q + 3) == 108 && str_char_at(source, q + 4) == 101 {
                                let prev: i64 = if q > 0 { str_char_at(source, q - 1) } else { 32 };
                                let next: i64 = if q + 5 < slen { str_char_at(source, q + 5) } else { 32 };
                                let prev_ok: i64 = if is_alnum(prev) == 0 && prev != 95 { 1 } else { 0 };
                                let next_ok: i64 = if is_alnum(next) == 0 && next != 95 { 1 } else { 0 };
                                if prev_ok == 1 && next_ok == 1 { while_count = while_count + 1; };
                            };
                        };
                        // R03-D3 Phase 1.6 (v0.8.292): `loop {` is the
                        // unbounded-loop form. Pre-v0.8.292 the estimator
                        // counted `while` only, so a `loop { ... }` body
                        // tallied 0 loops → multiplier=1 → severe under-
                        // estimate. Now treat `loop` as a loop too.
                        // Match: l, o, o, p, then non-ident.
                        if c == 108 && q + 4 <= slen {
                            if str_char_at(source, q + 1) == 111 && str_char_at(source, q + 2) == 111
                                && str_char_at(source, q + 3) == 112 {
                                let prev_l: i64 = if q > 0 { str_char_at(source, q - 1) } else { 32 };
                                let next_l: i64 = if q + 4 < slen { str_char_at(source, q + 4) } else { 32 };
                                let prev_ok_l: i64 = if is_alnum(prev_l) == 0 && prev_l != 95 { 1 } else { 0 };
                                let next_ok_l: i64 = if is_alnum(next_l) == 0 && next_l != 95 { 1 } else { 0 };
                                if prev_ok_l == 1 && next_ok_l == 1 { while_count = while_count + 1; };
                            };
                        };
                        q = q + 1;
                    };
                };
            };
        };
    };
    let mut multiplier: i64 = 1;
    if while_count == 1 { multiplier = 100; };
    if while_count == 2 { multiplier = 1000; };
    if while_count >= 3 { multiplier = 10000; };
    let units: i64 = stmt_count * multiplier;
    if units > stmt_cap { return stmt_cap; };
    return units;
}

// === R10-D2 Phase 1 (v0.8.297): @hot HotViolation enforcement ===
// Docs name HotViolation / HeapInLoop diagnostics but `nuc perf`
// emits only generic compile metrics. The `@hot` attribute is
// discovered but not enforced. A
// `@hot fn` containing `Vec::new()` or `print()` shipped silently
// despite the perf-critical annotation.
// Phase 1: analogous to NUM-009 (R09-D4 v0.8.293) — scan each
// `@hot` body for known-expensive patterns and emit warning[PERF-2].
// Severity = warning (not error) because `@hot` is a hint not a
// hard contract. Adopters use `#[allow_fn(PERF-2)]` to suppress
// when the cost is intentional. HeapInLoop (PERF-3) is Phase 2
// (needs nested-block tracking).
// Returns 0 (clean) or non-zero code naming first violation:
//   1 = allocation (Vec::new / Box::new)
//   2 = I/O (print / println / panic)
//   3 = Math-heavy stdlib helper (math_sqrt / math_pow)
#[manual_drop]
fn hot_fn_body_violation_code(source: str, fn_name: str) -> i64 {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut found_at: i64 = 0 - 1;
    while p + nlen <= slen && found_at < 0 {
        if str_eq_at_len(source, p, needle, nlen) == 1 { found_at = p; }
        else { p = p + 1; };
    };
    if found_at < 0 { return 0; };
    let mut q: i64 = found_at + nlen;
    while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
    if q >= slen { return 0; };
    let body_start: i64 = q + 1;
    q = body_start;
    let mut depth: i64 = 1;
    let mut body_end: i64 = slen;
    while q < slen && depth > 0 {
        let c: i64 = str_char_at(source, q);
        if c == 123 { depth = depth + 1; };
        if c == 125 {
            depth = depth - 1;
            if depth == 0 { body_end = q; };
        };
        q = q + 1;
    };
    let body: str = str_substring(source, body_start, body_end);
    if str_index_of(body, "Vec::new") >= 0 { return 1; };
    if str_index_of(body, "Box::new") >= 0 { return 1; };
    if str_index_of(body, "print(") >= 0 { return 2; };
    if str_index_of(body, "println(") >= 0 { return 2; };
    if str_index_of(body, "panic(") >= 0 { return 2; };
    return 0;
}

// === v0.8.308 — consolidated body-diagnostics single-walk pass ===
// Background: between v0.8.293 and v0.8.307 we added 6 separate
// emitters, each walking the source independently:
//   enforce_const_fn_purity (NUM-009)         — v0.8.293
//   enforce_hot_fn_purity   (PERF-2)          — v0.8.297
//   enforce_heap_in_loop    (PERF-3)          — v0.8.298
//   enforce_unawaited_spawn (RACE-002)        — v0.8.299
//   enforce_deadline_with_await (RACE-007)    — v0.8.300
//   enforce_pure_fn_purity  (EFF-001/002)     — v0.8.307/v0.8.320
// User-measured cold compile time blew up: baseline 4.64s ->
// ~12s (2.6×). Each emitter does an O(F·S) per-fn body extraction
// — 6 of them stack to ~36M ops on a 12K-line source.
// This consolidated pass walks the source EXACTLY ONCE, tracks
// the most recent attribute lines (for `@const_fn` / `@hot`
// recognition), extracts each fn body in-place (no re-scan from
// position 0), and runs ALL six checks against the same body
// substring. Total cost ~O(S + total_body_size) — well under
// the baseline budget.
// The 6 individual emitters above are kept as dead code (callable
// but unwired) so any external integration that imports them
// keeps working; the wire-in dispatch in compile_file_mode now
// calls only this consolidated pass.
#[manual_drop]
fn enforce_body_diagnostics_unified(diags: Vec<i32>, source: str) -> Vec<i32> {
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let has_pure_source: i64 = source_has_real_pure_fn_decl(source);
    let transitive_effectful: Vec<i32> = if has_pure_source == 1 { collect_transitive_effectful_fns(source) } else { Vec::new() };
    let unsafe_externs: Vec<i32> = if has_pure_source == 1 { collect_extern_fn_names(source) } else { Vec::new() };
    // Tracks attribute lines accumulated since the last non-attr
    // non-comment non-blank line. Cleared on encountering a fn decl
    // (consumed by the fn) or a non-attr code line (cleared).
    let mut prev_attrs: str = "";
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let trimmed: str = str_trim(line);
        let is_blank: i64 = if str_len(trimmed) == 0 { 1 } else { 0 };
        let is_comment: i64 = if str_index_of(trimmed, "//") == 0 { 1 } else { 0 };
        let starts_attr: i64 = if str_index_of(trimmed, "@") == 0 { 1 } else { if str_index_of(trimmed, "#[") == 0 { 1 } else { 0 } };
        if is_blank == 1 || is_comment == 1 {
            p = eol + 1;
            continue;
        };
        if starts_attr == 1 {
            prev_attrs = str_concat(prev_attrs, str_concat(line, "\n"));
            p = eol + 1;
            continue;
        };
        // Non-attr code line — possibly a fn decl.
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            // Find body opening brace. Start from the fn-decl line
            // start (`p`), not `eol`, because a fn decl ending in `{`
            // means `eol` lands at the `\n` AFTER the `{` — scanning
            // forward from there finds the NEXT fn's brace.
            let mut q: i64 = p;
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            let mut body: str = "";
            let mut body_q: i64 = q;
            if q < slen {
                let body_start: i64 = q + 1;
                q = q + 1;
                let mut depth: i64 = 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                body = str_substring(source, body_start, q - 1);
                body_q = q;
            };
            let bod_len: i64 = str_len(body);
            if bod_len > 0 {
                // Pre-compute a single set of substring presence flags.
                let has_print: i64 = if str_index_of(body, "print(") >= 0 { 1 } else {
                    if str_index_of(body, "println(") >= 0 { 1 } else {
                        if str_index_of(body, "print_") >= 0 { 1 } else {
                            if str_index_of(body, "eprint") >= 0 { 1 } else { 0 } } } };
                let has_alloc: i64 = if str_index_of(body, "Vec::new") >= 0 { 1 } else { if str_index_of(body, "Box::new") >= 0 { 1 } else { 0 } };
                let has_panic: i64 = if str_index_of(body, "panic(") >= 0 { 1 } else {
                    if str_index_of(body, ".unwrap(") >= 0 { 1 } else {
                        if str_index_of(body, ".expect(") >= 0 { 1 } else {
                            if str_index_of(body, "assert_eq(") >= 0 { 1 } else {
                                if str_index_of(body, "assert_ne(") >= 0 { 1 } else { 0 } } } } };
                let has_ambient: i64 = if str_index_of(body, "ambient_random") >= 0 { 1 } else { 0 };
                let has_async_spawn: i64 = if str_index_of(body, "async_spawn(") >= 0 { 1 } else { 0 };
                let has_async_await: i64 = if str_index_of(body, "async_await(") >= 0 { 1 } else { 0 };
                let attrs_have_const_fn: i64 = if str_index_of(prev_attrs, "@const_fn") >= 0 { 1 } else { 0 };
                let attrs_have_hot: i64 = if str_index_of(prev_attrs, "@hot") >= 0 { 1 } else { 0 };
                let line_has_pure_fn: i64 = if str_index_of(line, "pure fn ") >= 0 { 1 } else { 0 };
                let line_has_requires_effect: i64 = if str_index_of(line, str_concat("requires", " [")) >= 0 { 1 } else { if str_index_of(line, str_concat("requires", "[")) >= 0 { 1 } else { 0 } };
                let is_dl_inner: i64 = if str_starts_with(fn_name, "__nuc_dl_inner_") == 1 { 1 } else { 0 };

                // === NUM-009 (R09-D4): @const_fn must be pure ===
                if attrs_have_const_fn == 1 {
                    let mut code: i64 = 0;
                    if has_print == 1 { code = 1; };
                    if code == 0 && has_alloc == 1 { code = 2; };
                    if code == 0 && has_panic == 1 { code = 3; };
                    if code == 0 && has_ambient == 1 { code = 4; };
                    if code > 0 {
                        let kind: str = if code == 1 { "calls print() — I/O is not const" }
                            else if code == 2 { "calls Vec::new()/Box::new() — heap allocation is not const" }
                            else if code == 3 { "may panic (panic/unwrap/expect/assert) — control-flow trap is not const" }
                            else { "uses ambient capability (ambient_*) — non-deterministic input is not const" };
                        let msg: str = str_concat("`@const_fn` function `", str_concat(fn_name, str_concat("` ", str_concat(kind, "; remove the @const_fn annotation, or move the effectful work to a normal fn"))));
                        let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "error", "num", "NUM-009", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                    };
                };

                // === EFF-001 (R05-D1): pure fn must be pure ===
                if line_has_pure_fn == 1 {
                    if line_has_requires_effect == 1 {
                        let msg_eff2: str = str_concat("`pure fn ", str_concat(fn_name, "` declares a `requires [...]` effect row; pure functions cannot require effects"));
                        let lc_eff2: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "error", "effect", "EFF-002", msg_eff2, fn_name, vec_get(lc_eff2, 0), vec_get(lc_eff2, 1), "");
                    };
                    let pure_body: str = strip_strings_and_line_comments(body);
                    let mut pcode: i64 = 0;
                    let mut specific_callee: str = "";
                    if has_print == 1 { pcode = 1; };
                    if pcode == 0 && has_alloc == 1 { pcode = 2; };
                    if pcode == 0 && has_ambient == 1 { pcode = 3; };
                    if pcode == 0 && str_index_of(pure_body, "scope {") >= 0 { pcode = 4; };
                    if pcode == 0 && str_index_of(pure_body, "spawn {") >= 0 { pcode = 4; };
                    if pcode == 0 && str_index_of(pure_body, "channel(") >= 0 { pcode = 5; };
                    // RFC-0063 Phase 1.5: bridge syntactic-Phase-1
                    // toward semantic-Phase-2b. Inspect body for known-impure
                    // stdlib helpers (vec_push, str_concat, file_*, ...) that
                    // the constructor-only Phase-1 check missed.
                    if pcode == 0 {
                        specific_callee = priv_first_impure_callee(pure_body);
                        if str_len(specific_callee) > 0 { pcode = 6; };
                    };
                    if pcode > 0 {
                        let kind2: str = if pcode == 1 { "calls print/println/print_* — I/O is not pure" }
                            else if pcode == 2 { "allocates (Vec::new / Box::new) — heap allocation is not pure" }
                            else if pcode == 3 { "uses ambient capability (ambient_*) — non-deterministic input is not pure" }
                            else if pcode == 4 { "uses structured scheduling (scope/spawn) — scheduler effects are not pure" }
                            else if pcode == 5 { "uses channel construction — sync.channel effects are not pure" }
                            else { str_concat("calls ", str_concat(specific_callee, " — not pure")) };
                        let msg2: str = str_concat("`pure fn ", str_concat(fn_name, str_concat("` ", str_concat(kind2, "; remove `pure` qualifier or move the side effect to a normal fn"))));
                        let lc2: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "error", "effect", "EFF-001", msg2, fn_name, vec_get(lc2, 0), vec_get(lc2, 1), "");
                    } else {
                        let pure_extern: str = first_effectful_user_call(pure_body, unsafe_externs, fn_name);
                        let pure_callee: str = if str_len(pure_extern) > 0 { pure_extern } else { first_effectful_user_call(pure_body, transitive_effectful, fn_name) };
                        if str_len(pure_callee) > 0 {
                            let callee_kind: str = if str_len(pure_extern) > 0 { "which is an extern/default-unsafe effect surface" } else { "which has transitive side effects" };
                            let msg_trans2: str = str_concat("`pure fn ", str_concat(fn_name, str_concat("` calls `", str_concat(pure_callee, str_concat("()` ", str_concat(callee_kind, "; remove `pure` qualifier or make the call chain effect-free"))))));
                            let lc_trans2: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                            diag_add_ex(diags, "error", "effect", "EFF-001", msg_trans2, fn_name, vec_get(lc_trans2, 0), vec_get(lc_trans2, 1), "");
                        };
                    };
                };

                // === PERF-2 (R10-D2): @hot must be alloc/IO-free ===
                if attrs_have_hot == 1 {
                    let mut hcode: i64 = 0;
                    if has_alloc == 1 { hcode = 1; };
                    if hcode == 0 && has_print == 1 { hcode = 2; };
                    if hcode > 0 {
                        let hkind: str = if hcode == 1 { "allocates (Vec::new / Box::new) — heap allocation in a perf-critical path" }
                            else { "performs I/O (print / println / panic) — blocking syscall in a perf-critical path" };
                        let hmsg: str = str_concat("`@hot` function `", str_concat(fn_name, str_concat("` ", str_concat(hkind, "; suppress with `#[allow_fn(PERF-2)]` when intentional, or move the work out of the hot path"))));
                        let hlc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "warning", "perf", "PERF-2", hmsg, fn_name, vec_get(hlc, 0), vec_get(hlc, 1), "");
                    };
                };

                // === PERF-3 (R10-D2): heap alloc inside while/loop ===
                if has_alloc == 1 {
                    if detect_heap_in_loop_in_body(body) == 1 {
                        let p3msg: str = str_concat("function `", str_concat(fn_name, "` allocates (Vec::new / Box::new) inside a `while` or `loop` block — per-iteration heap alloc is a perf hazard; reserve outside the loop, use a stack-allocated buffer, or `#[allow_fn(PERF-3)]` if intentional"));
                        let p3lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "warning", "perf", "PERF-3", p3msg, fn_name, vec_get(p3lc, 0), vec_get(p3lc, 1), "");
                    };
                };

                // === RACE-002 (R04-D3): unawaited async_spawn ===
                if has_async_spawn == 1 && has_async_await == 0 {
                    let r2msg: str = str_concat("function `", str_concat(fn_name, "` calls `async_spawn(...)` but never `async_await(...)` — fire-and-forget breaks completion ordering and may leak the task handle; await each spawn or `#[allow_fn(RACE-002)]` if intentional"));
                    let r2lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                    diag_add_ex(diags, "warning", "race", "RACE-002", r2msg, fn_name, vec_get(r2lc, 0), vec_get(r2lc, 1), "");
                };

                // === RACE-007 (R04-D3): __nuc_dl_inner_* + async_await ===
                if is_dl_inner == 1 && has_async_await == 1 {
                    let r7msg: str = str_concat("function `", str_concat(fn_name, "` is the inner of a #[deadline]-wrapped fn AND calls `async_await(...)` — the deadline checker cannot see past the actor executor boundary; the awaited task may take arbitrarily long, invalidating the deadline. Either drop the deadline, drop the await, or `#[allow_fn(RACE-007)]` on the original fn"));
                    let r7lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                    diag_add_ex(diags, "warning", "race", "RACE-007", r7msg, fn_name, vec_get(r7lc, 0), vec_get(r7lc, 1), "");
                };
            };
            prev_attrs = "";
            // Advance past the body's close brace.
            if body_q > eol { p = body_q; }
            else { p = eol + 1; };
            continue;
        };
        // Non-fn code line — clear pending attrs and advance.
        prev_attrs = "";
        p = eol + 1;
    };
    return diags;
}

#[manual_drop]
fn enforce_hot_fn_purity(diags: Vec<i32>, source: str) -> Vec<i32> {
    let needle: str = str_concat("@h", "ot");
    let names: str = attribute_audit_fn_names(source, needle);
    let nlen: i64 = str_len(names);
    if nlen == 0 { return diags; };
    let mut start: i64 = 0;
    let mut q: i64 = 0;
    while q <= nlen {
        let at_end: i64 = if q == nlen { 1 } else { 0 };
        let is_sep: i64 = if at_end == 0 && str_char_at(names, q) == 59 { 1 } else { 0 };
        if at_end == 1 || is_sep == 1 {
            let raw: str = str_substring(names, start, q);
            let fn_name: str = str_trim(raw);
            if str_len(fn_name) > 0 {
                let code: i64 = hot_fn_body_violation_code(source, fn_name);
                if code > 0 {
                    let kind: str = if code == 1 { "allocates (Vec::new / Box::new) — heap allocation in a perf-critical path" }
                        else { "performs I/O (print / println / panic) — blocking syscall in a perf-critical path" };
                    let msg: str = str_concat("`@hot` function `", str_concat(fn_name, str_concat("` ", str_concat(kind, "; suppress with `#[allow_fn(PERF-2)]` when intentional, or move the work out of the hot path"))));
                    let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                    diag_add_ex(diags, "warning", "perf", "PERF-2", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                };
            };
            start = q + 2;
            q = q + 2;
        } else {
            q = q + 1;
        };
    };
    return diags;
}

// === R04-D3 Phase 1.5 (v0.8.300): RACE-007 emitter (deadline + actor await) ===
// RACE-007 = "Deadline composition under actor await
// is invalid". Detect: a fn carries `#[deadline = ...]` AND its
// body calls `async_await(`. The deadline checker can't see
// past the actor executor boundary — the awaited task may take
// arbitrarily long.
// Severity = warning. Suppress with `#[allow_fn(RACE-007)]`.
#[manual_drop]
fn enforce_deadline_with_await(diags: Vec<i32>, source: str) -> Vec<i32> {
    // Post-deadline-rewrite the `#[deadline = ...]` attribute is
    // desugared into `deadline_check(__nuc_dl_start, ...)` calls
    // injected at the top of the (renamed) inner fn. Detection: walk
    // every fn body; if it contains BOTH `deadline_check(` (deadline
    // marker) AND `async_await(` (the actor-suspend call), emit
    // RACE-007. The `__nuc_dl_inner_*` rewrite means the ORIGINAL fn
    // name is no longer recoverable from the post-rewrite source —
    // we report against the wrapper / inner name as found.
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            let nd: str = str_concat("fn ", str_concat(fn_name, "("));
            let ndl: i64 = str_len(nd);
            let mut sp: i64 = 0;
            let mut found: i64 = 0 - 1;
            while sp + ndl <= slen && found < 0 {
                if str_eq_at_len(source, sp, nd, ndl) == 1 { found = sp; }
                else { sp = sp + 1; };
            };
            if found >= 0 {
                let mut bp: i64 = found + ndl;
                while bp < slen && str_char_at(source, bp) != 123 { bp = bp + 1; };
                if bp < slen {
                    let body_start: i64 = bp + 1;
                    bp = bp + 1;
                    let mut depth: i64 = 1;
                    while bp < slen && depth > 0 {
                        let c: i64 = str_char_at(source, bp);
                        if c == 123 { depth = depth + 1; };
                        if c == 125 { depth = depth - 1; };
                        bp = bp + 1;
                    };
                    let body: str = str_substring(source, body_start, bp - 1);
                    // The deadline-wrap rewrite splits the original fn into
                    // a wrapper (carrying `deadline_check(...)`) and an inner
                    // (`__nuc_dl_inner_*` carrying the original body, including
                    // any `async_await(...)`). Detect the inner by name prefix,
                    // and check it for `async_await(`.
                    let is_inner: i64 = if str_starts_with(fn_name, "__nuc_dl_inner_") == 1 { 1 } else { 0 };
                    if is_inner == 1 && str_index_of(body, "async_await(") >= 0 {
                        let msg: str = str_concat("function `", str_concat(fn_name, "` is the inner of a #[deadline]-wrapped fn AND calls `async_await(...)` — the deadline checker cannot see past the actor executor boundary; the awaited task may take arbitrarily long, invalidating the deadline. Either drop the deadline, drop the await, or `#[allow_fn(RACE-007)]` on the original fn"));
                        let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "warning", "race", "RACE-007", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                    };
                };
            };
        };
        p = eol + 1;
    };
    return diags;
}

#[manual_drop]
fn _enforce_deadline_with_await_unused_VESTIGIAL(diags: Vec<i32>, source: str) -> Vec<i32> {
    // Removed scaffolding — the actual emitter is `enforce_deadline_with_await` above.
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let trimmed_outer: str = str_trim(line);
        let is_outer_comment: i64 = if str_index_of(trimmed_outer, "//") == 0 { 1 } else { 0 };
        if is_outer_comment == 0 && str_index_of(line, "#[deadline") >= 0 {
            // Walk forward past attr lines + whitespace to find fn decl.
            let mut np: i64 = eol + 1;
            let mut tries: i64 = 0;
            while np < slen && tries < 32 {
                let mut nle: i64 = np;
                while nle < slen && str_char_at(source, nle) != 10 { nle = nle + 1; };
                let nline: str = str_substring(source, np, nle);
                let trimmed: str = str_trim(nline);
                if str_len(trimmed) == 0 || str_index_of(trimmed, "//") == 0 || str_index_of(trimmed, "#[") == 0 || str_index_of(trimmed, "@") == 0 {
                    np = nle + 1;
                    tries = tries + 1;
                } else {
                    let info: Vec<i32> = priv_extract_fn_decl_info(nline);
                    let fn_name: str = vec_get(info, 0);
                    if str_len(fn_name) > 0 {
                        // Scan that fn body for async_await(.
                        let nd: str = str_concat("fn ", str_concat(fn_name, "("));
                        let ndl: i64 = str_len(nd);
                        let mut sp: i64 = np;
                        let mut found: i64 = 0 - 1;
                        while sp + ndl <= slen && found < 0 {
                            if str_eq_at_len(source, sp, nd, ndl) == 1 { found = sp; }
                            else { sp = sp + 1; };
                        };
                        if found >= 0 {
                            let mut bp: i64 = found + ndl;
                            while bp < slen && str_char_at(source, bp) != 123 { bp = bp + 1; };
                            if bp < slen {
                                let body_start: i64 = bp + 1;
                                bp = bp + 1;
                                let mut depth: i64 = 1;
                                while bp < slen && depth > 0 {
                                    let c: i64 = str_char_at(source, bp);
                                    if c == 123 { depth = depth + 1; };
                                    if c == 125 { depth = depth - 1; };
                                    bp = bp + 1;
                                };
                                let body: str = str_substring(source, body_start, bp - 1);
                                if str_index_of(body, "async_await(") >= 0 {
                                    let msg: str = str_concat("function `", str_concat(fn_name, "` carries `#[deadline = ...]` AND calls `async_await(...)` — the deadline checker cannot see past the actor executor boundary; the awaited task may take arbitrarily long, invalidating the deadline. Either drop the deadline, drop the await, or `#[allow_fn(RACE-007)]`"));
                                    let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                                    diag_add_ex(diags, "warning", "race", "RACE-007", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                                };
                            };
                        };
                    };
                    tries = 32;
                };
            };
        };
        p = eol + 1;
    };
    return diags;
}

// === R04-D3 Phase 1 (v0.8.299): RACE-002 emitter (unawaited spawn) ===
// RACE codes RACE-002 / 004 / 006 / 007 / 009 / 010 are registered
// in `is_known_diag_code` + tools-suite explain registry but NO
// CODE PATH EMITS THEM. `nuc explain RACE-002` overstates the
// shipped checker.
// Phase 1: light up RACE-002 ("Actor method called without await")
// via a conservative source-pattern check — body contains
// `async_spawn(` but does NOT contain `async_await(`. That's the
// fire-and-forget pattern: the spawn returns a handle that's
// never awaited, so completion ordering is not enforced.
// Severity = warning. Suppress via `#[allow_fn(RACE-002)]` for
// genuinely fire-and-forget tasks. Phase 2 lights RACE-004/006/
// 007 with deeper pattern checks.
#[manual_drop]
fn enforce_unawaited_spawn(diags: Vec<i32>, source: str) -> Vec<i32> {
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            let needle: str = str_concat("fn ", str_concat(fn_name, "("));
            let nlen: i64 = str_len(needle);
            let mut sp: i64 = 0;
            let mut found: i64 = 0 - 1;
            while sp + nlen <= slen && found < 0 {
                if str_eq_at_len(source, sp, needle, nlen) == 1 { found = sp; }
                else { sp = sp + 1; };
            };
            if found >= 0 {
                let mut q: i64 = found + nlen;
                while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
                if q < slen {
                    let body_start: i64 = q + 1;
                    q = q + 1;
                    let mut depth: i64 = 1;
                    while q < slen && depth > 0 {
                        let c: i64 = str_char_at(source, q);
                        if c == 123 { depth = depth + 1; };
                        if c == 125 { depth = depth - 1; };
                        q = q + 1;
                    };
                    let body: str = str_substring(source, body_start, q - 1);
                    let has_spawn: i64 = if str_index_of(body, "async_spawn(") >= 0 { 1 } else { 0 };
                    let has_await: i64 = if str_index_of(body, "async_await(") >= 0 { 1 } else { 0 };
                    if has_spawn == 1 && has_await == 0 {
                        let msg: str = str_concat("function `", str_concat(fn_name, "` calls `async_spawn(...)` but never `async_await(...)` — fire-and-forget breaks completion ordering and may leak the task handle; await each spawn or `#[allow_fn(RACE-002)]` if intentional"));
                        let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "warning", "race", "RACE-002", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                    };
                };
            };
        };
        p = eol + 1;
    };
    return diags;
}

// === R05-D1 Phase 1 (v0.8.307): pure fn purity enforcement in s1 ===
// `pure fn` parses but the s1 build path must run the effect checker.
// tools-suite (`nuc check`) emits EFF-001 for
// pure-with-effects, but `nuc build` ships the binary regardless.
// Phase 1: port the same body-substring scan from
// enforce_const_fn_purity (v0.8.293 NUM-009) for the `pure fn`
// surface. Direct builtin check only — transitive user-call
// closure is future work.

// Returns 0 (clean) or non-zero code naming the first effect:
//   1 = print / print_* / eprint*
//   2 = allocation (Vec::new / Box::new)
//   3 = ambient capability (ambient_random / ambient_*)
#[manual_drop]
fn pure_fn_body_effect_code(source: str, fn_name: str) -> i64 {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut found_at: i64 = 0 - 1;
    while p + nlen <= slen && found_at < 0 {
        if str_eq_at_len(source, p, needle, nlen) == 1 { found_at = p; }
        else { p = p + 1; };
    };
    if found_at < 0 { return 0; };
    let mut q: i64 = found_at + nlen;
    while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
    if q >= slen { return 0; };
    let body_start: i64 = q + 1;
    q = body_start;
    let mut depth: i64 = 1;
    let mut body_end: i64 = slen;
    while q < slen && depth > 0 {
        let c: i64 = str_char_at(source, q);
        if c == 123 { depth = depth + 1; };
        if c == 125 {
            depth = depth - 1;
            if depth == 0 { body_end = q; };
        };
        q = q + 1;
    };
    let body: str = str_substring(source, body_start, body_end);
    if str_index_of(body, "print(") >= 0 { return 1; };
    if str_index_of(body, "println(") >= 0 { return 1; };
    if str_index_of(body, "print_") >= 0 { return 1; };
    if str_index_of(body, "eprint") >= 0 { return 1; };
    if str_index_of(body, "Vec::new") >= 0 { return 2; };
    if str_index_of(body, "Box::new") >= 0 { return 2; };
    if str_index_of(body, "ambient_random") >= 0 { return 3; };
    if str_index_of(body, "scope {") >= 0 { return 4; };
    if str_index_of(body, "spawn {") >= 0 { return 4; };
    if str_index_of(body, "channel(") >= 0 { return 5; };
    return 0;
}

#[manual_drop]
fn effect_scan_fn_names(source: str) -> Vec<i32> {
    let mut names: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let trimmed: str = str_trim(line);
        let is_comment: i64 = if str_index_of(trimmed, "//") == 0 { 1 } else { 0 };
        if is_comment == 0 {
            let info: Vec<i32> = priv_extract_fn_decl_info(line);
            let fn_name: str = vec_get(info, 0);
            if str_len(fn_name) > 0 { names.push(fn_name); };
        };
        p = eol + 1;
    };
    return names;
}

#[manual_drop]
fn str_vec_contains(v: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(v) {
        if str_eq(vec_get(v, i), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn source_has_real_pure_fn_decl(source: str) -> i64 {
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let trimmed: str = str_trim(line);
        if str_index_of(trimmed, "//") != 0 {
            let compact: str = strip_spaces(line);
            let clen: i64 = str_len(compact);
            if clen >= 6 && str_eq(str_substring(compact, 0, 6), "purefn") == 1 { return 1; };
            if clen >= 9 && str_eq(str_substring(compact, 0, 9), "pubpurefn") == 1 { return 1; };
        };
        p = eol + 1;
    };
    return 0;
}

#[manual_drop]
fn first_effectful_user_call(body: str, effectful: Vec<i32>, self_name: str) -> str {
    let mut i: i64 = 0;
    while i < vec_len(effectful) {
        let callee: str = vec_get(effectful, i);
        if str_eq(callee, self_name) == 0 {
            let pat: str = str_concat(callee, "(");
            if str_contains(body, pat) == 1 { return callee; };
        };
        i = i + 1;
    };
    return "";
}

#[manual_drop]
fn collect_transitive_effectful_fns(source: str) -> Vec<i32> {
    let names: Vec<i32> = effect_scan_fn_names(source);
    let mut effectful: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(names) {
        let fn_name: str = vec_get(names, i);
        if pure_fn_body_effect_code(source, fn_name) > 0 { effectful.push(fn_name); };
        i = i + 1;
    };
    let mut pass: i64 = 0;
    let mut changed: i64 = 1;
    while pass < 8 && changed == 1 {
        changed = 0;
        i = 0;
        while i < vec_len(names) {
            let fn_name2: str = vec_get(names, i);
            if str_vec_contains(effectful, fn_name2) == 0 {
                let body_raw: str = source_fn_body_for_scan(source, fn_name2);
                if str_len(body_raw) > 0 {
                    let body: str = strip_strings_and_line_comments(body_raw);
                    let callee: str = first_effectful_user_call(body, effectful, fn_name2);
                    if str_len(callee) > 0 {
                        effectful.push(fn_name2);
                        changed = 1;
                    };
                };
            };
            i = i + 1;
        };
        pass = pass + 1;
    };
    return effectful;
}

// Walks the source line-by-line. When a line declares `pure fn
// <name>(`, scans the body for effects and emits EFF-001.
#[manual_drop]
fn enforce_pure_fn_purity(diags: Vec<i32>, source: str) -> Vec<i32> {
    if source_has_real_pure_fn_decl(source) == 0 { return diags; };
    let transitive_effectful: Vec<i32> = collect_transitive_effectful_fns(source);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let trimmed: str = str_trim(line);
        let is_comment: i64 = if str_index_of(trimmed, "//") == 0 { 1 } else { 0 };
        if is_comment == 0 && str_index_of(line, "pure fn ") >= 0 {
            // Extract fn name. Pattern: optional `pub`, then `pure fn <name>(`.
            let pos: i64 = str_index_of(line, "pure fn ");
            let after: i64 = pos + 8; // len("pure fn ")
            let llen: i64 = str_len(line);
            let mut np: i64 = after;
            while np < llen && (str_char_at(line, np) == 32 || str_char_at(line, np) == 9) { np = np + 1; };
            let mut ne: i64 = np;
            while ne < llen && (is_alnum(str_char_at(line, ne)) == 1 || str_char_at(line, ne) == 95) { ne = ne + 1; };
            if ne > np {
                let fn_name: str = str_substring(line, np, ne);
                let code: i64 = pure_fn_body_effect_code(source, fn_name);
                if code > 0 {
                    let kind: str = if code == 1 { "calls print() / println() — I/O is not pure" }
                        else if code == 2 { "allocates (Vec::new / Box::new) — heap allocation is not pure" }
                        else if code == 3 { "uses ambient capability (ambient_*) — non-deterministic input is not pure" }
                        else if code == 4 { "uses structured scheduling (scope/spawn) — scheduler effects are not pure" }
                        else { "uses channel construction — sync.channel effects are not pure" };
                    let msg: str = str_concat("`pure fn ", str_concat(fn_name, str_concat("` ", str_concat(kind, "; remove `pure` qualifier or move the side effect to a normal fn"))));
                    let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                    diag_add_ex(diags, "error", "effect", "EFF-001", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                } else {
                    let body_raw: str = source_fn_body_for_scan(source, fn_name);
                    if str_len(body_raw) > 0 {
                        let body: str = strip_strings_and_line_comments(body_raw);
                        let callee: str = first_effectful_user_call(body, transitive_effectful, fn_name);
                        if str_len(callee) > 0 {
                            let msg_trans: str = str_concat("`pure fn ", str_concat(fn_name, str_concat("` calls `", str_concat(callee, "()` which has transitive side effects; remove `pure` qualifier or make the call chain effect-free"))));
                            let lc2: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                            diag_add_ex(diags, "error", "effect", "EFF-001", msg_trans, fn_name, vec_get(lc2, 0), vec_get(lc2, 1), "");
                        };
                    };
                };
            };
        };
        p = eol + 1;
    };
    return diags;
}

// === R10-D2 Phase 1.5 (v0.8.298): HeapInLoop PERF-3 detection ===
// PERF-2 catches alloc / I/O at the @hot fn level.
// HeapInLoop (PERF-3) catches `Vec::new` / `Box::new` INSIDE a
// `while` or `loop {}` block — a per-iteration alloc that ships
// silently is the dominant perf bug class for adopters.
// Scan ANY fn (not just @hot — the perf hit hurts everywhere).
// Track loop-depth as we walk the body: enter on `while ... {`
// or `loop {`, exit on the matching `}`. When we see an alloc
// site WHILE depth > 0, emit warning[PERF-3].
// Severity = warning. Suppress with `#[allow_fn(PERF-3)]` when
// the alloc is intentional (e.g. amortized via reserve()).
// RFC-0063 Phase 1.5: bridge syntactic-Phase-1 toward
// semantic-Phase-2b. Returns the first known-impure stdlib helper
// found in `body`, suffixed with the reason — or "" if none. Catches
// the soundness gap where a pure fn calls a helper that allocates or
// does IO via a non-constructor name (vec_push, str_concat, etc.).
// The list is curated to high-frequency callees from
// docs/rfcs/helper_manifest.toml (effects != []). Manual sync with
// the manifest until full call-graph effect propagation lands
// (Phase 2.0 parser unification + Phase 2.1+ generic monomorphization
// give us the substrate to do this properly across modules).
// Conservatism note: only flags helpers whose effect is unambiguous
// from the name. Read-only accessors (vec_get, vec_len, hashmap_get,
// str_eq, str_len, str_starts_with, ...) are NOT flagged — they're
// classified as pure in PATTERN_OVERRIDES.
#[manual_drop]
fn priv_first_impure_callee(body: str) -> str {
    // --- Allocation: Vec mutators / producers ---
    if str_index_of(body, "vec_push(") >= 0 { return "vec_push (allocates: may grow Vec)"; };
    if str_index_of(body, "vec_insert_at(") >= 0 { return "vec_insert_at (allocates / mutates)"; };
    if str_index_of(body, "vec_remove_at(") >= 0 { return "vec_remove_at (mutates)"; };
    if str_index_of(body, "vec_extend(") >= 0 { return "vec_extend (allocates)"; };
    if str_index_of(body, "vec_clone(") >= 0 { return "vec_clone (allocates)"; };
    if str_index_of(body, "vec_clear(") >= 0 { return "vec_clear (mutates)"; };
    if str_index_of(body, "vec_sort(") >= 0 { return "vec_sort (mutates)"; };
    if str_index_of(body, "vec_sort_i64(") >= 0 { return "vec_sort_i64 (mutates)"; };
    if str_index_of(body, "vec_reverse(") >= 0 { return "vec_reverse (mutates)"; };
    if str_index_of(body, "vec_shuffle(") >= 0 { return "vec_shuffle (mutates + uses RNG capability)"; };
    if str_index_of(body, "vec_filter(") >= 0 { return "vec_filter (allocates new Vec)"; };
    if str_index_of(body, "vec_map(") >= 0 { return "vec_map (allocates new Vec)"; };
    if str_index_of(body, "vec_swap(") >= 0 { return "vec_swap (mutates)"; };
    // --- Allocation: HashMap / Collection mutators / producers ---
    if str_index_of(body, "hashmap_new(") >= 0 { return "hashmap_new (allocates)"; };
    if str_index_of(body, "hashmap_insert(") >= 0 { return "hashmap_insert (allocates / mutates)"; };
    if str_index_of(body, "hashmap_remove(") >= 0 { return "hashmap_remove (mutates)"; };
    if str_index_of(body, "hashmap_clone(") >= 0 { return "hashmap_clone (allocates)"; };
    if str_index_of(body, "hashmap_clear(") >= 0 { return "hashmap_clear (mutates)"; };
    if str_index_of(body, "hashmap_keys(") >= 0 { return "hashmap_keys (allocates a Vec)"; };
    if str_index_of(body, "hashmap_values(") >= 0 { return "hashmap_values (allocates a Vec)"; };
    if str_index_of(body, "hashmap_merge(") >= 0 { return "hashmap_merge (mutates)"; };
    // --- Allocation: String producers ---
    if str_index_of(body, "str_concat(") >= 0 { return "str_concat (allocates new string)"; };
    if str_index_of(body, "str_substring(") >= 0 { return "str_substring (allocates new string)"; };
    if str_index_of(body, "str_lines(") >= 0 { return "str_lines (allocates a Vec)"; };
    if str_index_of(body, "str_split(") >= 0 { return "str_split (allocates a Vec)"; };
    if str_index_of(body, "str_chars(") >= 0 { return "str_chars (allocates a Vec)"; };
    if str_index_of(body, "str_to_lower(") >= 0 { return "str_to_lower (allocates)"; };
    if str_index_of(body, "str_to_upper(") >= 0 { return "str_to_upper (allocates)"; };
    if str_index_of(body, "str_trim(") >= 0 { return "str_trim (allocates)"; };
    if str_index_of(body, "str_pad_left(") >= 0 { return "str_pad_left (allocates)"; };
    if str_index_of(body, "str_pad_right(") >= 0 { return "str_pad_right (allocates)"; };
    if str_index_of(body, "str_replace(") >= 0 { return "str_replace (allocates)"; };
    if str_index_of(body, "str_join(") >= 0 { return "str_join (allocates)"; };
    if str_index_of(body, "str_reverse(") >= 0 { return "str_reverse (allocates)"; };
    if str_index_of(body, "int_to_str(") >= 0 { return "int_to_str (allocates new string)"; };
    if str_index_of(body, "int_to_hex(") >= 0 { return "int_to_hex (allocates new string)"; };
    if str_index_of(body, "f64_to_str(") >= 0 { return "f64_to_str (allocates new string)"; };
    if str_index_of(body, "bool_to_str(") >= 0 { return "bool_to_str (allocates new string)"; };
    if str_index_of(body, "sb_new(") >= 0 { return "sb_new (allocates StringBuilder)"; };
    if str_index_of(body, "sb_append(") >= 0 { return "sb_append (mutates / allocates)"; };
    // --- IO: read side ---
    if str_index_of(body, "file_read_string(") >= 0 { return "file_read_string (IO + allocates)"; };
    if str_index_of(body, "file_read_string_or_panic(") >= 0 { return "file_read_string_or_panic (IO + allocates + panics)"; };
    if str_index_of(body, "getenv(") >= 0 { return "getenv (IO + allocates)"; };
    if str_index_of(body, "getcwd(") >= 0 { return "getcwd (IO + allocates)"; };
    // --- IO: write side ---
    if str_index_of(body, "file_write_string(") >= 0 { return "file_write_string (IO)"; };
    if str_index_of(body, "file_append_string(") >= 0 { return "file_append_string (IO)"; };
    if str_index_of(body, "system(") >= 0 { return "system (IO + spawns process)"; };
    if str_index_of(body, "eprint(") >= 0 { return "eprint (IO)"; };
    if str_index_of(body, "eprintln(") >= 0 { return "eprintln (IO)"; };
    if str_index_of(body, "putchar(") >= 0 { return "putchar (IO)"; };
    // --- Time: clock effect ---
    if str_index_of(body, "time_now(") >= 0 { return "time_now (clock capability)"; };
    if str_index_of(body, "time_iso_now(") >= 0 { return "time_iso_now (clock capability)"; };
    if str_index_of(body, "now_monotonic(") >= 0 { return "now_monotonic (clock capability)"; };
    // --- Random: non-deterministic ---
    if str_index_of(body, "random_int(") >= 0 { return "random_int (non-deterministic input)"; };
    if str_index_of(body, "random_uniform(") >= 0 { return "random_uniform (non-deterministic input)"; };
    if str_index_of(body, "random_normal(") >= 0 { return "random_normal (non-deterministic input)"; };
    if str_index_of(body, "rng_int(") >= 0 { return "rng_int (RNG capability)"; };
    // --- ADT: panicking accessors ---
    if str_index_of(body, "option_unwrap(") >= 0 { return "option_unwrap (panics on None)"; };
    if str_index_of(body, "option_expect(") >= 0 { return "option_expect (panics on None)"; };
    if str_index_of(body, "result_unwrap(") >= 0 { return "result_unwrap (panics on Err)"; };
    if str_index_of(body, "result_expect(") >= 0 { return "result_expect (panics on Err)"; };
    if str_index_of(body, "result_unwrap_err(") >= 0 { return "result_unwrap_err (panics on Ok)"; };
    return "";
}

#[manual_drop]
fn detect_heap_in_loop_in_body(body: str) -> i64 {
    // Returns 1 if any `Vec::new(` / `Box::new(` is found inside
    // a while/loop block. State machine:
    //   loop_depth: incremented when we just consumed `while`/`loop`
    //               and then see `{`; decremented when we close.
    let blen: i64 = str_len(body);
    let mut bp: i64 = 0;
    let mut loop_depth: i64 = 0;
    let mut depth_stack: Vec<i32> = Vec::new();
    let mut pending_loop: i64 = 0;
    while bp < blen {
        let c: i64 = str_char_at(body, bp);
        if c == 119 && bp + 5 <= blen
            && str_char_at(body, bp + 1) == 104 && str_char_at(body, bp + 2) == 105
            && str_char_at(body, bp + 3) == 108 && str_char_at(body, bp + 4) == 101 {
            let prev: i64 = if bp > 0 { str_char_at(body, bp - 1) } else { 32 };
            let next: i64 = if bp + 5 < blen { str_char_at(body, bp + 5) } else { 32 };
            if (is_alnum(prev) == 0 && prev != 95) && (is_alnum(next) == 0 && next != 95) {
                pending_loop = 1;
            };
        };
        if c == 108 && bp + 4 <= blen
            && str_char_at(body, bp + 1) == 111 && str_char_at(body, bp + 2) == 111
            && str_char_at(body, bp + 3) == 112 {
            let prev_l: i64 = if bp > 0 { str_char_at(body, bp - 1) } else { 32 };
            let next_l: i64 = if bp + 4 < blen { str_char_at(body, bp + 4) } else { 32 };
            if (is_alnum(prev_l) == 0 && prev_l != 95) && (is_alnum(next_l) == 0 && next_l != 95) {
                pending_loop = 1;
            };
        };
        if c == 123 {
            depth_stack.push(pending_loop);
            if pending_loop == 1 { loop_depth = loop_depth + 1; };
            pending_loop = 0;
        };
        if c == 125 {
            let dlen: i64 = vec_len(depth_stack);
            if dlen > 0 {
                let was_loop: i64 = vec_get(depth_stack, dlen - 1);
                depth_stack.pop();
                if was_loop == 1 && loop_depth > 0 { loop_depth = loop_depth - 1; };
            };
        };
        if loop_depth > 0 && bp + 8 <= blen {
            if str_eq_at_len(body, bp, "Vec::new", 8) == 1 { return 1; };
        };
        if loop_depth > 0 && bp + 8 <= blen {
            if str_eq_at_len(body, bp, "Box::new", 8) == 1 { return 1; };
        };
        bp = bp + 1;
    };
    return 0;
}

#[manual_drop]
fn enforce_heap_in_loop(diags: Vec<i32>, source: str) -> Vec<i32> {
    // Walk every fn declaration in the source and check its body.
    // This is broad — the warning fires anywhere, not just @hot —
    // but per-iteration heap alloc is a portable perf bug.
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let fn_name: str = vec_get(info, 0);
        if str_len(fn_name) > 0 {
            // Find the body (matching `{...}` after the line).
            let needle: str = str_concat("fn ", str_concat(fn_name, "("));
            let nlen: i64 = str_len(needle);
            let mut sp: i64 = 0;
            let mut found: i64 = 0 - 1;
            while sp + nlen <= slen && found < 0 {
                if str_eq_at_len(source, sp, needle, nlen) == 1 { found = sp; }
                else { sp = sp + 1; };
            };
            if found >= 0 {
                let mut q: i64 = found + nlen;
                while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
                if q < slen {
                    let body_start: i64 = q + 1;
                    q = q + 1;
                    let mut depth: i64 = 1;
                    while q < slen && depth > 0 {
                        let c: i64 = str_char_at(source, q);
                        if c == 123 { depth = depth + 1; };
                        if c == 125 { depth = depth - 1; };
                        q = q + 1;
                    };
                    let body: str = str_substring(source, body_start, q - 1);
                    if detect_heap_in_loop_in_body(body) == 1 {
                        let msg: str = str_concat("function `", str_concat(fn_name, "` allocates (Vec::new / Box::new) inside a `while` or `loop` block — per-iteration heap alloc is a perf hazard; reserve outside the loop, use a stack-allocated buffer, or `#[allow_fn(PERF-3)]` if intentional"));
                        let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                        diag_add_ex(diags, "warning", "perf", "PERF-3", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                    };
                };
            };
        };
        p = eol + 1;
    };
    return diags;
}

// === R09-D4 Phase 1 (v0.8.293): @const_fn purity enforcement ===
// `@const_fn` used to be advisory only. A `@const_fn` containing `print()`, `Vec::new()`,
// `panic()`, etc. compiled cleanly and ran the side effects.
// Adopters relying on @const_fn for compile-time evaluation
// guarantees got nothing.
// User pushback after v0.8.291/.292 ("can this be fixed?") drove
// this to a real implementation. This is fail-closed: a
// `@const_fn` body containing any known-effectful pattern fails
// build with `error[NUM-009]`.
// Phase 2 work (deferred): actually evaluate the const_fn body
// at compile time and substitute the result. Today's pass just
// rejects effectful bodies.

// Find the body of `fn <name>(...)` and scan for effectful
// substrings. Returns 0 if pure (or not found), or a non-zero
// code naming the first effect found:
//   1 = print / print_* / eprint*
//   2 = allocation (Vec::new / Box::new)
//   3 = panic / unwrap / expect / assert
//   4 = ambient capability (ambient_random / ambient_*)
#[manual_drop]
fn const_fn_body_effect_code(source: str, fn_name: str) -> i64 {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut found_at: i64 = 0 - 1;
    while p + nlen <= slen && found_at < 0 {
        if str_eq_at_len(source, p, needle, nlen) == 1 { found_at = p; }
        else { p = p + 1; };
    };
    if found_at < 0 { return 0; };
    let mut q: i64 = found_at + nlen;
    while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
    if q >= slen { return 0; };
    let body_start: i64 = q + 1;
    q = body_start;
    let mut depth: i64 = 1;
    let mut body_end: i64 = slen;
    while q < slen && depth > 0 {
        let c: i64 = str_char_at(source, q);
        if c == 123 { depth = depth + 1; };
        if c == 125 {
            depth = depth - 1;
            if depth == 0 { body_end = q; };
        };
        q = q + 1;
    };
    let body: str = str_substring(source, body_start, body_end);
    if str_index_of(body, "print(") >= 0 { return 1; };
    if str_index_of(body, "println(") >= 0 { return 1; };
    if str_index_of(body, "print_") >= 0 { return 1; };
    if str_index_of(body, "eprint") >= 0 { return 1; };
    if str_index_of(body, "Vec::new") >= 0 { return 2; };
    if str_index_of(body, "Box::new") >= 0 { return 2; };
    if str_index_of(body, "panic(") >= 0 { return 3; };
    if str_index_of(body, ".unwrap(") >= 0 { return 3; };
    if str_index_of(body, ".expect(") >= 0 { return 3; };
    if str_index_of(body, "assert_eq(") >= 0 { return 3; };
    if str_index_of(body, "assert_ne(") >= 0 { return 3; };
    if str_index_of(body, "ambient_random") >= 0 { return 4; };
    return 0;
}

#[manual_drop]
fn enforce_const_fn_purity(diags: Vec<i32>, source: str) -> Vec<i32> {
    // Walk every `@const_fn` annotated fn name (semicolon-separated
    // string from attribute_audit_fn_names) and reject effectful
    // bodies with NUM-009.
    let needle: str = str_concat("@const_", "fn");
    let names: str = attribute_audit_fn_names(source, needle);
    let nlen: i64 = str_len(names);
    if nlen == 0 { return diags; };
    let mut start: i64 = 0;
    let mut q: i64 = 0;
    while q <= nlen {
        let at_end: i64 = if q == nlen { 1 } else { 0 };
        let is_sep: i64 = if at_end == 0 && str_char_at(names, q) == 59 { 1 } else { 0 };
        if at_end == 1 || is_sep == 1 {
            let raw: str = str_substring(names, start, q);
            let fn_name: str = str_trim(raw);
            if str_len(fn_name) > 0 {
                let code: i64 = const_fn_body_effect_code(source, fn_name);
                if code > 0 {
                    let kind: str = if code == 1 { "calls print() — I/O is not const" }
                        else if code == 2 { "calls Vec::new()/Box::new() — heap allocation is not const" }
                        else if code == 3 { "may panic (panic/unwrap/expect/assert) — control-flow trap is not const" }
                        else { "uses ambient capability (ambient_*) — non-deterministic input is not const" };
                    let msg: str = str_concat("`@const_fn` function `", str_concat(fn_name, str_concat("` ", str_concat(kind, "; remove the @const_fn annotation, or move the effectful work to a normal fn"))));
                    let lc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
                    diag_add_ex(diags, "error", "num", "NUM-009", msg, fn_name, vec_get(lc, 0), vec_get(lc, 1), "");
                };
            };
            start = q + 2;
            q = q + 2;
        } else {
            q = q + 1;
        };
    };
    return diags;
}

#[manual_drop]
fn enforce_static_wcet(diags: Vec<i32>, source: str) -> Vec<i32> {
    // For each #[deadline = N] fn (post-resolver shape — inner +
    // outer wrapper pair from T3.1), estimate WCET on the inner
    // body and warn if the estimate exceeds the budget.
    let entries: Vec<i32> = wcet_collect_deadline_fns(source);
    let n: i64 = vec_len(entries);
    let mut i: i64 = 0;
    while i + 1 < n {
        let inner_name: str = vec_get(entries, i);
        let limit_us: i64 = vec_get(entries, i + 1);
        let units: i64 = wcet_estimate_fn_units(source, inner_name);
        let estimated_us: i64 = (units + 9) / 10;
        if estimated_us > limit_us {
            let msg: str = str_concat("heuristic deadline estimate ", str_concat(str_from_int(estimated_us), str_concat(" us (", str_concat(str_from_int(units), str_concat(" units x 0.1 us) exceeds #[deadline = ", str_concat(str_from_int(limit_us), str_concat(" us] (RT-004 is a heuristic, NOT certified WCET; no callee/ISA/cache modeling; use #[allow(RT-004)] file-wide or #[allow_fn(RT-004)] per-fn when the estimate is wrong; default loop multiplier 100x)", "")))))));
            diag_add_fn_site(diags, "warning", "rt", "RT-004", msg, source, inner_name);
        };
        i = i + 2;
    };
    return diags;
}

// === T3.5 (v0.3.3): RT-007 cross-check — #[deadline] without #[no_alloc] / #[no_panic] ===
// Allocations and panics are non-deterministic and can blow past
// any fixed deadline budget. The runtime deadline check (RT-004)
// catches overruns AFTER the fact. RT-007 nudges authors to also
// declare intent: at least one of #[no_alloc] or #[no_panic]
// should accompany #[deadline] so the compiler can statically
// rule out the most common deadline-busters.

#[manual_drop]
fn enforce_deadline_safety(diags: Vec<i32>, source: str) -> Vec<i32> {
    let dl_entries: Vec<i32> = wcet_collect_deadline_fns(source);
    let no_alloc_fns: Vec<i32> = collect_no_alloc_fns(source);
    let no_panic_fns: Vec<i32> = collect_no_panic_fns(source);
    let n: i64 = vec_len(dl_entries);
    let mut i: i64 = 0;
    while i + 1 < n {
        let inner_name: str = vec_get(dl_entries, i);
        let mut has_no_alloc: i64 = 0;
        let mut j: i64 = 0;
        let na_n: i64 = vec_len(no_alloc_fns);
        while j < na_n && has_no_alloc == 0 {
            if str_eq(vec_get(no_alloc_fns, j), inner_name) == 1 { has_no_alloc = 1; };
            j = j + 1;
        };
        let mut has_no_panic: i64 = 0;
        j = 0;
        let np_n: i64 = vec_len(no_panic_fns);
        while j < np_n && has_no_panic == 0 {
            if str_eq(vec_get(no_panic_fns, j), inner_name) == 1 { has_no_panic = 1; };
            j = j + 1;
        };
        if has_no_alloc == 0 && has_no_panic == 0 {
            let msg: str = str_concat("'", str_concat(inner_name, "' has #[deadline] but neither #[no_alloc] nor #[no_panic]; allocations or panics can break WCET determinism (use #[allow(RT-007)] file-wide, or #[allow_fn(RT-007)] per-fn)"));
            diag_add_fn_site(diags, "warning", "rt", "RT-007", msg, source, inner_name);
        };
        i = i + 2;
    };
    return diags;
}

#[manual_drop]
fn byte_to_line(source: str, byte_off: i64) -> i64 {
    let slen: i64 = str_len(source);
    let mut line: i64 = 1;
    let mut i: i64 = 0;
    let limit: i64 = byte_off;
    if limit > slen { return 0; };
    while i < limit {
        if str_char_at(source, i) == 10 { line = line + 1; };
        i = i + 1;
    };
    return line;
}

// RFC-0020 phase 1: LineMap — precomputed line-start byte offsets.
// linemap_build returns Vec<i32> where item[k] = byte offset of line (k+1)'s
// first character (line 1 starts at offset 0). Lookup is O(log n) via
// binary search; pair with linemap_col for column number.
#[manual_drop]
fn linemap_build(source: str) -> Vec<i32> {
    let mut starts: Vec<i32> = Vec::new();
    starts.push(0);  // line 1 starts at offset 0
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(source, i) == 10 { starts.push(i + 1); };
        i = i + 1;
    };
    return starts;
}

#[manual_drop]
fn linemap_line(starts: Vec<i32>, byte_off: i64) -> i64 {
    let n: i64 = vec_len(starts);
    if n == 0 { return 1; };
    let mut lo: i64 = 0;
    let mut hi: i64 = n - 1;
    // Find the largest index `k` such that starts[k] <= byte_off.
    // Returned line number is k + 1 (1-indexed).
    while lo < hi {
        let mid: i64 = (lo + hi + 1) / 2;
        if vec_get(starts, mid) <= byte_off { lo = mid; }
        else { hi = mid - 1; };
    };
    return lo + 1;
}

#[manual_drop]
fn linemap_col(starts: Vec<i32>, byte_off: i64) -> i64 {
    let line: i64 = linemap_line(starts, byte_off);
    let line_start: i64 = vec_get(starts, line - 1);
    return byte_off - line_start + 1;
}

#[manual_drop]
fn linemap_line_count(starts: Vec<i32>) -> i64 { return vec_len(starts); }

#[manual_drop]
fn find_linecol_in_source(source: str, fn_name: str, var_name: str) -> Vec<i32> {
    let slen: i64 = str_len(source);
    let fnlen: i64 = str_len(fn_name);
    let vlen: i64 = str_len(var_name);
    let mut out: Vec<i32> = Vec::new();
    if fnlen == 0 || vlen == 0 { out.push(0); out.push(0); return out; };
    let target: str = str_concat("fn ", fn_name);
    let tlen: i64 = str_len(target);
    let mut i: i64 = 0;
    let mut fn_start: i64 = 0 - 1;
    while i < slen - tlen {
        if str_eq_at_len(source, i, target, tlen) == 1 { fn_start = i; i = slen; };
        i = i + 1;
    };
    if fn_start < 0 { out.push(0); out.push(0); return out; };
    let mut line: i64 = byte_to_line(source, fn_start);
    let mut col: i64 = 1;
    i = fn_start;
    while i < slen - vlen {
        if str_eq_at_len(source, i, var_name, vlen) == 1 {
            out.push(line);
            out.push(col);
            return out;
        };
        if str_char_at(source, i) == 10 { line = line + 1; col = 1; }
        else { col = col + 1; };
        i = i + 1;
    };
    out.push(byte_to_line(source, fn_start));
    out.push(1);
    return out;
}
#[manual_drop]
fn find_in_source(source: str, fn_name: str, var_name: str) -> i64 {
    return vec_get(find_linecol_in_source(source, fn_name, var_name), 0);
}

#[manual_drop]
fn find_column_in_source(source: str, fn_name: str, var_name: str) -> i64 {
    return vec_get(find_linecol_in_source(source, fn_name, var_name), 1);
}

// RFC-0020 phase 1: Rust-style diagnostic rendering.
// Detects TTY via NO_COLOR env; ANSI when colored, plain otherwise.
#[manual_drop]
fn diag_use_color() -> i64 {
    if str_len(getenv("NO_COLOR")) > 0 { return 0; };
    if str_len(getenv("NUCLEOR_NO_COLOR")) > 0 { return 0; };
    if isatty_stdout() == 0 { return 0; };
    return 1;
}

#[manual_drop]
fn ansi_red(s: str) -> str {
    if diag_use_color() == 0 { return s; };
    let esc: str = chr(27);
    return str_concat(esc, str_concat("[31m", str_concat(s, str_concat(esc, "[0m"))));
}

#[manual_drop]
fn ansi_yellow(s: str) -> str {
    if diag_use_color() == 0 { return s; };
    let esc: str = chr(27);
    return str_concat(esc, str_concat("[33m", str_concat(s, str_concat(esc, "[0m"))));
}

#[manual_drop]
fn ansi_dim(s: str) -> str {
    if diag_use_color() == 0 { return s; };
    let esc: str = chr(27);
    return str_concat(esc, str_concat("[2m", str_concat(s, str_concat(esc, "[0m"))));
}

#[manual_drop]
fn ansi_bold(s: str) -> str {
    if diag_use_color() == 0 { return s; };
    let esc: str = chr(27);
    return str_concat(esc, str_concat("[1m", str_concat(s, str_concat(esc, "[0m"))));
}

// RFC-0020 phase 2: JSON renderer for IDE / CI consumption.
// Honors NUCLEOR_DIAG_JSON env var (when set, all diags emit as one JSON
// array of objects). Stable schema for tool integration:
//   { "code": "OWN-008", "severity": "error", "message": "...",
//     "fn": "main", "line": 14, "col": 5,
//     "child": "moved here", "child_line": 13,
//     "suggestion": "consider `let mut x` here" }
#[manual_drop]
fn diag_use_json() -> i64 {
    if str_len(getenv("NUCLEOR_DIAG_JSON")) > 0 { return 1; };
    return 0;
}

#[manual_drop]
fn diag_json_escape(s: str) -> str {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 34 { sb_append(sb, "\\\""); }
        else if c == 92 { sb_append(sb, "\\\\"); }
        else if c == 10 { sb_append(sb, "\\n"); }
        else if c == 13 { sb_append(sb, "\\r"); }
        else if c == 9 { sb_append(sb, "\\t"); }
        else { sb_append_char_at(sb, s, i); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn diag_emit_json(diags: Vec<i32>) -> i64 {
    let cnt: i64 = vec_len(diags);
    print("[");
    let mut i: i64 = 0;
    while i < cnt {
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let col: i64 = vec_get(d, 6);
        let suggestion: str = vec_get(d, 8);
        let child_msg: str = vec_get(d, 10);
        let child_line: i64 = vec_get(d, 11);
        let mut sb: i64 = sb_new();
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"code\":\"");
        sb_append(sb, diag_json_escape(code));
        sb_append(sb, "\",\"severity\":\"");
        sb_append(sb, severity);
        sb_append(sb, "\",\"message\":\"");
        sb_append(sb, diag_json_escape(message));
        sb_append(sb, "\"");
        if str_len(fn_name) > 0 {
            sb_append(sb, ",\"fn\":\"");
            sb_append(sb, diag_json_escape(fn_name));
            sb_append(sb, "\"");
        };
        if line > 0 {
            sb_append(sb, ",\"line\":");
            sb_append(sb, str_from_int(line));
        };
        if col > 0 {
            sb_append(sb, ",\"col\":");
            sb_append(sb, str_from_int(col));
        };
        if str_len(child_msg) > 0 {
            sb_append(sb, ",\"child\":\"");
            sb_append(sb, diag_json_escape(child_msg));
            sb_append(sb, "\"");
        };
        if child_line > 0 {
            sb_append(sb, ",\"child_line\":");
            sb_append(sb, str_from_int(child_line));
        };
        if str_len(suggestion) > 0 {
            sb_append(sb, ",\"suggestion\":\"");
            sb_append(sb, diag_json_escape(suggestion));
            sb_append(sb, "\"");
        };
        sb_append(sb, "}");
        print(sb_to_str(sb));
        i = i + 1;
    };
    print("]");
    return cnt;
}

// T1.8 (v0.2.335): extract a single 1-based line from a source
// string. Returns "" if line is out of range. Memory-safe: walks
// the source by index without allocating a substring per
// candidate.
#[manual_drop]
fn diag_extract_line(source: str, line_no: i64) -> str {
    if line_no <= 0 || str_len(source) == 0 { return ""; };
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut cur_line: i64 = 1;
    let mut line_start: i64 = 0;
    while p < slen && cur_line < line_no {
        if str_char_at(source, p) == 10 { cur_line = cur_line + 1; line_start = p + 1; };
        p = p + 1;
    };
    if cur_line != line_no { return ""; };
    let mut line_end: i64 = line_start;
    while line_end < slen && str_char_at(source, line_end) != 10 { line_end = line_end + 1; };
    return str_substring(source, line_start, line_end);
}

// T1.8: build a caret line "    ^^^^^^" pointing at column `col`
// (1-based). Length defaults to 1 (single caret) for now; future
// work can pass a token span.
#[manual_drop]
fn diag_caret_line(col: i64) -> str {
    if col <= 0 { return ""; };
    let mut sb: i64 = sb_new();
    let mut i: i64 = 1;
    while i < col { sb_append(sb, " "); i = i + 1; };
    sb_append(sb, "^");
    return sb_to_str(sb);
}

#[manual_drop]
fn diag_emit_text(diags: Vec<i32>) -> i64 {
    return diag_emit_text_with_source(diags, "");
}

// T1.8: source-aware text emit. Renders Rust-style frame:
//   error[CODE]: message
//     --> fn:line:col
//     |
//   42 |     let x: u8 = 256;
//      |                 ^
//     = help: ...
#[manual_drop]
fn diag_emit_text_with_source(diags: Vec<i32>, source: str) -> i64 {
    let cnt: i64 = vec_len(diags);
    let mut i: i64 = 0;
    while i < cnt {
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let col: i64 = vec_get(d, 6);
        let suggestion: str = vec_get(d, 8);
        let child_msg: str = vec_get(d, 10);
        let child_line: i64 = vec_get(d, 11);

        // First line: severity[CODE]: message
        let mut head: i64 = sb_new();
        let label: str = if str_eq(severity, "error") == 1 { ansi_red("error") } else { ansi_yellow("warning") };
        sb_append(head, label);
        sb_append(head, ansi_bold(str_concat("[", str_concat(code, "]"))));
        sb_append(head, ": ");
        sb_append(head, message);
        print(sb_to_str(head));

        // Second line: --> file:line:col  (file currently unknown; emit fn:line:col)
        if line > 0 {
            let mut loc: i64 = sb_new();
            sb_append(loc, "  ");
            sb_append(loc, ansi_dim("-->"));
            sb_append(loc, " ");
            if str_len(fn_name) > 0 {
                sb_append(loc, ansi_dim("fn "));
                sb_append(loc, fn_name);
                sb_append(loc, ansi_dim("@"));
            };
            sb_append(loc, ansi_dim(str_concat("line ", str_from_int(line))));
            if col > 0 {
                sb_append(loc, ansi_dim(str_concat(":", str_from_int(col))));
            };
            print(sb_to_str(loc));
        };

        // T1.8: source snippet + caret frame, when source is available.
        // Format (Rust-style):
        //     |
        //  42 | let x: u8 = 256;
        //     |             ^
        if str_len(source) > 0 && line > 0 {
            let snippet: str = diag_extract_line(source, line);
            if str_len(snippet) > 0 {
                let line_str: str = str_from_int(line);
                let gutter_w: i64 = str_len(line_str);
                // Pad line number gutter + vertical bar on blank row.
                let mut blank: i64 = sb_new();
                let mut pi: i64 = 0;
                while pi < gutter_w { sb_append(blank, " "); pi = pi + 1; };
                sb_append(blank, " ");
                sb_append(blank, ansi_dim("|"));
                print(sb_to_str(blank));
                // Source line row.
                let mut src_row: i64 = sb_new();
                sb_append(src_row, ansi_dim(line_str));
                sb_append(src_row, " ");
                sb_append(src_row, ansi_dim("|"));
                sb_append(src_row, " ");
                sb_append(src_row, snippet);
                print(sb_to_str(src_row));
                // Caret row.
                if col > 0 {
                    let mut caret_row: i64 = sb_new();
                    pi = 0;
                    while pi < gutter_w { sb_append(caret_row, " "); pi = pi + 1; };
                    sb_append(caret_row, " ");
                    sb_append(caret_row, ansi_dim("|"));
                    sb_append(caret_row, " ");
                    sb_append(caret_row, ansi_red(diag_caret_line(col)));
                    print(sb_to_str(caret_row));
                };
            };
        };

        // Child note line ("moved here", "borrowed here", etc.)
        if str_len(child_msg) > 0 && child_line > 0 {
            let mut child: i64 = sb_new();
            sb_append(child, "  ");
            sb_append(child, ansi_dim("note: "));
            sb_append(child, child_msg);
            sb_append(child, ansi_dim(str_concat(" (line ", str_concat(str_from_int(child_line), ")"))));
            print(sb_to_str(child));
        };

        // Suggestion / help line
        if str_len(suggestion) > 0 {
            let mut help: i64 = sb_new();
            sb_append(help, "  ");
            sb_append(help, ansi_dim("help: "));
            sb_append(help, suggestion);
            print(sb_to_str(help));
        };

        // Blank separator between diagnostics
        if i + 1 < cnt { print(""); };
        i = i + 1;
    };
    return cnt;
}

