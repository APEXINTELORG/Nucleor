// =====================================================
// S12a — STRUCTURED DIAGNOSTIC SURFACE
// =====================================================
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


