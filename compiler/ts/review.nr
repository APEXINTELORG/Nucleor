// =====================================================
// S12b — REVIEW HOOKS (single coupling surface)
// Delete this section + call sites to fully remove S12b
// =====================================================
fn review_active(review_path: str) -> i64 {
    if str_len(review_path) > 0 { return 1; };
    return 0;
}
fn review_emit(review_path: str, json_line: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    file_append_string(review_path, str_concat(json_line, "\n"));
    return 0;
}
fn review_filter_allows_checker(filter: str, checker: str) -> i64 {
    if str_len(filter) == 0 { return 1; };
    if str_eq(filter, "findings") { return 1; };
    // function= filter doesn't restrict by checker
    if str_len(filter) > 9 && str_eq(str_substring(filter, 0, 9), "function=") { return 1; };
    let flen: i64 = str_len(filter);
    let clen: i64 = str_len(checker);
    let mut i: i64 = 0;
    while i <= flen - clen {
        if str_eq(str_substring(filter, i, i + clen), checker) { return 1; };
        i = i + 1;
    };
    return 0;
}
fn review_filter_allows_function(filter: str, fn_name: str) -> i64 {
    if str_len(filter) == 0 { return 1; };
    // Check for function= in comma-separated filter parts
    let flen: i64 = str_len(filter);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    let mut found_fn_filter: i64 = 0;
    while i <= flen {
        let at_end: i64 = i == flen;
        let mut at_comma: i64 = 0;
        if at_end == 0 { if str_char_at(filter, i) == 44 { at_comma = 1; }; };
        if at_comma == 1 || at_end == 1 {
            let part: str = str_substring(filter, start, i);
            if str_len(part) > 9 && str_eq(str_substring(part, 0, 9), "function=") {
                found_fn_filter = 1;
                let target: str = str_substring(part, 9, str_len(part));
                if str_eq(target, fn_name) { return 1; };
            };
            start = i + 1;
        };
        i = i + 1;
    };
    // If no function= filter was found, allow all functions
    if found_fn_filter == 0 { return 1; };
    return 0;
}
fn review_on_checker_enter(review_path: str, checker: str, fn_name: str, filter: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    if review_filter_allows_checker(filter, checker) == 0 { return 0; };
    if review_filter_allows_function(filter, fn_name) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"checker_enter\",\"checker\":\"");
    sb_append(sb, checker); sb_append(sb, "\",\"function\":\""); sb_append(sb, fn_name); sb_append(sb, "\"}");
    return review_emit(review_path, sb_to_str(sb));
}
fn review_on_checker_exit(review_path: str, checker: str, fn_name: str, findings: i64, filter: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    if review_filter_allows_checker(filter, checker) == 0 { return 0; };
    if review_filter_allows_function(filter, fn_name) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"checker_exit\",\"checker\":\"");
    sb_append(sb, checker); sb_append(sb, "\",\"function\":\""); sb_append(sb, fn_name);
    sb_append(sb, "\",\"findings\":"); sb_append(sb, str_from_int(findings)); sb_append(sb, "}");
    return review_emit(review_path, sb_to_str(sb));
}
fn review_on_state_transition(review_path: str, checker: str, fn_name: str, symbol: str, from_state: str, to_state: str, cause: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"state_transition\",\"checker\":\"");
    sb_append(sb, checker); sb_append(sb, "\",\"function\":\""); sb_append(sb, fn_name);
    sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"from_state\":\""); sb_append(sb, from_state);
    sb_append(sb, "\",\"to_state\":\""); sb_append(sb, to_state);
    sb_append(sb, "\",\"cause\":\""); sb_append(sb, cause); sb_append(sb, "\"}");
    return review_emit(review_path, sb_to_str(sb));
}
fn review_on_taint_propagation(review_path: str, fn_name: str, symbol: str, source_sym: str, sanitized: i64) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_propagation\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"taint_source\":\""); sb_append(sb, source_sym);
    sb_append(sb, "\",\"sanitized\":"); if sanitized == 1 { sb_append(sb, "true"); } else { sb_append(sb, "false"); };
    sb_append(sb, "}");
    return review_emit(review_path, sb_to_str(sb));
}
fn review_on_effect_violation(review_path: str, fn_name: str, callee: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"effect_violation\",\"checker\":\"effect\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"declared_effect\":\"pure\",\"actual_effect\":\"io\",\"callee\":\"");
    sb_append(sb, callee); sb_append(sb, "\"}");
    return review_emit(review_path, sb_to_str(sb));
}

// S12b: review event accumulation helpers (all removable)
#[manual_drop]
fn rev_get(own: Vec<i32>) -> Vec<i32> {
    let rev: i64 = own_revents_vec(own);
    if rev < 0 { return Vec::new(); };
    return rev;
}
fn rev_active(own: Vec<i32>) -> i64 {
    let rp: str = own_get_type(own, "__review");
    if str_len(rp) > 0 { return 1; };
    return 0;
}
#[manual_drop]
fn rev_push(own: Vec<i32>, json: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let revents: Vec<i32> = rev_get(own);
    revents.push(json);
    return 0;
}
fn review_acc_move(own: Vec<i32>, fn_name: str, symbol: str, cause: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"state_transition\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"from_state\":\"owned\",\"to_state\":\"moved\",\"cause\":\"");
    sb_append(sb, cause); sb_append(sb, "\"}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_revive(own: Vec<i32>, fn_name: str, symbol: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"state_transition\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"from_state\":\"moved\",\"to_state\":\"owned\",\"cause\":\"reassign\"}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_init(own: Vec<i32>, fn_name: str, symbol: str, type_name: str, is_copy: i64) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"state_transition\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"from_state\":\"uninitialized\",\"to_state\":\"owned\",\"cause\":\"declaration\",\"type\":\"");
    sb_append(sb, type_name); sb_append(sb, "\",\"is_copy\":");
    if is_copy == 1 { sb_append(sb, "true"); } else { sb_append(sb, "false"); };
    sb_append(sb, "}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_call_edge(own: Vec<i32>, fn_name: str, callee: str, argc: i64) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"call_graph_edge\",\"caller\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"callee\":\""); sb_append(sb, callee);
    sb_append(sb, "\",\"arg_count\":"); sb_append(sb, str_from_int(argc)); sb_append(sb, "}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_branch_fork(own: Vec<i32>, fn_name: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"branch_state_fork\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\"}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_branch_merge(own: Vec<i32>, fn_name: str, strategy: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"branch_state_merge\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"strategy\":\""); sb_append(sb, strategy); sb_append(sb, "\"}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_fn_sig(own: Vec<i32>, fn_name: str, param_info: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"function_signature\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"params\":\""); sb_append(sb, param_info); sb_append(sb, "\"}");
    return rev_push(own, sb_to_str(sb));
}
// Taint-specific helpers (use taint Vec instead of own)
#[manual_drop]
fn trev_get(taint: Vec<i32>) -> Vec<i32> {
    let rev: i64 = taint_get(taint, "__revents");
    if rev < 0 { return Vec::new(); };
    return rev;
}
#[manual_drop]
fn trev_push(taint: Vec<i32>, json: str) -> i64 {
    let revents: Vec<i32> = trev_get(taint);
    revents.push(json);
    return 0;
}
fn review_acc_taint_prop(taint: Vec<i32>, fn_name: str, symbol: str, source_sym: str) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_propagation\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"taint_source\":\""); sb_append(sb, source_sym); sb_append(sb, "\",\"sanitized\":false}");
    return trev_push(taint, sb_to_str(sb));
}
fn review_acc_taint_sanitize(taint: Vec<i32>, fn_name: str, symbol: str) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_propagation\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"taint_source\":\"sanitize\",\"sanitized\":true}");
    return trev_push(taint, sb_to_str(sb));
}
fn review_acc_taint_sink(taint: Vec<i32>, fn_name: str, symbol: str, sink: str) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_sink_attempt\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"sink\":\""); sb_append(sb, sink); sb_append(sb, "\",\"blocked\":false}");
    return trev_push(taint, sb_to_str(sb));
}
fn review_acc_taint_call(taint: Vec<i32>, fn_name: str, callee: str, tainted_arg_count: i64) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_through_call\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"callee\":\""); sb_append(sb, callee);
    sb_append(sb, "\",\"tainted_args\":"); sb_append(sb, str_from_int(tainted_arg_count)); sb_append(sb, "}");
    return trev_push(taint, sb_to_str(sb));
}

