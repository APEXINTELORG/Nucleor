// =====================================================
// rods/jsonl — JSONL evidence-emit rod (NUC-IMPROVE-003)
// =====================================================
// Import: import "stdlib/rods/jsonl.nr"
//
// Emits one JSON object per line to stdout. Schema documented in
// Nucleor_ML_Suite/docs/NUCLEOR_LANGUAGE_FEEDBACK.md (NUC-IMPROVE-003).
// Designed for Python parity runners that want to consume Nucleor
// program output via `json.loads` line by line — no fragile stdout
// scraping.
//
// API:
//   emit_json_run_meta(case, suite, surface, dtype, rows, cols, policy)
//   emit_json_metric_f64(name, value)
//   emit_json_metric_i64(name, value)
//   emit_json_array_f64(name, values, rows, cols)
//   emit_json_array_i64(name, values, rows, cols)
//   emit_json_status(passed)
//
// All emitters write a single newline-terminated line to stdout.
// Values are emitted with stable key order: kind first, then
// type-specific fields, then values/value last.
// =====================================================

// JSON-encode a string: wraps in double quotes, escapes \ and ".
fn jsonl_quote(s: str) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "\"");
    let n: i64 = str_len(s);
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(s, i);
        if c == 92 { sb_append(sb, "\\\\"); }
        else if c == 34 { sb_append(sb, "\\\""); }
        else if c == 10 { sb_append(sb, "\\n"); }
        else if c == 13 { sb_append(sb, "\\r"); }
        else if c == 9 { sb_append(sb, "\\t"); }
        else { sb_append(sb, str_substring(s, i, i + 1)); };
        i = i + 1;
    }
    sb_append(sb, "\"");
    return sb_to_str(sb);
}

// Emit `{"kind":"run_meta","case":...}` with the provided metadata.
fn emit_json_run_meta(case: str, suite: str, surface: str, dtype: str, rows: i64, cols: i64, policy: str) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"run_meta\",\"case\":");
    sb_append(sb, jsonl_quote(case));
    sb_append(sb, ",\"suite\":");
    sb_append(sb, jsonl_quote(suite));
    sb_append(sb, ",\"surface\":");
    sb_append(sb, jsonl_quote(surface));
    sb_append(sb, ",\"dtype\":");
    sb_append(sb, jsonl_quote(dtype));
    sb_append(sb, ",\"shape\":[");
    sb_append(sb, str_from_int(rows));
    sb_append(sb, ",");
    sb_append(sb, str_from_int(cols));
    sb_append(sb, "],\"policy\":");
    sb_append(sb, jsonl_quote(policy));
    sb_append(sb, "}");
    print(sb_to_str(sb));
    return 0;
}

// Emit `{"kind":"metric","name":...,"dtype":"f64","value":...}` for an f64
// scalar. Value is encoded via the existing f64_to_str helper.
fn emit_json_metric_f64(name: str, value: f64) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"metric\",\"name\":");
    sb_append(sb, jsonl_quote(name));
    sb_append(sb, ",\"dtype\":\"f64\",\"value\":");
    sb_append(sb, f64_to_str(value));
    sb_append(sb, "}");
    print(sb_to_str(sb));
    return 0;
}

// Emit `{"kind":"metric","name":...,"dtype":"i64","value":...}` for an i64
// scalar.
fn emit_json_metric_i64(name: str, value: i64) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"metric\",\"name\":");
    sb_append(sb, jsonl_quote(name));
    sb_append(sb, ",\"dtype\":\"i64\",\"value\":");
    sb_append(sb, str_from_int(value));
    sb_append(sb, "}");
    print(sb_to_str(sb));
    return 0;
}

// Emit `{"kind":"array","name":...,"dtype":"f64","shape":[r,c],"values":[…]}`
// for a flat Vec<i64> holding f64 bit patterns (the canonical Nucleor
// runtime representation for narrow-float storage; see NUC-FEEDBACK-002
// workaround). Pass the row/col shape separately since Vec<f64> doesn't
// carry shape metadata at the runtime level.
fn emit_json_array_f64(name: str, values: Vec<i64>, rows: i64, cols: i64) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"array\",\"name\":");
    sb_append(sb, jsonl_quote(name));
    sb_append(sb, ",\"dtype\":\"f64\",\"shape\":[");
    sb_append(sb, str_from_int(rows));
    sb_append(sb, ",");
    sb_append(sb, str_from_int(cols));
    sb_append(sb, "],\"values\":[");
    let n: i64 = vec_len(values);
    let mut i: i64 = 0;
    while i < n {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, f64_to_str(vec_get(values, i)));
        i = i + 1;
    }
    sb_append(sb, "]}");
    print(sb_to_str(sb));
    return 0;
}

// Emit `{"kind":"array","name":...,"dtype":"i64","shape":[r,c],"values":[…]}`
// for a flat Vec<i64>.
fn emit_json_array_i64(name: str, values: Vec<i64>, rows: i64, cols: i64) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"array\",\"name\":");
    sb_append(sb, jsonl_quote(name));
    sb_append(sb, ",\"dtype\":\"i64\",\"shape\":[");
    sb_append(sb, str_from_int(rows));
    sb_append(sb, ",");
    sb_append(sb, str_from_int(cols));
    sb_append(sb, "],\"values\":[");
    let n: i64 = vec_len(values);
    let mut i: i64 = 0;
    while i < n {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, str_from_int(vec_get(values, i)));
        i = i + 1;
    }
    sb_append(sb, "]}");
    print(sb_to_str(sb));
    return 0;
}

// Emit `{"kind":"status","passed":true|false}`.
fn emit_json_status(passed: i64) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"status\",\"passed\":");
    if passed != 0 { sb_append(sb, "true"); } else { sb_append(sb, "false"); };
    sb_append(sb, "}");
    print(sb_to_str(sb));
    return 0;
}
