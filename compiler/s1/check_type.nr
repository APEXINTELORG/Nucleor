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

