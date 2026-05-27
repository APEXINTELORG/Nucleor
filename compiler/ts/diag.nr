// =====================================================
// S12a — STRUCTURED DIAGNOSTIC SURFACE
// =====================================================
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
        if str_eq(str_substring(source, i, i + tlen), target) { fn_start = i; i = slen; };
        i = i + 1;
    };
    if fn_start < 0 { out.push(0); out.push(0); return out; };
    let mut line: i64 = byte_to_line(source, fn_start);
    let mut col: i64 = 1;
    i = fn_start;
    while i < slen - vlen {
        if str_eq(str_substring(source, i, i + vlen), var_name) {
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
fn line_col_to_byte(source: str, line: i64, col: i64) -> i64 {
    let slen: i64 = str_len(source);
    let mut cur_line: i64 = 1;
    let mut i: i64 = 0;
    while i < slen {
        if cur_line == line { return i + col - 1; };
        if str_char_at(source, i) == 10 { cur_line = cur_line + 1; };
        i = i + 1;
    };
    return 0;
}

fn json_escape(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut result: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 34 { sb_append(result, "\\\""); }
        else if c == 92 { sb_append(result, "\\\\"); }
        else if c == 10 { sb_append(result, "\\n"); }
        else if c == 9 { sb_append(result, "\\t"); }
        else { sb_append(result, str_substring(s, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(result);
}

fn source_line_at(source: str, line_num: i64) -> str {
    let slen: i64 = str_len(source);
    let mut cur_line: i64 = 1;
    let mut line_start: i64 = 0;
    let mut i: i64 = 0;
    while i < slen {
        if cur_line == line_num { line_start = i; i = slen; }
        else if str_char_at(source, i) == 10 { cur_line = cur_line + 1; };
        i = i + 1;
    };
    if cur_line < line_num { return ""; };
    // Find end of line
    let mut line_end: i64 = line_start;
    while line_end < slen && str_char_at(source, line_end) != 10 { line_end = line_end + 1; };
    return str_substring(source, line_start, line_end);
}

fn diag_emit_json(diags: Vec<i32>, source: str, src_path: str) -> i64 {
    let cnt: i64 = vec_len(diags);
    let mut ow_cnt: i64 = 0; let mut tn_cnt: i64 = 0; let mut ef_cnt: i64 = 0;
    let mut err_cnt: i64 = 0; let mut warn_cnt: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let checker: str = vec_get(d, 1);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let snippet: str = source_line_at(source, line);
        // Emit JSONL diagnostic
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"diagnostic\",\"id\":\"D-");
        sb_append(sb, str_from_int(i + 1));
        sb_append(sb, "\",\"severity\":\""); sb_append(sb, severity);
        sb_append(sb, "\",\"checker\":\""); sb_append(sb, checker);
        sb_append(sb, "\",\"code\":\""); sb_append(sb, code);
        sb_append(sb, "\",\"message\":\""); sb_append(sb, message);
        sb_append(sb, "\",\"function\":\""); sb_append(sb, fn_name);
        let col: i64 = vec_get(d, 6);
        let related_id: str = vec_get(d, 7);
        sb_append(sb, "\",\"location\":{\"file\":\""); sb_append(sb, src_path);
        sb_append(sb, "\",\"line\":"); sb_append(sb, str_from_int(line));
        if col > 0 {
            sb_append(sb, ",\"column\":"); sb_append(sb, str_from_int(col));
            let bs: i64 = line_col_to_byte(source, line, col);
            sb_append(sb, ",\"byte_start\":"); sb_append(sb, str_from_int(bs));
            sb_append(sb, ",\"byte_end\":"); sb_append(sb, str_from_int(bs + 1));
        };
        sb_append(sb, "}");
        if str_len(related_id) > 0 {
            sb_append(sb, ",\"related_diagnostics\":[\""); sb_append(sb, related_id); sb_append(sb, "\"]");
        };
        if str_len(snippet) > 0 {
            sb_append(sb, ",\"source_snippet\":{\"text\":\""); sb_append(sb, json_escape(snippet));
            if col > 0 {
                let vlen: i64 = 1; // default highlight length
                sb_append(sb, "\",\"highlight_start\":"); sb_append(sb, str_from_int(col));
                sb_append(sb, ",\"highlight_end\":"); sb_append(sb, str_from_int(col + vlen));
            };
            sb_append(sb, "\"}");
        };
        // Suggestion
        let sug_msg: str = vec_get(d, 8);
        let sug_app: str = vec_get(d, 9);
        if str_len(sug_msg) > 0 {
            sb_append(sb, ",\"suggestion\":{\"message\":\""); sb_append(sb, sug_msg);
            sb_append(sb, "\",\"applicability\":\""); sb_append(sb, sug_app); sb_append(sb, "\"}");
        };
        // Children (notes)
        let child_msg: str = vec_get(d, 10);
        let child_line: i64 = vec_get(d, 11);
        if str_len(child_msg) > 0 {
            sb_append(sb, ",\"children\":[{\"severity\":\"note\",\"message\":\""); sb_append(sb, child_msg);
            if child_line > 0 {
                sb_append(sb, "\",\"location\":{\"line\":"); sb_append(sb, str_from_int(child_line)); sb_append(sb, "}");
            };
            sb_append(sb, "\"}]");
        };
        sb_append(sb, "}");
        print(sb_to_str(sb));
        if str_eq(severity, "error") { err_cnt = err_cnt + 1; }
        else { warn_cnt = warn_cnt + 1; };
        if str_eq(checker, "ownership") { ow_cnt = ow_cnt + 1; }
        else if str_eq(checker, "taint") { tn_cnt = tn_cnt + 1; }
        else if str_eq(checker, "effect") { ef_cnt = ef_cnt + 1; };
        i = i + 1;
    };
    // Emit summary
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"summary\",\"file\":\""); sb_append(sb, src_path);
    sb_append(sb, "\",\"checkers_run\":[\"ownership\",\"taint\",\"effect\"]");
    sb_append(sb, ",\"diagnostics_emitted\":"); sb_append(sb, str_from_int(cnt));
    sb_append(sb, ",\"by_severity\":{\"error\":"); sb_append(sb, str_from_int(err_cnt));
    sb_append(sb, ",\"warning\":"); sb_append(sb, str_from_int(warn_cnt));
    sb_append(sb, "},\"by_checker\":{\"ownership\":"); sb_append(sb, str_from_int(ow_cnt));
    sb_append(sb, ",\"taint\":"); sb_append(sb, str_from_int(tn_cnt));
    sb_append(sb, ",\"effect\":"); sb_append(sb, str_from_int(ef_cnt));
    sb_append(sb, "}");
    if err_cnt > 0 { sb_append(sb, ",\"compilation_result\":\"failure\""); }
    else if warn_cnt > 0 { sb_append(sb, ",\"compilation_result\":\"success_with_warnings\""); }
    else { sb_append(sb, ",\"compilation_result\":\"success\""); };
    sb_append(sb, "}");
    print(sb_to_str(sb));
    return cnt;
}

fn diag_emit_sarif(diags: Vec<i32>, source: str, src_path: str) -> i64 {
    let cnt: i64 = vec_len(diags);
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"version\":\"2.1.0\",\"$schema\":\"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json\",\"runs\":[{\"tool\":{\"driver\":{\"name\":\"nucleor\",\"version\":\"1.0.0\",\"rules\":[");
    sb_append(sb, "{\"id\":\"ownership/OWN-001\",\"shortDescription\":{\"text\":\"use after move\"}},");
    sb_append(sb, "{\"id\":\"taint/TNT-001\",\"shortDescription\":{\"text\":\"tainted data to sensitive sink\"}},");
    sb_append(sb, "{\"id\":\"effect/EFF-001\",\"shortDescription\":{\"text\":\"side effect in pure function\"}}");
    sb_append(sb, "]}},\"results\":[");
    let mut i: i64 = 0;
    while i < cnt {
        if i > 0 { sb_append(sb, ","); };
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let checker: str = vec_get(d, 1);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let col: i64 = vec_get(d, 6);
        let mut level: str = "warning";
        if str_eq(severity, "error") { level = "error"; };
        sb_append(sb, "{\"ruleId\":\""); sb_append(sb, checker); sb_append(sb, "/"); sb_append(sb, code);
        sb_append(sb, "\",\"level\":\""); sb_append(sb, level);
        sb_append(sb, "\",\"message\":{\"text\":\""); sb_append(sb, message);
        sb_append(sb, "\"},\"locations\":[{\"physicalLocation\":{\"artifactLocation\":{\"uri\":\"");
        sb_append(sb, src_path);
        sb_append(sb, "\"},\"region\":{\"startLine\":"); sb_append(sb, str_from_int(line));
        if col > 0 { sb_append(sb, ",\"startColumn\":"); sb_append(sb, str_from_int(col)); };
        let snippet: str = source_line_at(source, line);
        if str_len(snippet) > 0 {
            sb_append(sb, ",\"snippet\":{\"text\":\""); sb_append(sb, json_escape(snippet)); sb_append(sb, "\"}");
        };
        sb_append(sb, "}}}]}");
        i = i + 1;
    };
    sb_append(sb, "]}]}");
    print(sb_to_str(sb));
    return cnt;
}

fn diag_emit_text(diags: Vec<i32>) -> i64 {
    let cnt: i64 = vec_len(diags);
    let mut i: i64 = 0;
    while i < cnt {
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let checker: str = vec_get(d, 1);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let mut sb: i64 = sb_new();
        if str_eq(severity, "error") { sb_append(sb, "ERROR"); } else { sb_append(sb, "WARNING"); };
        sb_append(sb, " ["); sb_append(sb, code); sb_append(sb, "]: ");
        sb_append(sb, message);
        if str_len(fn_name) > 0 { sb_append(sb, " in function '"); sb_append(sb, fn_name); sb_append(sb, "'"); };
        if line > 0 { sb_append(sb, " (line "); sb_append(sb, str_from_int(line)); sb_append(sb, ")"); };
        print(sb_to_str(sb));
        i = i + 1;
    };
    return cnt;
}

