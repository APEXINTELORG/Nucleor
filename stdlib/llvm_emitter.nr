// llvm_emitter.nr — LLVM IR text emitter for self-hosted Nucleor compiler
// Full pipeline: .nr source → lex → parse → emit LLVM IR text (.ll) → clang → native .exe
// Follows the nucleor_native.nr pattern: direct source-text transpilation.
// All values are i64. Strings are ptr. Uses alloca for all locals.
// LLVM's mem2reg pass optimizes alloca to SSA registers.

// ============================================================
// Helpers
// ============================================================
fn is_digit(c: i32) -> bool { return c >= 48 && c <= 57; }
fn is_alpha(c: i32) -> bool { return (c >= 65 && c <= 90) || (c >= 97 && c <= 122); }
fn is_ident_start(c: i32) -> bool { return is_alpha(c) || c == 95; }
fn is_ident_cont(c: i32) -> bool { return is_alpha(c) || is_digit(c) || c == 95; }
fn is_ws(c: i32) -> bool { return c == 32 || c == 10 || c == 13 || c == 9; }

// Check if ",name," appears in a comma-delimited list like ",a,b,c,"
fn name_in_list(list: str, name: str) -> bool {
    let needle: str = str_concat(",", str_concat(name, ","));
    let hlen: i32 = str_len(list);
    let nlen: i32 = str_len(needle);
    let mut i: i32 = 0;
    while i + nlen <= hlen {
        let mut match_ok: bool = true;
        let mut j: i32 = 0;
        while j < nlen && match_ok {
            if str_char_at(list, i + j) != str_char_at(needle, j) { match_ok = false; };
            j = j + 1;
        };
        if match_ok { return true; };
        i = i + 1;
    };
    return false;
}

fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i32 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

// ============================================================
// Skip helpers — advance past whitespace, comments, type annotations
// ============================================================
fn skip_ws(source: str, pos: i32, len: i32) -> i32 {
    let mut p: i32 = pos;
    while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
    return p;
}

fn skip_line_comment(source: str, pos: i32, len: i32) -> i32 {
    let mut p: i32 = pos;
    while p < len && str_char_at(source, p) != 10 { p = p + 1; };
    return p;
}

fn read_ident(source: str, pos: i32, len: i32) -> str {
    let mut p: i32 = pos;
    while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
    return str_substring(source, pos, p);
}

fn read_ident_end(source: str, pos: i32, len: i32) -> i32 {
    let mut p: i32 = pos;
    while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
    return p;
}

// Skip a type annotation like ": i32", ": bool", ": str", ": Vec<i32>"
fn skip_type_annotation(source: str, pos: i32, len: i32) -> i32 {
    let mut p: i32 = pos;
    p = skip_ws(source, p, len);
    if p < len && str_char_at(source, p) == 58 {
        p = p + 1;
        p = skip_ws(source, p, len);
        // Read type name
        if p < len && is_ident_start(str_char_at(source, p)) {
            p = read_ident_end(source, p, len);
        };
        // Handle Vec<...>
        if p < len && str_char_at(source, p) == 60 {
            p = p + 1;
            let mut ad: i32 = 1;
            while p < len && ad > 0 {
                if str_char_at(source, p) == 60 { ad = ad + 1; };
                if str_char_at(source, p) == 62 { ad = ad - 1; };
                if ad > 0 { p = p + 1; };
            };
            if p < len { p = p + 1; };
        };
    };
    return p;
}

// ============================================================
// String literal helpers — extract raw content, compute length with escapes
// ============================================================
fn read_string_literal(source: str, pos: i32, len: i32) -> str {
    // pos points at opening quote; returns content between quotes
    let mut p: i32 = pos + 1;
    let rsb: i64 = sb_new();
    while p < len && str_char_at(source, p) != 34 {
        if str_char_at(source, p) == 92 && p + 1 < len {
            sb_append(rsb, str_substring(source, p, p + 2));
            p = p + 2;
        } else {
            sb_append(rsb, str_substring(source, p, p + 1));
            p = p + 1;
        };
    };
    return sb_to_str(rsb);
}

fn skip_string_literal(source: str, pos: i32, len: i32) -> i32 {
    // pos points at opening quote; returns position after closing quote
    let mut p: i32 = pos + 1;
    while p < len && str_char_at(source, p) != 34 {
        if str_char_at(source, p) == 92 && p + 1 < len { p = p + 2; }
        else { p = p + 1; };
    };
    if p < len { p = p + 1; };
    return p;
}

// Count actual bytes in a string literal (handling \n, \t, \0, \\, \" as 1 byte each)
fn string_literal_byte_len(raw: str) -> i32 {
    let rlen: i32 = str_len(raw);
    let mut count: i32 = 0;
    let mut i: i32 = 0;
    while i < rlen {
        if str_char_at(raw, i) == 92 && i + 1 < rlen {
            count = count + 1;
            i = i + 2;
        } else {
            count = count + 1;
            i = i + 1;
        };
    };
    return count + 1;
}

// Convert a Nucleor string literal to LLVM IR constant format
// "hello" -> c"hello\00"
// Escape sequences: \n -> \0A, \t -> \09, \\ -> \5C, \" -> \22, \0 -> \00
fn string_to_llvm_const(raw: str) -> str {
    let rlen: i32 = str_len(raw);
    let osb: i64 = sb_new();
    let mut i: i32 = 0;
    while i < rlen {
        let ch: i32 = str_char_at(raw, i);
        if ch == 92 && i + 1 < rlen {
            let esc: i32 = str_char_at(raw, i + 1);
            if esc == 110 { sb_append(osb, "\\0A"); }
            else if esc == 116 { sb_append(osb, "\\09"); }
            else if esc == 48 { sb_append(osb, "\\00"); }
            else if esc == 92 { sb_append(osb, "\\5C"); }
            else if esc == 34 { sb_append(osb, "\\22"); }
            else {
                sb_append(osb, "\\5C");
                sb_append(osb, str_substring(raw, i + 1, i + 2));
            };
            i = i + 2;
        } else if ch == 124 {
            sb_append(osb, "\\7C");
            i = i + 1;
        } else {
            sb_append(osb, str_substring(raw, i, i + 1));
            i = i + 1;
        };
    };
    return sb_to_str(osb);
}

// ============================================================
// LLVM IR Preamble — target triple and external declarations
// ============================================================
fn llvm_preamble() -> str {
    return str_concat("target triple = \"x86_64-pc-windows-msvc\"\n\n",
    str_concat("; External runtime functions\n",
    str_concat("declare void @__nucleor_print_str(ptr)\n",
    str_concat("declare i64 @__nucleor_print_i64(i64)\n",
    str_concat("declare void @__nucleor_print_bool(i32)\n",
    str_concat("declare i64 @__nucleor_str_len(ptr)\n",
    str_concat("declare i64 @__nucleor_str_eq(ptr, ptr)\n",
    str_concat("declare i64 @__nucleor_str_char_at(ptr, i64)\n",
    str_concat("declare ptr @__nucleor_str_substring(ptr, i64, i64)\n",
    str_concat("declare ptr @__nucleor_str_concat(ptr, ptr)\n",
    str_concat("declare ptr @__nucleor_file_read_string(ptr)\n",
    str_concat("declare void @__nucleor_file_write_string(ptr, ptr)\n",
    str_concat("declare i64 @__nucleor_system(ptr)\n",
    str_concat("declare ptr @__nucleor_vec_new()\n",
    str_concat("declare void @__nucleor_vec_push(ptr, i64)\n",
    str_concat("declare i64 @__nucleor_vec_get(ptr, i64)\n",
    str_concat("declare i64 @__nucleor_vec_len(ptr)\n",
    str_concat("declare void @__nucleor_vec_set(ptr, i64, i64)\n",
    str_concat("declare void @__nucleor_vec_pop(ptr)\n",
    str_concat("declare i64 @__nucleor_sb_new()\n",
    str_concat("declare void @__nucleor_sb_append(i64, ptr)\n",
    str_concat("declare ptr @__nucleor_sb_to_str(i64)\n",
    str_concat("declare i64 @__nucleor_args_count()\n",
    str_concat("declare ptr @__nucleor_args_get(i64)\n",
    str_concat("declare void @__nucleor_file_append_string(ptr, ptr)\n",
    str_concat("declare void @__nucleor_sb_free(i64)\n",
    "\n"))))))))))))))))))))))))));
}

// ============================================================
// Post-processing: fix unterminated basic blocks
// LLVM requires every basic block to end with a terminator (ret, br, unreachable).
// The emitter may leave merge blocks from else-if chains without terminators.
// This pass scans the IR and adds "unreachable" to any block that needs it.
// ============================================================
fn fixup_unterminated_blocks(ir: str) -> str {
    // Pass 1: Collect all labels and check which ones have real instructions
    // (not just "br label %X"). Then redirect empty cascade blocks.
    let len: i32 = str_len(ir);

    // First, insert basic terminators where missing
    let p1sb: i64 = sb_new();
    let mut pos: i32 = 0;
    let mut in_function: bool = false;
    let mut last_was_terminator: bool = false;

    while pos < len {
        let line_start: i32 = pos;
        while pos < len && str_char_at(ir, pos) != 10 { pos = pos + 1; };
        let line_end: i32 = pos;
        if pos < len { pos = pos + 1; };
        let line: str = str_substring(ir, line_start, line_end);
        let line_len: i32 = str_len(line);

        if line_len >= 6 && str_eq(str_substring(line, 0, 6), "define") { in_function = true; last_was_terminator = false; };

        let mut is_term: bool = false;
        if line_len >= 5 && str_eq(str_substring(line, 0, 5), "  ret") { is_term = true; };
        if line_len >= 4 && str_eq(str_substring(line, 0, 4), "  br") { is_term = true; };
        if line_len >= 13 && str_eq(str_substring(line, 0, 13), "  unreachable") { is_term = true; };

        let mut is_label: bool = false;
        let mut label_name: str = "";
        if in_function && line_len > 1 && str_char_at(line, line_len - 1) == 58 {
            if str_char_at(line, 0) != 64 {
                is_label = true;
                label_name = str_substring(line, 0, line_len - 1);
            };
        };

        let mut is_close: bool = false;
        if line_len == 1 && str_char_at(line, 0) == 125 { is_close = true; };

        if in_function && is_label && !last_was_terminator {
            sb_append(p1sb, "  br label %"); sb_append(p1sb, label_name); sb_append(p1sb, "\n");
        };
        if in_function && is_close && !last_was_terminator {
            sb_append(p1sb,"  ret i64 0\n");
        };

        sb_append(p1sb, line); sb_append(p1sb, "\n");

        if is_term { last_was_terminator = true; }
        else if is_label { last_was_terminator = false; }
        else if is_close { in_function = false; last_was_terminator = false; }
        else if line_len > 0 { last_was_terminator = false; };
    };

    // Pass 2 disabled — chain-following optimization is unsafe because it searches
    // the entire IR without scoping to individual functions. Spurious L.0 blocks
    // in different functions cause cross-function label redirection.
    // LLVM's own optimizer handles branch chain collapsing at -O1+.
    return sb_to_str(p1sb);
}

// ============================================================
fn lookup_const(const_map: str, name: str) -> str {
    let mlen: i32 = str_len(const_map);
    let nlen: i32 = str_len(name);
    let search: str = str_concat(name, "=");
    let slen: i32 = str_len(search);
    let mut pos: i32 = 0;
    while pos + slen <= mlen {
        if str_eq(str_substring(const_map, pos, pos + slen), search) {
            // Found — extract value until comma
            let vs: i32 = pos + slen;
            let mut ve: i32 = vs;
            while ve < mlen && str_char_at(const_map, ve) != 44 { ve = ve + 1; };
            return str_substring(const_map, vs, ve);
        };
        // Skip to next entry (after comma)
        while pos < mlen && str_char_at(const_map, pos) != 44 { pos = pos + 1; };
        if pos < mlen { pos = pos + 1; };
    };
    return "";
}

// ============================================================
// Const preprocessor: substitute const NAME = VALUE into source text
// ============================================================
fn preprocess_consts(source: str) -> str {
    let len: i32 = str_len(source);
    let mut const_map: str = "";
    // Pass 1: collect const NAME = VALUE declarations
    let mut fp: i32 = 0;
    while fp < len {
        let fc: i32 = str_char_at(source, fp);
        if is_ws(fc) { fp = fp + 1; }
        else if is_ident_start(fc) {
            let fws: i32 = fp;
            fp = read_ident_end(source, fp, len);
            if str_eq(str_substring(source, fws, fp), "const") {
                fp = skip_ws(source, fp, len);
                let cns: i32 = fp;
                fp = read_ident_end(source, fp, len);
                let cname: str = str_substring(source, cns, fp);
                while fp < len && str_char_at(source, fp) != 61 { fp = fp + 1; };
                fp = fp + 1;
                fp = skip_ws(source, fp, len);
                let cvs: i32 = fp;
                while fp < len && str_char_at(source, fp) != 59 { fp = fp + 1; };
                const_map = str_concat(const_map, str_concat(cname, str_concat("=", str_concat(str_substring(source, cvs, fp), ","))));
                fp = fp + 1;
            };
        }
        else { fp = fp + 1; };
    };
    if str_len(const_map) == 0 { return source; };
    // Pass 2: substitute
    return subst_consts(source, const_map);
}

fn subst_consts(source: str, const_map: str) -> str {
    let len: i32 = str_len(source);
    let mut out: str = "";
    let mut sp: i32 = 0;
    while sp < len {
        let sc: i32 = str_char_at(source, sp);
        if sc == 34 {
            let ss: i32 = sp;
            sp = skip_string_literal(source, sp, len);
            out = str_concat(out, str_substring(source, ss, sp));
        }
        else if is_ident_start(sc) {
            let ids: i32 = sp;
            sp = read_ident_end(source, sp, len);
            let id_text: str = str_substring(source, ids, sp);
            let cv: str = lookup_const(const_map, id_text);
            if str_len(cv) > 0 { out = str_concat(out, cv); }
            else { out = str_concat(out, id_text); };
        }
        else { out = str_concat(out, str_substring(source, sp, sp + 1)); sp = sp + 1; };
    };
    return out;
}

// ============================================================
// Main emitter: takes Nucleor source, returns LLVM IR text
// ============================================================
fn emit_llvm_ir(source: str) -> str {
    let len: i32 = str_len(source);
    let mut out: str = llvm_preamble();
    let str_sb: i64 = sb_new();
    let mut str_count: i32 = 0;
    let mut forward_decls: str = "";
    let bodies_sb: i64 = sb_new();
    let mut p: i32 = 0;
    let mut global_lbl: i32 = 0;
    // const_map is now handled by preprocess_consts() before this function

    // --- Pass 1: collect all function names for forward declarations ---
    let mut fp: i32 = 0;
    let mut fn_names: str = ",";
    while fp < len {
        let fc: i32 = str_char_at(source, fp);
        if is_ws(fc) { fp = fp + 1; }
        else if fc == 47 && fp + 1 < len && str_char_at(source, fp + 1) == 47 {
            fp = skip_line_comment(source, fp, len);
        }
        else if is_ident_start(fc) {
            let fws: i32 = fp;
            fp = read_ident_end(source, fp, len);
            let fword: str = str_substring(source, fws, fp);
            if str_eq(fword, "fn") {
                fp = skip_ws(source, fp, len);
                let fns: i32 = fp;
                fp = read_ident_end(source, fp, len);
                let fname: str = str_substring(source, fns, fp);
                fn_names = str_concat(fn_names, str_concat(fname, ","));
            };
        }
        else { fp = fp + 1; };
    };

    // --- Pass 2: emit each function ---
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if c == 47 && p + 1 < len && str_char_at(source, p + 1) == 47 {
            p = skip_line_comment(source, p, len);
        }
        else if is_ident_start(c) {
            let ws: i32 = p;
            p = read_ident_end(source, p, len);
            let word: str = str_substring(source, ws, p);

            if str_eq(word, "fn") {
                p = skip_ws(source, p, len);
                let ns: i32 = p;
                p = read_ident_end(source, p, len);
                let fname: str = str_substring(source, ns, p);

                // Parse parameters
                while p < len && str_char_at(source, p) != 40 { p = p + 1; };
                p = p + 1; // skip (
                let mut params: str = "";
                let mut param_names: str = ",";
                let mut param_count: i32 = 0;
                while p < len && str_char_at(source, p) != 41 {
                    let pc: i32 = str_char_at(source, p);
                    if is_ws(pc) { p = p + 1; }
                    else if is_ident_start(pc) {
                        let ps: i32 = p;
                        p = read_ident_end(source, p, len);
                        let pname: str = str_substring(source, ps, p);
                        // skip : type
                        p = skip_type_annotation(source, p, len);
                        if param_count > 0 { params = str_concat(params, ", "); };
                        params = str_concat(params, str_concat("i64 %p.", str_concat(str_from_int(param_count), str_concat(".", pname))));
                        param_names = str_concat(param_names, str_concat(pname, ","));
                        param_count = param_count + 1;
                        if p < len && str_char_at(source, p) == 44 { p = p + 1; };
                    }
                    else { p = p + 1; };
                };
                if p < len { p = p + 1; }; // skip )

                // Skip -> return type
                p = skip_ws(source, p, len);
                if p + 1 < len && str_char_at(source, p) == 45 && str_char_at(source, p + 1) == 62 {
                    p = p + 2;
                    p = skip_ws(source, p, len);
                    p = read_ident_end(source, p, len);
                };

                // Skip to {
                while p < len && str_char_at(source, p) != 123 { p = p + 1; };
                p = p + 1; // skip {

                // Emit function header
                let fb: i64 = sb_new();
                let discard_sb: i64 = sb_new();
                let alloca_sb: i64 = sb_new();
                sb_append(fb, "define i64 @"); sb_append(fb, fname); sb_append(fb, "("); sb_append(fb, params); sb_append(fb, ") {\n");
                sb_append(fb, "entry:\n");

                // Emit alloca + store for each parameter
                let mut pi: i32 = 0;
                while pi < param_count {
                    // Extract param name from param_names
                    let pn: str = emit_extract_param_name(param_names, pi);
                    sb_append(fb, "  %"); sb_append(fb, pn); sb_append(fb, " = alloca i64\n");
                    sb_append(fb, "  store i64 %p."); sb_append(fb, str_from_int(pi)); sb_append(fb, "."); sb_append(fb, pn); sb_append(fb, ", ptr %"); sb_append(fb, pn); sb_append(fb, "\n");
                    pi = pi + 1;
                };
                // Marker for body alloca insertion point
                sb_append(fb, ";!ALLOCA!\n");

                // Now emit the function body
                let mut reg: i32 = 0;
                let mut lbl: i32 = global_lbl;
                let mut depth: i32 = 1;
                let mut has_ret: bool = false;
                let mut alloc_names: str = ",";

                // Stack for while loop labels (header, end) — encoded as string
                let mut while_stack: str = "";
                let mut while_depth: i32 = 0;

                // Stack for if/else labels — encoded as string
                let mut if_stack: str = "";
                let mut if_depth: i32 = 0;

                // Construct order stack: "W" for while, "I" for if
                // Tracks the order constructs were opened so } knows what to close
                let mut construct_stack: str = "";

                // Track block termination to avoid instructions after terminator
                let mut block_terminated: bool = false;

                while p < len && depth > 0 {
                    let bc: i32 = str_char_at(source, p);

                    if is_ws(bc) { p = p + 1; }
                    else if bc == 47 && p + 1 < len && str_char_at(source, p + 1) == 47 {
                        p = skip_line_comment(source, p, len);
                    }
                    else if bc == 125 {
                        depth = depth - 1;
                        if depth > 0 {
                            p = p + 1;
                            // Closing brace — check what block we're closing
                            // Peek ahead to see if "else" follows (for if blocks)
                            // Must skip comments (// ...) between } and else
                            let mut peek_p: i32 = skip_ws(source, p, len);
                            while peek_p + 1 < len && str_char_at(source, peek_p) == 47 && str_char_at(source, peek_p + 1) == 47 {
                                peek_p = skip_line_comment(source, peek_p, len);
                                peek_p = skip_ws(source, peek_p, len);
                            };
                            let mut next_is_else: bool = false;
                            if peek_p < len && is_ident_start(str_char_at(source, peek_p)) {
                                let pk_end: i32 = read_ident_end(source, peek_p, len);
                                let pk_word: str = str_substring(source, peek_p, pk_end);
                                if str_eq(pk_word, "else") { next_is_else = true; };
                            };

                            // Check construct stack to determine what } closes
                            let cs_len: i32 = str_len(construct_stack);
                            let mut top_construct: i32 = 0; // 0=none, 87=W(while), 73=I(if)
                            if cs_len > 0 { top_construct = str_char_at(construct_stack, cs_len - 1); };

                            if top_construct == 87 && !next_is_else {
                                // Closing while body (top of construct stack is W)
                                construct_stack = str_substring(construct_stack, 0, cs_len - 1);
                                let mut closing_while: bool = true;
                                if closing_while {
                                    let wctx: str = extract_while_top(while_stack, while_depth);
                                    let wheader: i32 = extract_if_field(wctx, 0);
                                    let wend: i32 = extract_if_field(wctx, 1);
                                    if !block_terminated {
                                        sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(wheader)); sb_append(fb, "\n");
                                    };
                                    sb_append(fb, "L."); sb_append(fb, str_from_int(wend)); sb_append(fb, ":\n");
                                    block_terminated = false;
                                    while_depth = while_depth - 1;
                                    while_stack = pop_stack(while_stack);
                                };
                            }
                            else if top_construct == 73 && !next_is_else {
                                // Closing an if (top of construct stack is I)
                                construct_stack = str_substring(construct_stack, 0, cs_len - 1);
                                let if_ctx: str = extract_if_top(if_stack, if_depth);
                                let else_lbl: i32 = extract_if_field(if_ctx, 0);
                                let merge_lbl: i32 = extract_if_field(if_ctx, 1);
                                let then_term: i32 = extract_if_field(if_ctx, 2);
                                let mut else_terminated: bool = block_terminated;
                                if !block_terminated {
                                    sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(merge_lbl)); sb_append(fb, "\n");
                                };
                                // If else_lbl wasn't consumed (no else clause), emit it
                                if else_lbl >= 0 {
                                    sb_append(fb, "L."); sb_append(fb, str_from_int(else_lbl)); sb_append(fb, ":\n");
                                    sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(merge_lbl)); sb_append(fb, "\n");
                                };
                                // Both branches terminated => merge is unreachable
                                let mut both_terminated: bool = false;
                                if else_lbl < 0 && then_term == 1 && else_terminated {
                                    both_terminated = true;
                                };
                                if both_terminated {
                                    // Merge label is dead code, but LLVM needs a terminator
                                    sb_append(fb, "L."); sb_append(fb, str_from_int(merge_lbl)); sb_append(fb, ":\n");
                                    sb_append(fb, "  unreachable\n");
                                    block_terminated = true;
                                } else {
                                    sb_append(fb, "L."); sb_append(fb, str_from_int(merge_lbl)); sb_append(fb, ":\n");
                                    block_terminated = false;
                                };
                                if_depth = if_depth - 1;
                                if_stack = pop_stack(if_stack);
                            };
                        };
                    }
                    else if bc == 123 { depth = depth + 1; p = p + 1; }
                    else if bc == 59 { p = p + 1; } // skip semicolons
                    else if bc == 34 {
                        // String literal as expression — skip it
                        p = skip_string_literal(source, p, len);
                    }
                    else if is_digit(bc) {
                        // Number literal — could be implicit return
                        let num_start: i32 = p;
                        while p < len && is_digit(str_char_at(source, p)) { p = p + 1; };
                        let num_val: str = str_substring(source, num_start, p);
                        if !block_terminated {
                            let peek: i32 = skip_ws(source, p, len);
                            let mut is_ret: bool = false;
                            let mut tp: i32 = peek;
                            let mut td: i32 = depth;
                            while tp < len && td > 0 {
                                let tc: i32 = str_char_at(source, tp);
                                if tc == 125 { td = td - 1; tp = tp + 1; }
                                else if tc == 59 { tp = tp + 1; }
                                else if is_ws(tc) { tp = tp + 1; }
                                else { td = 1; tp = len; };
                            };
                            if td == 0 { is_ret = true; };
                            if is_ret {
                                sb_append(fb, "  ret i64 "); sb_append(fb, num_val); sb_append(fb, "\n");
                                block_terminated = true;
                                has_ret = true;
                            };
                        };
                    }
                    else if bc == 40 {
                        // Standalone parenthesized expression — parse as full expression
                        // Handles: (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
                        if !block_terminated {
                            let expr_result: str = emit_expr(source, p, len, reg, lbl, str_count, fn_names, param_names, param_count, 0, fb, str_sb);
                            let er_val: str = extract_field(expr_result, 0);
                            p = extract_field_int(expr_result, 1);
                            reg = extract_field_int(expr_result, 2);
                            lbl = extract_field_int(expr_result, 3);
                            str_count = extract_field_int(expr_result, 4);
                            let peek: i32 = skip_ws(source, p, len);
                            let mut is_impl_ret: bool = false;
                            let mut tp2: i32 = peek;
                            let mut td2: i32 = depth;
                            while tp2 < len && td2 > 0 {
                                let tc2: i32 = str_char_at(source, tp2);
                                if tc2 == 125 { td2 = td2 - 1; tp2 = tp2 + 1; }
                                else if tc2 == 59 { tp2 = tp2 + 1; }
                                else if is_ws(tc2) { tp2 = tp2 + 1; }
                                else { td2 = 1; tp2 = len; };
                            };
                            if td2 == 0 { is_impl_ret = true; };
                            if is_impl_ret {
                                sb_append(fb, "  ret i64 "); sb_append(fb, er_val); sb_append(fb, "\n");
                                block_terminated = true;
                                has_ret = true;
                            };
                        };
                        if !block_terminated {
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                        };
                    }
                    else if is_ident_start(bc) {
                        let ks: i32 = p;
                        p = read_ident_end(source, p, len);
                        let kw: str = str_substring(source, ks, p);

                        // --- let binding ---
                        if str_eq(kw, "let") {
                            // Rewind to start of "let" and re-parse cleanly
                            p = ks;
                            p = read_ident_end(source, p, len); // skip "let"
                            p = skip_ws(source, p, len);
                            let vns3: i32 = p;
                            p = read_ident_end(source, p, len);
                            let vn_or_mut: str = str_substring(source, vns3, p);
                            let mut real_vname: str = vn_or_mut;
                            if str_eq(vn_or_mut, "mut") {
                                p = skip_ws(source, p, len);
                                let vns4: i32 = p;
                                p = read_ident_end(source, p, len);
                                real_vname = str_substring(source, vns4, p);
                            };

                            // Skip type annotation
                            p = skip_type_annotation(source, p, len);

                            // Emit alloca to entry block (dedup: skip if already allocated)
                            if !name_in_list(alloc_names, real_vname) {
                                sb_append(alloca_sb, "  %"); sb_append(alloca_sb, real_vname); sb_append(alloca_sb, " = alloca i64\n");
                                alloc_names = str_concat(alloc_names, str_concat(real_vname, ","));
                            };

                            // Check for = initializer
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 61 {
                                p = p + 1; // skip =
                                p = skip_ws(source, p, len);

                                // Parse init expression and emit
                                let mut let_sb: i64 = fb;
                                if block_terminated { let_sb = discard_sb; };
                                let expr_result: str = emit_expr(source, p, len, reg, lbl, str_count, fn_names, param_names, param_count, 0, let_sb, str_sb);
                                let er_val: str = extract_field(expr_result, 0);
                                p = extract_field_int(expr_result, 1);
                                reg = extract_field_int(expr_result, 2);
                                lbl = extract_field_int(expr_result, 3);
                                str_count = extract_field_int(expr_result, 4);

                                if !block_terminated {
                                    sb_append(fb, "  store i64 "); sb_append(fb, er_val); sb_append(fb, ", ptr %"); sb_append(fb, real_vname); sb_append(fb, "\n");
                                };
                            };
                            // skip trailing ;
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                        }
                        // --- return ---
                        else if str_eq(kw, "return") {
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) != 59 && str_char_at(source, p) != 125 {
                                let mut ret_sb: i64 = fb;
                                if block_terminated { ret_sb = discard_sb; };
                                let expr_result: str = emit_expr(source, p, len, reg, lbl, str_count, fn_names, param_names, param_count, 0, ret_sb, str_sb);
                                let er_val: str = extract_field(expr_result, 0);
                                p = extract_field_int(expr_result, 1);
                                reg = extract_field_int(expr_result, 2);
                                lbl = extract_field_int(expr_result, 3);
                                str_count = extract_field_int(expr_result, 4);
                                if !block_terminated {
                                    sb_append(fb, "  ret i64 "); sb_append(fb, er_val); sb_append(fb, "\n");
                                    block_terminated = true;
                                };
                                has_ret = true;
                            } else {
                                if !block_terminated {
                                    sb_append(fb, "  ret i64 0\n");
                                    block_terminated = true;
                                };
                                has_ret = true;
                            };
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                        }
                        // --- if ---
                        else if str_eq(kw, "if") {
                            p = skip_ws(source, p, len);
                            // Parse condition
                            let mut if_sb: i64 = fb;
                            if block_terminated { if_sb = discard_sb; };
                            let cond_result: str = emit_cond(source, p, len, reg, lbl, str_count, fn_names, param_names, param_count, if_sb, str_sb);
                            let cr_val: str = extract_field(cond_result, 0);
                            p = extract_field_int(cond_result, 1);
                            reg = extract_field_int(cond_result, 2);
                            lbl = extract_field_int(cond_result, 3);
                            str_count = extract_field_int(cond_result, 4);

                            let lbl_then: i32 = lbl;
                            lbl = lbl + 1;
                            let lbl_else: i32 = lbl;
                            lbl = lbl + 1;
                            let lbl_merge: i32 = lbl;
                            lbl = lbl + 1;

                            // Truncate i64 condition to i1
                            let cond_i1: str = str_concat("%t.", str_from_int(reg));
                            reg = reg + 1;
                            if !block_terminated {
                                sb_append(fb, "  "); sb_append(fb, cond_i1); sb_append(fb, " = trunc i64 "); sb_append(fb, cr_val); sb_append(fb, " to i1\n");
                                sb_append(fb, "  br i1 "); sb_append(fb, cond_i1); sb_append(fb, ", label %L."); sb_append(fb, str_from_int(lbl_then)); sb_append(fb, ", label %L."); sb_append(fb, str_from_int(lbl_else)); sb_append(fb, "\n");
                            };
                            sb_append(fb, "L."); sb_append(fb, str_from_int(lbl_then)); sb_append(fb, ":\n");
                            block_terminated = false;

                            // Push if context: else_label, merge_label, then_terminated(0)
                            if_stack = str_concat(if_stack, str_concat(str_from_int(lbl_else), str_concat(",", str_concat(str_from_int(lbl_merge), ",0;"))));
                            if_depth = if_depth + 1;
                            construct_stack = str_concat(construct_stack, "I");

                            // Skip opening brace (already consumed by depth tracking above or here)
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 123 { depth = depth + 1; p = p + 1; };
                        }
                        // --- else ---
                        else if str_eq(kw, "else") {
                            if if_depth > 0 {
                                let if_ctx: str = extract_if_top(if_stack, if_depth);
                                let else_lbl: i32 = extract_if_field(if_ctx, 0);
                                let merge_lbl: i32 = extract_if_field(if_ctx, 1);

                                // Record whether then-branch was terminated
                                let mut then_term: i32 = 0;
                                if block_terminated { then_term = 1; };

                                if !block_terminated {
                                    sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(merge_lbl)); sb_append(fb, "\n");
                                };
                                sb_append(fb, "L."); sb_append(fb, str_from_int(else_lbl)); sb_append(fb, ":\n");
                                block_terminated = false;

                                // Update if_stack: replace else_lbl with -1 (consumed), store then_term
                                if_stack = replace_if_top_3(if_stack, if_depth, merge_lbl, then_term);
                            };

                            p = skip_ws(source, p, len);
                            // Check for "else if"
                            if p < len && is_ident_start(str_char_at(source, p)) {
                                let eiks: i32 = p;
                                let eikw: str = read_ident(source, p, len);
                                if str_eq(eikw, "if") {
                                    // else if — FLATTEN the chain.
                                    // Close the current if: pop it and emit merge for it.
                                    // Then let the `if` handler create a new if that reuses
                                    // the same merge_lbl from the parent.
                                    // Step 1: pop current if (its merge_lbl is the chain's common merge)
                                    let pop_ctx: str = extract_if_top(if_stack, if_depth);
                                    let parent_merge: i32 = extract_if_field(pop_ctx, 1);
                                    if_depth = if_depth - 1;
                                    if_stack = pop_stack(if_stack);
                                    // Pop "I" from construct stack too
                                    let cs_len2: i32 = str_len(construct_stack);
                                    if cs_len2 > 0 { construct_stack = str_substring(construct_stack, 0, cs_len2 - 1); };
                                    // DON'T emit merge label yet - it goes at the end of the chain
                                    // Step 2: The `if` handler will run from the main loop.
                                    // We need to make it use parent_merge as the merge label.
                                    // Hack: push a "chain marker" that the if handler will pick up.
                                    // Instead, we inline the if handling here with the right merge.
                                    p = read_ident_end(source, p, len); // consume "if"
                                    p = skip_ws(source, p, len);
                                    // Parse condition (block_terminated is false here — else starts new block)
                                    let cond_result: str = emit_cond(source, p, len, reg, lbl, str_count, fn_names, param_names, param_count, fb, str_sb);
                                    let cr_val: str = extract_field(cond_result, 0);
                                    p = extract_field_int(cond_result, 1);
                                    reg = extract_field_int(cond_result, 2);
                                    lbl = extract_field_int(cond_result, 3);
                                    str_count = extract_field_int(cond_result, 4);

                                    let lbl_then: i32 = lbl;
                                    lbl = lbl + 1;
                                    let lbl_else2: i32 = lbl;
                                    lbl = lbl + 1;
                                    // Use parent_merge instead of a new merge label!

                                    let cond_i1: str = str_concat("%t.", str_from_int(reg));
                                    reg = reg + 1;
                                    if !block_terminated {
                                        sb_append(fb, "  "); sb_append(fb, cond_i1); sb_append(fb, " = trunc i64 "); sb_append(fb, cr_val); sb_append(fb, " to i1\n");
                                        sb_append(fb, "  br i1 "); sb_append(fb, cond_i1); sb_append(fb, ", label %L."); sb_append(fb, str_from_int(lbl_then)); sb_append(fb, ", label %L."); sb_append(fb, str_from_int(lbl_else2)); sb_append(fb, "\n");
                                    };
                                    sb_append(fb, "L."); sb_append(fb, str_from_int(lbl_then)); sb_append(fb, ":\n");
                                    block_terminated = false;

                                    // Push with parent's merge label (flattened chain)
                                    if_stack = str_concat(if_stack, str_concat(str_from_int(lbl_else2), str_concat(",", str_concat(str_from_int(parent_merge), ",0;"))));
                                    if_depth = if_depth + 1;
                                    construct_stack = str_concat(construct_stack, "I");

                                    p = skip_ws(source, p, len);
                                    if p < len && str_char_at(source, p) == 123 { depth = depth + 1; p = p + 1; };
                                } else {
                                    // Plain else
                                    if p < len && str_char_at(source, p) == 123 { depth = depth + 1; p = p + 1; };
                                };
                            } else {
                                if p < len && str_char_at(source, p) == 123 { depth = depth + 1; p = p + 1; };
                            };
                        }
                        // --- while ---
                        else if str_eq(kw, "while") {
                            let lbl_header: i32 = lbl;
                            lbl = lbl + 1;
                            let lbl_body: i32 = lbl;
                            lbl = lbl + 1;
                            let lbl_end: i32 = lbl;
                            lbl = lbl + 1;

                            if !block_terminated {
                                sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(lbl_header)); sb_append(fb, "\n");
                            };
                            sb_append(fb, "L."); sb_append(fb, str_from_int(lbl_header)); sb_append(fb, ":\n");
                            block_terminated = false;

                            p = skip_ws(source, p, len);
                            // Parse condition (block_terminated is false — while header starts new block)
                            let cond_result: str = emit_cond(source, p, len, reg, lbl, str_count, fn_names, param_names, param_count, fb, str_sb);
                            let cr_val: str = extract_field(cond_result, 0);
                            p = extract_field_int(cond_result, 1);
                            reg = extract_field_int(cond_result, 2);
                            lbl = extract_field_int(cond_result, 3);
                            str_count = extract_field_int(cond_result, 4);

                            let cond_i1: str = str_concat("%t.", str_from_int(reg));
                            reg = reg + 1;
                            sb_append(fb, "  "); sb_append(fb, cond_i1); sb_append(fb, " = trunc i64 "); sb_append(fb, cr_val); sb_append(fb, " to i1\n");
                            sb_append(fb, "  br i1 "); sb_append(fb, cond_i1); sb_append(fb, ", label %L."); sb_append(fb, str_from_int(lbl_body)); sb_append(fb, ", label %L."); sb_append(fb, str_from_int(lbl_end)); sb_append(fb, "\n");
                            sb_append(fb, "L."); sb_append(fb, str_from_int(lbl_body)); sb_append(fb, ":\n");
                            block_terminated = false;

                            // Push while context
                            while_stack = str_concat(while_stack, str_concat(str_from_int(lbl_header), str_concat(",", str_concat(str_from_int(lbl_end), ";"))));
                            while_depth = while_depth + 1;
                            construct_stack = str_concat(construct_stack, "W");

                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 123 { depth = depth + 1; p = p + 1; };
                        }
                        // --- break ---
                        else if str_eq(kw, "break") {
                            if while_depth > 0 && !block_terminated {
                                let wctx: str = extract_while_top(while_stack, while_depth);
                                let wend: i32 = extract_if_field(wctx, 1);
                                sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(wend)); sb_append(fb, "\n");
                                block_terminated = true;
                            };
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                        }
                        // --- continue ---
                        else if str_eq(kw, "continue") {
                            if while_depth > 0 && !block_terminated {
                                let wctx: str = extract_while_top(while_stack, while_depth);
                                let wheader: i32 = extract_if_field(wctx, 0);
                                sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(wheader)); sb_append(fb, "\n");
                                block_terminated = true;
                            };
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                        }
                        // --- assignment: ident = expr ---
                        else if str_eq(kw, "true") || str_eq(kw, "false") {
                            let mut bool_val: str = "0";
                            if str_eq(kw, "true") { bool_val = "1"; };
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                            if !block_terminated {
                                let peek: i32 = skip_ws(source, p, len);
                                let mut is_ret: bool = false;
                                let mut tp: i32 = peek;
                                let mut td: i32 = depth;
                                while tp < len && td > 0 {
                                    let tc: i32 = str_char_at(source, tp);
                                    if tc == 125 { td = td - 1; tp = tp + 1; }
                                    else if tc == 59 { tp = tp + 1; }
                                    else if is_ws(tc) { tp = tp + 1; }
                                    else { td = 1; tp = len; };
                                };
                                if td == 0 { is_ret = true; };
                                if is_ret {
                                    sb_append(fb, "  ret i64 "); sb_append(fb, bool_val); sb_append(fb, "\n");
                                    block_terminated = true;
                                    has_ret = true;
                                };
                            };
                        }
                        else {
                            // Check for assignment (ident = expr) or function call (ident(...))
                            p = skip_ws(source, p, len);
                            if p < len && str_char_at(source, p) == 61 && (p + 1 >= len || str_char_at(source, p + 1) != 61) {
                                // Assignment
                                p = p + 1; // skip =
                                p = skip_ws(source, p, len);
                                let mut asn_sb: i64 = fb;
                                if block_terminated { asn_sb = discard_sb; };
                                let expr_result: str = emit_expr(source, p, len, reg, lbl, str_count, fn_names, param_names, param_count, 0, asn_sb, str_sb);
                                let er_val: str = extract_field(expr_result, 0);
                                p = extract_field_int(expr_result, 1);
                                reg = extract_field_int(expr_result, 2);
                                lbl = extract_field_int(expr_result, 3);
                                str_count = extract_field_int(expr_result, 4);

                                if !block_terminated {
                                    sb_append(fb, "  store i64 "); sb_append(fb, er_val); sb_append(fb, ", ptr %"); sb_append(fb, kw); sb_append(fb, "\n");
                                };
                                p = skip_ws(source, p, len);
                                if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                            }
                            else if p < len && str_char_at(source, p) == 40 {
                                // Function call as statement (or as implicit return)
                                let call_start: i32 = ks;
                                let mut call_sb: i64 = fb;
                                if block_terminated { call_sb = discard_sb; };
                                let expr_result: str = emit_expr(source, call_start, len, reg, lbl, str_count, fn_names, param_names, param_count, 0, call_sb, str_sb);
                                let er_val: str = extract_field(expr_result, 0);
                                p = extract_field_int(expr_result, 1);
                                reg = extract_field_int(expr_result, 2);
                                lbl = extract_field_int(expr_result, 3);
                                str_count = extract_field_int(expr_result, 4);

                                if !block_terminated {
                                    // Check for implicit return (only at function level, depth==1)
                                    let peek: i32 = skip_ws(source, p, len);
                                    let mut is_impl_ret: bool = false;
                                    if depth == 1 && peek < len && str_char_at(source, peek) == 125 { is_impl_ret = true; };
                                    if depth == 1 && peek < len && str_char_at(source, peek) == 59 {
                                        let pk2: i32 = skip_ws(source, peek + 1, len);
                                        if pk2 < len && str_char_at(source, pk2) == 125 { is_impl_ret = true; };
                                    };
                                    if is_impl_ret {
                                        sb_append(fb, "  ret i64 "); sb_append(fb, er_val); sb_append(fb, "\n");
                                        block_terminated = true;
                                        has_ret = true;
                                    };
                                };
                                p = skip_ws(source, p, len);
                                if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                            }
                            else if p < len && str_char_at(source, p) == 46 {
                                // Method call: ident.method(args)
                                p = p + 1;
                                p = skip_ws(source, p, len);
                                let mcs: i32 = p;
                                p = read_ident_end(source, p, len);
                                let mcm: str = str_substring(source, mcs, p);
                                p = skip_ws(source, p, len);
                                if p < len && str_char_at(source, p) == 40 { p = p + 1; };
                                let mc_or: str = str_concat("%r.", str_from_int(reg));
                                reg = reg + 1;
                                if !block_terminated {
                                    sb_append(fb, "  "); sb_append(fb, mc_or); sb_append(fb, " = load i64, ptr %"); sb_append(fb, kw); sb_append(fb, "\n");
                                };
                                let mc_ptr: str = str_concat("%r.", str_from_int(reg));
                                reg = reg + 1;
                                if !block_terminated {
                                    sb_append(fb, "  "); sb_append(fb, mc_ptr); sb_append(fb, " = inttoptr i64 "); sb_append(fb, mc_or); sb_append(fb, " to ptr\n");
                                };
                                if str_eq(mcm, "push") {
                                    p = skip_ws(source, p, len);
                                    let mut push_sb: i64 = fb;
                                    if block_terminated { push_sb = discard_sb; };
                                    let expr_result: str = emit_expr(source, p, len, reg, lbl, str_count, fn_names, param_names, param_count, 0, push_sb, str_sb);
                                    let mc_ev: str = extract_field(expr_result, 0);
                                    p = extract_field_int(expr_result, 1);
                                    reg = extract_field_int(expr_result, 2);
                                    lbl = extract_field_int(expr_result, 3);
                                    str_count = extract_field_int(expr_result, 4);
                                    if !block_terminated {
                                        sb_append(fb, "  call void @__nucleor_vec_push(ptr "); sb_append(fb, mc_ptr); sb_append(fb, ", i64 "); sb_append(fb, mc_ev); sb_append(fb, ")\n");
                                    };
                                }
                                else if str_eq(mcm, "pop") {
                                    if !block_terminated {
                                        sb_append(fb, "  call void @__nucleor_vec_pop(ptr "); sb_append(fb, mc_ptr); sb_append(fb, ")\n");
                                    };
                                };
                                p = skip_ws(source, p, len);
                                if p < len && str_char_at(source, p) == 41 { p = p + 1; };
                                p = skip_ws(source, p, len);
                                if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                            }
                            else {
                                // Bare expression starting with identifier — parse full expression
                                // (handles: c == 32 || c == 10, x + y, function_result, etc.)
                                // Rewind to identifier start and parse as full expression
                                if !block_terminated {
                                    let expr_result: str = emit_expr(source, ks, len, reg, lbl, str_count, fn_names, param_names, param_count, 0, fb, str_sb);
                                    let er_val: str = extract_field(expr_result, 0);
                                    p = extract_field_int(expr_result, 1);
                                    reg = extract_field_int(expr_result, 2);
                                    lbl = extract_field_int(expr_result, 3);
                                    str_count = extract_field_int(expr_result, 4);
                                    // Check if this is the last expression before } (implicit return)
                                    let peek: i32 = skip_ws(source, p, len);
                                    let mut is_implicit_ret: bool = false;
                                    let mut tp3: i32 = peek;
                                    let mut td3: i32 = depth;
                                    while tp3 < len && td3 > 0 {
                                        let tc3: i32 = str_char_at(source, tp3);
                                        if tc3 == 125 { td3 = td3 - 1; tp3 = tp3 + 1; }
                                        else if tc3 == 59 { tp3 = tp3 + 1; }
                                        else if is_ws(tc3) { tp3 = tp3 + 1; }
                                        else { td3 = 1; tp3 = len; };
                                    };
                                    if td3 == 0 { is_implicit_ret = true; };
                                    if is_implicit_ret {
                                        sb_append(fb, "  ret i64 "); sb_append(fb, er_val); sb_append(fb, "\n");
                                        block_terminated = true;
                                        has_ret = true;
                                    };
                                };
                                p = skip_ws(source, p, len);
                                if p < len && str_char_at(source, p) == 59 { p = p + 1; };
                            };
                        };
                    }
                    else { p = p + 1; };

                    // Check if we just closed a while body or if body
                    // Handle merge/end labels when depth decreases
                    // This is checked after each "}" is consumed above
                    // We look ahead to see if the next token is "else"
                    if depth > 0 {
                        // Check if the closing brace we just consumed needs a branch
                        let peeked: i32 = skip_ws(source, p, len);
                        if peeked < len && str_char_at(source, peeked) == 125 {
                            // Next is another }, so this inner block is ending
                        };
                    };
                };

                // Handle pending while end labels
                while while_depth > 0 {
                    let wctx: str = extract_while_top(while_stack, while_depth);
                    let wheader: i32 = extract_if_field(wctx, 0);
                    let wend: i32 = extract_if_field(wctx, 1);
                    if !block_terminated {
                        sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(wheader)); sb_append(fb, "\n");
                    };
                    sb_append(fb, "L."); sb_append(fb, str_from_int(wend)); sb_append(fb, ":\n");
                    block_terminated = false;
                    while_depth = while_depth - 1;
                    while_stack = pop_stack(while_stack);
                };

                // Handle pending if merge labels
                while if_depth > 0 {
                    let if_ctx: str = extract_if_top(if_stack, if_depth);
                    let else_lbl: i32 = extract_if_field(if_ctx, 0);
                    let merge_lbl: i32 = extract_if_field(if_ctx, 1);
                    if !block_terminated {
                        sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(merge_lbl)); sb_append(fb, "\n");
                    };
                    // If else_lbl wasn't consumed (no else clause), emit it pointing to merge
                    if else_lbl >= 0 {
                        sb_append(fb, "L."); sb_append(fb, str_from_int(else_lbl)); sb_append(fb, ":\n");
                        sb_append(fb, "  br label %L."); sb_append(fb, str_from_int(merge_lbl)); sb_append(fb, "\n");
                    };
                    sb_append(fb, "L."); sb_append(fb, str_from_int(merge_lbl)); sb_append(fb, ":\n");
                    block_terminated = false;
                    if_depth = if_depth - 1;
                    if_stack = pop_stack(if_stack);
                };

                // Save label counter for next function (unique labels across functions)
                global_lbl = lbl;

                // Ensure function ends with ret
                if !has_ret && !block_terminated {
                    sb_append(fb, "  ret i64 0\n");
                };
                sb_append(fb, "}\n\n");
                // Insert body allocas at the marker point
                let fb_str: str = sb_to_str(fb);
                let alloca_str: str = sb_to_str(alloca_sb);
                if str_len(alloca_str) > 0 {
                    // Find the marker ";!ALLOCA!\n" and replace it with body allocas
                    let marker: str = ";!ALLOCA!\n";
                    let mlen: i32 = str_len(marker);
                    let fl: i32 = str_len(fb_str);
                    let mut mp: i32 = 0;
                    let mut found_marker: bool = false;
                    while mp + mlen <= fl && !found_marker {
                        let mut mm: bool = true;
                        let mut mi: i32 = 0;
                        while mi < mlen && mm {
                            if str_char_at(fb_str, mp + mi) != str_char_at(marker, mi) { mm = false; };
                            mi = mi + 1;
                        };
                        if mm { found_marker = true; }
                        else { mp = mp + 1; };
                    };
                    if found_marker {
                        sb_append(bodies_sb, str_substring(fb_str, 0, mp));
                        sb_append(bodies_sb, alloca_str);
                        sb_append(bodies_sb, str_substring(fb_str, mp + mlen, fl));
                    } else {
                        sb_append(bodies_sb, fb_str);
                    };
                } else {
                    sb_append(bodies_sb, fb_str);
                };
            }
            // --- const ---
            else if str_eq(word, "const") {
                // Consts already substituted by preprocess_consts — just skip declaration
                while p < len && str_char_at(source, p) != 59 { p = p + 1; };
                if p < len { p = p + 1; };
            }
            // --- struct/enum/impl/trait/use ---
            else if str_eq(word, "struct") || str_eq(word, "enum") || str_eq(word, "impl") || str_eq(word, "trait") {
                while p < len && str_char_at(source, p) != 123 && str_char_at(source, p) != 59 { p = p + 1; };
                if p < len && str_char_at(source, p) == 123 {
                    p = p + 1;
                    let mut sd: i32 = 1;
                    while p < len && sd > 0 {
                        if str_char_at(source, p) == 123 { sd = sd + 1; };
                        if str_char_at(source, p) == 125 { sd = sd - 1; };
                        if sd > 0 { p = p + 1; };
                    };
                    if p < len { p = p + 1; };
                }
                else if p < len { p = p + 1; };
            }
            else if str_eq(word, "use") {
                while p < len && str_char_at(source, p) != 59 { p = p + 1; };
                if p < len { p = p + 1; };
            }
            else { };
        }
        else { p = p + 1; };
    };

    // Assemble final output: strings first, then preamble, then functions
    return str_concat(out, str_concat(sb_to_str(str_sb), str_concat("\n", sb_to_str(bodies_sb))));
}

// ============================================================
// Expression emitter — returns "VALUE|POS|REG|LBL|SC"
// Instructions appended directly to out_sb; string constants to str_sb
// ============================================================
fn emit_expr(source: str, pos: i32, len: i32, reg_in: i32, lbl_in: i32, sc_in: i32, fn_names: str, param_names: str, param_count: i32, min_prec: i32, out_sb: i64, str_sb: i64) -> str {
    let mut p: i32 = pos;
    let mut reg: i32 = reg_in;
    let mut lbl: i32 = lbl_in;
    let mut sc: i32 = sc_in;

    p = skip_ws(source, p, len);

    // Parse primary expression
    let mut val: str = "0";
    let ch: i32 = str_char_at(source, p);

    if is_digit(ch) || (ch == 45 && p + 1 < len && is_digit(str_char_at(source, p + 1))) {
        // Integer literal
        let ns: i32 = p;
        if ch == 45 { p = p + 1; };
        while p < len && is_digit(str_char_at(source, p)) { p = p + 1; };
        val = str_substring(source, ns, p);
    }
    else if ch == 34 {
        // String literal
        let raw: str = read_string_literal(source, p, len);
        p = skip_string_literal(source, p, len);
        let ll_str: str = string_to_llvm_const(raw);
        let byte_len: i32 = string_literal_byte_len(raw);
        let str_name: str = str_concat("@.str.", str_from_int(sc));
        sb_append(str_sb, str_name); sb_append(str_sb, " = private unnamed_addr constant ["); sb_append(str_sb, str_from_int(byte_len)); sb_append(str_sb, " x i8] c\""); sb_append(str_sb, ll_str); sb_append(str_sb, "\\00\"\n");
        // Get pointer to string
        let r: str = str_concat("%r.", str_from_int(reg));
        reg = reg + 1;
        sb_append(out_sb, "  "); sb_append(out_sb, r); sb_append(out_sb, " = ptrtoint ptr "); sb_append(out_sb, str_name); sb_append(out_sb, " to i64\n");
        val = r;
        sc = sc + 1;
    }
    else if is_ident_start(ch) {
        let ids: i32 = p;
        p = read_ident_end(source, p, len);
        let id: str = str_substring(source, ids, p);

        if str_eq(id, "true") {
            val = "1";
        }
        else if str_eq(id, "false") {
            val = "0";
        }
        else if str_eq(id, "Vec") {
            // Vec::new() constructor
            p = skip_ws(source, p, len);
            if p + 1 < len && str_char_at(source, p) == 58 && str_char_at(source, p + 1) == 58 {
                p = p + 2;
                p = skip_ws(source, p, len);
                p = read_ident_end(source, p, len);
                p = skip_ws(source, p, len);
                if p < len && str_char_at(source, p) == 40 { p = p + 1; };
                p = skip_ws(source, p, len);
                if p < len && str_char_at(source, p) == 41 { p = p + 1; };
                let pr: str = str_concat("%r.", str_from_int(reg));
                reg = reg + 1;
                sb_append(out_sb, "  "); sb_append(out_sb, pr); sb_append(out_sb, " = call ptr @__nucleor_vec_new()\n");
                let vr: str = str_concat("%r.", str_from_int(reg));
                reg = reg + 1;
                sb_append(out_sb, "  "); sb_append(out_sb, vr); sb_append(out_sb, " = ptrtoint ptr "); sb_append(out_sb, pr); sb_append(out_sb, " to i64\n");
                val = vr;
            };
        }
        else {
            p = skip_ws(source, p, len);
            if p < len && str_char_at(source, p) == 40 {
                // Function call
                let call_result: str = emit_call(source, ids, p, len, reg, lbl, sc, fn_names, param_names, param_count, out_sb, str_sb);
                val = extract_field(call_result, 0);
                p = extract_field_int(call_result, 1);
                reg = extract_field_int(call_result, 2);
                lbl = extract_field_int(call_result, 3);
                sc = extract_field_int(call_result, 4);
            } else {
                // Variable load
                let r: str = str_concat("%r.", str_from_int(reg));
                reg = reg + 1;
                sb_append(out_sb, "  "); sb_append(out_sb, r); sb_append(out_sb, " = load i64, ptr %"); sb_append(out_sb, id); sb_append(out_sb, "\n");
                val = r;
                // Check for method call: id.method(args)
                p = skip_ws(source, p, len);
                if p < len && str_char_at(source, p) == 46 {
                    p = p + 1;
                    p = skip_ws(source, p, len);
                    let ms2: i32 = p;
                    p = read_ident_end(source, p, len);
                    let meth: str = str_substring(source, ms2, p);
                    p = skip_ws(source, p, len);
                    if p < len && str_char_at(source, p) == 40 { p = p + 1; };
                    let mptr: str = str_concat("%r.", str_from_int(reg));
                    reg = reg + 1;
                    sb_append(out_sb, "  "); sb_append(out_sb, mptr); sb_append(out_sb, " = inttoptr i64 "); sb_append(out_sb, val); sb_append(out_sb, " to ptr\n");
                    if str_eq(meth, "len") {
                        let mr: str = str_concat("%r.", str_from_int(reg));
                        reg = reg + 1;
                        sb_append(out_sb, "  "); sb_append(out_sb, mr); sb_append(out_sb, " = call i64 @__nucleor_vec_len(ptr "); sb_append(out_sb, mptr); sb_append(out_sb, ")\n");
                        val = mr;
                    }
                    else if str_eq(meth, "get") {
                        p = skip_ws(source, p, len);
                        let ma: str = emit_expr(source, p, len, reg, lbl, sc, fn_names, param_names, param_count, 0, out_sb, str_sb);
                        let mav: str = extract_field(ma, 0);
                        p = extract_field_int(ma, 1);
                        reg = extract_field_int(ma, 2);
                        lbl = extract_field_int(ma, 3);
                        sc = extract_field_int(ma, 4);
                        let mr: str = str_concat("%r.", str_from_int(reg));
                        reg = reg + 1;
                        sb_append(out_sb, "  "); sb_append(out_sb, mr); sb_append(out_sb, " = call i64 @__nucleor_vec_get(ptr "); sb_append(out_sb, mptr); sb_append(out_sb, ", i64 "); sb_append(out_sb, mav); sb_append(out_sb, ")\n");
                        val = mr;
                    }
                    else if str_eq(meth, "push") {
                        p = skip_ws(source, p, len);
                        let ma: str = emit_expr(source, p, len, reg, lbl, sc, fn_names, param_names, param_count, 0, out_sb, str_sb);
                        let mav: str = extract_field(ma, 0);
                        p = extract_field_int(ma, 1);
                        reg = extract_field_int(ma, 2);
                        lbl = extract_field_int(ma, 3);
                        sc = extract_field_int(ma, 4);
                        sb_append(out_sb, "  call void @__nucleor_vec_push(ptr "); sb_append(out_sb, mptr); sb_append(out_sb, ", i64 "); sb_append(out_sb, mav); sb_append(out_sb, ")\n");
                    }
                    else if str_eq(meth, "pop") {
                        sb_append(out_sb, "  call void @__nucleor_vec_pop(ptr "); sb_append(out_sb, mptr); sb_append(out_sb, ")\n");
                    };
                    p = skip_ws(source, p, len);
                    if p < len && str_char_at(source, p) == 41 { p = p + 1; };
                };
            };
        };
    }
    else if ch == 40 {
        // Parenthesized expression
        p = p + 1; // skip (
        let sub: str = emit_expr(source, p, len, reg, lbl, sc, fn_names, param_names, param_count, 0, out_sb, str_sb);
        val = extract_field(sub, 0);
        p = extract_field_int(sub, 1);
        reg = extract_field_int(sub, 2);
        lbl = extract_field_int(sub, 3);
        sc = extract_field_int(sub, 4);
        p = skip_ws(source, p, len);
        if p < len && str_char_at(source, p) == 41 { p = p + 1; }; // skip )
    }
    else if ch == 33 {
        // Unary not: !expr (min_prec=6 so ! only applies to immediate operand, not full expression)
        p = p + 1;
        let sub: str = emit_expr(source, p, len, reg, lbl, sc, fn_names, param_names, param_count, 6, out_sb, str_sb);
        let sv: str = extract_field(sub, 0);
        p = extract_field_int(sub, 1);
        reg = extract_field_int(sub, 2);
        lbl = extract_field_int(sub, 3);
        sc = extract_field_int(sub, 4);
        let r: str = str_concat("%r.", str_from_int(reg));
        reg = reg + 1;
        sb_append(out_sb, "  "); sb_append(out_sb, r); sb_append(out_sb, " = icmp eq i64 "); sb_append(out_sb, sv); sb_append(out_sb, ", 0\n");
        let r2: str = str_concat("%r.", str_from_int(reg));
        reg = reg + 1;
        sb_append(out_sb, "  "); sb_append(out_sb, r2); sb_append(out_sb, " = zext i1 "); sb_append(out_sb, r); sb_append(out_sb, " to i64\n");
        val = r2;
    };

    // Now check for binary operators
    p = skip_ws(source, p, len);
    let mut cont: bool = true;
    while cont && p < len {
        let op_ch: i32 = str_char_at(source, p);
        let mut op_str: str = "";
        let mut is_cmp: bool = false;
        let mut op_len: i32 = 0;

        // Two-char ops first
        if p + 1 < len {
            let op2: i32 = str_char_at(source, p + 1);
            if op_ch == 61 && op2 == 61 { op_str = "icmp eq"; is_cmp = true; op_len = 2; }
            else if op_ch == 33 && op2 == 61 { op_str = "icmp ne"; is_cmp = true; op_len = 2; }
            else if op_ch == 60 && op2 == 61 { op_str = "icmp sle"; is_cmp = true; op_len = 2; }
            else if op_ch == 62 && op2 == 61 { op_str = "icmp sge"; is_cmp = true; op_len = 2; }
            else if op_ch == 38 && op2 == 38 { op_str = "and"; op_len = 2; }
            else if op_ch == 124 && op2 == 124 { op_str = "or"; op_len = 2; };
        };
        if op_len == 0 {
            if op_ch == 43 { op_str = "add"; op_len = 1; }
            else if op_ch == 45 { op_str = "sub"; op_len = 1; }
            else if op_ch == 42 { op_str = "mul"; op_len = 1; }
            else if op_ch == 47 { op_str = "sdiv"; op_len = 1; }
            else if op_ch == 37 { op_str = "srem"; op_len = 1; }
            else if op_ch == 60 { op_str = "icmp slt"; is_cmp = true; op_len = 1; }
            else if op_ch == 62 { op_str = "icmp sgt"; is_cmp = true; op_len = 1; };
        };

        // Operator precedence: || =1, && =2, comparisons =3, +- =4, */% =5
        let mut op_prec: i32 = 0;
        if str_eq(op_str, "mul") || str_eq(op_str, "sdiv") || str_eq(op_str, "srem") { op_prec = 5; }
        else if str_eq(op_str, "add") || str_eq(op_str, "sub") { op_prec = 4; }
        else if is_cmp { op_prec = 3; }
        else if str_eq(op_str, "and") { op_prec = 2; }
        else if str_eq(op_str, "or") { op_prec = 1; }
        else { op_prec = 1; };

        if op_len > 0 && op_prec >= min_prec {
            p = p + op_len;
            p = skip_ws(source, p, len);
            // Parse RHS with higher precedence (Pratt parsing)
            let rhs: str = emit_expr(source, p, len, reg, lbl, sc, fn_names, param_names, param_count, op_prec + 1, out_sb, str_sb);
            let rv: str = extract_field(rhs, 0);
            p = extract_field_int(rhs, 1);
            reg = extract_field_int(rhs, 2);
            lbl = extract_field_int(rhs, 3);
            sc = extract_field_int(rhs, 4);

            let r: str = str_concat("%r.", str_from_int(reg));
            reg = reg + 1;
            if is_cmp {
                let rc: str = str_concat("%r.", str_from_int(reg));
                reg = reg + 1;
                sb_append(out_sb, "  "); sb_append(out_sb, r); sb_append(out_sb, " = "); sb_append(out_sb, op_str); sb_append(out_sb, " i64 "); sb_append(out_sb, val); sb_append(out_sb, ", "); sb_append(out_sb, rv); sb_append(out_sb, "\n");
                sb_append(out_sb, "  "); sb_append(out_sb, rc); sb_append(out_sb, " = zext i1 "); sb_append(out_sb, r); sb_append(out_sb, " to i64\n");
                val = rc;
            } else {
                sb_append(out_sb, "  "); sb_append(out_sb, r); sb_append(out_sb, " = "); sb_append(out_sb, op_str); sb_append(out_sb, " i64 "); sb_append(out_sb, val); sb_append(out_sb, ", "); sb_append(out_sb, rv); sb_append(out_sb, "\n");
                val = r;
            };
            p = skip_ws(source, p, len);
        } else {
            cont = false;
        };
    };

    // Pack result: VALUE|POS|REG|LBL|SC (instructions already in out_sb, strings in str_sb)
    return str_concat(val, str_concat("|", str_concat(str_from_int(p), str_concat("|", str_concat(str_from_int(reg), str_concat("|", str_concat(str_from_int(lbl), str_concat("|", str_from_int(sc)))))))));
}

// Emit a condition expression (same as emit_expr but stops at { )
fn emit_cond(source: str, pos: i32, len: i32, reg_in: i32, lbl_in: i32, sc_in: i32, fn_names: str, param_names: str, param_count: i32, out_sb: i64, str_sb: i64) -> str {
    // A condition ends at '{'
    // Just use emit_expr — it naturally stops at { since { is not an operator or primary
    return emit_expr(source, pos, len, reg_in, lbl_in, sc_in, fn_names, param_names, param_count, 0, out_sb, str_sb);
}

// ============================================================
// Function call emitter
// ============================================================
fn emit_call(source: str, name_start: i32, paren_pos: i32, len: i32, reg_in: i32, lbl_in: i32, sc_in: i32, fn_names: str, param_names: str, param_count: i32, out_sb: i64, str_sb: i64) -> str {
    let mut reg: i32 = reg_in;
    let mut lbl: i32 = lbl_in;
    let mut sc: i32 = sc_in;

    let fname: str = str_substring(source, name_start, paren_pos);
    // Trim trailing whitespace from fname
    let mut flen: i32 = str_len(fname);
    while flen > 0 && is_ws(str_char_at(fname, flen - 1)) { flen = flen - 1; };
    let clean_fname: str = str_substring(fname, 0, flen);

    let mut p: i32 = paren_pos + 1; // skip (

    // Parse arguments
    let mut arg_vals: str = "";
    let mut arg_count: i32 = 0;
    let mut arg_types: str = ""; // track if arg is string (from str literal or str_concat)

    p = skip_ws(source, p, len);
    while p < len && str_char_at(source, p) != 41 {
        if str_char_at(source, p) == 44 {
            p = p + 1;
            p = skip_ws(source, p, len);
        } else {
            let arg_result: str = emit_expr(source, p, len, reg, lbl, sc, fn_names, param_names, param_count, 0, out_sb, str_sb);
            let av: str = extract_field(arg_result, 0);
            p = extract_field_int(arg_result, 1);
            reg = extract_field_int(arg_result, 2);
            lbl = extract_field_int(arg_result, 3);
            sc = extract_field_int(arg_result, 4);

            if arg_count > 0 { arg_vals = str_concat(arg_vals, ","); };
            arg_vals = str_concat(arg_vals, av);
            arg_count = arg_count + 1;
            p = skip_ws(source, p, len);
        };
    };
    if p < len { p = p + 1; }; // skip )

    // Map builtin function names to runtime names
    let mut rt_name: str = clean_fname;
    let mut is_void: bool = false;
    let mut use_ptr_args: bool = false;

    if str_eq(clean_fname, "print") {
        rt_name = "__nucleor_print_str";
        is_void = true;
        use_ptr_args = true;
    }
    else if str_eq(clean_fname, "print_int") { rt_name = "__nucleor_print_i64"; }
    else if str_eq(clean_fname, "print_bool") {
        rt_name = "__nucleor_print_bool";
        is_void = true;
    }
    else if str_eq(clean_fname, "str_len") { rt_name = "__nucleor_str_len"; use_ptr_args = true; }
    else if str_eq(clean_fname, "str_eq") { rt_name = "__nucleor_str_eq"; use_ptr_args = true; }
    else if str_eq(clean_fname, "str_char_at") { rt_name = "__nucleor_str_char_at"; use_ptr_args = true; }
    else if str_eq(clean_fname, "str_substring") { rt_name = "__nucleor_str_substring"; use_ptr_args = true; }
    else if str_eq(clean_fname, "str_concat") { rt_name = "__nucleor_str_concat"; use_ptr_args = true; }
    else if str_eq(clean_fname, "file_read_string") { rt_name = "__nucleor_file_read_string"; use_ptr_args = true; }
    else if str_eq(clean_fname, "file_write_string") {
        rt_name = "__nucleor_file_write_string";
        is_void = true;
        use_ptr_args = true;
    }
    else if str_eq(clean_fname, "system") { rt_name = "__nucleor_system"; use_ptr_args = true; }
    else if str_eq(clean_fname, "sb_new") { rt_name = "__nucleor_sb_new"; }
    else if str_eq(clean_fname, "sb_append") {
        rt_name = "__nucleor_sb_append";
        is_void = true;
        use_ptr_args = true;
    }
    else if str_eq(clean_fname, "sb_to_str") { rt_name = "__nucleor_sb_to_str"; }
    else if str_eq(clean_fname, "args_count") { rt_name = "__nucleor_args_count"; }
    else if str_eq(clean_fname, "args_get") { rt_name = "__nucleor_args_get"; }
    else if str_eq(clean_fname, "vec_set") {
        rt_name = "__nucleor_vec_set";
        is_void = true;
        use_ptr_args = true;
    }
    else if str_eq(clean_fname, "file_append_string") {
        rt_name = "__nucleor_file_append_string";
        is_void = true;
        use_ptr_args = true;
    }
    else if str_eq(clean_fname, "sb_free") {
        rt_name = "__nucleor_sb_free";
        is_void = true;
    };

    // Build call instruction
    let mut call_args: str = "";
    let mut ai2: i32 = 0;
    while ai2 < arg_count {
        let av2: str = extract_arg(arg_vals, ai2);
        if ai2 > 0 { call_args = str_concat(call_args, ", "); };
        // For ptr args, inttoptr the i64 value
        if use_ptr_args && needs_ptr_arg(clean_fname, ai2) {
            let ptr_reg: str = str_concat("%r.", str_from_int(reg));
            reg = reg + 1;
            sb_append(out_sb, "  "); sb_append(out_sb, ptr_reg); sb_append(out_sb, " = inttoptr i64 "); sb_append(out_sb, av2); sb_append(out_sb, " to ptr\n");
            call_args = str_concat(call_args, str_concat("ptr ", ptr_reg));
        } else {
            call_args = str_concat(call_args, str_concat("i64 ", av2));
        };
        ai2 = ai2 + 1;
    };

    let mut val: str = "0";
    if is_void {
        sb_append(out_sb, "  call void @"); sb_append(out_sb, rt_name); sb_append(out_sb, "("); sb_append(out_sb, call_args); sb_append(out_sb, ")\n");
    } else {
        // Check if return type is ptr (str_concat, file_read_string, str_substring)
        if returns_ptr(clean_fname) {
            let pr: str = str_concat("%r.", str_from_int(reg));
            reg = reg + 1;
            sb_append(out_sb, "  "); sb_append(out_sb, pr); sb_append(out_sb, " = call ptr @"); sb_append(out_sb, rt_name); sb_append(out_sb, "("); sb_append(out_sb, call_args); sb_append(out_sb, ")\n");
            let r: str = str_concat("%r.", str_from_int(reg));
            reg = reg + 1;
            sb_append(out_sb, "  "); sb_append(out_sb, r); sb_append(out_sb, " = ptrtoint ptr "); sb_append(out_sb, pr); sb_append(out_sb, " to i64\n");
            val = r;
        } else {
            let r: str = str_concat("%r.", str_from_int(reg));
            reg = reg + 1;
            sb_append(out_sb, "  "); sb_append(out_sb, r); sb_append(out_sb, " = call i64 @"); sb_append(out_sb, rt_name); sb_append(out_sb, "("); sb_append(out_sb, call_args); sb_append(out_sb, ")\n");
            val = r;
        };
    };

    // Pack result: VALUE|POS|REG|LBL|SC (instructions already in out_sb, strings in str_sb)
    return str_concat(val, str_concat("|", str_concat(str_from_int(p), str_concat("|", str_concat(str_from_int(reg), str_concat("|", str_concat(str_from_int(lbl), str_concat("|", str_from_int(sc)))))))));
}

// Check if a builtin function argument at position idx should be ptr
fn needs_ptr_arg(fname: str, idx: i32) -> bool {
    if str_eq(fname, "print") { return true; }
    else if str_eq(fname, "str_len") { return idx == 0; }
    else if str_eq(fname, "str_eq") { return true; }
    else if str_eq(fname, "str_char_at") { return idx == 0; }
    else if str_eq(fname, "str_substring") { return idx == 0; }
    else if str_eq(fname, "str_concat") { return true; }
    else if str_eq(fname, "file_read_string") { return idx == 0; }
    else if str_eq(fname, "file_write_string") { return true; }
    else if str_eq(fname, "system") { return idx == 0; }
    else if str_eq(fname, "sb_append") { return idx == 1; }
    else if str_eq(fname, "vec_set") { return idx == 0; }
    else if str_eq(fname, "file_append_string") { return true; }
    else { return false; };
    return false;
}

// Check if a builtin function returns ptr
fn returns_ptr(fname: str) -> bool {
    return str_eq(fname, "str_concat") || str_eq(fname, "str_substring") || str_eq(fname, "file_read_string") || str_eq(fname, "sb_to_str") || str_eq(fname, "args_get");
}

// ============================================================
// Pipe-delimited field extraction helpers
// ============================================================
fn extract_field(packed: str, idx: i32) -> str {
    let plen: i32 = str_len(packed);
    let mut field: i32 = 0;
    let mut start: i32 = 0;
    let mut i: i32 = 0;
    while i <= plen {
        if i == plen || str_char_at(packed, i) == 124 {
            if field == idx {
                return str_substring(packed, start, i);
            };
            field = field + 1;
            start = i + 1;
        };
        i = i + 1;
    };
    return "";
}

fn extract_field_int(packed: str, idx: i32) -> i32 {
    let s: str = extract_field(packed, idx);
    return parse_int(s);
}

fn parse_int(s: str) -> i32 {
    let slen: i32 = str_len(s);
    if slen == 0 { return 0; };
    let mut neg: bool = false;
    let mut i: i32 = 0;
    if str_char_at(s, 0) == 45 { neg = true; i = 1; };
    let mut val: i32 = 0;
    while i < slen {
        let d: i32 = str_char_at(s, i) - 48;
        if d >= 0 && d <= 9 { val = val * 10 + d; };
        i = i + 1;
    };
    if neg { return 0 - val; };
    return val;
}

// Extract comma-separated argument by index
fn extract_arg(args: str, idx: i32) -> str {
    let alen: i32 = str_len(args);
    let mut field: i32 = 0;
    let mut start: i32 = 0;
    let mut i: i32 = 0;
    while i <= alen {
        if i == alen || str_char_at(args, i) == 44 {
            if field == idx {
                return str_substring(args, start, i);
            };
            field = field + 1;
            start = i + 1;
        };
        i = i + 1;
    };
    return "0";
}

// Extract param name by index from ",name1,name2," format
fn emit_extract_param_name(param_names: str, idx: i32) -> str {
    let plen: i32 = str_len(param_names);
    let mut field: i32 = 0;
    let mut start: i32 = 1; // skip leading comma
    let mut i: i32 = 1;
    while i < plen {
        if str_char_at(param_names, i) == 44 {
            if field == idx {
                return str_substring(param_names, start, i);
            };
            field = field + 1;
            start = i + 1;
        };
        i = i + 1;
    };
    return "";
}

// ============================================================
// Stack helpers for if/while context (semicolon-delimited entries, comma-separated fields)
// ============================================================
fn extract_if_top(stack: str, depth: i32) -> str {
    // Stack format: "field0,field1;field0,field1;"
    // Return the last entry
    let slen: i32 = str_len(stack);
    if slen == 0 { return "0,0"; };
    // Find the start of the last entry (second-to-last semicolon + 1)
    let mut last_semi: i32 = slen - 1;
    if last_semi >= 0 && str_char_at(stack, last_semi) == 59 { last_semi = last_semi - 1; };
    let mut start: i32 = 0;
    let mut i: i32 = last_semi;
    while i >= 0 {
        if str_char_at(stack, i) == 59 { start = i + 1; i = 0 - 1; }
        else { i = i - 1; };
    };
    return str_substring(stack, start, last_semi + 1);
}

fn extract_while_top(stack: str, depth: i32) -> str {
    return extract_if_top(stack, depth);
}

fn extract_if_field(ctx: str, idx: i32) -> i32 {
    return parse_int(extract_arg(ctx, idx));
}

fn replace_if_top(stack: str, depth: i32, merge_lbl: i32) -> str {
    // Replace the else_lbl in the top entry with -1 (consumed)
    let slen: i32 = str_len(stack);
    if slen == 0 { return stack; };
    let mut last_semi: i32 = slen - 1;
    if last_semi >= 0 && str_char_at(stack, last_semi) == 59 { last_semi = last_semi - 1; };
    let mut start: i32 = 0;
    let mut i: i32 = last_semi;
    while i >= 0 {
        if str_char_at(stack, i) == 59 { start = i + 1; i = 0 - 1; }
        else { i = i - 1; };
    };
    let prefix: str = str_substring(stack, 0, start);
    return str_concat(prefix, str_concat("-1,", str_concat(str_from_int(merge_lbl), ",0;")));
}

fn replace_if_top_3(stack: str, depth: i32, merge_lbl: i32, then_term: i32) -> str {
    // Replace top entry with: -1,merge_lbl,then_term
    let slen: i32 = str_len(stack);
    if slen == 0 { return stack; };
    let mut last_semi: i32 = slen - 1;
    if last_semi >= 0 && str_char_at(stack, last_semi) == 59 { last_semi = last_semi - 1; };
    let mut start: i32 = 0;
    let mut i: i32 = last_semi;
    while i >= 0 {
        if str_char_at(stack, i) == 59 { start = i + 1; i = 0 - 1; }
        else { i = i - 1; };
    };
    let prefix: str = str_substring(stack, 0, start);
    return str_concat(prefix, str_concat("-1,", str_concat(str_from_int(merge_lbl), str_concat(",", str_concat(str_from_int(then_term), ";")))));
}

fn pop_stack(stack: str) -> str {
    let slen: i32 = str_len(stack);
    if slen == 0 { return ""; };
    // Remove last entry (everything from last-but-one semicolon to end)
    let mut last_semi: i32 = slen - 1;
    if last_semi >= 0 && str_char_at(stack, last_semi) == 59 { last_semi = last_semi - 1; };
    let mut prev_semi: i32 = 0;
    let mut i: i32 = last_semi;
    while i >= 0 {
        if str_char_at(stack, i) == 59 { prev_semi = i + 1; i = 0 - 1; }
        else { i = i - 1; };
    };
    return str_substring(stack, 0, prev_semi);
}

// ============================================================
// Full pipeline: .nr file -> .ll -> .exe
// ============================================================
fn compile_to_native(input_path: str, output_path: str) -> i32 {
    print(str_concat("  input:  ", input_path));
    print(str_concat("  output: ", output_path));
    let source: str = file_read_string(input_path);
    if str_len(source) == 0 { print("  ERROR: cannot read input"); return 1; };
    print(str_concat("  source: ", str_concat(str_from_int(str_len(source)), " bytes")));
    let raw_ir: str = emit_llvm_ir(source);
    let ll_code: str = fixup_unterminated_blocks(raw_ir);
    let ll_path: str = str_concat(output_path, ".ll");
    file_write_string(ll_path, ll_code);
    let rt_path: str = "stdlib/runtime/nucleor_llvm_rt.c";
    let cmd: str = str_concat("\"C:\\Program Files\\LLVM\\bin\\clang.exe\" ", str_concat(ll_path, str_concat(" ", str_concat(rt_path, str_concat(" -o ", str_concat(output_path, " -Wno-override-module -Wl,/STACK:8388608 2>&1"))))));
    let rc: i32 = system(cmd);
    if rc == 0 { print(str_concat("  compiled: ", output_path)); return 0; }
    else { print("  ERROR: clang compilation failed"); return 1; };
}

// ============================================================
// Tests
// ============================================================
fn run_one(name: str, path: str, exe: str, expect: i32) -> i32 {
    print(name);
    let r: i32 = compile_to_native(path, exe);
    if r == 0 {
        let rc: i32 = system(str_concat(".\\", exe));
        print(str_concat("  exit: ", str_from_int(rc)));
        if rc == expect { print("  PASS"); return 0; } else { print("  FAIL"); return 1; };
    };
    return r;
}

fn main() -> i32 {
    let mut pass: i32 = 0;
    let mut fail: i32 = 0;

    // Write test programs
    file_write_string("target/llvm_t1.nr", "fn main() -> i32 { return 42; }");
    file_write_string("target/llvm_t2.nr", "fn main() -> i32 { let x: i32 = 6; let y: i32 = 7; return x * y; }");
    file_write_string("target/llvm_t3.nr", "fn add(a: i32, b: i32) -> i32 { return a + b; }\nfn main() -> i32 { return add(20, 22); }");
    file_write_string("target/llvm_t4.nr", "fn main() -> i32 { let x: i32 = 10; if x > 5 { return 1; } else { return 0; }; }");
    file_write_string("target/llvm_t5.nr", "fn main() -> i32 { let mut sum: i32 = 0; let mut i: i32 = 1; while i <= 10 { sum = sum + i; i = i + 1; }; return sum; }");
    file_write_string("target/llvm_t6.nr", "fn double(x: i32) -> i32 { return x + x; }\nfn main() -> i32 { return double(double(10)) + 2; }");
    file_write_string("target/llvm_t7.nr", "fn main() -> i32 { print(\"hello LLVM\"); print_int(42); return 0; }");
    file_write_string("target/llvm_t8.nr", "fn main() -> i32 { let s: str = str_concat(\"hello \", \"world\"); print(s); return 0; }");
    file_write_string("target/llvm_t9.nr", "fn main() -> i32 { file_write_string(\"target/llvm_io_test.txt\", \"LLVM writes files\"); let s: str = file_read_string(\"target/llvm_io_test.txt\"); print(s); return 0; }");

    if run_one("T1: return 42", "target/llvm_t1.nr", "target\\llvm_t1.exe", 42) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T2: arithmetic", "target/llvm_t2.nr", "target\\llvm_t2.exe", 42) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T3: fn call", "target/llvm_t3.nr", "target\\llvm_t3.exe", 42) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T4: if/else", "target/llvm_t4.nr", "target\\llvm_t4.exe", 1) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T5: while", "target/llvm_t5.nr", "target\\llvm_t5.exe", 55) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T6: nested", "target/llvm_t6.nr", "target\\llvm_t6.exe", 42) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T7: print", "target/llvm_t7.nr", "target\\llvm_t7.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T8: str_concat", "target/llvm_t8.nr", "target\\llvm_t8.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T9: file I/O", "target/llvm_t9.nr", "target\\llvm_t9.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T10: medium", "target/medium_test.nr", "target\\medium_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T11: mini", "target/llvm_mini_compiler.nr", "target\\llvm_mini_compiler.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T12: compile", "target/llvm_compile_test.nr", "target\\llvm_compile_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    file_write_string("target/vec_test.nr", "fn main() -> i32 {\n    let mut v: Vec<i32> = Vec::new();\n    v.push(10);\n    v.push(20);\n    v.push(30);\n    let n: i32 = v.len();\n    if n != 3 { print(\"FAIL: len\"); return 1; };\n    if v.get(0) != 10 { print(\"FAIL: get(0)\"); return 1; };\n    if v.get(1) != 20 { print(\"FAIL: get(1)\"); return 1; };\n    if v.get(2) != 30 { print(\"FAIL: get(2)\"); return 1; };\n    let mut sum: i32 = 0;\n    let mut i: i32 = 0;\n    while i < v.len() { sum = sum + v.get(i); i = i + 1; };\n    if sum != 60 { print(\"FAIL: sum\"); return 1; };\n    print(\"ALL VEC TESTS PASS\");\n    return 0;\n}");
    if run_one("T13: vec", "target/vec_test.nr", "target\\vec_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    file_write_string("target/elseif_while_test.nr", "fn main() -> i32 {\n    let c: i32 = 47;\n    let mut pos: i32 = 0;\n    let len: i32 = 10;\n    if c == 32 { pos = pos + 1; }\n    else if c == 47 { while pos < len { pos = pos + 1; }; }\n    else if c == 34 { pos = 99; };\n    return pos;\n}");
    if run_one("T14: elseif_while", "target/elseif_while_test.nr", "target\\elseif_while_test.exe", 10) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T15: real_lexer", "target/const_test_output.nr", "target\\real_lexer_llvm.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    file_write_string("target/sb_test.nr", "fn main() -> i32 {\n    let sb: i64 = sb_new();\n    sb_append(sb, \"hello\");\n    sb_append(sb, \" \");\n    sb_append(sb, \"world\");\n    let result: str = sb_to_str(sb);\n    if str_eq(result, \"hello world\") { print(\"SB PASS\"); return 0; };\n    print(\"SB FAIL\");\n    return 1;\n}");
    if run_one("T16: stringbuilder", "target/sb_test.nr", "target\\sb_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T18: string_ops", "target/string_ops_test.nr", "target\\string_ops_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T19: hashmap", "target/hashmap_test.nr", "target\\hashmap_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T20: error_utils", "target/error_utils_test.nr", "target\\error_utils_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T21: file_utils", "target/file_utils_test.nr", "target\\file_utils_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T22: typesys", "target/typesys_test.nr", "target\\typesys_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T23: typecheck", "target/typecheck_test.nr", "target\\typecheck_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T24: ir", "target/ir_test.nr", "target\\ir_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T25: ir_emit", "target/ir_emit_test.nr", "target\\ir_emit_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T26: lexer", "target/lexer_test.nr", "target\\lexer_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T27: parser", "target/parser_test.nr", "target\\parser_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T28: ast_lower", "target/ast_lower_test.nr", "target\\ast_lower_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T29: pipeline", "target/pipeline_test.nr", "target\\pipeline_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T30: pipeline+str", "target/pipeline_str_test.nr", "target\\pipeline_str_test.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if run_one("T31: s1-compiler", "target/nucleor_s1_compiler.nr", "target\\nucleor_s1.exe", 1) == 0 { pass = pass + 1; } else { fail = fail + 1; };

    // T17: Self-compilation (guarded against infinite recursion via guard file)
    let guard_val: str = file_read_string("target/self_compile_guard.txt");
    if str_eq(guard_val, "") {
        file_write_string("target/self_compile_guard.txt", "GUARD");
        if run_one("T17: self-compile", "stdlib/llvm_emitter.nr", "target\\self_emitter.exe", 0) == 0 { pass = pass + 1; } else { fail = fail + 1; };
    } else {
        print("T17: self-compile (skipped - recursion guard)");
    };

    print("================================================");
    print(str_concat("  passed: ", str_from_int(pass)));
    print(str_concat("  failed: ", str_from_int(fail)));
    if fail == 0 { print("  ALL LLVM TESTS PASS"); };
    print("================================================");
    return fail;
}
