// gen_helper_manifest_inventory.nr
//
// Read-only native inventory prototype for tools/gen_helper_manifest.py.
//
// This is an opt-in HERM-B first slice. It inventories the source surfaces
// consumed by the Python helper-manifest generator, prints stable counts to
// stdout, and intentionally does not write docs/rfcs/helper_manifest.toml.
// Keep tools/gen_helper_manifest.py as the drift-gate generator until a later
// native port proves schema-equivalent or byte-equivalent TOML output.

// ---------- generic helpers ----------

fn find_from(s: str, needle: str, start: i64) -> i64 {
    let n: i64 = str_len(s);
    let nl: i64 = str_len(needle);
    if nl == 0 { return -1; };
    if start < 0 || start >= n { return -1; };
    if nl > n - start { return -1; };
    let rest: str = str_substring(s, start, n);
    let off: i64 = str_index_of(rest, needle);
    if off < 0 { return -1; };
    return start + off;
}

fn is_ident_char(c: i64) -> i64 {
    if c >= 97 && c <= 122 { return 1; };
    if c >= 65 && c <= 90 { return 1; };
    if c >= 48 && c <= 57 { return 1; };
    if c == 95 { return 1; };
    return 0;
}

fn str_cmp_lt(a: str, b: str) -> i64 {
    let la: i64 = str_len(a);
    let lb: i64 = str_len(b);
    let mut i: i64 = 0;
    let limit: i64 = if la < lb { la } else { lb };
    while i < limit {
        let ca: i64 = str_char_at(a, i);
        let cb: i64 = str_char_at(b, i);
        if ca < cb { return 1; };
        if ca > cb { return 0; };
        i = i + 1;
    };
    if la < lb { return 1; };
    return 0;
}

fn sort_strs(v: Vec<str>) -> i64 {
    let n: i64 = vec_len(v);
    let mut i: i64 = 1;
    while i < n {
        let key: str = vec_get(v, i);
        let mut j: i64 = i - 1;
        while j >= 0 && str_cmp_lt(vec_get(v, j), key) == 0 {
            vec_set(v, j + 1, vec_get(v, j));
            j = j - 1;
        };
        vec_set(v, j + 1, key);
        i = i + 1;
    };
    return n;
}

fn contains_str(v: Vec<str>, value: str) -> i64 {
    let n: i64 = vec_len(v);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(v, i), value) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn push_unique(v: Vec<str>, value: str) -> i64 {
    if str_len(value) == 0 { return 0; };
    if contains_str(v, value) == 0 {
        vec_push(v, value);
        return 1;
    };
    return 0;
}

fn skip_ws(s: str, p0: i64) -> i64 {
    let n: i64 = str_len(s);
    let mut p: i64 = p0;
    while p < n {
        let c: i64 = str_char_at(s, p);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        p = p + 1;
    };
    return p;
}

fn match_delim_aware(s: str, open_pos: i64, open_char: i64, close_char: i64) -> i64 {
    let n: i64 = str_len(s);
    if open_pos >= n || str_char_at(s, open_pos) != open_char { return -1; };
    let mut depth: i64 = 1;
    let mut p: i64 = open_pos + 1;
    while p < n {
        let c: i64 = str_char_at(s, p);
        if c == 47 && p + 1 < n && str_char_at(s, p + 1) == 47 {
            while p < n && str_char_at(s, p) != 10 { p = p + 1; };
        }
        else if c == 34 {
            p = p + 1;
            while p < n && str_char_at(s, p) != 34 {
                if str_char_at(s, p) == 92 && p + 1 < n { p = p + 1; };
                p = p + 1;
            };
        }
        else if c == 39 {
            p = p + 1;
            while p < n && str_char_at(s, p) != 39 {
                if str_char_at(s, p) == 92 && p + 1 < n { p = p + 1; };
                p = p + 1;
            };
        }
        else if c == open_char {
            depth = depth + 1;
        }
        else if c == close_char {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return -1;
}

fn match_brace(s: str, open_brace: i64) -> i64 {
    return match_delim_aware(s, open_brace, 123, 125);
}

fn line_end_from(s: str, p0: i64, limit: i64) -> i64 {
    let n: i64 = str_len(s);
    let mut p: i64 = p0;
    let lim: i64 = if limit < n { limit } else { n };
    while p < lim && str_char_at(s, p) != 10 { p = p + 1; };
    return p;
}

fn read_quoted_after(s: str, start: i64) -> str {
    let n: i64 = str_len(s);
    if start < 0 || start >= n { return ""; };
    if str_char_at(s, start) != 34 { return ""; };
    let close: i64 = find_from(s, "\"", start + 1);
    if close < 0 { return ""; };
    return str_substring(s, start + 1, close);
}

fn basename_no_ext(name: str) -> str {
    if str_ends_with(name, ".c") == 1 {
        return str_substring(name, 0, str_len(name) - 2);
    };
    if str_ends_with(name, ".nr") == 1 {
        return str_substring(name, 0, str_len(name) - 3);
    };
    return name;
}

// ---------- compiler-source inventory ----------

fn collect_get_rt_pairs(src: str, names: Vec<str>, symbols: Vec<str>) -> i64 {
    let needle: str = "if str_eq(name, \"";
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    while p >= 0 {
        let hit: i64 = find_from(src, needle, p);
        if hit < 0 { break; };
        let name_start: i64 = hit + str_len(needle);
        let name_close: i64 = find_from(src, "\"", name_start);
        if name_close < 0 { break; };
        let ret_hit: i64 = find_from(src, "return \"", name_close);
        if ret_hit < 0 { p = name_close + 1; continue; };
        let sym_start: i64 = ret_hit + str_len("return \"");
        let sym_close: i64 = find_from(src, "\"", sym_start);
        if sym_close < 0 { break; };
        let name: str = str_substring(src, name_start, name_close);
        let symbol: str = str_substring(src, sym_start, sym_close);
        if str_starts_with(symbol, "__nucleor_") == 1 {
            vec_push(names, name);
            vec_push(symbols, symbol);
            count = count + 1;
        };
        p = sym_close + 1;
    };
    return count;
}

fn collect_str_eq_return_ones_in_fn(src: str, fn_name: str, out: Vec<str>) -> i64 {
    let fn_needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let fn_pos: i64 = find_from(src, fn_needle, 0);
    if fn_pos < 0 { return 0; };
    let body_start: i64 = find_from(src, "{", fn_pos);
    if body_start < 0 { return 0; };
    let body_end: i64 = match_brace(src, body_start);
    if body_end < 0 { return 0; };

    let needle: str = "if str_eq(name, \"";
    let mut p: i64 = body_start;
    let mut count: i64 = 0;
    while p >= 0 && p < body_end {
        let hit: i64 = find_from(src, needle, p);
        if hit < 0 || hit >= body_end { break; };
        let name_start: i64 = hit + str_len(needle);
        let name_close: i64 = find_from(src, "\"", name_start);
        if name_close < 0 || name_close >= body_end { break; };
        let row_end: i64 = line_end_from(src, name_close, body_end);
        let row: str = str_substring(src, hit, row_end);
        let ret_hit: i64 = str_index_of(row, "return 1;");
        if ret_hit >= 0 {
            let name: str = str_substring(src, name_start, name_close);
            push_unique(out, name);
            count = count + 1;
        };
        p = name_close + 1;
    };
    sort_strs(out);
    return count;
}

fn collect_ir_declares(src: str, symbols: Vec<str>) -> i64 {
    let needle: str = "sb_append(sb, \"declare ";
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    while p >= 0 {
        let hit: i64 = find_from(src, needle, p);
        if hit < 0 { break; };
        let at_pos: i64 = find_from(src, "@", hit + str_len(needle));
        if at_pos < 0 { p = hit + str_len(needle); continue; };
        let open_paren: i64 = find_from(src, "(", at_pos);
        if open_paren < 0 { p = at_pos + 1; continue; };
        let sym: str = str_substring(src, at_pos + 1, open_paren);
        if str_starts_with(sym, "__nucleor_") == 1 {
            push_unique(symbols, sym);
            count = count + 1;
        };
        p = open_paren + 1;
    };
    sort_strs(symbols);
    return count;
}

// ---------- runtime C inventory ----------

fn collect_runtime_symbol_mentions(text: str, symbols: Vec<str>) -> i64 {
    let needle: str = "__nucleor_";
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    while p >= 0 {
        let hit: i64 = find_from(text, needle, p);
        if hit < 0 { break; };
        let mut endp: i64 = hit;
        while endp < str_len(text) && is_ident_char(str_char_at(text, endp)) == 1 {
            endp = endp + 1;
        };
        let after: i64 = skip_ws(text, endp);
        if after < str_len(text) && str_char_at(text, after) == 40 {
            let sym: str = str_substring(text, hit, endp);
            push_unique(symbols, sym);
            count = count + 1;
        };
        p = endp + 1;
    };
    return count;
}

fn collect_overflow_macro_defs(text: str, symbols: Vec<str>) -> i64 {
    let signed_needle: str = "NUC_DEFINE_SIGNED_OVERFLOW";
    let unsigned_needle: str = "NUC_DEFINE_UNSIGNED_OVERFLOW";
    let arith: Vec<str> = vec_new();
    vec_push(arith, "wrapping_add");
    vec_push(arith, "wrapping_sub");
    vec_push(arith, "wrapping_mul");
    vec_push(arith, "saturating_add");
    vec_push(arith, "saturating_sub");
    vec_push(arith, "saturating_mul");
    vec_push(arith, "checked_add");
    vec_push(arith, "checked_sub");
    vec_push(arith, "checked_mul");

    let mut total: i64 = 0;
    let mut pass: i64 = 0;
    while pass < 2 {
        let needle: str = if pass == 0 { signed_needle } else { unsigned_needle };
        let mut p: i64 = 0;
        while p >= 0 {
            let hit: i64 = find_from(text, needle, p);
            if hit < 0 { break; };
            let openp: i64 = find_from(text, "(", hit + str_len(needle));
            if openp < 0 { p = hit + str_len(needle); continue; };
            let width_start: i64 = skip_ws(text, openp + 1);
            let mut width_end: i64 = width_start;
            while width_end < str_len(text) && is_ident_char(str_char_at(text, width_end)) == 1 {
                width_end = width_end + 1;
            };
            let width: str = str_substring(text, width_start, width_end);
            if str_len(width) > 0 {
                let mut i: i64 = 0;
                while i < vec_len(arith) {
                    let sym: str = str_concat("__nucleor_", str_concat(vec_get(arith, i), str_concat("_", width)));
                    push_unique(symbols, sym);
                    total = total + 1;
                    i = i + 1;
                };
            };
            p = width_end + 1;
        };
        pass = pass + 1;
    };
    return total;
}

fn collect_runtime_inventory(rt_dir: str, c_files: Vec<str>, symbols: Vec<str>) -> Vec<i64> {
    let entries: Vec<str> = fs_list_dir(rt_dir);
    let mut i: i64 = 0;
    while i < vec_len(entries) {
        let name: str = vec_get(entries, i);
        if str_ends_with(name, ".c") == 1 {
            vec_push(c_files, name);
        };
        i = i + 1;
    };
    sort_strs(c_files);

    let counts: Vec<i64> = vec_new();
    let mut direct_mentions: i64 = 0;
    let mut macro_defs: i64 = 0;
    let mut k: i64 = 0;
    while k < vec_len(c_files) {
        let path: str = str_concat(rt_dir, str_concat("/", vec_get(c_files, k)));
        let text: str = file_read_string(path);
        direct_mentions = direct_mentions + collect_runtime_symbol_mentions(text, symbols);
        macro_defs = macro_defs + collect_overflow_macro_defs(text, symbols);
        k = k + 1;
    };
    sort_strs(symbols);
    vec_push(counts, direct_mentions);
    vec_push(counts, macro_defs);
    return counts;
}

fn print_first_values(label: str, values: Vec<str>, limit: i64) -> i64 {
    let n: i64 = vec_len(values);
    print(str_concat(label, str_concat("_count: ", int_to_str(n))));
    let mut shown: i64 = 0;
    let mut line: str = "";
    while shown < n && shown < limit {
        if shown > 0 { line = str_concat(line, ","); };
        line = str_concat(line, vec_get(values, shown));
        shown = shown + 1;
    };
    print(str_concat(label, str_concat("_first: ", line)));
    return shown;
}

fn print_value_lines(label: str, values: Vec<str>) -> i64 {
    let n: i64 = vec_len(values);
    let mut i: i64 = 0;
    while i < n {
        print(str_concat(label, str_concat(": ", vec_get(values, i))));
        i = i + 1;
    };
    return n;
}

// ---------- main ----------

fn main() -> i64 {
    let s1_path: str = "compiler/nucleor_s1_compiler.nr";
    let rt_dir: str = "stdlib/runtime";

    let src: str = file_read_string(s1_path);
    if str_len(src) == 0 {
        print(str_concat("ERROR: cannot read ", s1_path));
        return 1;
    };

    let rt_names: Vec<str> = vec_new();
    let rt_symbols: Vec<str> = vec_new();
    let rt_pair_count: i64 = collect_get_rt_pairs(src, rt_names, rt_symbols);

    let unique_rt_symbols: Vec<str> = vec_new();
    let mut i: i64 = 0;
    while i < vec_len(rt_symbols) {
        push_unique(unique_rt_symbols, vec_get(rt_symbols, i));
        i = i + 1;
    };
    sort_strs(unique_rt_symbols);

    let void_names: Vec<str> = vec_new();
    let ptr_ret_names: Vec<str> = vec_new();
    let ptr_arg_names: Vec<str> = vec_new();
    collect_str_eq_return_ones_in_fn(src, "is_void_ret", void_names);
    collect_str_eq_return_ones_in_fn(src, "is_ptr_ret", ptr_ret_names);
    collect_str_eq_return_ones_in_fn(src, "is_ptr_arg", ptr_arg_names);

    let ir_symbols: Vec<str> = vec_new();
    let ir_decl_count: i64 = collect_ir_declares(src, ir_symbols);

    let c_files: Vec<str> = vec_new();
    let runtime_symbols: Vec<str> = vec_new();
    let runtime_counts: Vec<i64> = collect_runtime_inventory(rt_dir, c_files, runtime_symbols);
    let runtime_direct_mentions: i64 = vec_get(runtime_counts, 0);
    let runtime_macro_defs: i64 = vec_get(runtime_counts, 1);

    let union_symbols: Vec<str> = vec_new();
    let mut u: i64 = 0;
    while u < vec_len(unique_rt_symbols) {
        push_unique(union_symbols, vec_get(unique_rt_symbols, u));
        u = u + 1;
    };
    u = 0;
    while u < vec_len(ir_symbols) {
        push_unique(union_symbols, vec_get(ir_symbols, u));
        u = u + 1;
    };
    sort_strs(union_symbols);

    print("helper_manifest_inventory_v2");
    print(str_concat("source: ", s1_path));
    print(str_concat("runtime_dir: ", rt_dir));
    print(str_concat("runtime_c_files: ", int_to_str(vec_len(c_files))));
    print(str_concat("get_rt_name_pairs: ", int_to_str(rt_pair_count)));
    print(str_concat("get_rt_name_unique_symbols: ", int_to_str(vec_len(unique_rt_symbols))));
    print(str_concat("is_void_ret_names: ", int_to_str(vec_len(void_names))));
    print(str_concat("is_ptr_ret_names: ", int_to_str(vec_len(ptr_ret_names))));
    print(str_concat("is_ptr_arg_names: ", int_to_str(vec_len(ptr_arg_names))));
    print(str_concat("ir_declares_seen: ", int_to_str(ir_decl_count)));
    print(str_concat("ir_declares_unique_symbols: ", int_to_str(vec_len(ir_symbols))));
    print(str_concat("runtime_direct_symbol_mentions: ", int_to_str(runtime_direct_mentions)));
    print(str_concat("runtime_macro_expanded_symbols: ", int_to_str(runtime_macro_defs)));
    print(str_concat("runtime_unique_symbols: ", int_to_str(vec_len(runtime_symbols))));
    print(str_concat("manifest_candidate_symbols: ", int_to_str(vec_len(union_symbols))));
    print_first_values("get_rt_name_symbol", unique_rt_symbols, 12);
    print_first_values("ir_symbol", ir_symbols, 12);
    print_first_values("runtime_symbol", runtime_symbols, 12);
    print_value_lines("void_ret_name", void_names);
    print_value_lines("ptr_ret_name", ptr_ret_names);
    print_value_lines("ptr_arg_name", ptr_arg_names);
    print_value_lines("candidate_symbol", union_symbols);
    print("note: read-only inventory only; canonical TOML still comes from tools/gen_helper_manifest.py");
    return 0;
}
