// =====================================================
// MODULE SYSTEM (imports)
// =====================================================

// V2: Parallel import resolution — collect all imports first, then resolve
// independent ones in parallel via threading. Falls back to sequential if
// only one import or threading unavailable.
fn collect_import_paths(src: str, base_dir: str) -> Vec<i32> {
    let mut paths: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(src, lp) == 32 || str_char_at(src, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        let mut prefix_len: i64 = 0;
        if line_len >= 8 && str_eq(str_substring(src, lp, lp + 7), "import ") { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "use ") { prefix_len = 4; };
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < eol && str_char_at(src, qp) == 32 { qp = qp + 1; };
            if qp < eol && str_char_at(src, qp) == 34 {
                let ps: i64 = qp + 1;
                let mut pe: i64 = ps;
                while pe < eol && str_char_at(src, pe) != 34 { pe = pe + 1; };
                let imp_path: str = resolve_import_path(base_dir, str_substring(src, ps, pe));
                paths.push(imp_path);
            };
        };
        p = eol + 1;
    };
    return paths;
}


fn ascii_upper(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c >= 97 && c <= 122 {
            sb_append(sb, str_substring("ABCDEFGHIJKLMNOPQRSTUVWXYZ", c - 97, c - 96));
        } else {
            sb_append(sb, str_substring(s, i, i + 1));
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}




fn explain_error_reference(code: str) -> str {
    return str_concat("docs/spec/Nucleor_Error_Codes.md#", ascii_upper(code));
}

fn explain_error_known(code: str) -> i64 {
    if str_len(explain_error_title(code)) == 0 { return 0; };
    return 1;
}


fn explain_error_render(code: str, json_mode: i64) -> str {
    let title: str = explain_error_title(code);
    let summary: str = explain_error_summary(code);
    let explanation: str = explain_error_explanation(code);
    let reference: str = explain_error_reference(code);
    let steps: Vec<i32> = explain_error_next_steps(code);
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"code\":\""); sb_append(sb, json_escape(code));
        sb_append(sb, "\",\"title\":\""); sb_append(sb, json_escape(title));
        sb_append(sb, "\",\"summary\":\""); sb_append(sb, json_escape(summary));
        sb_append(sb, "\",\"explanation\":\""); sb_append(sb, json_escape(explanation));
        sb_append(sb, "\",\"reference\":\""); sb_append(sb, json_escape(reference));
        sb_append(sb, "\",\"next_steps\":[");
        let mut i: i64 = 0;
        while i < vec_len(steps) {
            if i > 0 { sb_append(sb, ","); };
            sb_append(sb, "\""); sb_append(sb, json_escape(vec_get(steps, i))); sb_append(sb, "\"");
            i = i + 1;
        };
        sb_append(sb, "]}");
        return sb_to_str(sb);
    };
    let mut sb2: i64 = sb_new();
    sb_append(sb2, code); sb_append(sb2, ": "); sb_append(sb2, title); sb_append(sb2, "\n");
    sb_append(sb2, summary); sb_append(sb2, "\n");
    sb_append(sb2, explanation); sb_append(sb2, "\n");
    sb_append(sb2, "reference: "); sb_append(sb2, reference); sb_append(sb2, "\n");
    if vec_len(steps) > 0 {
        sb_append(sb2, "next steps:\n");
        let mut j: i64 = 0;
        while j < vec_len(steps) {
            sb_append(sb2, "- "); sb_append(sb2, vec_get(steps, j)); sb_append(sb2, "\n");
            j = j + 1;
        };
    };
    return sb_to_str(sb2);
}

