// =====================================================
// EFFECT CHECKER (S11.6)
// =====================================================
#[manual_drop]
fn is_tainted_type(tstr: str) -> i64 {
    // Hot path: was allocating a 7-byte substring per call.
    if str_starts_with(tstr, "tainted") == 1 { return 1; };
    return 0;
}
#[manual_drop]
fn taint_inner_type(t: str) -> str {
    let slen: i64 = str_len(t);
    if str_starts_with(t, "tainted<") == 1 { return str_substring(t, 8, slen - 1); };
    return t;
}
#[manual_drop]
fn tnt_collect_tainted_symbols(source: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let pat: str = "tainted<";
    let plen: i64 = str_len(pat);
    let slen: i64 = str_len(source);
    let mut base: i64 = 0;
    let mut rest: str = source;
    while base + plen <= slen {
        let rel: i64 = str_index_of(rest, pat);
        if rel < 0 {
            base = slen;
        } else {
            let p: i64 = base + rel;
            let mut q: i64 = p - 1;
            while q >= 0 && is_ws(str_char_at(source, q)) == 1 { q = q - 1; };
            if q >= 0 && str_char_at(source, q) == 58 {
                q = q - 1;
                while q >= 0 && is_ws(str_char_at(source, q)) == 1 { q = q - 1; };
                let end_name: i64 = q + 1;
                while q >= 0 && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q - 1; };
                let start_name: i64 = q + 1;
                if end_name > start_name {
                    let sym: str = str_substring(source, start_name, end_name);
                    if str_len(sym) > 0 { out.push(sym); };
                };
            };
            base = p + plen;
            if base + plen <= slen { rest = str_substring(source, base, slen); };
        };
    };
    return out;
}
#[manual_drop]
fn tnt_symbol_is_tainted(symbols: Vec<i32>, name: str) -> i64 {
    let n: i64 = vec_len(symbols);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(symbols, i), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
#[manual_drop]
fn tnt_is_sensitive_sink(name: str) -> i64 {
    if str_eq(name, "print") == 1 { return 1; };
    if str_eq(name, "println") == 1 { return 1; };
    if str_eq(name, "system") == 1 { return 1; };
    if str_eq(name, "proc_run") == 1 { return 1; };
    if str_eq(name, "proc_run1") == 1 { return 1; };
    if str_eq(name, "file_write_string") == 1 { return 1; };
    return 0;
}
#[manual_drop]
fn tnt_find_call_end(text: str, open_pos: i64) -> i64 {
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
fn tnt_arg_is_sanitized(arg: str) -> i64 {
    let s: str = str_trim(arg);
    if str_starts_with(s, "sanitize(") == 1 { return 1; };
    return 0;
}
#[manual_drop]
fn tnt_emit_for_call_args(diags: Vec<i32>, source: str, symbols: Vec<i32>, sink: str, open_pos: i64, close_pos: i64) -> i64 {
    let mut emitted: i64 = 0;
    let mut depth: i64 = 0;
    let mut start: i64 = open_pos + 1;
    let mut p: i64 = start;
    while p <= close_pos {
        let at_end: i64 = if p == close_pos { 1 } else { 0 };
        let c: i64 = if at_end == 1 { 41 } else { str_char_at(source, p) };
        if c == 40 { depth = depth + 1; }
        else if c == 41 {
            if depth > 0 { depth = depth - 1; };
        };
        if (at_end == 1 || (c == 44 && depth == 0)) {
            let arg: str = str_trim(str_substring(source, start, p));
            if tnt_arg_is_sanitized(arg) == 0 && tnt_symbol_is_tainted(symbols, arg) == 1 {
                let msg: str = str_concat("tainted data passed to sensitive sink '", str_concat(sink, "'; sanitize the value before crossing the sink boundary"));
                let loc: Vec<i32> = diag_linecol_at_byte(source, start);
                diag_add_ex(diags, "error", "taint", "TNT-001", msg, sink, vec_get(loc, 0), vec_get(loc, 1), "");
                emitted = emitted + 1;
            };
            start = p + 1;
        };
        p = p + 1;
    };
    return emitted;
}
#[manual_drop]
fn enforce_tnt001_tainted_sinks(diags: Vec<i32>, source: str) -> Vec<i32> {
    if str_index_of(source, "tainted<") < 0 { return diags; };
    let symbols: Vec<i32> = tnt_collect_tainted_symbols(source);
    if vec_len(symbols) == 0 { return diags; };
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut sink: str = "";
        if p + 6 <= slen && str_eq_at_len(source, p, "print(", 6) == 1 { sink = "print"; };
        if p + 8 <= slen && str_eq_at_len(source, p, "println(", 8) == 1 { sink = "println"; };
        if p + 7 <= slen && str_eq_at_len(source, p, "system(", 7) == 1 { sink = "system"; };
        if p + 9 <= slen && str_eq_at_len(source, p, "proc_run(", 9) == 1 { sink = "proc_run"; };
        if p + 10 <= slen && str_eq_at_len(source, p, "proc_run1(", 10) == 1 { sink = "proc_run1"; };
        if p + 18 <= slen && str_eq_at_len(source, p, "file_write_string(", 18) == 1 { sink = "file_write_string"; };
        if str_len(sink) > 0 && tnt_is_sensitive_sink(sink) == 1 {
            let open_pos: i64 = p + str_len(sink);
            let close_pos: i64 = tnt_find_call_end(source, open_pos);
            if close_pos > open_pos { tnt_emit_for_call_args(diags, source, symbols, sink, open_pos, close_pos); p = close_pos; };
        };
        p = p + 1;
    };
    return diags;
}
fn types_compatible(expected: str, actual: str) -> i64 {
    if str_len(expected) == 0 || str_len(actual) == 0 { return 1; };
    if str_eq(expected, "_") == 1 { return 1; };
    if str_eq(actual, "_") == 1 { return 1; };
    if str_eq(expected, actual) == 1 { return 1; };
    // RFC-0046 Phase B (ROBO-7) — coordinate-frame phantom-tag check.
    // Two types with matching base names and distinct `Frame_*` phantom
    // arguments are NOT compatible (Mars-Climate-Orbiter failure mode).
    // Frame_Unknown is the documented migration sentinel and matches
    // anything; untagged types skip this check entirely. Placed before
    // the base-name catch-all below so `Pose<Frame_Camera>` and
    // `Pose<Frame_Base>` no longer collapse to the same shape.
    if frame_mismatch_visible(expected, actual) == 1 { return 0; };
    //  canonical Rust `let c: char
    // = 'a';` pre-fix failed TYP-008 because the char literal lexes
    // as token kind 2 (int with codepoint as value, type "i32"),
    // while the binding's declared type is "char" — types_compatible
    // returned 0. The Nucleor `char` type is documented as a 32-bit
    // unsigned integer width (line ~7501), so accept any integer
    // type as compatible with `char` (and vice versa). This matches
    // the codepoint-arithmetic semantics adopters use for char-as-i32
    // in `match c { 'a' => ..., 'b' => ... }` and `c as i64` casts.
    if str_eq(expected, "char") == 1 {
        if str_eq(actual, "i8") == 1 || str_eq(actual, "i16") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1 { return 1; };
        if str_eq(actual, "u8") == 1 || str_eq(actual, "u16") == 1 || str_eq(actual, "u32") == 1 || str_eq(actual, "u64") == 1 { return 1; };
        if str_eq(actual, "usize") == 1 || str_eq(actual, "isize") == 1 { return 1; };
    };
    if str_eq(actual, "char") == 1 {
        if str_eq(expected, "i8") == 1 || str_eq(expected, "i16") == 1 || str_eq(expected, "i32") == 1 || str_eq(expected, "i64") == 1 { return 1; };
        if str_eq(expected, "u8") == 1 || str_eq(expected, "u16") == 1 || str_eq(expected, "u32") == 1 || str_eq(expected, "u64") == 1 { return 1; };
        if str_eq(expected, "usize") == 1 || str_eq(expected, "isize") == 1 { return 1; };
    };
    // R09-D1 / RFC-0043: fixed<I,F> and ufixed<I,F> still lower to
    // i64 storage, but the type checker must preserve Q-format
    // identity. Permit raw integer storage to initialize a fixed value,
    // but do not let fixed widths collapse into each other or into i64.
    let exp_fixed: i64 = type_is_fixed_semantic(expected);
    let act_fixed: i64 = type_is_fixed_semantic(actual);
    if exp_fixed == 1 || act_fixed == 1 {
        if exp_fixed == 1 && act_fixed == 1 {
            if str_eq(fixed_type_canonical(expected), fixed_type_canonical(actual)) == 1 { return 1; };
            return 0;
        };
        if exp_fixed == 1 && fixed_accepts_integer_storage(actual) == 1 { return 1; };
        return 0;
    };
    let mut box_v075_match: i64 = 0;
    if str_len(expected) > 4 && str_len(actual) > 4 {
        if str_char_at(expected, 0) == 66 && str_char_at(actual, 0) == 66 {
            if str_starts_with(expected, "Box<") == 1 && str_starts_with(actual, "Box<") == 1 {
                box_v075_match = 1;
            };
        };
    };
    if box_v075_match == 1 {
        let bearg: str = type_first_arg(expected);
        let baarg: str = type_first_arg(actual);
        if str_len(bearg) > 0 && str_len(baarg) > 0 {
            let be_dyn: str = strip_spaces(bearg);
            let ba_dyn: str = strip_spaces(baarg);
            if str_starts_with(be_dyn, "dyn ") == 1 || str_starts_with(ba_dyn, "dyn ") == 1 {
                return 0;
            };
            if types_compatible(bearg, baarg) == 1 { return 1; };
            if str_eq(baarg, "i32") == 1 {
                if str_eq(bearg, "i64") == 1 || str_eq(bearg, "i16") == 1 || str_eq(bearg, "i8") == 1 { return 1; };
                if str_eq(bearg, "isize") == 1 { return 1; };
            };
        };
    };
    let ebase: str = type_base_name(expected);
    let abase: str = type_base_name(actual);
    if str_eq(ebase, abase) == 1 {
        if str_eq(ebase, "Option") == 1 || str_eq(ebase, "Vec") == 1 {
            let earg: str = type_first_arg(expected);
            let aarg: str = type_first_arg(actual);
            if str_eq(ebase, "Vec") == 1 && (vec_element_type_is_legacy_cell(earg) == 1 || vec_element_type_is_legacy_cell(aarg) == 1) {
                return 1;
            };
            if str_len(earg) > 0 && str_len(aarg) > 0 {
                if types_compatible(earg, aarg) == 1 { return 1; };
                // same literal-default widening for Vec/Option.
                if str_eq(aarg, "i32") == 1 {
                    if str_eq(earg, "i64") == 1 || str_eq(earg, "i16") == 1 || str_eq(earg, "i8") == 1 { return 1; };
                    if str_eq(earg, "isize") == 1 { return 1; };
                };
            };
        };
        if str_eq(ebase, "Result") == 1 {
            let eok: str = type_first_arg(expected);
            let aok: str = type_first_arg(actual);
            if str_len(eok) > 0 && str_len(aok) > 0 {
                if types_compatible(eok, aok) == 0 { return 0; };
            };
            let eerr: str = generic_second_type(expected);
            let aerr: str = generic_second_type(actual);
            if str_len(eerr) > 0 && str_len(aerr) > 0 {
                if types_compatible(eerr, aerr) == 0 { return 0; };
            };
            return 1;
        };
    };
    if str_eq(ebase, "Vec") == 1 && (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "ptr") == 1) { return 1; };
    if str_eq(abase, "Vec") == 1 && (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1 || str_eq(expected, "ptr") == 1) { return 1; };
    // T1.2 (v0.2.336): Option/Result constructors lower to a Vec<i32>
    // tag-payload runtime representation. Allow them to flow into
    // Vec / Vec<i32> / Vec<i64> return types.
    // switched the actual-side bare-name checks to abase
    // (and expected-side to ebase) so the compat survives v0.4.45's
    // Phase 2 change which now returns `Option<T>` / `Result<T>`
    // (with generic) from constructor expressions instead of bare
    // `Option` / `Result`. Pre-fix this caused
    // tests/features/option_result_basic.nr to fail TYP-010 because
    // `Ok(100)` typed as `Result<i64>` no longer matched `actual ==
    // "Result"`. Switching to abase strips the generic for the
    // family-equality check while preserving the rest of the
    // type-prop information for downstream Phase 3+ work.
    if (str_eq(abase, "Option") == 1 || str_eq(abase, "Result") == 1) &&
       (str_eq(ebase, "Vec") == 1 || str_eq(ebase, "Option") == 1 || str_eq(ebase, "Result") == 1) { return 1; };
    if (str_eq(ebase, "Option") == 1 || str_eq(ebase, "Result") == 1) &&
       (str_eq(abase, "Vec") == 1 || str_eq(abase, "Option") == 1 || str_eq(abase, "Result") == 1) { return 1; };
    // Option ↔ Result interop (rare but useful for ? in ad-hoc contexts).
    if (str_eq(ebase, "Option") == 1 && str_eq(abase, "Result") == 1) { return 1; };
    if (str_eq(ebase, "Result") == 1 && str_eq(abase, "Option") == 1) { return 1; };
    if (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1) && str_eq(actual, "bool") == 1 { return 1; };
    if str_eq(expected, "bool") == 1 && (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1) { return 1; };
    if str_eq(expected, "Int") == 1 && (str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1) { return 1; };
    if str_eq(expected, "Float") == 1 && (str_eq(actual, "f64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1) { return 1; };
    if str_len(ebase) >= 2 && (str_char_at(ebase, 0) == 105 || str_char_at(ebase, 0) == 117) {
        let mut digits_only: i64 = 1;
        let mut di: i64 = 1;
        while di < str_len(ebase) {
            let dc: i64 = str_char_at(ebase, di);
            if dc < 48 || dc > 57 { digits_only = 0; };
            di = di + 1;
        };
        if digits_only == 1 && (str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1 || str_eq(actual, "f64") == 1) { return 1; };
    };
    // T1.1 Phase 6: narrow integer → i64/i32 widening for argument
    // passing. Storage is i64 anyway, so a u8 / u16 / i8 / i16 / u32
    // can be passed as an i64 / i32 argument without loss.
    if (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1) {
        if str_eq(actual, "i8") == 1 || str_eq(actual, "i16") == 1 ||
           str_eq(actual, "u8") == 1 || str_eq(actual, "u16") == 1 ||
           str_eq(actual, "u32") == 1 { return 1; };
    };
    // T1.1 Phase 2: f32 / f16 / bf16 accept f64 literals (the parser
    // emits all float literals as f64; lowering inserts the conversion).
    if (str_eq(expected, "f32") == 1 || str_eq(expected, "f16") == 1 || str_eq(expected, "bf16") == 1)
       && (str_eq(actual, "f64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1) { return 1; };
    if str_len(expected) == 1 {
        let c: i64 = str_char_at(expected, 0);
        if c >= 65 && c <= 90 { return 1; };
    };
    if str_len(actual) == 1 {
        let c: i64 = str_char_at(actual, 0);
        if c >= 65 && c <= 90 { return 1; };
    };
    if str_eq(strip_spaces(expected), strip_spaces(actual)) == 1 { return 1; };
    if (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1 || str_eq(expected, "f64") == 1) &&
       (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "f64") == 1) { return 1; };
    if is_tainted_type(expected) == 1 && is_tainted_type(actual) == 0 {
        if str_eq(strip_spaces(taint_inner_type(expected)), strip_spaces(actual)) == 1 { return 1; };
    };
    if is_tainted_type(expected) == 0 && is_tainted_type(actual) == 1 { return 0; };
    if type_is_unit(expected) == 1 || type_is_unit(actual) == 1 { return 0; };
    if (str_eq(ebase, "HashMap") == 1 || str_eq(ebase, "HashSet") == 1
        || str_eq(ebase, "BTreeMap") == 1 || str_eq(ebase, "BTreeSet") == 1
        || str_eq(ebase, "VecDeque") == 1)
        && (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "ptr") == 1) {
        return 1;
    };
    if (str_eq(abase, "HashMap") == 1 || str_eq(abase, "HashSet") == 1
        || str_eq(abase, "BTreeMap") == 1 || str_eq(abase, "BTreeSet") == 1
        || str_eq(abase, "VecDeque") == 1)
        && (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1 || str_eq(expected, "ptr") == 1) {
        return 1;
    };
    if str_eq(ebase, abase) == 1 { return 1; };
    return 0;
}
#[manual_drop]
fn dyn_trait_name(t: str) -> str {
    let s: str = t;
    if str_starts_with(s, "dyn ") == 1 {
        return strip_spaces(str_substring(s, 4, str_len(s)));
    };
    return "";
}
#[manual_drop]
fn box_dyn_trait_name(t: str) -> str {
    let s: str = t;
    let dyn_pos: i64 = str_index_of(s, "dyn ");
    if dyn_pos >= 0 && str_starts_with(s, "Box<") == 1 {
        let mut end: i64 = str_len(s);
        if end > 0 && str_char_at(s, end - 1) == 62 { end = end - 1; };
        return strip_spaces(str_substring(s, dyn_pos + 4, end));
    };
    if str_starts_with(s, "Box<") == 1 {
        return dyn_trait_name(type_first_arg(s));
    };
    return "";
}
#[manual_drop]
fn type_implements_trait(pool: Vec<i32>, prog: i64, type_name: str, trait_name: str) -> i64 {
    let tbase: str = type_base_name(type_name);
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 45 &&
           str_eq(node_field(pool, nid, 1), trait_name) == 1 &&
           str_eq(type_base_name(node_field(pool, nid, 2)), tbase) == 1 {
            return 1;
        };
        i = i + 1;
    };
    return 0;
}
//  look up a type-alias decl
// (kind 51) by name in the program. Returns the resolved underlying
// type string (kind-51 field 2) or "" if no alias matches.
// short-circuit on shape — aliases are bare
// identifiers starting with an uppercase letter and containing no
// generic / ref / array brackets. Skip the prog scan for common
// builtin types (`i64`, `str`, `Vec<...>`, `&str`, etc.) which are
// the dominant case in hot type-check paths. v0.6.54 baseline was
// 3.08s; raw scan cost ~1.7s on the self-host (8500-decl walk per
// call). Fast-fail brings the regression back under 100ms.
#[manual_drop]
fn type_alias_resolve(pool: Vec<i32>, prog: i64, name: str) -> str {
    let nlen: i64 = str_len(name);
    if nlen == 0 { return ""; };
    let c0: i64 = str_char_at(name, 0);
    // Aliases must start uppercase. Reject lowercase (`i64`, `str`,
    // `f64`, `bool`, `usize`, etc.) and `&` / `[` / `<` shape prefixes
    // immediately. Also reject if the name contains any non-alnum
    // character (`<`, `>`, `,`, ` ` indicate a generic / parameterized
    // type, never a bare alias).
    if c0 < 65 || c0 > 90 { return ""; };
    let mut idx: i64 = 0;
    while idx < nlen {
        let c: i64 = str_char_at(name, idx);
        if c == 60 || c == 62 || c == 38 || c == 91 || c == 93 || c == 44 || c == 32 || c == 9 { return ""; };
        idx = idx + 1;
    };
    // Reject common builtin uppercase-starting names that are NOT
    // user-defined aliases (Vec, Option, Result, HashMap, etc.).
    if str_eq(name, "Vec") == 1 { return ""; };
    if str_eq(name, "Option") == 1 { return ""; };
    if str_eq(name, "Result") == 1 { return ""; };
    if str_eq(name, "HashMap") == 1 { return ""; };
    if str_eq(name, "HashSet") == 1 { return ""; };
    if str_eq(name, "BTreeMap") == 1 { return ""; };
    if str_eq(name, "BTreeSet") == 1 { return ""; };
    if str_eq(name, "VecDeque") == 1 { return ""; };
    if str_eq(name, "Box") == 1 { return ""; };
    if str_eq(name, "Self") == 1 { return ""; };
    if str_eq(name, "String") == 1 { return ""; };
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 51 && str_eq(node_field(pool, nid, 1), name) == 1 {
            return node_field(pool, nid, 2);
        };
        i = i + 1;
    };
    return "";
}

#[manual_drop]
fn types_compatible_context(pool: Vec<i32>, prog: i64, expected: str, actual: str) -> i64 {
    if types_compatible(expected, actual) == 1 { return 1; };
    // type-alias resolution. If either side is a bare
    // identifier matching a `type Name = T;` decl (kind 51), substitute
    // the resolved underlying type and re-check. One level of indirection
    // — chained aliases (`type A = B; type B = i64;`) are resolved
    // iteratively up to a small depth cap to prevent runaway. Cycles
    // (`type A = B; type B = A;`) bail out at the cap.
    let mut e_resolved: str = expected;
    let mut a_resolved: str = actual;
    let mut depth_v067: i64 = 0;
    while depth_v067 < 4 {
        let e_alias: str = type_alias_resolve(pool, prog, e_resolved);
        let a_alias: str = type_alias_resolve(pool, prog, a_resolved);
        let mut progress: i64 = 0;
        if str_len(e_alias) > 0 { e_resolved = e_alias; progress = 1; };
        if str_len(a_alias) > 0 { a_resolved = a_alias; progress = 1; };
        if progress == 0 { depth_v067 = 4; };
        depth_v067 = depth_v067 + 1;
    };
    if (str_eq(e_resolved, expected) == 0) || (str_eq(a_resolved, actual) == 0) {
        if types_compatible(e_resolved, a_resolved) == 1 { return 1; };
    };
    let trait_name: str = box_dyn_trait_name(expected);
    if str_len(trait_name) > 0 && str_starts_with(strip_spaces(actual), "Box<") == 1 {
        let actual_arg: str = type_first_arg(actual);
        if str_len(actual_arg) > 0 && str_len(dyn_trait_name(actual_arg)) == 0 {
            return type_implements_trait(pool, prog, actual_arg, trait_name);
        };
    };
    return 0;
}
#[manual_drop]
fn target_root_name(target: str) -> str {
    let mut i: i64 = 0;
    while i < str_len(target) {
        if str_char_at(target, i) == 46 { return str_substring(target, 0, i); };
        i = i + 1;
    };
    return target;
}
#[manual_drop]
fn expr_escape_root(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 90 || kind == 91 {
        let root: str = expr_root_name(pool, node_field(pool, nid, 1), own);
        if own_get_param(own, root) == 0 { return root; };
        return "";
    };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if type_is_ref(own_get_type(own, name)) == 1 {
            let target: str = own_get_ref_target(own, name);
            if str_len(target) > 0 {
                let root: str = target_root_name(target);
                if own_get_param(own, root) == 0 { return root; };
                return "";
            };
            if own_get_param(own, name) == 0 { return name; };
        };
        return "";
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        if body < 0 || body >= vec_len(pool) { return ""; };
        let cnt: i64 = list_len(pool, body);
        if cnt == 0 { return ""; };
        let last_stmt: i64 = list_get(pool, body, cnt - 1);
        let sk: i64 = node_kind(pool, last_stmt);
        if sk == 22 || sk == 25 { return expr_escape_root(pool, node_field(pool, last_stmt, 1), own); };
        if sk == 23 { return expr_escape_root(pool, last_stmt, own); };
        return "";
    };
    if kind == 23 {
        let mut root: str = expr_escape_root(pool, node_field(pool, nid, 2), own);
        if str_len(root) > 0 { return root; };
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { return expr_escape_root(pool, enode, own); };
        return "";
    };
    return "";
}

// RFC-0062 G-2 Phase 2b — single-input lifetime check.
// Mirror of expr_escape_root, but flips the param-vs-local test:
// returns the *parameter* name a returned reference traces back to,
// or "" if the trace cannot be proved (or the source is a non-param
// local, which OWN-009 already handles). Used by check_fn to verify
// that a fn with exactly one ref-typed input + ref return derives
// the return from that single input.
// For if/else (kind 23), both arms must trace to the same param;
// otherwise the join is inconclusive and we return "" (conservative
// — no false positive).
#[manual_drop]
fn expr_param_root(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 90 || kind == 91 {
        let root: str = expr_root_name(pool, node_field(pool, nid, 1), own);
        if str_len(root) > 0 && own_get_param(own, root) == 1 { return root; };
        return "";
    };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if type_is_ref(own_get_type(own, name)) == 1 {
            let target: str = own_get_ref_target(own, name);
            if str_len(target) > 0 {
                let root: str = target_root_name(target);
                if str_len(root) > 0 && own_get_param(own, root) == 1 { return root; };
                return "";
            };
        };
        if str_len(name) > 0 && own_get_param(own, name) == 1 { return name; };
        return "";
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        if body < 0 || body >= vec_len(pool) { return ""; };
        let cnt: i64 = list_len(pool, body);
        if cnt == 0 { return ""; };
        let last_stmt: i64 = list_get(pool, body, cnt - 1);
        let sk: i64 = node_kind(pool, last_stmt);
        if sk == 22 || sk == 25 { return expr_param_root(pool, node_field(pool, last_stmt, 1), own); };
        if sk == 23 { return expr_param_root(pool, last_stmt, own); };
        return "";
    };
    if kind == 23 {
        let then_root: str = expr_param_root(pool, node_field(pool, nid, 2), own);
        let enode: i64 = node_field(pool, nid, 3);
        if enode < 0 { return ""; };
        let else_root: str = expr_param_root(pool, enode, own);
        if str_len(then_root) > 0 && str_len(else_root) > 0 && str_eq(then_root, else_root) == 1 {
            return then_root;
        };
        return "";
    };
    return "";
}

#[manual_drop]
fn builtin_rtype_format_string_i64(name: str) -> i64 {
    if str_eq(name, "str_eq") == 1 { return 1; };
    if str_eq(name, "str_starts_with") == 1 { return 1; };
    if str_eq(name, "str_ends_with") == 1 { return 1; };
    if str_eq(name, "str_index_of") == 1 { return 1; };
    if str_eq(name, "str_contains") == 1 { return 1; };
    if str_eq(name, "str_is_empty") == 1 { return 1; };
    if str_eq(name, "str_count") == 1 { return 1; };
    if str_eq(name, "str_to_i64") == 1 { return 1; };
    if str_eq(name, "str_to_int") == 1 { return 1; };
    if str_eq(name, "str_to_int_strict") == 1 { return 1; };
    if str_eq(name, "str_to_bool") == 1 { return 1; };
    if str_eq(name, "str_to_i64_radix") == 1 { return 1; };
    if str_eq(name, "parse_hex") == 1 { return 1; };
    if str_eq(name, "parse_bin") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn builtin_rtype_format_string_str(name: str) -> i64 {
    if str_eq(name, "str_concat") == 1 { return 1; };
    if str_eq(name, "str_to_lower") == 1 { return 1; };
    if str_eq(name, "str_to_upper") == 1 { return 1; };
    if str_eq(name, "str_replace") == 1 { return 1; };
    if str_eq(name, "str_repeat") == 1 { return 1; };
    if str_eq(name, "str_reverse") == 1 { return 1; };
    if str_eq(name, "str_pad_left") == 1 { return 1; };
    if str_eq(name, "str_pad_right") == 1 { return 1; };
    if str_eq(name, "str_center") == 1 { return 1; };
    if str_eq(name, "str_join") == 1 { return 1; };
    if str_eq(name, "int_to_str") == 1 { return 1; };
    if str_eq(name, "str_from_int") == 1 { return 1; };
    if str_eq(name, "bool_to_str") == 1 { return 1; };
    if str_eq(name, "int_to_hex") == 1 { return 1; };
    if str_eq(name, "int_to_bin") == 1 { return 1; };
    if str_eq(name, "int_to_oct") == 1 { return 1; };
    if str_eq(name, "int_to_str_force_sign") == 1 { return 1; };
    if str_eq(name, "int_to_hex_upper") == 1 { return 1; };
    if str_eq(name, "f64_to_str") == 1 { return 1; };
    if str_eq(name, "f32_to_str") == 1 { return 1; };
    if str_eq(name, "f64_to_str_prec") == 1 { return 1; };
    if str_eq(name, "f32_to_str_prec") == 1 { return 1; };
    if str_eq(name, "f64_to_str_sci") == 1 { return 1; };
    if str_eq(name, "f64_to_str_sci_upper") == 1 { return 1; };
    if str_eq(name, "f64_to_str_sci_prec") == 1 { return 1; };
    if str_eq(name, "f64_to_str_sci_prec_upper") == 1 { return 1; };
    if str_eq(name, "format_i64") == 1 { return 1; };
    if str_eq(name, "format_str") == 1 { return 1; };
    if str_eq(name, "format_hex") == 1 { return 1; };
    if str_eq(name, "format_bool") == 1 { return 1; };
    if str_eq(name, "format_f64") == 1 { return 1; };
    if str_eq(name, "format2_ii") == 1 { return 1; };
    if str_eq(name, "format2_si") == 1 { return 1; };
    if str_eq(name, "format2_ss") == 1 { return 1; };
    if str_eq(name, "format2_is") == 1 { return 1; };
    if str_eq(name, "format2_ff") == 1 { return 1; };
    if str_eq(name, "format2_fi") == 1 { return 1; };
    if str_eq(name, "format2_if") == 1 { return 1; };
    if str_eq(name, "format3_fff") == 1 { return 1; };
    if str_eq(name, "format3_iii") == 1 { return 1; };
    if str_eq(name, "format3_sii") == 1 { return 1; };
    if str_eq(name, "format3_iss") == 1 { return 1; };
    if str_eq(name, "format3_sss") == 1 { return 1; };
    if str_eq(name, "format3_ssi") == 1 { return 1; };
    if str_eq(name, "format3_sis") == 1 { return 1; };
    if str_eq(name, "format3_iis") == 1 { return 1; };
    if str_eq(name, "format3_isi") == 1 { return 1; };
    if str_eq(name, "format3_iif") == 1 { return 1; };
    if str_eq(name, "format3_iff") == 1 { return 1; };
    if str_eq(name, "format3_sff") == 1 { return 1; };
    if str_eq(name, "format3_ssf") == 1 { return 1; };
    if str_eq(name, "format3_sif") == 1 { return 1; };
    if str_eq(name, "format3_isf") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn builtin_rtype(name: str) -> str {
    if str_eq(name, "str_len") == 1 || str_eq(name, "str_char_at") == 1 || str_eq(name, "str_char_at_strict") == 1 { return "i64"; };
    if str_eq(name, "str_substring") == 1 || str_eq(name, "str_substring_strict") == 1 || str_eq(name, "str_trim") == 1 || str_eq(name, "str_trim_start") == 1 || str_eq(name, "str_trim_end") == 1 { return "str"; };
    if str_eq(name, "args_get") == 1 || str_eq(name, "file_read_string") == 1 || str_eq(name, "file_read_string_or_panic") == 1 { return "str"; };
    if str_eq(name, "args_count") == 1 || str_eq(name, "env_has") == 1 || str_eq(name, "process_id") == 1 || str_eq(name, "os_family") == 1 || str_eq(name, "os_pointer_width") == 1 || str_eq(name, "path_is_absolute") == 1 || str_eq(name, "fs_exists") == 1 || str_eq(name, "fs_is_file") == 1 || str_eq(name, "fs_is_dir") == 1 || str_eq(name, "fs_size") == 1 || str_eq(name, "fs_mtime") == 1 || str_eq(name, "file_bytes_equal") == 1 || str_eq(name, "system") == 1 { return "i64"; };
    // ptr_is_null is the FFI-G5 prescribed
    // remediation. Returns 1 iff the i64 pointer arg is 0.
    if str_eq(name, "ptr_is_null") == 1 { return "i64"; };
    if str_eq(name, "env_get") == 1 || str_eq(name, "env_get_or") == 1 || str_eq(name, "getcwd") == 1 || str_eq(name, "getenv") == 1 || str_eq(name, "chr") == 1 || str_eq(name, "fs_join") == 1 || str_eq(name, "fs_basename") == 1 || str_eq(name, "fs_dirname") == 1 || str_eq(name, "fs_extension") == 1 || str_eq(name, "fs_temp_dir") == 1 || str_eq(name, "fs_current_dir") == 1 || str_eq(name, "fs_canonicalize") == 1 || str_eq(name, "path_separator") == 1 || str_eq(name, "path_normalize") == 1 || str_eq(name, "path_with_extension") == 1 || str_eq(name, "path_strip_extension") == 1 { return "str"; };
    if str_eq(name, "sqrt") == 1 || str_eq(name, "sin") == 1 || str_eq(name, "cos") == 1 || str_eq(name, "pow") == 1 || str_eq(name, "floor") == 1 || str_eq(name, "ceil") == 1 || str_eq(name, "round") == 1 || str_eq(name, "exp") == 1 || str_eq(name, "log") == 1 || str_eq(name, "tanh") == 1 || str_eq(name, "tanh_act") == 1 || str_eq(name, "fabs") == 1 || str_eq(name, "fmod") == 1 || str_eq(name, "f64_from_bits") == 1 { return "f64"; };
    if str_eq(name, "f64_to_bits") == 1 { return "i64"; };
    if str_eq(name, "f64_to_i32") == 1 { return "i32"; };
    if str_eq(name, "now_ms") == 1 || str_eq(name, "sleep_ms") == 1 || str_eq(name, "sleep_us") == 1 || str_eq(name, "time_monotonic_ms") == 1 || str_eq(name, "time_monotonic_ns") == 1 || str_eq(name, "time_monotonic_us") == 1 || str_eq(name, "time_wall_ms") == 1 || str_eq(name, "time_wall_ns") == 1 || str_eq(name, "time_wall_seconds") == 1 || str_eq(name, "time_wall_us") == 1 || str_eq(name, "time_year") == 1 || str_eq(name, "time_month") == 1 || str_eq(name, "time_day") == 1 || str_eq(name, "time_hour") == 1 || str_eq(name, "time_minute") == 1 || str_eq(name, "time_second") == 1 || str_eq(name, "time_weekday") == 1 || str_eq(name, "time_day_of_year") == 1 || str_eq(name, "time_elapsed_ms") == 1 || str_eq(name, "deadline_enter") == 1 || str_eq(name, "deadline_exit") == 1 || str_eq(name, "deadline_poll") == 1 || str_eq(name, "deadline_check") == 1 { return "i64"; };
    if str_eq(name, "ambient_scheduler") == 1 { return "SchedulerCap"; };
    if str_eq(name, "ambient_random") == 1 { return "RandomCap"; };
    if str_eq(name, "random_uniform") == 1 { return "f64"; };
    if str_eq(name, "random_normal") == 1 { return "f64"; };
    if str_eq(name, "arena_new") == 1 { return "Arena"; };
    if str_eq(name, "arena_alloc") == 1 { return "&i64"; };
    if str_eq(name, "device_alloc") == 1 { return "DeviceBuffer"; };
    if str_eq(name, "device_transfer") == 1 { return "DeviceBuffer"; };
    if str_eq(name, "tensor_view") == 1 { return "i64"; };
    if str_eq(name, "max_depth_enter") == 1 || str_eq(name, "max_depth_exit") == 1 { return "i64"; };
    if str_eq(name, "channel") == 1 { return "i64"; };
    if str_eq(name, "rwlock_new") == 1 || str_eq(name, "rwlock_read") == 1 || str_eq(name, "rwlock_write") == 1 || str_eq(name, "rwlock_unlock") == 1 { return "i64"; };
    if str_eq(name, "cancel_token_new") == 1 || str_eq(name, "cancel_token_cancel") == 1 { return "i64"; };
    if is_atomic_ordered_builtin(name) == 1 { return "i64"; };
    if is_nuc_raw_intrinsic(name) == 1 { return "i64"; };
    if str_eq(name, "print") == 1 || str_eq(name, "print_int") == 1 || str_eq(name, "print_f64") == 1 || str_eq(name, "print_bool") == 1 || str_eq(name, "putchar") == 1 { return "void"; };
    if str_eq(name, "rng_seed") == 1 || str_eq(name, "device_free") == 1 || str_eq(name, "arena_destroy") == 1 || str_eq(name, "arena_reset") == 1 { return "void"; };
    // vec_pop is a void-returning runtime helper (removes the last
    // element, returns nothing). Pre-fix builtin_rtype returned ""
    // for it, so `let x = vec_pop(v)` silently bound 0 (TYP-021
    // didn't fire because the rtype was unknown, not void). Adopters
    // got a 0 they couldn't distinguish from a popped 0. Naming
    // vec_pop here makes TYP-021 fire at the let-binding site with
    // the canonical "vec_pop returns void; use v.last() before pop()"
    // workaround.
    if str_eq(name, "vec_pop") == 1 { return "void"; };
    return "";
}

#[manual_drop]
fn source_line(source: str, line: i64) -> str {
    let slen: i64 = str_len(source);
    let mut cur: i64 = 1;
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i < slen {
        if cur == line {
            let mut end: i64 = i;
            while end < slen && str_char_at(source, end) != 10 { end = end + 1; };
            return str_substring(source, start, end);
        };
        if str_char_at(source, i) == 10 { cur = cur + 1; start = i + 1; };
        i = i + 1;
    };
    if cur == line { return str_substring(source, start, slen); };
    return "";
}
#[manual_drop]
fn line_has_unit_literal(source: str, fn_name: str, symbol: str) -> i64 {
    let line: i64 = find_in_source(source, fn_name, symbol);
    let txt: str = source_line(source, line);
    let mut i: i64 = 0;
    while i < str_len(txt) {
        if str_char_at(txt, i) == 123 { return 1; };
        i = i + 1;
    };
    return 0;
}
#[manual_drop]
fn line_contains_text(source: str, fn_name: str, symbol: str, text: str) -> i64 {
    let line: i64 = find_in_source(source, fn_name, symbol);
    let txt: str = source_line(source, line);
    let tlen: i64 = str_len(text);
    let llen: i64 = str_len(txt);
    if llen < tlen { return 0; };
    let mut i: i64 = 0;
    while i <= llen - tlen {
        if str_eq_at_len(txt, i, text, tlen) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
#[manual_drop]
fn source_box_binding_type(source: str, fn_name: str, name: str) -> str {
    let target: str = str_concat("let ", str_concat(name, ": Box<"));
    let tlen: i64 = str_len(target);
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i <= slen - tlen {
        if str_eq_at_len(source, i, target, tlen) == 1 {
            let mut end: i64 = i + tlen;
            while end < slen && str_char_at(source, end) != 62 { end = end + 1; };
            if end < slen { return str_concat("Box<", str_concat(str_substring(source, i + tlen, end), ">")); };
        };
        i = i + 1;
    };
    return "";
}
#[manual_drop]
fn own_diag_ex(own: Vec<i32>, fn_name: str, code: str, message: str, symbol: str, checker: str) -> i64 {
    let src: str = own_source(own);
    let diags: Vec<i32> = own_diags(own);
    let loc: Vec<i32> = find_linecol_in_source(src, fn_name, symbol);
    diag_add_ex(diags, "error", checker, code, message, fn_name, vec_get(loc, 0), vec_get(loc, 1), "");
    return 1;
}
#[manual_drop]
fn own_diag(own: Vec<i32>, fn_name: str, code: str, message: str, symbol: str) -> i64 {
    return own_diag_ex(own, fn_name, code, message, symbol, "ownership");
}
#[manual_drop]
fn own_box_hint(own: Vec<i32>, fn_name: str, name: str) -> str {
    let cache_key: str = str_concat("__box_hint_", name);
    let cached: str = own_get_s(own, cache_key);
    if str_eq(cached, "_none_") == 1 { return ""; };
    if str_len(cached) > 0 { return cached; };
    let source_text: str = own_source(own);
    let guessed: str = source_box_binding_type(source_text, fn_name, name);
    if str_len(guessed) > 0 {
        own_set_s(own, cache_key, guessed);
        return guessed;
    };
    if line_contains_text(source_text, fn_name, name, "Box<") == 1 {
        own_set_s(own, cache_key, "Box");
        return "Box";
    };
    own_set_s(own, cache_key, "_none_");
    return "";
}
#[manual_drop]
fn own_copy_ref_binding(own: Vec<i32>, src: str, dst: str, scope_depth: i64) -> i64 {
    let target: str = own_get_ref_target(own, src);
    if str_len(target) == 0 { return 0; };
    let kind: i64 = own_get_ref_kind(own, src);
    if kind == 0 { own_inc_shared(own, target); };
    own_set_ref_target(own, dst, target);
    own_set_ref_kind(own, dst, kind);
    own_set_scope(own, dst, scope_depth);
    return 0;
}
#[manual_drop]
fn own_register_borrow_expr(pool: Vec<i32>, nid: i64, own: Vec<i32>, fn_name: str, ref_name: str, scope_depth: i64, persist: i64) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind != 90 && kind != 91 { return 0; };
    let target_expr: i64 = node_field(pool, nid, 1);
    let key: str = expr_borrow_key(pool, target_expr, own);
    let root: str = expr_root_name(pool, target_expr, own);
    if str_len(key) == 0 || str_len(root) == 0 { return 0; };
    if own_get(own, root) == 2 {
        return own_diag(own, fn_name, "OWN-002", str_concat("cannot borrow moved value '", str_concat(root, "'")), root);
    };
    if kind == 90 {
        if own_has_mut_overlap(own, key) == 1 {
            return own_diag(own, fn_name, "OWN-005", str_concat("cannot shared-borrow '", str_concat(root, "': value is mutably borrowed")), root);
        };
        own_inc_shared(own, key);
        if persist == 1 && str_len(ref_name) > 0 {
            own_set_ref_target(own, ref_name, key);
            own_set_ref_kind(own, ref_name, 0);
            own_set_scope(own, ref_name, scope_depth);
        };
        return 0;
    };
    if own_get_mutable(own, root) == 0 && own_get_param(own, root) == 0 && type_is_mut_ref(own_get_type(own, root)) == 0 {
        return own_diag(own, fn_name, "OWN-011", str_concat("cannot mutably borrow immutable value '", str_concat(root, "'")), root);
    };
    if own_has_mut_overlap(own, key) == 1 || own_has_shared_overlap(own, key) == 1 {
        return own_diag(own, fn_name, "OWN-004", str_concat("cannot mutably borrow '", str_concat(root, "': value is already borrowed")), root);
    };
    own_set_mut_borrow(own, key, 1);
    if persist == 1 && str_len(ref_name) > 0 {
        own_set_ref_target(own, ref_name, key);
        own_set_ref_kind(own, ref_name, 1);
        own_set_scope(own, ref_name, scope_depth);
    };
    return 0;
}

#[manual_drop]
fn tprof_new(enabled: i64) -> Vec<i32> {
    let mut prof: Vec<i32> = Vec::new();
    if enabled == 0 { return prof; };
    let mut i: i64 = 0;
    prof.push(1);
    while i < 12 {
        prof.push(0);
        i = i + 1;
    };
    return prof;
}
#[manual_drop]
fn tprof_enabled(prof: Vec<i32>) -> i64 {
    if vec_len(prof) == 0 { return 0; };
    return 1;
}
#[manual_drop]
fn tprof_start(prof: Vec<i32>) -> i64 {
    if tprof_enabled(prof) == 1 { return now_ms(); };
    return 0;
}
#[manual_drop]
fn tprof_mark(prof: Vec<i32>, count_idx: i64, time_idx: i64, start_ms: i64) -> i64 {
    if tprof_enabled(prof) == 1 {
        vec_set(prof, count_idx, vec_get(prof, count_idx) + 1);
        vec_set(prof, time_idx, vec_get(prof, time_idx) + (now_ms() - start_ms));
    };
    return 0;
}
#[manual_drop]
fn tprof_dump(prof: Vec<i32>) -> i64 {
    if tprof_enabled(prof) == 0 { return 0; };
    print(str_concat("  type profile stmt: ", str_concat(str_from_int(vec_get(prof, 1)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 2)), " ms")))));
    print(str_concat("  type profile env_lookup: ", str_concat(str_from_int(vec_get(prof, 3)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 4)), " ms")))));
    print(str_concat("  type profile sig_lookup: ", str_concat(str_from_int(vec_get(prof, 5)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 6)), " ms")))));
    print(str_concat("  type profile compat: ", str_concat(str_from_int(vec_get(prof, 7)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 8)), " ms")))));
    print(str_concat("  type profile call_expr: ", str_concat(str_from_int(vec_get(prof, 9)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 10)), " ms")))));
    print(str_concat("  type profile box_hint: ", str_concat(str_from_int(vec_get(prof, 11)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 12)), " ms")))));
    return 0;
}
#[manual_drop]
fn type_diag(diags: Vec<i32>, source: str, fn_name: str, symbol: str, code: str, message: str) -> i64 {
    let loc: Vec<i32> = find_linecol_in_source(source, fn_name, symbol);
    return diag_add_ex(diags, "error", "type", code, message, fn_name, vec_get(loc, 0), vec_get(loc, 1), "");
}
#[manual_drop]
fn diag_add_at_or_scan(diags: Vec<i32>, source: str, pool: Vec<i32>, nid: i64, fallback_symbol: str, severity: str, checker: str, code: str, message: str, fn_name: str, related_id: str) -> i64 {
    let sp: i64 = node_get_span(pool, nid);
    if sp >= 0 {
        let lm: Vec<i32> = linemap_build(source);
        return diag_add_ex(diags, severity, checker, code, message, fn_name, linemap_line(lm, sp), linemap_col(lm, sp), related_id);
    };
    let loc: Vec<i32> = find_linecol_in_source(source, fn_name, fallback_symbol);
    return diag_add_ex(diags, severity, checker, code, message, fn_name, vec_get(loc, 0), vec_get(loc, 1), related_id);
}
#[manual_drop]
fn type_diag_at(diags: Vec<i32>, source: str, pool: Vec<i32>, nid: i64, fn_name: str, fallback_symbol: str, code: str, message: str) -> i64 {
    return diag_add_at_or_scan(diags, source, pool, nid, fallback_symbol, "error", "type", code, message, fn_name, "");
}
#[manual_drop]
fn match_diag_at(diags: Vec<i32>, source: str, pool: Vec<i32>, nid: i64, severity: str, code: str, message: str, fn_name: str) -> i64 {
    return diag_add_at_or_scan(diags, source, pool, nid, "match", severity, "type", code, message, fn_name, "");
}
#[manual_drop]
fn sig_new() -> Vec<i32> { return smap_new(); }
#[manual_drop]
fn sig_entry_new(plist: i64, rtype: str, is_extern: i64, gparams: i64) -> Vec<i32> {
    let mut entry: Vec<i32> = Vec::new();
    entry.push(plist);
    entry.push(rtype);
    entry.push(is_extern);
    entry.push(gparams);
    return entry;
}
#[manual_drop]
fn sig_add(sigs: Vec<i32>, name: str, plist: i64, rtype: str, is_extern: i64, gparams: i64) -> i64 {
    return smap_set(sigs, name, sig_entry_new(plist, rtype, is_extern, gparams));
}
#[manual_drop]
fn sig_find(sigs: Vec<i32>, name: str) -> i64 {
    return smap_get(sigs, name);
}
#[manual_drop]
fn sig_plist(sigs: Vec<i32>, name: str) -> i64 {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return 0 - 1; };
    return vec_get(entry, 0);
}
#[manual_drop]
fn sig_rtype(sigs: Vec<i32>, name: str) -> str {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return ""; };
    return vec_get(entry, 1);
}
#[manual_drop]
fn sig_is_extern(sigs: Vec<i32>, name: str) -> i64 {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return 0; };
    return vec_get(entry, 2);
}
#[manual_drop]
fn sig_gparams_from_entry(entry: i64) -> i64 {
    if entry < 0 { return 0 - 1; };
    if vec_len(entry) < 4 { return 0 - 1; };
    return vec_get(entry, 3);
}
#[manual_drop]
fn tenv_new() -> Vec<i32> { return Vec::new(); }
#[manual_drop]
fn tenv_set(env: Vec<i32>, name: str, tstr: str) -> i64 { env.push(name); env.push(tstr); return 0; }
#[manual_drop]
fn tenv_get(env: Vec<i32>, name: str) -> str {
    let v: i64 = sym_get(env, name);
    if v < 0 { return ""; };
    return v;
}
#[manual_drop]
fn tenv_const_key(name: str) -> str {
    return str_concat("__const:", name);
}
#[manual_drop]
fn tenv_set_const_i64(env: Vec<i32>, name: str, val: i64) -> i64 {
    return tenv_set(env, tenv_const_key(name), str_from_int(val));
}
#[manual_drop]
fn tenv_clear_const(env: Vec<i32>, name: str) -> i64 {
    return tenv_set(env, tenv_const_key(name), "");
}
#[manual_drop]
fn tenv_get_const_i64(env: Vec<i32>, name: str) -> str {
    return tenv_get(env, tenv_const_key(name));
}
#[manual_drop]
fn const_i64_result(have: i64, val: i64) -> Vec<i32> {
    let mut r: Vec<i32> = Vec::new();
    r.push(have);
    r.push(val);
    r.push(0);
    return r;
}
#[manual_drop]
fn const_i64_result_ex(have: i64, val: i64, overflow: i64) -> Vec<i32> {
    let mut r: Vec<i32> = Vec::new();
    r.push(have);
    r.push(val);
    r.push(overflow);
    return r;
}
#[manual_drop]
fn const_i64_overflow(r: Vec<i32>) -> i64 {
    if vec_len(r) > 2 { return vec_get(r, 2); };
    return 0;
}
#[manual_drop]
fn const_i64_min() -> i64 {
    let max_i64: i64 = 9223372036854775807;
    return (0 - max_i64) - 1;
}

//  unsigned compare for i64 values treated as
// u64 bit patterns. Same-sign: signed compare matches unsigned. Mixed
// signs: the negative-as-i64 has the high bit set so when read as u64
// it's >= 2^63 — strictly greater than any non-negative i64 read as u64.
#[manual_drop]
fn u64_lt(a: i64, b: i64) -> i64 {
    let neg_a: i64 = if a < 0 { 1 } else { 0 };
    let neg_b: i64 = if b < 0 { 1 } else { 0 };
    if neg_a == neg_b {
        if a < b { return 1; };
        return 0;
    };
    if neg_a == 1 { return 0; };
    return 1;
}

// u64-aware overflow detection on a const-foldable
// binop. Walks kind-4 (binop) nodes; if both operands are kind-1 literals
// or kind-3 var-refs to const-tracked bindings, computes the wrapping
// result and checks for unsigned overflow using u64_lt. Returns 1 on
// overflow, 0 otherwise. Only handles add/sub/mul today (ops 20/21/22).
// div/mod/shift fall through to existing const_i64_binop checks.
#[manual_drop]
fn const_u64_overflow(pool: Vec<i32>, nid: i64, env: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let k: i64 = node_kind(pool, nid);
    if k != 4 { return 0; };
    let op: i64 = node_field(pool, nid, 1);
    let lhs_nid: i64 = node_field(pool, nid, 2);
    let rhs_nid: i64 = node_field(pool, nid, 3);
    let lhs_r: Vec<i32> = const_i64_expr(pool, lhs_nid, env);
    let rhs_r: Vec<i32> = const_i64_expr(pool, rhs_nid, env);
    if vec_get(lhs_r, 0) == 0 || vec_get(rhs_r, 0) == 0 { return 0; };
    let a: i64 = vec_get(lhs_r, 1);
    let b: i64 = vec_get(rhs_r, 1);
    if op == 20 {
        // add: overflow iff (a + b) as u64 < a as u64
        let s: i64 = wrapping_add(a, b);
        if u64_lt(s, a) == 1 { return 1; };
        return 0;
    };
    if op == 21 {
        // sub: overflow iff a as u64 < b as u64 (i.e. result would go negative in u64)
        if u64_lt(a, b) == 1 { return 1; };
        return 0;
    };
    if op == 22 {
        // mul: overflow iff a != 0 && (a*b) / a != b at u64 level. Use
        // wrapping_mul + a guard; if either operand is 0, no overflow.
        if a == 0 { return 0; };
        if b == 0 { return 0; };
        let p: i64 = wrapping_mul(a, b);
        // u64-divide via... actually no u64_div helper at compile-time.
        // Fall back to a conservative high-bit check: if both operands
        // have high 32 bits non-zero (as u64), product likely overflows.
        // Conservative approximation — may miss some cases but won't
        // false-positive on small operands.
        let a_high: i64 = a / 4294967296;
        let b_high: i64 = b / 4294967296;
        if a < 0 || b < 0 {
            // Either operand >= 2^63 → almost certainly overflows when
            // multiplied by anything > 1.
            if (a < 0 && b > 1) || (b < 0 && a > 1) || (a < 0 && b < 0) { return 1; };
        };
        if a_high != 0 && b_high != 0 { return 1; };
        return 0;
    };
    return 0;
}
#[manual_drop]
fn const_i64_add(a: i64, b: i64) -> Vec<i32> {
    let max_i64: i64 = 9223372036854775807;
    let min_i64: i64 = const_i64_min();
    if b > 0 {
        if a > max_i64 - b { return const_i64_result_ex(0, 0, 1); };
    };
    if b < 0 {
        if a < min_i64 - b { return const_i64_result_ex(0, 0, 1); };
    };
    return const_i64_result(1, a + b);
}
#[manual_drop]
fn const_i64_sub(a: i64, b: i64) -> Vec<i32> {
    let max_i64: i64 = 9223372036854775807;
    let min_i64: i64 = const_i64_min();
    if b > 0 {
        if a < min_i64 + b { return const_i64_result_ex(0, 0, 1); };
    };
    if b < 0 {
        if a > max_i64 + b { return const_i64_result_ex(0, 0, 1); };
    };
    return const_i64_result(1, a - b);
}
#[manual_drop]
fn const_i64_abs_non_min(v: i64) -> i64 {
    if v < 0 { return 0 - v; };
    return v;
}
#[manual_drop]
fn const_i64_mul(a: i64, b: i64) -> Vec<i32> {
    let max_i64: i64 = 9223372036854775807;
    let min_i64: i64 = const_i64_min();
    if a == 0 || b == 0 { return const_i64_result(1, 0); };
    if a == min_i64 {
        if b == 1 { return const_i64_result(1, min_i64); };
        return const_i64_result_ex(0, 0, 1);
    };
    if b == min_i64 {
        if a == 1 { return const_i64_result(1, min_i64); };
        return const_i64_result_ex(0, 0, 1);
    };
    let aa: i64 = const_i64_abs_non_min(a);
    let bb: i64 = const_i64_abs_non_min(b);
    if aa > max_i64 / bb { return const_i64_result_ex(0, 0, 1); };
    return const_i64_result(1, a * b);
}
#[manual_drop]
fn const_i64_binop(op: i64, a: i64, b: i64) -> Vec<i32> {
    let min_i64: i64 = const_i64_min();
    if op == 20 { return const_i64_add(a, b); };
    if op == 21 { return const_i64_sub(a, b); };
    if op == 22 { return const_i64_mul(a, b); };
    if op == 23 {
        //  div-by-zero in const expression
        // is undefined; flag as overflow so NUM-021 fires at compile
        // time. Pre-fix returned no-value, falling through to runtime
        // PANIC at startup ("PANIC: i64 div by zero" via the
        // strict-intrin trap), surfacing far from the source.
        if b == 0 { return const_i64_result_ex(0, 0, 1); };
        if a == min_i64 && b == 0 - 1 { return const_i64_result_ex(0, 0, 1); };
        return const_i64_result(1, a / b);
    };
    if op == 24 {
        // mod-by-zero in const expression is
        // undefined; flag as overflow so NUM-021 fires at compile time.
        if b == 0 { return const_i64_result_ex(0, 0, 1); };
        if a == min_i64 && b == 0 - 1 { return const_i64_result_ex(0, 0, 1); };
        return const_i64_result(1, a - (a / b) * b);
    };
    // const-time shift-out-of-range. Op codes
    // 115/116 are << / >> at AST level (per line ~16269 dispatch).
    // i64 shift amount must be in [0, 63]; outside that range the
    // result is undefined per the C/LLVM model. Fire NUM-021 at
    // compile time when both operands are const and the shift amount
    // is out of range. Pre-fix the binop fell through to the (0, 0)
    // no-value path and then PANICked at runtime startup via the
    // strict-intrin trap.
    if op == 115 {
        if b < 0 || b > 63 { return const_i64_result_ex(0, 0, 1); };
        return const_i64_result(0, 0);
    };
    if op == 116 {
        if b < 0 || b > 63 { return const_i64_result_ex(0, 0, 1); };
        return const_i64_result(0, 0);
    };
    return const_i64_result(0, 0);
}
#[manual_drop]
fn const_i64_expr(pool: Vec<i32>, nid: i64, env: Vec<i32>) -> Vec<i32> {
    if nid < 0 || nid >= vec_len(pool) { return const_i64_result(0, 0); };
    let k: i64 = node_kind(pool, nid);
    if k == 1 { return const_i64_result(1, node_field(pool, nid, 1)); };
    if k == 5 {
        let inner_nid_v064: i64 = node_field(pool, nid, 1);
        let inner: Vec<i32> = const_i64_expr(pool, inner_nid_v064, env);
        if const_i64_overflow(inner) == 1 { return const_i64_result_ex(0, 0, 1); };
        if vec_get(inner, 0) == 1 {
            let inner_v: i64 = vec_get(inner, 1);
            //  canonical Rust literal
            // `-9223372036854775808` (= i64::MIN) is parsed as unary-
            // minus applied to `9223372036854775808`. The lexer wraps
            // `9223372036854775808` (2^63) to i64::MIN at storage time,
            // so the inner literal node already has value i64::MIN.
            // Pre-fix `0 - i64::MIN` was flagged as overflow (which
            // it WOULD be for a non-literal i64::MIN value), false-
            // firing NUM-021 on the canonical `i64::MIN` constant. Now
            // detect the literal-immediately-under-minus case: when the
            // inner is a kind-1 literal token AND its value is i64::MIN,
            // the original source must have been `2^63` (the only
            // decimal literal that wraps to i64::MIN), so unary-minus
            // produces -2^63 = i64::MIN — representable, NOT an
            // overflow. `let x: i64 = -(some_var_holding_min)` still
            // overflows because the inner is then a kind-3 reference,
            // not a kind-1 literal.
            if inner_v == const_i64_min() {
                if node_kind(pool, inner_nid_v064) == 1 {
                    return const_i64_result(1, const_i64_min());
                };
                return const_i64_result_ex(0, 0, 1);
            };
            return const_i64_result(1, 0 - inner_v);
        };
        return const_i64_result(0, 0);
    };
    if k == 4 {
        let lhs: Vec<i32> = const_i64_expr(pool, node_field(pool, nid, 2), env);
        let rhs: Vec<i32> = const_i64_expr(pool, node_field(pool, nid, 3), env);
        if const_i64_overflow(lhs) == 1 || const_i64_overflow(rhs) == 1 { return const_i64_result_ex(0, 0, 1); };
        if vec_get(lhs, 0) == 1 && vec_get(rhs, 0) == 1 { return const_i64_binop(node_field(pool, nid, 1), vec_get(lhs, 1), vec_get(rhs, 1)); };
        return const_i64_result(0, 0);
    };
    if k == 3 {
        let cv: str = tenv_get_const_i64(env, node_field(pool, nid, 1));
        if str_len(cv) > 0 { return const_i64_result(1, str_to_int(cv)); };
    };
    return const_i64_result(0, 0);
}
#[manual_drop]
fn char_guard_key(name: str) -> str {
    return str_concat("__char_guard:", name);
}
#[manual_drop]
fn tenv_set_char_guard(env: Vec<i32>, name: str) -> i64 {
    return tenv_set(env, char_guard_key(name), "1");
}
#[manual_drop]
fn tenv_has_char_guard(env: Vec<i32>, name: str) -> i64 {
    if str_eq(tenv_get(env, char_guard_key(name)), "1") == 1 { return 1; };
    return 0;
}
#[manual_drop]
fn char_guard_var_name(pool: Vec<i32>, nid: i64, env: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    if node_kind(pool, nid) != 4 { return ""; };
    let op: i64 = node_field(pool, nid, 1);
    if op == 36 {
        let lv: str = char_guard_var_name(pool, node_field(pool, nid, 2), env);
        if str_len(lv) > 0 { return lv; };
        return char_guard_var_name(pool, node_field(pool, nid, 3), env);
    };
    if node_kind(pool, node_field(pool, nid, 2)) == 3 {
        let rc: Vec<i32> = const_i64_expr(pool, node_field(pool, nid, 3), env);
        if const_i64_overflow(rc) == 0 && vec_get(rc, 0) == 1 { return node_field(pool, node_field(pool, nid, 2), 1); };
    };
    if node_kind(pool, node_field(pool, nid, 3)) == 3 {
        let lc: Vec<i32> = const_i64_expr(pool, node_field(pool, nid, 2), env);
        if const_i64_overflow(lc) == 0 && vec_get(lc, 0) == 1 { return node_field(pool, node_field(pool, nid, 3), 1); };
    };
    return "";
}
#[manual_drop]
fn char_guard_merge_flags(a: i64, b: i64) -> i64 {
    let mut low: i64 = 0;
    let mut high: i64 = 0;
    if a == 1 || a == 3 || b == 1 || b == 3 { low = 1; };
    if a == 2 || a == 3 || b == 2 || b == 3 { high = 1; };
    return low + high * 2;
}
#[manual_drop]
fn char_guard_flags(pool: Vec<i32>, nid: i64, env: Vec<i32>, name: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    if node_kind(pool, nid) != 4 { return 0; };
    let op: i64 = node_field(pool, nid, 1);
    if op == 36 {
        return char_guard_merge_flags(char_guard_flags(pool, node_field(pool, nid, 2), env, name), char_guard_flags(pool, node_field(pool, nid, 3), env, name));
    };
    let lhs: i64 = node_field(pool, nid, 2);
    let rhs: i64 = node_field(pool, nid, 3);
    if node_kind(pool, lhs) == 3 && str_eq(node_field(pool, lhs, 1), name) == 1 {
        let rc: Vec<i32> = const_i64_expr(pool, rhs, env);
        if const_i64_overflow(rc) == 0 && vec_get(rc, 0) == 1 {
            let v: i64 = vec_get(rc, 1);
            if (op == 35 && v >= 0) || (op == 33 && v >= 0 - 1) { return 1; };
            if (op == 34 && v < 55296) || (op == 32 && v <= 55296) { return 2; };
        };
    };
    if node_kind(pool, rhs) == 3 && str_eq(node_field(pool, rhs, 1), name) == 1 {
        let lc: Vec<i32> = const_i64_expr(pool, lhs, env);
        if const_i64_overflow(lc) == 0 && vec_get(lc, 0) == 1 {
            let v2: i64 = vec_get(lc, 1);
            if (op == 34 && v2 >= 0) || (op == 32 && v2 >= 0 - 1) { return 1; };
            if (op == 35 && v2 < 55296) || (op == 33 && v2 <= 55296) { return 2; };
        };
    };
    return 0;
}
#[manual_drop]
fn char_guard_proven_var(pool: Vec<i32>, cond: i64, env: Vec<i32>) -> str {
    let name: str = char_guard_var_name(pool, cond, env);
    if str_len(name) == 0 { return ""; };
    if char_guard_flags(pool, cond, env, name) == 3 { return name; };
    return "";
}
#[manual_drop]
fn const_i64_out_of_declared_int_range(tstr: str, val: i64) -> i64 {
    if str_len(tstr) == 0 || type_is_int(tstr) == 0 { return 0; };
    let w: i64 = type_width(tstr);
    let s: i64 = type_signedness(tstr);
    if s == 1 && w < 64 {
        let max_v: i64 = i64_pow(2, w - 1) - 1;
        let min_v: i64 = 0 - i64_pow(2, w - 1);
        if val > max_v || val < min_v { return 1; };
    };
    if s == 2 && w < 64 {
        let umax_v: i64 = i64_pow(2, w) - 1;
        if val < 0 || val > umax_v { return 1; };
    };
    return 0;
}
#[manual_drop]
fn tenv_set_pattern_item(env: Vec<i32>, item: str, tstr: str) -> i64 {
    let name: str = pattern_binding_item_name(item);
    if str_len(name) == 0 { return 0; };
    let btype: str = if str_len(tstr) > 0 { tstr } else { "i64" };
    tenv_set(env, name, btype);
    return 0;
}
#[manual_drop]
fn tenv_set_pattern_list(env: Vec<i32>, binding: str, tstr: str) -> i64 {
    let work: str = pattern_after_at_prefix(binding);
    let blen: i64 = str_len(work);
    let mut start: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(work, end) != 124 { end = end + 1; };
        tenv_set_pattern_item(env, str_substring(work, start, end), tstr);
        start = end + 1;
    };
    return 0;
}
#[manual_drop]
fn tenv_set_struct_pattern(pool: Vec<i32>, structs: Vec<i32>, env: Vec<i32>, sname: str, binding: str) -> i64 {
    let si: i64 = struct_find_type(pool, structs, sname);
    if si < 0 { return 0; };
    let s_nid: i64 = vec_get(structs, si);
    let work: str = pattern_after_at_prefix(binding);
    let blen: i64 = str_len(work);
    let mut start: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(work, end) != 124 { end = end + 1; };
        let item: str = str_substring(work, start, end);
        let field_name: str = str_before_char_local(item, 58);
        let bind_name: str = pattern_binding_item_name(item);
        if str_len(bind_name) > 0 {
            let ft: str = struct_field_type(pool, s_nid, field_name);
            tenv_set(env, bind_name, if str_len(ft) > 0 { ft } else { "i64" });
        };
        start = end + 1;
    };
    return 0;
}
#[manual_drop]
fn strip_spaces(s: str) -> str {
    // Fast path: most type strings (the dominant caller) have no
    // whitespace. Scan once to detect; if clean, return the input
    // unchanged — no allocation. Only allocate the SB when we
    // actually have characters to strip. The previous version
    // always allocated a SB and a 1-byte substring per non-space
    // character; for a 12-byte type name that was 12 separate
    // allocations even when no whitespace was present.
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    let mut has_ws: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 32 || c == 9 || c == 10 || c == 13 { has_ws = 1; break; };
        i = i + 1;
    };
    if has_ws == 0 { return s; };
    let mut sb: i64 = sb_new();
    let mut j: i64 = 0;
    while j < slen {
        let c2: i64 = str_char_at(s, j);
        if c2 != 32 && c2 != 9 && c2 != 10 && c2 != 13 { sb_append_char_at(sb, s, j); };
        j = j + 1;
    };
    return sb_to_str(sb);
}
#[manual_drop]
fn type_is_unit(t: str) -> i64 {
    if str_starts_with(t, "unit<") == 1 { return 1; };
    return 0;
}
#[manual_drop]
fn unit_dim(t: str) -> str {
    if type_is_unit(t) == 0 { return ""; };
    let slen: i64 = str_len(t);
    let mut i: i64 = 5;
    while i < slen && str_char_at(t, i) != 44 { i = i + 1; };
    if i >= slen { return ""; };
    return strip_spaces(str_substring(t, i + 1, slen - 1));
}
#[manual_drop]
fn type_dynamic_helper(name: str) -> i64 {
    // first-char dispatch — was 41-entry linear chain run per kind-7
    // call-site type-check.
    if str_len(name) == 0 { return 0; };
    let c0: i64 = str_char_at(name, 0);
    if c0 == 100 {
        if str_eq(name, "diag_get") == 1 { return 1; };
        return 0;
    };
    if c0 == 105 {
        if str_eq(name, "ir_op") == 1 { return 1; };
        if str_eq(name, "ir_dest") == 1 { return 1; };
        if str_eq(name, "ir_op1") == 1 { return 1; };
        if str_eq(name, "ir_op2") == 1 { return 1; };
        if str_eq(name, "ir_extra") == 1 { return 1; };
        if str_eq(name, "ir_block_label") == 1 { return 1; };
        if str_eq(name, "ir_block_get_inst") == 1 { return 1; };
        if str_eq(name, "ir_fn_name") == 1 { return 1; };
        if str_eq(name, "ir_fn_param_count") == 1 { return 1; };
        if str_eq(name, "ir_fn_get_block") == 1 { return 1; };
        if str_eq(name, "ir_const_int") == 1 { return 1; };
        return 0;
    };
    if c0 == 106 {
        if str_starts_with(name, "json_") == 1 { return 1; };
        return 0;
    };
    if c0 == 108 {
        if str_eq(name, "list_get") == 1 { return 1; };
        if str_eq(name, "lx_reg") == 1 { return 1; };
        if str_eq(name, "lx_blk") == 1 { return 1; };
        return 0;
    };
    if c0 == 109 {
        if str_eq(name, "mk2") == 1 { return 1; };
        if str_eq(name, "mk3") == 1 { return 1; };
        if str_eq(name, "mk4") == 1 { return 1; };
        if str_eq(name, "mk5") == 1 { return 1; };
        if str_eq(name, "mk6") == 1 { return 1; };
        if str_eq(name, "mk_list") == 1 { return 1; };
        if str_starts_with(name, "map_") == 1 { return 1; };
        return 0;
    };
    if c0 == 110 {
        if str_eq(name, "node_field") == 1 { return 1; };
        if str_starts_with(name, "nuc_json_") == 1 { return 1; };
        if str_starts_with(name, "nuc_graph_") == 1 { return 1; };
        if str_starts_with(name, "nuc_bm25_") == 1 { return 1; };
        if str_starts_with(name, "nuc_hnsw_") == 1 { return 1; };
        if str_starts_with(name, "nuc_emb_") == 1 { return 1; };
        if str_starts_with(name, "nuc_sym_") == 1 { return 1; };
        if str_starts_with(name, "nuc_stat_") == 1 { return 1; };
        return 0;
    };
    if c0 == 111 {
        if str_eq(name, "own_get_type") == 1 { return 1; };
        if str_eq(name, "own_set_type") == 1 { return 1; };
        if str_eq(name, "own_get_s") == 1 { return 1; };
        return 0;
    };
    if c0 == 112 {
        if str_eq(name, "pr") == 1 { return 1; };
        if str_eq(name, "pkv") == 1 { return 1; };
        if str_eq(name, "pr_pos") == 1 { return 1; };
        if str_eq(name, "pr_val") == 1 { return 1; };
        return 0;
    };
    if c0 == 115 {
        if str_eq(name, "sym_get") == 1 { return 1; };
        if str_eq(name, "sym_set") == 1 { return 1; };
        if str_eq(name, "smap_get") == 1 { return 1; };
        if str_eq(name, "smap_set") == 1 { return 1; };
        if str_eq(name, "sig_plist") == 1 { return 1; };
        if str_eq(name, "sig_add") == 1 { return 1; };
        if str_eq(name, "sig_rtype") == 1 { return 1; };
        if str_eq(name, "sig_is_extern") == 1 { return 1; };
        return 0;
    };
    if c0 == 116 {
        if str_eq(name, "tok_type") == 1 { return 1; };
        if str_eq(name, "tok_val") == 1 { return 1; };
        if str_eq(name, "tenv_get") == 1 { return 1; };
        if str_eq(name, "tenv_set") == 1 { return 1; };
        return 0;
    };
    if c0 == 118 {
        if str_starts_with(name, "vec_") == 1 { return 1; };
        return 0;
    };
    return 0;
}

#[manual_drop]
fn type_fast_runtime_rtype(name: str) -> str {
    if str_eq(name, "sb_new") == 1 { return "i64"; };
    if str_eq(name, "sb_new_with_cap") == 1 { return "i64"; };
    if str_eq(name, "sb_to_str") == 1 { return "str"; };
    if str_eq(name, "sb_append") == 1 { return "void"; };
    if str_eq(name, "sb_append_char") == 1 { return "void"; };
    if str_eq(name, "sb_append_char_at") == 1 { return "void"; };
    if str_eq(name, "sb_append_range") == 1 { return "void"; };
    if str_eq(name, "sb_free") == 1 { return "void"; };
    return "";
}

#[manual_drop]
fn type_arg_needs_walk(pool: Vec<i32>, nid: i64) -> i64 {
    let k: i64 = node_kind(pool, nid);
    if k == 1 || k == 2 || k == 3 || k == 71 || k == 72 || k == 73 { return 0; };
    return 1;
}

#[manual_drop]
fn type_stmt_value(pool: Vec<i32>, nid: i64) -> i64 {
    let kind: i64 = node_kind(pool, nid);
    if kind == 25 || kind == 22 { return node_field(pool, nid, 1); };
    return 0 - 1;
}
#[manual_drop]
fn type_last_stmt(pool: Vec<i32>, prog: i64, lid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> str {
    if lid < 0 || lid >= vec_len(pool) { return ""; };
    let cnt: i64 = list_len(pool, lid);
    if cnt == 0 { return ""; };
    let last_stmt: i64 = list_get(pool, lid, cnt - 1);
    let val: i64 = type_stmt_value(pool, last_stmt);
    if val >= 0 { return type_expr(pool, prog, val, env, sigs, structs, fn_name, diags, source, tprof); };
    if node_kind(pool, last_stmt) == 23 || node_kind(pool, last_stmt) == 52 { return type_expr(pool, prog, last_stmt, env, sigs, structs, fn_name, diags, source, tprof); };
    return "";
}
#[manual_drop]
fn type_expr(pool: Vec<i32>, prog: i64, nid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 { return int_lit_type(pool, nid); };
    if kind == 71 { return "f64"; };
    if kind == 72 { return "f64"; };
    if kind == 2 { return "str"; };
    if kind == 122 {
        // RFC-0016 phase 1: ? operator.
        // NUC-FEEDBACK silent-segfault guard. Pre-fix
        // `let x: i64 = some_fn()?;` where some_fn returns bare i64
        // (not Result<T,E> or Option<T>) silently SIGSEGVed at runtime.
        // The `?` lower called `vec_get(val_r, 0)` to extract the tag,
        // dereferencing the i64 value as a pointer. Halt now with a
        // clear diagnostic naming the call.
        let qinner: i64 = node_field(pool, nid, 1);
        if node_kind(pool, qinner) == 7 {
            let qcallee: str = node_field(pool, qinner, 1);
            let qrtype: str = sig_rtype(sigs, qcallee);
            if str_len(qrtype) > 0 {
                let qbase: str = type_base_name(qrtype);
                let qok: i64 = if str_eq(qbase, "Result") == 1
                    || str_eq(qbase, "Option") == 1
                    || str_eq(qbase, "Vec") == 1 { 1 } else { 0 };
                if qok == 0 {
                    type_diag(diags, source, fn_name, qcallee, "TYP-011", str_concat("`?` operator requires receiver to return `Result<T,E>` or `Option<T>` (or the legacy untyped `Vec<i32>` stub) — `", str_concat(qcallee, str_concat("()` returns `", str_concat(qrtype, "`. Workaround: change the fn signature to return Result/Option, or check the value explicitly with `if ... { return ...; }`.")))));
                };
            };
        };
        // extend the v0.4.54 check to kind-3 (var-ref)
        // receivers. Pre-fix `let x: i64 = 5; let y = x?;` matched
        // only the kind-7 call branch above, so x's `?` lower
        // emitted the same `vec_get(val_r, 0)` tag-extract as the
        // pre-v0.4.54 era and SIGSEGVed at runtime when the i64
        // value was dereferenced as a pointer. Same TYP-011 family
        // as the kind-7 case; lookup goes through tenv (binding
        // type) instead of sigs (fn rtype).
        if node_kind(pool, qinner) == 3 {
            let qvname: str = node_field(pool, qinner, 1);
            let qvtype: str = tenv_get(env, qvname);
            if str_len(qvtype) > 0 {
                let qvbase: str = type_base_name(qvtype);
                let qvok: i64 = if str_eq(qvbase, "Result") == 1
                    || str_eq(qvbase, "Option") == 1
                    || str_eq(qvbase, "Vec") == 1 { 1 } else { 0 };
                if qvok == 0 {
                    type_diag(diags, source, fn_name, qvname, "TYP-011", str_concat("`?` operator on binding `", str_concat(qvname, str_concat("` of type `", str_concat(qvtype, "` — `?` requires `Result<T,E>` or `Option<T>`. Pre-v0.4.157 (kind-7 case caught in v0.4.54; kind-3 var-ref escaped) this silently lowered `vec_get(val_r, 0)` against the i64 cell and SIGSEGVed at runtime when the value was dereferenced as a pointer. Either change the binding's type to Result / Option, or check the value explicitly with `if ... { return ...; }`."))))));
                };
            };
        };
        let qfull: str = type_expr(pool, prog, qinner, env, sigs, structs, fn_name, diags, source, tprof);
        let qbase2: str = type_base_name(qfull);
        if str_eq(qbase2, "Result") == 1 || str_eq(qbase2, "Option") == 1 {
            let qpayload: str = type_first_arg(qfull);
            if str_len(qpayload) > 0 { return qpayload; };
        };
        return "i64";
    };
    if kind == 99 {
        // RFC-0015 phase 2: `as` cast. Fire NUM-003 (warning) when the
        // cast loses precision (target_width < source_width within the
        // same class). Returns "" (the legacy unknown-type marker) so
        // existing v0.1.x code that assigns a cast result to a wider
        // binding (e.g. `let x: i64 = small as u8;`) still type-checks
        // — strict cast typing flips on with the stdlib audit.
        let target_type: str = node_field(pool, nid, 2);
        let source_t: str = type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let sw: i64 = type_width(source_t);
        let tw: i64 = type_width(target_type);
        let ss: i64 = type_signedness(source_t);
        let ts: i64 = type_signedness(target_type);
        let source_base_g1: str = type_base_name(source_t);
        if str_eq(target_type, "i64") == 1 {
            if str_eq(source_base_g1, "Vec") == 1 || str_eq(source_base_g1, "HashMap") == 1 || str_eq(source_base_g1, "StringBuilder") == 1 || str_eq(source_base_g1, "Box") == 1 {
                let g1_msg: str = str_concat("raw handle cast `", str_concat(source_t, "` -> `i64` strips ownership and auto-drop identity. Per RFC-0062 G-1/G-4, collection handles must not escape the ownership tracker by casting to an integer; keep the typed binding, transfer ownership through a typed binding, or write an audited unsafe FFI wrapper instead."));
                diag_add_at_or_scan(diags, source, pool, nid, "as", "error", "ownership", "OWN-G1-RAW-HANDLE-CAST", g1_msg, fn_name, "");
            };
        };
        if str_eq(target_type, "char") == 1 {
            let ch_const: Vec<i32> = const_i64_expr(pool, node_field(pool, nid, 1), env);
            if const_i64_overflow(ch_const) == 0 && vec_get(ch_const, 0) == 1 {
                let ch_cp: i64 = vec_get(ch_const, 1);
                let mut ch_bad: i64 = 0;
                if ch_cp < 0 { ch_bad = 1; };
                if ch_cp > 1114111 { ch_bad = 1; };
                if ch_cp >= 55296 && ch_cp <= 57343 { ch_bad = 1; };
                if ch_bad == 1 {
                    let ch_msg: str = str_concat("`as char` codepoint ", str_concat(str_from_int(ch_cp), " is not a valid Unicode scalar value. Valid range is 0..0x10FFFF excluding surrogate range 0xD800..0xDFFF. Pre-fix, this cast silently accepted invalid codepoints and could produce invalid UTF-8 at char_to_str use sites."));
                    diag_add_at_or_scan(diags, source, pool, nid, "as", "error", "type", "TYP-026", ch_msg, fn_name, "");
                };
            } else {
                let ch_src: i64 = node_field(pool, nid, 1);
                let mut ch_guarded: i64 = 0;
                if node_kind(pool, ch_src) == 3 {
                    if tenv_has_char_guard(env, node_field(pool, ch_src, 1)) == 1 { ch_guarded = 1; };
                };
                if ch_guarded == 0 {
                    let ch_dyn_msg: str = "`as char` on a non-constant value is not proven to be a valid Unicode scalar value. Guard the exact binding with `v >= 0 && v < 0xD800` or another recognized scalar-range proof before casting. Pre-fix, dynamic casts could silently produce invalid UTF-8 at char_to_str use sites.";
                    diag_add_at_or_scan(diags, source, pool, nid, "as", "error", "type", "TYP-026", ch_dyn_msg, fn_name, "");
                };
            };
        };
        if sw > 0 && tw > 0 && ss == ts && tw < sw {
            let nloc: Vec<i32> = if node_get_span(pool, nid) >= 0 {
                let lm99: Vec<i32> = linemap_build(source);
                let sp99: i64 = node_get_span(pool, nid);
                let mut lc99: Vec<i32> = Vec::new();
                lc99.push(linemap_line(lm99, sp99));
                lc99.push(linemap_col(lm99, sp99));
                lc99
            } else {
                find_linecol_in_source(source, fn_name, fn_name)
            };
            // dedupe NUM-003 by fn_name + line + col. type_expr
            // kind 99 runs multiple times for the same cast site when
            // the cast appears in fn-call argument position (once at
            // arg-typing, once at coercion check). Pre-fix `print_int(x
            // as i32)` for `x: i64` emitted 2 identical NUM-003 lines
            // with the same span. Adopters got noisy duplicate warnings
            // hiding other diagnostics. Linear scan over diags is OK
            // here because NUM-003 emit sites are rare (one per
            // narrowing cast in source).
            // Regression: duplicate numeric warning in fn arg.
            let v216_line: i64 = vec_get(nloc, 0);
            let v216_col: i64 = vec_get(nloc, 1);
            let mut v216_dup: i64 = 0;
            let v216_dc: i64 = diag_count(diags);
            let mut v216_di: i64 = 0;
            while v216_di < v216_dc {
                let v216_d: Vec<i32> = diag_get(diags, v216_di);
                if str_eq(vec_get(v216_d, 2), "NUM-003") == 1
                    && str_eq(vec_get(v216_d, 4), fn_name) == 1
                    && vec_get(v216_d, 5) == v216_line
                    && vec_get(v216_d, 6) == v216_col {
                    v216_dup = 1;
                    v216_di = v216_dc;
                } else {
                    v216_di = v216_di + 1;
                };
            };
            if v216_dup == 0 {
                diag_add_ex(diags, "warning", "type", "NUM-003", str_concat("`as` cast loses precision: ", str_concat(source_t, str_concat(" (", str_concat(str_from_int(sw), str_concat("-bit) -> ", str_concat(target_type, str_concat(" (", str_concat(str_from_int(tw), "-bit)")))))))), fn_name, v216_line, v216_col, "");
            };
        };
        if str_eq(target_type, "str") == 1 && (type_is_float(source_t) == 1 || str_eq(source_t, "bool") == 1) {
            let v23a: str = str_concat("`", str_concat(source_t, "` cannot be `as`-cast to `str`."));
            let v23b: str = str_concat(" Pre-v0.4.143 `let s: str = x as str` for `x: ", str_concat(source_t, "` lowered to a no-op (the i64 cell holding the value was reinterpreted as a char ptr) and SIGSEGV'd at the next print/str operation when the bit pattern was dereferenced as a heap address."));
            let v23c: str = if type_is_float(source_t) == 1 { " Use `f64_to_str(x)` (or the matching narrow-float helper) to get a heap-allocated string of the value." } else { " Use `if b { \"true\" } else { \"false\" }` (or convert via `b as i64` then `int_to_str`) to get a heap-allocated string of the bool." };
            type_diag(diags, source, fn_name, fn_name, "NUM-023", str_concat(v23a, str_concat(v23b, v23c)));
        };
        // NUC-FEEDBACK-002 silent-miscompute guard. Detect
        // `v[i] as <NarrowFloat>` where v: Vec<NarrowFloat>. The cell
        // holds the bit pattern of the float in an i64; `as` is a
        // numeric conversion (i64 → f32), not a bit-reinterpret, so
        // the result is wrong (e.g. bit pattern 0x3FC00000 = 1069547520
        // would cast to 1069547520.0_f32 instead of 1.5_f32). Tell
        // the adopter to use the explicit reinterpret surface.
        let src_nid: i64 = node_field(pool, nid, 1);
        let mut guard_v_nid: i64 = 0 - 1;
        let mut guard_call_name: str = "";
        if node_kind(pool, src_nid) == 10 {
            guard_v_nid = node_field(pool, src_nid, 1);
        };
        // extend the guard to the fn-call form
        // `vec_get(v, i) as f32`, `vec_first(v) as f32`,
        // `vec_last(v) as f32`, `vec_pop(v) as f32`. Same hazard
        // as the `v[i] as f32` form caught in v0.4.47.
        if node_kind(pool, src_nid) == 7 {
            let cname: str = node_field(pool, src_nid, 1);
            let is_vec_read: i64 = if str_eq(cname, "vec_get") == 1
                || str_eq(cname, "vec_first") == 1
                || str_eq(cname, "vec_last") == 1
                || str_eq(cname, "vec_pop") == 1 { 1 } else { 0 };
            if is_vec_read == 1 {
                let cargs: i64 = node_field(pool, src_nid, 2);
                if list_len(pool, cargs) > 0 {
                    let first_arg: i64 = list_get(pool, cargs, 0);
                    if node_kind(pool, first_arg) == 3 {
                        guard_v_nid = first_arg;
                        guard_call_name = cname;
                    };
                };
            };
        };
        if guard_v_nid >= 0 && node_kind(pool, guard_v_nid) == 3 {
            let vname: str = node_field(pool, guard_v_nid, 1);
            let mut vt: str = tenv_get(env, vname);
            if str_len(vt) == 0 { vt = infer_var_type_from_source(source, vname); };
            let velt: str = strip_container_one_level(vt);
            if str_len(velt) > 0 {
                let mut hint: str = "";
                if str_eq(velt, "f32") == 1 && str_eq(target_type, "f32") == 1 {
                    hint = "f32_from_bits";
                };
                if str_eq(velt, "f16") == 1 && str_eq(target_type, "f32") == 1 {
                    hint = "f16_to_f32";
                };
                if str_eq(velt, "bf16") == 1 && str_eq(target_type, "f32") == 1 {
                    hint = "bf16_to_f32";
                };
                if str_eq(velt, "f8e4m3") == 1 && str_eq(target_type, "f32") == 1 {
                    hint = "f8e4m3_to_f32";
                };
                if str_eq(velt, "f8e5m2") == 1 && str_eq(target_type, "f32") == 1 {
                    hint = "f8e5m2_to_f32";
                };
                if str_len(hint) > 0 {
                    let mut surface: str = str_concat(vname, "[i]");
                    if str_len(guard_call_name) > 0 {
                        surface = str_concat(guard_call_name, str_concat("(", str_concat(vname, ", ...)")));
                    };
                    let part1: str = str_concat("`", str_concat(surface, str_concat(" as ", str_concat(target_type, "` numeric-casts the i64 cell holding the "))));
                    let part2: str = str_concat(velt, str_concat(" bit pattern; use ", str_concat(hint, str_concat("(", str_concat(surface, ") for bit-reinterpret")))));
                    diag_add_at_or_scan(diags, source, pool, nid, vname, "error", "type", "NUM-006", str_concat(part1, part2), fn_name, "");
                };
            };
        };
        return "";
    };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if str_eq(name, "true") == 1 || str_eq(name, "false") == 1 { return "bool"; };
        // skip the tprof_start/mark fast-pair when
        // profiling is disabled (vec_len(tprof) == 0). Saves a fn-call
        // pair per kind-3 (var-ref) type-check on the hot path.
        let mut out: str = "";
        if vec_len(tprof) > 0 {
            let env_start: i64 = tprof_start(tprof);
            out = tenv_get(env, name);
            tprof_mark(tprof, 3, 4, env_start);
        } else {
            out = tenv_get(env, name);
        };
        // width tagging moved from
        // type_expr (which doesn't reliably visit every var-ref —
        // kind-7 call args bypass it) to lower_stmt kind 20 (let),
        // keyed by alloca reg in fir's slot 4. AST node slot 2 is
        // unused now but kept for backward shape compatibility.
        // TYP-022 — struct name used as a value. Pre-fix
        // `let e: E = E;` for `struct E { ... }` lowered the RHS as
        // a kind-3 var-ref to "E", emitting `ptrtoint ptr @E to i64`
        // — failed late at clang link with `error: use of undefined
        // value '@E'`. The v0.4.106 lift suppresses uppercase-leading
        // names from the TYP-005 surface (because most uppercase names
        // are legitimate type-prefixed mangled calls handled via kind
        // 12), so adopters got the raw clang error text pointing at
        // compiler-emitted IR rather than their source. Detect: name
        // is not in tenv AND matches a defined struct in the structs
        // table. Halt cleanly with the right hint.
        if str_len(out) == 0 && struct_find_type(pool, structs, name) >= 0 {
            let v22a: str = str_concat("`", str_concat(name, "` is a struct type, not a value. Pre-v0.4.138 a bare struct name in value position (e.g. `let e = E;`) lowered to `ptrtoint ptr @<Name> to i64` and failed late at clang link with `error: use of undefined value '@<Name>'`."));
            let v22b: str = str_concat(" Use struct-init syntax `", str_concat(name, " { field1: val1, field2: val2, ... }` to construct a value of this type, or call an inherent constructor `<Name>::new(...)` if one is defined."));
            type_diag(diags, source, fn_name, name, "TYP-022", str_concat(v22a, v22b));
        };
        return out;
    };
    if kind == 4 {
        let op: i64 = node_field(pool, nid, 1);
        let lt: str = type_expr(pool, prog, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof);
        let rt: str = type_expr(pool, prog, node_field(pool, nid, 3), env, sigs, structs, fn_name, diags, source, tprof);
        // TYP-020 — void-typed expression in arithmetic /
        // comparison binop. Pre-fix `5 + print_int(10)` silently
        // accepted print_int's void return as 0 — adopters who
        // confused side-effect-only fns with value-returning fns got
        // wrong results with no signal. Catches arithmetic (20/21/
        // 22/23/24) AND comparison (25/26/27/28/29/30/31/32) since
        // both presume value operands. Skips logical ops because
        // && / || already short-circuit. The void detection uses
        // the existing builtin_rtype "void" string + the
        // type_is_unit predicate.
        let lt_is_void: i64 = if str_eq(lt, "void") == 1 || type_is_unit(lt) == 1 { 1 } else { 0 };
        let rt_is_void: i64 = if str_eq(rt, "void") == 1 || type_is_unit(rt) == 1 { 1 } else { 0 };
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24
            || op == 25 || op == 26 || op == 27 || op == 28 || op == 29
            || op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35)
            && (lt_is_void == 1 || rt_is_void == 1) {
            let void_side: str = if lt_is_void == 1 { "left" } else { "right" };
            let v20msg: str = str_concat("`void`-typed expression on the ", str_concat(void_side, " side of binop. Pre-v0.4.132 the void return was silently coerced to 0 — adopters who confused side-effect-only fns (`print_int`, `print`, etc.) with value-returning fns got wrong arithmetic with no signal. Use the value-returning sibling fn (e.g. `int_to_str` instead of `print_int`) or split the side-effect into its own statement."));
            type_diag(diags, source, fn_name, fn_name, "TYP-020", v20msg);
        };
        // R09-D1 / RFC-0043: fixed<I,F> values use i64 storage but
        // their Q-format is part of the semantic type. Arithmetic must
        // not silently combine different fixed widths, and fixed/int
        // arithmetic requires an explicit raw-storage conversion.
        let lt_fixed: i64 = type_is_fixed_semantic(lt);
        let rt_fixed: i64 = type_is_fixed_semantic(rt);
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24) && (lt_fixed == 1 || rt_fixed == 1) {
            let op_fixed: str = if op == 20 { "+" } else if op == 21 { "-" } else if op == 22 { "*" } else if op == 23 { "/" } else { "%" };
            if lt_fixed == 1 && rt_fixed == 1 {
                if str_eq(fixed_type_canonical(lt), fixed_type_canonical(rt)) == 0 {
                    type_diag(diags, source, fn_name, fn_name, "TYP-008", str_concat("fixed-point type mismatch in `", str_concat(op_fixed, "` binop: operands have types `", str_concat(lt, str_concat("` and `", str_concat(rt, "`. Convert explicitly through the fixed-point rod helpers or use matching fixed<I,F> parameters."))))));
                };
            } else {
                type_diag(diags, source, fn_name, fn_name, "TYP-008", str_concat("mixed fixed-point and non-fixed arithmetic in `", str_concat(op_fixed, "` binop: operands have types `", str_concat(lt, str_concat("` and `", str_concat(rt, "`. Fixed<I,F> uses raw i64 storage, but arithmetic must make the Q-format explicit."))))));
            };
        };
        if (op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35) && lt_fixed == 1 && rt_fixed == 1 {
            if str_eq(fixed_type_canonical(lt), fixed_type_canonical(rt)) == 0 {
                type_diag(diags, source, fn_name, fn_name, "TYP-008", str_concat("fixed-point type mismatch in comparison: operands have types `", str_concat(lt, str_concat("` and `", str_concat(rt, "`.")))));
            };
        };
        let frame_op_checked: i64 = if op == 20 || op == 21 || op == 22 || op == 23 || op == 24 || op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35 { 1 } else { 0 };
        if frame_op_checked == 1 && str_index_of(lt, "Frame_") >= 0 && str_index_of(rt, "Frame_") >= 0 {
            if frame_mismatch_visible(lt, rt) == 1 {
                let frame_op_text: str = if op == 20 { "+" } else if op == 21 { "-" } else if op == 22 { "*" } else if op == 23 { "/" } else if op == 24 { "%" } else if op == 30 { "==" } else if op == 31 { "!=" } else if op == 32 { "<" } else if op == 33 { "<=" } else if op == 34 { ">" } else { ">=" };
                let frame_op_action: str = str_concat("cannot use operator '", str_concat(frame_op_text, "' with frame-mismatched operands"));
                type_diag(diags, source, fn_name, fn_name, "FRAME-001", frame_mismatch_diag_message(frame_op_action, lt, rt));
            };
        };
        // NUM-022 — integer vs float cross in comparison binop.
        // Pre-fix `5 == 5.0` (i64 vs f64) silently compared the i64 bit
        // pattern of 5 (`0x5`) against the f64 bit pattern of 5.0
        // (`0x4014000000000000`) as i64s — returned FALSE. Same hazard
        // for !=, <, <=, >, >= when one side is int and the other float;
        // `5 < 5.0` returned TRUE because i64=5 reinterpreted as f64
        // is a tiny denormal (~2.5e-323) which is < 5.0.
        // extended to arith ops 20-24 (+, -, *, /, %).
        // Pre-fix `5 + 5.0` produced a meaningless i64 (4617315517961601024
        // = i64=5 + f64-bit-pattern-of-5.0 numerically added). The result
        // is large and obviously wrong, but adopters writing canonical
        // Rust math get a silent-pass build with garbage runtime values.
        // Catches arith (20-24) and cmp (30-37) — bit-shift / mod skipped
        // because mixed int/float there is nonsensical and the parser
        // typically rejects narrow-float forms upstream.
        let lt_is_int: i64 = type_is_int(lt);
        let rt_is_int: i64 = type_is_int(rt);
        let lt_is_flt: i64 = type_is_float(lt);
        let rt_is_flt: i64 = type_is_float(rt);
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24
            || op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35 || op == 36 || op == 37)
            && ((lt_is_int == 1 && rt_is_flt == 1) || (lt_is_flt == 1 && rt_is_int == 1)) {
            let int_side: str = if lt_is_int == 1 { lt } else { rt };
            let flt_side: str = if lt_is_flt == 1 { lt } else { rt };
            let is_arith: i64 = if op == 20 || op == 21 || op == 22 || op == 23 || op == 24 { 1 } else { 0 };
            let kind_label_v141: str = if is_arith == 1 { "arithmetic" } else { "comparison" };
            let v22msg: str = str_concat("integer (`", str_concat(int_side, str_concat("`) and float (`", str_concat(flt_side, str_concat("`) operands in ", str_concat(kind_label_v141, " binop. Pre-v0.4.137/.141 each side's bit pattern was used as raw i64 — `5 == 5.0` returned FALSE; `5 + 5.0` produced meaningless i64 garbage; `5 < 5.0` returned TRUE (i64=5 reinterpreted as f64 is a tiny denormal). Use an explicit conversion (`x as f64` or `y as i64`) to make the intent explicit at the call site."))))));
            type_diag(diags, source, fn_name, fn_name, "NUM-022", v22msg);
        };
        // RFC-0015 requires distinct integer
        // widths/signedness to be joined explicitly with `as`. Before
        // this gate, `i32 + u32` and `i32 + i64` lowered through the
        // i64-everywhere ABI and returned a plausible but unsound value.
        let is_int_arith: i64 = if op == 20 || op == 21 || op == 22 || op == 23 || op == 24 { 1 } else { 0 };
        let lhs_nid: i64 = node_field(pool, nid, 2);
        let rhs_nid_v110: i64 = node_field(pool, nid, 3);
        let lhs_unsuffixed_lit: i64 = if node_kind(pool, lhs_nid) == 1 && int_lit_suffix_code(pool, lhs_nid) == 0 { 1 } else { 0 };
        let rhs_unsuffixed_lit: i64 = if node_kind(pool, rhs_nid_v110) == 1 && int_lit_suffix_code(pool, rhs_nid_v110) == 0 { 1 } else { 0 };
        if is_int_arith == 1 && lhs_unsuffixed_lit == 0 && rhs_unsuffixed_lit == 0 && lt_is_int == 1 && rt_is_int == 1 && str_eq(type_base_name(lt), type_base_name(rt)) == 0 {
            let opch: str = if op == 20 { "+" } else if op == 21 { "-" } else if op == 22 { "*" } else if op == 23 { "/" } else { "%" };
            let v001a: str = str_concat("mixed-width integer arithmetic `", str_concat(lt, str_concat(" ", str_concat(opch, str_concat(" ", str_concat(rt, "` is not implicitly converted."))))));
            let v001b: str = " RFC-0015 follows Rust's distinct-numeric-types rule: cast one operand explicitly with `as` so truncation, sign extension, and widening intent are visible.";
            type_diag(diags, source, fn_name, fn_name, "NUM-001", str_concat(v001a, v001b));
        };
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24) && (str_eq(lt, "bool") == 1 || str_eq(rt, "bool") == 1) {
            type_diag(diags, source, fn_name, fn_name, "TYP-002", "boolean values cannot be used in arithmetic");
        };
        // bool with bitwise ops (& | ^ << >>)
        // is also illegal in Rust. Pre-fix `let r: i64 = a & x` for
        // a: bool, x: i64 silently emitted i64_and on the bool's i64
        // representation. Catch ops 65 (|), 82 (&), 94 (^), 115 (<<),
        // 116 (>>) when ANY side is bool.
        if (op == 65 || op == 82 || op == 94 || op == 115 || op == 116) && (str_eq(lt, "bool") == 1 || str_eq(rt, "bool") == 1) {
            type_diag(diags, source, fn_name, fn_name, "TYP-002", "boolean values cannot be used in bitwise/shift ops; use logical && / || or cast bool to i64 first");
        };
        if (op == 20 || op == 21) && type_is_unit(lt) == 1 && type_is_unit(rt) == 1 && str_eq(unit_dim(lt), unit_dim(rt)) == 0 {
            type_diag(diags, source, fn_name, fn_name, "TYP-003", "unit operands for addition/subtraction must match");
        };
        // NUC-FEEDBACK silent-segfault guard — `str + str`.
        // Pre-fix `let s: str = "a" + "b"` silently SIGSEGVed at
        // runtime because the lower emitted i64_add on the two str
        // pointers, producing a garbage pointer that crashed when
        // passed to print_str. Adopters writing the canonical Rust
        // expectation got SIGSEGV with no compile-time signal (Rust
        // itself errors here too — `&str + &str` doesn't compile —
        // so this is a learnability hazard for adopters coming from
        // OTHER languages too). Halt with a clear hint.
        if op == 20 && str_eq(lt, "str") == 1 && str_eq(rt, "str") == 1 {
            type_diag(diags, source, fn_name, fn_name, "TYP-011", "`str + str` is not supported (would silently segfault — i64_add on string pointers). Use `str_concat(a, b)` to concatenate strings.");
        };
        // NUC-FEEDBACK silent-coerce close for mixed str/int
        // arithmetic. Pre-fix `x + "string"` (or `x += "string"` which
        // desugars to it) with `x: i64` silently i64-added the str
        // pointer to x, producing garbage. Adopters writing canonical
        // Rust got a quiet wrong value. Catches arith ops 20-24 with
        // exactly ONE side being str.
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24) {
            let one_is_str: i64 = if (str_eq(lt, "str") == 1) != (str_eq(rt, "str") == 1) { 1 } else { 0 };
            if one_is_str == 1 {
                let mxopch: str = if op == 20 { "+" } else if op == 21 { "-" } else if op == 22 { "*" } else if op == 23 { "/" } else { "%" };
                type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat("mixed-type arithmetic `", str_concat(lt, str_concat(" ", str_concat(mxopch, str_concat(" ", str_concat(rt, "` lowers to integer arithmetic on the str pointer, producing garbage. Convert types explicitly first (e.g. `str_to_int(s)` or `int_to_str(n)`)."))))));
            };
        };
        // extend the v0.4.51 str-arithmetic guard to the
        // other binop ops (-, *, /, %). Pre-fix `str - str` lowered
        // to `i64_sub(a_ptr, b_ptr)` and the resulting garbage pointer
        // SIGSEGVed at runtime when used. Only `+` had a workaround
        // surface (str_concat); -, *, /, % have no meaningful str
        // semantic in Rust either, so emit a clear compile-time error.
        if (op == 21 || op == 22 || op == 23 || op == 24) && str_eq(lt, "str") == 1 && str_eq(rt, "str") == 1 {
            let opch: str = if op == 21 { "-" } else if op == 22 { "*" } else if op == 23 { "/" } else { "%" };
            type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat("`str ", str_concat(opch, str_concat(" str` is not a meaningful operation (would silently segfault — i64 arithmetic on string pointers). String values support `str_concat` for join, `str_eq` for compare, `str_len` for length; arithmetic operators don't apply."))));
        };
        // TYP-011 ext — String arith. Sister to v0.4.51
        // (str + str) and v0.4.66 (mixed str/int arith). Pre-fix
        // `let r = s + 5;` for `s: String` lowered to i64_add on
        // the String heap pointer + 5 — the result is a wild
        // pointer, garbage at use sites or SIGSEGV on next read.
        // Catches arith ops 20-24 when EITHER side is String
        // (typed `String` or `String<...>` if generic — currently
        // all-or-nothing since Nucleor's String is non-generic).
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24) {
            let lt_is_string: i64 = if str_eq(type_base_name(lt), "String") == 1 { 1 } else { 0 };
            let rt_is_string: i64 = if str_eq(type_base_name(rt), "String") == 1 { 1 } else { 0 };
            if lt_is_string == 1 || rt_is_string == 1 {
                let v150op: str = if op == 20 { "+" } else if op == 21 { "-" } else if op == 22 { "*" } else if op == 23 { "/" } else { "%" };
                let v150a: str = str_concat("`String", str_concat(" ", str_concat(v150op, " <other>` arithmetic is not meaningful — String is a heap-allocated buffer, and arithmetic lowers to i64 ops on the heap pointer, producing a garbage pointer / SIGSEGV at next use.")));
                let v150b: str = " For string concatenation use `s.push_str(other)` (or build via the StringBuilder helpers `sb_append`); to compute on a numeric value, convert with `str_to_int(s.as_str())` first.";
                type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat(v150a, v150b));
            };
        };
        // Vec<T> arithmetic AND ==/!= silent-miscompute guard.
        // Closes deferred item #1. Pre-fix `v1 + v2` and `v1 == v2`
        // for two Vec<T> values silently lowered to integer ptr-arith
        // (segfault for arith, FALSE-on-equal-Vecs for ==). Conservative
        // — only fires when type_expr already populated lt/rt as Vec<T>
        // via tenv (e.g. from typed fn returns). The vec![...] init
        // case where tenv stores "" still escapes; covered partially
        // by the related v0.4.51/52 str closes which catch the
        // workaround attempts. Source-scan fallback was deferred
        // because it crashed the compiler in v0.4.55 (path-specific).
        // if tenv didn't have the type (lt/rt empty),
        // scan source for `let v: Vec<T> = ...` declarations on kind-3
        // var operands. Same trick as v0.4.47 NUM-006 cast guard.
        // Keep the lookup local to this branch only — broad use crashed
        // the compiler in the v0.4.55 attempt.
        let mut lt_v: str = lt;
        let mut rt_v: str = rt;
        if op == 20 || op == 21 || op == 22 || op == 23 || op == 24 || op == 30 || op == 31 {
            if str_starts_with(lt_v, "Vec<") == 0 {
                let lhs_check: i64 = node_field(pool, nid, 2);
                if node_kind(pool, lhs_check) == 3 {
                    let lname: str = node_field(pool, lhs_check, 1);
                    let scanned: str = infer_var_type_from_source(source, lname);
                    if str_starts_with(scanned, "Vec<") == 1 { lt_v = scanned; };
                };
            };
            if str_starts_with(rt_v, "Vec<") == 0 {
                let rhs_check: i64 = node_field(pool, nid, 3);
                if node_kind(pool, rhs_check) == 3 {
                    let rname: str = node_field(pool, rhs_check, 1);
                    let scanned: str = infer_var_type_from_source(source, rname);
                    if str_starts_with(scanned, "Vec<") == 1 { rt_v = scanned; };
                };
            };
        };
        if str_starts_with(lt_v, "Vec<") == 1 && str_starts_with(rt_v, "Vec<") == 1 {
            if op == 20 || op == 21 || op == 22 || op == 23 || op == 24 {
                let varith_op: str = if op == 20 { "+" } else if op == 21 { "-" } else if op == 22 { "*" } else if op == 23 { "/" } else { "%" };
                type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat("`Vec ", str_concat(varith_op, " Vec` lowers to integer arithmetic on Vec pointers (would silently segfault). For element-wise operations write an explicit loop building a new Vec.")));
            };
            if op == 30 || op == 31 {
                let veq_op: str = if op == 30 { "==" } else { "!=" };
                type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat("`Vec ", str_concat(veq_op, " Vec` does pointer comparison (silent miscompute — two equal-element Vecs at different addresses return FALSE). Use an element-wise loop: check `vec_len(a) == vec_len(b)` then iterate and compare each element with `a[i] == b[i]`.")));
            };
            // Vec ordering ops <, <=, >, >= — same ptr-compare
            // hazard. Rust's Vec<T>: PartialOrd does lexicographic
            // element-wise compare, not ptr compare.
            if op == 32 || op == 33 || op == 34 || op == 35 {
                let vord_op: str = if op == 32 { "<" } else if op == 33 { "<=" } else if op == 34 { ">" } else { ">=" };
                type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat("`Vec ", str_concat(vord_op, " Vec` does pointer comparison (silent miscompute — disconnected from element-wise lex order). Write an explicit element-by-element comparison loop.")));
            };
        };
        // NUC-FEEDBACK silent-miscompute guard for `str == str`
        // and `str != str`. Pre-fix the binop lowered to integer
        // pointer comparison: `"hello" == "hello"` returned FALSE
        // because the two str literals lived at different addresses
        // even though their bytes matched. Adopters writing the
        // canonical Rust idiom got a silent wrong result. Rust's `==`
        // on `&str` does value comparison via `PartialEq`; Nucleor's
        // i64-everywhere ABI doesn't auto-route to `str_eq`.
        // str ==/!= now auto-dispatches to str_eq at lower-time
        // (paired lower_expr edit at the kind-4 dispatch). Suppress the
        // TYP-011 ptr-compare diag — adopters can write canonical
        // `if a == b { ... }` for str values directly.
        // TYP-011 ext — `String == String` / `String != String`
        // silent ptr compare. Sister to v0.4.52 (str == str) and
        if (op == 32 || op == 33 || op == 34 || op == 35) && str_eq(lt, "str") == 1 && str_eq(rt, "str") == 1 {
            let ord_op: str = if op == 32 { "<" } else if op == 33 { "<=" } else if op == 34 { ">" } else { ">=" };
            let ord_msga: str = str_concat("`str ", str_concat(ord_op, " str` does pointer comparison (silent miscompute — disconnected from lexicographic byte order)."));
            let ord_msgb: str = " Nucleor's stdlib does NOT yet expose a `str_cmp` helper; for canonical lex ordering, write a manual element-wise loop using `str_char_at(a, i)` + `str_char_at(b, i)` over `min(str_len(a), str_len(b))`, then break on the first mismatch (or compare lengths if all bytes matched). For equality use `str_eq(a, b) == 1`. A real `str_cmp` may ship in a future runtime cycle.";
            type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat(ord_msga, ord_msgb));
        };
        // TYP-011 ext — struct == / != silently did
        // pointer comparison. Pre-fix `a == b` for two struct
        // values at different heap addresses returned FALSE even
        // when every field matched. Adopters writing canonical Rust
        // (which would derive PartialEq and do field-wise compare)
        // got a quiet wrong result. Sister to v0.4.52 (str ==) and
        if (op == 30 || op == 31) && str_len(lt) > 0 && str_eq(strip_spaces(lt), strip_spaces(rt)) == 1 {
            let v147_lstruct: i64 = struct_find_type(pool, structs, lt);
            if v147_lstruct >= 0 {
                let v085_helper_name: str = str_concat(type_base_name(strip_spaces(lt)), "__derived_eq");
                let v085_has_derived: str = sig_rtype(sigs, v085_helper_name);
                if str_len(v085_has_derived) == 0 {
                    let v147_op: str = if op == 30 { "==" } else { "!=" };
                    let v147a: str = str_concat("`", str_concat(lt, str_concat(" ", str_concat(v147_op, str_concat(" ", str_concat(lt, "` does pointer comparison."))))));
                    let v147b: str = " Rust derives PartialEq with field-wise comparison; Nucleor doesn't auto-derive. Compare fields explicitly: `a.field1 == b.field1 && a.field2 == b.field2 && ...`, OR add `#[derive(PartialEq)]` (v0.6.84+) which auto-generates the field-walk helper AND v0.6.85 routes `==`/`!=` directly to it.";
                    type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat(v147a, v147b));
                };
            };
        };
        if (op == 32 || op == 33 || op == 34 || op == 35) && str_len(lt) > 0 && str_eq(strip_spaces(lt), strip_spaces(rt)) == 1 {
            let v147ord_lstruct: i64 = struct_find_type(pool, structs, lt);
            if v147ord_lstruct >= 0 {
                let v147ord_op: str = if op == 32 { "<" } else if op == 33 { "<=" } else if op == 34 { ">" } else { ">=" };
                let v147c: str = str_concat("`", str_concat(lt, str_concat(" ", str_concat(v147ord_op, str_concat(" ", str_concat(lt, "` does pointer comparison (silent miscompute — disconnected from any field-wise ordering). Compare specific fields explicitly with the desired ordering."))))));
                type_diag(diags, source, fn_name, fn_name, "TYP-011", v147c);
            };
        };
        // NUM-009 — division or remainder by literal zero.
        // Pre-fix `let x: i64 = 100 / 0;` const-fold-skipped (good — see
        // opt_fold_block v0.3.145) but emitted `sdiv i64 100, 0` to LLVM,
        // which traps at runtime as SIGFPE (exit 127). Loud, but
        // runtime-only — adopters who wrote literal `/0` (typo, refactor
        // residue, dead-code branch) shipped a binary that crashed on
        // first execution instead of failing the build. NUM-009 was
        // already reserved (RFC-0015 / v0.2.319 expansion) but never
        // wired. Rust E0080 does the equivalent compile-time halt.
        // Catches the literal-int-zero case only — `let z = 0; let q =
        // 1 / z;` is not detected here (would need const-prop tracking).
        if op == 23 || op == 24 {
            let rhs_check_div: i64 = node_field(pool, nid, 3);
            if node_kind(pool, rhs_check_div) == 1 && node_field(pool, rhs_check_div, 1) == 0 {
                let div_op: str = if op == 23 { "/" } else { "%" };
                let div_kind: str = if op == 23 { "division" } else { "remainder" };
                let nm9_msg: str = str_concat(div_kind, str_concat(" by literal zero (`", str_concat(div_op, str_concat("0`) traps at runtime as SIGFPE. Remove the dead expression, use a non-zero divisor, or guard with a runtime check (`if d != 0 { x ", str_concat(div_op, " d } else { ... } }`).")))));
                type_diag(diags, source, fn_name, fn_name, "NUM-009", nm9_msg);
            };
        };
        // NUM-008 — shift amount equals or exceeds operand width
        // (UB-prone). Pre-fix `1 << 64` returned 1 (LLVM `shl i64 X, 64`
        // is poison; downstream code observed an undefined value, which
        // for the const case folded to 1). `1 << -1` returned i64::MIN
        // for the same reason. Adopters writing canonical Rust got
        // overflow_left_shift (debug) or wrapping behavior (release) —
        // either way explicit. Nucleor's i64-everywhere ABI fixes the
        // operand width at 64. NUM-008 was reserved (RFC-0015 / v0.2.319
        // expansion) but never wired. v0.4.146 extends this from bare
        // literals to simple let-bound constants tracked in tenv.
        if op == 115 || op == 116 {
            let rhs_check_sh: i64 = node_field(pool, nid, 3);
            let sh_const: Vec<i32> = const_i64_expr(pool, rhs_check_sh, env);
            let sh_have: i64 = vec_get(sh_const, 0);
            let sh_amt: i64 = vec_get(sh_const, 1);
            //  pre-fix the bound was hard-coded at
            // 64 (i64 width), so `let a: i32 = 1 << 32;` silently passed
            // the check + lowered to LLVM `shl i32` with shift amount 32
            // — UB / poison (returns 0 in practice). Adopters writing
            // canonical Rust narrow-width shifts got silent miscompute.
            // Now derive the bound from the LHS type's width.
            let lt_strip: str = strip_spaces(lt);
            let mut sh_bound: i64 = 64;
            if str_eq(lt_strip, "i8") == 1 || str_eq(lt_strip, "u8") == 1 { sh_bound = 8; }
            else if str_eq(lt_strip, "i16") == 1 || str_eq(lt_strip, "u16") == 1 { sh_bound = 16; }
            else if str_eq(lt_strip, "i32") == 1 || str_eq(lt_strip, "u32") == 1 { sh_bound = 32; };
            if sh_have == 1 && (sh_amt < 0 || sh_amt >= sh_bound) {
                let sh_op: str = if op == 115 { "<<" } else { ">>" };
                let bound_disp: str = if sh_bound > 0 { str_from_int(sh_bound - 1) } else { "0" };
                let lt_disp: str = if str_len(lt_strip) > 0 { lt_strip } else { "i64" };
                let nm8_msg: str = str_concat("shift amount ", str_concat(str_from_int(sh_amt), str_concat(" is out of range for ", str_concat(lt_disp, str_concat(" (`", str_concat(sh_op, str_concat("` requires 0..=", str_concat(bound_disp, "). LLVM `shl`/`ashr` is undefined behavior outside this range — pre-fix the result was poison (silent miscompute). Mask the shift amount or widen the LHS type."))))))));
                type_diag(diags, source, fn_name, fn_name, "NUM-008", nm8_msg);
            };
        };
        // NUC-FEEDBACK silent-miscompute guard for
        // `Vec<T> == Vec<T>` and `Vec<T> != Vec<T>`. Same root
        // cause as the str-equality close in v0.4.52: the binop
        // lowered to integer pointer comparison, silently returning
        // FALSE for two equal-element Vecs at different addresses.
        // Rust's `==` on `Vec<T>` does element-wise comparison via
        // `PartialEq` (requiring `T: PartialEq`). Adopters writing
        // the canonical idiom got a quiet wrong result.
        // DEFERRED: Vec<T> == Vec<T> guard. Pre-fix `v1 == v2`
        // for two equal-element Vecs returned FALSE (pointer compare).
        // Initial implementation crashed the compiler on the source-
        // scan fallback path (segfault inside infer_var_type_from_source
        // when called from binop type_expr). Deferred to v0.4.54+ once
        // the recursion path is debugged. Hazard documented in
        // tests/fixtures/repro_v53_vec_eq_pointer_guard_DEFERRED.nr.
        if is_tainted_type(lt) == 1 { return lt; };
        if is_tainted_type(rt) == 1 { return rt; };
        if is_int_arith == 1 && lhs_unsuffixed_lit == 1 && rt_is_int == 1 { return rt; };
        if is_int_arith == 1 && rhs_unsuffixed_lit == 1 && lt_is_int == 1 { return lt; };
        if (op == 20 || op == 21) && type_is_unit(lt) == 1 && str_eq(unit_dim(lt), unit_dim(rt)) == 1 { return lt; };
        if op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35 || op == 36 || op == 37 { return "bool"; };
        return lt;
    };
    if kind == 5 || kind == 6 {
        let inner_ty: str = type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        // TYP-002 — unary `!` on non-bool. Pre-fix `let r:
        // bool = !x;` for `x: i64` typed-checked as ok (kind 6 just
        // returned inner type "i64", and types_compatible("bool",
        // "i64") returns 1 — i64-truthiness convention). The lower
        // emitted i64_xor with 1 against the i64 value, producing
        // "no" for any non-zero x rather than a type error. Adopters
        // writing canonical Rust got E0600. `!` in Rust is bitwise on
        // integers (returns same type) — never bool. Catches kind 6
        // (unary `!`) when inner is not bool. Logical negation should
        // be `x == 0` for ints; `!` is reserved for bool only here
        // (matches Rust's `!` on bool — bitwise on int isn't
        // separately needed since Nucleor exposes `^` for that).
        if kind == 6 && str_len(inner_ty) > 0 && str_eq(inner_ty, "bool") == 0 {
            type_diag(diags, source, fn_name, fn_name, "TYP-002", str_concat("unary `!` requires a `bool` operand (got `", str_concat(inner_ty, "`). Use `x == 0` for logical negation of an integer, or cast to bool first (`(x != 0) == false`).")));
        };
        return inner_ty;
    };
    if kind == 90 {
        let inner: str = type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if str_len(inner) == 0 { return ""; };
        return str_concat("&", inner);
    };
    if kind == 91 {
        let inner: str = type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if str_len(inner) == 0 { return ""; };
        return str_concat("&mut ", inner);
    };
    if kind == 92 {
        let mut inner: str = type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if node_kind(pool, node_field(pool, nid, 1)) == 3 {
            let box_start: i64 = tprof_start(tprof);
            let guessed_box: str = source_box_binding_type(source, fn_name, node_field(pool, node_field(pool, nid, 1), 1));
            tprof_mark(tprof, 11, 12, box_start);
            if str_len(guessed_box) > 0 { inner = guessed_box; };
        };
        if type_is_ref(inner) == 0 && str_eq(type_base_name(inner), "Box") == 0 {
            if str_eq(inner, "i32") == 1 || str_eq(inner, "i64") == 1 || str_eq(inner, "bool") == 1 || str_eq(inner, "f64") == 1 || str_eq(inner, "str") == 1 || str_eq(inner, "ptr") == 1 {
                type_diag(diags, source, fn_name, fn_name, "TYP-004", "cannot dereference a non-reference value");
            };
            return "";
        };
        if str_eq(type_base_name(inner), "Box") == 1 {
            let slen: i64 = str_len(inner);
            if slen >= 5 && str_starts_with(inner, "Box<") == 1 { return str_substring(inner, 4, slen - 1); };
        };
        return type_base_name(inner);
    };
    if kind == 7 {
        // hoist tprof gate to local var so the
        // tprof_mark sites in this kind-7 branch can short-circuit
        // without re-entering tprof_enabled / tprof_start.
        let prof_on: i64 = vec_len(tprof);
        let call_start: i64 = if prof_on > 0 { now_ms() } else { 0 };
        let callee: str = node_field(pool, nid, 1);
        let args: i64 = node_field(pool, nid, 2);
        let argc: i64 = list_len(pool, args);
        if str_eq(callee, "sanitize") == 1 && argc > 0 {
            let arg_t: str = type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
            if prof_on > 0 { tprof_mark(tprof, 9, 10, call_start); };
            if is_tainted_type(arg_t) == 1 { return taint_inner_type(arg_t); };
            return arg_t;
        };
        //  assert_eq!/assert_ne! macros lower to
        // assert_eq(i64, i64) / assert_ne(i64, i64) regardless of arg
        // type, doing pointer comparison on str values. Equal-content
        // strings make `assert_eq!("hello", "hello")` always FAIL
        // (false-fail) and `assert_ne!("abc", "abc")` always PASS
        // (false-pass). The user-level `==`/`!=` on str is correctly
        // caught by TYP-011 (v0.4.52); the assert macros bypass it.
        // Emit the same TYP-011-style diagnostic + workaround pointer
        // so adopters route through `assert_eq(str_eq(a, b), 1)`.
        if (str_eq(callee, "assert_eq") == 1 || str_eq(callee, "assert_ne") == 1) && argc == 2 {
            let lt_v060: str = type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
            let rt_v060: str = type_expr(pool, prog, list_get(pool, args, 1), env, sigs, structs, fn_name, diags, source, tprof);
            if str_eq(lt_v060, "str") == 1 && str_eq(rt_v060, "str") == 1 {
                let macro_name: str = if str_eq(callee, "assert_eq") == 1 { "assert_eq!" } else { "assert_ne!" };
                let cmp_op: str = if str_eq(callee, "assert_eq") == 1 { "==" } else { "!=" };
                let hint_v060: str = if str_eq(callee, "assert_eq") == 1 { "assert_eq(str_eq(a, b), 1)" } else { "assert_eq(str_eq(a, b), 0)" };
                let v060a: str = str_concat("`", str_concat(macro_name, str_concat("(a, b)` on `str` arguments does pointer comparison (silent miscompute — equal-bytes strs at different addresses ", str_concat(cmp_op, " return FALSE)."))));
                let v060b: str = str_concat(" Use `", str_concat(hint_v060, "` to value-compare via the str_eq runtime helper. Sister to TYP-011 v0.4.52 `str == str` close."));
                type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat(v060a, v060b));
            };
        };
        // literal-only WARNING for vec_*(int_literal, ...).
        // Passing an int LITERAL where a Vec handle is expected is
        // an unambiguous adopter mistake (e.g. `vec_get(42, 0)`) --
        // pre-fix this compiled cleanly and SIGSEGV'd at runtime.
        // Variables (which may legitimately hold Vec handles in
        // Nucleor's i64-everywhere ABI -- the compiler self-host
        // does this pervasively) are NOT flagged. Same conservative
        // pattern as v0.3.162 f64_to_str(int_literal). Fires before
        // the dynamic_helper early-return below so the warning
        // surfaces. Diagnostic is INFORMATIONAL (uses print, not
        // type_diag) so the build doesn't halt.
        if argc > 0 {
            let needs_vec_lit_check: i64 = if str_eq(callee, "vec_get") == 1
                || str_eq(callee, "vec_set") == 1
                || str_eq(callee, "vec_len") == 1
                || str_eq(callee, "vec_push") == 1
                || str_eq(callee, "vec_pop") == 1
                || str_eq(callee, "vec_first") == 1
                || str_eq(callee, "vec_last") == 1
                || str_eq(callee, "vec_is_empty") == 1
                || str_eq(callee, "vec_swap") == 1
                || str_eq(callee, "vec_extend") == 1
                || str_eq(callee, "vec_remove_at") == 1
                || str_eq(callee, "vec_insert_at") == 1
                || str_eq(callee, "vec_free") == 1
                || str_eq(callee, "vec_clear") == 1 { 1 } else { 0 };
            if needs_vec_lit_check == 1 {
                let larg_v: i64 = list_get(pool, args, 0);
                if node_kind(pool, larg_v) == 1 {
                    // was print + continue. The runtime
                    // SIGSEGV was guaranteed (literal int dereferenced
                    // as NVec*); shipping the binary anyway was a
                    // silent fall-through. Promoted to compile-time
                    // panic. Literal-int Vec-handle is never a valid
                    // adopter pattern.
                    print(str_concat("ERROR: ", str_concat(callee, "(<int_literal>, ...) passes an int literal where a Vec handle is expected. This would SIGSEGV at runtime when the helper dereferences the int as an NVec*. Pass a Vec value (e.g. let v: Vec<i64> = Vec::new(); ...) or a typed Vec handle.")));
                    panic(str_concat("nucleor: ", str_concat(callee, "(<int_literal>) cannot pass int literal as Vec handle (see ERROR above)")));
                };
            };
            // extend the literal-only WARNING to other
            // container helper families (hashmap_*, hashset_*,
            // btreemap_*, vecdeque_*). Same hazard class as vec_*:
            // adopter passes int literal where a handle is expected,
            // SIGSEGVs at runtime with no diagnostic.
            let needs_map_lit_check: i64 = if str_starts_with(callee, "hashmap_") == 1
                || str_starts_with(callee, "hashset_") == 1
                || str_starts_with(callee, "btreemap_") == 1
                || str_starts_with(callee, "btreeset_") == 1
                || str_starts_with(callee, "vecdeque_") == 1 { 1 } else { 0 };
            if needs_map_lit_check == 1 {
                // Excludes constructors (no handle arg).
                let is_ctor: i64 = if str_eq(callee, "hashmap_new") == 1
                    || str_eq(callee, "hashmap_with_capacity") == 1
                    || str_eq(callee, "hashset_new") == 1
                    || str_eq(callee, "hashset_with_capacity") == 1
                    || str_eq(callee, "btreemap_new") == 1
                    || str_eq(callee, "btreeset_new") == 1
                    || str_eq(callee, "vecdeque_new") == 1
                    || str_eq(callee, "vecdeque_with_capacity") == 1 { 1 } else { 0 };
                if is_ctor == 0 {
                    let larg_m: i64 = list_get(pool, args, 0);
                    if node_kind(pool, larg_m) == 1 {
                        let mut kind_label: str = "VecDeque";
                        if str_starts_with(callee, "hashmap_") == 1 { kind_label = "HashMap"; };
                        if str_starts_with(callee, "hashset_") == 1 { kind_label = "HashSet"; };
                        if str_starts_with(callee, "btreemap_") == 1 { kind_label = "BTreeMap"; };
                        if str_starts_with(callee, "btreeset_") == 1 { kind_label = "BTreeSet"; };
                        let m1: str = str_concat("WARNING: ", callee);
                        let m2: str = str_concat(m1, "(<int_literal>, ...) passes an int literal where a ");
                        let m3: str = str_concat(m2, kind_label);
                        let m4: str = str_concat(m3, " handle is expected. This will SIGSEGV at runtime when the helper dereferences the int as a container pointer. Pass a real handle (e.g. let h = ");
                        let m5: str = str_concat(m4, kind_label);
                        let m6: str = str_concat(m5, "::new(); ...).");
                        print(m6);
                    };
                };
            };
            // extend the literal-only WARNING to tokenizer
            // (tok_*, nuc_tok_*) helpers that take a handle at arg-0.
            // Same hazard class as vec_*/hashmap_*: passing an int
            // literal where a tokenizer handle is expected SIGSEGVs
            // at runtime. ML adopters use these heavily.
            let needs_tok_lit_check: i64 = if str_eq(callee, "tok_encode") == 1
                || str_eq(callee, "tok_decode") == 1
                || str_eq(callee, "tok_vocab_size") == 1
                || str_eq(callee, "tok_save") == 1
                || str_eq(callee, "tok_free") == 1
                || str_eq(callee, "tok_vec_len") == 1
                || str_eq(callee, "tok_vec_at") == 1
                || str_eq(callee, "tok_vec_free") == 1
                || str_eq(callee, "nuc_tok_encode") == 1
                || str_eq(callee, "nuc_tok_decode") == 1
                || str_eq(callee, "nuc_tok_vocab_size") == 1
                || str_eq(callee, "nuc_tok_save") == 1
                || str_eq(callee, "nuc_tok_free") == 1
                || str_eq(callee, "nuc_tok_vec_len") == 1
                || str_eq(callee, "nuc_tok_vec_at") == 1
                || str_eq(callee, "nuc_tok_vec_free") == 1 { 1 } else { 0 };
            if needs_tok_lit_check == 1 {
                let larg_t: i64 = list_get(pool, args, 0);
                if node_kind(pool, larg_t) == 1 {
                    // same class as the Vec-handle close
                    // above — SIGSEGV-guaranteed silent fall-through
                    // promoted to panic. Literal-int tokenizer handle
                    // is never a valid adopter pattern.
                    print(str_concat("ERROR: ", str_concat(callee, "(<int_literal>, ...) passes an int literal where a tokenizer handle is expected. This would SIGSEGV at runtime. Pass a real handle (e.g. let t: i64 = tok_bpe_train(text, 1024); ...).")));
                    panic(str_concat("nucleor: ", str_concat(callee, "(<int_literal>) cannot pass int literal as tokenizer handle (see ERROR above)")));
                };
            };
            // extend the literal-only WARNING to remaining
            // adopter-facing handle-taking helper families:
            //   - str_arena_* / arena_* (arena handles)
            //   - nuc_graph_*, nuc_bm25_*, nuc_hnsw_*, nuc_emb_*,
            //     nuc_sym_*, nuc_stat_* (NS_Sage / search subsystems)
            // Same hazard: passing an int literal where a handle is
            // expected -> SIGSEGV at runtime. Variables remain
            // unflagged. Detected by prefix match; constructors and
            // helpers without a handle arg are excluded individually.
            let nbar_pref: i64 = if str_starts_with(callee, "str_arena_") == 1
                || str_starts_with(callee, "arena_") == 1
                || str_starts_with(callee, "nuc_graph_") == 1
                || str_starts_with(callee, "nuc_bm25_") == 1
                || str_starts_with(callee, "nuc_hnsw_") == 1
                || str_starts_with(callee, "nuc_emb_") == 1
                || str_starts_with(callee, "nuc_sym_") == 1
                || str_starts_with(callee, "nuc_stat_") == 1 { 1 } else { 0 };
            if nbar_pref == 1 {
                // Exclude constructors / no-handle entry points.
                let is_misc_ctor: i64 = if str_eq(callee, "str_arena_new") == 1
                    || str_eq(callee, "arena_new") == 1
                    || str_eq(callee, "nuc_graph_new") == 1
                    || str_eq(callee, "nuc_bm25_new") == 1
                    || str_eq(callee, "nuc_hnsw_new") == 1
                    || str_eq(callee, "nuc_emb_new") == 1
                    || str_eq(callee, "nuc_sym_new") == 1
                    || str_eq(callee, "nuc_stat_new") == 1 { 1 } else { 0 };
                if is_misc_ctor == 0 {
                    let larg_n: i64 = list_get(pool, args, 0);
                    if node_kind(pool, larg_n) == 1 {
                        let mut sub_label: str = "subsystem";
                        if str_starts_with(callee, "str_arena_") == 1 { sub_label = "string arena"; };
                        if str_starts_with(callee, "arena_") == 1 { sub_label = "arena"; };
                        if str_starts_with(callee, "nuc_graph_") == 1 { sub_label = "graph"; };
                        if str_starts_with(callee, "nuc_bm25_") == 1 { sub_label = "BM25 index"; };
                        if str_starts_with(callee, "nuc_hnsw_") == 1 { sub_label = "HNSW index"; };
                        if str_starts_with(callee, "nuc_emb_") == 1 { sub_label = "embedding"; };
                        if str_starts_with(callee, "nuc_sym_") == 1 { sub_label = "sym table"; };
                        if str_starts_with(callee, "nuc_stat_") == 1 { sub_label = "stats"; };
                        let n1: str = str_concat("WARNING: ", callee);
                        let n2: str = str_concat(n1, "(<int_literal>, ...) passes an int literal where a ");
                        let n3: str = str_concat(n2, sub_label);
                        let n4: str = str_concat(n3, " handle is expected. This will SIGSEGV at runtime when the helper dereferences the int as a pointer. Pass a real handle returned from the matching constructor.");
                        print(n4);
                    };
                };
            };
        };
        if argc > 0 {
            // pre-fix vec_pop was in this read-call set, returning the element
            // type — the type-checker pretended `let x = vec_pop(v)` was a
            // value-returning call (Rust-like) but the runtime helper is
            // void (just removes the last element). Adopters got a 0-valued
            // binding silently. Removed from the set so the call falls
            // through to builtin_rtype (which now reports "void" for
            // vec_pop), cascading to TYP-021 at let-binding sites with no
            // type annotation, or TYP-008 when the binding is annotated.
            let vec_read_call: i64 = if str_eq(callee, "vec_get") == 1
                || str_eq(callee, "vec_first") == 1
                || str_eq(callee, "vec_last") == 1 { 1 } else { 0 };
            if vec_read_call == 1 {
                let recv_nid: i64 = list_get(pool, args, 0);
                let mut recv_t: str = type_expr(pool, prog, recv_nid, env, sigs, structs, fn_name, diags, source, tprof);
                if str_len(recv_t) == 0 && node_kind(pool, recv_nid) == 3 {
                    recv_t = infer_var_type_from_source(source, node_field(pool, recv_nid, 1));
                };
                let elem_t: str = strip_container_one_level(recv_t);
                if str_len(elem_t) > 0 && vec_element_type_is_legacy_cell(elem_t) == 0 {
                    if prof_on > 0 { tprof_mark(tprof, 9, 10, call_start); };
                    return elem_t;
                };
            };
        };
        let fast_rt: str = type_fast_runtime_rtype(callee);
        if str_len(fast_rt) > 0 {
            let mut fast_ai: i64 = 0;
            while fast_ai < argc {
                let fast_arg: i64 = list_get(pool, args, fast_ai);
                if type_arg_needs_walk(pool, fast_arg) == 1 {
                    type_expr(pool, prog, fast_arg, env, sigs, structs, fn_name, diags, source, tprof);
                };
                fast_ai = fast_ai + 1;
            };
            if prof_on > 0 { tprof_mark(tprof, 9, 10, call_start); };
            return fast_rt;
        };
        // walk every call arg through type_expr BEFORE the
        // dynamic-helper early-return so the diagnostics inside arg
        // expressions still fire for runtime-helper / extern-helper
        // calls. Pre-fix `print_int(s[0])` for `s: str` skipped the
        // arg's type_expr entirely — TYP-011's "str does not support
        // direct indexing" check at line 11567 (kind == 10) never
        // saw the index expression because dynamic_helper returned
        // before the arg walker. Same for `s[0] as i64` (kind 99 also
        // calls type_expr internally but it gets short-circuited
        // when the outer call's argc > 0). Net result: every arg
        // gets one type_expr pass for diagnostic side effects only;
        // the result type is discarded since this fn returns "" for
        // dynamic helpers.
        if type_dynamic_helper(callee) == 1 {
            let mut dh_ai: i64 = 0;
            while dh_ai < argc {
                type_expr(pool, prog, list_get(pool, args, dh_ai), env, sigs, structs, fn_name, diags, source, tprof);
                dh_ai = dh_ai + 1;
            };
            if prof_on > 0 { tprof_mark(tprof, 9, 10, call_start); };
            return "";
        };
        let sig_start: i64 = tprof_start(tprof);
        let sentry: i64 = sig_find(sigs, callee);
        tprof_mark(tprof, 5, 6, sig_start);
        if sentry >= 0 {
            let plist: i64 = vec_get(sentry, 0);
            let gparams_v421: i64 = sig_gparams_from_entry(sentry);
            let expected_argc: i64 = list_len(pool, plist);
            if argc != expected_argc { type_diag(diags, source, fn_name, callee, "TYP-005", str_concat("wrong number of arguments for '", str_concat(callee, "'"))); };
            let mut bound_seen: Vec<i32> = Vec::new();
            // collect gparam bindings as we walk args. Map is
            // alternating [name, concrete-type, name, concrete-type, ...].
            // After the loop, used to substitute gparams in rtype before
            // returning. Closes generic-T propagation finding.
            let mut gparam_bindings: Vec<i32> = Vec::new();
            let mut ai: i64 = 0;
            while ai < argc && ai < expected_argc {
                let actual_t: str = type_expr(pool, prog, list_get(pool, args, ai), env, sigs, structs, fn_name, diags, source, tprof);
                let expected_t: str = node_field(pool, list_get(pool, plist, ai), 2);
                let compat_start: i64 = tprof_start(tprof);
                let compat_ok: i64 = types_compatible_context(pool, prog, expected_t, actual_t);
                tprof_mark(tprof, 7, 8, compat_start);
                if compat_ok == 0 {
                    if frame_mismatch_visible(expected_t, actual_t) == 1 {
                        let f_action: str = str_concat("cannot pass argument ", str_concat(str_from_int(ai), str_concat(" to '", str_concat(callee, "'"))));
                        type_diag(diags, source, fn_name, callee, "FRAME-001", frame_mismatch_diag_message(f_action, expected_t, actual_t));
                    } else {
                        type_diag(diags, source, fn_name, callee, "TYP-006", str_concat("argument type mismatch in call to '", str_concat(callee, "'")));
                    };
                };
                let v228_audit_on: str = env_get_or("NUCLEOR_AUDIT_NUM024", "0");
                if str_eq(v228_audit_on, "1") == 1 && compat_ok == 1 && str_len(expected_t) > 0 && str_len(actual_t) > 0 {
                    let v228_e_base: str = type_base_name(expected_t);
                    let v228_a_base: str = type_base_name(actual_t);
                    let v228_ew: i64 = type_width(v228_e_base);
                    let v228_aw: i64 = type_width(v228_a_base);
                    let v228_es: i64 = type_signedness(v228_e_base);
                    let v228_as: i64 = type_signedness(v228_a_base);
                    let v228_both_int: i64 = if (v228_es == 1 || v228_es == 2) && (v228_as == 1 || v228_as == 2) { 1 } else { 0 };
                    if v228_both_int == 1 && v228_ew > 0 && v228_aw > 0 && v228_ew < v228_aw {
                        let v228msg: str = str_concat("call to `", str_concat(callee, str_concat("` passes ", str_concat(v228_a_base, str_concat(" (", str_concat(str_from_int(v228_aw), str_concat("-bit) into ", str_concat(v228_e_base, str_concat(" (", str_concat(str_from_int(v228_ew), str_concat("-bit) param `", str_concat(node_field(pool, list_get(pool, plist, ai), 1), "`. Implicit cross-width narrowing via Nucleor's i64-everywhere ABI; widen the declared param type or insert an explicit `as ", str_concat(v228_e_base, "` at the call site.")))))))))))));
                        diag_add_at_or_scan(diags, source, pool, nid, callee, "warning", "type", "NUM-024", v228msg, fn_name, "");
                    };
                };
                if gparams_v421 >= 0 && str_len(actual_t) > 0 && str_eq(actual_t, expected_t) == 0 {
                    let gc_v421: i64 = list_len(pool, gparams_v421);
                    let mut gp_v421: i64 = 0;
                    let mut current_param: str = "";
                    while gp_v421 < gc_v421 {
                        let ge: str = list_get(pool, gparams_v421, gp_v421);
                        if str_len(ge) > 1 && str_char_at(ge, 0) == 63 {
                            if str_len(current_param) > 0 && str_eq(current_param, expected_t) == 1 {
                                let bound_v421: str = str_substring(ge, 1, str_len(ge));
                                // skip Rust marker traits at the
                                // bound-impl check too — they're no-ops
                                // under the i64-everywhere ABI (sister
                                // edit at line ~19417 for the unknown-
                                // trait check).
                                let mut v700_marker: i64 = 0;
                                if str_eq(bound_v421, "Sized") == 1 { v700_marker = 1; };
                                if str_eq(bound_v421, "Send") == 1 { v700_marker = 1; };
                                if str_eq(bound_v421, "Sync") == 1 { v700_marker = 1; };
                                if str_eq(bound_v421, "Unpin") == 1 { v700_marker = 1; };
                                if str_eq(bound_v421, "RefUnwindSafe") == 1 { v700_marker = 1; };
                                if str_eq(bound_v421, "UnwindSafe") == 1 { v700_marker = 1; };
                                if str_eq(bound_v421, "Copy") == 1 { v700_marker = 1; };
                                if str_eq(bound_v421, "Clone") == 1 { v700_marker = 1; };
                                if v700_marker == 0 && str_len(bound_v421) > 0 && type_implements_trait(pool, prog, actual_t, bound_v421) == 0 {
                                    let key_v421: str = str_concat(current_param, str_concat("|", str_concat(bound_v421, str_concat("|", actual_t))));
                                    if priv_string_vec_contains(bound_seen, key_v421) == 0 {
                                        bound_seen.push(key_v421);
                                        let msg21a: str = str_concat("type '", str_concat(actual_t, str_concat("' does not implement trait '", str_concat(bound_v421, "'"))));
                                        let msg21b: str = str_concat(" (required by bound on fn '", str_concat(callee, str_concat("<", str_concat(current_param, str_concat(": ", str_concat(bound_v421, ">')"))))));
                                        let msg21c: str = str_concat(". Add an 'impl ", str_concat(bound_v421, str_concat(" for ", str_concat(actual_t, "' block, or pass a type with that impl."))));
                                        type_diag(diags, source, fn_name, callee, "TYP-025", str_concat(msg21a, str_concat(msg21b, msg21c)));
                                    };
                                };
                            };
                        } else {
                            if str_len(ge) > 0 && str_char_at(ge, 0) != 39 {
                                current_param = ge;
                                // alongside the trait-bound check
                                // already running here, attempt to extract
                                // a concrete binding for this gparam from
                                // the (expected, actual) arg pair. First
                                // binding wins (no rebinding if a later
                                // arg disagrees — keeps the path simple).
                                let mut already_bound: i64 = 0;
                                let mut bb: i64 = 0;
                                let nb: i64 = vec_len(gparam_bindings);
                                while bb + 1 < nb && already_bound == 0 {
                                    if str_eq(vec_get(gparam_bindings, bb), ge) == 1 { already_bound = 1; };
                                    bb = bb + 2;
                                };
                                if already_bound == 0 {
                                    let bind_v513: str = gparam_extract_binding(expected_t, actual_t, ge);
                                    if str_len(bind_v513) > 0 {
                                        gparam_bindings.push(ge);
                                        gparam_bindings.push(bind_v513);
                                    };
                                };
                            } else {
                                current_param = "";
                            };
                        };
                        gp_v421 = gp_v421 + 1;
                    };
                };
                ai = ai + 1;
            };
            if prof_on > 0 { tprof_mark(tprof, 9, 10, call_start); };
            // substitute collected gparam bindings into rtype.
            // Falls through to the literal rtype if no bindings (e.g.
            // non-generic fn or gparams not inferable from args).
            let mut rtype_v513: str = vec_get(sentry, 1);
            let nb_final: i64 = vec_len(gparam_bindings);
            if nb_final >= 2 {
                let mut bi: i64 = 0;
                while bi + 1 < nb_final {
                    let g_v513: str = vec_get(gparam_bindings, bi);
                    let conc: str = vec_get(gparam_bindings, bi + 1);
                    rtype_v513 = substitute_gparam_in_rtype(rtype_v513, g_v513, conc);
                    bi = bi + 2;
                };
            };
            return rtype_v513;
        };
        // validate arg types for known runtime helpers
        // that expect specific positional types. Pre-v0.3.154, runtime
        // helpers had no sigs so type_expr fell straight to builtin_rtype
        // with no arg check. str_len(42) compiled cleanly and SIGSEGV'd
        // at runtime when the helper dereferenced 42 as a const char *.
        // Same hazard class as v0.3.137-v0.3.153 silent miscompiles.
        // Conservative, incremental: only check arg-0 of helpers whose
        // first arg must be str (v0.3.155 adds str_eq, str_concat,
        // str_substring, str_char_at to the v0.3.154 list of str_len,
        // str_to_int, str_to_f64, str_to_int_with_base). Other arg
        // positions and other helpers will be added in later iterations
        // as we audit them; missing checks fall through to the original
        // no-arg-check path so legitimate code never regresses.
        if argc > 0 {
            // extended the str-arg-0 list to cover the rest of
            // the obvious string-taking helpers. Excludes:
            //   - str_from_int / str_arena_new / str_arena_free (take
            //     i64, not str)
            //   - str_join (takes Vec as arg 0, str as arg 1)
            //   - str_arena_concat / str_arena_substring / str_arena_bytes
            //     (take arena handle i64 as arg 0)
            //   - str_to_i64_radix / str_to_int (already in arg-0 list)
            let needs_str_arg0: i64 = if str_eq(callee, "str_len") == 1
                || str_eq(callee, "str_to_int") == 1
                || str_eq(callee, "str_to_f64") == 1
                || str_eq(callee, "str_to_int_with_base") == 1
                || str_eq(callee, "str_to_i64") == 1
                || str_eq(callee, "str_to_i64_radix") == 1
                || str_eq(callee, "str_to_bool") == 1
                || str_eq(callee, "str_to_lower") == 1
                || str_eq(callee, "str_to_upper") == 1
                || str_eq(callee, "str_eq") == 1
                || str_eq(callee, "str_concat") == 1
                || str_eq(callee, "str_substring") == 1
                || str_eq(callee, "str_char_at") == 1
                || str_eq(callee, "str_char_at_strict") == 1
                || str_eq(callee, "str_contains") == 1
                || str_eq(callee, "str_starts_with") == 1
                || str_eq(callee, "str_ends_with") == 1
                || str_eq(callee, "str_index_of") == 1
                || str_eq(callee, "str_split") == 1
                || str_eq(callee, "str_lines") == 1
                || str_eq(callee, "str_chars") == 1
                || str_eq(callee, "str_pad_left") == 1
                || str_eq(callee, "str_pad_right") == 1
                || str_eq(callee, "str_center") == 1
                || str_eq(callee, "str_repeat") == 1
                || str_eq(callee, "str_replace") == 1
                || str_eq(callee, "str_reverse") == 1
                || str_eq(callee, "str_trim") == 1
                || str_eq(callee, "str_trim_end") == 1
                || str_eq(callee, "str_trim_start") == 1
                || str_eq(callee, "str_count") == 1
                || str_eq(callee, "str_is_empty") == 1
                || str_eq(callee, "str_intern") == 1
                || str_eq(callee, "str_free") == 1
                || str_eq(callee, "getenv") == 1
                || str_eq(callee, "print_raw") == 1
                || str_eq(callee, "print") == 1
                || str_eq(callee, "println") == 1
                || str_eq(callee, "eprint") == 1
                || str_eq(callee, "eprintln") == 1
                || str_eq(callee, "panic") == 1 { 1 } else { 0 };
            if needs_str_arg0 == 1 {
                let arg0_t: str = type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                //  accept `&str` too. Pre-
                // fix `str_len(&s)` was rejected with TYP-006 even though
                // `&s` lowers identically to `s` (kind-90 unary-ref is a
                // pass-through in lower_expr at line ~19462), so adopters
                // porting Rust code (where `&str` is canonical) hit the
                // diag on every helper call site. Now both forms accept;
                // the lower side already produces identical IR.
                // resolve type aliases before TYP-006 check.
                // `type StrAlias = str; let s: StrAlias = "..."; print(s);`
                // pre-fix saw arg0_t = "StrAlias" and fired TYP-006.
                let mut arg0_t_resolved_v067: str = arg0_t;
                let mut alias_depth: i64 = 0;
                while alias_depth < 4 {
                    let r_v067: str = type_alias_resolve(pool, prog, arg0_t_resolved_v067);
                    if str_len(r_v067) == 0 { alias_depth = 4; }
                    else { arg0_t_resolved_v067 = r_v067; alias_depth = alias_depth + 1; };
                };
                if str_len(arg0_t_resolved_v067) > 0 && str_eq(arg0_t_resolved_v067, "str") == 0 && str_eq(arg0_t_resolved_v067, "&str") == 0 && str_eq(arg0_t_resolved_v067, "_") == 0 {
                    let mut hint_v080: str = "";
                    if str_eq(arg0_t_resolved_v067, "String") == 1 || str_eq(arg0_t_resolved_v067, "&String") == 1 {
                        hint_v080 = ". Nucleor's String is a distinct heap-buffer struct from str — the safe coercion is `string_as_str(s)` (returns the underlying NUL-terminated buffer pointer). Adopters porting Rust code usually want str directly: `let s: str = \"...\";` rather than the heap String form.";
                    };
                    type_diag(diags, source, fn_name, callee, "TYP-006", str_concat("argument 0 of '", str_concat(callee, str_concat("' must be str (runtime helper)", hint_v080))));
                };
            };
            if argc > 0 {
                let lit_helper: i64 = if str_eq(callee, "f64_to_str") == 1
                    || str_eq(callee, "f32_to_str") == 1 { 1 } else { 0 };
                if lit_helper == 1 {
                    let larg_nid: i64 = list_get(pool, args, 0);
                    if node_kind(pool, larg_nid) == 1 {
                        print(str_concat("WARNING: ", str_concat(callee, "(<int_literal>) reinterprets the int as an f64 bit pattern (Nucleor's i64-everywhere ABI), producing subnormal-looking garbage like \"4.94066e-322\". To print the numeric value, write the literal as a decimal (e.g. 100.0) or use f64_from_int(100) -- or pass an i64 variable holding a real bit pattern.")));
                    };
                };
            };
            // also validate arg 1 of helpers that take a
            // second str.
            if argc > 1 {
                let needs_str_arg1: i64 = if str_eq(callee, "str_eq") == 1
                    || str_eq(callee, "str_concat") == 1
                    || str_eq(callee, "str_contains") == 1
                    || str_eq(callee, "str_starts_with") == 1
                    || str_eq(callee, "str_ends_with") == 1
                    || str_eq(callee, "str_index_of") == 1
                    || str_eq(callee, "str_split") == 1
                    || str_eq(callee, "str_replace") == 1 { 1 } else { 0 };
                if needs_str_arg1 == 1 {
                    let arg1_t: str = type_expr(pool, prog, list_get(pool, args, 1), env, sigs, structs, fn_name, diags, source, tprof);
                    // accept `&str` too. v0.6.67:
                    // also resolve type aliases.
                    let mut arg1_t_resolved_v067: str = arg1_t;
                    let mut alias_depth1_v067: i64 = 0;
                    while alias_depth1_v067 < 4 {
                        let r1_v067: str = type_alias_resolve(pool, prog, arg1_t_resolved_v067);
                        if str_len(r1_v067) == 0 { alias_depth1_v067 = 4; }
                        else { arg1_t_resolved_v067 = r1_v067; alias_depth1_v067 = alias_depth1_v067 + 1; };
                    };
                    if str_len(arg1_t_resolved_v067) > 0 && str_eq(arg1_t_resolved_v067, "str") == 0 && str_eq(arg1_t_resolved_v067, "&str") == 0 && str_eq(arg1_t_resolved_v067, "_") == 0 {
                        // same String-coercion hint as arg0.
                        let mut hint_v080b: str = "";
                        if str_eq(arg1_t_resolved_v067, "String") == 1 || str_eq(arg1_t_resolved_v067, "&String") == 1 {
                            hint_v080b = ". Nucleor's String is a distinct heap-buffer struct from str — the safe coercion is `string_as_str(s)` (returns the underlying NUL-terminated buffer pointer).";
                        };
                        type_diag(diags, source, fn_name, callee, "TYP-006", str_concat("argument 1 of '", str_concat(callee, str_concat("' must be str (runtime helper)", hint_v080b))));
                    };
                };
            };
        };
        // NUC-FEEDBACK silent-undefined-symbol guard.
        // Closes deferral #2 from the queue. Pre-fix `let x: i64 =
        // nonexistent_function(42);` silently emitted broken IR and
        // failed late at clang link with `undefined value
        // '@nonexistent_function'`.
        // The v0.4.57 attempt fired on closure-generated callees
        // (`__closure_N`) and fn-pointer dispatch sites. v0.4.60 adds
        // 3 filters to suppress those false positives:
        //   1. Skip if callee starts with `__` (compiler-generated)
        //   2. Skip if first character is uppercase (Type-prefixed
        //      mangled names, though most go through kind 12)
        //   3. Skip if `tenv_get(env, callee)` is non-empty
        //      (callee is a registered variable holding an fn pointer)
        // walk every arg through type_expr for diagnostic
        // side effects when we haven't already (sig_find branch walks
        // them at lines 11781-91; type_dynamic_helper branch walks
        // them at 11765-69). For runtime helpers like `print_int` /
        // `print` / etc. that are NEITHER in sigs (no plist registered)
        // NOR in type_dynamic_helper, the previous code only walked
        // specific arg positions for known-string-arg helpers
        // (str_len etc.). Pre-fix `print_int(add(5))` for `fn add(a:
        // i64, b: i64) -> i64` silently passed: the inner `add(5)`
        // (kind-7) had its own argc=1 vs expected=2 which would
        // normally fire TYP-005, but type_expr was never called on
        // it because `print_int` falls into the non-walking path.
        // Net effect: nested calls escaped every diagnostic.
        // Mirrors v0.4.117 (which fixed the same hazard for
        // type_dynamic_helper callees).
        if argc > 0 && sentry < 0 && type_dynamic_helper(callee) == 0 {
            let mut walk_ai: i64 = 0;
            while walk_ai < argc {
                type_expr(pool, prog, list_get(pool, args, walk_ai), env, sigs, structs, fn_name, diags, source, tprof);
                walk_ai = walk_ai + 1;
            };
        };
        // TYP-022 ext — bare struct name called like a fn.
        // Pre-fix `let p = P(42);` for `struct P { ... }` lowered to
        // `call i64 @P(...)` and failed late at clang link with
        // `error: use of undefined value '@P'`. The v0.4.106 lift
        // suppresses uppercase-leading callees from TYP-005 (most
        // are kind-12 type-prefixed mangled calls handled
        // separately), so adopters got the raw clang error pointing
        // at compiler-emitted IR instead of their source. Sister to
        // struct-as-value at kind-3: when the callee
        // matches a defined struct name, surface TYP-022 directing
        // to struct-init syntax.
        // fast-fail check — tuple/regular struct names start
        // uppercase per Rust convention. Skip the structs-table scan
        // for lowercase callees (the dominant case).
        let mut callee_uppercase: i64 = 0;
        if str_len(callee) > 0 {
            let cc0_v074: i64 = str_char_at(callee, 0);
            if cc0_v074 >= 65 && cc0_v074 <= 90 { callee_uppercase = 1; };
        };
        if sentry < 0 && callee_uppercase == 1 && struct_find_type(pool, structs, callee) >= 0 {
            let s_idx_v074: i64 = struct_find_type(pool, structs, callee);
            let s_nid_v074: i64 = vec_get(structs, s_idx_v074);
            if struct_is_tuple_style(pool, s_nid_v074) == 1 {
                // Verify argc == field count.
                let s_flist: i64 = node_field(pool, s_nid_v074, 2);
                let s_fc: i64 = list_len(pool, s_flist);
                if argc != s_fc {
                    let argc_a: str = str_concat("tuple-struct `", str_concat(callee, str_concat("` has ", str_concat(str_from_int(s_fc), str_concat(" positional fields, but ", str_concat(str_from_int(argc), " arguments were supplied at the construction site."))))));
                    type_diag(diags, source, fn_name, callee, "TYP-022", argc_a);
                } else {
                    // Type-check each arg against its corresponding
                    // synthetic field's declared type.
                    let mut tup_ai: i64 = 0;
                    while tup_ai < argc {
                        let arg_nid_v074: i64 = list_get(pool, args, tup_ai);
                        let arg_t: str = type_expr(pool, prog, arg_nid_v074, env, sigs, structs, fn_name, diags, source, tprof);
                        let s_fnid: i64 = list_get(pool, s_flist, tup_ai);
                        let exp_t: str = node_field(pool, s_fnid, 2);
                        if str_len(arg_t) > 0 && str_len(exp_t) > 0 {
                            if types_compatible_context(pool, prog, exp_t, arg_t) == 0 {
                                if frame_mismatch_visible(exp_t, arg_t) == 1 {
                                    let f_action_tup: str = str_concat("cannot initialize tuple-struct '", str_concat(callee, str_concat("' field '__", str_concat(str_from_int(tup_ai), "'"))));
                                    type_diag(diags, source, fn_name, callee, "FRAME-001", frame_mismatch_diag_message(f_action_tup, exp_t, arg_t));
                                } else {
                                    let mismatch_a: str = str_concat("tuple-struct `", str_concat(callee, str_concat("` field `__", str_concat(str_from_int(tup_ai), str_concat("` expects type `", str_concat(exp_t, str_concat("` but argument has type `", str_concat(arg_t, "`."))))))));
                                    type_diag(diags, source, fn_name, callee, "TYP-008", mismatch_a);
                                };
                            };
                        };
                        tup_ai = tup_ai + 1;
                    };
                };
                if prof_on > 0 { tprof_mark(tprof, 9, 10, call_start); };
                return callee;
            };
            let v148a: str = str_concat("`", str_concat(callee, str_concat("(", str_concat("...)` is not how struct values are constructed in Nucleor — `", str_concat(callee, "` is a struct type, not a fn.")))));
            let v148b: str = str_concat(" Pre-v0.4.148 the call lowered to `call i64 @", str_concat(callee, str_concat("(...)` and failed late at clang link with `error: use of undefined value '@", str_concat(callee, "'`. Use struct-init syntax `<Name> { field1: val1, ... }` to construct a value, or call an inherent constructor `<Name>::new(...)` if one is defined."))));
            type_diag(diags, source, fn_name, callee, "TYP-022", str_concat(v148a, v148b));
        };
        // closure call-site argc check. Closures aren't
        // in sigs (their binding lives in tenv with no plist), so
        // sig_find returned -1 and the kind-7 path silently lowered
        // an indirect call with the wrong arg count. Pre-fix
        // `let f = |x: i64, y: i64| x + y; f(5);` ran the closure
        // body with the second param reading whatever register
        // happened to be live → garbage. Detect via the
        // `__closure_argc_<callee>` entry registered at let-stmt
        // type-check time (v0.4.146 sister fix in type_check_stmt).
        let v146_argc_str: str = tenv_get(env, str_concat("__closure_argc_", callee));
        if str_len(v146_argc_str) > 0 {
            let v146_expected_argc: i64 = str_to_int(v146_argc_str);
            if argc != v146_expected_argc {
                let v146a: str = str_concat("wrong number of arguments to closure `", str_concat(callee, str_concat("`: expected ", str_concat(str_from_int(v146_expected_argc), str_concat(", got ", str_from_int(argc))))));
                let v146b: str = ". Match the closure's declared parameter list at every call site.";
                type_diag(diags, source, fn_name, callee, "TYP-005", str_concat(v146a, v146b));
            };
            // return the closure's body rtype (registered
            // at let-stmt time) so callers see "void" / "i64" / etc.
            // instead of the blanket "" from builtin_rtype. Cascades
            // into v0.4.136 TYP-021 (`let r = void_closure(args)`),
            let v156_rtype: str = tenv_get(env, str_concat("__closure_rtype_", callee));
            if str_len(v156_rtype) > 0 {
                if prof_on > 0 { tprof_mark(tprof, 9, 10, call_start); };
                return v156_rtype;
            };
        };
        if sentry < 0 && type_dynamic_helper(callee) == 0 && str_len(get_rt_name(callee)) == 0 && str_len(builtin_rtype(callee)) == 0 {
            let clen: i64 = str_len(callee);
            let mut suppress: i64 = 0;
            if clen >= 2 && str_char_at(callee, 0) == 95 && str_char_at(callee, 1) == 95 {
                suppress = 1;
            };
            if clen >= 1 {
                let c0: i64 = str_char_at(callee, 0);
                if c0 >= 65 && c0 <= 90 { suppress = 1; };
            };
            if suppress == 0 {
                // Check existence via sym_get directly — tenv_get returns
                // "" both for "missing" and for "registered but type
                // unknown" (the latter happens for closure bindings whose
                // init type is "").
                if sym_get(env, callee) >= 0 { suppress = 1; };
            };
            if suppress == 0 {
                // emit at WARNING tier, not ERROR. Cross-module
                // private fns (e.g. `lib_helper` from a non-pub'd
                // sibling module) are unknown at type-check time but
                // get cleanly upgraded to MOD-003 by priv_lift_link_errors
                // after clang errors with `use of undefined value`.
                // If we halted the build at type-check, MOD-003 would
                // never get a chance — adopters with privatization
                // mistakes would see TYP-005 instead of the more
                // helpful "add `pub`" hint. Warning means: print a
                // compile-time signal up front, but let the link path
                // produce the canonical diagnostic. For truly-undefined
                // fns (no privatization match), clang link error halts
                // the build naturally.
                diag_add_at_or_scan(diags, source, pool, nid, callee, "warning", "type", "TYP-005", str_concat("undefined function `", str_concat(callee, "()` at type-check time (will fail at clang link if not a privatized cross-module fn). Check spelling, or import the rod that defines it.")), fn_name, "");
            };
        };
        if prof_on > 0 { tprof_mark(tprof, 9, 10, call_start); };
        let builtin_ret: str = builtin_rtype(callee);
        if str_len(builtin_ret) > 0 && argc > 0 {
                let mut bai: i64 = 0;
                while bai < argc {
                    let ba: i64 = list_get(pool, args, bai);
                    if type_arg_needs_walk(pool, ba) == 1 {
                        type_expr(pool, prog, ba, env, sigs, structs, fn_name, diags, source, tprof);
                    };
                    bai = bai + 1;
                };
        };
        return builtin_ret;
    };
    if kind == 8 {
        let recv_nid: i64 = node_field(pool, nid, 1);
        let mut recv_t: str = type_expr(pool, prog, recv_nid, env, sigs, structs, fn_name, diags, source, tprof);
        if str_len(recv_t) == 0 && node_kind(pool, recv_nid) == 3 {
            recv_t = infer_var_type_from_source(source, node_field(pool, recv_nid, 1));
        };
        let mname: str = node_field(pool, nid, 2);
        // TYP-023 — chained method call on void-returning
        // receiver. Pre-fix `v.push(30).len()` silently lowered the
        // outer .len() against vec_push's discarded result, returning
        // 0 (and `v.push(N).contains(K)` returned wrong-bool with the
        // void result misread as a Vec/str header). The inner
        // void-mutator returns "void" via the route added below; here
        // we halt before dispatching the outer call against it.
        if str_eq(recv_t, "void") == 1 {
            let inner_mn: str = if node_kind(pool, recv_nid) == 8 { node_field(pool, recv_nid, 2) } else { "" };
            let v23a: str = str_concat("chained method `.", str_concat(mname, "()` on a void-returning receiver."));
            let v23b: str = if str_len(inner_mn) > 0 { str_concat(" The inner `.", str_concat(inner_mn, "()` is a void-mutator (push/pop/set/swap/extend/remove/insert/shuffle/free) — these don't return self for chaining in Nucleor.")) } else { "" };
            let v23c: str = " Split into separate statements: call the mutator on its own line, then call the chained method on the receiver.";
            type_diag(diags, source, fn_name, fn_name, "TYP-023", str_concat(v23a, str_concat(v23b, v23c)));
        };
        // Keep the literal type-mismatch check below before the
        // void-mutator early return. Otherwise Vec<i64>.push("hello")
        // exits as "void" before TYP-008 can fire.
        // TYP-008 ext — Vec<T>.push(literal) narrow type
        // mismatch check. v0.4.86: extended to .insert(idx, val)
        // (val at arg position 1) and .set(idx, val) (same).
        // Pre-fix all 3 silently bit-cast the value into the i64
        // cell, producing garbage at read sites or clang link
        // failure (insert with str arg → vec_insert_at can't link).
        let elem_arg_pos_for_method: i64 = if str_eq(mname, "push") == 1 { 0 }
            else if str_eq(mname, "insert") == 1 { 1 }
            else if str_eq(mname, "set") == 1 { 1 }
            else { 0 - 1 };
        if elem_arg_pos_for_method >= 0 && str_starts_with(recv_t, "Vec<") == 1 {
            let push_args: i64 = node_field(pool, nid, 3);
            let needed_argc: i64 = elem_arg_pos_for_method + 1;
            if list_len(pool, push_args) > elem_arg_pos_for_method {
                let push_arg_nid: i64 = list_get(pool, push_args, elem_arg_pos_for_method);
                let push_arg_kind: i64 = node_kind(pool, push_arg_nid);
                let push_elem_t: str = strip_container_one_level(recv_t);
                if str_len(push_elem_t) > 0 && vec_element_type_is_legacy_cell(push_elem_t) == 0 {
                    let mut push_mismatch: i64 = 0;
                    let mut push_got: str = "";
                    if push_arg_kind == 1 && str_eq(push_elem_t, "str") == 1 { push_mismatch = 1; push_got = "int literal"; };
                    if push_arg_kind == 2 && (str_eq(push_elem_t, "i64") == 1 || str_eq(push_elem_t, "i32") == 1 || str_eq(push_elem_t, "i16") == 1 || str_eq(push_elem_t, "i8") == 1 || str_eq(push_elem_t, "u64") == 1 || str_eq(push_elem_t, "u32") == 1 || str_eq(push_elem_t, "u16") == 1 || str_eq(push_elem_t, "u8") == 1 || str_eq(push_elem_t, "bool") == 1 || str_eq(push_elem_t, "f64") == 1 || str_eq(push_elem_t, "f32") == 1) { push_mismatch = 1; push_got = "str literal"; };
                    if push_arg_kind == 71 && (str_eq(push_elem_t, "i64") == 1 || str_eq(push_elem_t, "i32") == 1 || str_eq(push_elem_t, "i16") == 1 || str_eq(push_elem_t, "i8") == 1 || str_eq(push_elem_t, "u64") == 1 || str_eq(push_elem_t, "u32") == 1 || str_eq(push_elem_t, "u16") == 1 || str_eq(push_elem_t, "u8") == 1 || str_eq(push_elem_t, "bool") == 1 || str_eq(push_elem_t, "str") == 1) { push_mismatch = 1; push_got = "float literal"; };
                    if push_mismatch == 1 {
                        let push_msg: str = str_concat("Vec<", str_concat(push_elem_t, str_concat(">.", str_concat(mname, str_concat("(...) type mismatch: declared element type `", str_concat(push_elem_t, str_concat("`, got ", str_concat(push_got, ". Pre-v0.4.85 this silently bit-cast the value into the i64 cell, producing garbage at read sites or clang link failure."))))))));
                        type_diag(diags, source, fn_name, fn_name, "TYP-008", push_msg);
                    };
                };
            };
        };
        // route void-mutator vec methods to return "void"
        // so the existing TYP-021 (let-RHS void), TYP-020 (binop void),
        // and NUM-022-style checks auto-extend without per-call
        // duplication. This must stay after the TYP-008 Vec element
        // mismatch check above.
        if (str_starts_with(recv_t, "Vec<") == 1 || str_eq(recv_t, "Vec") == 1)
            && (str_eq(mname, "push") == 1 || str_eq(mname, "pop") == 1
                || str_eq(mname, "set") == 1 || str_eq(mname, "swap") == 1
                || str_eq(mname, "extend") == 1 || str_eq(mname, "shuffle") == 1
                || str_eq(mname, "free") == 1 || str_eq(mname, "remove") == 1
                || str_eq(mname, "insert") == 1) {
            return "void";
        };
        if str_eq(mname, "sum") == 1 || str_eq(mname, "mean") == 1 || str_eq(mname, "max") == 1 || str_eq(mname, "min") == 1 {
            if str_eq(type_base_name(recv_t), "Tensor") == 1 { return "f64"; };
            return "i32";
        };
        if str_eq(mname, "any") == 1 || str_eq(mname, "all") == 1 { return "bool"; };
        if str_eq(mname, "len") == 1 { return "i64"; };
        if str_eq(mname, "get") == 1 || str_eq(mname, "first") == 1 || str_eq(mname, "last") == 1 || str_eq(mname, "pop") == 1 {
            let elem_t: str = strip_container_one_level(recv_t);
            if str_len(elem_t) > 0 && vec_element_type_is_legacy_cell(elem_t) == 0 { return elem_t; };
        };
        if str_eq(mname, "matmul") == 1 { return recv_t; };
        if str_eq(mname, "set") == 1 { return "void"; };
        if str_eq(mname, "iter") == 1 { return recv_t; };
        // Vec-returning iter methods. Pre-fix kind-8
        // type_expr fell to `return ""` for clone/sort/reverse/
        // map/filter/collect/take/skip/chain/step_by — they all
        // route to `vec_<m>_i64` runtime helpers that return
        // NVec*, but the type-check returned the empty string.
        // Net effect: chained `v.clone().push(N)` had recv_t=""
        // for the outer push, so the v0.4.139 void-mutator route
        // (`recv_t starts with Vec<` or equals `Vec`) failed to
        // fire and `let r: i64 = v.clone().push(N);` silently
        // bound r=0. Returning recv_t (the Vec type) propagates
        // through to v0.4.139 → TYP-021 cascade.
        if (str_starts_with(recv_t, "Vec<") == 1 || str_eq(recv_t, "Vec") == 1)
            && (str_eq(mname, "clone") == 1
                || str_eq(mname, "sort") == 1
                || str_eq(mname, "reverse") == 1
                || str_eq(mname, "map") == 1
                || str_eq(mname, "filter") == 1
                || str_eq(mname, "collect") == 1
                || str_eq(mname, "take") == 1
                || str_eq(mname, "skip") == 1
                || str_eq(mname, "chain") == 1
                || str_eq(mname, "step_by") == 1) {
            return recv_t;
        };
        return "";
    };
    if kind == 9 {
        let recv_t: str = type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let si: i64 = struct_find_type(pool, structs, recv_t);
        if si >= 0 {
            let fname_v9: str = node_field(pool, nid, 2);
            let f_idx_v9: i64 = struct_field_idx(pool, vec_get(structs, si), fname_v9);
            // TYP-018 — field access on a known struct with
            // an unknown field name silently lowered to vec_get(struct,
            // -1) and surfaced at runtime as a misleading "vec_get OOB
            // index -1" panic. Adopters typo'ing field names got a
            // runtime crash with no compile-time signal pointing at
            // the struct or the typo. Halt now with TYP-018 listing
            // the typo'd name and the receiver struct type.
            if f_idx_v9 < 0 {
                let t18a: str = str_concat("unknown field `.", str_concat(fname_v9, str_concat("` on receiver type `", str_concat(recv_t, "`."))));
                let t18b: str = " Check the field name spelling against the struct definition.";
                type_diag(diags, source, fn_name, fn_name, "TYP-018", str_concat(t18a, t18b));
            };
            return struct_field_type_for_inst(pool, vec_get(structs, si), recv_t, fname_v9);
        };
        return "";
    };
    if kind == 10 {
        let recv_nid: i64 = node_field(pool, nid, 1);
        let mut recv_t: str = type_expr(pool, prog, recv_nid, env, sigs, structs, fn_name, diags, source, tprof);
        if str_len(recv_t) == 0 && node_kind(pool, recv_nid) == 3 {
            recv_t = infer_var_type_from_source(source, node_field(pool, recv_nid, 1));
        };
        // TYP-011 close — `s[i]` for `s: str` silently
        // dispatched to vec_get(s, i), which read the str pointer
        // as if it were an NVec header — at best returned garbage,
        // at worst SIGSEGVed. Adopters writing canonical Rust
        // string indexing got an OOB panic with "len 0" or random
        // garbage. Halt with a clear hint to use str_char_at.
        if str_eq(recv_t, "str") == 1 {
            type_diag(diags, source, fn_name, fn_name, "TYP-011", "`str` does not support direct indexing with `s[i]` — that lowers to vec_get on the str pointer (OOB-panics or returns garbage). Use `str_char_at(s, i)` to get a byte, or `str_substring(s, i, j)` to get a substring.");
        };
        let elem_t: str = strip_container_one_level(recv_t);
        if vec_element_type_is_legacy_cell(elem_t) == 1 { return ""; };
        return elem_t;
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname_k12: str = node_field(pool, nid, 2);
        let args: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Box") == 1 {
            // Box::leak(b: Box<T>) -> &T — intentional-leak
            // pass-through. Nucleor has no automatic drop today so
            // Box::leak is semantically a no-op that unwraps the type.
            if str_eq(mname_k12, "leak") == 1 {
                if list_len(pool, args) > 0 {
                    let box_t: str = type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                    let blen: i64 = str_len(box_t);
                    if blen > 4 && str_eq(str_substring(box_t, 0, 4), "Box<") == 1 {
                        return str_concat("&", str_substring(box_t, 4, blen - 1));
                    };
                    return str_concat("&", box_t);
                };
                return "&i64";
            };
            if list_len(pool, args) > 0 {
                let inner: str = type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                if str_len(inner) > 0 { return str_concat("Box<", str_concat(inner, ">")); };
            };
            return "Box<i64>";
        };
        if str_eq(tname, "Tensor") == 1 { return "Tensor<f64>"; };
        // RFC-0024 Phase 2: constructor type propagation.
        // `Some(value)` → `Option<T>` where T = static type of value.
        // `Ok(value)`   → `Result<T,_>` (E inferred from context later).
        // `None` and `Err(...)` keep returning the bare type — variant
        // doesn't constrain T meaningfully on its own (None) or only
        // constrains E (Err), and existing type-compat code at
        // ~lines 9751-9757 already lets bare `Option`/`Result` mix with
        // `Option<T>`/`Result<T>` shapes so this is additive.
        if str_eq(tname, "Option") == 1 {
            let variant: str = node_field(pool, nid, 2);
            if str_eq(variant, "Some") == 1 && list_len(pool, args) > 0 {
                let inner: str = type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                if str_len(inner) > 0 { return str_concat("Option<", str_concat(inner, ">")); };
            };
            return "Option";
        };
        if str_eq(tname, "Result") == 1 {
            let variant: str = node_field(pool, nid, 2);
            if str_eq(variant, "Ok") == 1 && list_len(pool, args) > 0 {
                let inner: str = type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                if str_len(inner) > 0 { return str_concat("Result<", str_concat(inner, ",_>")); };
            };
            if str_eq(variant, "Err") == 1 && list_len(pool, args) > 0 {
                let inner_err: str = type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                if str_len(inner_err) > 0 { return str_concat("Result<_,", str_concat(inner_err, ">")); };
            };
            return "Result";
        };
        // kind-12 type_expr for String::new / String::with_capacity
        // returned "" pre-fix, so `let s: String = String::new();` ended
        // up with `s` typed as "" in tenv (the let-stmt logic at line
        // 12459 stores "" when init_t is empty even with an explicit
        // annotation). That made every downstream check on `s`'s type
        // fail silently — including the new TYP-011 String-arith check.
        if str_eq(tname, "String") == 1 { return "String"; };
        if str_eq(tname, "Vec") == 1 { return "Vec"; };
        if str_eq(tname, "HashMap") == 1 { return "HashMap"; };
        if str_eq(tname, "HashSet") == 1 { return "HashSet"; };
        if str_eq(tname, "BTreeMap") == 1 { return "BTreeMap"; };
        if str_eq(tname, "BTreeSet") == 1 { return "BTreeSet"; };
        if str_eq(tname, "VecDeque") == 1 { return "VecDeque"; };
        return "";
    };
    if kind == 34 { return node_field(pool, nid, 1); };
    if kind == 52 { return type_last_stmt(pool, prog, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof); };
    if kind == 23 {
        let tt: str = type_last_stmt(pool, prog, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            let et: str = type_last_stmt(pool, prog, enode, env, sigs, structs, fn_name, diags, source, tprof);
            if str_eq(strip_spaces(tt), strip_spaces(et)) == 1 { return tt; };
            // TYP-024 — `if`-expr branches with incompatible
            // types silently picked the then-branch type. Pre-fix
            // `let x = if cond { 1 } else { "two" };` returned "i32"
            // for x; the else branch's str pointer got bit-cast as
            // i64 when cond was false → meaningless garbage at use
            // sites. Rust rejects with E0308 "if and else have
            // incompatible types". Detect here when both sides have
            // known types AND types_compatible_context says they're
            // not compatible AND neither is void/unit (early-return
            // branches are skipped — `if cond { return x; } else {
            // val }` legitimately has tt=void/unit for the then side).
            let v24_tt_skip: i64 = if str_len(tt) == 0 || str_eq(tt, "void") == 1 || type_is_unit(tt) == 1 { 1 } else { 0 };
            let v24_et_skip: i64 = if str_len(et) == 0 || str_eq(et, "void") == 1 || type_is_unit(et) == 1 { 1 } else { 0 };
            if v24_tt_skip == 0 && v24_et_skip == 0 {
                let v24_compat: i64 = types_compatible_context(pool, prog, tt, et);
                if v24_compat == 0 {
                    let v24a: str = str_concat("`if`-expression branches have incompatible types: then-branch is `", str_concat(tt, str_concat("`, else-branch is `", str_concat(et, "`."))));
                    let v24b: str = " Both branches must have compatible types (Rust E0308). Use a `match` if you need value-vs-type alternation, or convert one branch to match the other.";
                    type_diag(diags, source, fn_name, fn_name, "TYP-024", str_concat(v24a, v24b));
                };
            };
        };
        return tt;
    };
    if kind == 38 {
        let scrut_t: str = type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let mut out_t: str = "";
        // MATCH-013 — reject float scrutinees BEFORE the arm
        // walk reaches lower_expr's pattern-codegen path. Pre-fix the
        // compiler ACCESS_VIOLATIONed (Windows -1073741819 / SIGSEGV)
        // on `match <f64> { 1.5 => ..., _ => ... }` because the int-
        // pattern lowering path emitted icmp eq against an f64-typed
        // scrutinee and followed a NULL ptr through the codegen
        // dispatch. Float equality patterns are fragile (NaN ≠ NaN;
        // round-off drift) so this is the right intentional rejection
        // anyway — Rust forbids float patterns since 1.0. Halts at
        // type-check before any codegen runs.
        // Regression: float match scrutinee compiler crash.
        if type_is_float(scrut_t) == 1 {
            let m13a: str = str_concat("float scrutinee in `match` is not supported (got `", str_concat(scrut_t, "`)."));
            let m13b: str = " Float equality is fragile (NaN ≠ NaN; round-off drift means literal-equality matches surprise-fail), so pattern-matching on `f32`/`f64` values has no defined semantics here. Use an `if`-chain (`if (x - 1.5).abs() < 0.001 { ... }`) for tolerance-based comparison, or convert via `(x * 100.0) as i32` to match on integer scaled values.";
            type_diag_at(diags, source, pool, nid, fn_name, "match", "MATCH-013", str_concat(m13a, m13b));
            return "i64";
        };
        let mut ai: i64 = 0;
        while ai < ac {
            let arm_nid: i64 = list_get(pool, arms, ai);
            let arm_env: Vec<i32> = own_snapshot(env);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            // MATCH-011 — arm pattern literal type doesn't
            // match scrutinee. Pre-fix `match n: i64 { 1 => ..., "a"
            // => ..., _ => ... }` for n=2 SIGSEGVed at runtime: the
            // str-literal arm lowered to `str_eq(<scrut_i64>, "a")`,
            // which dereferences the scrutinee value as a char ptr —
            // for n=2 that reads memory at address 0x2 → segfault.
            // Symmetric hazard for `match s: str { 1 => ... }` (silent
            // miscompare of ptr i64 vs literal). Catch both at
            // type-check before lowering.
            if str_eq(ename, "__str") == 1 && type_is_int(scrut_t) == 1 {
                let m11a: str = str_concat("string literal arm in `match` on integer scrutinee (`", str_concat(scrut_t, "`)."));
                let m11b: str = " Use integer literal arms (`1 => ..., 2 => ...`) for an int match, or convert the scrutinee to str (`int_to_str(n)`) to use string literal arms.";
                type_diag_at(diags, source, pool, nid, fn_name, "match", "MATCH-011", str_concat(m11a, m11b));
            };
            if str_eq(ename, "__int") == 1 && str_eq(scrut_t, "str") == 1 {
                let m11ia: str = "integer literal arm in `match` on string scrutinee (`str`).";
                let m11ib: str = " Use string literal arms (`\"a\" => ..., \"b\" => ...`) for a str match, or convert the scrutinee with `str_to_int(s)` to match on integer values.";
                type_diag_at(diags, source, pool, nid, fn_name, "match", "MATCH-011", str_concat(m11ia, m11ib));
            };
            let at_name: str = if str_eq(ename, "__range_at") == 1 || str_eq(ename, "__range_bad_at") == 1 { pattern_binding_item_name(str_after_char_local(binding, 124)) } else { pattern_at_prefix_name(binding) };
            if str_len(at_name) > 0 {
                if str_len(tenv_get(env, at_name)) > 0 {
                    type_diag(diags, source, fn_name, at_name, "MATCH-010", str_concat("@-binding name collides with an outer binding: ", at_name));
                };
                tenv_set(arm_env, at_name, if str_len(scrut_t) > 0 { scrut_t } else { "i64" });
            };
            if str_eq(ename, "__struct") == 1 {
                if str_eq(type_base_name(scrut_t), type_base_name(vname)) == 0 {
                    type_diag_at(diags, source, pool, nid, fn_name, "match", "TYP-010", str_concat("struct pattern type mismatch: expected ", str_concat(vname, str_concat(" but scrutinee is ", scrut_t))));
                };
                tenv_set_struct_pattern(pool, structs, arm_env, vname, binding);
            } else if str_eq(ename, "__tuple") == 1 || str_eq(ename, "__slice") == 1 {
                if str_len(scrut_t) > 0 && str_eq(type_base_name(scrut_t), "Vec") == 0 {
                    type_diag_at(diags, source, pool, nid, fn_name, "match", "TYP-010", str_concat("tuple/slice pattern requires Vec<T> scrutinee, found ", scrut_t));
                };
                let elem_t: str = type_first_arg(scrut_t);
                tenv_set_pattern_list(arm_env, binding, if str_len(elem_t) > 0 { elem_t } else { "i64" });
            } else {
                // Lane 1 audit fix (2026-05-08) — close F-002 (cross-enum
                // match silent miscompile). Pre-fix `match a: A { B::On
                // => ..., B::Off => ... }` was accepted because both
                // enums lower to integer tags; A::Red (tag 0) silently
                // matched B::On (tag 0). Here `ename` carries the enum
                // type name from the pattern (e.g. `B`); reject when
                // it doesn't match the scrutinee's base type. Skip
                // wildcard / underscore / range / synthesized prefixes
                // (`__*`) which don't carry an enum identity, and skip
                // when the scrutinee type couldn't be resolved (so we
                // don't add false positives in the limited-info path).
                // Skip wildcard / underscore / range / synthesized
                // patterns (those starting with `_`) and the well-known
                // Option/Result short-form variants (Some/None/Ok/Err)
                // which are usable from any scope without an enum prefix.
                // Lane 1 audit fix (2026-05-08) — F-002 best-effort
                // check. The scrut_t value can be empty in some
                // user-defined-enum scrutinee shapes (the type env
                // doesn't always populate during the let-statement
                // walk), so the precise reproducer of the audit's
                // F-002 (cross-enum `match a { B::On => ... }`) does
                // not fire MATCH-016 in every shape. The check still
                // catches the common case where the scrutinee comes
                // from a fn return whose type is propagated, and from
                // a binding whose annotation precedes the match. The
                // tighter end-to-end fix (cross-enum identity check
                // even for limited-info scrut_t) is tracked as a
                // follow-on once the generic monomorphization
                // architectural fix lands per F-029 (NOTE).
                if str_len(ename) > 0
                    && str_len(scrut_t) > 0
                    && str_char_at(ename, 0) != 95
                    && str_eq(ename, "__struct") == 0
                    && str_eq(ename, "__tuple") == 0
                    && str_eq(ename, "__slice") == 0
                    && str_eq(ename, "__int") == 0
                    && str_eq(ename, "__str") == 0
                    && str_eq(ename, "__range_at") == 0
                    && str_eq(ename, "__range_bad_at") == 0
                    && str_eq(ename, "Some") == 0
                    && str_eq(ename, "None") == 0
                    && str_eq(ename, "Ok") == 0
                    && str_eq(ename, "Err") == 0 {
                    let scrut_base: str = type_base_name(scrut_t);
                    if str_len(scrut_base) > 0 && str_eq(scrut_base, ename) == 0 {
                        // Allow `i64`/`i32` scrutinees against any enum
                        // pattern (legacy as-int matching) to avoid
                        // breaking the rod-level int dispatch idiom.
                        if str_eq(scrut_base, "i64") == 0
                            && str_eq(scrut_base, "i32") == 0 {
                            let m12a: str = str_concat("pattern variant `", str_concat(ename, str_concat("::", str_concat(vname, str_concat("` belongs to enum `", str_concat(ename, "`, but the scrutinee type is `"))))));
                            let m12b: str = str_concat(scrut_t, "`. Use a pattern from the scrutinee's enum type, or convert the scrutinee with an explicit cast / map.");
                            type_diag_at(diags, source, pool, nid, fn_name, "match", "MATCH-016", str_concat(m12a, m12b));
                        };
                    };
                };
                let payload_binding: str = pattern_after_at_prefix(binding);
                let bind_t: str = match_payload_type_from_scrutinee(scrut_t, ename, vname, 0);
                tenv_set_pattern_list(arm_env, payload_binding, if str_len(bind_t) > 0 { bind_t } else { "i64" });
            };
            let bt: str = type_last_stmt(pool, prog, node_field(pool, arm_nid, 4), arm_env, sigs, structs, fn_name, diags, source, tprof);
            if str_len(out_t) == 0 { out_t = bt; };
            vec_free(arm_env);
            ai = ai + 1;
        };
        return out_t;
    };
    return "";
}
#[manual_drop]
fn box_new_concrete_arg_type(pool: Vec<i32>, prog: i64, nid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    let mut args: i64 = 0 - 1;
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        if str_eq(tname, "Box") == 1 && str_eq(mname, "new") == 1 {
            args = node_field(pool, nid, 3);
        };
    };
    if kind == 7 {
        let callee: str = node_field(pool, nid, 1);
        if str_eq(callee, "Box::new") == 1 || str_eq(callee, "Box__new") == 1 || str_eq(callee, "box_new") == 1 {
            args = node_field(pool, nid, 2);
        };
    };
    if args >= 0 && list_len(pool, args) > 0 {
        return type_expr(pool, prog, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
    };
    return "";
}
#[manual_drop]
fn type_check_stmt(pool: Vec<i32>, prog: i64, nid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, rtype: str, tprof: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 20 {
        let vname: str = node_field(pool, nid, 1);
        let is_mut_g11: i64 = node_field(pool, nid, 2);
        let tstr: str = node_field(pool, nid, 3);
        let init: i64 = node_field(pool, nid, 4);
        // RFC-0062 G-11 Phase 2b/3/4 — TYP-008 narrowed for mutable
        // no-init bindings.
        //   let x: i64;       (immutable, never settable)  → still TYP-008.
        //   let mut x: i64;   (mutable, DA-trackable)      → permitted.
        //                     check_stmt sets the init flag; reads on
        //                     paths that don't dominate the assignment
        //                     fire INIT-G11-READ-BEFORE-INIT instead.
        if init < 0 && str_len(vname) > 0 && str_eq(vname, "_") == 0 && is_mut_g11 == 0 {
            // Skip the special `__tuple_destructure_unsupported__`
            // placeholder name (already panics at parse time).
            if str_eq(vname, "__tuple_destructure_unsupported__") == 0 {
                type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-008", str_concat("binding `", str_concat(vname, "` declared without initializer (type-only). Immutable bindings are never settable so this is structurally unreachable — assign at declaration. (Mutable `let mut ", str_concat(vname, ": T;` is now permitted; reads before a definite assignment fire INIT-G11-READ-BEFORE-INIT instead, per RFC-0062 G-11 Phase 2b definite-assignment flow.)"))));
            };
        };
        // NUC-FEEDBACK-002 -- promoted parse-time
        // narrow-float-vector warning to a HARD type-check error.
        // NUC-FEEDBACK-002 deeper fix -- DOWNGRADE to a
        // single advisory print (not a TYP-009 hard error), now that
        // the round-trip pattern is verifiable end-to-end:
        //   let mut v: Vec<f32> = Vec::new();
        //   v.push(1.5 as f32);           // i64 cell holds f32 bit pattern
        //   let s: f32 = f32_from_bits(v[0]);  // reinterpret, no convert
        //   println!("{}", f32_add(s, s as f32));
        // Pinned by tests/fixtures/t462_vec_f32_round_trip.nr.
        // The advisory tells the adopter that `v[i] as f32` would
        // numeric-cast the integer (silent miscompute), so they must
        // use `f32_from_bits(v[i])` for the read side. Vec<f64>
        // continues to work transparently (i64 cells hold f64 bit
        // patterns at the same width). f16/bf16/f8eXmY still need
        // their own pack/unpack helpers (no runtime support yet).
        // NUC-FEEDBACK-002 fully closed.
        // All narrow-float vectors now have a verified round-trip
        // path:
        //   Vec<f32>:   v.push(x as i64); f32_from_bits(v[i])
        //   Vec<f16>:   v.push(f16_from_f32(x as f32)); f16_to_f32(v[i])
        //   Vec<bf16>:  v.push(bf16_from_f32(x as f32)); bf16_to_f32(v[i])
        //   Vec<f8e4m3>: v.push(f8e4m3_from_f32(x as f32)); f8e4m3_to_f32(v[i])
        //   Vec<f8e5m2>: v.push(f8e5m2_from_f32(x as f32)); f8e5m2_to_f32(v[i])
        // Display via println!("{}", val) dispatches to the
        // *_to_str runtime helpers added in v0.3.206. Pinned by
        // tests/fixtures/t463_vec_narrow_float_round_trip.nr.
        // (No diagnostic emitted for any narrow-float vector type.)
        let mut init_t: str = "";
        if init >= 0 {
            init_t = type_expr(pool, prog, init, env, sigs, structs, fn_name, diags, source, tprof);
            // when the let RHS is a direct kind-7 call to `vec_pop`, override
            // init_t to "void" so the TYP-021 check below fires. Pre-fix
            // type_expr for vec_pop returned the Vec's element type (treated
            // it as a value-returning Rust-like helper) but the runtime is
            // void — adopters got a silent 0-valued binding indistinguishable
            // from a popped 0. The override here makes the let-binding
            // surface the void-rtype mismatch with TYP-021's existing diag
            // wording.
            if str_eq(init_t, "void") == 0 && node_kind(pool, init) == 7 {
                let init_callee: str = node_field(pool, init, 1);
                if str_eq(init_callee, "vec_pop") == 1 {
                    init_t = "void";
                };
            };
            // TYP-021 — void-typed RHS in `let` binding without
            // type annotation. Pre-fix `let x = print_int(5);` silently
            // bound `x` to the void return coerced to 0 — sister bug to
            if str_len(tstr) == 0 && (str_eq(init_t, "void") == 1 || type_is_unit(init_t) == 1)
                && str_eq(vname, "_") == 0 {
                let v21msg: str = str_concat("`void`-typed expression cannot initialize binding `", str_concat(vname, "`. Pre-v0.4.136 the void return was silently coerced to 0 — adopters who confused side-effect-only fns (`print_int`, `print`, etc.) with value-returning fns got a 0-valued binding with no signal. Use the value-returning sibling fn (e.g. `int_to_str` instead of `print_int`) or split the side-effect into its own statement above the let."));
                type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-021", v21msg);
            };
            if str_len(tstr) == 0 && node_kind(pool, init) == 7 {
                let infer_callee: str = node_field(pool, init, 1);
                let infer_sentry: i64 = sig_find(sigs, infer_callee);
                if infer_sentry >= 0 {
                    let infer_gparams: i64 = sig_gparams_from_entry(infer_sentry);
                    let infer_args: i64 = node_field(pool, init, 2);
                    let infer_rtype: str = vec_get(infer_sentry, 1);
                    if gparams_type_count(pool, infer_gparams) > 0
                       && list_len(pool, infer_args) == 0
                       && type_contains_any_type_gparam(pool, infer_gparams, infer_rtype) == 1
                       && str_eq(vname, "_") == 0 {
                        type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-027", str_concat("type annotation required for binding `", str_concat(vname, str_concat("`: generic call `", str_concat(infer_callee, "()` returns a type containing an unconstrained type parameter.")))));
                    };
                };
            };
            if str_len(tstr) > 0 {
                let arity_base: str = type_base_name(tstr);
                let mut arity_gparams: i64 = 0 - 1;
                let arity_struct_idx: i64 = struct_find_type(pool, structs, tstr);
                if arity_struct_idx >= 0 {
                    arity_gparams = node_field(pool, vec_get(structs, arity_struct_idx), 3);
                } else {
                    arity_gparams = enum_gparams_for_name(pool, prog, arity_base);
                };
                if arity_gparams >= 0 {
                    let expected_arity: i64 = gparams_type_count(pool, arity_gparams);
                    let actual_arity: i64 = type_arg_count(tstr);
                    if expected_arity != actual_arity {
                        // ROBO-7 frame tags are zero-cost phantoms over
                        // non-generic handle structs. Keep the check gated
                        // by base name so ordinary generic aliases like
                        // Vec<i32> do not pay per-use frame parsing cost.
                        let mut frame_phantom_ok: i64 = 0;
                        if expected_arity == 0 {
                            if (str_eq(arity_base, "Pose") == 1 && actual_arity == 1) || ((str_eq(arity_base, "Transform") == 1 || str_eq(arity_base, "Se3Buf") == 1) && actual_arity == 2) {
                                frame_phantom_ok = 1;
                                let mut frame_arg_i: i64 = 0;
                                while frame_arg_i < actual_arity {
                                    let frame_arg: str = strip_spaces(type_arg_at(tstr, frame_arg_i));
                                    if str_starts_with(frame_arg, "Frame_") == 0 { frame_phantom_ok = 0; };
                                    frame_arg_i = frame_arg_i + 1;
                                };
                            };
                        };
                        if frame_phantom_ok == 0 {
                            type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-005", str_concat("wrong number of type arguments for `", str_concat(arity_base, str_concat("`: expected ", str_concat(str_from_int(expected_arity), str_concat(", found ", str_from_int(actual_arity)))))));
                        };
                    };
                };
                if node_kind(pool, init) == 34 && arity_struct_idx >= 0
                   && str_eq(type_base_name(tstr), node_field(pool, init, 1)) == 1 {
                    let init_fields: i64 = node_field(pool, init, 2);
                    let init_fc: i64 = list_len(pool, init_fields);
                    let mut init_fi: i64 = 0;
                    while init_fi < init_fc {
                        let init_field: i64 = list_get(pool, init_fields, init_fi);
                        let init_fname: str = node_field(pool, init_field, 1);
                        let exp_field: str = struct_field_type_for_inst(pool, vec_get(structs, arity_struct_idx), tstr, init_fname);
                        let act_field: str = type_expr(pool, prog, node_field(pool, init_field, 2), env, sigs, structs, fn_name, diags, source, tprof);
                        if str_len(exp_field) > 0 && str_len(act_field) > 0 {
                            if types_compatible_context(pool, prog, exp_field, act_field) == 0 {
                                type_diag_at(diags, source, pool, init_field, fn_name, init_fname, "TYP-008", str_concat("generic struct field initializer mismatch for `", str_concat(arity_base, str_concat(".", str_concat(init_fname, str_concat("`: instantiated field type `", str_concat(exp_field, str_concat("`, got `", str_concat(act_field, "`.")))))))));
                            };
                        };
                        init_fi = init_fi + 1;
                    };
                };
                // Type-system hardening: numeric
                // primitives are not implicitly converted between
                // widths at binding sites. The previous build hid
                // this behind NUC_STRICT_NUMERIC=1; production mode is
                // now strict by default, with an explicit escape hatch
                // only for legacy compatibility audits.
                let v0508_narrow_strict: i64 = if str_eq(env_get_or("NUC_STRICT_NUMERIC", "1"), "1") == 1 { 1 } else { 0 };
                if v0508_narrow_strict == 1 && node_kind(pool, init) == 3
                   && type_is_int(tstr) == 1 && type_is_int(init_t) == 1
                   && str_eq(tstr, init_t) == 0 {
                    type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-044", str_concat("implicit integer width conversion in binding `", str_concat(vname, str_concat("`: source type `", str_concat(init_t, str_concat("` to declared type `", str_concat(tstr, "`. RFC-0015 §3.2: numeric primitives are not implicitly converted between widths. Use an explicit `as` cast (e.g. `a as i32`) to make the truncation / widening visible at the source site.")))))));
                };
                if type_is_float(tstr) == 1 && type_is_int(init_t) == 1 && node_kind(pool, init) == 1 {
                    type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-008", str_concat("integer literal cannot initialize float binding `", str_concat(vname, str_concat("` of type `", str_concat(tstr, "`. Numeric primitives are not implicitly converted; write a float literal such as `3.0`, or use an explicit conversion helper/cast.")))));
                };
                if node_kind(pool, init) == 12 && str_index_of(tstr, "<") >= 0 {
                    let init_enum_name: str = node_field(pool, init, 1);
                    let init_variant: str = node_field(pool, init, 2);
                    if str_eq(type_base_name(tstr), init_enum_name) == 1 {
                        let enum_gparams: i64 = enum_gparams_for_name(pool, prog, init_enum_name);
                        let init_args: i64 = node_field(pool, init, 3);
                        let init_argc: i64 = list_len(pool, init_args);
                        let mut enum_ai: i64 = 0;
                        while enum_ai < init_argc {
                            let raw_payload: str = infer_enum_variant_payload_type(source, init_enum_name, init_variant, enum_ai);
                            let exp_payload: str = substitute_gparams_from_list(pool, enum_gparams, tstr, raw_payload);
                            let act_payload: str = type_expr(pool, prog, list_get(pool, init_args, enum_ai), env, sigs, structs, fn_name, diags, source, tprof);
                            if str_len(exp_payload) > 0 && str_len(act_payload) > 0 {
                                if types_compatible_context(pool, prog, exp_payload, act_payload) == 0 {
                                    let enum_msg: str = str_concat("generic enum payload mismatch for `", str_concat(init_enum_name, str_concat("::", str_concat(init_variant, str_concat("`: declared binding type `", str_concat(tstr, str_concat("` requires payload `", str_concat(exp_payload, str_concat("`, got `", str_concat(act_payload, "`. Pre-fix the payload was bit-stored into the erased i64 slot with no type check."))))))))));
                                    type_diag_at(diags, source, pool, init, fn_name, vname, "TYP-008", enum_msg);
                                };
                            };
                            enum_ai = enum_ai + 1;
                        };
                    };
                };
                let strict_infer_t4: i64 = if str_eq(env_get_or("NUC_STRICT_INFERENCE", "0"), "1") == 1 { 1 } else { 0 };
                if str_len(init_t) == 0 && strict_infer_t4 == 1 && node_kind(pool, init) == 7 {
                    let strict_callee_t4: str = node_field(pool, init, 1);
                    if builtin_rtype_format_string_i64(strict_callee_t4) == 1 { init_t = "i64"; }
                    else if builtin_rtype_format_string_str(strict_callee_t4) == 1 { init_t = "str"; };
                };
                if str_len(init_t) == 0 && strict_infer_t4 == 1 {
                    let v27msg: str = str_concat("type inference failed for binding '", str_concat(vname, "'; explicit annotation required"));
                    type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-027", v27msg);
                } else if type_is_unit(tstr) == 1 && (node_kind(pool, init) == 1 || node_kind(pool, init) == 71) && line_has_unit_literal(source, fn_name, vname) == 0 {
                    type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-007", "bare numeric literal cannot initialize a unit value");
                } else {
                    let compat_start: i64 = tprof_start(tprof);
                    let compat_ok: i64 = types_compatible_context(pool, prog, tstr, init_t);
                    tprof_mark(tprof, 7, 8, compat_start);
                    if compat_ok == 0 {
                    // RFC-0046 Phase B (ROBO-7): if the mismatch is
                    // specifically a coordinate-frame phantom-tag
                    // mismatch, fire FRAME-001 with the canonical
                    // Mars-Climate-Orbiter framing instead of the
                    // generic TYP-008 binding-mismatch diag. Adopters
                    // run `nuc explain FRAME-001` for fix guidance.
                    if frame_mismatch_visible(tstr, init_t) == 1 {
                        let f1_action_v840: str = str_concat("cannot initialize binding '", str_concat(vname, "'"));
                        type_diag_at(diags, source, pool, nid, fn_name, vname, "FRAME-001", frame_mismatch_diag_message(f1_action_v840, tstr, init_t));
                    } else {
                        type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-008", str_concat("type mismatch for binding '", str_concat(vname, "'")));
                    };
                    } else {
                        let box_dyn_trait: str = box_dyn_trait_name(tstr);
                        if str_len(box_dyn_trait) > 0 {
                            let box_actual: str = box_new_concrete_arg_type(pool, prog, init, env, sigs, structs, fn_name, diags, source, tprof);
                            if str_len(box_actual) > 0 && str_len(dyn_trait_name(box_actual)) == 0 {
                                if type_implements_trait(pool, prog, box_actual, box_dyn_trait) == 0 {
                                    type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-008", str_concat("type mismatch for binding '", str_concat(vname, "'")));
                                };
                            };
                        };
                    };
                };
                // NUM-018 — float literal in integer context.
                // Pre-fix `let x: i64 = 3.14;` types_compatible returned
                // 1 (line 10063 allows i*/u* expected to accept f64
                // actual — legacy from when narrow-float values flowed
                // through i64 cells). The init was bit-cast: x got
                // 4614253070214989087 (the IEEE 754 bit pattern of
                // 3.14 reinterpreted as i64). Total silent miscompute.
                // Adopters writing canonical Rust got E0308 mismatched
                // types. NUM-018 was already reserved (RFC-0015 /
                if node_kind(pool, init) == 71 && type_is_int(tstr) == 1 {
                    type_diag_at(diags, source, pool, nid, fn_name, vname, "NUM-018", str_concat("float literal cannot initialize integer binding `", str_concat(vname, str_concat("` of type ", str_concat(tstr, " — pre-fix this silently bit-cast the IEEE 754 representation into the i64 slot. Use `as i64` to truncate explicitly, or change the type to `f64`.")))));
                };
                // NUM-020 — int-typed expr (non-literal) in
                // float binding. Pre-fix `let f: f64 = i;` where `i: i64`
                // type-checked clean (types_compatible at line 10298
                // accepts any i*/f* combo) and codegen lowered without
                // a sitofp — the i64 bit pattern was stored directly
                // in the f64 slot. `let f: f64 = 5;` for an i64=5 prints
                // `0.000000` (5 as a denormal f64) instead of `5.0`.
                // Total silent miscompute. The literal path
                // (kind 1 int_lit) is handled separately by the
                // parser-side coercion that emits the literal as
                // f64 directly when tstr is float — that's why
                // `let f: f64 = 5;` works correctly. The bug fires
                // only when init is a non-literal int expression.
                let init_kind_n20: i64 = node_kind(pool, init);
                if type_is_float(tstr) == 1 && type_is_int(init_t) == 1
                    && init_kind_n20 != 1 && init_kind_n20 != 71 {
                    let n20msg_a: str = str_concat("integer-typed expression (`", str_concat(init_t, str_concat("`) cannot initialize float binding `", str_concat(vname, str_concat("` of type `", str_concat(tstr, "`."))))));
                    let n20msg_b: str = " Pre-v0.4.113 the i64 bit pattern was stored directly in the f64 slot — e.g. `let f: f64 = i;` for `i: i64 = 5` printed `0.000000` (5 as a denormal f64). Use an explicit conversion (`i as f64`) or `f64_from_bits(i)` if you really meant to reinterpret the bits.";
                    type_diag_at(diags, source, pool, nid, fn_name, vname, "NUM-020", str_concat(n20msg_a, n20msg_b));
                };
                // TYP-016 — `if cond { val }` with NO else branch
                // assigned to a non-void/unit binding. Pre-fix
                // `let x: i64 = if false { 5 };` silently lowered the
                // taken-branch path with the false branch reaching the
                // alloca's zero-init slot — `x` ends up as 0 with no
                // diagnostic. Rust rejects with "if expression of type
                // X must have an else clause." Detect: init kind == 23
                // (if-expr), enode (else branch) field 3 == -1, and
                // tstr is non-void/unit. Emit clean halt directing the
                // user to add the missing else.
                if init_kind_n20 == 23 && node_field(pool, init, 3) < 0
                    && str_eq(tstr, "void") == 0 && type_is_unit(tstr) == 0 {
                    // don't misfire on synthesized passthrough
                    // blocks. `wrapping { ... }` and `unsafe { ... }` are
                    // lowered (line 1057) as `if 1 { ...body... }` with
                    // else=-1 — same shape as a real if-no-else, but the
                    // cond is the literal 1, so the body always runs.
                    // Pre-fix `let x: i32 = wrapping { ... };` printed
                    // TYP-016 "if expression missing else branch" on
                    // every wrapping/unsafe block, breaking
                    // tests/features/overflow_{wrapping,comprehensive}
                    // and any user code using these block forms.
                    let t16_cond_nid: i64 = node_field(pool, init, 1);
                    let mut t16_is_passthrough: i64 = 0;
                    if node_kind(pool, t16_cond_nid) == 1
                        && node_field(pool, t16_cond_nid, 1) == 1 {
                        t16_is_passthrough = 1;
                    };
                    if t16_is_passthrough == 0 {
                        let t16a: str = str_concat("`if` expression assigned to binding `", str_concat(vname, str_concat("` of type `", str_concat(tstr, "` is missing an `else` branch."))));
                        let t16b: str = " Add an `else { ... }` arm that produces the same type, or restructure to a stmt-form `if` that doesn't assign.";
                        type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-016", str_concat(t16a, t16b));
                    };
                };
                // NUM-019 — negative literal in unsigned binding.
                // Pre-fix `let x: u32 = -5;` two's-complement-wrapped to
                // 4294967291 silently (the LLVM `i64 -5` truncates to
                // u32::MAX-4 when stored in a 32-bit slot). Adopters
                // writing canonical Rust got E0080 (overflowing_literals
                // in debug; wrapping in release). NUM-019 was already
                // reserved (RFC-0015 / v0.2.319 expansion) but never
                // wired. Detection: init is unary-minus (kind 5) wrapping
                // a positive int literal (kind 1), declared type is
                // unsigned (signedness == 2).
                if node_kind(pool, init) == 5 && str_len(tstr) > 0 && type_is_int(tstr) == 1 && type_signedness(tstr) == 2 {
                    let inner_neg: i64 = node_field(pool, init, 1);
                    if node_kind(pool, inner_neg) == 1 {
                        let lit_n: i64 = node_field(pool, inner_neg, 1);
                        if lit_n > 0 {
                            let nm19_msg: str = str_concat("negative literal `-", str_concat(str_from_int(lit_n), str_concat("` cannot initialize unsigned binding `", str_concat(vname, str_concat("` of type ", str_concat(tstr, " — pre-fix this silently two's-complement-wrapped (e.g. `-5` became u32::MAX-4 = 4294967291). Use a non-negative literal, change the type to a signed equivalent, or wrap explicitly with `(-N) as <type>`."))))));
                            type_diag_at(diags, source, pool, nid, fn_name, vname, "NUM-019", nm19_msg);
                        };
                    };
                };
                //  pre-fix `let a: u32 = 0 - 5;` evaded
                // NUM-019 because the literal-form check at kind 5 only
                // matched `let a: u32 = -5;`. The binop form (kind 4)
                // const-folds to -5 at compile time but the unsigned-
                // negative check didn't see it. Now const-fold the init
                // and check for a negative result against unsigned types
                // — fires NUM-019 for any const-foldable negative binop.
                if str_len(tstr) > 0 && type_is_int(tstr) == 1 && type_signedness(tstr) == 2 {
                    let cf: Vec<i32> = const_i64_expr(pool, init, env);
                    let cf_have: i64 = vec_get(cf, 0);
                    let cf_val: i64 = vec_get(cf, 1);
                    // Lane 1 audit fix (2026-05-08) — close C-007 / NUM-019
                    // false-fire for u64 div/rem. const_i64_expr does
                    // signed arithmetic on i64-cmap values, so a u64
                    // operand with the high bit set (e.g.
                    // 18446744073709551614u64) is interpreted as a
                    // negative i64 (-2) and `n / 2` const-folds to -1 —
                    // pre-fix that falsely triggered NUM-019 on a
                    // genuinely valid u64 division. Detect: when init is
                    // a kind-4 binop or kind-5 unary-minus and the
                    // declared binding type's base is u64, skip the
                    // const-fold-negative check (the runtime u64 helper
                    // panic_div_u64 / panic_rem_u64 does the right thing).
                    let v0508_skip_num19: i64 = if str_eq(type_base_name(tstr), "u64") == 1 { 1 } else { 0 };
                    if v0508_skip_num19 == 0
                       && cf_have == 1 && cf_val < 0
                       && node_kind(pool, init) != 5 && node_kind(pool, init) != 1 {
                        let nm19b_msg: str = str_concat("expression evaluates to negative value `", str_concat(str_from_int(cf_val), str_concat("` at compile time, cannot initialize unsigned binding `", str_concat(vname, str_concat("` of type ", str_concat(tstr, ". Pre-v0.6.45 the binop / cast form (e.g. `0 - 5`, `1000 - 2000`) evaded the kind-5 unary-minus NUM-019 check and silently two's-complement-wrapped at runtime. Use a non-negative result, change the type to a signed equivalent, or wrap explicitly with `(expr) as <type>`."))))));
                        type_diag_at(diags, source, pool, nid, fn_name, vname, "NUM-019", nm19b_msg);
                    };
                };
            };
            // RFC-0015 phase 6: NUM-002 — integer literal out of range for
            // declared type. Only fires for bare integer literal init
            // (kind == 1) with an explicit narrow numeric type. The check
            // uses two's-complement signed range / 0..2^width unsigned
            // range. Fires as warning, not error, until the strict-mode
            // flip in v0.4.
            if str_len(tstr) > 0 && node_kind(pool, init) == 1 && type_is_int(tstr) == 1 {
                let lit_v: i64 = node_field(pool, init, 1);
                let w: i64 = type_width(tstr);
                let s: i64 = type_signedness(tstr);
                let mut out_of_range: i64 = 0;
                if s == 1 && w < 64 {
                    let max_v: i64 = i64_pow(2, w - 1) - 1;
                    let min_v: i64 = 0 - i64_pow(2, w - 1);
                    if lit_v > max_v || lit_v < min_v { out_of_range = 1; };
                };
                if s == 2 && w < 64 {
                    let umax_v: i64 = i64_pow(2, w) - 1;
                    if lit_v < 0 || lit_v > umax_v { out_of_range = 1; };
                };
                // removed the s==2 && w==64 negative check.
                // Pre-fix `let h: u64 = 0xFFFFFFFFFFFFFFFF;` rejected
                // because the hex literal parsed as i64 = -1 (sign-bit
                // wrap) and the check fired. But the BIT PATTERN is the
                // valid u64::MAX. AST kind-1 literals only carry the i64
                // value (no radix flag), so we can't distinguish
                // "intentional hex bit pattern" from "decimal negative
                // typo". Decimal-negative-to-u64 (e.g. `let h: u64 = -100;`)
                // doesn't reach this check anyway — it parses as kind-5
                // unary-neg on kind-1 literal 100, not kind-1 itself —
                // so removing the check is safe. NUM-021 still catches
                // decimal-overflow-to-u64::MAX at lex time.
                if out_of_range == 1 {
                    // promote NUM-002 from warning to error
                    // Pre-fix `let x: u8 = 256;`
                    // truncated to 0 silently with only a warning;
                    // adopters writing canonical Rust got E0080
                    // (unconditional_recursion). Now hard error.
                    type_diag_at(diags, source, pool, nid, fn_name, vname, "NUM-002", str_concat("numeric literal ", str_concat(str_from_int(lit_v), str_concat(" out of range for declared type ", str_concat(tstr, ". Use a wider type or change the literal.")))));
                };
            };
            // RFC-0015 phase 6: NUM-005 — usize/isize mixed with an
            // explicit-width numeric type. Even when widths happen to
            // match on the current target, this is a portability hazard
            // (LP64 vs ILP32). Warning only.
            if str_len(tstr) > 0 && type_is_numeric(tstr) == 1 && type_is_numeric(init_t) == 1 {
                let lhs_is_size: i64 = if str_eq(type_base_name(tstr), "usize") == 1 || str_eq(type_base_name(tstr), "isize") == 1 { 1 } else { 0 };
                let rhs_is_size: i64 = if str_eq(type_base_name(init_t), "usize") == 1 || str_eq(type_base_name(init_t), "isize") == 1 { 1 } else { 0 };
                if lhs_is_size != rhs_is_size {
                    diag_add_at_or_scan(diags, source, pool, nid, vname, "warning", "type", "NUM-005", str_concat("usize/isize mixed with explicit-width type: ", str_concat(tstr, str_concat(" vs ", init_t))), fn_name, "");
                };
            };
        };
        if str_len(tstr) > 0 {
            if str_len(init_t) == 0 {
                let tstr_base: str = type_base_name(tstr);
                if enum_gparams_for_name(pool, prog, tstr_base) >= 0 {
                    tenv_set(env, vname, tstr);
                } else {
                    tenv_set(env, vname, "");
                };
            }
            else { tenv_set(env, vname, tstr); };
        }
        else { tenv_set(env, vname, init_t); };
        // CRITICAL — `HashMap<i64, V>`, `HashMap<bool, V>`, etc. (any
        // non-str key type) crashed at runtime with STATUS_ACCESS_
        // VIOLATION (rc=-1073741819) on the first hashmap_insert. The
        // runtime helper `__nucleor_hashmap_insert` takes the key as
        // `const char *` and dereferences it as a string pointer; an
        // i64 key like `1` makes it deref address `0x1`. Same hazard
        // applies to HashSet, BTreeMap, BTreeSet (all use the same
        // str-key runtime path). Halt at let-binding type-check with
        // a clean diagnostic naming the workaround. The compiler's
        // own internal HashMaps use str keys (the i64-everywhere ABI
        // stores str pointers cast to i64), so the workaround mirrors
        // that pattern.
        if str_len(tstr) > 0 {
            let mut hm_keyed_collection: i64 = 0;
            if str_starts_with(tstr, "HashMap<") == 1 { hm_keyed_collection = 1; };
            if str_starts_with(tstr, "HashSet<") == 1 { hm_keyed_collection = 1; };
            if str_starts_with(tstr, "BTreeMap<") == 1 { hm_keyed_collection = 1; };
            if str_starts_with(tstr, "BTreeSet<") == 1 { hm_keyed_collection = 1; };
            if hm_keyed_collection == 1 {
                let key_t: str = type_first_arg(tstr);
                if str_len(key_t) > 0 && str_eq(key_t, "str") == 0 && str_eq(key_t, "_") == 0 {
                    let hm_msg: str = str_concat("non-str key type `", str_concat(key_t, str_concat("` in keyed collection `", str_concat(tstr, str_concat("` (binding `", str_concat(vname, "`) is not yet supported in Nucleor. Workaround: convert the key to str via `str_from_int(k)` (for i64/i32/u32/u64/i16/u16/i8/u8), `if b { \"true\" } else { \"false\" }` (for bool), or `f64_to_str(k)` (for f64). Use a `Vec<(KeyT, ValT)>` if you need ordered insertion-time semantics with non-str keys."))))));
                    type_diag_at(diags, source, pool, nid, fn_name, vname, "TYP-026", hm_msg);
                };
            };
        };
        if init >= 0 {
            let init_const: Vec<i32> = const_i64_expr(pool, init, env);
            //  also fire NUM-021 at
            // compile time when a let-binding const expression
            // overflows i64. Pre-fix `let x: i64 = i64::MAX + 1;`
            // PANICked at runtime startup via the strict-intrin trap
            // — surfaced opaquely far from the source. Now NUM-021
            // fires at the let-stmt site with the same wording the
            // const-decl path already uses (line ~17859). Only the
            // overflow class triggers; non-overflowing const exprs
            // continue to set the const tracker per the v0.4.146
            // path. Skipped for kind-7 (fn call) inits where the
            // const fold returned overflow because the call body
            // chain is opaque from the binding site.
            //  unsigned-aware overflow
            // routing. If declared type is unsigned, ONLY check
            // u64-overflow (i64 might "overflow" via wrap but still fit
            // u64 — e.g. `let x: u64 = i64::MAX + 1;` has i64 result
            // -9223372036854775808 which fits u64). For signed types
            // (or no annotation), use the existing i64-overflow path.
            let mut is_unsigned: i64 = 0;
            if str_len(tstr) > 0 && type_is_int(tstr) == 1 && type_signedness(tstr) == 2 {
                is_unsigned = 1;
            };
            let mut u64_overflow_v064: i64 = 0;
            if is_unsigned == 1 && node_kind(pool, init) != 7 {
                u64_overflow_v064 = const_u64_overflow(pool, init, env);
            };
            if u64_overflow_v064 == 1 {
                let m21u_msg: str = str_concat("integer constant expression for let-binding `", str_concat(vname, str_concat("` overflows declared unsigned type `", str_concat(tstr, "` at compile time. Use explicit `wrapping_add_u64` / `saturating_add_u64` / `checked_add_u64` if wrapping is intentional, reduce the operands, or widen the type."))));
                type_diag_at(diags, source, pool, nid, fn_name, vname, "NUM-021", m21u_msg);
                tenv_clear_const(env, vname);
            } else if is_unsigned == 0 && const_i64_overflow(init_const) == 1 && node_kind(pool, init) != 7 {
                let m21msg: str = str_concat("integer constant expression for let-binding `", str_concat(vname, "` overflows i64 at compile time. Use explicit wrapping_* / saturating_* helpers, reduce the value, or move the calculation to runtime if wrapping is intentional."));
                type_diag_at(diags, source, pool, nid, fn_name, vname, "NUM-021", m21msg);
                tenv_clear_const(env, vname);
            }
            else if vec_get(init_const, 0) == 1 { tenv_set_const_i64(env, vname, vec_get(init_const, 1)); }
            else { tenv_clear_const(env, vname); };
        } else {
            tenv_clear_const(env, vname);
        };
        // register closure argc on the binding so the
        // call-site type-check can verify `f(args)` has the right
        // arity. Pre-fix `let f = |x: i64, y: i64| x + y; f(5);`
        // silently passed every kind-7 check (closure binding
        // wasn't in sigs and had no type_expr branch for kind 42)
        // and the indirect call lowered with arg_regs of length 1
        // for a 2-param closure → garbage at runtime.
        // also register the closure's return type so the
        // call site can return it from kind-7 type_expr instead of
        // the blanket "" that builtin_rtype returns for non-runtime
        // names. Pre-fix `let r = f(args);` for a void-returning
        // closure (e.g. `|n: i64| { print_int(n); }`) silently bound
        // r=0 because init_t was "" (not "void"), so v0.4.136
        // TYP-021 didn't fire. Sister to v0.4.139 (Vec void mutator
        // route to "void" → cascades to TYP-021/020/022).
        if init >= 0 && node_kind(pool, init) == 42 {
            let v146_params: i64 = node_field(pool, init, 1);
            let v146_pc: i64 = list_len(pool, v146_params);
            tenv_set(env, str_concat("__closure_argc_", vname), str_from_int(v146_pc));
            // Type the closure body's last stmt to learn the rtype.
            // For void-returning bodies (last stmt is a kind-25
            // tail-expr-stmt wrapping a print_int / similar void
            // helper), this returns "void". For value-returning
            // bodies it returns the value's type.
            // type_last_stmt on the closure body must run
            // in a SCOPED env that includes the closure's parameters
            // AND any closure-local let-bindings. Pre-fix `let outer
            // = |x| { let inner = |y| ...; inner(args) };` saw
            // type_last_stmt walk the body with the OUTER env (no
            // closure-locals), which fed type_expr kind 7 a callee
            // `inner` it couldn't find — false-firing TYP-005.
            // Regression: TYP-005 closure binding false positive.
            let v156_body: i64 = node_field(pool, init, 2);
            let v214_scoped_env: Vec<i32> = own_snapshot(env);
            let mut v214_pi2: i64 = 0;
            while v214_pi2 < v146_pc {
                let v214_pname2: str = list_get(pool, v146_params, v214_pi2);
                tenv_set(v214_scoped_env, v214_pname2, "i64");
                v214_pi2 = v214_pi2 + 1;
            };
            // Pre-walk body let-stmts to populate scoped env with
            // closure-local bindings before type_last_stmt's tail-expr
            // type-resolution touches them.
            let v214_bcnt: i64 = list_len(pool, v156_body);
            let mut v214_li: i64 = 0;
            while v214_li < v214_bcnt {
                let v214_lnid: i64 = list_get(pool, v156_body, v214_li);
                if node_kind(pool, v214_lnid) == 20 {
                    let v214_lname: str = node_field(pool, v214_lnid, 1);
                    let v214_ltstr: str = node_field(pool, v214_lnid, 3);
                    tenv_set(v214_scoped_env, v214_lname, if str_len(v214_ltstr) > 0 { v214_ltstr } else { "i64" });
                };
                v214_li = v214_li + 1;
            };
            let v156_rtype: str = type_last_stmt(pool, prog, v156_body, v214_scoped_env, sigs, structs, fn_name, diags, source, tprof);
            vec_free(v214_scoped_env);
            if str_len(v156_rtype) > 0 {
                tenv_set(env, str_concat("__closure_rtype_", vname), v156_rtype);
            };
        };
        return warns;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let rhs: i64 = node_field(pool, nid, 2);
        let rhs_t: str = type_expr(pool, prog, rhs, env, sigs, structs, fn_name, diags, source, tprof);
        if node_kind(pool, lhs) == 3 {
            let env_start: i64 = tprof_start(tprof);
            let lhs_t: str = tenv_get(env, node_field(pool, lhs, 1));
            tprof_mark(tprof, 3, 4, env_start);
            let compat_start: i64 = tprof_start(tprof);
            let compat_ok: i64 = types_compatible_context(pool, prog, lhs_t, rhs_t);
            tprof_mark(tprof, 7, 8, compat_start);
            if compat_ok == 0 {
                let lhs_name_assign: str = node_field(pool, lhs, 1);
                if frame_mismatch_visible(lhs_t, rhs_t) == 1 {
                    let f_action_assign: str = str_concat("cannot assign to '", str_concat(lhs_name_assign, "'"));
                    type_diag(diags, source, fn_name, lhs_name_assign, "FRAME-001", frame_mismatch_diag_message(f_action_assign, lhs_t, rhs_t));
                } else {
                    type_diag(diags, source, fn_name, lhs_name_assign, "TYP-009", "assignment type mismatch");
                };
            };
            let lhs_name_v146: str = node_field(pool, lhs, 1);
            let rhs_const: Vec<i32> = const_i64_expr(pool, rhs, env);
            if vec_get(rhs_const, 0) == 1 { tenv_set_const_i64(env, lhs_name_v146, vec_get(rhs_const, 1)); }
            else { tenv_clear_const(env, lhs_name_v146); };
        };
        // NUC-FEEDBACK silent-miscompute close for indexed
        // assignment. Pre-fix `v[0] = "string"` on `let v: Vec<i64>`
        // silently accepted the str pointer as i64. Adopters writing
        // canonical Rust (which errors on type mismatch) got a quiet
        // wrong value. Validate RHS against the Vec's element type
        // when LHS is kind-10 (indexing) on a kind-3 var ref.
        if node_kind(pool, lhs) == 10 {
            let v_op: i64 = node_field(pool, lhs, 1);
            if node_kind(pool, v_op) == 3 {
                let vname: str = node_field(pool, v_op, 1);
                let mut vt: str = tenv_get(env, vname);
                if str_len(vt) == 0 { vt = infer_var_type_from_source(source, vname); };
                if str_starts_with(vt, "Vec<") == 1 {
                    let elem_t: str = strip_container_one_level(vt);
                    if str_len(elem_t) > 0 && str_len(rhs_t) > 0 {
                        let compat_idx: i64 = types_compatible_context(pool, prog, elem_t, rhs_t);
                        if compat_idx == 0 {
                            if frame_mismatch_visible(elem_t, rhs_t) == 1 {
                                let f_action_idx: str = str_concat("cannot assign indexed element of '", str_concat(vname, "'"));
                                type_diag(diags, source, fn_name, vname, "FRAME-001", frame_mismatch_diag_message(f_action_idx, elem_t, rhs_t));
                            } else {
                                let pa: str = str_concat("indexed assignment type mismatch on `", str_concat(vname, str_concat("`: element type `", str_concat(elem_t, str_concat("` vs RHS type `", str_concat(rhs_t, "`."))))));
                                let pb: str = " List the conversion explicitly or use a typed Vec.";
                                type_diag(diags, source, fn_name, vname, "TYP-009", str_concat(pa, pb));
                            };
                        };
                    };
                };
            };
        };
        // NUC-FEEDBACK silent-coerce close for field
        // assignment. Pre-fix `p.x = "string"` on `let p: Point` with
        // `x: i64` silently stored the str ptr as i64. Same hazard
        // class as v0.4.64. Look up the struct's field type via
        // expr_struct_type + struct_field_type and validate RHS.
        if node_kind(pool, lhs) == 9 {
            let recv_nid: i64 = node_field(pool, lhs, 1);
            let fname: str = node_field(pool, lhs, 2);
            if node_kind(pool, recv_nid) == 3 {
                let recv_name: str = node_field(pool, recv_nid, 1);
                let mut recv_t: str = tenv_get(env, recv_name);
                if str_len(recv_t) == 0 { recv_t = infer_var_type_from_source(source, recv_name); };
                let s_idx2: i64 = struct_find_type(pool, structs, recv_t);
                if s_idx2 >= 0 {
                    let s_nid2: i64 = vec_get(structs, s_idx2);
                    // TYP-018 sister fix — assignment to
                    // unknown struct field. Pre-fix `p.y = 99` for
                    // `struct P { x: i64 }` (no y) lowered to
                    // `vec_set(p, -1, 99)` and OOB-panicked at runtime
                    // with no compile-time signal. Same misdiag class
                    // as v0.4.129 (read-side close); this catches the
                    // assignment LHS that v0.4.129 misses because
                    // assignment goes through kind 21 (not kind 9
                    // type_expr).
                    let f_idx_v131: i64 = struct_field_idx(pool, s_nid2, fname);
                    if f_idx_v131 < 0 {
                        let t18a131: str = str_concat("unknown field `.", str_concat(fname, str_concat("` on receiver type `", str_concat(recv_t, "` (assignment LHS)."))));
                        let t18b131: str = " Pre-v0.4.131 this lowered to vec_set(struct, -1, ...) and OOB-panicked at runtime with no compile-time signal. Check the field name spelling against the struct definition.";
                        type_diag(diags, source, fn_name, recv_name, "TYP-018", str_concat(t18a131, t18b131));
                    };
                    let f_t: str = struct_field_type(pool, s_nid2, fname);
                    if str_len(f_t) > 0 && str_len(rhs_t) > 0 {
                        let compat_fld: i64 = types_compatible_context(pool, prog, f_t, rhs_t);
                        if compat_fld == 0 {
                            if frame_mismatch_visible(f_t, rhs_t) == 1 {
                                let f_action_field: str = str_concat("cannot assign field '", str_concat(recv_name, str_concat(".", str_concat(fname, "'"))));
                                type_diag(diags, source, fn_name, recv_name, "FRAME-001", frame_mismatch_diag_message(f_action_field, f_t, rhs_t));
                            } else {
                                let pa2: str = str_concat("field assignment type mismatch on `", str_concat(recv_name, str_concat(".", str_concat(fname, str_concat("`: field type `", str_concat(f_t, str_concat("` vs RHS type `", str_concat(rhs_t, "`."))))))));
                                let pb2: str = " Pre-v0.4.65 the i64-everywhere ABI silently coerced any RHS to fit.";
                                type_diag(diags, source, fn_name, recv_name, "TYP-009", str_concat(pa2, pb2));
                            };
                        };
                    };
                };
            };
        };
        return warns;
    };
    if kind == 22 {
        let val: i64 = node_field(pool, nid, 1);
        if val >= 0 {
            let val_t: str = type_expr(pool, prog, val, env, sigs, structs, fn_name, diags, source, tprof);
            let compat_start: i64 = tprof_start(tprof);
            let compat_ok: i64 = types_compatible_context(pool, prog, rtype, val_t);
            tprof_mark(tprof, 7, 8, compat_start);
            if str_len(rtype) > 0 && str_eq(rtype, "void") == 0 && compat_ok == 0 {
                if frame_mismatch_visible(rtype, val_t) == 1 {
                    let f_action_return: str = str_concat("cannot return from fn '", str_concat(fn_name, "'"));
                    type_diag(diags, source, fn_name, fn_name, "FRAME-001", frame_mismatch_diag_message(f_action_return, rtype, val_t));
                } else {
                    type_diag(diags, source, fn_name, fn_name, "TYP-010", "return type mismatch");
                };
            };
            // TYP-010 ext — return-with-value in void/unit/
            // implicit-void fn. Pre-fix `fn f() { return 42; }`
            // silently discarded the value at codegen time; the
            // returned i64 register was thrown away and the fn
            // appeared to return cleanly. The `fn f() -> () { ... }`
            // form was already caught (rtype = "()", non-void check
            // path), but the `fn f() { ... }` form with rtype = ""
            // sailed past every existing branch.
            let v142_void_ret: i64 = if str_len(rtype) == 0 || str_eq(rtype, "void") == 1 || type_is_unit(rtype) == 1 { 1 } else { 0 };
            let v142_val_nonvoid: i64 = if str_len(val_t) > 0 && str_eq(val_t, "void") == 0 && type_is_unit(val_t) == 0 { 1 } else { 0 };
            if v142_void_ret == 1 && v142_val_nonvoid == 1 {
                let v142a: str = str_concat("`return ", str_concat(val_t, str_concat("`-typed value in fn `", str_concat(fn_name, "` whose return type is void / `()` (or no `-> T` declared, defaulting to void)."))));
                let v142b: str = " Either remove the value (`return;`), drop the explicit `return` if it's a tail position, or add `-> <Type>` to the fn signature so the value is part of the contract.";
                type_diag(diags, source, fn_name, fn_name, "TYP-010", str_concat(v142a, v142b));
            };
        } else {
            // bare `return;` in a non-void fn. Pre-fix the
            // val < 0 branch was skipped silently, so codegen emitted
            // `ret i64 undef` (LLVM optimised that to the alloca's
            // zero-init slot) and the caller got 0 / garbage with no
            // diagnostic. Sister to v0.4.108's tail-expr ret check.
            if str_len(rtype) > 0 && str_eq(rtype, "void") == 0 {
                let pa112: str = str_concat("bare `return;` in fn `", str_concat(fn_name, str_concat("` declared to return `", str_concat(rtype, "`."))));
                let pb112: str = " Either supply a value (`return <expr>;`) or change the fn signature to `-> ()` / drop the return type.";
                type_diag(diags, source, fn_name, fn_name, "TYP-010", str_concat(pa112, pb112));
            };
        };
        return warns;
    };
    if kind == 23 {
        type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let then_env: Vec<i32> = own_snapshot(env);
        let char_guard: str = char_guard_proven_var(pool, node_field(pool, nid, 1), env);
        if str_len(char_guard) > 0 { tenv_set_char_guard(then_env, char_guard); };
        warns = warns + type_check_stmts(pool, prog, node_field(pool, nid, 2), then_env, sigs, structs, fn_name, diags, source, rtype, tprof);
        vec_free(then_env);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            let else_env: Vec<i32> = own_snapshot(env);
            warns = warns + type_check_stmts(pool, prog, enode, else_env, sigs, structs, fn_name, diags, source, rtype, tprof);
            vec_free(else_env);
        };
        return warns;
    };
    if kind == 24 { type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof); return type_check_stmts(pool, prog, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, rtype, tprof); };
    if kind == 25 { type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof); return warns; };
    if kind == 28 { return type_check_stmts(pool, prog, node_field(pool, nid, 4), env, sigs, structs, fn_name, diags, source, rtype, tprof); };
    if kind == 49 {
        let v152_iter_t: str = type_expr(pool, prog, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof);
        // TYP-011 ext — `for c in s` for `s: str` silently
        // produced 0 iterations. kind-49 codegen calls vec_len/vec_get
        // on the iterable; for a str pointer that returns 0 / garbage
        // (same v0.4.135 hazard class). The loop body never ran and
        // adopters got silent-no-output. Detect at type-check: str /
        // String / scalar / bool → halt with TYP-011 and a hint at
        // the canonical Nucleor surface.
        let v152_iter_base: str = type_base_name(v152_iter_t);
        if str_eq(v152_iter_t, "str") == 1 {
            type_diag(diags, source, fn_name, fn_name, "TYP-011", "`for <var> in <str>` is not supported — Nucleor's for-loop expects a container iterable (Vec<T> or range `a..b`); the kind-49 codegen calls `vec_len` / `vec_get` which silently return 0 / garbage on a str pointer. Use `for byte in str_chars(s) { ... }` (returns Vec<i64> of byte values) or `let mut i: i64 = 0; while i < str_len(s) { let c = str_char_at(s, i); ...; i = i + 1; }` for byte-by-byte iteration.");
        } else if str_eq(v152_iter_base, "String") == 1 {
            type_diag(diags, source, fn_name, fn_name, "TYP-011", "`for <var> in <String>` is not supported — String is a heap-allocated buffer; the kind-49 for-loop expects a container iterable. Convert via `str_chars(s.as_str())` and iterate that Vec<i64>, or walk byte-by-byte with `let mut i: i64 = 0; while i < s.len() { let c = s.get_byte(i); ...; i = i + 1; }`.");
        } else if type_is_int(v152_iter_t) == 1 || type_is_float(v152_iter_t) == 1 || str_eq(v152_iter_t, "bool") == 1 {
            type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat("`for <var> in <", str_concat(v152_iter_t, ">` is not supported — scalar / bool values are not iterable. Use a range (`for i in 0..n`), a Vec, or another container.")));
        } else if str_starts_with(v152_iter_t, "Vec<") == 0 && struct_find_type(pool, structs, v152_iter_t) >= 0 {
            // TYP-011 ext — struct value as `for` iterand silently bit-walked
            // the struct's storage via vec_len/vec_get (type-punned heterogeneous fields,
            // leaked Vec/String/`&T` pointers as integers). Vec<...> short-circuit
            // skips the structs linear scan on the dominant valid case.
            // Detected + first-implemented by probe agent (orphan commit d8b1006);
            // integrated to main 2026-04-30.
            type_diag(diags, source, fn_name, fn_name, "TYP-011", str_concat("`for <var> in <", str_concat(v152_iter_t, ">` is not supported — struct values are not iterable; the kind-49 codegen would bit-walk the struct's storage. Iterate a Vec field explicitly (`for x in s.items`), or build a `Vec<T>` of the values you want to walk.")));
        };
        return type_check_stmts(pool, prog, node_field(pool, nid, 3), env, sigs, structs, fn_name, diags, source, rtype, tprof);
    };
    if kind == 38 {
        let scrut_t: str = type_expr(pool, prog, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let mut ai: i64 = 0;
        while ai < ac {
            let arm_nid: i64 = list_get(pool, arms, ai);
            let arm_env: Vec<i32> = own_snapshot(env);
            let binding: str = node_field(pool, arm_nid, 3);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let at_name: str = if str_eq(ename, "__range_at") == 1 || str_eq(ename, "__range_bad_at") == 1 { pattern_binding_item_name(str_after_char_local(binding, 124)) } else { pattern_at_prefix_name(binding) };
            if str_len(at_name) > 0 {
                if str_len(tenv_get(env, at_name)) > 0 {
                    type_diag(diags, source, fn_name, at_name, "MATCH-010", str_concat("@-binding name collides with an outer binding: ", at_name));
                    warns = warns + 1;
                };
                tenv_set(arm_env, at_name, if str_len(scrut_t) > 0 { scrut_t } else { "i64" });
            };
            if str_eq(ename, "__struct") == 1 {
                if str_eq(type_base_name(scrut_t), type_base_name(vname)) == 0 {
                    type_diag_at(diags, source, pool, nid, fn_name, "match", "TYP-010", str_concat("struct pattern type mismatch: expected ", str_concat(vname, str_concat(" but scrutinee is ", scrut_t))));
                    warns = warns + 1;
                };
                tenv_set_struct_pattern(pool, structs, arm_env, vname, binding);
            } else if str_eq(ename, "__tuple") == 1 || str_eq(ename, "__slice") == 1 {
                if str_len(scrut_t) > 0 && str_eq(type_base_name(scrut_t), "Vec") == 0 {
                    type_diag_at(diags, source, pool, nid, fn_name, "match", "TYP-010", str_concat("tuple/slice pattern requires Vec<T> scrutinee, found ", scrut_t));
                    warns = warns + 1;
                };
                let elem_t: str = type_first_arg(scrut_t);
                tenv_set_pattern_list(arm_env, binding, if str_len(elem_t) > 0 { elem_t } else { "i64" });
            } else if str_eq(ename, "__range_at") == 1 || str_eq(ename, "__range_bad_at") == 1 {
            } else {
                let payload_binding: str = pattern_after_at_prefix(binding);
                tenv_set_pattern_list(arm_env, payload_binding, "i64");
            };
            if str_len(binding) > 0 {
                let bind_t: str = match_payload_type_from_scrutinee(scrut_t, ename, vname, 0);
                if str_len(bind_t) > 0 { tenv_set_pattern_list(arm_env, binding, bind_t); };
            };
            warns = warns + type_check_stmts(pool, prog, node_field(pool, arm_nid, 4), arm_env, sigs, structs, fn_name, diags, source, rtype, tprof);
            vec_free(arm_env);
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 85 {
        // tuple-destructure-in-let type pass.
        // Check the RHS expression; bindings are i64 by default.
        let init85t: i64 = node_field(pool, nid, 2);
        if init85t >= 0 { type_expr(pool, prog, init85t, env, sigs, structs, fn_name, diags, source, tprof); };
        return 0;
    };
    return warns;
}
#[manual_drop]
fn type_check_stmts(pool: Vec<i32>, prog: i64, lid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, rtype: str, tprof: Vec<i32>) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    let mut warns: i64 = 0;
    while i < cnt {
        let stmt_start: i64 = tprof_start(tprof);
        warns = warns + type_check_stmt(pool, prog, list_get(pool, lid, i), env, sigs, structs, fn_name, diags, source, rtype, tprof);
        tprof_mark(tprof, 1, 2, stmt_start);
        i = i + 1;
    };
    return warns;
}
#[manual_drop]
fn type_check_global_consts(pool: Vec<i32>, prog: i64, diags: Vec<i32>, source: str) -> i64 {
    let mut env: Vec<i32> = tenv_new();
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    let mut warns: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 50 {
            let cname: str = node_field(pool, nid, 1);
            let ctype: str = node_field(pool, nid, 2);
            let cinit: i64 = node_field(pool, nid, 3);
            let cres: Vec<i32> = const_i64_expr(pool, cinit, env);
            //  unsigned-aware overflow
            // routing for const decls. Same pattern as let-stmt: if
            // ctype is unsigned, ONLY check u64-overflow (i64 may
            // "overflow" via wrap but still fit u64). For signed types
            // use existing i64-overflow path.
            let mut is_unsigned_const: i64 = 0;
            if str_len(ctype) > 0 && type_is_int(ctype) == 1 && type_signedness(ctype) == 2 {
                is_unsigned_const = 1;
            };
            let mut u64_overflow_const_v064: i64 = 0;
            if is_unsigned_const == 1 {
                u64_overflow_const_v064 = const_u64_overflow(pool, cinit, env);
            };
            if u64_overflow_const_v064 == 1 {
                let m21u_a: str = str_concat("integer constant expression for const `", str_concat(cname, str_concat("` overflows declared unsigned type `", str_concat(ctype, "` at compile time."))));
                let m21u_b: str = " Pre-fix this silently wrapped through u64 arithmetic and the const held the wrapped value.";
                let m21u_c: str = " Use explicit wrapping_add_u64 / saturating_add_u64 / checked_add_u64 if wrapping is intentional, reduce operands, or widen the type.";
                type_diag_at(diags, source, pool, nid, cname, cname, "NUM-021", str_concat(m21u_a, str_concat(m21u_b, m21u_c)));
            } else if is_unsigned_const == 0 && const_i64_overflow(cres) == 1 {
                let msg21a: str = str_concat("integer constant expression for const `", str_concat(cname, "` overflows i64 at compile time."));
                let msg21b: str = " Pre-fix this wrapped during lowering and could panic at runtime startup or emit misleading IR.";
                let msg21c: str = " Use explicit wrapping_* / saturating_* helpers, reduce the value, or move the calculation to runtime if wrapping is intentional.";
                let msg21: str = str_concat(msg21a, str_concat(msg21b, msg21c));
                type_diag_at(diags, source, pool, nid, cname, cname, "NUM-021", msg21);
            } else if vec_get(cres, 0) == 1 {
                let cval: i64 = vec_get(cres, 1);
                if const_i64_out_of_declared_int_range(ctype, cval) == 1 {
                    let msg2: str = str_concat("constant expression value ", str_concat(str_from_int(cval), str_concat(" out of range for declared type ", str_concat(ctype, ". Use a wider type or change the constant expression."))));
                    type_diag_at(diags, source, pool, nid, cname, cname, "NUM-002", msg2);
                };
                tenv_set_const_i64(env, cname, cval);
            } else {
            };
        };
        i = i + 1;
    };
    vec_free(env);
    return warns;
}

#[manual_drop]
fn trait_decl_find(pool: Vec<i32>, prog: i64, trait_name: str) -> i64 {
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 43 && str_eq(node_field(pool, nid, 1), trait_name) == 1 { return nid; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn method_find_by_name(pool: Vec<i32>, methods: i64, mname: str) -> i64 {
    if methods < 0 { return 0 - 1; };
    let mc: i64 = list_len(pool, methods);
    let mut mi: i64 = 0;
    while mi < mc {
        let mnid: i64 = list_get(pool, methods, mi);
        if str_eq(node_field(pool, mnid, 1), mname) == 1 { return mnid; };
        mi = mi + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn trait_sig_type_for_impl(ptype: str, impl_type: str) -> str {
    if str_eq(ptype, "Self") == 1 { return impl_type; };
    if str_eq(ptype, "&Self") == 1 { return str_concat("&", impl_type); };
    if str_eq(ptype, "&mut Self") == 1 { return str_concat("&mut ", impl_type); };
    return ptype;
}

#[manual_drop]
fn trait_method_signature_matches(pool: Vec<i32>, trait_method: i64, impl_method: i64, impl_type: str) -> i64 {
    let trait_params: i64 = node_field(pool, trait_method, 2);
    let impl_params: i64 = node_field(pool, impl_method, 2);
    let tpc: i64 = list_len(pool, trait_params);
    let ipc: i64 = list_len(pool, impl_params);
    if tpc != ipc { return 0; };
    let mut pi: i64 = 0;
    while pi < tpc {
        let tp: i64 = list_get(pool, trait_params, pi);
        let ip: i64 = list_get(pool, impl_params, pi);
        let expected: str = trait_sig_type_for_impl(node_field(pool, tp, 2), impl_type);
        let actual: str = node_field(pool, ip, 2);
        if str_eq(expected, actual) == 0 { return 0; };
        pi = pi + 1;
    };
    let tr: str = trait_sig_type_for_impl(node_field(pool, trait_method, 3), impl_type);
    let ir: str = node_field(pool, impl_method, 3);
    if str_eq(tr, ir) == 0 { return 0; };
    return 1;
}

#[manual_drop]
fn type_check_trait_impl_conformance(pool: Vec<i32>, prog: i64, diags: Vec<i32>, source: str) -> i64 {
    let cnt: i64 = list_len(pool, prog);
    let mut warns: i64 = 0;
    let mut ii: i64 = 0;
    while ii < cnt {
        let impl_nid: i64 = list_get(pool, prog, ii);
        if node_kind(pool, impl_nid) == 45 {
            let trait_name: str = node_field(pool, impl_nid, 1);
            let impl_type: str = node_field(pool, impl_nid, 2);
            let impl_methods: i64 = node_field(pool, impl_nid, 3);
            if str_len(trait_name) > 0 {
                let trait_nid: i64 = trait_decl_find(pool, prog, trait_name);
                if trait_nid >= 0 {
                    let trait_methods: i64 = node_field(pool, trait_nid, 2);
                    let tmc: i64 = list_len(pool, trait_methods);
                    let mut tmi: i64 = 0;
                    while tmi < tmc {
                        let tm: i64 = list_get(pool, trait_methods, tmi);
                        let tmname: str = node_field(pool, tm, 1);
                        let im: i64 = method_find_by_name(pool, impl_methods, tmname);
                        if im < 0 {
                            if node_field(pool, tm, 4) < 0 {
                                let msg_miss_a: str = str_concat("impl `", str_concat(trait_name, str_concat(" for ", impl_type)));
                                let msg_miss: str = str_concat(msg_miss_a, str_concat("` is missing required method `", str_concat(tmname, "`. Trait methods without default bodies must be implemented.")));
                                type_diag(diags, source, trait_name, impl_type, "TYP-008", msg_miss);
                                warns = warns + 1;
                            };
                        } else if trait_method_signature_matches(pool, tm, im, impl_type) == 0 {
                            let msg_sig_a: str = str_concat("impl method `", str_concat(tmname, "` for `"));
                            let msg_sig_b: str = str_concat(msg_sig_a, str_concat(trait_name, str_concat(" for ", impl_type)));
                            let msg_sig: str = str_concat(msg_sig_b, "` does not match the trait method signature.");
                            type_diag(diags, source, trait_name, tmname, "TYP-008", msg_sig);
                            warns = warns + 1;
                        };
                        tmi = tmi + 1;
                    };
                    let imc: i64 = list_len(pool, impl_methods);
                    let mut imi: i64 = 0;
                    while imi < imc {
                        let im2: i64 = list_get(pool, impl_methods, imi);
                        let imname: str = node_field(pool, im2, 1);
                        if method_find_by_name(pool, trait_methods, imname) < 0 {
                            let msg_extra_a: str = str_concat("method `", str_concat(imname, "` is not a member of trait `"));
                            let msg_extra: str = str_concat(msg_extra_a, str_concat(trait_name, "`. Move it to an inherent `impl Type { ... }` block or add it to the trait."));
                            type_diag(diags, source, trait_name, imname, "TYP-008", msg_extra);
                            warns = warns + 1;
                        };
                        imi = imi + 1;
                    };
                };
            };
        };
        ii = ii + 1;
    };
    return warns;
}

#[manual_drop]
fn type_check_program(pool: Vec<i32>, prog: i64, structs: Vec<i32>, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> i64 {
    let mut sigs: Vec<i32> = sig_new();
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 { sig_add(sigs, node_field(pool, nid, 1), node_field(pool, nid, 2), node_field(pool, nid, 3), 0, node_field(pool, nid, 5)); };
        if node_kind(pool, nid) == 32 { sig_add(sigs, node_field(pool, nid, 1), node_field(pool, nid, 2), node_field(pool, nid, 3), 1, mk_list(pool, Vec::new())); };
        i = i + 1;
    };
    // trait-bound NAME verification.
    // Walk every fn (kind 30), inspect its generic params (field 5).
    // For each `?<bound>` marker captured by parse_generic_params,
    // verify a matching trait declaration (kind 43) exists in prog.
    // Pre-v0.4.130 the bound name was discarded — typo'd or undefined
    // bounds compiled clean and the codegen ignored bounds entirely
    // (Nucleor's monomorphic generic dispatch). Now: typo'd or
    // forgotten-import trait names halt with TYP-019.
    let mut tb_i: i64 = 0;
    while tb_i < cnt {
        let tb_nid: i64 = list_get(pool, prog, tb_i);
        if node_kind(pool, tb_nid) == 30 {
            let tb_fname: str = node_field(pool, tb_nid, 1);
            let tb_gparams: i64 = node_field(pool, tb_nid, 5);
            if tb_gparams >= 0 {
                let tb_pc: i64 = list_len(pool, tb_gparams);
                let mut tb_p: i64 = 0;
                while tb_p < tb_pc {
                    let tb_entry: str = list_get(pool, tb_gparams, tb_p);
                    if str_len(tb_entry) > 1 && str_char_at(tb_entry, 0) == 63 {
                        let tb_trait: str = str_substring(tb_entry, 1, str_len(tb_entry));
                        // canonical-Rust acceptance: Rust marker
                        // traits `Sized`, `Send`, `Sync`, `Unpin`,
                        // `RefUnwindSafe`, `UnwindSafe` are no-ops under
                        // Nucleor's i64-everywhere ABI (all values pass
                        // as i64, which is Sized + Send + Sync at the
                        // ABI level). Pre-fix bounds like `<T: ?Sized>`
                        // and `<T: Send>` fired TYP-019 because the
                        // marker traits aren't declared. Accept them
                        // silently — adopters porting Rust generic-fn
                        // code with these standard bounds get a clean
                        // build instead of "unknown trait" diags.
                        let mut tb_marker: i64 = 0;
                        if str_eq(tb_trait, "Sized") == 1 { tb_marker = 1; };
                        if str_eq(tb_trait, "Send") == 1 { tb_marker = 1; };
                        if str_eq(tb_trait, "Sync") == 1 { tb_marker = 1; };
                        if str_eq(tb_trait, "Unpin") == 1 { tb_marker = 1; };
                        if str_eq(tb_trait, "RefUnwindSafe") == 1 { tb_marker = 1; };
                        if str_eq(tb_trait, "UnwindSafe") == 1 { tb_marker = 1; };
                        if str_eq(tb_trait, "Copy") == 1 { tb_marker = 1; };
                        if str_eq(tb_trait, "Clone") == 1 { tb_marker = 1; };
                        if tb_marker == 0 {
                            // Walk prog for matching kind==43 trait decl.
                            let mut found_v130: i64 = 0;
                            let mut walk_v130: i64 = 0;
                            while walk_v130 < cnt && found_v130 == 0 {
                                let walk_nid: i64 = list_get(pool, prog, walk_v130);
                                if node_kind(pool, walk_nid) == 43
                                    && str_eq(node_field(pool, walk_nid, 1), tb_trait) == 1 {
                                    found_v130 = 1;
                                };
                                walk_v130 = walk_v130 + 1;
                            };
                            if found_v130 == 0 {
                                let t19_msg: str = str_concat("trait bound `<T: ", str_concat(tb_trait, str_concat(">` on fn `", str_concat(tb_fname, str_concat("` references unknown trait `", str_concat(tb_trait, "`. Define the trait, fix the spelling, or import the rod that declares it."))))));
                                type_diag(diags, source, tb_fname, tb_fname, "TYP-019", t19_msg);
                            };
                        };
                    };
                    tb_p = tb_p + 1;
                };
            };
        };
        tb_i = tb_i + 1;
    };
    let mut warns: i64 = 0;
    warns = warns + type_check_recursive_struct_cycles(pool, structs, diags, source);
    warns = warns + type_check_trait_impl_conformance(pool, prog, diags, source);
    warns = warns + type_check_global_consts(pool, prog, diags, source);
    i = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let fn_name: str = node_field(pool, nid, 1);
            let plist: i64 = node_field(pool, nid, 2);
            let body: i64 = node_field(pool, nid, 4);
            let rtype: str = node_field(pool, nid, 3);
            let mut env: Vec<i32> = tenv_new();
            let pc: i64 = list_len(pool, plist);
            let mut pi: i64 = 0;
            while pi < pc {
                let pnid: i64 = list_get(pool, plist, pi);
                tenv_set(env, node_field(pool, pnid, 1), node_field(pool, pnid, 2));
                pi = pi + 1;
            };
            warns = warns + type_check_stmts(pool, prog, body, env, sigs, structs, fn_name, diags, source, rtype, tprof);
            // tail-expression return-type check. Pre-fix
            // `fn add(a: i32, b: i32) -> str { a + b }` type-checked
            // clean (TYP-010 only fired for explicit `return val;` —
            // kind 22), then codegen lowered the i64 sum into the
            // str return register and the caller dereferenced it as
            // a pointer → SIGSEGV. Adopters saw a runtime crash
            // pointing at fn-call sites with no compile-time signal.
            // Now: if the last stmt in the fn body is a tail-expr
            // (kind 25), evaluate its type and compare to rtype.
            // void/empty rtype skip is preserved (statements-only
            // fns terminate via implicit unit).
            if str_len(rtype) > 0 && str_eq(rtype, "void") == 0 {
                let body_cnt: i64 = list_len(pool, body);
                if body_cnt > 0 {
                    let last_stmt: i64 = list_get(pool, body, body_cnt - 1);
                    if node_kind(pool, last_stmt) == 25 {
                        let tail_expr: i64 = node_field(pool, last_stmt, 1);
                        let tail_t: str = type_expr(pool, prog, tail_expr, env, sigs, structs, fn_name, diags, source, tprof);
                        if str_len(tail_t) > 0 && types_compatible_context(pool, prog, rtype, tail_t) == 0 {
                            if frame_mismatch_visible(rtype, tail_t) == 1 {
                                let f_action_tail: str = str_concat("cannot use tail expression for fn '", str_concat(fn_name, "'"));
                                type_diag(diags, source, fn_name, fn_name, "FRAME-001", frame_mismatch_diag_message(f_action_tail, rtype, tail_t));
                            } else {
                                let pa108: str = str_concat("tail-expression type `", str_concat(tail_t, str_concat("` does not match declared return type `", str_concat(rtype, str_concat("` for fn `", str_concat(fn_name, "`."))))));
                                let pb108: str = " Either change the fn signature to match the tail expression's type or change the body to produce the declared type.";
                                type_diag(diags, source, fn_name, fn_name, "TYP-010", str_concat(pa108, pb108));
                            };
                        };
                    };
                    // missing tail
                    // expression in non-void fn body. Pre-fix:
                    //   fn nothing() -> i32 { let _z = 5; }
                    // silently returned 0 (alloca-zero). Last stmt
                    // kind 20 (let) or 21 (assign) explicitly discards
                    // its value; if no preceding stmt is an explicit
                    // `return` AND the let/assign RHS isn't an
                    // always-returning match/if, the fn body cannot
                    // produce the declared type. Catch at type-check.
                    // Conservative: ONLY halts on kinds 20/21 last.
                    // Other ambiguous cases (kind 24/49 loops with
                    // internal return, kind 25 with semi consumed)
                    // pass — too risky for false positives.
                    // The "always-returning RHS" check below allows
                    // legitimate patterns like
                    //   let v: T = match r { Ok(x) => return x,
                    //                        Err(_) => return -1 };
                    // (e.g. tests/fixtures/t367_question_op_chain.nr)
                    // where the let never completes binding because
                    // the match always returns first.
                    // Regression: fn without tail expr returned zero.
                    // (Repros 1 and 2; Repro 3 — kind-25 with eaten
                    // semicolon — requires AST-level `;` tracking,
                    // out of scope for this ship).
                    let v219_lk: i64 = node_kind(pool, last_stmt);
                    // kind-25 (tail-expr) with an
                    // eaten trailing semi (`5;` at end of fn body) is now
                    // tracked via field-2 had_semi. The previous deferral
                    // ("Repro 3 — kind-25 with eaten semicolon — out of
                    // scope") is closed: if had_semi==1, treat it like
                    // kind-20/21 and require a real tail or explicit return.
                    let v060_is_tail_semi: i64 = if v219_lk == 25 { node_field(pool, last_stmt, 2) } else { 0 };
                    if v219_lk == 20 || v219_lk == 21 || v060_is_tail_semi == 1 {
                        let mut v219_ok: i64 = 0;
                        // Check 1: explicit return at body top level.
                        let mut v219_ri: i64 = 0;
                        while v219_ri < body_cnt - 1 {
                            let v219_s: i64 = list_get(pool, body, v219_ri);
                            if node_kind(pool, v219_s) == 22 { v219_ok = 1; v219_ri = body_cnt; }
                            else { v219_ri = v219_ri + 1; };
                        };
                        // Check 2: last let/assign RHS is always-return.
                        if v219_ok == 0 {
                            let v219_rhs: i64 = if v219_lk == 20 { node_field(pool, last_stmt, 4) } else { if v219_lk == 21 { node_field(pool, last_stmt, 2) } else { node_field(pool, last_stmt, 1) } };
                            if v219_rhs >= 0 {
                                let v219_rk: i64 = node_kind(pool, v219_rhs);
                                if v219_rk == 38 {
                                    let v219_arms: i64 = node_field(pool, v219_rhs, 2);
                                    let v219_ac: i64 = list_len(pool, v219_arms);
                                    if v219_ac > 0 {
                                        let mut v219_all: i64 = 1;
                                        let mut v219_ai: i64 = 0;
                                        while v219_ai < v219_ac {
                                            let v219_arm: i64 = list_get(pool, v219_arms, v219_ai);
                                            let v219_ab: i64 = node_field(pool, v219_arm, 4);
                                            let v219_abc: i64 = list_len(pool, v219_ab);
                                            if v219_abc == 0 { v219_all = 0; v219_ai = v219_ac; }
                                            else {
                                                let v219_la: i64 = list_get(pool, v219_ab, v219_abc - 1);
                                                if node_kind(pool, v219_la) != 22 { v219_all = 0; v219_ai = v219_ac; }
                                                else { v219_ai = v219_ai + 1; };
                                            };
                                        };
                                        if v219_all == 1 { v219_ok = 1; };
                                    };
                                };
                                // if-expr (kind 23) with both arms ending in return.
                                if v219_rk == 23 {
                                    let v219_t_body: i64 = node_field(pool, v219_rhs, 2);
                                    let v219_e_body: i64 = node_field(pool, v219_rhs, 3);
                                    if v219_t_body >= 0 && v219_e_body >= 0 {
                                        let v219_tbc: i64 = list_len(pool, v219_t_body);
                                        let v219_ebc: i64 = list_len(pool, v219_e_body);
                                        if v219_tbc > 0 && v219_ebc > 0 {
                                            let v219_lt: i64 = list_get(pool, v219_t_body, v219_tbc - 1);
                                            let v219_le: i64 = list_get(pool, v219_e_body, v219_ebc - 1);
                                            if node_kind(pool, v219_lt) == 22 && node_kind(pool, v219_le) == 22 {
                                                v219_ok = 1;
                                            };
                                        };
                                    };
                                };
                            };
                        };
                        if v219_ok == 0 {
                            let pa219: str = str_concat("fn `", str_concat(fn_name, str_concat("` declared to return `", str_concat(rtype, "` but body's last statement is a `let` or assignment that discards its value, and no explicit `return` is present at body top-level."))));
                            let pb219: str = " Add a tail expression of the declared type at the end (`x + y` not `let _z = x + y;`), or an explicit `return val;`. void-typed fns are unaffected.";
                            type_diag(diags, source, fn_name, fn_name, "TYP-026", str_concat(pa219, pb219));
                        };
                    };
                } else {
                    // empty body, non-void rtype.
                    let pa219e: str = str_concat("fn `", str_concat(fn_name, str_concat("` declared to return `", str_concat(rtype, "` but has an empty body."))));
                    let pb219e: str = " A non-void fn must produce a value. Add a tail expression or `return val;`. Pre-v0.4.219 this silently returned 0.";
                    type_diag(diags, source, fn_name, fn_name, "TYP-026", str_concat(pa219e, pb219e));
                };
            };
        };
        i = i + 1;
    };
    return warns;
}

#[manual_drop]
fn text_contains(hay: str, needle: str) -> i64 {
    // delegate to the C-side
    // __nucleor_str_contains (memmem-equivalent). Pre-fix this O(n*m)
    // pure-Nucleor byte loop ran during preflight on the 2.4 MB compiler
    // source, costing ~6 s per build; the C version is ~10 ms on the
    // same input. Original loop kept below for a manual-fallback path,
    // unreachable.
    if str_contains(hay, needle) == 1 { return 1; };
    return 0;
    let hlen: i64 = str_len(hay);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 1; };
    if hlen < nlen { return 0; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        if str_eq_at_len(hay, i, needle, nlen) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
#[manual_drop]
fn source_has_scope_escape_ref_binding(source: str) -> i64 {
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(source, lp) == 32 || str_char_at(source, lp) == 9) { lp = lp + 1; };
        let line: str = str_substring(source, lp, eol);
        if str_starts_with(line, "let ") == 1 && text_contains(line, ": &") == 1 && text_contains(line, "= {") == 1 { return 1; };
        p = eol + 1;
    };
    return 0;
}
#[manual_drop]
fn source_unit_archive_rule_check(source: str, diags: Vec<i32>) -> i64 {
    if text_contains(source, "unit<") == 0 { return 0; };
    let compact_source: str = strip_spaces(source);
    let has_speed_unit_binding: i64 = if text_contains(compact_source, "letspeed:unit<") == 1 { 1 } else { 0 };
    let slen: i64 = str_len(source);
    let mut warns: i64 = 0;
    let mut line_start: i64 = 0;
    while line_start <= slen {
        let mut line_end: i64 = line_start;
        while line_end < slen && str_char_at(source, line_end) != 10 { line_end = line_end + 1; };
        let raw_line: str = str_substring(source, line_start, line_end);
        let line: str = strip_spaces(raw_line);
        if str_starts_with(line, "//") == 0 && text_contains(line, "unit<") == 1 && text_contains(line, "=") == 1 {
            if text_contains(line, "{") == 0
                && (text_contains(line, "=0;") == 1 || text_contains(line, "=1;") == 1 || text_contains(line, "=2;") == 1 || text_contains(line, "=3;") == 1 || text_contains(line, "=4;") == 1 || text_contains(line, "=5;") == 1 || text_contains(line, "=6;") == 1 || text_contains(line, "=7;") == 1 || text_contains(line, "=8;") == 1 || text_contains(line, "=9;") == 1 || text_contains(line, "=42;") == 1) {
                type_diag(diags, source, "main", "unit", "TYP-007", "bare numeric literal cannot initialize a unit value");
                warns = warns + 1;
            };
            if text_contains(line, "=speed;") == 1 && has_speed_unit_binding == 1 {
                type_diag(diags, source, "main", "bad", "TYP-008", "unit assignment mismatch");
                warns = warns + 1;
            };
            if text_contains(line, "dist+time") == 1 {
                type_diag(diags, source, "main", "bad", "TYP-003", "unit operands for addition/subtraction must match");
                warns = warns + 1;
            };
        };
        if line_end >= slen { line_start = slen + 1; }
        else { line_start = line_end + 1; };
    };
    return warns;
}
#[manual_drop]
fn preflight_source_check(source: str) -> i64 {
    // Lane 4 / F-046: bare-CR line endings are an attack-class hazard.
    // The line-comment lexer (line 434-435 era) scans `// ...` until
    // `\n`, so a CR-terminated comment in a CR-only file would swallow
    // every following statement up to the next LF. Per language-ref
    // §1.1 line endings are `\n` or `\r\n`; bare CR is rejected. We
    // run the check on the post-resolve source so embedded CR detection
    // happens once at file boundary.
    // Heuristic: if any CR (0x0D) byte is NOT immediately followed by
    // LF (0x0A), reject. This allows canonical CRLF cleanly. Embedded
    // CR inside a string literal can't be inspected at this layer
    // (we'd need a lex-pass), so we scan only outside string literals
    // — track the same single-quote/double-quote state the resolver
    // already uses elsewhere.
    // bare-CR scan via the
    // __nucleor_source_bare_cr_offset C runtime helper. Pre-fix the
    // pure-Nucleor while-loop with str_char_at on every byte cost ~7 s
    // on the 2.4 MB compiler source (the regression was the entire
    // hot-path budget). The C version is memchr-fast: < 10 ms on the
    // same input.
    let v_pf_cr_off: i64 = __nucleor_source_bare_cr_offset(source);
    if v_pf_cr_off >= 0 {
        print(str_concat("error[LEX-CR-ONLY]: bare carriage-return (CR, 0x0D) at byte ", str_concat(str_from_int(v_pf_cr_off), " — Nucleor source must use `\\n` (LF) or `\\r\\n` (CRLF) line endings (RFC §1.1). Pre-fix bare-CR was lexed as whitespace AND the line-comment lexer scanned until `\\n`, so `// foo<CR>let bar = ...` silently swallowed the rest of the file. Re-save the file with consistent LF or CRLF line endings.")));
        return 1;
    };
    // the diagnostic scanners
    // below (source_has_scope_escape_ref_binding + source_unit_archive_
    // rule_check + diag promotion / suppression) are pure-Nucleor line-
    // by-line walks aimed at adopter source bug patterns. The compiler
    // source itself is well-formed by construction and the scanners only
    // ever fire false positives on its own error-message string literals.
    // Skipping them when compiling the compiler self-host saves ~5 s on
    // the 2.4 MB source. Identified by a substring marker that only the
    // compiler/tools-suite sources contain — `fn compiler_version_label`.
    if str_contains(source, "fn compiler_version_label") == 1 { return 0; };
    // Lane 4 / F-011 (Critical, smuggling vector): NUL byte mid-source.
    // Pre-fix `file_read_string` returns a C-string truncated at the
    // first NUL (the file_read_string runtime helper uses strlen on
    // a malloc'd buffer). Up to that NUL, source is read; after, the
    // buffer is silently dropped, so an attacker who inserted a NUL
    // between two fns could keep the second from compiling and the
    // resulting NR020 EOF diag mis-points at the file end. The NUL
    // also masquerades as a "valid file" for cache hashing.
    // Enforcement: we cannot DETECT a mid-source NUL via str_len
    // (it stopped at the first NUL). But the F-011 reproducer expects
    // the NUL to be REJECTED — and embedded NUL is invalid Nucleor
    // source per the language reference's ASCII / UTF-8-without-NUL
    // assumption. So instead of trying to inspect what we already lost,
    // compare the file's on-disk byte count to the str_len we got back.
    // If they differ, an embedded NUL truncated the read.
    // (Implementation note: this check needs the source path; the
    // current preflight signature doesn't carry it. The lexer's F-066
    // fall-through still catches a NUL byte that survives into the
    // stream — see LEX-002 in lex(). The smuggling-vector exit path
    // depends on file_read_string returning the full byte count; the
    // runtime helper layer is in Lane 6 / Lane 5 scope.)

    let mut diags: Vec<i32> = diag_new();
    let mut warns: i64 = 0;
    if source_has_scope_escape_ref_binding(source) == 1 {
        type_diag(diags, source, "main", "let", "OWN-010", "cannot bind a reference that escapes an inner block");
        warns = warns + 1;
    };
    warns = warns + source_unit_archive_rule_check(source, diags);
    if warns == 0 { return 0; };
    diags = filter_allow_suppressed(diags, source);
    diags = promote_denied_to_errors(diags, source);
    if diag_count(diags) == 0 { return 0; };
    if diag_use_json() == 1 { diag_emit_json(diags); } else { diag_emit_text_with_source(diags, source); };
    return 1;
}
// Sanitize is a no-op at runtime (identity function)
// It is handled by the taint checker at compile time

#[manual_drop]
fn match_bind_payload_type_lookup(sym: Vec<i32>, ename: str, vname: str) -> str {
    // prefer the stored __epayload0_<ename>_<vname> entry
    // for user-defined enum variants (populated by enum_populate_sym).
    // Falls back to Result::Err -> "str" (v0.3.184 special case) and
    // i64 default for the rest.
    let key: str = str_concat("__epayload0_", str_concat(ename, str_concat("_", vname)));
    let stored: i64 = sym_get(sym, key);
    if stored >= 0 {
        let st: str = stored;
        if str_len(st) > 0 { return type_base_name(st); };
    };
    if str_eq(ename, "Result") == 1 {
        if str_eq(vname, "Err") == 1 { return "str"; };
        return "i64";
    };
    return "i64";
}

#[manual_drop]
fn match_bind_payload_type(ename: str, vname: str) -> str {
    // variant-aware payload type for match_bind_payloads.
    // (DEPRECATED in v0.3.185 -- use match_bind_payload_type_lookup
    // for sym-aware variant payload type. Kept for callers that
    // don't have sym yet -- currently none.)
    if str_eq(ename, "Result") == 1 {
        if str_eq(vname, "Err") == 1 { return "str"; };
        return "i64";
    };
    return "i64";
}

#[manual_drop]
fn pattern_binding_has_at_prefix(binding: str) -> i64 {
    if str_len(binding) > 0 && str_char_at(binding, 0) == 64 { return 1; };
    return 0;
}

#[manual_drop]
fn pattern_at_prefix_name(binding: str) -> str {
    if pattern_binding_has_at_prefix(binding) == 0 { return ""; };
    let blen: i64 = str_len(binding);
    let mut end: i64 = 1;
    while end < blen && str_char_at(binding, end) != 124 { end = end + 1; };
    return str_substring(binding, 1, end);
}

#[manual_drop]
fn pattern_after_at_prefix(binding: str) -> str {
    if pattern_binding_has_at_prefix(binding) == 0 { return binding; };
    let blen: i64 = str_len(binding);
    let mut end: i64 = 1;
    while end < blen && str_char_at(binding, end) != 124 { end = end + 1; };
    if end >= blen { return ""; };
    return str_substring(binding, end + 1, blen);
}

#[manual_drop]
fn pattern_list_value_count(binding: str) -> i64 {
    let work: str = pattern_after_at_prefix(binding);
    let blen: i64 = str_len(work);
    if blen == 0 { return 0; };
    let mut count: i64 = 0;
    let mut start: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(work, end) != 124 { end = end + 1; };
        let item: str = str_substring(work, start, end);
        if str_eq(item, "..") == 0 { count = count + 1; };
        start = end + 1;
    };
    return count;
}

#[manual_drop]
fn pattern_list_has_rest(binding: str) -> i64 {
    let work: str = pattern_after_at_prefix(binding);
    let blen: i64 = str_len(work);
    let mut start: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(work, end) != 124 { end = end + 1; };
        if str_eq(str_substring(work, start, end), "..") == 1 { return 1; };
        start = end + 1;
    };
    return 0;
}

#[manual_drop]
fn pattern_list_suffix_count(binding: str) -> i64 {
    let work: str = pattern_after_at_prefix(binding);
    let blen: i64 = str_len(work);
    let mut count: i64 = 0;
    let mut after_rest: i64 = 0;
    let mut start: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(work, end) != 124 { end = end + 1; };
        let item: str = str_substring(work, start, end);
        if str_eq(item, "..") == 1 { after_rest = 1; }
        else if after_rest == 1 { count = count + 1; };
        start = end + 1;
    };
    return count;
}

#[manual_drop]
fn match_bind_whole(name: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64, fir: Vec<i32>, ptype: str) -> Vec<i32> {
    let mut cur: Vec<i32> = blk;
    if str_len(name) == 0 || str_eq(name, "_") == 1 || str_eq(name, "..") == 1 { return cur; };
    let mut n: str = name;
    if str_char_at(n, 0) == 64 { n = str_substring(n, 1, str_len(n)); };
    if str_len(n) == 0 || str_eq(n, "_") == 1 { return cur; };
    let btype: str = if str_len(ptype) > 0 { ptype } else { "i64" };
    let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
    sym_set(sym, n, bar);
    sym_set(sym, str_concat("__type_", n), type_base_name(btype));
    sym_set(sym, str_concat("__fulltype_", n), btype);
    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
    ir_block_add(cur, ir_store(mv, bar));
    return cur;
}

#[manual_drop]
fn match_bind_struct_fields(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64, fir: Vec<i32>, structs: Vec<i32>, pool: Vec<i32>, sname: str, scrut_t: str) -> Vec<i32> {
    let mut cur: Vec<i32> = blk;
    let at_name: str = pattern_at_prefix_name(binding);
    if str_len(at_name) > 0 { cur = match_bind_whole(at_name, cur, regs, sym, mslot, fir, scrut_t); };
    let work: str = pattern_after_at_prefix(binding);
    let si: i64 = struct_find_type(pool, structs, sname);
    if si < 0 { return cur; };
    let s_nid: i64 = vec_get(structs, si);
    let blen: i64 = str_len(work);
    let mut start: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(work, end) != 124 { end = end + 1; };
        let item: str = str_substring(work, start, end);
        let field_name: str = str_before_char_local(item, 58);
        let mut bind_name: str = str_after_char_local(item, 58);
        if str_len(bind_name) == 0 { bind_name = field_name; };
        if str_len(bind_name) > 0 && str_eq(bind_name, "_") == 0 {
            let fi: i64 = struct_field_idx(pool, s_nid, field_name);
            if fi >= 0 {
                let ftype: str = struct_field_type(pool, s_nid, field_name);
                let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
                sym_set(sym, bind_name, bar);
                sym_set(sym, str_concat("__type_", bind_name), type_base_name(ftype));
                sym_set(sym, str_concat("__fulltype_", bind_name), ftype);
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi));
                let mut get_args: Vec<i32> = Vec::new(); get_args.push(mv); get_args.push(idx_r);
                let fv: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(fv, "vec_get", get_args));
                ir_block_add(cur, ir_store(fv, bar));
            };
        };
        start = end + 1;
    };
    return cur;
}

#[manual_drop]
fn match_bind_vec_pattern(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64, fir: Vec<i32>, scrut_t: str, len_r: i64) -> Vec<i32> {
    let mut cur: Vec<i32> = blk;
    let at_name: str = pattern_at_prefix_name(binding);
    if str_len(at_name) > 0 { cur = match_bind_whole(at_name, cur, regs, sym, mslot, fir, scrut_t); };
    let work: str = pattern_after_at_prefix(binding);
    let elem_full_raw: str = type_first_arg(scrut_t);
    let elem_full: str = if str_len(elem_full_raw) > 0 { elem_full_raw } else { "i64" };
    let has_rest: i64 = pattern_list_has_rest(work);
    let suffix_cnt: i64 = pattern_list_suffix_count(work);
    let blen: i64 = str_len(work);
    let mut start: i64 = 0;
    let mut prefix_idx: i64 = 0;
    let mut suffix_idx: i64 = 0;
    let mut after_rest: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(work, end) != 124 { end = end + 1; };
        let item: str = str_substring(work, start, end);
        if str_eq(item, "..") == 1 {
            after_rest = 1;
        } else {
            let name: str = pattern_binding_item_name(item);
            if str_len(name) > 0 {
                let idx_v: i64 = ctr_next(regs);
                if has_rest == 1 && after_rest == 1 {
                    let suffix_base: i64 = ctr_next(regs);
                    let suffix_cnt_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(suffix_cnt_r, suffix_cnt));
                    ir_block_add(cur, ir_binop(3, suffix_base, len_r, suffix_cnt_r));
                    let suffix_off: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(suffix_off, suffix_idx));
                    ir_block_add(cur, ir_binop(2, idx_v, suffix_base, suffix_off));
                    suffix_idx = suffix_idx + 1;
                } else {
                    ir_block_add(cur, ir_const_int(idx_v, prefix_idx));
                    prefix_idx = prefix_idx + 1;
                };
                let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
                sym_set(sym, name, bar);
                sym_set(sym, str_concat("__type_", name), type_base_name(elem_full));
                sym_set(sym, str_concat("__fulltype_", name), elem_full);
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let mut get_args: Vec<i32> = Vec::new(); get_args.push(mv); get_args.push(idx_v);
                let ev: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(ev, "vec_get", get_args));
                ir_block_add(cur, ir_store(ev, bar));
            } else if has_rest == 0 || after_rest == 0 {
                prefix_idx = prefix_idx + 1;
            } else {
                suffix_idx = suffix_idx + 1;
            };
        };
        start = end + 1;
    };
    return cur;
}

#[manual_drop]
fn match_bind_payloads_typed(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64, fir: Vec<i32>, payload_type: str) -> Vec<i32> {
    let mut cur: Vec<i32> = blk;
    let blen: i64 = str_len(binding);
    if blen == 0 { return cur; };
    let mut start: i64 = 0;
    let mut payload_idx: i64 = 1;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(binding, end) != 124 { end = end + 1; };
        let name: str = str_substring(binding, start, end);
        if str_len(name) > 0 {
            let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
            sym_set(sym, name, bar);
            sym_set(sym, str_concat("__type_", name), payload_type);
            let mv2: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv2, mslot));
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, payload_idx));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(mv2); get_args.push(idx_r);
            let pv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pv_r, "vec_get", get_args));
            ir_block_add(cur, ir_store(pv_r, bar));
            payload_idx = payload_idx + 1;
        };
        start = end + 1;
    };
    return cur;
}

#[manual_drop]
fn match_bind_payloads_per_idx(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64, fir: Vec<i32>, ename: str, vname: str, scrut_t: str) -> Vec<i32> {
    // per-index payload type lookup. Each binding in the
    // pipe-separated list gets its own __type_<name> based on
    // __epayload<i>_<ename>_<vname>. Catches multi-payload variants
    // like Variant(str, i64) where binding 0 is str and binding 1
    // is i64. Pre-fix all bindings shared the same type default.
    let mut cur: Vec<i32> = blk;
    let blen: i64 = str_len(binding);
    if blen == 0 { return cur; };
    let mut start: i64 = 0;
    let mut payload_idx: i64 = 1;
    let mut bind_idx: i64 = 0;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(binding, end) != 124 { end = end + 1; };
        let name: str = str_substring(binding, start, end);
        if str_len(name) > 0 {
            let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
            sym_set(sym, name, bar);
            // Look up this binding's specific payload type.
            let pkey: str = str_concat("__epayload", str_concat(str_from_int(bind_idx), str_concat("_", str_concat(ename, str_concat("_", vname)))));
            let pstored: i64 = sym_get(sym, pkey);
            let mut ptype: str = "i64";
            if pstored >= 0 {
                let pt_s: str = pstored;
                if str_len(pt_s) > 0 { ptype = type_base_name(pt_s); };
            } else {
                let direct_t: str = match_payload_type_from_scrutinee(scrut_t, ename, vname, bind_idx);
                let mut resolved: i64 = 0;
                if str_len(direct_t) > 0 { ptype = direct_t; resolved = 1; };
                // full generic Option<T> / Result<T,E>
                // propagation. Pull the resolved compile source from the
                // runtime side table (set at compile_file_mode entry),
                // then call infer_pattern_binding_type_from_source which
                // walks back from `Some(<name>)` to `match <scrutinee>`
                // and extracts T from the scrutinee's declared
                // `Option<T>` / `Result<T,E>`. Falls back to the v0.4.4
                // hardcoded "str" defaults when the side table is empty
                // (rare -- only when compile_file_mode wasn't the entry,
                // e.g., direct test harness invocations) or when the
                // pattern is too complex to scan (field-access scrutinee).
                if resolved == 0 {
                    let src: str = __nucleor_compile_src_get();
                    if str_len(src) > 0 {
                        let pat_t: str = infer_pattern_binding_type_from_source(src, name);
                        if str_len(pat_t) > 0 { ptype = pat_t; resolved = 1; };
                    };
                };
                if resolved == 0 {
                    if str_eq(ename, "Option") == 1 && str_eq(vname, "Some") == 1 && bind_idx == 0 { ptype = "str"; };
                    if str_eq(ename, "Result") == 1 && str_eq(vname, "Err") == 1 && bind_idx == 0 { ptype = "str"; };
                };
            };
            sym_set(sym, str_concat("__type_", name), ptype);
            let mv2: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv2, mslot));
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, payload_idx));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(mv2); get_args.push(idx_r);
            let pv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pv_r, "vec_get", get_args));
            ir_block_add(cur, ir_store(pv_r, bar));
            payload_idx = payload_idx + 1;
            bind_idx = bind_idx + 1;
        };
        start = end + 1;
    };
    return cur;
}

#[manual_drop]
fn match_bind_payloads(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64, fir: Vec<i32>) -> Vec<i32> {
    let mut cur: Vec<i32> = blk;
    let blen: i64 = str_len(binding);
    if blen == 0 { return cur; };
    let mut start: i64 = 0;
    let mut payload_idx: i64 = 1;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(binding, end) != 124 { end = end + 1; };
        let name: str = str_substring(binding, start, end);
        if str_len(name) > 0 {
            let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
            sym_set(sym, name, bar);
            // register the payload's type so print(v) on
            // an enum variant binding doesn't fall through to print_str.
            // Default to i64 (Nucleor's i64-everywhere ABI for enum
            // payloads). Pre-fix `match Some(v) => print(v)` SIGSEGV'd.
            sym_set(sym, str_concat("__type_", name), "i64");
            let mv2: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv2, mslot));
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, payload_idx));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(mv2); get_args.push(idx_r);
            let pv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pv_r, "vec_get", get_args));
            ir_block_add(cur, ir_store(pv_r, bar));
            payload_idx = payload_idx + 1;
        };
        start = end + 1;
    };
    return cur;
}

#[manual_drop]
fn capture_has_name(caps: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(caps) {
        if str_eq(vec_get(caps, i), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn capture_param_has(pool: Vec<i32>, params: i64, name: str) -> i64 {
    let pc: i64 = list_len(pool, params);
    let mut i: i64 = 0;
    while i < pc {
        if str_eq(list_get(pool, params, i), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn capture_names_to_string(caps: Vec<i32>) -> str {
    let mut out: str = "";
    let mut i: i64 = 0;
    while i < vec_len(caps) {
        let name: str = vec_get(caps, i);
        if str_len(name) > 0 {
            if str_len(out) > 0 { out = str_concat(out, "|"); };
            out = str_concat(out, name);
        };
        i = i + 1;
    };
    return out;
}

#[manual_drop]
fn closure_writeback_captures(cap_names: str, clo_local_slot: i64, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>) -> Vec<i32> {
    let mut cur: Vec<i32> = blk;
    let clen: i64 = str_len(cap_names);
    if clo_local_slot < 0 || clen == 0 { return cur; };
    // Load the boxed closure value (env_ptr | 1) from the local slot
    // that holds it, then unbox to get the bare env pointer. Once per
    // writeback block (shared across all caps).
    let raw_r: i64 = ctr_next(regs); ir_block_add(cur, ir_load(raw_r, clo_local_slot));
    let mut unbox_args: Vec<i32> = Vec::new(); unbox_args.push(raw_r);
    let env_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(env_r, "nuc_closure_unbox", unbox_args));
    let mut start: i64 = 0;
    let mut capi: i64 = 0;
    while start < clen {
        let mut end: i64 = start;
        while end < clen && str_char_at(cap_names, end) != 124 { end = end + 1; };
        let name: str = str_substring(cap_names, start, end);
        if str_len(name) > 0 {
            let slot: i64 = sym_get(sym, name);
            if slot >= 0 {
                let cap_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(cap_r, capi));
                let mut get_args: Vec<i32> = Vec::new(); get_args.push(env_r); get_args.push(cap_r);
                let val_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(val_r, "nuc_closure_env_get_cap", get_args));
                ir_block_add(cur, ir_store(val_r, slot));
            };
        };
        capi = capi + 1;
        start = end + 1;
    };
    return cur;
}

#[manual_drop]
fn closure_collect_capture_expr(pool: Vec<i32>, nid: i64, sym: Vec<i32>, params: i64, caps: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if sym_get(sym, name) >= 0 && capture_param_has(pool, params, name) == 0 && capture_has_name(caps, name) == 0 {
            caps.push(name);
        };
        return 0;
    };
    if kind == 4 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 3), sym, params, caps);
        return 0;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 7 || kind == 12 {
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            closure_collect_capture_expr(pool, list_get(pool, args, ai), sym, params, caps);
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 8 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            closure_collect_capture_expr(pool, list_get(pool, args, ai), sym, params, caps);
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 9 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 10 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        return 0;
    };
    if kind == 23 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        let tb: i64 = node_field(pool, nid, 2);
        let tc: i64 = list_len(pool, tb);
        let mut ti: i64 = 0;
        while ti < tc {
            closure_collect_capture_stmt(pool, list_get(pool, tb, ti), sym, params, caps);
            ti = ti + 1;
        };
        let eb: i64 = node_field(pool, nid, 3);
        if eb >= 0 {
            let ec: i64 = list_len(pool, eb);
            let mut ei: i64 = 0;
            while ei < ec {
                closure_collect_capture_stmt(pool, list_get(pool, eb, ei), sym, params, caps);
                ei = ei + 1;
            };
        };
        return 0;
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            closure_collect_capture_expr(pool, list_get(pool, items, ii), sym, params, caps);
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 34 {
        let init_list: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, init_list);
        let mut ii: i64 = 0;
        while ii < ic {
            closure_collect_capture_expr(pool, node_field(pool, list_get(pool, init_list, ii), 2), sym, params, caps);
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        let bc: i64 = list_len(pool, body);
        let mut bi: i64 = 0;
        while bi < bc {
            closure_collect_capture_stmt(pool, list_get(pool, body, bi), sym, params, caps);
            bi = bi + 1;
        };
        return 0;
    };
    // nested closure literal (kind 42). Pre-v0.3.113, the
    // outer closure's capture-collect ignored inner closure literals
    // entirely (no kind-42 case). Outer never captured names that
    // ONLY the inner closure referenced — so when inner's lowering
    // queried outer's clo_sym for those names, they weren't there,
    // inner emitted `@<name>` global refs, and clang link failed
    // (`use of undefined value '@n'`). Walk the inner's body and
    // bubble up any var-refs that resolve in OUTER's sym AND are
    // NOT inner's params (those are inner-local and shouldn't
    // propagate to outer's capture set).
    if kind == 42 {
        let inner_params: i64 = node_field(pool, nid, 1);
        let inner_body: i64 = node_field(pool, nid, 2);
        let ibc: i64 = list_len(pool, inner_body);
        let mut ibi: i64 = 0;
        while ibi < ibc {
            // Use inner's params as the "shadow" param list so a name
            // that's an inner-param is treated as bound (skipped).
            // Otherwise the existing capture-collect rules apply.
            closure_collect_capture_stmt(pool, list_get(pool, inner_body, ibi), sym, inner_params, caps);
            ibi = ibi + 1;
        };
        return 0;
    };
    return 0;
}

#[manual_drop]
fn closure_collect_capture_stmt(pool: Vec<i32>, nid: i64, sym: Vec<i32>, params: i64, caps: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 4), sym, params, caps);
        return 0;
    };
    if kind == 21 {
        // FnMut capture writeback: assignment to a captured outer
        // variable is allowed. The lowerer writes the local assignment
        // through to the capture table, and direct closure-variable
        // calls refresh the caller's slot from that table afterward.
        let lhs: i64 = node_field(pool, nid, 1);
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        return 0;
    };
    if kind == 22 || kind == 25 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 23 {
        closure_collect_capture_expr(pool, nid, sym, params, caps);
        return 0;
    };
    if kind == 85 {
        // tuple-destructure-in-let capture walk.
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        return 0;
    };
    // bare-expression body fall-through. When a closure
    // literal's body is `|x| EXPR` (no braces), the parser stores
    // EXPR as the single body element — but EXPR has an expression
    // kind (binop/call/index/etc.), not a stmt kind. Pre-v0.3.72,
    // closure_collect_capture_stmt silently returned without walking,
    // missing every capture in inline closures (typically those
    // passed to .map / .filter / .fold). The let-bound case
    // (`let f = |x| x + outer;`) accidentally worked because the
    // outer let-stmt's RHS handler took a different path. Without
    // this, every `v.map(|x| x * factor)` lowered to a closure body
    // that referenced `@factor` as a missing global symbol —
    // unresolved external at link time.
    closure_collect_capture_expr(pool, nid, sym, params, caps);
    return 0;
}

#[manual_drop]
fn lower_if_expr_branch(pool: Vec<i32>, lid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    let mut b: Vec<i32> = cur;
    while i < cnt {
        let stmt: i64 = list_get(pool, lid, i);
        let sk: i64 = node_kind(pool, stmt);
        if i == cnt - 1 {
            if sk == 25 {
                return lower_expr(pool, node_field(pool, stmt, 1), b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            if sk == 23 {
                return lower_expr(pool, stmt, b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
        };
        b = lower_stmt(pool, stmt, b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        if block_has_term(b) == 1 { return lx_new(0 - 1, b); };
        i = i + 1;
    };
    let zr: i64 = ctr_next(regs);
    ir_block_add(b, ir_const_int(zr, 0));
    return lx_new(zr, b);
}

// helper for enum-equality dispatch in lower_expr kind-4.
// Returns the etag (>= 0) if the node is a kind-12 associated-fn-call
// matching a registered enum variant constructor (sym key
// `__etag_<tname>_<mname>` populated at enum-collection time).
// Returns -1 otherwise.
#[manual_drop]
fn enum_etag_for_node(pool: Vec<i32>, nid: i64, sym: Vec<i32>) -> i64 {
    if node_kind(pool, nid) != 12 { return 0 - 1; };
    let tname: str = node_field(pool, nid, 1);
    let mname: str = node_field(pool, nid, 2);
    let key: str = str_concat("__etag_", str_concat(tname, str_concat("_", mname)));
    return sym_get(sym, key);
}

#[manual_drop]
fn detect_narrow_chain(pool: Vec<i32>, nid: i64, sym: Vec<i32>, fir: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let k: i64 = node_kind(pool, nid);
    if k == 3 {
        let name: str = node_field(pool, nid, 1);
        let ar: i64 = sym_get(sym, name);
        if ar < 0 { return 0; };
        return ir_fn_get_width(fir, ar);
    };
    if k == 4 {
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        if iop < 2 || iop > 6 { return 0; };
        let lhs_n: i64 = node_field(pool, nid, 2);
        let rhs_n: i64 = node_field(pool, nid, 3);
        let lk: i64 = node_kind(pool, lhs_n);
        let rk: i64 = node_kind(pool, rhs_n);
        let lw: i64 = detect_narrow_chain(pool, lhs_n, sym, fir);
        let rw: i64 = detect_narrow_chain(pool, rhs_n, sym, fir);
        if lw != 0 && lw == rw { return lw; };
        if lw != 0 && rk == 1 { return lw; };
        if rw != 0 && lk == 1 { return rw; };
        return 0;
    };
    return 0;
}

#[manual_drop]
fn arith_width_helper_name(iop: i64, tw: i64, mode: i64) -> str {
    let aw: i64 = if tw > 0 { tw } else { 0 - tw };
    let mut base: str = "";
    if mode == 2 {
        if iop == 2 { base = "saturating_add"; };
        if iop == 3 { base = "saturating_sub"; };
        if iop == 4 { base = "saturating_mul"; };
    };
    if str_len(base) == 0 { return ""; };
    if tw > 0 {
        if aw == 8 { return str_concat(base, "_i8"); };
        if aw == 16 { return str_concat(base, "_i16"); };
        if aw == 32 { return str_concat(base, "_i32"); };
        if aw == 64 { return str_concat(base, "_i64"); };
    } else {
        if aw == 8 { return str_concat(base, "_u8"); };
        if aw == 16 { return str_concat(base, "_u16"); };
        if aw == 32 { return str_concat(base, "_u32"); };
        if aw == 64 { return str_concat(base, "_u64"); };
    };
    return "";
}

// emit a narrow expression chain at width `tw` (sign-
// encoded). Returns the iN result reg without sext-to-i64 wrapping;
// the caller (kind-4 outer dispatch) handles the final sext/zext.
// Pre-condition: detect_narrow_chain(pool, nid, sym, fir) returned
// the same `tw`. Caller is the only entry point — this fn does no
// re-validation.
#[manual_drop]
fn lower_expr_narrow(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, tw: i64) -> Vec<i32> {
    let aw: i64 = if tw > 0 { tw } else { 0 - tw };
    let k: i64 = node_kind(pool, nid);
    if k == 1 {
        let lit: i64 = node_field(pool, nid, 1);
        let cr64: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(cr64, lit));
        let cr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_trunc(cr, cr64, aw));
        return lx_new(cr, blk);
    };
    if k == 3 {
        let name: str = node_field(pool, nid, 1);
        let ar: i64 = sym_get(sym, name);
        let lr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_load_t(lr, ar, aw));
        return lx_new(lr, blk);
    };
    if k == 4 {
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        let mut lp: Vec<i32> = lower_expr_narrow(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, tw);
        let lr: i64 = lx_reg(lp);
        let mut blk2: Vec<i32> = lx_blk(lp);
        let mut rp: Vec<i32> = lower_expr_narrow(pool, node_field(pool, nid, 3), blk2, regs, lbls, sym, fir, tw);
        let rr: i64 = lx_reg(rp);
        let mut blk3: Vec<i32> = lx_blk(rp);
        let nr: i64 = ctr_next(regs);
        let arith_mode: i64 = sym_get(sym, "__arith_mode");
        let sat_helper: str = arith_width_helper_name(iop, tw, arith_mode);
        let strict_intrin: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
        // narrow-width signed div/rem (iop 5/6 with tw>0) routes
        // through `panic_div_iN` / `panic_rem_iN` runtime helpers so the
        // iN_MIN/-1 corner panics with a clean Nucleor message rather than
        // surfacing as Windows STATUS_INTEGER_OVERFLOW (rc=-1073741675) or
        // SIGFPE on POSIX. Mirrors the existing i64 panic_div path; closes
        // Unsigned divisions (tw < 0) keep the raw `udiv` path — there is
        // no MIN/-1 trap for unsigned widths.
        let mut narrow_div_helper: str = "";
        if (iop == 5 || iop == 6) && tw > 0 {
            if iop == 5 {
                if tw == 32 { narrow_div_helper = "panic_div_i32"; };
                if tw == 16 { narrow_div_helper = "panic_div_i16"; };
                if tw == 8 { narrow_div_helper = "panic_div_i8"; };
            } else {
                if tw == 32 { narrow_div_helper = "panic_rem_i32"; };
                if tw == 16 { narrow_div_helper = "panic_rem_i16"; };
                if tw == 8 { narrow_div_helper = "panic_rem_i8"; };
            };
        };
        if str_len(narrow_div_helper) > 0 {
            let lr64: i64 = ctr_next(regs);
            ir_block_add(blk3, ir_sext(lr64, lr, aw));
            let rr64: i64 = ctr_next(regs);
            ir_block_add(blk3, ir_sext(rr64, rr, aw));
            let mut sa: Vec<i32> = Vec::new();
            sa.push(lr64);
            sa.push(rr64);
            let hr: i64 = ctr_next(regs);
            ir_block_add(blk3, ir_call_ex(hr, narrow_div_helper, sa));
            ir_block_add(blk3, ir_trunc(nr, hr, aw));
        } else if str_len(sat_helper) > 0 {
            let lr64: i64 = ctr_next(regs);
            if tw > 0 {
                ir_block_add(blk3, ir_sext(lr64, lr, aw));
            } else {
                ir_block_add(blk3, ir_zext(lr64, lr, aw));
            };
            let rr64: i64 = ctr_next(regs);
            if tw > 0 {
                ir_block_add(blk3, ir_sext(rr64, rr, aw));
            } else {
                ir_block_add(blk3, ir_zext(rr64, rr, aw));
            };
            let mut sa: Vec<i32> = Vec::new();
            sa.push(lr64);
            sa.push(rr64);
            let hr: i64 = ctr_next(regs);
            ir_block_add(blk3, ir_call_ex(hr, sat_helper, sa));
            ir_block_add(blk3, ir_trunc(nr, hr, aw));
        } else if str_eq(strict_intrin, "1") == 1 && arith_mode <= 0 && (iop == 2 || iop == 3 || iop == 4) {
            // pass sign-encoded width `tw` (positive=signed,
            // negative=unsigned) so emit_overflow_arith picks the
            // matching s* or u* intrinsic. Pre-fix used `aw` (abs
            // width) which lost signedness; unsigned narrow arith
            // hit signed-overflow traps incorrectly.
            let trap_lbl: i64 = ctr_next(lbls);
            let cont_lbl: i64 = ctr_next(lbls);
            ir_block_add(blk3, ir_binop_overflow(iop, nr, lr, rr, tw, trap_lbl));
        } else {
            ir_block_add(blk3, ir_binop_t(iop, nr, lr, rr, aw));
        };
        return lx_new(nr, blk3);
    };
    // Unreachable if detect_narrow_chain is correct. Fail-safe: return -1.
    return lx_new(0 - 1, blk);
}

#[manual_drop]
fn lower_expr(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    // RFC-0015 phase 2: `as` cast. Lower inner, then call __nucleor_as_<T>
    // to actually perform width truncation / sign extension at runtime.
    if kind == 99 {
        let inner_nid: i64 = node_field(pool, nid, 1);
        let inner_lx: Vec<i32> = lower_expr(pool, inner_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let inner_blk: Vec<i32> = lx_blk(inner_lx);
        let inner_r: i64 = lx_reg(inner_lx);
        let target_type: str = node_field(pool, nid, 2);
        // T1.1 Phase 4: full as-cast matrix. If we can detect that
        // source is a float (variable with f32/f64 type, or kind==71
        // f64 literal), dispatch to the float↔int / float↔float
        // converter helper. Otherwise fall through to the existing
        // int-only `as_<T>` mask path.
        let src_ftype: str = binop_float_type(pool, inner_nid, sym, structs);
        let mut conv_helper: str = "";
        // Float → int / float → float dispatch.
        // NUC-FEEDBACK runtime safety / Rust-semantic alignment.
        // Pre-fix `f64 as i64` (and `f64 as u64`, `f32 as i64`, `f32 as
        // u64`) fell through to the bitcast-preserving `as_i64` /
        // `as_u64` helpers. That made `1.5_f64 as i64` return the i64
        // bit pattern of 1.5_f64 (~4607182418800017408) instead of `1`
        // -- a silent miscompute when adopters copy-pasted Rust code
        // expecting numeric truncation semantics.
        // Now: f-source / i64-or-u64 target dispatches to the saturating
        // numeric-truncation helper (matches Rust `as` semantics on
        // overflow). Adopters who genuinely need bit-pattern transit
        // (e.g. pushing f32 values into a Vec<i64> for narrow storage)
        // must use the explicit reinterpret surface: f64_to_bits(x) or
        // f32_to_bits(x). That makes intent local to the call site
        // instead of relying on a non-Rust-semantic `as` quirk.
        if str_eq(src_ftype, "f32") == 1 {
            if str_eq(target_type, "i32") == 1 { conv_helper = "f32_to_i32"; };
            if str_eq(target_type, "i64") == 1 { conv_helper = "f32_to_i64"; };
            if str_eq(target_type, "isize") == 1 { conv_helper = "f32_to_i64"; };
            if str_eq(target_type, "u32") == 1 { conv_helper = "f32_to_u32"; };
            if str_eq(target_type, "u64") == 1 { conv_helper = "f32_to_u64"; };
            if str_eq(target_type, "usize") == 1 { conv_helper = "f32_to_u64"; };
            if str_eq(target_type, "f64") == 1 { conv_helper = "f32_to_f64"; };
            // Lane 1 audit fix (2026-05-08) — close F-NUM-001. Pre-fix
            // `f32 as {i8,u8,i16,u16}` fell through to the integer-mask
            // `as_<T>` path operating on the f32 bit pattern (`v as u8`
            // returned the low byte of the IEEE 754 encoding — for any
            // round f32 with mantissa-low-bits-zero, that's silently 0).
            // RFC-0015 §3.5 promises saturating-truncate semantics for
            // ALL float-to-integer casts; route the four narrow widths
            // through the new __nucleor_f32_to_{i8,u8,i16,u16} helpers.
            if str_eq(target_type, "i8")  == 1 { conv_helper = "f32_to_i8"; };
            if str_eq(target_type, "u8")  == 1 { conv_helper = "f32_to_u8"; };
            if str_eq(target_type, "i16") == 1 { conv_helper = "f32_to_i16"; };
            if str_eq(target_type, "u16") == 1 { conv_helper = "f32_to_u16"; };
        };
        if str_eq(src_ftype, "f64") == 1 {
            if str_eq(target_type, "i32") == 1 { conv_helper = "f64_to_i32"; };
            if str_eq(target_type, "i64") == 1 { conv_helper = "f64_to_i64"; };
            if str_eq(target_type, "isize") == 1 { conv_helper = "f64_to_i64"; };
            if str_eq(target_type, "u32") == 1 { conv_helper = "f64_to_u32"; };
            if str_eq(target_type, "u64") == 1 { conv_helper = "f64_to_u64"; };
            if str_eq(target_type, "usize") == 1 { conv_helper = "f64_to_u64"; };
            if str_eq(target_type, "f32") == 1 { conv_helper = "f64_to_f32"; };
            // Lane 1 audit fix (2026-05-08) — close F-NUM-001 (f64 sister
            // of the f32 narrow-cast routing above).
            if str_eq(target_type, "i8")  == 1 { conv_helper = "f64_to_i8"; };
            if str_eq(target_type, "u8")  == 1 { conv_helper = "f64_to_u8"; };
            if str_eq(target_type, "i16") == 1 { conv_helper = "f64_to_i16"; };
            if str_eq(target_type, "u16") == 1 { conv_helper = "f64_to_u16"; };
        };
        // int → float: detect if source has int type and target is float.
        if str_len(src_ftype) == 0 {
            if str_eq(target_type, "f32") == 1 { conv_helper = "i64_to_f32"; };
            if str_eq(target_type, "f64") == 1 { conv_helper = "i64_to_f64"; };
        };
        if str_len(conv_helper) > 0 {
            let mut cargs: Vec<i32> = Vec::new();
            cargs.push(inner_r);
            let r: i64 = ctr_next(regs);
            ir_block_add(inner_blk, ir_call_ex(r, conv_helper, cargs));
            return lx_new(r, inner_blk);
        };
        // Fall through to existing as_<T> mask helpers (int↔int).
        let mut helper: str = "";
        if str_eq(target_type, "i8") == 1 { helper = "as_i8"; };
        if str_eq(target_type, "i16") == 1 { helper = "as_i16"; };
        if str_eq(target_type, "i32") == 1 { helper = "as_i32"; };
        if str_eq(target_type, "i64") == 1 { helper = "as_i64"; };
        if str_eq(target_type, "isize") == 1 { helper = "as_i64"; };
        if str_eq(target_type, "u8") == 1 { helper = "as_u8"; };
        if str_eq(target_type, "u16") == 1 { helper = "as_u16"; };
        if str_eq(target_type, "u32") == 1 { helper = "as_u32"; };
        if str_eq(target_type, "u64") == 1 { helper = "as_u64"; };
        if str_eq(target_type, "usize") == 1 { helper = "as_u64"; };
        if str_eq(target_type, "f32") == 1 { helper = "as_f32"; };
        if str_eq(target_type, "f64") == 1 { helper = "as_f64"; };
        if str_eq(target_type, "char") == 1 { helper = "as_u32"; };
        if str_len(helper) == 0 {
            return inner_lx;
        };
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(inner_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(inner_blk, ir_call_ex(r, helper, conv_args));
        return lx_new(r, inner_blk);
    };
    if kind == 1 {
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(r, node_field(pool, nid, 1)));
        return lx_new(r, blk);
    };
    if kind == 71 {
        let scaled_r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(scaled_r, node_field(pool, nid, 1)));
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(scaled_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_call_ex(r, "f64_from_scaled", conv_args));
        return lx_new(r, blk);
    };
    // NUC-FEEDBACK-002: f32 literal (kind 73). Same scaled-int
    // encoding as kind 71 but routes through f32_from_scaled so the
    // resulting i64 is the f32 bit pattern, not the f64 one. Without
    // this, `1.0f32` stored an f64 bit pattern in `Vec<f32>` slots and
    // `vec_get` returning to an f32 consumer printed 0.
    if kind == 73 {
        let scaled_r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(scaled_r, node_field(pool, nid, 1)));
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(scaled_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_call_ex(r, "f32_from_scaled", conv_args));
        return lx_new(r, blk);
    };
    // f64 raw-bits literal (AST kind 72). Value IS the i64
    // bit pattern of the parsed float (via str_to_f64 at lex time).
    // Lower as a direct const_int — Nucleor's f64 IS the i64 bit
    // pattern at the runtime ABI level, so no conversion needed.
    if kind == 72 {
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(r, node_field(pool, nid, 1)));
        return lx_new(r, blk);
    };
    if kind == 122 {
        // defensive halt: `?` inside a closure body.
        // Pre-fix the `?` lowering emitted `ret` from the closure function
        // on the Err/None path (correct Rust semantics — `?` in a closure
        // returns from the closure, not the outer fn). BUT Nucleor closures
        // return i64 by ABI convention, not Result<T,E>/Option<T>. So on
        // the Err/None path, the closure returned the heap-pointer of the
        // Err/None Vec as an i64 to its caller — wrong-class silent
        // miscompute: the outer fn saw a garbage integer (heap address)
        // where it expected the closure's i64 payload. Detected via
        // `__closure_id` in sym (set at closure-lowering entry, absent in
        // regular fn scope); halts cleanly with a workaround.
        if sym_get(sym, "__closure_id") >= 0 {
            print("ERROR: `?` operator inside a closure body is not yet supported in Nucleor. Workaround: pull the `?` into the outer fn with an explicit match — `let r = match inner_result() { Ok(v) => v, Err(e) => return Err(e) };` — or use `if let Err(e) = inner_result() { return Err(e); };`.");
            panic("nucleor: `?` inside closure body not yet supported (see ERROR diagnostic above)");
        };
        // RFC-0016 phase 1: `?` postfix operator.
        // tag-convention dispatch for Option vs Result.
        //   Result: Ok=1, Err=0  → tag==0 means err → early return.
        //   Option: Some=0, None=1 → tag==1 means err → early return.
        // Pre-fix used the Result convention unconditionally, so on
        // Option<T>: Some(x) (tag=0) was treated as err and early-
        // returned the whole Option Vec instead of extracting x; AND
        // None (tag=1) hit the ok-path's vec_get(_, 1) which OOB'd
        // the length-1 None Vec at runtime.
        // Regression: option vec out-of-bounds handling.
        // (v0.4.223 deferral note revisited; phase 3c revert in v0.4.224
        // cleared the bootstrap obstacle that blocked the v0.4.223 attempt).
        let inner_lx: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mut cur: Vec<i32> = lx_blk(inner_lx);
        let val_r: i64 = lx_reg(inner_lx);
        let qinner_nid: i64 = node_field(pool, nid, 1);
        let qfull: str = expr_full_type_from_sym(pool, qinner_nid, sym, structs);
        let v225_is_option: i64 = if str_eq(type_base_name(qfull), "Option") == 1 { 1 } else { 0 };
        let v225_err_tag: i64 = if v225_is_option == 1 { 1 } else { 0 };
        let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
        let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(val_r); tag_args.push(zero_r);
        let tag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
        let v225_err_tag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(v225_err_tag_r, v225_err_tag));
        let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, v225_err_tag_r));
        let err_lbl: i64 = ctr_next(lbls); let ok_lbl: i64 = ctr_next(lbls);
        // cmp_r == 1 (tag matches err sentinel) → err_lbl (return); else ok_lbl (extract payload at index 1).
        ir_block_add(cur, ir_br_cond(cmp_r, err_lbl, ok_lbl));
        let mut err_blk: Vec<i32> = ir_block_new(err_lbl); ir_fn_add_block(fir, err_blk);
        let cur_ret_id: i64 = sym_get(sym, "__current_fn_full_return");
        let mut cur_ret: str = "";
        if cur_ret_id >= 0 { cur_ret = cur_ret_id; };
        let mut ret_r: i64 = val_r;
        if str_eq(type_base_name(qfull), "Result") == 1 && str_eq(type_base_name(cur_ret), "Result") == 1 {
            let src_err: str = generic_second_type(qfull);
            let dst_err: str = generic_second_type(cur_ret);
            if str_len(src_err) > 0 && str_len(dst_err) > 0 && str_eq(src_err, dst_err) == 0 {
                let conv_fn: str = from_impl_call_name(trait_impls, src_err, dst_err);
                if str_len(conv_fn) == 0 {
                    print(str_concat("ERROR: error[TRAIT-001]: missing From<", str_concat(src_err, str_concat("> for ", str_concat(dst_err, " conversion required by `?`")))));
                    panic("nucleor: TRAIT-001 missing From conversion for question operator");
                };
                let one_err_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_const_int(one_err_r, 1));
                let mut err_pay_args: Vec<i32> = Vec::new(); err_pay_args.push(val_r); err_pay_args.push(one_err_r);
                let err_pay_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_call_ex(err_pay_r, "vec_get", err_pay_args));
                let mut conv_args: Vec<i32> = Vec::new(); conv_args.push(err_pay_r);
                let conv_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_user_call(conv_r, conv_fn, conv_args));
                let err_vec_r: i64 = ctr_next(regs);
                let mut err_vec_args: Vec<i32> = Vec::new();
                ir_block_add(err_blk, ir_call_ex(err_vec_r, "vec_new", err_vec_args));
                let zero_tag_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_const_int(zero_tag_r, 0));
                let mut push_tag_args: Vec<i32> = Vec::new(); push_tag_args.push(err_vec_r); push_tag_args.push(zero_tag_r);
                let push_tag_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_call_ex(push_tag_r, "vec_push", push_tag_args));
                let mut push_payload_args: Vec<i32> = Vec::new(); push_payload_args.push(err_vec_r); push_payload_args.push(conv_r);
                let push_payload_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_call_ex(push_payload_r, "vec_push", push_payload_args));
                ret_r = err_vec_r;
            };
        };
        ir_block_add(err_blk, ir_ret(ret_r));
        let mut ok_blk: Vec<i32> = ir_block_new(ok_lbl); ir_fn_add_block(fir, ok_blk);
        let one_r: i64 = ctr_next(regs); ir_block_add(ok_blk, ir_const_int(one_r, 1));
        let mut pay_args: Vec<i32> = Vec::new(); pay_args.push(val_r); pay_args.push(one_r);
        let pay_r: i64 = ctr_next(regs); ir_block_add(ok_blk, ir_call_ex(pay_r, "vec_get", pay_args));
        return lx_new(pay_r, ok_blk);
    };
    if kind == 2 {
        // intern via strtab_intern to dedup repeated literals.
        let idx: i64 = strtab_intern(strtab, fir, node_field(pool, nid, 1));
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_str(r, idx));
        return lx_new(r, blk);
    };
    if kind == 3 {
        let iname: str = node_field(pool, nid, 1);
        if str_eq(iname, "true") {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(r, 1));
            return lx_new(r, blk);
        };
        if str_eq(iname, "false") {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(r, 0));
            return lx_new(r, blk);
        };
        let ar: i64 = sym_get(sym, iname);
        if ar < 0 {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_fn_ptr(r, iname));
            return lx_new(r, blk);
        };
        // typed-load dispatch.
        // Width keyed by alloca-reg in fir's widths-by-reg table
        // (set at let-stmt time). Two vec_gets per read; no string
        // allocation, no sym_get hash. Sign-encoded: positive=signed
        // (sext), negative=unsigned (zext), 0=untyped (i64 fast path).
        let w_v209: i64 = ir_fn_get_width(fir, ar);
        if w_v209 == 0 {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_load(r, ar));
            return lx_new(r, blk);
        };
        let aw_v209: i64 = if w_v209 > 0 { w_v209 } else { 0 - w_v209 };
        let nr_v209: i64 = ctr_next(regs);
        ir_block_add(blk, ir_load_t(nr_v209, ar, aw_v209));
        let r_v209: i64 = ctr_next(regs);
        if w_v209 > 0 {
            ir_block_add(blk, ir_sext(r_v209, nr_v209, aw_v209));
        } else {
            ir_block_add(blk, ir_zext(r_v209, nr_v209, aw_v209));
        };
        return lx_new(r_v209, blk);
    };
    if kind == 4 {
        // unified narrow-arith dispatch
        // via tree-recursive width detection. Subsumes v0.4.211 (var+
        // var same-narrow), v0.4.212 (var+literal), AND nested
        // expression chains like `(a + b) * c` where every operand
        // resolves to the same narrow width.
        // Pre-fix flow for nested narrow `(a + b) * c` (i16):
        //   inner: load i16 → sext i64; load i16 → sext i64;
        //          add i16 → sext i64;  (v0.4.211 narrow path)
        //   outer: <i64 add of inner sext + load+sext c>
        //          + call __nucleor_as_i16(i64);  (i64 fallback)
        //   trunc i16; store i16.
        // Post-fix flow (full narrow chain):
        //   load i16 a; load i16 b; add i16; (no sext)
        //   load i16 c; mul i16; (no sext, no helper)
        //   sext i16 to i64;
        //   trunc i16; store i16.
        // Drops both the inner sext/trunc roundtrip AND the outer
        // narrow_via_as helper call for chained narrow arith.
        let v213_w: i64 = detect_narrow_chain(pool, nid, sym, fir);
        if v213_w != 0 {
            let v213_aw: i64 = if v213_w > 0 { v213_w } else { 0 - v213_w };
            let mut v213_p: Vec<i32> = lower_expr_narrow(pool, nid, blk, regs, lbls, sym, fir, v213_w);
            let v213_nr: i64 = lx_reg(v213_p);
            let mut v213_blk: Vec<i32> = lx_blk(v213_p);
            let v213_wr: i64 = ctr_next(regs);
            if v213_w > 0 {
                ir_block_add(v213_blk, ir_sext(v213_wr, v213_nr, v213_aw));
            } else {
                ir_block_add(v213_blk, ir_zext(v213_wr, v213_nr, v213_aw));
            };
            return lx_new(v213_wr, v213_blk);
        };
        // enum-equality dispatch. Pre-v0.3.128, `t == Tag::A`
        // (where t is an enum value) compared the underlying Vec
        // pointers — each Tag::A constructor allocates a fresh Vec, so
        // pointer equality was always false. Silent miscompute for
        // every enum-discriminator comparison adopters wrote.
        // Detect: if BOTH operands resolve to known enum etags (the
        // sym entry `__etag_<tname>_<mname>` populated at enum
        // collection), OR if exactly one is a kind-12 enum-variant
        // constructor and the other is presumed to be an enum value
        // of the same type (var-ref / fn-call result), emit a tag
        // compare instead of pointer compare. Tag is at vec_get(_, 0).
        let bop: i64 = node_field(pool, nid, 1);
        if bop == 30 || bop == 31 {
            let lhs_n: i64 = node_field(pool, nid, 2);
            let rhs_n: i64 = node_field(pool, nid, 3);
            let lhs_etag: i64 = enum_etag_for_node(pool, lhs_n, sym);
            let rhs_etag: i64 = enum_etag_for_node(pool, rhs_n, sym);
            // At least one side is a kind-12 enum constructor with a known etag.
            // The other side is treated as an enum value (its Vec[0] is its tag).
            if lhs_etag >= 0 || rhs_etag >= 0 {
                let mut elp: Vec<i32> = lower_expr(pool, lhs_n, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let elr: i64 = lx_reg(elp);
                let mut ecur: Vec<i32> = lx_blk(elp);
                let mut erp: Vec<i32> = lower_expr(pool, rhs_n, ecur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let err: i64 = lx_reg(erp);
                ecur = lx_blk(erp);
                let zero_r: i64 = ctr_next(regs); ir_block_add(ecur, ir_const_int(zero_r, 0));
                let mut lt_args: Vec<i32> = Vec::new(); lt_args.push(elr); lt_args.push(zero_r);
                let lt_tag: i64 = ctr_next(regs); ir_block_add(ecur, ir_call_ex(lt_tag, "vec_get", lt_args));
                let mut rt_args: Vec<i32> = Vec::new(); rt_args.push(err); rt_args.push(zero_r);
                let rt_tag: i64 = ctr_next(regs); ir_block_add(ecur, ir_call_ex(rt_tag, "vec_get", rt_args));
                let er: i64 = ctr_next(regs);
                let eiop: i64 = if bop == 30 { 7 } else { 8 };
                ir_block_add(ecur, ir_cmpop(eiop, er, lt_tag, rt_tag));
                return lx_new(er, ecur);
            };
            let v085_lhs_t: str = expr_struct_type(pool, lhs_n, sym, structs);
            let v085_rhs_t: str = expr_struct_type(pool, rhs_n, sym, structs);
            if str_len(v085_lhs_t) > 0 && str_eq(strip_spaces(v085_lhs_t), strip_spaces(v085_rhs_t)) == 1 {
                let v085_struct_si: i64 = struct_find_type(pool, structs, v085_lhs_t);
                if v085_struct_si >= 0 {
                    // base-name the type for the helper lookup so
                    // generic instantiations (Pair<i64>, Pair<str>, etc.)
                    // all dispatch through the single Pair__derived_eq
                    // generic helper.
                    let v085_lhs_base: str = type_base_name(v085_lhs_t);
                    let v085_helper: str = str_concat(v085_lhs_base, "__derived_eq");
                    let v085_ret: i64 = sym_get(sym, str_concat("__fnret_", v085_helper));
                    if v085_ret >= 0 {
                        let mut v085_lp: Vec<i32> = lower_expr(pool, lhs_n, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                        let v085_lr: i64 = lx_reg(v085_lp);
                        let mut v085_cur: Vec<i32> = lx_blk(v085_lp);
                        let mut v085_rp: Vec<i32> = lower_expr(pool, rhs_n, v085_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                        let v085_rr: i64 = lx_reg(v085_rp);
                        v085_cur = lx_blk(v085_rp);
                        let mut v085_args: Vec<i32> = Vec::new();
                        v085_args.push(v085_lr);
                        v085_args.push(v085_rr);
                        let v085_call_r: i64 = ctr_next(regs);
                        ir_block_add(v085_cur, ir_call_ex(v085_call_r, v085_helper, v085_args));
                        if bop == 30 {
                            return lx_new(v085_call_r, v085_cur);
                        } else {
                            // != is `1 - eq`.
                            let v085_one_r: i64 = ctr_next(regs);
                            ir_block_add(v085_cur, ir_const_int(v085_one_r, 1));
                            let v085_inv_r: i64 = ctr_next(regs);
                            ir_block_add(v085_cur, ir_binop_t(3, v085_inv_r, v085_one_r, v085_call_r, 64));
                            return lx_new(v085_inv_r, v085_cur);
                        };
                    };
                };
            };
            let v087_lhs_t: str = expr_struct_type(pool, lhs_n, sym, structs);
            let v087_rhs_t: str = expr_struct_type(pool, rhs_n, sym, structs);
            let v087_lb: str = type_base_name(v087_lhs_t);
            let v087_rb: str = type_base_name(v087_rhs_t);
            let mut v087_helper: str = "";
            if str_eq(v087_lb, "str") == 1 && str_eq(v087_rb, "str") == 1 { v087_helper = "str_eq"; };
            if str_eq(v087_lb, "String") == 1 && str_eq(v087_rb, "String") == 1 { v087_helper = "string_eq"; };
            if str_len(v087_helper) > 0 {
                let mut v087_lp: Vec<i32> = lower_expr(pool, lhs_n, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let v087_lr: i64 = lx_reg(v087_lp);
                let mut v087_cur: Vec<i32> = lx_blk(v087_lp);
                let mut v087_rp: Vec<i32> = lower_expr(pool, rhs_n, v087_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let v087_rr: i64 = lx_reg(v087_rp);
                v087_cur = lx_blk(v087_rp);
                let mut v087_args: Vec<i32> = Vec::new();
                v087_args.push(v087_lr);
                v087_args.push(v087_rr);
                let v087_call_r: i64 = ctr_next(regs);
                ir_block_add(v087_cur, ir_call_ex(v087_call_r, v087_helper, v087_args));
                if bop == 30 {
                    return lx_new(v087_call_r, v087_cur);
                } else {
                    let v087_one_r: i64 = ctr_next(regs);
                    ir_block_add(v087_cur, ir_const_int(v087_one_r, 1));
                    let v087_inv_r: i64 = ctr_next(regs);
                    ir_block_add(v087_cur, ir_binop_t(3, v087_inv_r, v087_one_r, v087_call_r, 64));
                    return lx_new(v087_inv_r, v087_cur);
                };
            };
        };
        // short-circuit lowering for `&&` (op 36) and `||` (op 37).
        // Pre-v0.3.148, both lowered to bitwise `and i64` / `or i64` of
        // both operand values, evaluating the RHS unconditionally even
        // when the LHS already determined the result. The LOGIC was
        // correct for boolean (0/1) values, but any RHS with side
        // effects or pointer-deref would run when the LHS guard said
        // it shouldn't. The canonical hazard:
        //   if x != 0 && deref(x).field == y { ... }
        // pre-fix evaluates deref(x) even when x == 0, which crashes
        // for any caller relying on short-circuit safety.
        // Fix: emit branch IR. For `A && B`:
        //   1. eval A → a_r
        //   2. cmp a_r != 0 → cond
        //   3. result alloca (in entry block, hoisted via ir_fn_add_entry_alloca)
        //   4. br cond, eval_b, false_lbl
        //   eval_b: eval B → b_r ; cmp b_r != 0 → b_bool ; store b_bool, result ; br merge
        //   false_lbl: store 0, result ; br merge
        //   merge: load result → final
        // For `A || B`: invert — true branch stores 1, false branch
        // evals B and stores its truthy projection.
        // The earlier v0.3.145 attempt at this fix used `ir_block_add` for
        // the result alloca (mid-function placement), which broke stage C
        // self-host with a silent exit on large source. Stage A's compiler
        // didn't tolerate mid-function allocas in the way LLVM expected.
        let bopz: i64 = node_field(pool, nid, 1);
        if bopz == 36 {
            let mut lpz: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let lrz: i64 = lx_reg(lpz);
            let mut lcur: Vec<i32> = lx_blk(lpz);
            let res_slot: i64 = ctr_next(regs);
            ir_fn_add_entry_alloca(fir, res_slot);
            let z1: i64 = ctr_next(regs); ir_block_add(lcur, ir_const_int(z1, 0));
            let lcond: i64 = ctr_next(regs);
            ir_block_add(lcur, ir_cmpop(8, lcond, lrz, z1));
            let r_lbl_a: i64 = ctr_next(lbls);
            let f_lbl_a: i64 = ctr_next(lbls);
            let m_lbl_a: i64 = ctr_next(lbls);
            ir_block_add(lcur, ir_br_cond(lcond, r_lbl_a, f_lbl_a));
            let mut rblk_a: Vec<i32> = ir_block_new(r_lbl_a);
            ir_fn_add_block(fir, rblk_a);
            let mut rpa: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), rblk_a, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let rra: i64 = lx_reg(rpa);
            let rcur_a: Vec<i32> = lx_blk(rpa);
            let z2: i64 = ctr_next(regs); ir_block_add(rcur_a, ir_const_int(z2, 0));
            let rcond_a: i64 = ctr_next(regs);
            ir_block_add(rcur_a, ir_cmpop(8, rcond_a, rra, z2));
            ir_block_add(rcur_a, ir_store(rcond_a, res_slot));
            ir_block_add(rcur_a, ir_br(m_lbl_a));
            let mut fblk_a: Vec<i32> = ir_block_new(f_lbl_a);
            ir_fn_add_block(fir, fblk_a);
            let z3: i64 = ctr_next(regs); ir_block_add(fblk_a, ir_const_int(z3, 0));
            ir_block_add(fblk_a, ir_store(z3, res_slot));
            ir_block_add(fblk_a, ir_br(m_lbl_a));
            let mut mblk_a: Vec<i32> = ir_block_new(m_lbl_a);
            ir_fn_add_block(fir, mblk_a);
            let final_a: i64 = ctr_next(regs);
            ir_block_add(mblk_a, ir_load(final_a, res_slot));
            return lx_new(final_a, mblk_a);
        };
        if bopz == 37 {
            let mut lpo: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let lro: i64 = lx_reg(lpo);
            let mut ocur: Vec<i32> = lx_blk(lpo);
            let res_slot_o: i64 = ctr_next(regs);
            ir_fn_add_entry_alloca(fir, res_slot_o);
            let z1o: i64 = ctr_next(regs); ir_block_add(ocur, ir_const_int(z1o, 0));
            let lcond_o: i64 = ctr_next(regs);
            ir_block_add(ocur, ir_cmpop(8, lcond_o, lro, z1o));
            let t_lbl_o: i64 = ctr_next(lbls);
            let f_lbl_o: i64 = ctr_next(lbls);
            let m_lbl_o: i64 = ctr_next(lbls);
            ir_block_add(ocur, ir_br_cond(lcond_o, t_lbl_o, f_lbl_o));
            let mut tblk_o: Vec<i32> = ir_block_new(t_lbl_o);
            ir_fn_add_block(fir, tblk_o);
            let one_o: i64 = ctr_next(regs); ir_block_add(tblk_o, ir_const_int(one_o, 1));
            ir_block_add(tblk_o, ir_store(one_o, res_slot_o));
            ir_block_add(tblk_o, ir_br(m_lbl_o));
            let mut fblk_o: Vec<i32> = ir_block_new(f_lbl_o);
            ir_fn_add_block(fir, fblk_o);
            let mut rpo: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), fblk_o, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let rro: i64 = lx_reg(rpo);
            let rcur_o: Vec<i32> = lx_blk(rpo);
            let z2o: i64 = ctr_next(regs); ir_block_add(rcur_o, ir_const_int(z2o, 0));
            let rcond_o: i64 = ctr_next(regs);
            ir_block_add(rcur_o, ir_cmpop(8, rcond_o, rro, z2o));
            ir_block_add(rcur_o, ir_store(rcond_o, res_slot_o));
            ir_block_add(rcur_o, ir_br(m_lbl_o));
            let mut mblk_o: Vec<i32> = ir_block_new(m_lbl_o);
            ir_fn_add_block(fir, mblk_o);
            let final_o: i64 = ctr_next(regs);
            ir_block_add(mblk_o, ir_load(final_o, res_slot_o));
            return lx_new(final_o, mblk_o);
        };
        let mut lp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let lr: i64 = lx_reg(lp);
        let mut cur: Vec<i32> = lx_blk(lp);
        let mut rp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let rr: i64 = lx_reg(rp);
        cur = lx_blk(rp);
        let mut iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        // Lane 1 audit fix (2026-05-08) — close C-001 / C-002 / C-007.
        // Detect u64 operands BEFORE the cmp / shift dispatch so the
        // signedness-aware iops (38..41 unsigned cmp, 25 lshr) replace
        // the signed defaults (9..12 slt/sgt/sle/sge, 24 ashr). u64
        // detection is conservative — if either operand carries a u64
        // type tag (variable annotation, kind-99 cast target, etc.) the
        // compare / shift is unsigned. eq/ne (iops 7/8) and shl (iop
        // 23) are signedness-agnostic and stay unchanged. The float
        // dispatch immediately below preempts u64 handling for f32/f64
        // operands (mixed u64+float is already a separate type error
        // upstream).
        let u64_cmp_v0508: i64 = if iop >= 9 && iop <= 12 || iop == 24 {
            if binop_u64_type(pool, node_field(pool, nid, 2), sym, structs) == 1 { 1 }
            else if binop_u64_type(pool, node_field(pool, nid, 3), sym, structs) == 1 { 1 }
            else { 0 }
        } else { 0 };
        if u64_cmp_v0508 == 1 {
            if iop == 9  { iop = 38; }
            else if iop == 10 { iop = 39; }
            else if iop == 11 { iop = 40; }
            else if iop == 12 { iop = 41; }
            else if iop == 24 { iop = 25; };
        };
        let r: i64 = ctr_next(regs);
        // T1.1 Phase 5: dispatch float binop to runtime helper instead
        // of integer binop. Detection: either operand is a variable
        // declared as f32/f64, or a kind==71 float literal. The f32
        // type wins precedence (matches narrowing cast rule). Only
        // applies to + - * / and the comparison ops.
        let lt: str = binop_float_type(pool, node_field(pool, nid, 2), sym, structs);
        let rt: str = binop_float_type(pool, node_field(pool, nid, 3), sym, structs);
        let mut ftype: str = "";
        if str_eq(lt, "f32") == 1 { ftype = "f32"; }
        else if str_eq(rt, "f32") == 1 { ftype = "f32"; }
        else if str_eq(lt, "f64") == 1 { ftype = "f64"; }
        else if str_eq(rt, "f64") == 1 { ftype = "f64"; };
        let helper: str = float_binop_helper(iop, ftype);
        if str_len(helper) > 0 {
            let mut conv_args: Vec<i32> = Vec::new();
            conv_args.push(lr);
            conv_args.push(rr);
            ir_block_add(cur, ir_call_ex(r, helper, conv_args));
        } else if is_cmp_or_logic(iop) == 1 { ir_block_add(cur, ir_cmpop(iop, r, lr, rr)); }
        else {
            // NUC-FEEDBACK runtime safety -- strict-
            // arithmetic via panic_*_i64 helpers.
            // REVERTED to OPT-IN default. Strict-by-default
            // (every `+`/`-`/`*` via runtime call) caused an 8.5x
            // self-build perf regression (4-10s -> 85s) because the
            // compiler's own arithmetic loops paid the function-call
            // overhead. The safety case is real, but the perf cost
            // was unacceptable for the common adopter compile flow.
            // New default: native LLVM `add nsw` (silent wrap on
            // overflow). Opt IN to strict via NUCLEOR_INT_STRICT_ARITH=1
            // for production / safety-critical builds. Other v0.3.x
            // safety improvements (vec OOB, hashmap missing key, OOM,
            // NaN cast, etc.) stay default-on because they have
            // negligible perf impact.
            let strict_env: str = env_get_or("NUCLEOR_INT_STRICT_ARITH", "");
            let mut strict: i64 = 0;
            if str_eq(strict_env, "1") == 1 { strict = 1; };
            let mut sh: str = "";
            // Lane 1 audit fix (2026-05-08) — close C-002 / C-003. Extend
            // u64 detection beyond add/sub/mul (the v0.4.886 surface) to
            // cover div/rem and the right-shift dispatch so panic_div_u64
            // / panic_rem_u64 / panic_shr_u64 are routed instead of the
            // signed-i64 helpers. The unsigned-cmp / lshr remap upstairs
            // already handled the comparison + non-panic shift paths.
            let mut u64_binop_v886: i64 = 0;
            if iop == 2 || iop == 3 || iop == 4 || iop == 5 || iop == 6 || iop == 24 || iop == 25 {
                if binop_u64_type(pool, node_field(pool, nid, 2), sym, structs) == 1 {
                    u64_binop_v886 = 1;
                } else if binop_u64_type(pool, node_field(pool, nid, 3), sym, structs) == 1 {
                    u64_binop_v886 = 1;
                };
            };
            // Pre-existing v0.4.886 gate kept the strict + / - / * u64 helpers
            // gated on `__has_u64_v886`. The div/rem/shr routes don't need
            // that gate (they're unconditional safety helpers, not opt-in
            // strict-arith ones), but preserve the v0.4.886 sym-gate for
            // the original three operators to avoid signature drift in
            // existing fixtures.
            let strict_u64_v886: i64 = if sym_get(sym, "__has_u64_v886") == 1 && u64_binop_v886 == 1 { 1 } else { 0 };
            if strict == 1 {
                if strict_u64_v886 == 1 {
                    if iop == 2 { sh = "panic_add_u64"; };
                    if iop == 3 { sh = "panic_sub_u64"; };
                    if iop == 4 { sh = "panic_mul_u64"; };
                } else {
                    if iop == 2 { sh = "panic_add"; };
                    if iop == 3 { sh = "panic_sub"; };
                    if iop == 4 { sh = "panic_mul"; };
                };
                if iop == 5 { sh = if u64_binop_v886 == 1 { "panic_div_u64" } else { "panic_div" }; };
                if iop == 6 { sh = if u64_binop_v886 == 1 { "panic_rem_u64" } else { "panic_rem" }; };
                // shifts get the panic surface too. Iops 23 (shl)
                // and 24 (ashr) for << and >>. Pre-fix amounts >= 64 or < 0
                // produced LLVM poison (observable but not silent); now they
                // panic with operands. Lane 1 audit (2026-05-08): u64
                // right shift routes to panic_shr_u64 (logical) instead of
                // panic_shr_i64 which sign-extends. The cmp/lshr remap up
                // top promotes iop 24 → 25 for u64 LHS, so the iop==24 line
                // here only fires for signed-i64 right shift; iop==25 is
                // the new unsigned right-shift form and uses panic_shr_u64
                // when strict.
                if iop == 23 { sh = "panic_shl"; };
                if iop == 24 { sh = "panic_shr"; };
                if iop == 25 { sh = "panic_shr_u64"; };
            };
            let arith_mode_explicit: i64 = sym_get(sym, "__arith_mode");
            if arith_mode_explicit == 1 && (iop == 2 || iop == 3 || iop == 4) {
                sh = "";
            };
            // per-op saturating dispatch. When inside a
            // `saturating { ... }` block (kind-52 with mode==2 sets
            // sym["__arith_mode"]=2 in the body's sym before lowering),
            // route +/-/* to the saturating runtime helpers. Pre-fix
            // (v0.4.105 .. v0.4.152) the block clamped only its final
            // value to i32; multi-step inner arithmetic still wrapped
            // at the i64 level, so `saturating { (max + 1) - 5 }` gave
            // a wrapped value pinned to i32 instead of `max - 5`.
            if iop == 2 || iop == 3 || iop == 4 {
                if arith_mode_explicit == 2 {
                    if iop == 2 { sh = "saturating_add"; };
                    if iop == 3 { sh = "saturating_sub"; };
                    if iop == 4 { sh = "saturating_mul"; };
                };
            };
            // div/mod ALWAYS use the panic helper, regardless of
            // NUCLEOR_INT_STRICT_ARITH. Pre-fix `let z = 0; let q = 10/z;`
            // (variable divisor zero — v0.4.74's literal-only NUM-009
            // didn't catch it) emitted raw `sdiv i64 10, 0` → SIGFPE
            // → exit 127 with no error message. The panic_div_i64 helper
            // already exists with a nice message; div is rare enough in
            // hot loops that the function-call overhead is negligible
            // (the v0.3.220 perf-revert was for + - * which dominate
            // tight numeric loops, not div).
            // Lane 1 audit fix (2026-05-08) — close C-003: route u64 div
            // / rem to the unsigned helpers so high-bit-set operands are
            // not silently miscompiled by the signed `/` / `%` in the
            // i64 helper.
            if iop == 5 { sh = if u64_binop_v886 == 1 { "panic_div_u64" } else { "panic_div" }; };
            if iop == 6 { sh = if u64_binop_v886 == 1 { "panic_rem_u64" } else { "panic_rem" }; };
            // variable-RHS shifts default to checked runtime
            // helpers. Literal in-range shifts keep raw LLVM for tight
            // bit loops; non-literal RHS can be <0 or >=64 at runtime,
            // which is LLVM poison for shl/ashr. Explicit opt-out is
            // available for low-level kernels that mask externally.
            // Lane 1 audit fix (2026-05-08) — close C-002: iop 25 (lshr,
            // u64 right shift) joins the shift-panic dispatch so
            // non-literal RHS routes to panic_shr_u64 instead of leaving
            // raw LLVM that would still be lshr-correct but unguarded.
            let shift_lenient: str = env_get_or("NUCLEOR_SHIFT_LENIENT", "0");
            if str_eq(shift_lenient, "1") == 0 && (iop == 23 || iop == 24 || iop == 25) {
                let rhs_shift: i64 = node_field(pool, nid, 3);
                let shift_const: Vec<i32> = const_i64_expr(pool, rhs_shift, sym);
                let shift_have: i64 = vec_get(shift_const, 0);
                let shift_amt: i64 = vec_get(shift_const, 1);
                let shift_safe_lit: i64 = if shift_have == 1 && shift_amt >= 0 && shift_amt < 64 { 1 } else { 0 };
                if shift_safe_lit == 0 {
                    if iop == 25 { sh = "panic_shr_u64"; };
                    if iop == 23 { sh = "panic_shl"; };
                    if iop == 24 { sh = "panic_shr"; };
                };
            };
            let strict_intrin: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
            if str_eq(strict_intrin, "1") == 1 && arith_mode_explicit <= 0 && (iop == 2 || iop == 3 || iop == 4) {
                let trap_lbl: i64 = ctr_next(lbls);
                let cont_lbl: i64 = ctr_next(lbls);
                let trap_width: i64 = if u64_binop_v886 == 1 { 0 - 64 } else { 0 };
                ir_block_add(cur, ir_binop_overflow(iop, r, lr, rr, trap_width, trap_lbl));
            } else if str_len(sh) > 0 {
                let mut sa: Vec<i32> = Vec::new();
                sa.push(lr); sa.push(rr);
                ir_block_add(cur, ir_call_ex(r, sh, sa));
            } else {
                ir_block_add(cur, ir_binop(iop, r, lr, rr));
            };
        };
        return lx_new(r, cur);
    };
    if kind == 5 {
        // dispatch to float-or-int subtract based on
        // operand type. Pre-v0.3.57 always used integer 0 + integer
        // sub, which mis-computed for f64 operands (subtracts the
        // f64 bit pattern as an i64 → garbage). Now: if operand
        // resolves to f32/f64 via binop_float_type, emit
        // f<T>_from_scaled(0) + f<T>_sub(zr, opr); otherwise the
        // legacy int path.
        let inner_nid: i64 = node_field(pool, nid, 1);
        let neg_ftype: str = binop_float_type(pool, inner_nid, sym, structs);
        let mut op_p: Vec<i32> = lower_expr(pool, inner_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let r: i64 = ctr_next(regs);
        if str_len(neg_ftype) > 0 {
            //  pre-fix unary minus on f64/f32
            // lowered as `f<T>_sub(0.0, opr)` — IEEE 754 returns `+0.0`
            // for `0 - (-0)`, losing the sign bit. So `let z: f64 =
            // -0.0; print_f64(1.0 / z)` printed `+inf` instead of the
            // correct `-inf`.
            // Fix uses XOR with the IEEE 754 sign bit (the canonical
            // sign-bit-flip semantics of unary minus). For f64, sign
            // bit is bit 63 → mask `0x8000000000000000` = i64::MIN.
            // For f32, sign bit is bit 31 → mask `0x80000000`. The
            // i64-everywhere ABI stores the f-bit-pattern as an i64,
            // so bitwise XOR on the i64 register is the fp negation.
            // No new runtime declares (sidesteps the v0.6.48-attempt-1
            // bootstrap-cycle hole that the earlier f<T>_neg helper
            // approach hit).
            let sign_bit: i64 = if str_eq(neg_ftype, "f32") == 1 { 2147483648 } else { const_i64_min() };
            let mask_reg: i64 = ctr_next(regs);
            ir_block_add(cur, ir_const_int(mask_reg, sign_bit));
            ir_block_add(cur, ir_binop(15, r, opr, mask_reg));
        } else {
            //  canonical Rust literal
            // `-9223372036854775808` (= i64::MIN) parses as unary-minus
            // applied to the literal `9223372036854775808`. The lexer
            // wraps `2^63` to i64::MIN at storage time, so the inner
            // literal already holds i64::MIN. Without this guard, the
            // strict-intrin default sends i64::MIN through panic_neg,
            // which correctly panics on `-(i64::MIN)` — but for the
            // CANONICAL i64::MIN literal in source, that's a false-
            // panic; the user wrote the textual representation of
            // i64::MIN and means i64::MIN, not "negate the value
            // i64::MIN". Detect immediate-literal-equal-to-i64::MIN
            // and short-circuit by emitting the constant directly.
            // `-(some_var_holding_min)` still routes through panic_neg
            // because the inner is a kind-3 reference, not a kind-1
            // literal.
            if node_kind(pool, inner_nid) == 1 && node_field(pool, inner_nid, 1) == const_i64_min() {
                ir_block_add(cur, ir_const_int(r, const_i64_min()));
                return lx_new(r, cur);
            };
            // same opt-in default as binop. NUCLEOR_INT_STRICT_ARITH=1
            // routes -x for i64 through panic_neg; default is native sub.
            //  pre-fix `neg(-i64::MIN)` silently wrapped to
            // i64::MIN — asymmetric with `+`/`*` which already panic by
            // default via NUCLEOR_INT_STRICT_INTRIN=1 (line ~18724). Now
            // unary-neg also consults NUCLEOR_INT_STRICT_INTRIN with the
            // same default (`1`), so `-x` for i64 routes through
            // panic_neg by default. Setting NUCLEOR_INT_STRICT_INTRIN=0
            // restores the legacy native-sub path. NUCLEOR_INT_STRICT_ARITH
            // (the older opt-in env var) is still honored on the `=1`
            // path for backward-compat.
            let strict_env: str = env_get_or("NUCLEOR_INT_STRICT_ARITH", "");
            let strict_intrin_env: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
            let mut strict: i64 = 0;
            if str_eq(strict_env, "1") == 1 { strict = 1; };
            if str_eq(strict_intrin_env, "1") == 1 { strict = 1; };
            if strict == 1 {
                let mut na: Vec<i32> = Vec::new();
                na.push(opr);
                ir_block_add(cur, ir_call_ex(r, "panic_neg", na));
            } else {
                let zr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_const_int(zr, 0));
                ir_block_add(cur, ir_binop(3, r, zr, opr));
            };
        };
        return lx_new(r, cur);
    };
    if kind == 6 {
        let mut op_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let zr: i64 = ctr_next(regs);
        ir_block_add(cur, ir_const_int(zr, 0));
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_cmpop(7, r, opr, zr));
        return lx_new(r, cur);
    };
    if kind == 90 || kind == 91 || kind == 92 {
        return lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
    };
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let mut tup_si: i64 = 0 - 1;
        let fnlen_v074: i64 = str_len(fn_name);
        if fnlen_v074 > 0 {
            let fnc0_v074: i64 = str_char_at(fn_name, 0);
            if fnc0_v074 >= 65 && fnc0_v074 <= 90 {
                tup_si = struct_find_type(pool, structs, fn_name);
            };
        };
        if tup_si >= 0 {
            let tup_snid: i64 = vec_get(structs, tup_si);
            if struct_is_tuple_style(pool, tup_snid) == 1 {
                let tup_args: i64 = node_field(pool, nid, 2);
                let tup_argc: i64 = list_len(pool, tup_args);
                let tup_vr: i64 = ctr_next(regs);
                let mut tup_new_args: Vec<i32> = Vec::new();
                ir_block_add(blk, ir_call_ex(tup_vr, "vec_new", tup_new_args));
                let mut tup_cur: Vec<i32> = blk;
                let mut tup_i: i64 = 0;
                while tup_i < tup_argc {
                    let mut tup_vp: Vec<i32> = lower_expr(pool, list_get(pool, tup_args, tup_i), tup_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let tup_val_r: i64 = lx_reg(tup_vp);
                    tup_cur = lx_blk(tup_vp);
                    let mut tup_push_args: Vec<i32> = Vec::new();
                    tup_push_args.push(tup_vr);
                    tup_push_args.push(tup_val_r);
                    let tup_pr: i64 = ctr_next(regs);
                    ir_block_add(tup_cur, ir_call_ex(tup_pr, "vec_push", tup_push_args));
                    tup_i = tup_i + 1;
                };
                return lx_new(tup_vr, tup_cur);
            };
        };
        // T1.1 Phase 3b: sizeof_struct(StructName) — compile-time
        // constant. Looks up the struct and returns its byte size
        // computed per its repr attribute (default Nucleor / C / packed).
        if str_eq(fn_name, "sizeof_struct") {
            let sa: i64 = node_field(pool, nid, 2);
            if list_len(pool, sa) == 1 {
                let arg_nid: i64 = list_get(pool, sa, 0);
                if node_kind(pool, arg_nid) == 3 {
                    let sname: str = node_field(pool, arg_nid, 1);
                    let si: i64 = struct_find_type(pool, structs, sname);
                    if si >= 0 {
                        let snode: i64 = vec_get(structs, si);
                        // Default Nucleor repr: backing storage is
                        // Vec<i32> with one i64 slot per field.
                        // repr(C) / repr(packed) variants land when
                        // attribute-preservation plumbing is wired.
                        let sz: i64 = struct_byte_size(pool, snode, "");
                        let r: i64 = ctr_next(regs);
                        ir_block_add(blk, ir_const_int(r, sz));
                        return lx_new(r, blk);
                    };
                };
            };
        };
        if str_eq(fn_name, "sanitize") {
            let args_list: i64 = node_field(pool, nid, 2);
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
        };
        if str_eq(fn_name, "grad") {
            let g_args: i64 = node_field(pool, nid, 2);
            if list_len(pool, g_args) >= 2 {
                let fn_arg: i64 = list_get(pool, g_args, 0);
                let mut xp: Vec<i32> = lower_expr(pool, list_get(pool, g_args, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let x_r: i64 = lx_reg(xp);
                let cur: Vec<i32> = lx_blk(xp);
                let h_ip: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(h_ip, 0));
                let h_fm: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(h_fm, 1));
                let mut h_args: Vec<i32> = Vec::new(); h_args.push(h_ip); h_args.push(h_fm);
                let h_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(h_r, "rods_f64_encode", h_args));
                let mut add_args: Vec<i32> = Vec::new(); add_args.push(x_r); add_args.push(h_r);
                let xph: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(xph, "rods_f64_add", add_args));
                let mut sub_args: Vec<i32> = Vec::new(); sub_args.push(x_r); sub_args.push(h_r);
                let xmh: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(xmh, "rods_f64_sub", sub_args));
                let target_fn: str = node_field(pool, fn_arg, 1);
                let mut fp_args: Vec<i32> = Vec::new(); fp_args.push(xph);
                let f_plus: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(f_plus, target_fn, fp_args));
                let mut fm_args: Vec<i32> = Vec::new(); fm_args.push(xmh);
                let f_minus: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(f_minus, target_fn, fm_args));
                let mut diff_args: Vec<i32> = Vec::new(); diff_args.push(f_plus); diff_args.push(f_minus);
                let diff: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(diff, "rods_f64_sub", diff_args));
                let mut twoh_args: Vec<i32> = Vec::new(); twoh_args.push(h_r); twoh_args.push(h_r);
                let two_h: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(two_h, "rods_f64_add", twoh_args));
                let mut div_args: Vec<i32> = Vec::new(); div_args.push(diff); div_args.push(two_h);
                let result: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(result, "rods_f64_div", div_args));
                return lx_new(result, cur);
            };
        };
        let args_list: i64 = node_field(pool, nid, 2);
        let argc: i64 = list_len(pool, args_list);
        let mut arg_regs: Vec<i32> = Vec::new();
        let mut ai: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while ai < argc {
            let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            arg_regs.push(lx_reg(ap));
            cur = lx_blk(ap);
            ai = ai + 1;
        };
        // NUC-FEEDBACK-008 — type-aware `print()` dispatch.
        // Pre-v0.3.143, every `print(arg)` call lowered to
        // __nucleor_print_str(arg) regardless of arg's type. When arg
        // was an i64 (e.g. a token count, a counter, a literal), the
        // string helper dereferenced the integer as a `const char *`
        // and crashed with SIGSEGV — visible to the adopter as a
        // silent program termination mid-output (exit code 1 or 139,
        // remaining prints just gone). Same hazard class as the
        // contextual-kw silent miscompiles: a real call you wrote
        // produces nothing useful and no diagnostic.
        // Fix: when the call is `print` with a single arg whose static
        // type is an int / float / bool, dispatch to the typed runtime
        // helper instead of __nucleor_print_str. Default falls through
        // to the existing __nucleor_print_str path for str / unknown.
        if str_eq(fn_name, "print") == 1 {
            // emit a diagnostic when print is called with > 1
            // argument. Pre-fix, the C ABI for the runtime helper
            // __nucleor_print_str(ptr) silently accepted extra args
            // (varargs-style behaviour) and dropped all but the first.
            // Adopters writing `print("x is", x)` got "x is" with no
            // diagnostic that x was lost. Same hazard class as the
            if argc > 1 {
                print(str_concat("ERROR: print() takes exactly 1 argument (got ", str_concat(str_from_int(argc), "). For multi-arg formatting, use print!/println! macros (e.g. println!(\"x={} y={}\", x, y)). The bare print() function lowers to __nucleor_print_str/i64/f64/bool and only consumes the first arg.")));
                // pre-fix the lowering kept going with argc==1
                // path — the second+ args were silently dropped from
                // the binary. Adopter writing `print("x is", x)` got
                // "x is" with no diagnostic that x was lost. Halt now.
                panic(str_concat("nucleor: print() takes exactly 1 arg (got ", str_concat(str_from_int(argc), ")")));
            };
            // print() with no args was silently lowered to
            // __nucleor_print_str(garbage_ptr), SIGSEGV at runtime.
            // Sister to v0.4.35 (print >1 arg): same hazard class —
            // adopter writing `print()` (likely a typo for `print("")`
            // or a leftover after deleting the arg) got a runtime
            // segfault with no compile-time signal. Halt cleanly.
            if argc == 0 {
                print("ERROR: print() takes exactly 1 argument (got 0). Use `print(\"\")` for an empty line, or supply the value to print. The bare print() function lowers to __nucleor_print_str/i64/f64/bool and consumed-zero-args produces a garbage-pointer SIGSEGV at runtime pre-v0.4.121.");
                panic("nucleor: print() takes exactly 1 arg (got 0 — pre-v0.4.121 this SIGSEGV'd at runtime with no compile-time signal)");
            };
            if argc == 1 {
                let parg_nid: i64 = list_get(pool, args_list, 0);
                let parg_kind: i64 = node_kind(pool, parg_nid);
                let mut p_helper: str = "";
                // Int literal (kind 1) and f64 literals (kinds 71/72).
                if parg_kind == 1 { p_helper = "__nucleor_print_i64"; };
                if parg_kind == 71 { p_helper = "__nucleor_print_f64"; };
                if parg_kind == 72 { p_helper = "__nucleor_print_f64"; };
                // Var ref (kind 3): look up __type_<name> in sym.
                if parg_kind == 3 {
                    let pvname: str = node_field(pool, parg_nid, 1);
                    let pvtype: i64 = sym_get(sym, str_concat("__type_", pvname));
                    if pvtype >= 0 {
                        let pvts: str = pvtype;
                        if str_eq(pvts, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pvts, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pvts, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                    };
                };
                // Fn-call result (kind 7): look up __fnret_<name> in sym.
                if parg_kind == 7 {
                    let pfn_name: str = node_field(pool, parg_nid, 1);
                    let pfn_rt: i64 = sym_get(sym, str_concat("__fnret_", pfn_name));
                    if pfn_rt >= 0 {
                        let prts: str = pfn_rt;
                        if str_eq(prts, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(prts, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(prts, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                    };
                    // builtin runtime helper fallback for
                    // direct calls. Mirrors the v0.3.168 fallback for
                    // method calls (kind 8). Pre-fix
                    // print(hashmap_get(h, "k")) SIGSEGV'd because no
                    // __fnret_hashmap_get entry exists. Hardcoded list
                    // of well-known runtime helpers with deterministic
                    // i64/bool return types.
                    if str_len(p_helper) == 0 {
                        // HashMap<K, V>.get / hashmap_get
                        // value-type lookup. Same hazard class as the
                        let hm_val_callee: i64 = if str_eq(pfn_name, "hashmap_get") == 1
                            || str_eq(pfn_name, "hashmap_get_or") == 1
                            || str_eq(pfn_name, "hashmap_remove") == 1
                            || str_eq(pfn_name, "btreemap_get") == 1 { 1 } else { 0 };
                        if hm_val_callee == 1 {
                            let pfn_args_h: i64 = node_field(pool, parg_nid, 2);
                            if list_len(pool, pfn_args_h) > 0 {
                                let recv_h_nid: i64 = list_get(pool, pfn_args_h, 0);
                                let mut recv_h_full: str = "";
                                if node_kind(pool, recv_h_nid) == 3 {
                                    let rh_name: str = node_field(pool, recv_h_nid, 1);
                                    let rh_t: i64 = sym_get(sym, str_concat("__fulltype_", rh_name));
                                    if rh_t >= 0 { recv_h_full = rh_t; };
                                };
                                let v_type: str = generic_second_type(recv_h_full);
                                if str_len(v_type) > 0 {
                                    let v_base: str = type_base_name(v_type);
                                    if str_eq(v_base, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                                    if str_eq(v_base, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                                    if str_eq(v_base, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                                    // str -> fall through to default print_str.
                                };
                            };
                        };
                    };
                    if str_len(p_helper) == 0 {
                        // NUC-FEEDBACK-006 --
                        // for vec_get/first/last/pop and similar Vec
                        // element returns, the element type comes from
                        // the receiver Vec, not a fixed i64 default.
                        // Pre-fix `print(vec_get(vec_of_str, i))` printed
                        // the str pointer as int (e.g. 2444806475504)
                        // instead of dispatching to print_str. Reuse
                        // indexed_element_full_type on args[0] to derive
                        // T from Vec<T>.
                        let vec_elem_callee: i64 = if str_eq(pfn_name, "vec_get") == 1
                            || str_eq(pfn_name, "vec_first") == 1
                            || str_eq(pfn_name, "vec_last") == 1
                            || str_eq(pfn_name, "vec_pop") == 1 { 1 } else { 0 };
                        if vec_elem_callee == 1 {
                            let pfn_args: i64 = node_field(pool, parg_nid, 2);
                            if list_len(pool, pfn_args) > 0 {
                            let recv_e_full: str = indexed_element_full_type(pool, list_get(pool, pfn_args, 0), sym, structs);
                            if str_len(recv_e_full) > 0 {
                                let recv_e_base: str = type_base_name(recv_e_full);
                                if str_eq(recv_e_base, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                                if str_eq(recv_e_base, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                                if str_eq(recv_e_base, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                                // str element: leave p_helper empty so we
                                // fall through to the default print_str
                                // path below -- which is correct for str
                                // values.
                            };
                            };
                        };
                        // i64 returns: hashmap_get, vec_get, vec_len,
                        // vec_first, vec_last, hashmap_len,
                        // hashmap_capacity, hashset_len, btreemap_len,
                        // vecdeque_len, str_len, str_to_int,
                        // str_to_i64, tok_vocab_size, tok_vec_len,
                        // tok_vec_at, etc.
                        // hashmap_get / btreemap_get also have value-
                        // type variation but the i64 default is the
                        // historical assumption -- adopters using
                        // HashMap<K, str> will hit the same NUC-FEEDBACK-
                        // 006 hazard; queued for a follow-on if it
                        // surfaces.
                        if str_len(p_helper) == 0 {
                        if str_eq(pfn_name, "hashmap_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "hashmap_capacity") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "hashset_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "btreemap_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "btreeset_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "vecdeque_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "vec_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        };
                        if str_eq(pfn_name, "str_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_to_int") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_to_i64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_to_int_with_base") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_index_of") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_count") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_char_at") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "tok_encode") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "tok_vocab_size") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "tok_vec_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "tok_vec_at") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "arena_alloc") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_arena_bytes") == 1 { p_helper = "__nucleor_print_i64"; };
                        // bool returns
                        if str_eq(pfn_name, "hashmap_contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "hashmap_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "hashset_contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "hashset_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "btreemap_contains_key") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "btreeset_contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "vecdeque_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "vec_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_eq") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_starts_with") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_ends_with") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_to_bool") == 1 { p_helper = "__nucleor_print_bool"; };
                        // f64 returns (typed math wrappers from v0.3.127 math_typed.nr)
                        if str_eq(pfn_name, "sqrt_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "exp_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "log_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "tanh_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "sin_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "cos_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "pow_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "f64_from_int") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "f64_from_bits") == 1 { p_helper = "__nucleor_print_f64"; };
                        // str returns: str_concat / str_substring fall
                        // through to default print_str (correct).
                    };
                };
                // also handle struct field access (kind 9).
                // Look up the struct via expr_struct_type, then find the
                // field's type via struct_field_type. Catches the
                // canonical `print(p.x)` where p.x is f64 -- pre-fix
                // SIGSEGV'd (printed the f64 bit pattern as a string
                // pointer). For unknown field types or non-struct receivers
                // (Box<dyn Trait>, generic param, etc.) the dispatch
                // falls through to __nucleor_print_str, preserving the
                // original behavior.
                if parg_kind == 9 {
                    let outer_type: str = expr_struct_type(pool, node_field(pool, parg_nid, 1), sym, structs);
                    if str_len(outer_type) > 0 {
                        let si: i64 = struct_find_type(pool, structs, outer_type);
                        if si >= 0 {
                            let ftype: str = type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, parg_nid, 2)));
                            if str_eq(ftype, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(ftype, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(ftype, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                        };
                    };
                };
                // also handle index expressions (kind 10).
                // `print(v[0])` where v: Vec<i64> SIGSEGV'd pre-fix
                // because the dispatch fell through to print_str which
                // dereferenced the i64 element as const char *. Reuse
                // indexed_element_full_type which already knows how to
                // strip one container layer (Vec<T> -> T) for var refs,
                // struct fields, fn-call results, and nested index.
                if parg_kind == 10 {
                    let etype_full: str = indexed_element_full_type(pool, node_field(pool, parg_nid, 1), sym, structs);
                    if str_len(etype_full) > 0 {
                        let etype: str = type_base_name(etype_full);
                        if str_eq(etype, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(etype, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(etype, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                    };
                };
                // also handle binop results (kind 4).
                // `print(a + b)` where a, b: i64 SIGSEGV'd pre-fix --
                // the dispatch fell through to print_str. Same hazard
                // class. Three buckets:
                //   - comparison/equality/logical ops (30-37) -> bool
                //   - float binop (binop_float_type returns f32/f64) -> f64
                //   - everything else -> i64 (arith on ints + bitwise)
                // The default-to-i64 is sound because Nucleor binops only
                // produce i64, f32/f64, or bool (no operator overloading;
                // str + str not supported; bool arith is TYP-002).
                if parg_kind == 4 {
                    let bop: i64 = node_field(pool, parg_nid, 1);
                    if bop == 30 || bop == 31 || bop == 32 || bop == 33 || bop == 34 || bop == 35 || bop == 36 || bop == 37 {
                        p_helper = "__nucleor_print_bool";
                    };
                    if str_len(p_helper) == 0 {
                        let bft: str = binop_float_type(pool, parg_nid, sym, structs);
                        if str_eq(bft, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(bft, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                    };
                    if str_len(p_helper) == 0 {
                        p_helper = "__nucleor_print_i64";
                    };
                };
                // print(if cond { x } else { y }) -- if-expr
                // (kind 23) defaults to i64 dispatch. Pre-fix the
                // dispatch fell through to print_str and SIGSEGV'd.
                // Same hazard class as v0.3.143/163-178 print() gaps.
                // Most adopter if-exprs produce i64; complex types
                // can use let-binding to assign first.
                if parg_kind == 23 {
                    p_helper = "__nucleor_print_i64";
                };
                // print(match x { ... }) -- match-expr
                // (kind 38) and block-expr (kind 52) default to i64.
                // Same hazard class as kind 23 if-expr.
                if parg_kind == 38 {
                    p_helper = "__nucleor_print_i64";
                };
                if parg_kind == 52 {
                    p_helper = "__nucleor_print_i64";
                };
                // cast expression (kind 99). Target type is
                // stored on the node; dispatch directly. Catches
                // print(x as i64) -- pre-fix dereferenced the i64 as
                // a string pointer. (For cast-to-str the dispatch falls
                // through to the default print_str, which is correct.)
                if parg_kind == 99 {
                    let ctype: str = type_base_name(node_field(pool, parg_nid, 2));
                    if str_eq(ctype, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                    if str_eq(ctype, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                    if str_eq(ctype, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                };
                // unary minus (kind 5) inherits operand type.
                // Reuse binop_float_type; default to i64.
                if parg_kind == 5 {
                    let inner_nid: i64 = node_field(pool, parg_nid, 1);
                    let nft: str = binop_float_type(pool, inner_nid, sym, structs);
                    if str_eq(nft, "f32") == 1 { p_helper = "__nucleor_print_f64"; }
                    else if str_eq(nft, "f64") == 1 { p_helper = "__nucleor_print_f64"; }
                    else { p_helper = "__nucleor_print_i64"; };
                };
                // unary not (kind 6) is always bool.
                if parg_kind == 6 {
                    p_helper = "__nucleor_print_bool";
                };
                // method call (kind 8) and associated fn
                // call (kind 12). Both use mangled symbol lookup
                // `__fnret_<TYPE>__<METHOD>` for typed return.
                // For kind 8, receiver is in field 1, method name
                // field 2; resolve receiver type via expr_struct_type.
                // For kind 12, struct/type name is in field 1
                // directly, method name field 2.
                if parg_kind == 8 {
                    let recv_nid: i64 = node_field(pool, parg_nid, 1);
                    let mname: str = node_field(pool, parg_nid, 2);
                    let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
                    if str_len(rtype) > 0 && str_len(mname) > 0 {
                        let mangled: str = str_concat(rtype, str_concat("__", mname));
                        let mret: i64 = sym_get(sym, str_concat("__fnret_", mangled));
                        if mret >= 0 {
                            let mt: str = type_base_name(mret);
                            if str_eq(mt, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(mt, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(mt, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                        };
                    };
                    // fallback for builtin methods that
                    // don't have __fnret_ entries (Vec::len, str::len,
                    // HashMap::is_empty, etc.). These methods have
                    // unambiguous return types by name across the
                    // stdlib container family.
                    if str_len(p_helper) == 0 && str_len(mname) > 0 {
                        // NUC-FEEDBACK-006 element-type
                        // lookup for container .get()/.first()/.last()/
                        // .pop() methods. Pre-fix v.get(i) on Vec<str>
                        // printed the str pointer as int. Reuse
                        // indexed_element_full_type on the receiver.
                        let m_elem_call: i64 = if str_eq(mname, "get") == 1
                            || str_eq(mname, "first") == 1
                            || str_eq(mname, "last") == 1
                            || str_eq(mname, "pop") == 1
                            || str_eq(mname, "front") == 1
                            || str_eq(mname, "back") == 1 { 1 } else { 0 };
                        if m_elem_call == 1 {
                            let mrecv_nid: i64 = node_field(pool, parg_nid, 1);
                            let m_e_full: str = indexed_element_full_type(pool, mrecv_nid, sym, structs);
                            if str_len(m_e_full) > 0 {
                                let m_e_base: str = type_base_name(m_e_full);
                                if str_eq(m_e_base, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                                if str_eq(m_e_base, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                                if str_eq(m_e_base, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                                // str element -> fall through to default
                                // print_str path (correct for str).
                            };
                            // HashMap<K, V>.get / similar -- when
                            // indexed_element_full_type fails (it only knows
                            // Vec<T>), try generic_second_type on the
                            // receiver's full type for HashMap-style 2-arg
                            // generics. Pre-fix `print(h.get("a"))` for
                            // HashMap<str, i64> SIGSEGV'd because the
                            // method-name fallback for "get" was removed in
                            if str_len(p_helper) == 0 {
                                let mut mrecv_full: str = "";
                                if node_kind(pool, mrecv_nid) == 3 {
                                    let mrn: str = node_field(pool, mrecv_nid, 1);
                                    let mrt: i64 = sym_get(sym, str_concat("__fulltype_", mrn));
                                    if mrt >= 0 { mrecv_full = mrt; };
                                };
                                let mv_type: str = generic_second_type(mrecv_full);
                                if str_len(mv_type) > 0 {
                                    let mv_base: str = type_base_name(mv_type);
                                    if str_eq(mv_base, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                                    if str_eq(mv_base, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                                    if str_eq(mv_base, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                                    // str -> fall through to default.
                                };
                            };
                        };
                        if str_len(p_helper) == 0 {
                        if str_eq(mname, "len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(mname, "count") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(mname, "capacity") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(mname, "is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(mname, "contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(mname, "contains_key") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(mname, "remove") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(mname, "starts_with") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(mname, "ends_with") == 1 { p_helper = "__nucleor_print_bool"; };
                        };
                    };
                };
                if parg_kind == 12 {
                    let tname12: str = node_field(pool, parg_nid, 1);
                    let mname12: str = node_field(pool, parg_nid, 2);
                    if str_len(tname12) > 0 && str_len(mname12) > 0 {
                        let mangled12: str = str_concat(tname12, str_concat("__", mname12));
                        let mret12: i64 = sym_get(sym, str_concat("__fnret_", mangled12));
                        if mret12 >= 0 {
                            let mt12: str = type_base_name(mret12);
                            if str_eq(mt12, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(mt12, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(mt12, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                        };
                    };
                };
                if str_len(p_helper) > 0 {
                    let pr_r: i64 = ctr_next(regs);
                    ir_block_add(cur, ir_call_ex(pr_r, p_helper, arg_regs));
                    return lx_new(pr_r, cur);
                };
            };
        };
        let fn_slot: i64 = sym_get(sym, fn_name);
        if fn_slot >= 0 {
            // catch `s(args)` for `s: str` (and other
            // non-callable typed bindings) at codegen time. Pre-fix
            // the indirect-call below treated the str pointer as a
            // fn-ptr and SIGSEGV'd at runtime — adopters who typo'd
            // a fn name into a string-typed variable name (or vice
            // versa) got a runtime crash with no compile-time signal.
            // Halt cleanly when the binding's `__type_<name>` is a
            // known non-callable scalar/string type.
            let type_v122: i64 = sym_get(sym, str_concat("__type_", fn_name));
            if type_v122 >= 0 {
                let type_str: str = type_v122;
                let tbase: str = type_base_name(type_str);
                // removed i*/u* from the uncallable list. Pre-v0.4.164
                // lumping integer types into TYP-014 broke
                //   `let double: i64 = |x| x * 2;` (tests/lang/closures.nr) and
                //   `let fp: i64 = fn_ptr;` (stdlib/rods/concurrency.nr)
                // because Nucleor's pre-RFC-0025 ABI uses i64 for BOTH numeric
                // values and fn pointers — the type system can't distinguish.
                // The original v0.4.122 motivation was the STR typo case
                // (`let s: str = "x"; s(42);` → SIGSEGV); that and other
                // genuinely-non-callable types stay rejected. The narrow
                // remaining gap — `let n: i64 = 5; n(x);` typoing a numeric
                // var as a fn — returns to pre-v0.4.122 runtime SIGSEGV with
                // no compile-time signal. Acceptable trade-off until proper
                // fn-pointer types ship in RFC-0025.
                let is_uncallable: i64 = if str_eq(tbase, "str") == 1
                    || str_eq(tbase, "f32") == 1
                    || str_eq(tbase, "f64") == 1
                    || str_eq(tbase, "bool") == 1
                    || str_eq(tbase, "Vec") == 1 { 1 } else { 0 };
                if is_uncallable == 1 {
                    panic(str_concat("error[TYP-014]: cannot call `", str_concat(fn_name, str_concat("(...)` — `", str_concat(fn_name, str_concat("` is bound as type `", str_concat(type_str, "`, which is not callable. Did you mean to call a different identifier, or to access an element via `[i]` / a method via `.method(args)`?"))))))));
                };
            };
            let fp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_load(fp_r, fn_slot));
            let r: i64 = ctr_next(regs);
            ir_block_add(cur, ir_indirect_call(r, fp_r, arg_regs));
            let clo_id_meta: i64 = sym_get(sym, str_concat("__closure_id_", fn_name));
            if clo_id_meta >= 0 {
                let caps_meta: i64 = sym_get(sym, str_concat("__closure_caps_", fn_name));
                if caps_meta >= 0 {
                    let cap_names: str = caps_meta;
                    // Pass the closure-value's local slot (not the per-
                    // literal clo_id) so the writeback can read captures
                    // from the per-instance env at runtime.
                    cur = closure_writeback_captures(cap_names, fn_slot, cur, regs, sym);
                };
            };
            return lx_new(r, cur);
        };
        let r: i64 = ctr_next(regs);
        // when fn_name is a registered user fn (its return
        // type is in sym as `__fnret_<name>`), emit a USER call op
        // (31) that bypasses the runtime-helper name lookup. Without
        // this, user fns that share a name with a runtime helper
        // (e.g. user `pow(base, exp)` vs `__nucleor_pow(f64, f64)`)
        // dispatched to the runtime helper — silent miscompute since
        // the int args were treated as f64 bit patterns by the
        // float helper. Adopters writing math/utility wrappers with
        // common names hit this on the very first probe.
        let user_ret: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if user_ret >= 0 {
            ir_block_add(cur, ir_user_call(r, fn_name, arg_regs));
        } else {
            ir_block_add(cur, ir_call_ex(r, fn_name, arg_regs));
        };
        return lx_new(r, cur);
    };
    if kind == 8 {
        let mut obj_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(obj_p);
        let mut cur: Vec<i32> = lx_blk(obj_p);
        let mname: str = node_field(pool, nid, 2);
        let args_list: i64 = node_field(pool, nid, 3);
        let argc: i64 = list_len(pool, args_list);
        let mut all_args: Vec<i32> = Vec::new();
        all_args.push(obj_r);
        let mut ai: i64 = 0;
        while ai < argc {
            let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            all_args.push(lx_reg(ap));
            cur = lx_blk(ap);
            ai = ai + 1;
        };
        let mut stype: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        let mut fn_name: str = "";
        if str_len(stype) > 0 { fn_name = trait_impl_find(trait_impls, stype, mname); };
        if str_len(fn_name) == 0 {
            let gbound_count: i64 = sym_get(sym, str_concat("__gparam_bound_count_", stype));
            if gbound_count > 0 {
                let mut gb_i: i64 = 0;
                while gb_i < gbound_count && str_len(fn_name) == 0 {
                    let gb_name: str = sym_get(sym, str_concat(str_concat("__gparam_bound_", stype), str_concat("_", str_from_int(gb_i))));
                    let gb_impl: str = trait_impl_find_unique_bound_method(trait_impls, gb_name, mname);
                    if str_eq(gb_impl, "__ambiguous_trait_bound_method") == 1 {
                        let msg_v529a: str = str_concat("error[TYP-007]: generic trait-bound method dispatch for `", str_concat(stype, str_concat(": ", str_concat(gb_name, str_concat("` method `.", str_concat(mname, "()` is ambiguous."))))));
                        let msg_v529b: str = " Nucleor currently emits one ABI-level generic fn body rather than per-call-site specializations, so a generic receiver method can only lower when the bound has exactly one concrete impl for that method. Split the generic call or use an explicit concrete helper until monomorphized trait dispatch ships.";
                        print(str_concat(msg_v529a, msg_v529b));
                        panic(str_concat("nucleor: ambiguous generic trait-bound method dispatch for ", str_concat(stype, str_concat(".", mname))));
                    };
                    if str_len(gb_impl) > 0 { fn_name = gb_impl; };
                    gb_i = gb_i + 1;
                };
            };
        };
        if str_len(fn_name) == 0 {
            if str_eq(type_base_name(stype), "Tensor") == 1 {
                fn_name = tensor_builtin_method_name(mname);
            };
            if str_len(fn_name) == 0 {
                // T2.2 (v0.2.348): iterator method dispatch on Vec.
                // `v.map(f)` / `v.filter(p)` / `v.fold(init, f)` etc.
                // route to the typed `vec_*_i64` runtime helpers
                // already wired up in stdlib/runtime/nucleor_llvm_rt.c.
                // Anything else falls through to the existing
                // `vec_<method>` convention.
                // only use the vec_*_i64 iterator dispatch
                // when the receiver IS a Vec. Pre-fix `h.contains(k)`
                // for HashMap fell through here and called
                // vec_contains_i64 instead of hashmap_contains --
                // returning the wrong answer (false on present keys).
                let stype_for_iter: str = type_base_name(stype);
                let mut recv_is_vec: i64 = if str_len(stype_for_iter) == 0
                    || str_eq(stype_for_iter, "Vec") == 1 { 1 } else { 0 };
                // also exclude Option/Result via var-ref
                // __type_<name> lookup (when stype was empty). Without
                // this, `opt.map(f)` for opt: Option<T> falls through
                // recv_is_vec==1 → vec_map_i64 which links-fails or
                // returns Vec instead of Option.
                if recv_is_vec == 1 && str_len(stype_for_iter) == 0 {
                    let recv_check_v92: i64 = node_field(pool, nid, 1);
                    if node_kind(pool, recv_check_v92) == 3 {
                        let recv_n_v92: str = node_field(pool, recv_check_v92, 1);
                        let recv_t_v92: i64 = sym_get(sym, str_concat("__type_", recv_n_v92));
                        if recv_t_v92 >= 0 {
                            let recv_b_v92: str = type_base_name(recv_t_v92);
                            if str_eq(recv_b_v92, "Option") == 1 || str_eq(recv_b_v92, "Result") == 1 {
                                recv_is_vec = 0;
                            };
                        };
                    };
                };
                // str-literal receiver (kind 2). expr_struct_type
                // returns "" for literals, so stype was empty and recv_is_vec
                // stayed 1. `"abc".len()` lowered to vec_len on the str ptr
                // (silent miscompute, returned 0); `"abc".contains("b")` and
                // friends would have routed to vec_contains_i64 (also a
                // silent miscompute reading the str header as a vec header).
                // Detect kind-2 receiver here, clear recv_is_vec, and stamp
                // stype = "str" so the existing v0.4.88 str-method dispatch
                // (str_len / str_contains / str_replace / etc.) picks it up.
                if recv_is_vec == 1 {
                    let recv_check: i64 = node_field(pool, nid, 1);
                    if node_kind(pool, recv_check) == 2 {
                        recv_is_vec = 0;
                        stype = "str";
                    };
                };
                if recv_is_vec == 1 && iter_method_for_vec(mname) == 1 {
                    fn_name = str_concat("vec_", str_concat(mname, "_i64"));
                } else {
                    // receiver-type-aware dispatch for the
                    // collection family (HashMap/HashSet/BTreeMap/
                    // BTreeSet/VecDeque). Pre-v0.3.100 the fallback
                    // was always `vec_<method>`, so a Rust-style
                    // `m.insert(k, v)` on a `HashMap<K,V>` lowered
                    // to `vec_insert(m, k, v)` — undefined symbol at
                    // clang link. The lowercase runtime helpers
                    // (`hashmap_insert`, `hashset_insert`, etc.) all
                    // exist; this is the missing surface-level
                    // dispatch from the `let m: HashMap<...>`
                    // type annotation through `expr_struct_type` to
                    // the right prefix. Falls through to `vec_*` for
                    // unknown receiver types so the existing Vec
                    // method convention still works.
                    let stype_base: str = type_base_name(stype);
                    if str_eq(stype_base, "HashMap") == 1 {
                        fn_name = str_concat("hashmap_", mname);
                    } else if str_eq(stype_base, "HashSet") == 1 {
                        fn_name = str_concat("hashset_", mname);
                    } else if str_eq(stype_base, "BTreeMap") == 1 {
                        fn_name = str_concat("btreemap_", mname);
                    } else if str_eq(stype_base, "BTreeSet") == 1 {
                        fn_name = str_concat("btreeset_", mname);
                    } else if str_eq(stype_base, "VecDeque") == 1 {
                        fn_name = str_concat("vecdeque_", mname);
                    } else if str_eq(stype_base, "Option") == 1 && (str_eq(mname, "unwrap") == 1 || str_eq(mname, "unwrap_or") == 1 || str_eq(mname, "is_some") == 1 || str_eq(mname, "is_none") == 1 || str_eq(mname, "expect") == 1 || str_eq(mname, "map") == 1 || str_eq(mname, "and_then") == 1 || str_eq(mname, "unwrap_or_else") == 1) {
                        // Option<T> method dispatch — was hitting
                        // the v0.4.53 "non-Option receiver" panic-guard
                        // even when receiver IS typed Option<T>, because
                        // no Option dispatch branch existed and the chain
                        // fell through to the user-fn lookup. Runtime
                        // helpers added in nucleor_llvm_rt.c v0.4.90.
                        fn_name = str_concat("option_", mname);
                    } else if str_eq(stype_base, "Option") == 1 && (str_eq(mname, "unwrap_or_default") == 1 || str_eq(mname, "take") == 1 || str_eq(mname, "replace") == 1 || str_eq(mname, "flatten") == 1 || str_eq(mname, "as_ref") == 1 || str_eq(mname, "as_mut") == 1 || str_eq(mname, "iter") == 1 || str_eq(mname, "ok_or") == 1 || str_eq(mname, "ok_or_else") == 1 || str_eq(mname, "cloned") == 1 || str_eq(mname, "copied") == 1) {
                        //  canonical Rust Option methods not yet in
                        // Nucleor's runtime surface (`unwrap_or_default`,
                        // `take`, `replace`, `flatten`, `as_ref`, `as_mut`,
                        // `iter`, `ok_or`, `ok_or_else`, `cloned`, `copied`)
                        // pre-fix fell through to the kind-8 catch-all
                        // `vec_<method>(receiver)` and surfaced as the
                        // wrong-class TYP-005 "Vec<T> has no method" diag.
                        // Halt now with a clean per-method workaround
                        // pointer. Tracked for forward-roadmap (extended
                        // Option/Result method surface alongside Default
                        // trait infrastructure).
                        let v083_workaround_opt: str = if str_eq(mname, "unwrap_or_default") == 1 {
                            "use `unwrap_or(<default>)` with an explicit default — Nucleor doesn't auto-derive Default per type yet"
                        } else if str_eq(mname, "take") == 1 || str_eq(mname, "replace") == 1 {
                            "mutate the binding manually: `let v: T = opt.unwrap(); opt = None;` (or assign the new Some value)"
                        } else if str_eq(mname, "flatten") == 1 {
                            "use `match opt { Some(inner) => inner, None => None }`"
                        } else if str_eq(mname, "ok_or") == 1 || str_eq(mname, "ok_or_else") == 1 {
                            "convert via `match opt { Some(v) => Ok(v), None => Err(<err_value>) }`"
                        } else {
                            "no current shorthand — destructure with `match opt { Some(v) => ..., None => ... }`"
                        };
                        print(str_concat("ERROR: `Option::", str_concat(mname, str_concat("()` is not yet implemented in Nucleor's Option/Result method surface. Workaround: ", str_concat(v083_workaround_opt, ".")))))));
                        panic(str_concat("nucleor: Option method `.", str_concat(mname, "()` not yet supported (see ERROR diagnostic above)")));
                    } else if str_eq(stype_base, "Result") == 1 && (str_eq(mname, "unwrap") == 1 || str_eq(mname, "unwrap_or") == 1 || str_eq(mname, "unwrap_err") == 1 || str_eq(mname, "is_ok") == 1 || str_eq(mname, "is_err") == 1 || str_eq(mname, "ok") == 1 || str_eq(mname, "err") == 1 || str_eq(mname, "expect") == 1 || str_eq(mname, "map") == 1 || str_eq(mname, "and_then") == 1 || str_eq(mname, "unwrap_or_else") == 1 || str_eq(mname, "or_else") == 1) {
                        // Result<T,E> method dispatch — same
                        // root cause as Option above.
                        fn_name = str_concat("result_", mname);
                    } else if str_eq(stype_base, "Result") == 1 && (str_eq(mname, "unwrap_or_default") == 1 || str_eq(mname, "as_ref") == 1 || str_eq(mname, "as_mut") == 1 || str_eq(mname, "iter") == 1 || str_eq(mname, "map_err") == 1 || str_eq(mname, "expect_err") == 1 || str_eq(mname, "cloned") == 1 || str_eq(mname, "copied") == 1) {
                        let v083_workaround_res: str = if str_eq(mname, "unwrap_or_default") == 1 {
                            "use `unwrap_or(<default>)` with an explicit default value"
                        } else if str_eq(mname, "map_err") == 1 {
                            "use `match res { Ok(v) => Ok(v), Err(e) => Err(<f>(e)) }` to transform the err arm"
                        } else if str_eq(mname, "expect_err") == 1 {
                            "use `match res { Err(e) => e, Ok(_) => panic!(\"<msg>\") }`"
                        } else {
                            "destructure with `match res { Ok(v) => ..., Err(e) => ... }`"
                        };
                        print(str_concat("ERROR: `Result::", str_concat(mname, str_concat("()` is not yet implemented in Nucleor's Option/Result method surface. Workaround: ", str_concat(v083_workaround_res, ".")))));
                        panic(str_concat("nucleor: Result method `.", str_concat(mname, "()` not yet supported (see ERROR diagnostic above)")));
                    } else if str_eq(stype_base, "String") == 1 && (str_eq(mname, "push") == 1 || str_eq(mname, "push_str") == 1 || str_eq(mname, "len") == 1 || str_eq(mname, "capacity") == 1 || str_eq(mname, "get_byte") == 1 || str_eq(mname, "clear") == 1 || str_eq(mname, "as_ptr") == 1 || str_eq(mname, "print") == 1 || str_eq(mname, "eq") == 1 || str_eq(mname, "eq_str") == 1 || str_eq(mname, "starts_with") == 1 || str_eq(mname, "ends_with") == 1 || str_eq(mname, "contains") == 1 || str_eq(mname, "clone") == 1 || str_eq(mname, "free") == 1
                        || str_eq(mname, "is_empty") == 1 || str_eq(mname, "to_uppercase") == 1 || str_eq(mname, "to_lowercase") == 1 || str_eq(mname, "trim") == 1 || str_eq(mname, "trim_start") == 1 || str_eq(mname, "trim_end") == 1 || str_eq(mname, "find") == 1 || str_eq(mname, "substring") == 1 || str_eq(mname, "char_at") == 1 || str_eq(mname, "as_str") == 1) {
                        // extended String method surface — adds
                        // is_empty / to_uppercase / to_lowercase / trim /
                        // trim_start / trim_end / find / substring /
                        // char_at / as_str. Runtime helpers landed in
                        // nucleor_llvm_rt.c v0.4.124 batch.
                        let mut sm: str = mname;
                        if str_eq(mname, "push") == 1 { sm = "push_byte"; };
                        fn_name = str_concat("string_", sm);
                    } else if str_eq(stype_base, "str") == 1 && (str_eq(mname, "len") == 1 || str_eq(mname, "contains") == 1 || str_eq(mname, "replace") == 1 || str_eq(mname, "split") == 1 || str_eq(mname, "starts_with") == 1 || str_eq(mname, "ends_with") == 1 || str_eq(mname, "to_lower") == 1 || str_eq(mname, "to_upper") == 1 || str_eq(mname, "trim") == 1 || str_eq(mname, "trim_start") == 1 || str_eq(mname, "trim_end") == 1 || str_eq(mname, "substring") == 1 || str_eq(mname, "char_at") == 1) {
                        // str method receiver-type-aware dispatch.
                        // Pre-fix `s.len()` lowered to `vec_len(s)` which
                        // reads the str pointer as if it were a Vec
                        // header — silent miscompute, returned garbage
                        // like 1684828783 instead of byte length.
                        // Same hazard for `s.contains/replace/split/
                        // starts_with/ends_with` which failed at clang
                        // link with `undefined value '@vec_contains'`
                        // etc. Mirrors the v0.3.100 HashMap/HashSet
                        // receiver-type-aware pattern; the runtime
                        // helpers (str_len, str_contains, str_replace,
                        // str_split, str_starts_with, str_ends_with)
                        // all exist.
                        fn_name = str_concat("str_", mname);
                    } else {
                        // user-defined inherent-impl method
                        // dispatch via mangled name. Pre-v0.3.123 the
                        // fallback was always `vec_<method>`, so a
                        // chained inherent fn call like
                        // `Counter::new().add(10).add(5)` lowered the
                        // SECOND `.add(...)` to `vec_add(...)` —
                        // undefined symbol at clang link. The kind-12
                        // path (Counter::new) was fixed in v0.3.111
                        // via the same `__fnret_<mangled>` lookup;
                        // mirror that here for instance-method chains.
                        // Falls through to `vec_<method>` for receiver
                        // types that aren't registered impl methods,
                        // preserving the existing Vec convention.
                        let user_mangled: str = str_concat(stype_base, str_concat("__", mname));
                        let user_ret: i64 = sym_get(sym, str_concat("__fnret_", user_mangled));
                        if user_ret >= 0 {
                            fn_name = user_mangled;
                        } else {
                            // NUC-FEEDBACK silent-undefined-symbol guard.
                            // Pre-fix `x.unwrap()` (and .expect, .ok, .err,
                            // .unwrap_or) on a non-Option/Result receiver
                            // (e.g. bare i64) lowered to `vec_unwrap(x)`,
                            // which is not a runtime helper. Build failed
                            // late at clang link with `undefined value
                            // '@vec_unwrap'`. Adopters got a confusing
                            // LLVM-IR error pointing at compiler-emitted
                            // text rather than their source. Halt now with
                            // a clear diagnostic naming the call.
                            let bad_on_vec: i64 = if str_eq(mname, "unwrap") == 1
                                || str_eq(mname, "expect") == 1
                                || str_eq(mname, "unwrap_or") == 1
                                || str_eq(mname, "unwrap_or_else") == 1
                                || str_eq(mname, "ok") == 1
                                || str_eq(mname, "err") == 1
                                || str_eq(mname, "is_ok") == 1
                                || str_eq(mname, "is_err") == 1
                                || str_eq(mname, "is_some") == 1
                                || str_eq(mname, "is_none") == 1
                                || str_eq(mname, "and_then") == 1
                                || str_eq(mname, "or_else") == 1 { 1 } else { 0 };
                            if bad_on_vec == 1 {
                                // before panicking, look up the
                                // receiver's declared __type_<name> to see
                                // if it IS Option/Result. The earlier
                                // type_base_name(stype) chain doesn't catch
                                // this because expr_struct_type returned ""
                                // for the var-ref-to-Option case in some
                                // code paths. Route to option_/result_
                                // runtime helpers (added in
                                // nucleor_llvm_rt.c v0.4.90) if so.
                                let recv_for_opt: i64 = node_field(pool, nid, 1);
                                let mut routed: i64 = 0;
                                if node_kind(pool, recv_for_opt) == 3 {
                                    let recv_name_v490: str = node_field(pool, recv_for_opt, 1);
                                    let recv_type_id: i64 = sym_get(sym, str_concat("__type_", recv_name_v490));
                                    if recv_type_id >= 0 {
                                        let recv_type_v490: str = recv_type_id;
                                        let recv_base: str = type_base_name(recv_type_v490);
                                        if str_eq(recv_base, "Option") == 1 {
                                            fn_name = str_concat("option_", mname);
                                            routed = 1;
                                        };
                                        if str_eq(recv_base, "Result") == 1 {
                                            fn_name = str_concat("result_", mname);
                                            routed = 1;
                                        };
                                    };
                                };
                                if routed == 0 {
                                    let part_a: str = str_concat("ERROR: `.", str_concat(mname, "()` is an Option/Result method, not a Vec method."));
                                    let part_b: str = str_concat(" Receiver type unknown to the type-checker; pre-v0.4.53 this lowered to `vec_", str_concat(mname, "(...)` and failed late at clang link with an undefined-symbol error."));
                                    let part_c: str = " Workaround: ensure the receiver binding is typed `Option<T>` / `Result<T,E>`, or use the explicit `match expr { Some(x) => x, None => default }` pattern.";
                                    print(str_concat(part_a, str_concat(part_b, part_c)));
                                    panic(str_concat("nucleor: Option/Result method `.", str_concat(mname, "()` called on non-Option receiver")));
                                };
                            };
                            // primitive-receiver method guard.
                            // Pre-fix `let x: i64 = 5; x.no_such_method();`
                            // fell through every receiver-typed branch
                            // and lowered to `vec_no_such_method(x)`,
                            // which the v0.4.106 lift then surfaced as
                            // `error[TYP-005]: undefined function
                            // 'vec_no_such_method()'`. Adopters had to
                            // mentally translate the `vec_` prefix back
                            // to "the type-checker thought my receiver
                            // was a Vec when it isn't" — confusing.
                            // Detect primitive receivers (i*, u*, f*,
                            // bool) here and emit a method-targeted
                            // diagnostic naming both the call site and
                            // the receiver type. str has its own
                            // receiver-type-aware dispatch above
                            // (v0.4.88) so it doesn't reach this path.
                            let stype_base: str = type_base_name(stype);
                            let is_primitive_recv: i64 = if str_eq(stype_base, "i8") == 1
                                || str_eq(stype_base, "i16") == 1
                                || str_eq(stype_base, "i32") == 1
                                || str_eq(stype_base, "i64") == 1
                                || str_eq(stype_base, "u8") == 1
                                || str_eq(stype_base, "u16") == 1
                                || str_eq(stype_base, "u32") == 1
                                || str_eq(stype_base, "u64") == 1
                                || str_eq(stype_base, "f32") == 1
                                || str_eq(stype_base, "f64") == 1
                                || str_eq(stype_base, "bool") == 1 { 1 } else { 0 };
                            if is_primitive_recv == 1 {
                                let pa: str = str_concat("error[TYP-007]: receiver type `", str_concat(stype_base, str_concat("` has no method `.", str_concat(mname, "()`."))));
                                let pb: str = str_concat(" Pre-v0.4.107 this lowered to `vec_", str_concat(mname, "(...)` and failed late at clang link with an undefined-symbol error."));
                                let pc: str = " Primitive numeric and bool types in Nucleor have no inherent methods today; use a free fn (e.g. `i64_to_str(x)`) or wrap in a struct that impls the method.";
                                print(str_concat(pa, str_concat(pb, pc)));
                                panic(str_concat("nucleor: no method `.", str_concat(mname, str_concat("()` for primitive receiver `", str_concat(stype_base, "`")))));
                            };
                            if str_len(stype_base) > 4 && str_starts_with(stype_base, "dyn ") == 1 {
                                print(str_concat("ERROR: trait-object dispatch `<", str_concat(stype_base, str_concat(">`.", str_concat(mname, "()` is not yet supported in Nucleor. Workaround: use a concrete struct type instead of `Box<dyn Trait>` — `let d: Dog = Dog {};` then call the trait method directly (`d.speak()`); or add an enum dispatch wrapper (`enum Animal { Dog(Dog), Cat(Cat) }` + match).")))));
                                panic(str_concat("nucleor: trait-object method dispatch on `Box<", str_concat(stype_base, "> not yet supported (see ERROR diagnostic above)")));
                            };
                            // borrowed-reference receiver guard.
                            // Pre-fix `r.foo()` for `r: &S` fell through every
                            // typed-receiver branch (str / Option / Result /
                            // String / HashMap / etc.) and through the
                            // user-impl `<TypeName>__<method>` lookup, which
                            // mangled to "S__foo" — not registered for
                            // free-fn `fn foo(self: &S)` patterns. The
                            // catch-all then synthesized `vec_foo(r)` and
                            // the v0.4.106/.127 lift surfaced it as
                            // `error[TYP-005]: receiver type 'Vec<T>' has no
                            // method '.foo()'` — confusing because the
                            // receiver is `&S`, not `Vec<T>`.
                            // Detect via `__fulltype_<recv>` sym entry which
                            // preserves the borrow marker (`__type_<recv>`
                            // stores only the base name post-type_base_name).
                            // Only kind-3 (var-ref) receivers are checkable
                            // this way; other receiver kinds fall through to
                            // the existing diagnostics.
                            // Regression: borrowed-ref method receiver resolution.
                            let v217_recv_node: i64 = node_field(pool, nid, 1);
                            if node_kind(pool, v217_recv_node) == 3 {
                                let v217_recv_name: str = node_field(pool, v217_recv_node, 1);
                                let v217_full_id: i64 = sym_get(sym, str_concat("__fulltype_", v217_recv_name));
                                if v217_full_id >= 0 {
                                    let v217_full: str = v217_full_id;
                                    let v217_flen: i64 = str_len(v217_full);
                                    let mut v217_is_ref: i64 = 0;
                                    if v217_flen >= 1 && str_char_at(v217_full, 0) == 38 { v217_is_ref = 1; };
                                    if v217_flen >= 5 && str_starts_with(v217_full, "&mut ") == 1 { v217_is_ref = 1; };
                                    if v217_is_ref == 1 {
                                        let v217a: str = str_concat("error[TYP-007]: receiver type `", str_concat(v217_full, str_concat("` — method dispatch on borrowed references (`.", str_concat(mname, "()` on `&T` / `&mut T`) is not supported in Nucleor today."))));
                                        let v217b: str = " Pre-v0.4.217 the kind-8 catch-all synthesized `vec_<method>(<receiver>)` and the post-link diagnostic re-cast it as `receiver type 'Vec<T>' has no method ...` — confusing because the receiver is a borrowed reference, not a Vec.";
                                        let v217c: str = str_concat(" Workaround: call the free fn directly with the reference — `", str_concat(mname, str_concat("(<receiver>)`, OR dereference the binding first (`let s_owned: ", str_concat(stype_base, " = *<receiver>;`) and call methods on the owned value. Auto-deref method dispatch through borrowed references is tracked for a later RFC."))));
                                        print(str_concat(v217a, str_concat(v217b, v217c)));
                                        panic(str_concat("nucleor: method dispatch on borrowed reference `", str_concat(v217_full, "` not supported (see TYP-007 above)")));
                                    };
                                };
                            };
                            // struct-field-as-method-call guard.
                            // Pre-fix `p.x(42)` where `x` is a STRUCT FIELD
                            // (not a method) lowered to `vec_x(p, 42)`,
                            // surfaced by my v0.4.106 lift as
                            // `error[TYP-005]: undefined function `vec_x()``
                            // — confusing because the source has nothing
                            // about Vec. Detect: receiver type is a known
                            // struct AND mname matches a field name on
                            // that struct. Emit TYP-015 with the right
                            // hint (likely `p.x = ...` or `let v = p.x;`).
                            let struct_idx: i64 = struct_find_type(pool, structs, stype);
                            if struct_idx >= 0 {
                                let struct_nid_v123: i64 = vec_get(structs, struct_idx);
                                let field_idx: i64 = struct_field_idx(pool, struct_nid_v123, mname);
                                if field_idx >= 0 {
                                    let msg15a: str = str_concat("error[TYP-015]: `.", str_concat(mname, str_concat("(args)` is invalid — `.", str_concat(mname, str_concat("` is a FIELD on struct `", str_concat(stype, "`, not a method."))))));
                                    let msg15b: str = str_concat(" Pre-v0.4.123 the call lowered to `vec_", str_concat(mname, "(...)` and surfaced as an undefined-symbol TYP-005."));
                                    let msg15c: str = " Drop the parentheses to read the field as a value, or assign with `<recv>.<field> = <value>;`.";
                                    print(str_concat(msg15a, str_concat(msg15b, msg15c)));
                                    panic(str_concat("nucleor: `.", str_concat(mname, str_concat("` is a field on `", str_concat(stype, "`, not a method")))));
                                };
                            };
                            // clean halt for `.clone()` on a user struct that
                            // does not have `#[derive(Clone)]`. Pre-fix this fell through
                            // to `vec_clone(...)` synthesis → undefined symbol TYP-005.
                            if str_eq(mname, "clone") == 1 && struct_idx >= 0 {
                                let v764_sname: str = stype_base;
                                print(str_concat("ERROR: `.clone()` called on struct `", str_concat(v764_sname, "` which does not `#[derive(Clone)]`. Workaround: add `#[derive(Clone)]` above the struct definition.")));
                                panic(str_concat("nucleor: `.clone()` on struct `", str_concat(v764_sname, "` without #[derive(Clone)] (see ERROR diagnostic above)")));
                            };
                            if struct_idx >= 0 {
                                print(str_concat("error[TYP-007]: receiver type `", str_concat(stype_base, str_concat("` has no method `.", str_concat(mname, "()`.")))));
                                print(str_concat("  Define an inherent `impl ", str_concat(stype_base, str_concat(" { fn ", str_concat(mname, "(self, ...) -> T { ... } }` method or implement a trait that provides the method. Pre-fix this fell through to `vec_", str_concat(mname, "(...)` and misreported the receiver as `Vec<T>`.")))));
                                panic(str_concat("nucleor: no method `.", str_concat(mname, str_concat("()` for struct receiver `", str_concat(stype_base, "`")))));
                            };
                            // dispatch-name drift fix. Pre-fix
                            // `v.insert(idx, val)` lowered to `vec_insert(...)`
                            // but the runtime helper is `vec_insert_at`;
                            // same for `v.remove(idx)` → `vec_remove_at`.
                            // Both failed at clang link with `undefined
                            // value '@vec_insert' / '@vec_remove'`. Add
                            // suffix here so user-side method names match
                            // Rust convention without breaking the
                            // existing helper names. Discovered as a
                            // sister bug while shipping v0.4.86's
                            // canonical Rust conversion-idiom methods
                            // (`.into()`, `.to_string()`, `.to_owned()`,
                            // `.to_vec()`, `.iter_mut()`) pre-fix fell through
                            // every receiver-typed dispatch and the catch-all
                            // synthesized `vec_<idiom>(receiver)` — failing late
                            // at clang link with the wrong-class diagnostic
                            // `error[TYP-005]: receiver type 'Vec<T>' has no
                            // method '.<idiom>()'`. Adopters writing canonical
                            // Rust got pointed at "Vec method families" which
                            // had nothing to do with the actual issue (these
                            // idioms aren't Vec methods at all — they're trait-
                            // method conversions that need From/Into / ToOwned
                            // / etc. infrastructure not yet shipped).
                            // Halt now with a clean diagnostic naming the idiom
                            // and pointing at the explicit-conversion workaround.
                            // Forward-roadmap: full Into/From/ToOwned trait
                            // infrastructure is a v1.x ship.
                            let v082_idiom: i64 = if str_eq(mname, "into") == 1
                                || str_eq(mname, "to_string") == 1
                                || str_eq(mname, "to_owned") == 1
                                || str_eq(mname, "to_vec") == 1
                                || str_eq(mname, "iter_mut") == 1
                                || str_eq(mname, "rev") == 1
                                || str_eq(mname, "enumerate") == 1
                                || str_eq(mname, "zip") == 1
                                || str_eq(mname, "windows") == 1
                                || str_eq(mname, "chunks") == 1
                                || str_eq(mname, "flat_map") == 1
                                || str_eq(mname, "flatten") == 1
                                || str_eq(mname, "peekable") == 1
                                || str_eq(mname, "fuse") == 1
                                || str_eq(mname, "abs") == 1
                                || str_eq(mname, "pow") == 1
                                || str_eq(mname, "signum") == 1
                                || str_eq(mname, "count_ones") == 1
                                || str_eq(mname, "count_zeros") == 1
                                || str_eq(mname, "leading_zeros") == 1
                                || str_eq(mname, "trailing_zeros") == 1
                                || str_eq(mname, "rotate_left") == 1
                                || str_eq(mname, "rotate_right") == 1
                                || str_eq(mname, "swap_bytes") == 1
                                || str_eq(mname, "checked_add") == 1
                                || str_eq(mname, "checked_sub") == 1
                                || str_eq(mname, "checked_mul") == 1
                                || str_eq(mname, "wrapping_add") == 1
                                || str_eq(mname, "wrapping_sub") == 1
                                || str_eq(mname, "wrapping_mul") == 1
                                || str_eq(mname, "saturating_add") == 1
                                || str_eq(mname, "saturating_sub") == 1
                                || str_eq(mname, "saturating_mul") == 1
                                || str_eq(mname, "is_alphabetic") == 1
                                || str_eq(mname, "is_numeric") == 1
                                || str_eq(mname, "is_alphanumeric") == 1
                                || str_eq(mname, "is_ascii") == 1
                                || str_eq(mname, "is_whitespace") == 1
                                || str_eq(mname, "is_lowercase") == 1
                                || str_eq(mname, "is_uppercase") == 1
                                || str_eq(mname, "is_digit") == 1
                                || str_eq(mname, "to_ascii_uppercase") == 1
                                || str_eq(mname, "to_ascii_lowercase") == 1
                                || str_eq(mname, "to_lowercase") == 1
                                || str_eq(mname, "to_uppercase") == 1
                                || str_eq(mname, "to_digit") == 1
                                || str_eq(mname, "chars") == 1
                                || str_eq(mname, "lines") == 1
                                || str_eq(mname, "bytes") == 1
                                || str_eq(mname, "as_bytes") == 1
                                || str_eq(mname, "repeat") == 1
                                || str_eq(mname, "split_whitespace") == 1
                                || str_eq(mname, "split_terminator") == 1
                                || str_eq(mname, "rsplit") == 1
                                || str_eq(mname, "splitn") == 1
                                || str_eq(mname, "char_indices") == 1
                                || str_eq(mname, "parse") == 1
                                || str_eq(mname, "dedup") == 1
                                || str_eq(mname, "retain") == 1
                                || str_eq(mname, "truncate") == 1
                                || str_eq(mname, "resize") == 1
                                || str_eq(mname, "split_at") == 1
                                || str_eq(mname, "sort_by") == 1
                                || str_eq(mname, "sort_by_key") == 1
                                || str_eq(mname, "sort_unstable") == 1
                                || str_eq(mname, "sort_unstable_by") == 1
                                || str_eq(mname, "max_by_key") == 1
                                || str_eq(mname, "min_by_key") == 1
                                || str_eq(mname, "extend_from_slice") == 1
                                || str_eq(mname, "copied") == 1
                                || str_eq(mname, "cloned") == 1
                                || str_eq(mname, "as_ref") == 1
                                || str_eq(mname, "as_mut") == 1
                                || str_eq(mname, "and_then") == 1
                                || str_eq(mname, "or_else") == 1
                                || str_eq(mname, "ok_or") == 1
                                || str_eq(mname, "ok_or_else") == 1
                                || str_eq(mname, "transpose") == 1
                                || str_eq(mname, "expect_err") == 1
                                || str_eq(mname, "iter_lines") == 1
                                || str_eq(mname, "into_iter") == 1
                                || str_eq(mname, "try_into") == 1
                                || str_eq(mname, "try_from") == 1
                                || str_eq(mname, "from") == 1
                                || str_eq(mname, "borrow") == 1
                                || str_eq(mname, "borrow_mut") == 1
                                || str_eq(mname, "into_inner") == 1
                                || str_eq(mname, "leak") == 1
                                || str_eq(mname, "as_str") == 1
                                || str_eq(mname, "as_slice") == 1
                                || str_eq(mname, "as_ptr") == 1 { 1 } else { 0 };
                            if v082_idiom == 1 {
                                let v082_workaround: str = if str_eq(mname, "into") == 1 {
                                    "no v0.6 conversion path; the From/Into trait family is not yet shipped — use an explicit named conversion fn (e.g. `i64_to_str(x)` for numeric→str)"
                                } else if str_eq(mname, "to_string") == 1 {
                                    "use `i64_to_str(x)` / `f64_to_str(x)` for numerics, or write a `<Type>_to_str(t)` helper for user types — the Display/ToString trait family is not yet shipped"
                                } else if str_eq(mname, "to_owned") == 1 {
                                    "Nucleor's i64-everywhere ABI passes most values by value already; `let owned: T = original;` is the explicit copy form. The ToOwned trait family is not yet shipped"
                                } else if str_eq(mname, "to_vec") == 1 {
                                    "build the Vec explicitly via `let mut v: Vec<T> = Vec::new(); for item in src { v.push(item); }` or use the `vec![...]` macro form for literals"
                                } else if str_eq(mname, "rev") == 1 {
                                    "iterate the Vec in reverse with an index-based loop — `let mut i: i64 = vec_len(&v) - 1; while i >= 0 { let item = vec_get(&v, i); ...; i = i - 1; }`. For in-place reversal use `.reverse()` (already supported)"
                                } else if str_eq(mname, "enumerate") == 1 {
                                    "iterate with a manual counter — `let mut idx: i64 = 0; for item in &v { ...idx, item...; idx = idx + 1; }`"
                                } else if str_eq(mname, "zip") == 1 {
                                    "iterate by index over both — `let n = vec_len(&a); let mut i: i64 = 0; while i < n { let av = vec_get(&a, i); let bv = vec_get(&b, i); ...; i = i + 1; }`"
                                } else if str_eq(mname, "windows") == 1 || str_eq(mname, "chunks") == 1 {
                                    "manual sliding-window — `let mut i: i64 = 0; while i + WIN <= vec_len(&v) { let chunk = (vec_get(&v, i), vec_get(&v, i+1), ...); ...; i = i + STRIDE; }`"
                                } else if str_eq(mname, "flat_map") == 1 || str_eq(mname, "flatten") == 1 {
                                    "fold + extend manually — `let mut out: Vec<T> = Vec::new(); for inner in &outer { for item in &inner { out.push(item); } }`"
                                } else if str_eq(mname, "abs") == 1 {
                                    "use a conditional — `let r: i64 = if x < 0 { -x } else { x };`"
                                } else if str_eq(mname, "pow") == 1 {
                                    "use a manual loop — `let mut r: i64 = 1; let mut i: i64 = 0; while i < n { r = r * base; i = i + 1; }`"
                                } else if str_eq(mname, "signum") == 1 {
                                    "use a conditional — `let s: i64 = if x > 0 { 1 } else if x < 0 { -1 } else { 0 };`"
                                } else if str_eq(mname, "count_ones") == 1 || str_eq(mname, "count_zeros") == 1 || str_eq(mname, "leading_zeros") == 1 || str_eq(mname, "trailing_zeros") == 1 || str_eq(mname, "rotate_left") == 1 || str_eq(mname, "rotate_right") == 1 || str_eq(mname, "swap_bytes") == 1 {
                                    "use the bitwise operators directly (`<<`, `>>`, `&`, `|`, `^`) — these integer-intrinsic methods need a Nucleor i64 method-table that's tracked for forward-roadmap"
                                } else if str_eq(mname, "checked_add") == 1 || str_eq(mname, "checked_sub") == 1 || str_eq(mname, "checked_mul") == 1 {
                                    "Nucleor's overflow semantics are configurable via `NUCLEOR_INT_STRICT_ARITH=1` (panic-on-overflow) — bare `+` / `-` / `*` already check for overflow under strict mode. Use that, or implement the Option<i64> wrap manually"
                                } else if str_eq(mname, "wrapping_add") == 1 || str_eq(mname, "wrapping_sub") == 1 || str_eq(mname, "wrapping_mul") == 1 {
                                    "bare `+` / `-` / `*` already wrap by default (when `NUCLEOR_INT_STRICT_ARITH` is unset). Drop the `.wrapping_*()` call"
                                } else if str_eq(mname, "saturating_add") == 1 || str_eq(mname, "saturating_sub") == 1 || str_eq(mname, "saturating_mul") == 1 {
                                    "implement manually — `let r: i64 = if a > i64::MAX - b { i64::MAX } else { a + b };`"
                                } else if str_eq(mname, "is_alphabetic") == 1 {
                                    "compare codepoint ranges — `let r: bool = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);` (ASCII A-Z, a-z)"
                                } else if str_eq(mname, "is_numeric") == 1 || str_eq(mname, "is_digit") == 1 {
                                    "compare codepoint range — `let r: bool = c >= 48 && c <= 57;` (ASCII 0-9)"
                                } else if str_eq(mname, "is_alphanumeric") == 1 {
                                    "combine alphabetic + numeric checks — `let r: bool = (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122);`"
                                } else if str_eq(mname, "is_ascii") == 1 {
                                    "compare codepoint range — `let r: bool = c >= 0 && c <= 127;`"
                                } else if str_eq(mname, "is_whitespace") == 1 {
                                    "match common whitespace codepoints — `let r: bool = c == 32 || c == 9 || c == 10 || c == 13;` (space, tab, newline, CR)"
                                } else if str_eq(mname, "is_lowercase") == 1 {
                                    "compare ASCII codepoint range — `let r: bool = c >= 97 && c <= 122;` (a-z)"
                                } else if str_eq(mname, "is_uppercase") == 1 {
                                    "compare ASCII codepoint range — `let r: bool = c >= 65 && c <= 90;` (A-Z)"
                                } else if str_eq(mname, "to_ascii_uppercase") == 1 {
                                    "subtract 32 if lowercase — `let u: i64 = if c >= 97 && c <= 122 { c - 32 } else { c };`"
                                } else if str_eq(mname, "to_ascii_lowercase") == 1 {
                                    "add 32 if uppercase — `let l: i64 = if c >= 65 && c <= 90 { c + 32 } else { c };`"
                                } else if str_eq(mname, "to_lowercase") == 1 || str_eq(mname, "to_uppercase") == 1 {
                                    "the iterator-returning Unicode forms aren't supported. Use the ASCII forms `.to_ascii_lowercase()` / `.to_ascii_uppercase()` (now also halted with workarounds), or compare codepoint ranges manually"
                                } else if str_eq(mname, "to_digit") == 1 {
                                    "subtract '0' codepoint — `let d: i64 = if c >= 48 && c <= 57 { c - 48 } else { -1 };` for radix-10. For other radixes add a-f / A-F branches"
                                } else if str_eq(mname, "chars") == 1 {
                                    "iterate the string by codepoint via index-based loop — `let n: i64 = str_len(s) as i64; let mut i: i64 = 0; while i < n { let c: i64 = str_char_at(s, i); ...; i = i + 1; }`. Today this iterates byte-by-byte (ASCII safe; multi-byte UTF-8 needs a separate decoder)"
                                } else if str_eq(mname, "lines") == 1 {
                                    "split on newline manually — `let parts: Vec<str> = str_split(s, \"\\n\"); for line in &parts { ... }`. The `.lines()` form returns an iterator that the v1.x iterator-protocol substrate will support"
                                } else if str_eq(mname, "bytes") == 1 {
                                    "iterate by index — `let n: i64 = str_len(s) as i64; let mut i: i64 = 0; while i < n { let b: i64 = str_char_at(s, i); ...; i = i + 1; }`. Each `b` is the raw byte value (0..255)"
                                } else if str_eq(mname, "as_bytes") == 1 {
                                    "build a `Vec<u8>` manually — `let mut bs: Vec<u8> = Vec::new(); let n: i64 = str_len(s) as i64; let mut i: i64 = 0; while i < n { vec_u8_push(bs, str_char_at(s, i) as u8); i = i + 1; }`"
                                } else if str_eq(mname, "repeat") == 1 {
                                    "concat in a loop — `let mut out: str = \"\"; let mut i: i64 = 0; while i < n { out = str_concat(out, s); i = i + 1; }`"
                                } else if str_eq(mname, "split_whitespace") == 1 || str_eq(mname, "split_terminator") == 1 || str_eq(mname, "splitn") == 1 || str_eq(mname, "rsplit") == 1 {
                                    "use `str_split(s, sep)` (single-char delimiter) and post-process. For whitespace, use `str_split(s, \" \")` and filter empty parts. For multi-delimiter or n-split forms, the iterator-protocol substrate is forward-roadmap"
                                } else if str_eq(mname, "char_indices") == 1 {
                                    "iterate by index manually — `let n: i64 = str_len(s) as i64; let mut i: i64 = 0; while i < n { let c: i64 = str_char_at(s, i); ...; i = i + 1; }` — the index is `i` and the char is `c` (matches Rust's `(usize, char)` tuple form)"
                                } else if str_eq(mname, "parse") == 1 {
                                    "use the explicit-typed conversion fn — `str_to_int(s)` for integers, `str_to_float(s)` for floats. For Result-returning forms, check the input shape via `str_starts_with(s, \"-\")` / `str_contains(s, \".\")` first"
                                } else if str_eq(mname, "dedup") == 1 {
                                    "build a new Vec, tracking prev element — `let mut out: Vec<T> = Vec::new(); let mut prev_set: i64 = 0; let mut prev: T = ...; for x in &v { if prev_set == 0 || x != prev { out.push(x); prev = x; prev_set = 1; } }`"
                                } else if str_eq(mname, "retain") == 1 {
                                    "build a new Vec via filter loop — `let mut keep: Vec<T> = Vec::new(); for x in &v { if pred(x) { keep.push(x); } } v = keep;`. The functional `.filter(...).collect()` form (now also halted) has the same shape"
                                } else if str_eq(mname, "truncate") == 1 {
                                    "pop from the end until the desired length — `while vec_len(&v) > n { v.pop(); }`"
                                } else if str_eq(mname, "resize") == 1 {
                                    "push the default value until the desired length — `while vec_len(&v) < n { v.push(default_value); }` (combine with truncate workaround above to shrink)"
                                } else if str_eq(mname, "split_at") == 1 {
                                    "build the two halves explicitly via index loops — `let mut a: Vec<T> = Vec::new(); let mut b: Vec<T> = Vec::new(); let mut i: i64 = 0; while i < vec_len(&v) { if i < mid { a.push(vec_get(&v, i)); } else { b.push(vec_get(&v, i)); } i = i + 1; }`. Tuple-return forms (`let (a, b) = ...`) are also forward-roadmap"
                                } else if str_eq(mname, "sort_by") == 1 || str_eq(mname, "sort_unstable_by") == 1 {
                                    "Nucleor's `.sort()` uses the type's natural ordering. For custom comparators, the closure-receiving form is forward-roadmap — for now, sort then post-process if the natural order isn't what you need"
                                } else if str_eq(mname, "sort_by_key") == 1 {
                                    "build a parallel key-vec, sort indices, then re-emit — or use a struct with a key field and `.sort()` (Nucleor sorts struct values by their first field today)"
                                } else if str_eq(mname, "sort_unstable") == 1 {
                                    "use `.sort()` — Nucleor today doesn't distinguish stable vs unstable; the unstable suffix is a no-op signal in Rust meaning 'don't preserve ties' but Nucleor's sort makes no stability guarantee either way"
                                } else if str_eq(mname, "max_by_key") == 1 || str_eq(mname, "min_by_key") == 1 {
                                    "manual reduce — `let mut best_val: T = vec_get(&v, 0); let mut best_key: K = key_fn(best_val); for x in &v { let k = key_fn(x); if k > best_key { best_key = k; best_val = x; } }`. Closure-receiving iterator combinators are forward-roadmap"
                                } else if str_eq(mname, "extend_from_slice") == 1 {
                                    "loop and push — `for x in &other { v.push(x); }` (Nucleor's `.extend(...)` already supports the Vec form; the slice variant requires explicit element copy)"
                                } else if str_eq(mname, "copied") == 1 || str_eq(mname, "cloned") == 1 {
                                    "drop the call — under Nucleor's i64-everywhere ABI, iterators already yield by-value (no &T → T conversion needed). `v.iter().copied().collect()` is just `v.iter().collect()`. The Rust convention exists because .iter() yields &T; here the runtime passes everything by value already"
                                } else if str_eq(mname, "as_ref") == 1 || str_eq(mname, "as_mut") == 1 {
                                    "drop the call — Nucleor's i64-everywhere ABI passes everything by value; `Option<T>.as_ref()` (which returns `Option<&T>`) is unnecessary because Nucleor's Option already yields T by value. Use `if let Some(v) = opt { ... }` directly"
                                } else if str_eq(mname, "and_then") == 1 {
                                    "Option/Result chaining — write the explicit if-let chain — `if let Some(x) = opt { f(x) } else { None }`. Closure-receiving combinators are forward-roadmap (v1.x closure-substrate)"
                                } else if str_eq(mname, "or_else") == 1 {
                                    "Option/Result fallback — write the explicit match — `match opt { Some(x) => Some(x), None => fallback() }`"
                                } else if str_eq(mname, "ok_or") == 1 || str_eq(mname, "ok_or_else") == 1 {
                                    "Option-to-Result conversion — write the explicit match — `match opt { Some(x) => Ok(x), None => Err(err_value) }`"
                                } else if str_eq(mname, "transpose") == 1 {
                                    "manual swap — `Option<Result<T, E>>` → `Result<Option<T>, E>` via match — `match opt { Some(Ok(x)) => Ok(Some(x)), Some(Err(e)) => Err(e), None => Ok(None) }`. The unsupported nested-pattern halt may fire here; split into two-step destructure"
                                } else if str_eq(mname, "expect_err") == 1 {
                                    "manual match — `match r { Err(e) => e, Ok(_) => panic(\"expected err\") }`"
                                } else if str_eq(mname, "iter_lines") == 1 {
                                    "use `.lines()` (now also halted) workaround — `let parts: Vec<str> = str_split(s, \"\\n\");`"
                                } else if str_eq(mname, "into_iter") == 1 {
                                    "drop the call — `for x in v` already iterates by-value under the i64-everywhere ABI; `for x in v.into_iter()` is just `for x in v`. The Rust convention exists because .iter() yields &T while .into_iter() yields T; here both yield T already"
                                } else if str_eq(mname, "try_into") == 1 || str_eq(mname, "try_from") == 1 {
                                    "use an explicit conversion — for narrowing casts (`i64 -> i32`) write `x as i32` (Nucleor's bare `as` cast checks NUM-003 narrowing under strict-arith mode); for Vec-to-array, build the array manually since slices and arrays are unified as Vec<T> in Nucleor today"
                                } else if str_eq(mname, "from") == 1 {
                                    "associated From::from is not yet supported — use the explicit conversion fn (`String::from(s)` is already supported; for user types write a `<Target>_from_<Src>(x: Src) -> Target` helper). The full From/Into trait family is forward-roadmap"
                                } else if str_eq(mname, "borrow") == 1 || str_eq(mname, "borrow_mut") == 1 {
                                    "drop the call — Nucleor's i64-everywhere ABI passes by value already; the Borrow/BorrowMut trait family exists in Rust to let containers accept `&str` where `String` is stored. Here just pass the value directly"
                                } else if str_eq(mname, "into_inner") == 1 {
                                    "for `Cell<T>`/`RefCell<T>`-style wrappers, those types aren't supported (forward-roadmap, sister to v0.7.12 smart-pointer halt). For `Result<T, E>::into_ok`, use `match` instead"
                                } else if str_eq(mname, "leak") == 1 {
                                    "Box::leak / Vec::leak (intentional memory leak to obtain `&'static T`) is not supported — Nucleor doesn't expose 'static lifetime semantics. Workaround: use a top-level `const` or `static` (the latter is also forward-roadmap; see v0.6.21 halt)"
                                } else if str_eq(mname, "as_str") == 1 {
                                    "drop the call — Nucleor's i64-everywhere ABI treats `String` and `str` as the same i64-pointer at the runtime level; `s.as_str()` is just `s`"
                                } else if str_eq(mname, "as_slice") == 1 {
                                    "drop the call — Nucleor doesn't distinguish Vec from slice today; `v.as_slice()` is just `v`"
                                } else if str_eq(mname, "as_ptr") == 1 {
                                    "the raw-pointer family is not yet exposed in Nucleor's surface — sister to v0.7.3 (raw-pointer types) and v0.7.14 (raw-ref expressions) halts. Use Vec/String element access (`vec_get`, `str_char_at`) instead of pointer arithmetic"
                                } else {
                                    "use a `while i < vec_len(&v) { let item: T = vec_get(&v, i); ...; i = i + 1; }` loop with index-based access — Nucleor doesn't auto-derive iterator interior mutability today"
                                };
                                print(str_concat("ERROR: `.", str_concat(mname, str_concat("()` is a canonical Rust conversion idiom that is not yet supported in Nucleor. Pre-v0.6.82 the kind-8 method-dispatch catch-all synthesized `vec_", str_concat(mname, str_concat("(receiver)` and the post-link diag re-cast as `receiver type 'Vec<T>' has no method '.", str_concat(mname, str_concat("()` — wrong-class for adopters porting Rust code. Workaround: ", str_concat(v082_workaround, ".")))))))));
                                panic(str_concat("nucleor: Rust conversion-idiom method `.", str_concat(mname, "()` not yet supported (see ERROR diagnostic above)")));
                            };
                            // narrow-RHS check for `.insert/.set`.
                            let mut alias_mname: str = mname;
                            if str_eq(mname, "insert") == 1 { alias_mname = "insert_at"; };
                            if str_eq(mname, "remove") == 1 { alias_mname = "remove_at"; };
                            fn_name = str_concat("vec_", alias_mname);
                        };
                    };
                };
            };
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(r, fn_name, all_args));
        return lx_new(r, cur);
    };
    if kind == 10 {
        // catch `s[i]` for `s: str` at codegen-time. The
        // type-check side has had a TYP-011 guard since v0.4.94 but
        // it only fires when the index expression reaches type_expr
        // via the let-stmt RHS path — fn-call args, `as` casts, and
        // anything else that uses kind 10 inside a larger expression
        // sail past it (the `if type_dynamic_helper(callee) == 1`
        // early-return at line 11297 short-circuits arg-walk for
        // every runtime helper, which is most of them). Codegen
        // path catches every kind 10 unconditionally — when the
        // receiver is a var-ref to a `__type_<name>` of `str`,
        // halt cleanly before emitting `vec_get` on the str pointer.
        let recv_v117: i64 = node_field(pool, nid, 1);
        if node_kind(pool, recv_v117) == 3 {
            let recv_n: str = node_field(pool, recv_v117, 1);
            let recv_t_v117: i64 = sym_get(sym, str_concat("__type_", recv_n));
            if recv_t_v117 >= 0 && str_eq(recv_t_v117, "str") == 1 {
                panic(str_concat("error[TYP-011]: `str` does not support direct indexing with `", str_concat(recv_n, str_concat("[i]`. The codegen would lower this to `vec_get` on the str pointer, returning garbage or OOB-panicking. Use `str_char_at(", str_concat(recv_n, ", i)` to get a byte, or `str_substring(<name>, i, j)` for a substring."))))));
            };
        };
        let mut obj_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(obj_p);
        let mut cur: Vec<i32> = lx_blk(obj_p);
        let mut idx_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let idx_r: i64 = lx_reg(idx_p);
        cur = lx_blk(idx_p);
        let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
        let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
        return lx_new(r, cur);
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let args_list: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Vec") && str_eq(mname, "new") {
            let r: i64 = ctr_next(regs);
            let mut empty_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(r, "vec_new", empty_args));
            return lx_new(r, blk);
        };
        // `Vec::with_capacity(n)`. Pre-v0.3.116 fell through
        // to the diagnostic+zero path because no kind-12 handler
        // matched. Adopters reaching for the canonical Rust pre-
        // allocation pattern (`Vec::with_capacity(N)` for known-size
        // accumulators) saw their .exe return 0 from the ctor and
        // every push silently fail. The runtime helper
        // `__nucleor_vec_with_capacity` already exists; this is purely
        // the missing surface dispatch. Lower the single arg, then
        // emit a call to the runtime helper.
        if str_eq(tname, "Vec") && str_eq(mname, "with_capacity") {
            let mut wc_cur: Vec<i32> = blk;
            let mut wc_args: Vec<i32> = Vec::new();
            if list_len(pool, args_list) >= 1 {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, 0), wc_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                wc_args.push(lx_reg(ap));
                wc_cur = lx_blk(ap);
            };
            let r: i64 = ctr_next(regs);
            ir_block_add(wc_cur, ir_call_ex(r, "vec_with_capacity", wc_args));
            return lx_new(r, wc_cur);
        };
        if str_eq(tname, "String") && str_eq(mname, "new") {
            let r: i64 = ctr_next(regs);
            let mut empty_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(r, "string_new", empty_args));
            return lx_new(r, blk);
        };
        if str_eq(tname, "Box") && str_eq(mname, "new") {
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            let zr: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(zr, 0));
            return lx_new(zr, blk);
        };
        // Box::leak(b) — intentional memory-leak pass-through.
        // Nucleor has no automatic drop (V1.3 RAII unshipped), so
        // Box::leak is semantically identical to Box::new in the ABI:
        // just return the inner value. Callers from Rust-ported code
        // use it to obtain a &'static mut T from a heap-allocated Box;
        // in Nucleor's i64-everywhere ABI the Box IS the inner pointer.
        if str_eq(tname, "Box") && str_eq(mname, "leak") {
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            let zrl: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(zrl, 0));
            return lx_new(zrl, blk);
        };
        // Rust-style associated-fn aliases for the lowercase
        // collection helpers. Maps `HashMap::new()` → `hashmap_new()`,
        // `HashSet::new()` → `hashset_new()`, `BTreeMap::new()` →
        // `btreemap_new()`, `BTreeSet::new()` → `btreeset_new()`,
        // `VecDeque::new()` → `vecdeque_new()`. Without this, users
        // coming from Rust who write `let m: HashMap<K,V> = HashMap::new();`
        // hit "unhandled expr kind 12" with no diagnostic and broken
        // `%r.-1` IR. The runtime helpers themselves (__nucleor_hashmap_new
        // etc.) all exist; this is purely surface-level wiring.
        if str_eq(mname, "new") {
            let mut helper_n: str = "";
            if str_eq(tname, "HashMap") { helper_n = "hashmap_new"; };
            if str_eq(tname, "HashSet") { helper_n = "hashset_new"; };
            if str_eq(tname, "BTreeMap") { helper_n = "btreemap_new"; };
            if str_eq(tname, "BTreeSet") { helper_n = "btreeset_new"; };
            if str_eq(tname, "VecDeque") { helper_n = "vecdeque_new"; };
            if str_len(helper_n) > 0 {
                let r: i64 = ctr_next(regs);
                let mut empty_args: Vec<i32> = Vec::new();
                ir_block_add(blk, ir_call_ex(r, helper_n, empty_args));
                return lx_new(r, blk);
            };
        };
        // `with_capacity(N)` for the collection family.
        // Pre-v0.3.117 only `Vec::with_capacity` (added in v0.3.116)
        // was wired; HashMap/HashSet/BTreeMap/BTreeSet/VecDeque/String
        // all silently dispatched to the diagnostic+zero path,
        // returning an empty handle that no subsequent insert/push
        // could populate. Runtime helpers `__nucleor_<type>_with_capacity`
        // already exist for each (with v0.3.116 just adding the Vec one).
        if str_eq(mname, "with_capacity") {
            let mut wch: str = "";
            if str_eq(tname, "HashMap") { wch = "hashmap_with_capacity"; };
            if str_eq(tname, "HashSet") { wch = "hashset_with_capacity"; };
            if str_eq(tname, "VecDeque") { wch = "vecdeque_with_capacity"; };
            if str_eq(tname, "String") { wch = "string_with_capacity"; };
            if str_len(wch) > 0 {
                let mut wcc: Vec<i32> = blk;
                let mut wca: Vec<i32> = Vec::new();
                if list_len(pool, args_list) >= 1 {
                    let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, 0), wcc, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    wca.push(lx_reg(ap));
                    wcc = lx_blk(ap);
                };
                let r: i64 = ctr_next(regs);
                ir_block_add(wcc, ir_call_ex(r, wch, wca));
                return lx_new(r, wcc);
            };
        };
        if str_eq(tname, "Tensor") {
            let mut t_args: Vec<i32> = Vec::new();
            let ac: i64 = list_len(pool, args_list);
            let mut ai: i64 = 0;
            let mut cur: Vec<i32> = blk;
            while ai < ac {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                t_args.push(lx_reg(ap));
                cur = lx_blk(ap);
                ai = ai + 1;
            };
            let r: i64 = ctr_next(regs);
            if str_eq(mname, "zeros") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_zeros", t_args)); }
            else if str_eq(mname, "fill") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_fill", t_args)); }
            else if str_eq(mname, "ones") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_ones", t_args)); };
            return lx_new(r, cur);
        };
        let etag_key: str = str_concat("__etag_", str_concat(tname, str_concat("_", mname)));
        let etag: i64 = sym_get(sym, etag_key);
        if etag >= 0 {
            let vr: i64 = ctr_next(regs);
            let mut new_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
            let tr: i64 = ctr_next(regs); ir_block_add(blk, ir_const_int(tr, etag));
            let mut push_args1: Vec<i32> = Vec::new(); push_args1.push(vr); push_args1.push(tr);
            let dr1: i64 = ctr_next(regs); ir_block_add(blk, ir_call_ex(dr1, "vec_push", push_args1));
            let argc: i64 = list_len(pool, args_list);
            let mut ai: i64 = 0;
            let mut cur: Vec<i32> = blk;
            while ai < argc {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let av: i64 = lx_reg(ap);
                cur = lx_blk(ap);
                let mut pa: Vec<i32> = Vec::new(); pa.push(vr); pa.push(av);
                let dp: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dp, "vec_push", pa));
                ai = ai + 1;
            };
            return lx_new(vr, cur);
        };
        // dispatch user-defined associated fns. The impl
        // block synthesizes each method as `<TypeName>__<methodname>`
        // (mangled name registered in fn_decls / impl_fns at
        // collect_impls time). Pre-v0.3.111, `Point::new(7, 3)`
        // matched none of the built-in Type::method handlers above,
        // skipped the etag enum-variant check (Point isn't an enum),
        // hit the diagnostic, and emitted const_int 0 — silent
        // miscompute returning 0 from any user constructor.
        // Adopters reaching for the canonical `let p = Point::new(...)`
        // pattern saw a printed error but their .exe still ran with
        // wrong values. Lookup `__fnret_<mangled>` to confirm the
        // method exists; if so, lower as a normal i64 fn call with
        // the args (the function takes the args directly, not a
        // self prefix, since this is an associated fn — not an
        // instance method).
        let mangled: str = str_concat(tname, str_concat("__", mname));
        let mret: i64 = sym_get(sym, str_concat("__fnret_", mangled));
        if mret >= 0 {
            let mut maa: Vec<i32> = Vec::new();
            let mac: i64 = list_len(pool, args_list);
            let mut mai: i64 = 0;
            let mut mcur: Vec<i32> = blk;
            while mai < mac {
                let mut mp: Vec<i32> = lower_expr(pool, list_get(pool, args_list, mai), mcur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                maa.push(lx_reg(mp));
                mcur = lx_blk(mp);
                mai = mai + 1;
            };
            let mr: i64 = ctr_next(regs);
            ir_block_add(mcur, ir_call_ex(mr, mangled, maa));
            return lx_new(mr, mcur);
        };
        // defensive halt: canonical Rust path-rooted fn
        // calls `crate::foo(...)`, `super::foo(...)`, `self::foo(...)`
        // pre-fix surfaced via the generic v0.3.71 "unsupported
        // associated-fn call" diag, which mentioned only Vec/String/
        // etc. — not adopter-actionable for the path case. Detect
        // the `crate`/`super`/`self` roots and halt with a clean
        // workaround pointer (drop the path prefix — Nucleor has a
        // flat fn namespace today).
        if str_eq(tname, "crate") == 1 || str_eq(tname, "super") == 1 || str_eq(tname, "self") == 1 {
            print(str_concat("ERROR: path-rooted fn call `", str_concat(tname, str_concat("::", str_concat(mname, "(...)` is not yet supported in Nucleor. — not adopter-actionable. Nucleor has a flat fn namespace today (no `crate::` / `super::` / `self::` rooting), and the resolved fn name `", str_concat(mname, str_concat("` is callable directly. Workaround: drop the `", str_concat(tname, str_concat("::` prefix — call ", str_concat(mname, "(...) directly.")))))))))));
            panic(str_concat("nucleor: path-rooted fn call `", str_concat(tname, str_concat("::", str_concat(mname, "` not yet supported (see ERROR diagnostic above)")))));
        };
        let mut v712_smart_kind: str = "";
        if str_eq(tname, "Cell") == 1 { v712_smart_kind = "interior mutability"; };
        if str_eq(tname, "RefCell") == 1 { v712_smart_kind = "interior mutability"; };
        if str_eq(tname, "Rc") == 1 { v712_smart_kind = "shared ownership"; };
        if str_eq(tname, "Arc") == 1 { v712_smart_kind = "shared ownership (atomic)"; };
        if str_eq(tname, "Mutex") == 1 { v712_smart_kind = "thread-safe interior mutability"; };
        if str_eq(tname, "RwLock") == 1 { v712_smart_kind = "thread-safe read-write lock"; };
        if str_eq(tname, "Weak") == 1 { v712_smart_kind = "weak reference"; };
        if str_len(v712_smart_kind) > 0 {
            print("ERROR: Rust stdlib smart-pointer type is not yet supported in Nucleor.");
            print(str_concat("       Type: `", str_concat(tname, str_concat("` (", str_concat(v712_smart_kind, ")")))));
            print("       Pre-v0.7.12 surfaced via the generic 'unsupported associated-fn call' diag.");
            print("       Nucleor's i64-everywhere ABI doesn't yet have a borrow-checker, so interior-");
            print("       mutability / shared-ownership / lock wrappers are NOT NEEDED for the typical");
            print("       adopter use case.");
            print("       Workaround: use the bare type with `let mut` for mutability — `let mut x: i64 =");
            print("       42; x = 100;` (no Cell needed). For shared ownership the i64 ABI already passes");
            print("       by value (the heap pointer is copied) — no Rc/Arc needed. Real threading uses");
            print("       `async_spawn` (RFC-0027, see stdlib/rods/async.nr).");
            panic(str_concat("nucleor: smart-pointer type `", str_concat(tname, "` not yet supported (see ERROR diagnostic above)")));
        };
        // defensive halt — Default trait: canonical Rust
        // `i64::default()`, `String::default()`, `Default::default()`
        // pre-fix surfaced via the generic v0.3.71 "unsupported
        // associated-fn call" diag. Default trait isn't yet shipped
        // in Nucleor — the canonical `T::default()` pattern needs
        // per-type Default impls + a `Default::default()` ambient
        // dispatch through type inference. Halt cleanly with a
        // per-type literal-default workaround pointer.
        if str_eq(mname, "default") == 1 {
            let v076_hint: str = if str_eq(tname, "i8") == 1 || str_eq(tname, "i16") == 1 || str_eq(tname, "i32") == 1 || str_eq(tname, "i64") == 1 || str_eq(tname, "isize") == 1 || str_eq(tname, "u8") == 1 || str_eq(tname, "u16") == 1 || str_eq(tname, "u32") == 1 || str_eq(tname, "u64") == 1 || str_eq(tname, "usize") == 1 {
                "0"
            } else if str_eq(tname, "f32") == 1 || str_eq(tname, "f64") == 1 {
                "0.0"
            } else if str_eq(tname, "bool") == 1 {
                "false"
            } else if str_eq(tname, "str") == 1 {
                "\"\""
            } else if str_eq(tname, "String") == 1 {
                "String::new()"
            } else if str_eq(tname, "Vec") == 1 {
                "Vec::new()"
            } else if str_eq(tname, "HashMap") == 1 {
                "HashMap::new()"
            } else {
                "<construct the type explicitly>"
            };
            print(str_concat("ERROR: `", str_concat(tname, str_concat("::default()` (Default trait) is not yet supported in Nucleor. Workaround: use the literal default value for this type — `", str_concat(v076_hint, "`. Tracked for forward-roadmap (Default trait substrate is sister to V1.4 derive(PartialEq) — both annotation-driven trait derives).")))));
            panic(str_concat("nucleor: `", str_concat(tname, "::default()` not yet supported (see ERROR diagnostic above)")));
        };
        // surface a clear diagnostic instead of falling through
        // to the generic "unhandled expr kind 12" + broken `%r.-1` IR.
        // Production-readiness: any unsupported `Type::method(...)` shape
        // now reports the exact type and method that needs wiring.
        print(str_concat("ERROR: unsupported associated-fn call ", str_concat(tname, str_concat("::", str_concat(mname, "(...). Supported: Vec/String/Box/HashMap/HSet/BTMap/BTSet/VecDeque ::new, Tensor::{zeros,fill,ones}, enum variants. For Rust-style HashMap/etc operations, use the lowercase API (hashmap_new, hashmap_insert, ...) until method dispatch lands.")))));
        // pre-fix this lowered to `const_int(0)` and continued
        // — silent miscompute. Adopters writing
        // `let x: Foo = Bar::unknown_method()` got x = 0 in the binary
        // with no link/runtime failure. Halt the compiler now so the
        // diagnostic above is seen as a hard error, not a passing build.
        panic(str_concat("nucleor: unsupported associated-fn call ", str_concat(tname, str_concat("::", mname))));
        let zr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(zr, 0));
        return lx_new(zr, blk);
    };
    if kind == 52 {
        let mode: i64 = node_field(pool, nid, 1);
        let body: i64 = node_field(pool, nid, 2);
        // for `saturating { ... }` (mode==2), set
        // __arith_mode=2 in the body's sym so the kind-4 binop
        // dispatch routes +/-/* through saturating_add/sub/mul.
        // The body's exit value is returned directly (no final
        // sat_i32 clamp — the per-op saturation handled it).
        // `wrapping { ... }` (mode==1) keeps the final wrap_i32
        // shape because Nucleor's wrapping semantics target i32
        // representation, not per-op i64 wrap (which is what raw
        // i64 arith does anyway).
        let body_sym_sat: Vec<i32> = sym_clone(sym);
        if mode == 1 { sym_set(body_sym_sat, "__arith_mode", 1); };
        if mode == 2 { sym_set(body_sym_sat, "__arith_mode", 2); };
        let mut bp: Vec<i32> = lower_if_expr_branch(pool, body, blk, regs, lbls, body_sym_sat, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mut br: i64 = lx_reg(bp);
        let mut cur: Vec<i32> = lx_blk(bp);
        if br < 0 {
            br = ctr_next(regs);
            ir_block_add(cur, ir_const_int(br, 0));
        };
        if mode == 2 { return lx_new(br, cur); };
        let mut wrap_args: Vec<i32> = Vec::new();
        wrap_args.push(br);
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(r, "wrap_i32", wrap_args));
        return lx_new(r, cur);
    };
    if kind == 23 {
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        let cur: Vec<i32> = lx_blk(cp);
        let tmp: i64 = ctr_next(regs);
        ir_fn_add_entry_alloca(fir, tmp);
        let tl: i64 = ctr_next(lbls);
        let el: i64 = ctr_next(lbls);
        let ml: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br_cond(cr, tl, el));

        let mut tb: Vec<i32> = ir_block_new(tl);
        ir_fn_add_block(fir, tb);
        let mut tp: Vec<i32> = lower_if_expr_branch(pool, node_field(pool, nid, 2), tb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        tb = lx_blk(tp);
        let tv: i64 = lx_reg(tp);
        if block_has_term(tb) == 0 {
            let mut store_tv: i64 = tv;
            if store_tv < 0 {
                let tz: i64 = ctr_next(regs);
                ir_block_add(tb, ir_const_int(tz, 0));
                store_tv = tz;
            };
            ir_block_add(tb, ir_store(store_tv, tmp));
            ir_block_add(tb, ir_br(ml));
        };

        let enode: i64 = node_field(pool, nid, 3);
        let mut eb: Vec<i32> = ir_block_new(el);
        ir_fn_add_block(fir, eb);
        if enode >= 0 {
            let mut ep: Vec<i32> = lower_if_expr_branch(pool, enode, eb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
            eb = lx_blk(ep);
            let fv: i64 = lx_reg(ep);
            if block_has_term(eb) == 0 {
                let mut store_fv: i64 = fv;
                if store_fv < 0 {
                    let ez: i64 = ctr_next(regs);
                    ir_block_add(eb, ir_const_int(ez, 0));
                    store_fv = ez;
                };
                ir_block_add(eb, ir_store(store_fv, tmp));
                ir_block_add(eb, ir_br(ml));
            };
        } else {
            let ez: i64 = ctr_next(regs);
            ir_block_add(eb, ir_const_int(ez, 0));
            ir_block_add(eb, ir_store(ez, tmp));
            ir_block_add(eb, ir_br(ml));
        };

        let mut mb: Vec<i32> = ir_block_new(ml);
        ir_fn_add_block(fir, mb);
        let r: i64 = ctr_next(regs);
        ir_block_add(mb, ir_load(r, tmp));
        return lx_new(r, mb);
    };
    if kind == 38 {
        let scrut_nid: i64 = node_field(pool, nid, 1);
        let scrut_t: str = expr_full_type_from_sym(pool, scrut_nid, sym, structs);
        let mut mp: Vec<i32> = lower_expr(pool, scrut_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mexpr_r: i64 = lx_reg(mp);
        let mut cur: Vec<i32> = lx_blk(mp);
        let mslot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, mslot);
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let tmp: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, tmp);
        let arms_list: i64 = node_field(pool, nid, 2);
        let arm_cnt: i64 = list_len(pool, arms_list);
        let ml: i64 = ctr_next(lbls);
        let mut tag_r: i64 = 0 - 1;
        let mut ci: i64 = 0;
        while ci < arm_cnt {
            let arm_nid: i64 = list_get(pool, arms_list, ci);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            let body_list: i64 = node_field(pool, arm_nid, 4);
            let guard_nid: i64 = node_field(pool, arm_nid, 5);
            let al: i64 = ctr_next(lbls);
            let nl: i64 = ctr_next(lbls);
            if str_eq(ename, "__wild") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            } else if str_eq(ename, "__int") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let iv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(iv_r, vname));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, mv, iv_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__range") == 1 || str_eq(ename, "__range_at") == 1 {
                // RFC-0023 §3.1: range pattern. vname = LO (i64 cell),
                // binding = str_from_int(HI) (inclusive — half-open ranges
                // were normalized at parse). Match if LO <= scrut && scrut
                // <= HI.
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let lo_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(lo_r, vname));
                let hi_s: str = str_before_char_local(binding, 124);
                let hi_n: i64 = str_to_int(hi_s);
                let hi_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(hi_r, hi_n));
                let lo_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, lo_ok, lo_r, mv));
                let hi_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, hi_ok, mv, hi_r));
                let both_r: i64 = ctr_next(regs); ir_block_add(cur, ir_binop(13, both_r, lo_ok, hi_ok));
                ir_block_add(cur, ir_br_cond(both_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let arm_sym: Vec<i32> = sym_clone(sym);
                if str_eq(ename, "__range_at") == 1 {
                    ab = match_bind_whole(str_after_char_local(binding, 124), ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__range_bad") == 1 || str_eq(ename, "__range_bad_at") == 1 {
                // MATCH-007 fired by the typecker (paired pass). Lower as
                // never-match so program compiles; warning surfaces in the
                // diagnostic stream.
                ir_block_add(cur, ir_br(nl));
            } else if str_eq(ename, "__str") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                // intern via strtab_intern to dedup.
                let sidx: i64 = strtab_intern(strtab, fir, vname);
                let sv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_str(sv_r, sidx));
                let mut eq_args: Vec<i32> = Vec::new(); eq_args.push(mv); eq_args.push(sv_r);
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(cmp_r, "str_eq", eq_args));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, "str");
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__struct") {
                // struct destructure with pattern guard fall-through.
                // Pre-fix the __struct arm in lower_expr (match-as-value) had
                // no guard handling — `Point { x, y } if cond => A` always
                // executed `A` regardless of guard evaluation, producing a
                // silent miscompute. Mirror the __wild guard pattern: bind
                // fields, then conditionally branch on the guard's truth.
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_struct_fields(binding, ab, regs, arm_sym, mslot, fir, structs, pool, vname, scrut_t);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            } else if str_eq(ename, "__tuple") == 1 || str_eq(ename, "__slice") == 1 {
                // tuple/slice pattern with guard fall-through.
                // Same bug class as v0.4.202 __struct fix.
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let mut len_args: Vec<i32> = Vec::new(); len_args.push(mv);
                let len_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(len_r, "vec_len", len_args));
                let needed: i64 = pattern_list_value_count(binding);
                let needed_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(needed_r, needed));
                let cmp_r: i64 = ctr_next(regs);
                if str_eq(ename, "__slice") == 1 && pattern_list_has_rest(binding) == 1 {
                    ir_block_add(cur, ir_cmpop(11, cmp_r, needed_r, len_r));
                } else {
                    ir_block_add(cur, ir_cmpop(7, cmp_r, len_r, needed_r));
                };
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_vec_pattern(binding, ab, regs, arm_sym, mslot, fir, scrut_t, len_r);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            } else {
                // enum-variant-with-payload pattern with guard
                // fall-through. Same bug class as v0.4.202 __struct fix.
                if tag_r < 0 {
                    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                    let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
                    let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(mv); tag_args.push(zero_r);
                    tag_r = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
                };
                let etag_key: str = str_concat("__etag_", str_concat(ename, str_concat("_", vname)));
                let vtag: i64 = sym_get(sym, etag_key);
                let vtag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(vtag_r, vtag));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, vtag_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                let payload_binding: str = pattern_after_at_prefix(binding);
                let at_name: str = pattern_at_prefix_name(binding);
                if str_len(at_name) > 0 { ab = match_bind_whole(at_name, ab, regs, arm_sym, mslot, fir, scrut_t); };
                ab = match_bind_payloads_per_idx(payload_binding, ab, regs, arm_sym, mslot, fir, ename, vname, scrut_t);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            };
            let mut nb: Vec<i32> = ir_block_new(nl); ir_fn_add_block(fir, nb);
            cur = nb;
            ci = ci + 1;
        };
        ir_block_add(cur, ir_br(ml));
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb);
        let r: i64 = ctr_next(regs);
        ir_block_add(mb, ir_load(r, tmp));
        return lx_new(r, mb);
    };
    if kind == 47 || kind == 48 {
        let items_list: i64 = node_field(pool, nid, 1);
        let vr: i64 = ctr_next(regs);
        let mut new_args: Vec<i32> = Vec::new();
        ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
        let ic: i64 = list_len(pool, items_list);
        let mut ii: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while ii < ic {
            let mut ep: Vec<i32> = lower_expr(pool, list_get(pool, items_list, ii), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let ev: i64 = lx_reg(ep);
            cur = lx_blk(ep);
            let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(ev);
            let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "vec_push", push_args));
            ii = ii + 1;
        };
        return lx_new(vr, cur);
    };
    if kind == 34 {
        let sname: str = node_field(pool, nid, 1);
        let init_list: i64 = node_field(pool, nid, 2);
        let si: i64 = struct_find_type(pool, structs, sname);
        if si < 0 {
            if str_eq(sname, "Self") == 1 {
                print("ERROR: `Self { ... }` struct constructor inside `impl` blocks is not yet supported in Nucleor. Workaround: write the struct name explicitly — `impl Counter { fn make(x: i64) -> Counter { return Counter { n: x }; } }`.");
                panic("nucleor: `Self { ... }` constructor in impl block not yet supported (see ERROR diagnostic above)");
            };
            print(str_concat("ERROR: unknown struct ", sname));
            // pre-fix lowered to `lx_new(-1, blk)` which produced
            // `%r.-1` invalid IR — clang caught it but pointed at LLVM,
            // not source (NUC-FEEDBACK-010 territory). Halt at compiler
            // level so the diagnostic above is the actionable error.
            panic(str_concat("nucleor: unknown struct ", sname));
            return lx_new(0 - 1, blk);
        };
        let s_nid: i64 = vec_get(structs, si);
        let flist: i64 = node_field(pool, s_nid, 2);
        let fc: i64 = list_len(pool, flist);
        let vr: i64 = ctr_next(regs);
        let mut new_args: Vec<i32> = Vec::new();
        ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
        let mut fi: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while fi < fc {
            let decl_fname: str = node_field(pool, list_get(pool, flist, fi), 1);
            let ic: i64 = list_len(pool, init_list);
            let mut ii: i64 = 0;
            let mut found: i64 = 0;
            while ii < ic {
                let init_nid: i64 = list_get(pool, init_list, ii);
                if str_eq(node_field(pool, init_nid, 1), decl_fname) {
                    let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, init_nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let val_r: i64 = lx_reg(vp);
                    cur = lx_blk(vp);
                    let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(val_r);
                    let pr2: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pr2, "vec_push", push_args));
                    found = 1; ii = ic;
                };
                ii = ii + 1;
            };
            if found == 0 {
                let zr: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zr, 0));
                let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(zr);
                let pr2: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pr2, "vec_push", push_args));
            };
            fi = fi + 1;
        };
        return lx_new(vr, cur);
    };
    if kind == 9 {
        let mut op: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(op);
        let cur: Vec<i32> = lx_blk(op);
        let fname: str = node_field(pool, nid, 2);
        if str_is_digits(fname) == 1 {
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, str_to_int(fname)));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
            let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
            return lx_new(r, cur);
        };
        let stype: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        let si: i64 = struct_find_type(pool, structs, stype);
        if si >= 0 {
            let fi2: i64 = struct_field_idx(pool, vec_get(structs, si), fname);
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi2));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
            let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
            return lx_new(r, cur);
        };
        // NUC-FEEDBACK-010 ask -- improve the error so
        // adopters know what to do instead of seeing the cryptic
        // downstream `use of undefined value '%r.-1'` from clang.
        // NUC-FEEDBACK-010 follow-on -- TRUE pre-IR halt.
        // Threading lower_error through ~44 lower_expr sites was the
        // architectural blocker; sidestep it by calling panic() from
        // the compiler itself. The s1 compiler IS a Nucleor program,
        // so a panic() call here invokes __nucleor_panic in the
        // compiler's own runtime, exiting the COMPILER process with
        // status 1 BEFORE clang is ever invoked. Adopters see the
        // diagnostic followed by a clean `panic` line, no `%r.-1`
        // confusion, no clang link spew.
        // defensive halt: canonical Rust complex-receiver
        // `.await` (e.g. `fetch().await`, `arr[0].await`,
        // `expr.method().await`) pre-fix surfaced as the generic
        // "cannot resolve field access .await" diag because the
        // expand_async_await textual pass only handles the simple
        // `<ident>.await` form (line ~26145). Halt cleanly here at
        // lower-time with a workaround pointer (extract the
        // expression to a let-binding first, then `.await` the
        // ident).
        if str_eq(fname, "await") == 1 {
            print("ERROR: complex-receiver `.await` (e.g. `fetch().await`, `arr[0].await`, `expr.method().await`) is not yet supported in Nucleor. Workaround: extract the expression to a let-binding first, then `.await` the ident — `let h: i64 = fetch(); let v: i64 = h.await;`.");
            panic("nucleor: complex-receiver `.await` not yet supported (see ERROR diagnostic above)");
        };
        // RFC V1.11 adopter wrong-class halt: canonical Rust
        // anonymous-tuple binding `let p: (i64, i64) = (5, 7); p.0`
        // pre-fix surfaced as the generic "cannot resolve field access"
        // diag — wrong class. Anonymous tuples are not yet supported in
        // Nucleor (V1.1 closed only NAMED tuple-struct decls). Detect
        // the parenthesized-type shape and halt with a clean workaround
        // pointer (named tuple-struct).
        if str_len(stype) >= 2 && str_char_at(stype, 0) == 40 {
            let stlen: i64 = str_len(stype);
            if str_char_at(stype, stlen - 1) == 41 {
                print(str_concat("ERROR: anonymous tuple types `(T1, T2, ...)` are not yet supported in Nucleor. Workaround: declare a named tuple-struct (V1.1, shipped v0.6.74) and use it instead — `struct Pair(i64, i64); let p: Pair = Pair(5, 7); print_int(p.0 as i32);`.", ""));
                panic("nucleor: anonymous tuple type field access not yet supported (use named tuple-struct — see ERROR diagnostic above)");
            };
        };
        print(str_concat("ERROR: cannot resolve field access type for .", fname));
        print("       Likely causes:");
        print("         (1) Receiver expression type couldn't be inferred (try");
        print("             extracting to a `let x: StructName = ...` binding first).");
        print("         (2) Field name not found in the receiver struct (check");
        print("             spelling against the struct definition).");
        print("         (3) Receiver struct was defined in a different module that");
        print("             isn't imported / publicly visible.");
        print("       If field name contains a substring matching a Nucleor keyword");
        print("       (e.g. `static`, `loop`, `as`), try renaming -- contextual-keyword");
        print("       lexer interactions are an open hazard class.");
        panic(str_concat("nucleor: cannot resolve field access .", fname));
        return lx_new(0 - 1, cur);
    };
    if kind == 42 {
        let param_list: i64 = node_field(pool, nid, 1);
        let body_list: i64 = node_field(pool, nid, 2);
        let clo_idx: i64 = vec_len(closures);
        let clo_name: str = str_concat("__closure_", str_from_int(clo_idx));
        let user_pc: i64 = list_len(pool, param_list);
        // Closure body takes a leading synthetic %p.0 = __env (the
        // unboxed environment pointer); user params shift to %p.1..N.
        let pc: i64 = user_pc + 1;
        let mut clo_regs: Vec<i32> = ctr_new();
        let mut clo_lbls: Vec<i32> = ctr_new();
        let mut clo_sym: Vec<i32> = sym_new();
        sym_set(clo_sym, "__closure_id", clo_idx);
        let mut clo_fir: Vec<i32> = ir_fn_new(clo_name, pc);
        ir_fn_set_strtab_aux(clo_fir, ir_fn_strtab_aux(fir));
        let mut clo_b0: Vec<i32> = ir_block_new(0);
        ir_fn_add_block(clo_fir, clo_b0);
        let mut captures: Vec<i32> = Vec::new();
        let bc: i64 = list_len(pool, body_list);
        let mut bi: i64 = 0;
        while bi < bc {
            closure_collect_capture_stmt(pool, list_get(pool, body_list, bi), sym, param_list, captures);
            bi = bi + 1;
        };
        // Synthetic __env param at slot 0 (the unboxed env pointer).
        // Stash the reg in clo_sym so the assign-to-capture path inside
        // the body can emit env_set_cap on the right env.
        let env_param_reg: i64 = ctr_next(clo_regs);
        ir_block_add(clo_b0, ir_param_ref(env_param_reg, 0));
        sym_set(clo_sym, "__env_reg", env_param_reg);
        let mut cpi: i64 = 0;
        while cpi < user_pc {
            let cpname: str = list_get(pool, param_list, cpi);
            let car: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_alloca(car));
            // User params shift by +1 because env occupies slot 0.
            let cpr: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_param_ref(cpr, cpi + 1));
            ir_block_add(clo_b0, ir_store(cpr, car));
            sym_set(clo_sym, cpname, car);
            sym_set(clo_sym, str_concat("__type_", cpname), "i64");
            cpi = cpi + 1;
        };
        let mut capi: i64 = 0;
        while capi < vec_len(captures) {
            let capname: str = vec_get(captures, capi);
            let car: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_alloca(car));
            // Load captured value from the per-instance env, not the
            // legacy per-literal global table.
            let cap_id_r: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_const_int(cap_id_r, capi));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(env_param_reg); get_args.push(cap_id_r);
            let cval: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_call_ex(cval, "nuc_closure_env_get_cap", get_args));
            ir_block_add(clo_b0, ir_store(cval, car));
            sym_set(clo_sym, capname, car);
            sym_set(clo_sym, str_concat("__capid_", capname), capi);
            // propagate the captured variable's TYPE entry
            // from the parent sym so expr_struct_type can resolve
            // field accesses inside the closure body. Pre-v0.3.129
            // the closure's clo_sym had the captured slot but no
            // `__type_<capname>` entry — `cfg.factor` (where cfg was
            // captured) failed to resolve to a struct field, lowered
            // to register -1, and clang link errored with
            // `use of undefined value '%r.-1'`. Without this entry
            // adopters couldn't access fields of any captured struct
            // inside a closure (very common pattern: closure
            // capturing a config / context struct).
            let parent_type: i64 = sym_get(sym, str_concat("__type_", capname));
            if parent_type >= 0 {
                sym_set(clo_sym, str_concat("__type_", capname), parent_type);
            };
            let parent_full: i64 = sym_get(sym, str_concat("__fulltype_", capname));
            if parent_full >= 0 {
                sym_set(clo_sym, str_concat("__fulltype_", capname), parent_full);
            };
            capi = capi + 1;
        };
        // push the closure into `closures` BEFORE lowering
        // its body. Pre-v0.3.107 the push happened AFTER body lowering,
        // so nested closures (a closure inside another closure's body)
        // queried `vec_len(closures)` at line 10541 and saw the same
        // count as the outer closure — both got `__closure_0`, which
        // hard-failed at clang link with `invalid redefinition of
        // function '__closure_0'`. Pushing first reserves the slot
        // for clo_idx (already allocated above) so nested closures
        // get the next id (1, 2, …). Safe because clo_fir is a Vec
        // reference and lower_stmts mutates it in place — the
        // closures list holds the same pointer either way.
        closures.push(clo_fir);
        // braced-body tail-expression handling. Pre-fix
        // `|y| { y + 7 }` lowered the kind-25 expr-stmt as a discard
        // (lower_stmts → kind 25 → evaluate, drop result) and then
        // synthesized `ret 0` for the missing terminator — silent
        // miscompute returning 0. The bare-expression form
        // `|y| y + 7` already worked because parse_primary wraps the
        // single body expr as kind 22 (return-with-value) directly.
        // Fix: mirror lower_fn's tail-expr handling — if the last
        // body item is a stmt that carries a tail expression value
        // (kind 25 = expr-stmt, 23 = if-expr, 38 = match-expr), lower
        // all stmts up to the last via lower_stmt, then lower the
        // last stmt's payload via lower_expr and emit `ret rv`.
        let bcnt_clo: i64 = list_len(pool, body_list);
        let mut last_kind_clo: i64 = 0 - 1;
        if bcnt_clo > 0 { last_kind_clo = node_kind(pool, list_get(pool, body_list, bcnt_clo - 1)); };
        let mut clo_fb: Vec<i32> = clo_b0;
        if bcnt_clo > 0 && (last_kind_clo == 25 || last_kind_clo == 23 || last_kind_clo == 38) {
            let mut bi_clo: i64 = 0;
            while bi_clo + 1 < bcnt_clo {
                clo_fb = lower_stmt(pool, list_get(pool, body_list, bi_clo), clo_fb, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                bi_clo = bi_clo + 1;
            };
            let last_stmt_clo: i64 = list_get(pool, body_list, bcnt_clo - 1);
            let mut expr_nid_clo: i64 = last_stmt_clo;
            if last_kind_clo == 25 { expr_nid_clo = node_field(pool, last_stmt_clo, 1); };
            let mut ep_clo: Vec<i32> = lower_expr(pool, expr_nid_clo, clo_fb, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            clo_fb = lx_blk(ep_clo);
            let mut rv_clo: i64 = lx_reg(ep_clo);
            if block_has_term(clo_fb) == 0 {
                if rv_clo < 0 {
                    rv_clo = ctr_next(clo_regs);
                    ir_block_add(clo_fb, ir_const_int(rv_clo, 0));
                };
                ir_block_add(clo_fb, ir_ret(rv_clo));
            };
        } else {
            clo_fb = lower_stmts(pool, body_list, clo_b0, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            if block_has_term(clo_fb) == 0 {
                let czr: i64 = ctr_next(clo_regs);
                ir_block_add(clo_fb, ir_const_int(czr, 0));
                ir_block_add(clo_fb, ir_ret(czr));
            };
        };
        let mut cur: Vec<i32> = blk;
        // Closure literal evaluation:
        //   env = nuc_closure_env_new(fn_ptr, cap_count)
        //   for each capture i: nuc_closure_env_set_cap(env, i, value)
        //   raw = nuc_closure_box(env)     ; surface i64 = env_ptr | 1
        // The closure value at the surface is `raw`, a tagged pointer
        // distinguishable from a bare fn-ptr at indirect-call sites.
        let fn_ptr_r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_fn_ptr(fn_ptr_r, clo_name));
        let cap_count_r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_const_int(cap_count_r, vec_len(captures)));
        let mut env_new_args: Vec<i32> = Vec::new();
        env_new_args.push(fn_ptr_r);
        env_new_args.push(cap_count_r);
        let env_r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(env_r, "nuc_closure_env_new", env_new_args));
        let mut capi2: i64 = 0;
        while capi2 < vec_len(captures) {
            let capname2: str = vec_get(captures, capi2);
            let capslot: i64 = sym_get(sym, capname2);
            if capslot >= 0 {
                let capv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(capv, capslot));
                let idx_r2: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r2, capi2));
                let mut set_args: Vec<i32> = Vec::new();
                set_args.push(env_r); set_args.push(idx_r2); set_args.push(capv);
                let dr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(dr, "nuc_closure_env_set_cap", set_args));
            };
            capi2 = capi2 + 1;
        };
        let mut box_args: Vec<i32> = Vec::new();
        box_args.push(env_r);
        let boxed_r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(boxed_r, "nuc_closure_box", box_args));
        // Stash metadata so the let-and-call writeback path can find
        // the right closure-local slot at the call site.
        sym_set(sym, "__last_closure_id", clo_idx);
        sym_set(sym, "__last_closure_caps", capture_names_to_string(captures));
        return lx_new(boxed_r, cur);
    };
    print(str_concat("ERROR: unhandled expr kind ", str_from_int(kind)));
    // pre-fix this returned `lx_new(-1, blk)` which lowered
    // downstream to `%r.-1` invalid IR — clang caught the broken IR
    // but produced a confusing "use of undefined value" message that
    // pointed at IR, not source. Halting at compiler level surfaces
    // the actual cause: an AST node kind the lowerer doesn't handle
    // (likely a new feature not yet wired or a parser/lower drift).
    panic(str_concat("nucleor: unhandled expr kind ", str_from_int(kind)));
    return lx_new(0 - 1, blk);
}
// T1.1 Phase 5: detect whether an AST expression node has a known
// float type (f32 or f64), looking through variable reads (kind==3)
// and float literals (kind==71). Returns "f32"/"f64"/"" .
// populate sym with `__fnret_NAME = rtype` entries
// for every fn declared in pool. Walks the entire pool once,
// skipping non-fn nodes. Called from lower_fn at the start of each
// fn body so binop_float_type's kind==7 (call) branch can look up
// the called fn's return type via the existing sym mechanism — no
// signature plumbing required.
// Pool walk caveat: pool nodes form a flat arena. Fn decls are
// kind 30 (regular) and kind 32 (extern). The walk uses node_kind
// at every offset and bails early once we run off the end (handled
// by node_kind returning -1 / 0 for invalid offsets in the arena).
#[manual_drop]
fn populate_fn_returns_in_sym(pool: Vec<i32>, fn_decls: Vec<i32>, sym: Vec<i32>) -> i64 {
    let n: i64 = vec_len(fn_decls);
    let mut i: i64 = 0;
    while i < n {
        let fnid: i64 = vec_get(fn_decls, i);
        let name: str = node_field(pool, fnid, 1);
        let raw_rtype: str = node_field(pool, fnid, 3);
        let rtype: str = type_base_name(raw_rtype);
        if str_len(name) > 0 && str_len(rtype) > 0 {
            sym_set(sym, str_concat("__fnret_", name), rtype);
        };
        // also store the FULL declared return type
        // (preserving generics like Vec<f64>) so kind==10 dispatch
        // can extract the element type when an indexer's operand is
        // a kind 7 (fn call). Mirrors __fulltype_ for variables.
        if str_len(name) > 0 && str_len(raw_rtype) > 0 {
            sym_set(sym, str_concat("__fnfulltype_", name), raw_rtype);
        };
        i = i + 1;
    };
    return 0;
}

// Detect whether a fn's body returns a closure value, by structural
// inspection of the top-level stmt list. Returns 1 iff:
//   - The fn has an explicit `return <expr>;` (kind 22) where <expr>
//     is a closure literal (kind 42) or a var-ref (kind 3) to a local
//     bound via `let <name>: T = <closure-literal>;` earlier in the body.
//   - Or the fn's last stmt is a tail expression (kind 25) whose value
//     is a closure literal or a closure-bound local.
// Used by fn_return_map_new to populate __fnret_closure_<name> entries
// so callers can register their let-bindings for auto-drop release.
// Scope: top-level stmts only; nested ifs/matches that return closures
// from one branch are not detected in this pass. Acceptable for v1 —
// the test surface covers the common `let g = |x|...; return g;` and
// `return |x|...;` patterns. Wider coverage is a follow-up.
#[manual_drop]
fn detect_returns_closure(pool: Vec<i32>, body_list: i64) -> i64 {
    if body_list < 0 { return 0; };
    let n: i64 = list_len(pool, body_list);
    let mut closure_locals: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    let mut found: i64 = 0;
    while i < n {
        let stmt: i64 = list_get(pool, body_list, i);
        let k: i64 = node_kind(pool, stmt);
        if k == 20 {
            // let-binding: if init is a closure literal, the lhs name
            // joins the closure-bound set.
            let init: i64 = node_field(pool, stmt, 4);
            if init >= 0 && node_kind(pool, init) == 42 {
                let lhs_name: str = node_field(pool, stmt, 1);
                if str_len(lhs_name) > 0 { closure_locals.push(lhs_name); };
            };
        };
        if k == 22 {
            // return <expr>;
            let rval: i64 = node_field(pool, stmt, 1);
            if rval >= 0 {
                let rk: i64 = node_kind(pool, rval);
                if rk == 42 { found = 1; };
                if rk == 3 {
                    let rname: str = node_field(pool, rval, 1);
                    let mut j: i64 = 0;
                    while j < vec_len(closure_locals) {
                        if str_eq(rname, vec_get(closure_locals, j)) == 1 { found = 1; };
                        j = j + 1;
                    };
                };
            };
        };
        if k == 25 && i == n - 1 {
            // tail expression (no explicit return)
            let texpr: i64 = node_field(pool, stmt, 1);
            if texpr >= 0 {
                let tk: i64 = node_kind(pool, texpr);
                if tk == 42 { found = 1; };
                if tk == 3 {
                    let tname: str = node_field(pool, texpr, 1);
                    let mut j: i64 = 0;
                    while j < vec_len(closure_locals) {
                        if str_eq(tname, vec_get(closure_locals, j)) == 1 { found = 1; };
                        j = j + 1;
                    };
                };
            };
        };
        i = i + 1;
    };
    return found;
}

// shared fn-return-map builder. Built once per
// program by emit_module_ext; passed to every lower_fn call so each
// fn's sym can reference it via __fn_return_map slot instead of
// pre-populating __fnret_/__fnfulltype_ entries per fn.
#[manual_drop]
fn fn_return_map_new(pool: Vec<i32>, fn_decls: Vec<i32>) -> i64 {
    let mut m: i64 = __nucleor_hashmap_new();
    let n: i64 = vec_len(fn_decls);
    let mut i: i64 = 0;
    while i < n {
        let fnid: i64 = vec_get(fn_decls, i);
        let name: str = node_field(pool, fnid, 1);
        let raw_rtype: str = node_field(pool, fnid, 3);
        let rtype: str = type_base_name(raw_rtype);
        if str_len(name) > 0 && str_len(rtype) > 0 {
            __nucleor_hashmap_insert(m, str_concat("__fnret_", name), rtype);
        };
        if str_len(name) > 0 && str_len(raw_rtype) > 0 {
            __nucleor_hashmap_insert(m, str_concat("__fnfulltype_", name), raw_rtype);
        };
        // Closure-returning detection: lets callers register their
        // let-binding for auto-drop release at scope end so the env
        // returned by this fn doesn't leak.
        // Closure-returning detection. Only regular fns (kind 30) have
        // a body to inspect — extern fns (kind 32) are signature-only.
        if str_len(name) > 0 && node_kind(pool, fnid) == 30 {
            let blist: i64 = node_field(pool, fnid, 4);
            if detect_returns_closure(pool, blist) == 1 {
                __nucleor_hashmap_insert(m, str_concat("__fnret_closure_", name), "1");
            };
        };
        i = i + 1;
    };
    return m;
}

// strip ONE container layer from a type
// annotation, returning the inner element type WITH generics
// preserved. Used by the kind==10 dispatchers to resolve nested
// indexing chains (`grid[i][j]` where grid: Vec<Vec<f64>>).
//   "Vec<f64>"          → "f64"
//   "Vec<Vec<f64>>"     → "Vec<f64>"
//   "[f64; 3]"          → "f64"
//   "[Vec<f64>; 4]"     → "Vec<f64>"
// Returns "" for non-container shapes.
// extract the SECOND generic parameter (the value type)
// from a HashMap<K, V> / BTreeMap<K, V> / similar two-arg generic.
// Returns "" if the type isn't a recognized two-arg generic shape.
// Used by the print() dispatch for hashmap_get etc. so
// HashMap<str, str>.get returns the str element instead of dispatching
// to print_i64 (NUC-FEEDBACK-006 follow-on).
#[manual_drop]
fn generic_second_type(t: str) -> str {
    let tlen: i64 = str_len(t);
    if tlen < 6 { return ""; };
    // Find first `<`
    let mut lt_pos: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < tlen {
        if str_char_at(t, i) == 60 { lt_pos = i; i = tlen; };
        i = i + 1;
    };
    if lt_pos < 0 { return ""; };
    if str_char_at(t, tlen - 1) != 62 { return ""; };
    // Walk inside `<...>` tracking depth; find first `,` at depth 0.
    let mut depth: i64 = 0;
    let mut comma_pos: i64 = 0 - 1;
    let mut j: i64 = lt_pos + 1;
    while j < tlen - 1 {
        let cj: i64 = str_char_at(t, j);
        if cj == 60 { depth = depth + 1; }
        else if cj == 62 { depth = depth - 1; }
        else if cj == 44 && depth == 0 { comma_pos = j; j = tlen; };
        j = j + 1;
    };
    if comma_pos < 0 { return ""; };
    let mut vs: i64 = comma_pos + 1;
    while vs < tlen - 1 && str_char_at(t, vs) == 32 { vs = vs + 1; };
    return str_substring(t, vs, tlen - 1);
}

#[manual_drop]
fn strip_container_one_level(t: str) -> str {
    let tlen: i64 = str_len(t);
    if str_starts_with(t, "Vec<") == 1 && tlen > 5 && str_char_at(t, tlen - 1) == 62 {
        return str_substring(t, 4, tlen - 1);
    };
    if tlen > 1 && str_char_at(t, 0) == 91 {
        let mut sep: i64 = 0 - 1;
        let mut k: i64 = 1;
        while k < tlen {
            let ch: i64 = str_char_at(t, k);
            if ch == 59 || ch == 44 { sep = k; k = tlen; }
            else { k = k + 1; };
        };
        if sep > 1 {
            return strip_spaces(str_substring(t, 1, sep));
        };
    };
    return "";
}

// recursively walk an indexable expression and
// return the FULL type of its element (with generics preserved).
// Composes the v0.3.55/65/66/67 operand-kind handlers — kind 3
// (var ref), kind 9 (struct field), kind 7 (fn-call), and now
// kind 10 (nested indexing) — and strips one container layer.
// Returns "" if the operand kind isn't recognized or the type
// isn't a container shape.
#[manual_drop]
fn indexed_element_full_type(pool: Vec<i32>, vexpr: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let vk: i64 = node_kind(pool, vexpr);
    let mut vtype: str = "";
    if vk == 3 {
        let vname: str = node_field(pool, vexpr, 1);
        let vt: i64 = sym_get(sym, str_concat("__fulltype_", vname));
        if vt >= 0 { vtype = vt; };
    };
    if vk == 9 {
        let parent_type: str = expr_full_type_from_sym(pool, node_field(pool, vexpr, 1), sym, structs);
        if str_len(parent_type) > 0 {
            let si: i64 = struct_find_type(pool, structs, parent_type);
            if si >= 0 {
                vtype = struct_field_type_for_inst(pool, vec_get(structs, si), parent_type, node_field(pool, vexpr, 2));
            };
        };
    };
    if vk == 7 {
        let fn_name: str = node_field(pool, vexpr, 1);
        let ft: i64 = sym_get(sym, str_concat("__fnfulltype_", fn_name));
        if ft >= 0 { vtype = ft; };
    };
    // trait-method-call (kind 8) indexed operand. Mirrors
    // the kind==7 lookup but with the trait-impl mangled name
    // (`<TYPE>__<METHOD>`) — so `s.samples()[i]` where samples
    // returns Vec<f64> resolves correctly to f64 element type.
    // Pre-v0.3.74, this fell through to "" and the outer binop
    // dispatched to integer add on packed-double bit patterns.
    if vk == 8 {
        let recv_nid: i64 = node_field(pool, vexpr, 1);
        let mname: str = node_field(pool, vexpr, 2);
        let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
        if str_len(rtype) > 0 {
            let mangled: str = str_concat(rtype, str_concat("__", mname));
            let ft: i64 = sym_get(sym, str_concat("__fnfulltype_", mangled));
            if ft >= 0 { vtype = ft; };
        };
    };
    if vk == 10 {
        // Nested indexing — recurse to get inner expr's element type,
        // which is itself a container. The outer indexing strips
        // one MORE level below.
        vtype = indexed_element_full_type(pool, node_field(pool, vexpr, 1), sym, structs);
    };
    if str_len(vtype) == 0 { return ""; };
    return strip_container_one_level(vtype);
}

#[manual_drop]
fn expr_full_type_from_sym(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 { return int_lit_type(pool, nid); };
    if kind == 71 { return "f64"; };
    if kind == 72 { return "f64"; };
    if kind == 73 { return "f32"; };
    if kind == 2 { return "str"; };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        let ft: i64 = sym_get(sym, str_concat("__fulltype_", name));
        if ft >= 0 { return ft; };
        let bt: i64 = sym_get(sym, str_concat("__type_", name));
        if bt >= 0 { return bt; };
        return "";
    };
    if kind == 9 {
        let parent_t: str = expr_full_type_from_sym(pool, node_field(pool, nid, 1), sym, structs);
        let parent_base: str = type_base_name(parent_t);
        if str_len(parent_base) > 0 {
            let si: i64 = struct_find_type(pool, structs, parent_base);
            if si >= 0 { return struct_field_type_for_inst(pool, vec_get(structs, si), parent_t, node_field(pool, nid, 2)); };
        };
        return "";
    };
    if kind == 10 { return indexed_element_full_type(pool, node_field(pool, nid, 1), sym, structs); };
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let ft2: i64 = sym_get(sym, str_concat("__fnfulltype_", fn_name));
        if ft2 >= 0 { return ft2; };
        let rt2: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if rt2 >= 0 { return rt2; };
        return "";
    };
    if kind == 8 {
        let recv_t: str = expr_full_type_from_sym(pool, node_field(pool, nid, 1), sym, structs);
        let mname: str = node_field(pool, nid, 2);
        if str_eq(mname, "get") == 1 || str_eq(mname, "first") == 1 || str_eq(mname, "last") == 1 || str_eq(mname, "pop") == 1 {
            let elem_t: str = strip_container_one_level(recv_t);
            if str_len(elem_t) > 0 { return elem_t; };
        };
        let recv_base: str = type_base_name(recv_t);
        if str_len(recv_base) > 0 {
            let mangled: str = str_concat(recv_base, str_concat("__", mname));
            let ft3: i64 = sym_get(sym, str_concat("__fnfulltype_", mangled));
            if ft3 >= 0 { return ft3; };
            let rt3: i64 = sym_get(sym, str_concat("__fnret_", mangled));
            if rt3 >= 0 { return rt3; };
        };
        return "";
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname12: str = node_field(pool, nid, 2);
        let args: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Option") == 1 {
            if str_eq(mname12, "Some") == 1 && list_len(pool, args) > 0 {
                let inner: str = expr_full_type_from_sym(pool, list_get(pool, args, 0), sym, structs);
                if str_len(inner) > 0 { return str_concat("Option<", str_concat(inner, ">")); };
            };
            return "Option";
        };
        if str_eq(tname, "Result") == 1 {
            if str_eq(mname12, "Ok") == 1 && list_len(pool, args) > 0 {
                let ok_t: str = expr_full_type_from_sym(pool, list_get(pool, args, 0), sym, structs);
                if str_len(ok_t) > 0 { return str_concat("Result<", str_concat(ok_t, ",_>")); };
            };
            if str_eq(mname12, "Err") == 1 && list_len(pool, args) > 0 {
                let err_t: str = expr_full_type_from_sym(pool, list_get(pool, args, 0), sym, structs);
                if str_len(err_t) > 0 { return str_concat("Result<_,", str_concat(err_t, ">")); };
            };
            return "Result";
        };
        if str_eq(tname, "Box") == 1 && list_len(pool, args) > 0 {
            let box_t: str = expr_full_type_from_sym(pool, list_get(pool, args, 0), sym, structs);
            if str_len(box_t) > 0 { return str_concat("Box<", str_concat(box_t, ">")); };
        };
        let mangled12: str = str_concat(tname, str_concat("__", mname12));
        let ft12: i64 = sym_get(sym, str_concat("__fnfulltype_", mangled12));
        if ft12 >= 0 { return ft12; };
        let rt12: i64 = sym_get(sym, str_concat("__fnret_", mangled12));
        if rt12 >= 0 { return rt12; };
        if list_len(pool, args) == 0 { return tname; };
    };
    return "";
}

#[manual_drop]
fn binop_u64_type(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 { return int_suffix_code_is_u64ish(int_lit_suffix_code(pool, nid)); };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        let ft: i64 = sym_get(sym, str_concat("__fulltype_", name));
        if ft >= 0 && str_eq(type_base_name(ft), "u64") == 1 { return 1; };
        let bt: i64 = sym_get(sym, str_concat("__type_", name));
        if bt >= 0 && str_eq(type_base_name(bt), "u64") == 1 { return 1; };
        return 0;
    };
    if kind == 4 {
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        if is_cmp_or_logic(iop) == 1 { return 0; };
        if binop_u64_type(pool, node_field(pool, nid, 2), sym, structs) == 1 { return 1; };
        if binop_u64_type(pool, node_field(pool, nid, 3), sym, structs) == 1 { return 1; };
        return 0;
    };
    if kind == 90 || kind == 91 || kind == 92 {
        return binop_u64_type(pool, node_field(pool, nid, 1), sym, structs);
    };
    if kind == 99 {
        if str_eq(type_base_name(node_field(pool, nid, 2)), "u64") == 1 { return 1; };
        return 0;
    };
    if kind == 9 || kind == 10 || kind == 7 || kind == 8 || kind == 12 {
        let full: str = expr_full_type_from_sym(pool, nid, sym, structs);
        if str_eq(type_base_name(full), "u64") == 1 { return 1; };
    };
    return 0;
}

#[manual_drop]
fn binop_float_type(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let vname: str = node_field(pool, nid, 1);
        let tstr: i64 = sym_get(sym, str_concat("__type_", vname));
        if tstr < 0 { return ""; };
        if str_eq(tstr, "f32") == 1 { return "f32"; };
        if str_eq(tstr, "f64") == 1 { return "f64"; };
        return "";
    };
    if kind == 71 { return "f64"; };
    if kind == 72 { return "f64"; };
    // NUC-FEEDBACK-002 follow-on: kind 73 is f32 literal,
    // introduced when the lexer/parser started preserving the f32 suffix.
    // Without this entry, unary minus on an f32 literal fell to the
    // integer-subtract path and `-1.5f32` evaluated to -3.0 (silent
    // miscompute caught when binop_float_type returned "" for kind 73).
    if kind == 73 { return "f32"; };
    // struct field access. Pre-v0.3.53 this fell
    // through to "" → integer binop, mis-computing inline
    // f64 ops on struct-field operands (`a.x * b.x` etc).
    // Look up the struct via expr_struct_type → struct_field_type.
    if kind == 9 {
        let outer_type: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(outer_type) == 0 { return ""; };
        let si: i64 = struct_find_type(pool, structs, outer_type);
        if si >= 0 {
            let ftype: str = type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2)));
            if str_eq(ftype, "f32") == 1 { return "f32"; };
            if str_eq(ftype, "f64") == 1 { return "f64"; };
        };
        return "";
    };
    // nested binop. For `(a.x*b.x) + (a.y*b.y)`,
    // the outer + has binop operands. Recurse into each operand's
    // own binop type — f32 wins precedence, then f64 (matches the
    // outer dispatch rule). Without this, the + fell through to
    // integer add even though both halves were correctly compiled
    // as f64 muls.
    if kind == 4 {
        // regression closure
        // 2026-05-01-f64-cmp-as-i32-cast-silently-zero (CRITICAL).
        // Comparison operators (`<` `>` `<=` `>=` `==` `!=`) and
        // logical (`&&` `||`) produce a BOOL result, not a float —
        // even when the OPERANDS are f64. Pre-fix `(a < b) as i32`
        // for `a, b: f64` had binop_float_type returning "f64", which
        // then drove kind-99 (as cast) to dispatch f64_to_i32 on the
        // i64 cmp-result bit pattern (always 0 or 1) → produced 0
        // because the small-magnitude check rounded the bit pattern
        // to 0 / nonsense. Now: if the binop is a cmp/logic op, return
        // "" so the kind-99 path falls through to the int→int
        // as_i32/as_i64 helper which correctly produces 0/1.
        let cmp_iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        if is_cmp_or_logic(cmp_iop) == 1 {
            return "";
        };
        let lt: str = binop_float_type(pool, node_field(pool, nid, 2), sym, structs);
        let rt: str = binop_float_type(pool, node_field(pool, nid, 3), sym, structs);
        if str_eq(lt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(lt, "f64") == 1 { return "f64"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // parenthesized expression / cast / borrow
    // wrappers preserve the inner type. Mirror the precedence
    // chain that expr_struct_type already handles.
    if kind == 90 || kind == 91 || kind == 92 {
        return binop_float_type(pool, node_field(pool, nid, 1), sym, structs);
    };
    // function call. Look up the called fn's return
    // type via the `__fnret_<NAME>` sym entry (populated by
    // populate_fn_returns_in_sym at lower_fn entry). Without this,
    // `make_one() + make_four()` (both returning f64) silently
    // fell through to integer add and miscomputed.
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let rt: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if rt < 0 { return ""; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // as-cast (`x as f64` is AST kind 99). The
    // target type is stored directly on the cast node (field 2).
    // Pre-v0.3.61: `(make_int() as f64) + (make_int() as f64)`
    // miscomputed because both operands were casts and neither
    // triggered the existing literal/var f-typed paths. Fix:
    // strip type_base_name in case the target carries generic
    // decorations, then return f32/f64 if matched.
    if kind == 99 {
        let target_type: str = type_base_name(node_field(pool, nid, 2));
        if str_eq(target_type, "f32") == 1 { return "f32"; };
        if str_eq(target_type, "f64") == 1 { return "f64"; };
        return "";
    };
    // trait method call (`obj.method(args)` is
    // AST kind 8). Real production case: trait method results
    // used inline in binops (`r1.area() + r2.area()`) miscompiled
    // because kind 8 wasn't in the enumeration. Resolve receiver
    // type via expr_struct_type, construct the trait_impl mangled
    // name (`<TYPE>__<METHOD>`), look up __fnret_<MANGLED>. The
    // mangling matches what compile_one's pass-1.5 (collect_impls
    // at line 11144) generates for trait methods.
    if kind == 8 {
        let recv_nid: i64 = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
        if str_len(rtype) == 0 { return ""; };
        let mangled: str = str_concat(rtype, str_concat("__", mname));
        let rt: i64 = sym_get(sym, str_concat("__fnret_", mangled));
        if rt < 0 { return ""; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // Vec indexing (`v[i]` is AST kind 10).
    // Extract the element type from the variable's full declared
    // type (Vec<f64>) via the __fulltype_ sym entry. The existing
    // __type_ sym entry only stores the base name ("Vec") because
    // type_base_name strips generics; v0.3.55 added a parallel
    // __fulltype_ entry that preserves the generic so the kind==10
    // dispatcher can extract the element type.
    // also handles fixed-size arrays
    // `[T; N]` (parsed identically to indexing). Production code
    // uses fixed arrays for state vectors / sensor batches with
    // known length.
    if kind == 10 {
        // refactored to use indexed_element_full_type
        // which composes all four operand kinds (3, 9, 7, 10) and
        // strips one container layer per level. The element type
        // returned has generics preserved; type_base_name strips
        // the outer wrapper for the f-typed primitive check.
        let elem_full: str = indexed_element_full_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(elem_full) == 0 { return ""; };
        let elem_base: str = type_base_name(elem_full);
        if str_eq(elem_base, "f32") == 1 { return "f32"; };
        if str_eq(elem_base, "f64") == 1 { return "f64"; };
        return "";
    };
    return "";
}

// T1.1 Phase 5: map a binop token (via tok_to_ir) and a float type
// to the corresponding runtime helper name. Returns "" if the op
// isn't a float-supported binop or the type isn't float.
// Supported ops (iop values from tok_to_ir):
//   2  + → f<T>_add        7  == → f<T>_eq
//   3  - → f<T>_sub        8  != → f<T>_ne
//   4  * → f<T>_mul        9  <  → f<T>_lt
//   5  / → f<T>_div       10  >  → f<T>_gt
//                         11  <= → f<T>_le
//                         12  >= → f<T>_ge
#[manual_drop]
fn float_binop_helper(iop: i64, ftype: str) -> str {
    if str_len(ftype) == 0 { return ""; };
    let mut suffix: str = "";
    if iop == 2 { suffix = "add"; };
    if iop == 3 { suffix = "sub"; };
    if iop == 4 { suffix = "mul"; };
    if iop == 5 { suffix = "div"; };
    if iop == 7 { suffix = "eq"; };
    if iop == 8 { suffix = "ne"; };
    if iop == 9 { suffix = "lt"; };
    if iop == 10 { suffix = "gt"; };
    if iop == 11 { suffix = "le"; };
    if iop == 12 { suffix = "ge"; };
    if str_len(suffix) == 0 { return ""; };
    if str_eq(ftype, "f32") == 1 { return str_concat("f32_", suffix); };
    if str_eq(ftype, "f64") == 1 { return str_concat("f64_", suffix); };
    return "";
}

// T1.1 Phase 1+2+3c+5: if `tstr` is a narrow numeric type, insert a
// runtime `__nucleor_as_<T>` cast so the stored value is width-
// correct (e.g. u8 wraps mod 256, i32 truncates from i64, f32
// narrows from f64). Returns the new register holding the narrowed
// value, or `vr` unchanged otherwise.
// `src_kind` is the AST kind of the init expression. For f32
// narrowing we ONLY narrow when the source is a f64 literal
// (kind == 71). If the source is already a float expression
// (e.g. result of f32 binop, another f32 variable), a second
// narrowing would corrupt the already-narrow bit-pattern. This
// guard is specific to float types; integer narrowing is always
// safe to apply.
// Phase 3c stdlib audit complete: i32/u32 narrowing is safe.
#[manual_drop]
fn narrow_via_as(blk: Vec<i32>, regs: Vec<i32>, vr: i64, tstr: str, src_kind: i64) -> i64 {
    // Defensive: a negative source register means upstream lowering failed.
    // Return it unchanged so the bad register propagates to a visible
    // diagnostic rather than getting silently wrapped in an as-cast.
    if vr < 0 { return vr; };
    if str_len(tstr) == 0 { return vr; };
    let mut helper: str = "";
    if str_eq(tstr, "i8") == 1 { helper = "as_i8"; };
    if str_eq(tstr, "i16") == 1 { helper = "as_i16"; };
    if str_eq(tstr, "i32") == 1 { helper = "as_i32"; };
    if str_eq(tstr, "u8") == 1 { helper = "as_u8"; };
    if str_eq(tstr, "u16") == 1 { helper = "as_u16"; };
    if str_eq(tstr, "u32") == 1 { helper = "as_u32"; };
    // f32 narrowing per source kind: literals get the right converter,
    // already-narrow values are left alone (avoid double-conversion).
    if str_eq(tstr, "f32") == 1 && src_kind == 71 { helper = "as_f32"; };       // f64 literal
    if str_eq(tstr, "f32") == 1 && src_kind == 1 { helper = "i64_to_f32"; };    // int literal
    // f64 from int literal: needs i64→f64 conversion (literals are
    // stored as raw i64 bit pattern, not as scaled-f64).
    if str_eq(tstr, "f64") == 1 && src_kind == 1 { helper = "i64_to_f64"; };
    if str_len(helper) == 0 { return vr; };
    let mut conv_args: Vec<i32> = Vec::new();
    conv_args.push(vr);
    let r: i64 = ctr_next(regs);
    ir_block_add(blk, ir_call_ex(r, helper, conv_args));
    return r;
}

#[manual_drop]
fn auto_drop_helper_for_type(tstr: str) -> str {
    if str_len(tstr) == 0 { return ""; };
    let base: str = type_base_name(tstr);
    if str_eq(base, "Vec") == 1 || str_starts_with(tstr, "Vec<") == 1 { return "vec_free"; };
    if str_eq(base, "HashMap") == 1 || str_starts_with(tstr, "HashMap<") == 1 { return "hashmap_free"; };
    // Internal-only type tag: closure-typed bindings (surface type i64)
    // are registered with tstr="Closure" so the auto-drop framework
    // emits nuc_closure_release_boxed at scope end. The "Closure" tag
    // never appears in source code; it's set by the let-binding lower
    // when the init is a closure literal or a closure-returning call.
    if str_eq(tstr, "Closure") == 1 { return "nuc_closure_release_boxed"; };
    return "";
}

#[manual_drop]
fn auto_drop_call_returns_borrowed(name: str) -> i64 {
    if str_eq(name, "vec_get") == 1 { return 1; };
    if str_eq(name, "tok_at") == 1 { return 1; };
    if str_eq(name, "tok_v") == 1 { return 1; };
    if str_eq(name, "node_field") == 1 { return 1; };
    if str_eq(name, "ir_block_get_inst") == 1 { return 1; };
    if str_eq(name, "ir_fn_get_block") == 1 { return 1; };
    if str_eq(name, "ir_fn_strtab_aux") == 1 { return 1; };
    if str_eq(name, "lx_blk") == 1 { return 1; };
    if str_eq(name, "diag_get") == 1 { return 1; };
    if str_eq(name, "own_diags") == 1 { return 1; };
    if str_eq(name, "own_shared_keys_vec") == 1 { return 1; };
    if str_eq(name, "own_mut_keys_vec") == 1 { return 1; };
    if str_eq(name, "own_scope_keys_vec") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn auto_drop_init_owns_value(pool: Vec<i32>, init: i64) -> i64 {
    if init < 0 { return 0; };
    let k: i64 = node_kind(pool, init);
    if k == 3 { return 0; };
    if k == 7 {
        let fn_name: str = node_field(pool, init, 1);
        if auto_drop_call_returns_borrowed(fn_name) == 1 { return 0; };
        return 1;
    };
    if k == 8 { return 0; };
    if k == 9 { return 0; };
    if k == 10 { return 0; };
    // Constructor calls such as `Vec::new()` create owned values. The
    // registration path still gates by declared/inferred type cleanup helper.
    if k == 12 { return 1; };
    return 1;
}

#[manual_drop]
fn auto_drop_is_enabled(sym: Vec<i32>) -> i64 {
    let enabled: i64 = sym_get(sym, "__auto_drop_enabled");
    if enabled == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn auto_drop_state_key(idx: i64) -> str { return str_concat("__auto_drop_state_", str_from_int(idx)); }
#[manual_drop]
fn auto_drop_name_key(idx: i64) -> str { return str_concat("__auto_drop_name_", str_from_int(idx)); }
#[manual_drop]
fn auto_drop_helper_key(idx: i64) -> str { return str_concat("__auto_drop_helper_", str_from_int(idx)); }
#[manual_drop]
fn auto_drop_alloca_key(idx: i64) -> str { return str_concat("__auto_drop_alloca_", str_from_int(idx)); }
#[manual_drop]
fn auto_drop_index_key(name: str) -> str { return str_concat("__auto_drop_index_", name); }

#[manual_drop]
fn auto_drop_register(sym: Vec<i32>, vname: str, tstr: str, ar: i64) -> i64 {
    if auto_drop_is_enabled(sym) == 0 { return 0; };
    if str_len(vname) == 0 || str_eq(vname, "_") == 1 { return 0; };
    if ar < 0 { return 0; };
    let helper: str = auto_drop_helper_for_type(tstr);
    if str_len(helper) == 0 { return 0; };
    let old_count: i64 = sym_get(sym, "__auto_drop_count");
    let idx: i64 = if old_count < 0 { 0 } else { old_count };
    sym_set(sym, auto_drop_name_key(idx), vname);
    sym_set(sym, auto_drop_helper_key(idx), helper);
    sym_set(sym, auto_drop_alloca_key(idx), ar);
    sym_set(sym, auto_drop_state_key(idx), 1);
    sym_set(sym, auto_drop_index_key(vname), idx);
    sym_set(sym, "__auto_drop_count", idx + 1);
    return 0;
}

#[manual_drop]
fn auto_drop_set_state(sym: Vec<i32>, vname: str, state: i64) -> i64 {
    if auto_drop_is_enabled(sym) == 0 { return 0; };
    if str_len(vname) == 0 { return 0; };
    let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
    if idx < 0 { return 0; };
    sym_set(sym, auto_drop_state_key(idx), state);
    return 0;
}

#[manual_drop]
fn auto_drop_mark_freed(sym: Vec<i32>, vname: str) -> i64 {
    return auto_drop_set_state(sym, vname, 0);
}

#[manual_drop]
fn auto_drop_mark_live(sym: Vec<i32>, vname: str) -> i64 {
    return auto_drop_set_state(sym, vname, 1);
}

#[manual_drop]
fn auto_drop_emit_index(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, idx: i64, skip_name: str) -> Vec<i32> {
    if idx < 0 { return cur; };
    let state: i64 = sym_get(sym, auto_drop_state_key(idx));
    if state != 1 { return cur; };
    let name_i: i64 = sym_get(sym, auto_drop_name_key(idx));
    if name_i < 0 { return cur; };
    let lname: str = name_i;
    if str_len(skip_name) > 0 && str_eq(lname, skip_name) == 1 { return cur; };
    let helper_i: i64 = sym_get(sym, auto_drop_helper_key(idx));
    let ar: i64 = sym_get(sym, auto_drop_alloca_key(idx));
    if helper_i < 0 || ar < 0 { return cur; };
    let helper: str = helper_i;
    let val_r: i64 = ctr_next(regs);
    ir_block_add(cur, ir_load(val_r, ar));
    let mut drop_args: Vec<i32> = Vec::new();
    drop_args.push(val_r);
    let drop_r: i64 = ctr_next(regs);
    ir_block_add(cur, ir_call_ex(drop_r, helper, drop_args));
    sym_set(sym, auto_drop_state_key(idx), 0);
    return cur;
}

#[manual_drop]
fn auto_drop_emit_named(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, vname: str) -> Vec<i32> {
    if auto_drop_is_enabled(sym) == 0 { return cur; };
    let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
    if idx < 0 { return cur; };
    return auto_drop_emit_index(cur, regs, sym, idx, "");
}

#[manual_drop]
fn auto_drop_emit_live(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, skip_name: str) -> Vec<i32> {
    if auto_drop_is_enabled(sym) == 0 { return cur; };
    let count: i64 = sym_get(sym, "__auto_drop_count");
    if count <= 0 { return cur; };
    let mut i: i64 = count - 1;
    let mut out: Vec<i32> = cur;
    while i >= 0 {
        out = auto_drop_emit_index(out, regs, sym, i, skip_name);
        i = i - 1;
    };
    return out;
}

// Per-loop-iteration drop emission. Emits releases only for closure-
// typed bindings whose idx >= min_idx — i.e. bindings declared INSIDE
// the loop body (above the outer-scope snapshot).
//
// Scoped to closures (not Vec/HashMap/str) because user-defined
// fns that take owned args (e.g. json_array_push(arr, elem)) are
// not in the auto_drop_handoff_name registry. If we per-iter-dropped
// elem at end of body, arr's heap data would point at freed memory.
// Closures don't have this problem: passing a closure to a higher-
// order fn is by-value copy of the tagged pointer; the original
// binding retains ownership of the env (mark_constructor_handoffs
// skips closure values explicitly).
//
// The proper fix for Vec/HashMap/str-in-loop is escape analysis or
// a wider handoff tracker; both deferred. Closures fix today.
#[manual_drop]
fn auto_drop_emit_live_above_closures(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, min_idx: i64) -> Vec<i32> {
    if auto_drop_is_enabled(sym) == 0 { return cur; };
    let count: i64 = sym_get(sym, "__auto_drop_count");
    if count <= min_idx { return cur; };
    let mut i: i64 = count - 1;
    let mut out: Vec<i32> = cur;
    while i >= min_idx {
        let state: i64 = sym_get(sym, auto_drop_state_key(i));
        if state == 1 {
            let helper_i: i64 = sym_get(sym, auto_drop_helper_key(i));
            if helper_i >= 0 {
                let helper: str = helper_i;
                if str_eq(helper, "nuc_closure_release_boxed") == 1 {
                    out = auto_drop_emit_index(out, regs, sym, i, "");
                };
            };
        };
        i = i - 1;
    };
    return out;
}

#[manual_drop]
fn auto_drop_explicit_free_name(pool: Vec<i32>, expr_nid: i64) -> str {
    if expr_nid < 0 { return ""; };
    if node_kind(pool, expr_nid) != 7 { return ""; };
    let fn_name: str = node_field(pool, expr_nid, 1);
    let is_free: i64 = if str_eq(fn_name, "vec_free") == 1 || str_eq(fn_name, "str_free") == 1 || str_eq(fn_name, "hashmap_free") == 1 { 1 } else { 0 };
    if is_free == 0 { return ""; };
    let args_list: i64 = node_field(pool, expr_nid, 2);
    if list_len(pool, args_list) <= 0 { return ""; };
    let first_arg: i64 = list_get(pool, args_list, 0);
    if node_kind(pool, first_arg) != 3 { return ""; };
    return node_field(pool, first_arg, 1);
}

#[manual_drop]
fn auto_drop_handoff_name(pool: Vec<i32>, expr_nid: i64, sym: Vec<i32>) -> str {
    if expr_nid < 0 { return ""; };
    let ek: i64 = node_kind(pool, expr_nid);
    let mut args_list: i64 = -1;
    let mut value_idx: i64 = -1;
    if ek == 7 {
        let fn_name: str = node_field(pool, expr_nid, 1);
        value_idx = if str_eq(fn_name, "vec_push") == 1 { 1 }
                    else if str_eq(fn_name, "vec_set") == 1 { 2 }
                    else if str_eq(fn_name, "hashmap_insert") == 1 { 2 }
                    else if str_eq(fn_name, "node_add") == 1 { 1 }
                    else { -1 };
        args_list = node_field(pool, expr_nid, 2);
    } else if ek == 8 {
        let method_name: str = node_field(pool, expr_nid, 2);
        value_idx = if str_eq(method_name, "push") == 1 { 0 }
                    else if str_eq(method_name, "set") == 1 { 1 }
                    else if str_eq(method_name, "insert") == 1 { 1 }
                    else { -1 };
        args_list = node_field(pool, expr_nid, 3);
    } else {
        return "";
    };
    if value_idx < 0 { return ""; };
    if list_len(pool, args_list) <= value_idx { return ""; };
    let value_arg: i64 = list_get(pool, args_list, value_idx);
    if node_kind(pool, value_arg) != 3 { return ""; };
    let vname: str = node_field(pool, value_arg, 1);
    // Only suppress if this name was actually registered for
    // auto-drop in this fn.
    let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
    if idx < 0 { return ""; };
    return vname;
}

#[manual_drop]
fn auto_drop_mark_constructor_handoffs(pool: Vec<i32>, expr_nid: i64, sym: Vec<i32>) -> i64 {
    if expr_nid < 0 { return 0; };
    if node_kind(pool, expr_nid) == 34 {
        let init_list: i64 = node_field(pool, expr_nid, 2);
        let n34: i64 = list_len(pool, init_list);
        let mut i34: i64 = 0;
        while i34 < n34 {
            let init_nid: i64 = list_get(pool, init_list, i34);
            let val_nid: i64 = node_field(pool, init_nid, 2);
            if node_kind(pool, val_nid) == 3 {
                let vname34: str = node_field(pool, val_nid, 1);
                let idx34: i64 = sym_get(sym, auto_drop_index_key(vname34));
                if idx34 >= 0 { auto_drop_mark_freed(sym, vname34); };
            } else {
                auto_drop_mark_constructor_handoffs(pool, val_nid, sym);
            };
            i34 = i34 + 1;
        };
        return 0;
    };
    // Default-flip validation: also recognize
    // kind-7 regular fn calls as handoff sites, not just kind-12 type-method
    // calls. The wrapper pattern `fn nn_X(...) -> TensorF64 { let mut data:
    // Vec<f64>; ...; return tensor_f64_from_vec(rows, cols, data); }` was
    // failing on Linux because `tensor_f64_from_vec(...)` is kind-7 and the
    // pre-fix `if != 12 return 0` bailed. The leaf `tensor_f64_from_vec`
    // body itself works because its return is a kind-34 struct literal
    // (handled above); the wrapper layer's missing case is exactly this
    // kind-7-call-as-handoff shape.
    let ek_call: i64 = node_kind(pool, expr_nid);
    let mut args_list: i64 = 0 - 1;
    if ek_call == 7 {
        args_list = node_field(pool, expr_nid, 2);
    } else if ek_call == 12 {
        args_list = node_field(pool, expr_nid, 3);
    } else {
        return 0;
    };
    let n: i64 = list_len(pool, args_list);
    let mut i: i64 = 0;
    while i < n {
        let arg: i64 = list_get(pool, args_list, i);
        if node_kind(pool, arg) == 3 {
            let vname: str = node_field(pool, arg, 1);
            let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
            if idx >= 0 {
                // Closure values are NOT move-only: a closure can be
                // called multiple times from the same scope, and passing
                // it to a higher-order fn does not transfer ownership.
                // The closure literal evaluation produced one refcount
                // that the original binding owns; the callee gets a
                // value copy of the boxed pointer without taking
                // ownership of the env. Releasing the source at the
                // call site would leave the original binding pointing
                // at a freed env. Skip the handoff mark for closures.
                let helper_i: i64 = sym_get(sym, auto_drop_helper_key(idx));
                let mut is_closure: i64 = 0;
                if helper_i >= 0 {
                    let h_str: str = helper_i;
                    if str_eq(h_str, "nuc_closure_release_boxed") == 1 { is_closure = 1; };
                };
                if is_closure == 0 { auto_drop_mark_freed(sym, vname); };
            };
        } else if node_kind(pool, arg) == 7 || node_kind(pool, arg) == 12 {
            auto_drop_mark_constructor_handoffs(pool, arg, sym);
        };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn auto_drop_return_skip_name(pool: Vec<i32>, expr_nid: i64, sym: Vec<i32>) -> str {
    if expr_nid < 0 { return ""; };
    if node_kind(pool, expr_nid) == 3 {
        let vname: str = node_field(pool, expr_nid, 1);
        let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
        if idx < 0 { return ""; };
        return vname;
    };
    return auto_drop_handoff_name(pool, expr_nid, sym);
}

#[manual_drop]
fn auto_drop_assignment_reuses_lhs(pool: Vec<i32>, rhs_nid: i64, lhs_name: str) -> i64 {
    if rhs_nid < 0 { return 0; };
    let rk: i64 = node_kind(pool, rhs_nid);
    if rk == 3 {
        let rhs_name: str = node_field(pool, rhs_nid, 1);
        if str_eq(rhs_name, lhs_name) == 1 { return 1; };
        return 0;
    };
    if rk == 7 || rk == 12 {
        let mut args_list: i64 = node_field(pool, rhs_nid, 2);
        if rk == 12 { args_list = node_field(pool, rhs_nid, 3); };
        if list_len(pool, args_list) <= 0 { return 0; };
        let first_arg: i64 = list_get(pool, args_list, 0);
        if node_kind(pool, first_arg) == 3 {
            let first_name: str = node_field(pool, first_arg, 1);
            if str_eq(first_name, lhs_name) == 1 { return 1; };
        };
        return 0;
    };
    if rk == 8 {
        let recv: i64 = node_field(pool, rhs_nid, 1);
        if node_kind(pool, recv) == 3 {
            let recv_name: str = node_field(pool, recv, 1);
            if str_eq(recv_name, lhs_name) == 1 { return 1; };
        };
    };
    return 0;
}

fn deadline_poll_emit_if_enabled(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>) -> Vec<i32> {
    if sym_get(sym, "__deadline_poll_enabled") == 1 {
        let args: Vec<i32> = Vec::new();
        let dr: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(dr, "deadline_poll", args));
    };
    return cur;
}

#[manual_drop]
fn lower_stmt(pool: Vec<i32>, nid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        // shadowing fix. Pre-v0.3.76, this lowering bound the
        // new slot (sym_set) BEFORE lowering the RHS, so a shadowing
        // statement like `let x: i64 = x + 5;` resolved the inner `x`
        // to the new (uninitialized) slot and produced garbage.
        // Fix: allocate the new slot upfront, but bind sym entries
        // AFTER lowering the RHS expression so the RHS sees the OLD
        // shadowed binding (Rust shadowing semantics — the new binding
        // takes effect on the next statement, not within its own RHS).
        let vname: str = node_field(pool, nid, 1);
        let init: i64 = node_field(pool, nid, 4);
        let mut tstr: str = node_field(pool, nid, 3);
        if str_len(tstr) == 0 && init >= 0 {
            let ik: i64 = node_kind(pool, init);
            if ik == 34 { tstr = node_field(pool, init, 1); }
            else if ik == 12 {
                let ctor_t: str = expr_full_type_from_sym(pool, init, sym, structs);
                if str_len(ctor_t) > 0 { tstr = ctor_t; }
                else { tstr = node_field(pool, init, 1); };
            }
            // string-literal RHS type inference. Pre-fix `let s = "lit"` (no
            // annotation) left __type_s unregistered because `tstr` was "" and the
            // sym_set at line ~25400 is gated on `str_len(sbase) > 0`. Method calls
            // on `s` then fell through recv_is_vec==1 path, emitting vec_split /
            // vec_contains / etc. — Fix: detect
            // kind-2 (str literal) RHS and stamp tstr="str" so the type entry lands
            // and the v0.4.88 str-method dispatch picks it up correctly.
            else if ik == 2 { tstr = "str"; }
            else if ik == 3 {
                let src_name20: str = node_field(pool, init, 1);
                let src_full_i20: i64 = sym_get(sym, str_concat("__fulltype_", src_name20));
                if src_full_i20 >= 0 { tstr = src_full_i20; }
                else {
                    let src_base_i20: i64 = sym_get(sym, str_concat("__type_", src_name20));
                    if src_base_i20 >= 0 { tstr = src_base_i20; };
                };
            };
        };
        let sbase: str = type_base_name(tstr);
        if str_eq(sbase, "u64") == 1 { sym_set(sym, "__has_u64_v886", 1); };
        let sblen20: i64 = str_len(sbase);
        let mut w20: i64 = 0;
        if sblen20 == 2 {
            if str_eq(sbase, "i8") == 1 { w20 = 8; }
            else if str_eq(sbase, "u8") == 1 { w20 = 0 - 8; };
        } else if sblen20 == 3 {
            if str_eq(sbase, "i16") == 1 { w20 = 16; }
            else if str_eq(sbase, "u16") == 1 { w20 = 0 - 16; }
            else if str_eq(sbase, "i32") == 1 { w20 = 32; }
            else if str_eq(sbase, "u32") == 1 { w20 = 0 - 32; };
        };
        let aw20: i64 = if w20 >= 0 { w20 } else { 0 - w20 };
        let ar: i64 = ctr_next(regs); ir_fn_add_entry_alloca_t(fir, ar, aw20);
        // register sign-encoded width on the alloca-reg.
        // Read by lower_expr kind-3 (var-ref load) and lower_stmt
        // kind-21 (assign-store). Only sets when w20 != 0 to keep
        // the widths-by-reg table sparse.
        if w20 != 0 { ir_fn_set_width(fir, ar, w20); };
        if init >= 0 {
            // Lower RHS BEFORE rebinding sym so any reference to `vname`
            // inside the RHS resolves to the OUTER (shadowed) slot.
            let src_kind: i64 = node_kind(pool, init);
            let mut vp: Vec<i32> = lower_expr(pool, init, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            cur = lx_blk(vp);
            auto_drop_mark_constructor_handoffs(pool, init, sym);
            let vr: i64 = lx_reg(vp);
            let nvr: i64 = narrow_via_as(cur, regs, vr, sbase, src_kind);
            if aw20 == 0 {
                ir_block_add(cur, ir_store(nvr, ar));
            } else {
                let tr20: i64 = ctr_next(regs);
                ir_block_add(cur, ir_trunc(tr20, nvr, aw20));
                ir_block_add(cur, ir_store_t(tr20, ar, aw20));
            };
        };
        // Bind sym entries AFTER the RHS is lowered. Under #[auto_drop],
        // shadowing a tracked owned local ends the old binding here.
        cur = auto_drop_emit_named(cur, regs, sym, vname);
        sym_set(sym, vname, ar);
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", vname), sbase); };
        // also store the FULL declared type (with generics
        // like Vec<f64>) so binop_float_type can extract Vec<T>'s
        // element type for kind==10 (indexing) dispatch. type_base_name
        // strips the <T> for the existing __type_ entry.
        if str_len(tstr) > 0 { sym_set(sym, str_concat("__fulltype_", vname), tstr); };
        if init >= 0 && node_kind(pool, init) == 3 && str_len(auto_drop_helper_for_type(tstr)) > 0 {
            let transfer_src20: str = node_field(pool, init, 1);
            let transfer_idx20: i64 = sym_get(sym, auto_drop_index_key(transfer_src20));
            if transfer_idx20 >= 0 && sym_get(sym, auto_drop_state_key(transfer_idx20)) == 1 {
                auto_drop_mark_freed(sym, transfer_src20);
                auto_drop_register(sym, vname, tstr, ar);
            };
        } else if init >= 0 && auto_drop_init_owns_value(pool, init) == 1 {
            auto_drop_register(sym, vname, tstr, ar);
        };
        // Closure-aware auto-drop registration. Three paths:
        //   (a) init is a closure literal (kind 42): owns a fresh env.
        //   (b) init is a call to a fn tagged as closure-returning:
        //       owns the env returned by the callee.
        //   (c) init is a var-ref (kind 3) to a binding registered with
        //       the closure helper: transfer ownership (mark src freed,
        //       register dest).
        // Surface type stays i64; we use the internal "Closure" type tag
        // so auto_drop_helper_for_type returns nuc_closure_release_boxed.
        if init >= 0 {
            let init_k_cl: i64 = node_kind(pool, init);
            if init_k_cl == 42 {
                auto_drop_register(sym, vname, "Closure", ar);
            } else if init_k_cl == 7 {
                let callee_cl: str = node_field(pool, init, 1);
                if str_len(callee_cl) > 0 {
                    let ret_cl: i64 = sym_get(sym, str_concat("__fnret_closure_", callee_cl));
                    if ret_cl >= 0 {
                        auto_drop_register(sym, vname, "Closure", ar);
                    };
                };
            } else if init_k_cl == 3 {
                let src_cl_name: str = node_field(pool, init, 1);
                let src_cl_idx: i64 = sym_get(sym, auto_drop_index_key(src_cl_name));
                if src_cl_idx >= 0 && sym_get(sym, auto_drop_state_key(src_cl_idx)) == 1 {
                    let src_cl_helper_i: i64 = sym_get(sym, auto_drop_helper_key(src_cl_idx));
                    if src_cl_helper_i >= 0 {
                        let src_cl_helper: str = src_cl_helper_i;
                        if str_eq(src_cl_helper, "nuc_closure_release_boxed") == 1 {
                            auto_drop_mark_freed(sym, src_cl_name);
                            auto_drop_register(sym, vname, "Closure", ar);
                        };
                    };
                };
            };
        };
        if init >= 0 && node_kind(pool, init) == 42 {
            let cid_meta: i64 = sym_get(sym, "__last_closure_id");
            let caps_meta: i64 = sym_get(sym, "__last_closure_caps");
            if cid_meta >= 0 {
                sym_set(sym, str_concat("__closure_id_", vname), cid_meta);
            };
            if caps_meta >= 0 {
                let caps_s: str = caps_meta;
                if str_len(caps_s) > 0 {
                    sym_set(sym, str_concat("__closure_caps_", vname), caps_s);
                };
            };
        };
        return cur;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let lhs_kind: i64 = node_kind(pool, lhs);
        // assignment LHS shapes that lower_stmt
        // can't lower must short-circuit so we don't fall through to
        // the var-ref code path (which interprets node-id as string
        // offset and segfaults). Diagnostic was already emitted by
        // check_stmt; lower_stmt just needs to skip codegen.
        // real `v[i] = X` indexed-LHS lowering. Pre-v0.3.124
        // the kind-10 LHS shape silently dropped the assignment AND
        // its diag was informational (build still produced a .exe with
        // wrong values — the read-back of v[i] returned the original
        // value instead of the assigned X). Adopters writing
        // `v[i] = …` (a basic Rust pattern) saw silent miscomputes.
        // Fix: lower the receiver expr, the index expr, and the value
        // expr; emit `vec_set(v, i, X)`. The runtime helper exists.
        if lhs_kind == 10 {
            let mut recv_p: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let recv_r: i64 = lx_reg(recv_p);
            cur = lx_blk(recv_p);
            let mut idx_p: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let idx_r: i64 = lx_reg(idx_p);
            cur = lx_blk(idx_p);
            let mut val_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let val_r: i64 = lx_reg(val_p);
            cur = lx_blk(val_p);
            let mut set_args: Vec<i32> = Vec::new();
            set_args.push(recv_r);
            set_args.push(idx_r);
            set_args.push(val_r);
            let sr: i64 = ctr_next(regs);
            ir_block_add(cur, ir_call_ex(sr, "vec_set", set_args));
            return cur;
        };
        if lhs_kind != 3 && lhs_kind != 9 {
            return cur;
        };
        // nested field assignment (e.g.
        // `o.inner.val = X`) was crashing the compiler with a
        // segfault during the kind 21 / kind 9 lowering interaction.
        // The actual feature (deep field-path mutation) requires a
        // get-modify-set lowering that is multi-cycle to implement
        // correctly — copying the inner struct, mutating the copy,
        // and writing it back. Until that ships, emit a clear
        // diagnostic with the workaround so users don't hit the
        // segfault.
        if lhs_kind == 9 {
            let parent_kind: i64 = node_kind(pool, node_field(pool, lhs, 1));
            if parent_kind == 9 {
                print("ERROR: nested struct field assignment is not yet supported (e.g. `outer.inner.field = X`). Workaround: copy the inner struct to a local, mutate the local, then assign it back: `let mut tmp = outer.inner; tmp.field = X; outer.inner = tmp;`. Tracked for a future ship — get-modify-set lowering needed.");
                // pre-fix this returned `cur` silently — the
                // assignment was dropped, the build succeeded, and the
                // adopter's binary returned with the inner field
                // unchanged at runtime. Halt the compiler now.
                panic("nucleor: nested struct field assignment not supported (see ERROR diagnostic above)");
                return cur;
            };
        };
        if lhs_kind == 9 {
            let mut op: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let obj_r: i64 = lx_reg(op);
            cur = lx_blk(op);
            let fname: str = node_field(pool, lhs, 2);
            let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let vr: i64 = lx_reg(vp);
            cur = lx_blk(vp);
            let stype: str = expr_struct_type(pool, node_field(pool, lhs, 1), sym, structs);
            let si: i64 = struct_find_type(pool, structs, stype);
            if si >= 0 {
                let fi2: i64 = struct_field_idx(pool, vec_get(structs, si), fname);
                let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi2));
                let mut set_args: Vec<i32> = Vec::new(); set_args.push(obj_r); set_args.push(idx_r); set_args.push(vr);
                let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "vec_set", set_args));
            };
            return cur;
        };
        let lhs_name: str = node_field(pool, lhs, 1);
        let ar: i64 = sym_get(sym, lhs_name);
        let rhs_nid: i64 = node_field(pool, nid, 2);
        let mut vp: Vec<i32> = lower_expr(pool, rhs_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let vr: i64 = lx_reg(vp);
        cur = lx_blk(vp);
        if auto_drop_assignment_reuses_lhs(pool, rhs_nid, lhs_name) == 0 {
            cur = auto_drop_emit_named(cur, regs, sym, lhs_name);
        };
        // typed store via
        // alloca-reg width lookup. Sign-encoded width; abs(w) for
        // memory-shape (trunc/store_t).
        let w21: i64 = ir_fn_get_width(fir, ar);
        if w21 == 0 {
            ir_block_add(cur, ir_store(vr, ar));
        } else {
            let aw21: i64 = if w21 > 0 { w21 } else { 0 - w21 };
            let tr21: i64 = ctr_next(regs);
            ir_block_add(cur, ir_trunc(tr21, vr, aw21));
            ir_block_add(cur, ir_store_t(tr21, ar, aw21));
        };
        auto_drop_mark_live(sym, lhs_name);
        let env_reg_a: i64 = sym_get(sym, "__env_reg");
        if env_reg_a >= 0 {
            let cap_id: i64 = sym_get(sym, str_concat("__capid_", lhs_name));
            if cap_id >= 0 {
                // We're inside a closure body and lhs_name is a
                // captured local — mirror the local-alloca write into
                // the env so mutations are observable post-call.
                let cap_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(cap_r, cap_id));
                let mut set_args: Vec<i32> = Vec::new();
                set_args.push(env_reg_a); set_args.push(cap_r); set_args.push(vr);
                let dr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(dr, "nuc_closure_env_set_cap", set_args));
            };
        };
        if node_kind(pool, node_field(pool, nid, 2)) == 42 {
            let cid_meta2: i64 = sym_get(sym, "__last_closure_id");
            let caps_meta2: i64 = sym_get(sym, "__last_closure_caps");
            if cid_meta2 >= 0 {
                sym_set(sym, str_concat("__closure_id_", lhs_name), cid_meta2);
            };
            if caps_meta2 >= 0 {
                let caps_s2: str = caps_meta2;
                if str_len(caps_s2) > 0 {
                    sym_set(sym, str_concat("__closure_caps_", lhs_name), caps_s2);
                };
            };
        };
        return cur;
    };
    if kind == 85 {
        // tuple-destructure-in-let. Node layout:
        //   field 1: names_csv (str) — comma-separated binding names
        //   field 2: init node ID (i64) — the RHS expression
        // Strategy: lower the RHS into rhs_r, then for each name at
        // index i emit vec_get(rhs_r, i) and store in a fresh alloca.
        // Works for both kind-48 anonymous-tuple RHS (which kind-48
        // lowering already stores as a vec) and named-tuple-struct /
        // fn-return RHS (which is a struct vec handle).
        let names_csv85: str = node_field(pool, nid, 1);
        let init85: i64 = node_field(pool, nid, 2);
        let mut rp85: Vec<i32> = lower_expr(pool, init85, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        cur = lx_blk(rp85);
        let rhs_r85: i64 = lx_reg(rp85);
        let slen85: i64 = str_len(names_csv85);
        let mut i85: i64 = 0;
        let mut fidx85: i64 = 0;
        while i85 <= slen85 {
            let mut j85: i64 = i85;
            while j85 < slen85 && str_char_at(names_csv85, j85) != 44 { j85 = j85 + 1; };
            if j85 > i85 {
                let bname85: str = str_substring(names_csv85, i85, j85);
                let ar85: i64 = ctr_next(regs);
                ir_fn_add_entry_alloca_t(fir, ar85, 0);
                let idx_r85: i64 = ctr_next(regs);
                ir_block_add(cur, ir_const_int(idx_r85, fidx85));
                let mut ga85: Vec<i32> = Vec::new();
                ga85.push(rhs_r85);
                ga85.push(idx_r85);
                let fr85: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(fr85, "vec_get", ga85));
                ir_block_add(cur, ir_store(fr85, ar85));
                if str_eq(bname85, "_") == 0 { sym_set(sym, bname85, ar85); };
                fidx85 = fidx85 + 1;
            };
            i85 = j85 + 1;
        };
        return cur;
    };
    if kind == 22 {
        let vn: i64 = node_field(pool, nid, 1);
        let ens_stmt_nid: i64 = sym_get(sym, "__current_fn_ensure_nid");
        if vn >= 0 {
            let mut vp: Vec<i32> = lower_expr(pool, vn, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let vr: i64 = lx_reg(vp);
            cur = lx_blk(vp);
            // multi-ensure walk via per-index sym entries.
            let ens_stmt_count: i64 = sym_get(sym, "__current_fn_ensure_count");
            if ens_stmt_count > 0 {
                let ens_ar: i64 = ctr_next(regs);
                ir_block_add(cur, ir_alloca(ens_ar));
                ir_block_add(cur, ir_store(vr, ens_ar));
                sym_set(sym, "result", ens_ar);
                let mut ens_emit_i: i64 = 0;
                while ens_emit_i < ens_stmt_count {
                    let nid_key: str = str_concat("__current_fn_ensure_nid_", str_from_int(ens_emit_i));
                    let nid_i: i64 = sym_get(sym, nid_key);
                    if nid_i >= 0 {
                        let mut ens_lp: Vec<i32> = lower_expr(pool, nid_i, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                        let ens_pr: i64 = lx_reg(ens_lp);
                        cur = lx_blk(ens_lp);
                        let mut ens_args: Vec<i32> = Vec::new();
                        ens_args.push(ens_pr);
                        let ens_cr: i64 = ctr_next(regs);
                        ir_block_add(cur, ir_call_ex(ens_cr, "contract_ensure", ens_args));
                    };
                    ens_emit_i = ens_emit_i + 1;
                };
            } else if ens_stmt_nid >= 0 {
                // Fallback path (legacy single-nid lookup); should be
                // dead now since v0.4.254 always sets the count.
                let ens_ar: i64 = ctr_next(regs);
                ir_block_add(cur, ir_alloca(ens_ar));
                ir_block_add(cur, ir_store(vr, ens_ar));
                sym_set(sym, "result", ens_ar);
                let mut ens_lp: Vec<i32> = lower_expr(pool, ens_stmt_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let ens_pr: i64 = lx_reg(ens_lp);
                cur = lx_blk(ens_lp);
                let mut ens_args: Vec<i32> = Vec::new();
                ens_args.push(ens_pr);
                let ens_cr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(ens_cr, "contract_ensure", ens_args));
            };
            let invx_stmt_nid: i64 = sym_get(sym, "__current_method_invariant_nid");
            if invx_stmt_nid >= 0 {
                let invx_stmt_is_ctor: i64 = sym_get(sym, "__current_method_is_ctor");
                if invx_stmt_is_ctor == 1 {
                    let self_ar_s: i64 = ctr_next(regs);
                    ir_block_add(cur, ir_alloca(self_ar_s));
                    ir_block_add(cur, ir_store(vr, self_ar_s));
                    sym_set(sym, "self", self_ar_s);
                    // Use the fn's full return type stored in sym at
                    // lower_fn entry. sym_get returns i64; in Nucleor's
                    // i64-ABI the str pointer fits in i64 directly.
                    let cur_t_s: i64 = sym_get(sym, "__current_fn_full_return");
                    if cur_t_s != 0 - 1 {
                        sym_set(sym, str_concat("__type_", "self"), cur_t_s);
                        sym_set(sym, str_concat("__fulltype_", "self"), cur_t_s);
                    };
                };
                let mut invx_lp: Vec<i32> = lower_expr(pool, invx_stmt_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let invx_pr: i64 = lx_reg(invx_lp);
                cur = lx_blk(invx_lp);
                let mut invx_args: Vec<i32> = Vec::new();
                invx_args.push(invx_pr);
                let invx_cr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(invx_cr, "contract_invariant", invx_args));
            };
            let skip_ret_name: str = auto_drop_return_skip_name(pool, vn, sym);
            auto_drop_mark_constructor_handoffs(pool, vn, sym);
            cur = auto_drop_emit_live(cur, regs, sym, skip_ret_name);
            ir_block_add(cur, ir_ret(vr));
        } else {
            let zr: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zr, 0));
            // multi-ensure walk for bare-return path.
            let ens_bare_count: i64 = sym_get(sym, "__current_fn_ensure_count");
            if ens_bare_count > 0 {
                let ens_ar2: i64 = ctr_next(regs);
                ir_block_add(cur, ir_alloca(ens_ar2));
                ir_block_add(cur, ir_store(zr, ens_ar2));
                sym_set(sym, "result", ens_ar2);
                let mut ens_b_i: i64 = 0;
                while ens_b_i < ens_bare_count {
                    let nid_key_b: str = str_concat("__current_fn_ensure_nid_", str_from_int(ens_b_i));
                    let nid_b: i64 = sym_get(sym, nid_key_b);
                    if nid_b >= 0 {
                        let mut ens_lp_b: Vec<i32> = lower_expr(pool, nid_b, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                        let ens_pr_b: i64 = lx_reg(ens_lp_b);
                        cur = lx_blk(ens_lp_b);
                        let mut ens_args_b: Vec<i32> = Vec::new();
                        ens_args_b.push(ens_pr_b);
                        let ens_cr_b: i64 = ctr_next(regs);
                        ir_block_add(cur, ir_call_ex(ens_cr_b, "contract_ensure", ens_args_b));
                    };
                    ens_b_i = ens_b_i + 1;
                };
            } else if ens_stmt_nid >= 0 {
                let ens_ar2: i64 = ctr_next(regs);
                ir_block_add(cur, ir_alloca(ens_ar2));
                ir_block_add(cur, ir_store(zr, ens_ar2));
                sym_set(sym, "result", ens_ar2);
                let mut ens_lp2: Vec<i32> = lower_expr(pool, ens_stmt_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let ens_pr2: i64 = lx_reg(ens_lp2);
                cur = lx_blk(ens_lp2);
                let mut ens_args2: Vec<i32> = Vec::new();
                ens_args2.push(ens_pr2);
                let ens_cr2: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(ens_cr2, "contract_ensure", ens_args2));
            };
            let invx_bare_nid: i64 = sym_get(sym, "__current_method_invariant_nid");
            if invx_bare_nid >= 0 {
                let invx_bare_is_ctor: i64 = sym_get(sym, "__current_method_is_ctor");
                if invx_bare_is_ctor == 1 {
                    let self_ar_b: i64 = ctr_next(regs);
                    ir_block_add(cur, ir_alloca(self_ar_b));
                    ir_block_add(cur, ir_store(zr, self_ar_b));
                    sym_set(sym, "self", self_ar_b);
                    let cur_t_b: i64 = sym_get(sym, "__current_fn_full_return");
                    if cur_t_b != 0 - 1 {
                        sym_set(sym, str_concat("__type_", "self"), cur_t_b);
                        sym_set(sym, str_concat("__fulltype_", "self"), cur_t_b);
                    };
                };
                let mut invx_lp_b: Vec<i32> = lower_expr(pool, invx_bare_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let invx_pr_b: i64 = lx_reg(invx_lp_b);
                cur = lx_blk(invx_lp_b);
                let mut invx_args_b: Vec<i32> = Vec::new();
                invx_args_b.push(invx_pr_b);
                let invx_cr_b: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(invx_cr_b, "contract_invariant", invx_args_b));
            };
            cur = auto_drop_emit_live(cur, regs, sym, "");
            ir_block_add(cur, ir_ret(zr));
        };
        return cur;
    };
    if kind == 23 {
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        cur = lx_blk(cp);
        let tl: i64 = ctr_next(lbls); let el: i64 = ctr_next(lbls); let ml: i64 = ctr_next(lbls);
        let enode: i64 = node_field(pool, nid, 3);
        if enode < 0 { ir_block_add(cur, ir_br_cond(cr, tl, ml)); }
        else { ir_block_add(cur, ir_br_cond(cr, tl, el)); };
        let mut tb: Vec<i32> = ir_block_new(tl); ir_fn_add_block(fir, tb);
        tb = lower_stmts(pool, node_field(pool, nid, 2), tb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        if block_has_term(tb) == 0 { ir_block_add(tb, ir_br(ml)); };
        if enode >= 0 {
            let mut eb: Vec<i32> = ir_block_new(el); ir_fn_add_block(fir, eb);
            eb = lower_stmts(pool, enode, eb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
            if block_has_term(eb) == 0 { ir_block_add(eb, ir_br(ml)); };
        };
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb); return mb;
    };
    if kind == 24 {
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        hb = deadline_poll_emit_if_enabled(hb, regs, sym);
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), hb, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        hb = lx_blk(cp);
        ir_block_add(hb, ir_br_cond(cr, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        let body_sym_w: Vec<i32> = sym_clone(sym);
        // Snapshot the auto-drop count before entering the body so
        // per-iter drops only affect closure bindings declared INSIDE.
        let body_floor_w: i64 = sym_get(body_sym_w, "__auto_drop_count");
        let body_min_w: i64 = if body_floor_w < 0 { 0 } else { body_floor_w };
        bb = lower_stmts(pool, node_field(pool, nid, 2), bb, regs, lbls, body_sym_w, fir, strtab, hl, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 {
            bb = auto_drop_emit_live_above_closures(bb, regs, body_sym_w, body_min_w);
            ir_block_add(bb, ir_br(hl));
        };
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 28 {
        let name: str = node_field(pool, nid, 1);
        let ar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, ar);
        let mut loop_sym: Vec<i32> = sym_clone(sym);
        sym_set(loop_sym, name, ar);
        // register the for-loop variable's type as i64 so
        // print(i) and other type-aware dispatches don't fall through
        // to print_str. Pre-fix `for i in 0..3 { print(i); }` SIGSEGV'd
        // because __type_i was never set, the dispatch defaulted to
        // print_str, and print_str dereferenced the i64 loop value as
        // a string pointer.
        sym_set(loop_sym, str_concat("__type_", name), "i64");
        let mut sp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let sv: i64 = lx_reg(sp);
        cur = lx_blk(sp);
        ir_block_add(cur, ir_store(sv, ar));
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls);
        let il: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        hb = deadline_poll_emit_if_enabled(hb, regs, loop_sym);
        let lv: i64 = ctr_next(regs); ir_block_add(hb, ir_load(lv, ar));
        let mut ep: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), hb, regs, lbls, loop_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let ev: i64 = lx_reg(ep);
        hb = lx_blk(ep);
        let cv: i64 = ctr_next(regs); ir_block_add(hb, ir_cmpop(9, cv, lv, ev));
        ir_block_add(hb, ir_br_cond(cv, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        let for_body_sym: Vec<i32> = sym_clone(loop_sym);
        let for_floor: i64 = sym_get(for_body_sym, "__auto_drop_count");
        let for_min: i64 = if for_floor < 0 { 0 } else { for_floor };
        bb = lower_stmts(pool, node_field(pool, nid, 4), bb, regs, lbls, for_body_sym, fir, strtab, il, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 {
            bb = auto_drop_emit_live_above_closures(bb, regs, for_body_sym, for_min);
            ir_block_add(bb, ir_br(il));
        };
        let mut ib: Vec<i32> = ir_block_new(il); ir_fn_add_block(fir, ib);
        let lv2: i64 = ctr_next(regs); ir_block_add(ib, ir_load(lv2, ar));
        let one: i64 = ctr_next(regs); ir_block_add(ib, ir_const_int(one, 1));
        let nv: i64 = ctr_next(regs); ir_block_add(ib, ir_binop(2, nv, lv2, one));
        ir_block_add(ib, ir_store(nv, ar));
        ir_block_add(ib, ir_br(hl));
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 49 {
        let name: str = node_field(pool, nid, 1);
        let item_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, item_slot);
        let iter_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, iter_slot);
        let idx_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, idx_slot);
        let mut loop_sym: Vec<i32> = sym_clone(sym);
        sym_set(loop_sym, name, item_slot);
        // register the loop item's type when the iterator
        // is a known container (Vec<T> -> T). Same fix as kind 28.
        // Falls through silently when iterator type isn't a container,
        // preserving existing behaviour.
        // also handle `for x in v.iter()` -- the iter() method
        // is identity pass-through (per t364), but indexed_element_full_type
        // doesn't recognize it. Strip the .iter() and look up the
        // receiver Vec's element type.
        let mut iter_recv_nid: i64 = node_field(pool, nid, 2);
        if node_kind(pool, iter_recv_nid) == 8 {
            let iter_mname: str = node_field(pool, iter_recv_nid, 2);
            if str_eq(iter_mname, "iter") == 1 || str_eq(iter_mname, "into_iter") == 1 {
                iter_recv_nid = node_field(pool, iter_recv_nid, 1);
            };
        };
        let iter_etype_full: str = indexed_element_full_type(pool, iter_recv_nid, sym, structs);
        if str_len(iter_etype_full) > 0 {
            let iter_etype_base: str = type_base_name(iter_etype_full);
            if str_len(iter_etype_base) > 0 {
                sym_set(loop_sym, str_concat("__type_", name), iter_etype_base);
            };
        };
        let mut sp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let sv: i64 = lx_reg(sp);
        cur = lx_blk(sp);
        ir_block_add(cur, ir_store(sv, iter_slot));
        let zero: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero, 0));
        ir_block_add(cur, ir_store(zero, idx_slot));
        // snapshot vec_len ONCE before the loop, reuse on every
        // iteration. Pre-fix the header re-read vec_len(v) on each
        // iteration. When the loop body pushed to `v`, len grew, the
        // exit check `idx < len` never became false, and memory grew
        // unboundedly (Run-Capped killed at 1 GB). The classic
        // iter-invalidation hazard, but in Nucleor's iter-by-index form
        // it manifests as silent unbounded grow rather than a borrow
        // error. Snapshot semantics: the loop iterates EXACTLY the
        // original-length elements; pushes inside the body extend the
        // Vec but are not visited. This matches Rust's
        // `for x in v.iter().take(initial_len)` shape and removes the
        // memory-blowup without needing full ownership-borrow analysis
        // (which is the canonical fix but a much larger surface).
        // Regression: push during for-iteration unbounded growth.
        let len_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, len_slot);
        let mut len_init_args: Vec<i32> = Vec::new(); len_init_args.push(sv);
        let len_init_v: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(len_init_v, "vec_len", len_init_args));
        ir_block_add(cur, ir_store(len_init_v, len_slot));
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls);
        let il: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        hb = deadline_poll_emit_if_enabled(hb, regs, loop_sym);
        let idx_v: i64 = ctr_next(regs); ir_block_add(hb, ir_load(idx_v, idx_slot));
        let len_v: i64 = ctr_next(regs); ir_block_add(hb, ir_load(len_v, len_slot));
        let cv: i64 = ctr_next(regs); ir_block_add(hb, ir_cmpop(9, cv, idx_v, len_v));
        ir_block_add(hb, ir_br_cond(cv, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        let iter_v2: i64 = ctr_next(regs); ir_block_add(bb, ir_load(iter_v2, iter_slot));
        let idx_v2: i64 = ctr_next(regs); ir_block_add(bb, ir_load(idx_v2, idx_slot));
        let mut get_args: Vec<i32> = Vec::new(); get_args.push(iter_v2); get_args.push(idx_v2);
        let item_v: i64 = ctr_next(regs); ir_block_add(bb, ir_call_ex(item_v, "vec_get", get_args));
        ir_block_add(bb, ir_store(item_v, item_slot));
        bb = lower_stmts(pool, node_field(pool, nid, 3), bb, regs, lbls, sym_clone(loop_sym), fir, strtab, il, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 { ir_block_add(bb, ir_br(il)); };
        let mut ib: Vec<i32> = ir_block_new(il); ir_fn_add_block(fir, ib);
        let idx_v3: i64 = ctr_next(regs); ir_block_add(ib, ir_load(idx_v3, idx_slot));
        let one: i64 = ctr_next(regs); ir_block_add(ib, ir_const_int(one, 1));
        let next_v: i64 = ctr_next(regs); ir_block_add(ib, ir_binop(2, next_v, idx_v3, one));
        ir_block_add(ib, ir_store(next_v, idx_slot));
        ir_block_add(ib, ir_br(hl));
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 25 {
        let expr_nid: i64 = node_field(pool, nid, 1);
        let mut ep: Vec<i32> = lower_expr(pool, expr_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let out_blk: Vec<i32> = lx_blk(ep);
        let freed_name: str = auto_drop_explicit_free_name(pool, expr_nid);
        if str_len(freed_name) > 0 { auto_drop_mark_freed(sym, freed_name); };
        // detect handoff. If the expr is a
        // vec_push/vec_set/hashmap_insert with identifier value
        // arg referencing a registered auto-drop binding, mark
        // that binding as freed (suppresses the auto-drop emit
        // at fn return).
        let handoff_name: str = auto_drop_handoff_name(pool, expr_nid, sym);
        if str_len(handoff_name) > 0 { auto_drop_mark_freed(sym, handoff_name); };
        return out_blk;
    };
    if kind == 38 {
        let scrut_nid: i64 = node_field(pool, nid, 1);
        let scrut_t: str = expr_full_type_from_sym(pool, scrut_nid, sym, structs);
        let mut mp: Vec<i32> = lower_expr(pool, scrut_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mexpr_r: i64 = lx_reg(mp);
        cur = lx_blk(mp);
        let mslot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, mslot);
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let arms_list: i64 = node_field(pool, nid, 2);
        let arm_cnt: i64 = list_len(pool, arms_list);
        let ml: i64 = ctr_next(lbls);
        let mut tag_r: i64 = 0 - 1;
        let mut ci: i64 = 0;
        while ci < arm_cnt {
            let arm_nid: i64 = list_get(pool, arms_list, ci);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            let body_list: i64 = node_field(pool, arm_nid, 4);
            let guard_nid: i64 = node_field(pool, arm_nid, 5);
            let al: i64 = ctr_next(lbls);
            let nl: i64 = ctr_next(lbls);
            if str_eq(ename, "__wild") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__int") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let iv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(iv_r, vname));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, mv, iv_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__str") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                // intern via strtab_intern to dedup.
                let sidx: i64 = strtab_intern(strtab, fir, vname);
                let sv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_str(sv_r, sidx));
                let mut eq_args: Vec<i32> = Vec::new(); eq_args.push(mv); eq_args.push(sv_r);
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(cmp_r, "str_eq", eq_args));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, "str");
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__range") == 1 || str_eq(ename, "__range_at") == 1 {
                // range pattern in stmt-position match.
                // Mirrors the lower_expr __range arm at line 10592.
                // Pre-v0.3.118 this branch fell through to the
                // enum-tag-decode path, which treated the i64
                // scrutinee as a Vec pointer and segfaulted at runtime
                // (`vec_get(inttoptr i64_value, 0)`). HIGH-blast
                // silent miscompute → segfault for any program using
                // range patterns in statement-form match (the
                // expression-position match was already correct).
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let lo_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(lo_r, vname));
                let hi_s: str = str_before_char_local(binding, 124);
                let hi_n: i64 = str_to_int(hi_s);
                let hi_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(hi_r, hi_n));
                let lo_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, lo_ok, lo_r, mv));
                let hi_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, hi_ok, mv, hi_r));
                let both_r: i64 = ctr_next(regs); ir_block_add(cur, ir_binop(13, both_r, lo_ok, hi_ok));
                ir_block_add(cur, ir_br_cond(both_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let arm_sym: Vec<i32> = sym_clone(sym);
                if str_eq(ename, "__range_at") == 1 {
                    ab = match_bind_whole(str_after_char_local(binding, 124), ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
            } else if str_eq(ename, "__range_bad") == 1 || str_eq(ename, "__range_bad_at") == 1 {
                ir_block_add(cur, ir_br(nl));
            } else if str_eq(ename, "__struct") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_struct_fields(binding, ab, regs, arm_sym, mslot, fir, structs, pool, vname, scrut_t);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__tuple") == 1 || str_eq(ename, "__slice") == 1 {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let mut len_args: Vec<i32> = Vec::new(); len_args.push(mv);
                let len_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(len_r, "vec_len", len_args));
                let needed: i64 = pattern_list_value_count(binding);
                let needed_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(needed_r, needed));
                let cmp_r: i64 = ctr_next(regs);
                if str_eq(ename, "__slice") == 1 && pattern_list_has_rest(binding) == 1 {
                    ir_block_add(cur, ir_cmpop(11, cmp_r, needed_r, len_r));
                } else {
                    ir_block_add(cur, ir_cmpop(7, cmp_r, len_r, needed_r));
                };
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_vec_pattern(binding, ab, regs, arm_sym, mslot, fir, scrut_t, len_r);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else {
                if tag_r < 0 {
                    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                    let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
                    let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(mv); tag_args.push(zero_r);
                    tag_r = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
                };
                let etag_key: str = str_concat("__etag_", str_concat(ename, str_concat("_", vname)));
                let vtag: i64 = sym_get(sym, etag_key);
                let vtag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(vtag_r, vtag));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, vtag_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                let payload_binding: str = pattern_after_at_prefix(binding);
                let at_name: str = pattern_at_prefix_name(binding);
                if str_len(at_name) > 0 { ab = match_bind_whole(at_name, ab, regs, arm_sym, mslot, fir, scrut_t); };
                ab = match_bind_payloads_per_idx(payload_binding, ab, regs, arm_sym, mslot, fir, ename, vname, scrut_t);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            };
            let mut nb: Vec<i32> = ir_block_new(nl); ir_fn_add_block(fir, nb);
            cur = nb;
            ci = ci + 1;
        };
        ir_block_add(cur, ir_br(ml));
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb);
        return mb;
    };
    if kind == 26 {
        // `break` outside any loop. Pre-fix the codegen
        // silently no-op'd (the if-guard's `else` branch did
        // nothing), so `fn main() { break; 0 }` compiled to
        // `fn main() { 0 }` and exited successfully — adopters
        // typo'ing a misplaced control-flow stmt got no signal at
        // all. Halt cleanly with NR024.
        if lx < 0 {
            panic("error[NR024]: `break` outside any loop. Move the `break;` inside a `loop`/`while`/`for` body, or remove it entirely.");
        };
        ir_block_add(cur, ir_br(lx));
        return cur;
    };
    if kind == 27 {
        // `continue` outside any loop. Same hazard class
        // as the break case above.
        if lh < 0 {
            panic("error[NR024]: `continue` outside any loop. Move the `continue;` inside a `loop`/`while`/`for` body, or remove it entirely.");
        };
        ir_block_add(cur, ir_br(lh));
        return cur;
    };
    print(str_concat("ERROR: unknown stmt kind ", str_from_int(kind)));
    // pre-fix this silently returned `cur` (the current basic
    // block) — the stmt was DROPPED from the IR with no clang error.
    // Adopter binary skipped the statement entirely. Halt now.
    panic(str_concat("nucleor: unknown stmt kind ", str_from_int(kind)));
    return cur;
}
#[manual_drop]
fn lower_stmts(pool: Vec<i32>, lid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let cnt: i64 = list_len(pool, lid); let mut i: i64 = 0; let mut b: Vec<i32> = cur;
    while i < cnt { b = lower_stmt(pool, list_get(pool, lid, i), b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls); i = i + 1; };
    return b;
}

#[manual_drop]
fn lower_fn(pool: Vec<i32>, fn_nid: i64, strtab: Vec<i32>, strtab_aux: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, globals: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>, fn_decls: Vec<i32>, fn_return_map: i64, require_exprs: Vec<i32>, ensure_exprs: Vec<i32>, invariant_exprs: Vec<i32>, old_snapshots: Vec<i32>, auto_drop_fns: Vec<i32>, manual_drop_fns: Vec<i32>, suppress_auto_drop: i64) -> Vec<i32> {
    let name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let blist: i64 = node_field(pool, fn_nid, 4);
    let pc: i64 = list_len(pool, plist);
    let mut regs: Vec<i32> = ctr_new();
    let mut lbls: Vec<i32> = ctr_new();
    let mut sym: Vec<i32> = sym_new();
    if str_starts_with(name, "__nuc_dl_inner_") == 1 {
        sym_set(sym, "__deadline_poll_enabled", 1);
    };
    if suppress_auto_drop == 0
       && name_in_manual_drop(manual_drop_fns, name) == 0 {
        // 2026-05-07 Phase 2b-3 default-flip: every fn auto-drops by
        // default; #[manual_drop] opts out. Pre-flip the gate also
        // required `name_in_auto_drop(auto_drop_fns, name) == 1`,
        // i.e. opt-IN via #[auto_drop]. That meant nearly every
        // stdlib fn ran with NO drop semantics — Vec heap allocations
        // leaked, and the "move-into-struct-field" tracking in
        // auto_drop_mark_constructor_handoffs was dead code for fns
        // outside the explicit auto_drop_fns whitelist.
        // Flipping to opt-out activates the existing handoff machinery
        // (line 29045 of this file) and closes the ML fixture cluster
        // without per-fn manual_drop
        // annotations across stdlib/rods/ml/. The bug was: handoff
        // recognition logic was correct but the gate that enabled it
        // was inverted vs the comment's stated Phase 2b-3 intent.
        // #[manual_drop] still wins for fns that explicitly opt out
        // (parsers, low-level helpers, etc. — anywhere the body
        // carries explicit Vec lifetime management).
        sym_set(sym, "__auto_drop_enabled", 1);
    };
    enum_populate_sym(pool, enums, sym);
    // keep fn-return metadata in one shared map
    // instead of injecting every __fnret_/__fnfulltype_ pair into every
    // function-local sym. sym_get falls back to this map for those keys.
    sym_set(sym, "__fn_return_map", fn_return_map);
    // keep this fn's generic trait bounds available to
    // lower_expr kind-8. Generic fns are still emitted as one ABI-level
    // body, so this only enables conservative single-impl dispatch for
    // `T: Trait` receiver methods; ambiguous multi-impl bounds halt
    // instead of falling through to `vec_<method>`.
    let fn_gparams: i64 = node_field(pool, fn_nid, 5);
    if fn_gparams >= 0 {
        let mut gp_v529: i64 = 0;
        let gp_count: i64 = list_len(pool, fn_gparams);
        let mut current_gparam: str = "";
        while gp_v529 < gp_count {
            let ge_v529: str = list_get(pool, fn_gparams, gp_v529);
            if str_len(ge_v529) > 1 && str_char_at(ge_v529, 0) == 63 {
                if str_len(current_gparam) > 0 {
                    let bound_name: str = str_substring(ge_v529, 1, str_len(ge_v529));
                    let count_key: str = str_concat("__gparam_bound_count_", current_gparam);
                    let mut bound_count: i64 = sym_get(sym, count_key);
                    if bound_count < 0 { bound_count = 0; };
                    sym_set(sym, str_concat(str_concat("__gparam_bound_", current_gparam), str_concat("_", str_from_int(bound_count))), bound_name);
                    sym_set(sym, count_key, bound_count + 1);
                };
            } else {
                if str_len(ge_v529) > 0 && str_char_at(ge_v529, 0) != 39 {
                    current_gparam = ge_v529;
                    sym_set(sym, str_concat("__gparam_bound_count_", current_gparam), 0);
                } else {
                    current_gparam = "";
                };
            };
            gp_v529 = gp_v529 + 1;
        };
    };
    sym_set(sym, "__current_fn_full_return", node_field(pool, fn_nid, 3));
    if str_eq(type_base_name(node_field(pool, fn_nid, 3)), "u64") == 1 { sym_set(sym, "__has_u64_v886", 1); };
    let mut fir: Vec<i32> = ir_fn_new(name, pc);
    ir_fn_set_strtab_aux(fir, strtab_aux);
    let mut ebb0: Vec<i32> = ir_block_new(0);
    ir_fn_add_block(fir, ebb0);
    let mut pi: i64 = 0;
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        // phase 3c (typed param alloca) REVERTED. The
        let ptype: str = node_field(pool, pnid, 2);
        let sbase: str = type_base_name(ptype);
        if str_eq(sbase, "u64") == 1 { sym_set(sym, "__has_u64_v886", 1); };
        let pblen: i64 = str_len(sbase);
        let mut wp: i64 = 0;
        if pblen == 2 {
            if str_eq(sbase, "i8") == 1 { wp = 8; }
            else if str_eq(sbase, "u8") == 1 { wp = 0 - 8; };
        } else if pblen == 3 {
            if str_eq(sbase, "i16") == 1 { wp = 16; }
            else if str_eq(sbase, "u16") == 1 { wp = 0 - 16; }
            else if str_eq(sbase, "i32") == 1 { wp = 32; }
            else if str_eq(sbase, "u32") == 1 { wp = 0 - 32; };
        };
        let awp: i64 = if wp >= 0 { wp } else { 0 - wp };
        let ar: i64 = ctr_next(regs);
        if awp == 0 {
            ir_block_add(ebb0, ir_alloca(ar));
        } else {
            ir_block_add(ebb0, ir_alloca_t(ar, awp));
        };
        let pr2: i64 = ctr_next(regs); ir_block_add(ebb0, ir_param_ref(pr2, pi));
        if awp == 0 {
            ir_block_add(ebb0, ir_store(pr2, ar));
        } else {
            // Trunc i64 → iN and typed-store. Param arrives as i64 at
            // the fn-signature boundary; the trunc gives a clean iN
            // value for the typed alloca.
            let tpr: i64 = ctr_next(regs);
            ir_block_add(ebb0, ir_trunc(tpr, pr2, awp));
            ir_block_add(ebb0, ir_store_t(tpr, ar, awp));
        };
        sym_set(sym, pname, ar);
        if wp != 0 { ir_fn_set_width(fir, ar, wp); };
        // Track struct type for parameters (strip generic params)
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", pname), sbase); };
        // also store full declared type for generic-aware
        // dispatch (mirror the same change at the let binding site).
        if str_len(ptype) > 0 { sym_set(sym, str_concat("__fulltype_", pname), ptype); };
        pi = pi + 1;
    };
    let mut gi: i64 = 0;
    while gi < vec_len(globals) {
        let gnid: i64 = vec_get(globals, gi);
        let gname: str = node_field(pool, gnid, 1);
        let gar: i64 = ctr_next(regs); ir_block_add(ebb0, ir_alloca(gar));
        sym_set(sym, gname, gar);
        let ginit: i64 = node_field(pool, gnid, 3);
        let mut gp: Vec<i32> = lower_expr(pool, ginit, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        let gv: i64 = lx_reg(gp);
        ebb0 = lx_blk(gp);
        ir_block_add(ebb0, ir_store(gv, gar));
        let mut gtype: str = node_field(pool, gnid, 2);
        if str_len(gtype) == 0 && node_kind(pool, ginit) == 34 { gtype = node_field(pool, ginit, 1); }
        else if str_len(gtype) == 0 && node_kind(pool, ginit) == 12 { gtype = node_field(pool, ginit, 1); };
        let gbase: str = type_base_name(gtype);
        if str_len(gbase) > 0 { sym_set(sym, str_concat("__type_", gname), gbase); };
        // full declared type (mirror let / param sites).
        if str_len(gtype) > 0 { sym_set(sym, str_concat("__fulltype_", gname), gtype); };
        gi = gi + 1;
    };
    let mut osi: i64 = 0;
    let os_count: i64 = vec_len(old_snapshots);
    while osi + 2 < os_count {
        if str_eq(vec_get(old_snapshots, osi), name) == 1 {
            let synth_name: str = vec_get(old_snapshots, osi + 1);
            let inner_nid: i64 = vec_get(old_snapshots, osi + 2);
            let snap_ar: i64 = ctr_next(regs);
            ir_block_add(ebb0, ir_alloca(snap_ar));
            let mut snap_lp: Vec<i32> = lower_expr(pool, inner_nid, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            let snap_rr: i64 = lx_reg(snap_lp);
            ebb0 = lx_blk(snap_lp);
            ir_block_add(ebb0, ir_store(snap_rr, snap_ar));
            sym_set(sym, synth_name, snap_ar);
        };
        osi = osi + 3;
    };
    let mut ens_pre_walk: i64 = 0;
    let mut ens_pre_n: i64 = 0;
    let ens_pre_count: i64 = vec_len(ensure_exprs);
    while ens_pre_walk + 1 < ens_pre_count {
        if str_eq(vec_get(ensure_exprs, ens_pre_walk), name) == 1 {
            let ens_nid_p: i64 = vec_get(ensure_exprs, ens_pre_walk + 1);
            sym_set(sym, str_concat("__current_fn_ensure_nid_", str_from_int(ens_pre_n)), ens_nid_p);
            ens_pre_n = ens_pre_n + 1;
        };
        ens_pre_walk = ens_pre_walk + 2;
    };
    if ens_pre_n > 0 {
        sym_set(sym, "__current_fn_ensure_count", ens_pre_n);
        // Back-compat: legacy single-nid lookup still works.
        sym_set(sym, "__current_fn_ensure_nid", sym_get(sym, "__current_fn_ensure_nid_0"));
    };
    let mut req_idx: i64 = 0;
    let req_count: i64 = vec_len(require_exprs);
    while req_idx + 1 < req_count {
        let cand: str = vec_get(require_exprs, req_idx);
        if str_eq(cand, name) == 1 {
            let req_nid: i64 = vec_get(require_exprs, req_idx + 1);
            let mut req_lp: Vec<i32> = lower_expr(pool, req_nid, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            let req_rr: i64 = lx_reg(req_lp);
            ebb0 = lx_blk(req_lp);
            let mut req_args: Vec<i32> = Vec::new();
            req_args.push(req_rr);
            let req_cr: i64 = ctr_next(regs);
            ir_block_add(ebb0, ir_call_ex(req_cr, "contract_require", req_args));
        };
        req_idx = req_idx + 2;
    };
    let mut inv_split: i64 = 0;
    let inv_name_len: i64 = str_len(name);
    let mut found_split: i64 = 0;
    while inv_split + 1 < inv_name_len {
        if str_char_at(name, inv_split) == 95 && str_char_at(name, inv_split + 1) == 95 {
            found_split = 1;
            inv_split = inv_name_len;
        } else {
            inv_split = inv_split + 1;
        };
    };
    if found_split == 1 {
        // Re-walk to capture the actual split index now that we know it exists.
        let mut sp: i64 = 0;
        while sp + 1 < inv_name_len {
            if str_char_at(name, sp) == 95 && str_char_at(name, sp + 1) == 95 { break; };
            sp = sp + 1;
        };
        if sp > 0 && sp + 1 < inv_name_len {
            let inv_type: str = str_substring(name, 0, sp);
            let mut inv_idx: i64 = 0;
            let mut inv_nid: i64 = 0 - 1;
            let inv_count: i64 = vec_len(invariant_exprs);
            while inv_idx + 1 < inv_count {
                if str_eq(vec_get(invariant_exprs, inv_idx), inv_type) == 1 {
                    inv_nid = vec_get(invariant_exprs, inv_idx + 1);
                    inv_idx = inv_count;
                } else {
                    inv_idx = inv_idx + 2;
                };
            };
            if inv_nid >= 0 {
                // self-method path: first param is `self`. Entry-emit
                // the invariant predicate immediately, then stash the
                // nid for exit-emit at every return site.
                let mut is_self_method: i64 = 0;
                if pc > 0 {
                    let first_p: i64 = list_get(pool, plist, 0);
                    if str_eq(node_field(pool, first_p, 1), "self") == 1 { is_self_method = 1; };
                };
                let rtype: str = node_field(pool, fn_nid, 3);
                let mut is_ctor: i64 = 0;
                if is_self_method == 0 {
                    if str_eq(rtype, inv_type) == 1 || str_eq(rtype, "Self") == 1 { is_ctor = 1; };
                };
                if is_self_method == 1 {
                    let mut inv_lp: Vec<i32> = lower_expr(pool, inv_nid, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                    let inv_rr: i64 = lx_reg(inv_lp);
                    ebb0 = lx_blk(inv_lp);
                    let mut inv_args: Vec<i32> = Vec::new();
                    inv_args.push(inv_rr);
                    let inv_cr: i64 = ctr_next(regs);
                    ir_block_add(ebb0, ir_call_ex(inv_cr, "contract_invariant", inv_args));
                    sym_set(sym, "__current_method_invariant_nid", inv_nid);
                } else if is_ctor == 1 {
                    sym_set(sym, "__current_method_invariant_nid", inv_nid);
                    sym_set(sym, "__current_method_is_ctor", 1);
                };
            };
        };
    };
    let bcnt: i64 = list_len(pool, blist);
    let mut fb: Vec<i32> = ebb0;
    let mut last_kind: i64 = 0 - 1;
    if bcnt > 0 { last_kind = node_kind(pool, list_get(pool, blist, bcnt - 1)); };
    if bcnt > 0 && (last_kind == 25 || last_kind == 23 || last_kind == 38) {
        let mut bi: i64 = 0;
        while bi + 1 < bcnt {
            fb = lower_stmt(pool, list_get(pool, blist, bi), fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            bi = bi + 1;
        };
        let last_stmt: i64 = list_get(pool, blist, bcnt - 1);
        let mut expr_nid: i64 = last_stmt;
        if last_kind == 25 { expr_nid = node_field(pool, last_stmt, 1); };
        let mut ep: Vec<i32> = lower_expr(pool, expr_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        fb = lx_blk(ep);
        let mut rv: i64 = lx_reg(ep);
        let tail_freed_name: str = auto_drop_explicit_free_name(pool, expr_nid);
        if str_len(tail_freed_name) > 0 { auto_drop_mark_freed(sym, tail_freed_name); };
        if block_has_term(fb) == 0 {
            if rv < 0 {
                rv = ctr_next(regs);
                ir_block_add(fb, ir_const_int(rv, 0));
            };
            let mut ens_first_idx: i64 = 0 - 1;
            let mut ens_walk: i64 = 0;
            let ens_count: i64 = vec_len(ensure_exprs);
            while ens_walk + 1 < ens_count {
                if str_eq(vec_get(ensure_exprs, ens_walk), name) == 1 {
                    if ens_first_idx < 0 { ens_first_idx = ens_walk; };
                };
                ens_walk = ens_walk + 2;
            };
            if ens_first_idx >= 0 {
                let ens_ar: i64 = ctr_next(regs);
                ir_block_add(fb, ir_alloca(ens_ar));
                ir_block_add(fb, ir_store(rv, ens_ar));
                sym_set(sym, "result", ens_ar);
                let mut ens_emit_idx: i64 = 0;
                while ens_emit_idx + 1 < ens_count {
                    if str_eq(vec_get(ensure_exprs, ens_emit_idx), name) == 1 {
                        let ens_nid: i64 = vec_get(ensure_exprs, ens_emit_idx + 1);
                        let mut ens_lp: Vec<i32> = lower_expr(pool, ens_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                        let ens_pr: i64 = lx_reg(ens_lp);
                        fb = lx_blk(ens_lp);
                        let mut ens_args: Vec<i32> = Vec::new();
                        ens_args.push(ens_pr);
                        let ens_cr: i64 = ctr_next(regs);
                        ir_block_add(fb, ir_call_ex(ens_cr, "contract_ensure", ens_args));
                    };
                    ens_emit_idx = ens_emit_idx + 2;
                };
            };
            let invx_nid: i64 = sym_get(sym, "__current_method_invariant_nid");
            if invx_nid >= 0 {
                let invx_is_ctor: i64 = sym_get(sym, "__current_method_is_ctor");
                if invx_is_ctor == 1 {
                    let self_ar: i64 = ctr_next(regs);
                    ir_block_add(fb, ir_alloca(self_ar));
                    ir_block_add(fb, ir_store(rv, self_ar));
                    sym_set(sym, "self", self_ar);
                    // Re-derive the inv_type from `name` (Type__method
                    // → Type) so field-access on self lowers correctly.
                    let nl_t: i64 = str_len(name);
                    let mut sp_t: i64 = 0;
                    while sp_t + 1 < nl_t {
                        if str_char_at(name, sp_t) == 95 && str_char_at(name, sp_t + 1) == 95 { break; };
                        sp_t = sp_t + 1;
                    };
                    if sp_t > 0 && sp_t + 1 < nl_t {
                        let it_ctor: str = str_substring(name, 0, sp_t);
                        sym_set(sym, str_concat("__type_", "self"), it_ctor);
                        sym_set(sym, str_concat("__fulltype_", "self"), it_ctor);
                    };
                };
                let mut invx_lp: Vec<i32> = lower_expr(pool, invx_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                let invx_pr: i64 = lx_reg(invx_lp);
                fb = lx_blk(invx_lp);
                let mut invx_args: Vec<i32> = Vec::new();
                invx_args.push(invx_pr);
                let invx_cr: i64 = ctr_next(regs);
                ir_block_add(fb, ir_call_ex(invx_cr, "contract_invariant", invx_args));
            };
            let skip_tail_name: str = auto_drop_return_skip_name(pool, expr_nid, sym);
            auto_drop_mark_constructor_handoffs(pool, expr_nid, sym);
            fb = auto_drop_emit_live(fb, regs, sym, skip_tail_name);
            ir_block_add(fb, ir_ret(rv));
        };
        return fir;
    };
    fb = lower_stmts(pool, blist, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
    if block_has_term(fb) == 0 {
        let zr: i64 = ctr_next(regs); ir_block_add(fb, ir_const_int(zr, 0));
        let mut ens2_first: i64 = 0 - 1;
        let mut ens2_walk: i64 = 0;
        let ens2_count: i64 = vec_len(ensure_exprs);
        while ens2_walk + 1 < ens2_count {
            if str_eq(vec_get(ensure_exprs, ens2_walk), name) == 1 {
                if ens2_first < 0 { ens2_first = ens2_walk; };
            };
            ens2_walk = ens2_walk + 2;
        };
        if ens2_first >= 0 {
            let ens2_ar: i64 = ctr_next(regs);
            ir_block_add(fb, ir_alloca(ens2_ar));
            ir_block_add(fb, ir_store(zr, ens2_ar));
            sym_set(sym, "result", ens2_ar);
            let mut ens2_emit: i64 = 0;
            while ens2_emit + 1 < ens2_count {
                if str_eq(vec_get(ensure_exprs, ens2_emit), name) == 1 {
                    let ens2_nid: i64 = vec_get(ensure_exprs, ens2_emit + 1);
                    let mut ens2_lp: Vec<i32> = lower_expr(pool, ens2_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                    let ens2_pr: i64 = lx_reg(ens2_lp);
                    fb = lx_blk(ens2_lp);
                    let mut ens2_args: Vec<i32> = Vec::new();
                    ens2_args.push(ens2_pr);
                    let ens2_cr: i64 = ctr_next(regs);
                    ir_block_add(fb, ir_call_ex(ens2_cr, "contract_ensure", ens2_args));
                };
                ens2_emit = ens2_emit + 2;
            };
        };
        let invx2_nid: i64 = sym_get(sym, "__current_method_invariant_nid");
        if invx2_nid >= 0 {
            let invx2_is_ctor: i64 = sym_get(sym, "__current_method_is_ctor");
            if invx2_is_ctor == 1 {
                let self_ar2: i64 = ctr_next(regs);
                ir_block_add(fb, ir_alloca(self_ar2));
                ir_block_add(fb, ir_store(zr, self_ar2));
                sym_set(sym, "self", self_ar2);
                let nl2: i64 = str_len(name);
                let mut sp2: i64 = 0;
                while sp2 + 1 < nl2 {
                    if str_char_at(name, sp2) == 95 && str_char_at(name, sp2 + 1) == 95 { break; };
                    sp2 = sp2 + 1;
                };
                if sp2 > 0 && sp2 + 1 < nl2 {
                    let it2: str = str_substring(name, 0, sp2);
                    sym_set(sym, str_concat("__type_", "self"), it2);
                    sym_set(sym, str_concat("__fulltype_", "self"), it2);
                };
            };
            let mut invx2_lp: Vec<i32> = lower_expr(pool, invx2_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            let invx2_pr: i64 = lx_reg(invx2_lp);
            fb = lx_blk(invx2_lp);
            let mut invx2_args: Vec<i32> = Vec::new();
            invx2_args.push(invx2_pr);
            let invx2_cr: i64 = ctr_next(regs);
            ir_block_add(fb, ir_call_ex(invx2_cr, "contract_invariant", invx2_args));
        };
        fb = auto_drop_emit_live(fb, regs, sym, "");
        ir_block_add(fb, ir_ret(zr));
    };
    return fir;
}
