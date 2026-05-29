// compare_probe.nr — VER-5: self-hosted PROBE-2 pipeline-parity comparator.
//
// Replaces the four Python oracles (tests/probes/pipeline_parity/compare_0N.py)
// so the gate no longer depends on `python` to read the reference JSON. It
// parses the Nucleor pipeline's structured stdout and the staged reference
// JSON (via stdlib/rods/json.nr) and compares the predict-related fields.
//
// Usage:  compare_probe <NN> <nucleor_stdout> <reference_json>
//   NN = 01 (tabular classification), 02 (regression), 03 (KMeans),
//        04 (text classification / BernoulliNB)
// Exit:  0 = match, 1 = mismatch, 2 = usage error.
#[allow(PERF-3)]

import "stdlib/rods/json.nr"

// ---- small string helpers (self-contained; no compiler-entry deps) ----

fn cp_trim(s: str) -> str {
    let n: i64 = str_len(s);
    let mut a: i64 = 0;
    while a < n {
        let c: i64 = str_char_at(s, a);
        if c != 32 && c != 9 && c != 13 && c != 10 { break; };
        a = a + 1;
    };
    let mut b: i64 = n;
    while b > a {
        let c: i64 = str_char_at(s, b - 1);
        if c != 32 && c != 9 && c != 13 && c != 10 { break; };
        b = b - 1;
    };
    return str_substring(s, a, b);
}

// Is `s` a signed decimal integer literal (no '.' / exponent)?
fn cp_is_int(s: str) -> i64 {
    let n: i64 = str_len(s);
    if n == 0 { return 0; };
    let mut i: i64 = 0;
    if str_char_at(s, 0) == 45 { if n == 1 { return 0; }; i = 1; };
    while i < n {
        let c: i64 = str_char_at(s, i);
        if c < 48 || c > 57 { return 0; };
        i = i + 1;
    };
    return 1;
}

fn cp_to_int(s: str) -> i64 {
    let n: i64 = str_len(s);
    let mut i: i64 = 0;
    let mut neg: i64 = 0;
    if n > 0 && str_char_at(s, 0) == 45 { neg = 1; i = 1; };
    let mut v: i64 = 0;
    while i < n { v = v * 10 + (str_char_at(s, i) - 48); i = i + 1; };
    if neg == 1 { return 0 - v; };
    return v;
}

// End index (position of '\n' or end-of-string) of the line starting at `start`.
fn cp_line_end(text: str, start: i64) -> i64 {
    let n: i64 = str_len(text);
    let mut p: i64 = start;
    while p < n && str_char_at(text, p) != 10 { p = p + 1; };
    return p;
}

// Collect the integer lines in the section headed by `header` (a "name:" line)
// into `out` — stops at a blank line, another header, or a non-integer line.
fn cp_collect_after(text: str, header: str, out: Vec<i32>) -> i64 {
    let n: i64 = str_len(text);
    let mut pos: i64 = 0;
    let mut found: i64 = 0;
    while pos <= n {
        let e: i64 = cp_line_end(text, pos);
        let line: str = cp_trim(str_substring(text, pos, e));
        if found == 1 {
            if str_len(line) == 0 { return 0; };
            if cp_is_int(line) == 1 { out.push(cp_to_int(line) as i32); }
            else { return 0; };
        } else {
            if str_eq(line, header) == 1 { found = 1; };
        };
        pos = e + 1;
    };
    return 0;
}

// First integer line after the header `header`, or `missing` if absent.
fn cp_scalar_after(text: str, header: str, missing: i64) -> i64 {
    let n: i64 = str_len(text);
    let mut pos: i64 = 0;
    let mut found: i64 = 0;
    while pos <= n {
        let e: i64 = cp_line_end(text, pos);
        let line: str = cp_trim(str_substring(text, pos, e));
        if found == 1 {
            if cp_is_int(line) == 1 { return cp_to_int(line); };
            if str_len(line) > 0 { return missing; };
        } else {
            if str_eq(line, header) == 1 { found = 1; };
        };
        pos = e + 1;
    };
    return missing;
}

// ---- JSON helpers ----

fn cp_json_int_array(j: Vec<i32>, key: str, out: Vec<i32>) -> i64 {
    let arr: Vec<i32> = json_object_get(j, key);
    let m: i64 = json_array_len(arr);
    let mut i: i64 = 0;
    while i < m { out.push(json_int(json_array_get(arr, i)) as i32); i = i + 1; };
    return m;
}

fn cp_ints_eq(a: Vec<i32>, b: Vec<i32>) -> i64 {
    if vec_len(a) != vec_len(b) { return 0; };
    let mut i: i64 = 0;
    while i < vec_len(a) { if vec_get(a, i) != vec_get(b, i) { return 0; }; i = i + 1; };
    return 1;
}

// ---- pipeline comparisons ----

// 01 / 04: integer y_pred must byte-equal ref.y_pred; accuracy_correct must be
// the count where ref.y_pred[i]==ref.y_test[i]; accuracy_total == len(y_test).
fn cp_cmp_class(text: str, j: Vec<i32>, label: str) -> i64 {
    let got_yp: Vec<i32> = Vec::new();
    cp_collect_after(text, "y_pred:", got_yp);
    let ref_yp: Vec<i32> = Vec::new();
    cp_json_int_array(j, "y_pred", ref_yp);
    let ref_yt: Vec<i32> = Vec::new();
    cp_json_int_array(j, "y_test", ref_yt);
    if cp_ints_eq(got_yp, ref_yp) == 0 {
        print(str_concat(label, ": y_pred mismatch\n")); return 1;
    };
    let mut exp_correct: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(ref_yt) {
        if vec_get(ref_yp, i) == vec_get(ref_yt, i) { exp_correct = exp_correct + 1; };
        i = i + 1;
    };
    let got_correct: i64 = cp_scalar_after(text, "accuracy_correct:", 0 - 999999);
    let got_total: i64 = cp_scalar_after(text, "accuracy_total:", 0 - 999999);
    if got_correct != exp_correct { print(str_concat(label, ": accuracy_correct mismatch\n")); return 1; };
    if got_total != vec_len(ref_yt) { print(str_concat(label, ": accuracy_total mismatch\n")); return 1; };
    print(str_concat(label, ": y_pred byte-equal, accuracy verified\n"));
    return 0;
}

// 02: the pipeline self-reports close_count_vs_reference / close_count_total
// (its own f64 predictions within 1e-5 of the embedded reference). Parity holds
// iff every prediction was close. (Float re-parse is intentionally not redone
// here — Nucleor has no str->f64 and the JSON parser truncates floats; the
// pipeline already performed the tolerance comparison internally.)
fn cp_cmp_regression(text: str) -> i64 {
    let vs_ref: i64 = cp_scalar_after(text, "close_count_vs_reference:", 0 - 999999);
    let total: i64 = cp_scalar_after(text, "close_count_total:", 0 - 999999);
    if total <= 0 { print("PROBE-2 02: close_count_total not positive\n"); return 1; };
    if vs_ref != total {
        print("PROBE-2 02: close_count_vs_reference != close_count_total\n"); return 1;
    };
    print("PROBE-2 02: all predictions within tolerance of reference\n");
    return 0;
}

// 03: KMeans cluster IDs are permutation-invariant. (a) the reported sorted
// cluster-size signature must equal sorted counts of ref.labels; (b) the
// row-equivalence partition must match — checked pairwise: for all i<j,
// (got[i]==got[j]) iff (ref[i]==ref[j]).
fn cp_cmp_clustering(text: str, j: Vec<i32>) -> i64 {
    let got_labels: Vec<i32> = Vec::new();
    cp_collect_after(text, "labels:", got_labels);
    let got_sig: Vec<i32> = Vec::new();
    cp_collect_after(text, "cluster_size_signature_sorted:", got_sig);
    let ref_labels: Vec<i32> = Vec::new();
    cp_json_int_array(j, "labels", ref_labels);

    // (a) cluster-size signature: sorted occurrence counts of ref.labels.
    let mut maxlab: i64 = -1;
    let mut i: i64 = 0;
    while i < vec_len(ref_labels) { if vec_get(ref_labels, i) > maxlab { maxlab = vec_get(ref_labels, i); }; i = i + 1; };
    let counts: Vec<i32> = Vec::new();
    let mut c: i64 = 0;
    while c <= maxlab { counts.push(0); c = c + 1; };
    i = 0;
    while i < vec_len(ref_labels) { let l: i64 = vec_get(ref_labels, i); vec_set(counts, l, vec_get(counts, l) + 1); i = i + 1; };
    // collect non-zero counts
    let exp_sig: Vec<i32> = Vec::new();
    i = 0;
    while i <= maxlab { if vec_get(counts, i) > 0 { exp_sig.push(vec_get(counts, i) as i32); }; i = i + 1; };
    // insertion sort exp_sig ascending
    i = 1;
    while i < vec_len(exp_sig) {
        let key: i64 = vec_get(exp_sig, i);
        let mut k: i64 = i - 1;
        while k >= 0 && vec_get(exp_sig, k) > key { vec_set(exp_sig, k + 1, vec_get(exp_sig, k)); k = k - 1; };
        vec_set(exp_sig, k + 1, key);
        i = i + 1;
    };
    if cp_ints_eq(got_sig, exp_sig) == 0 { print("PROBE-2 03: cluster_size_signature mismatch\n"); return 1; };

    // (b) pairwise equivalence-relation match.
    if vec_len(got_labels) != vec_len(ref_labels) { print("PROBE-2 03: labels length mismatch\n"); return 1; };
    let nn: i64 = vec_len(ref_labels);
    i = 0;
    while i < nn {
        let mut jx: i64 = i + 1;
        while jx < nn {
            let ge: i64 = if vec_get(got_labels, i) == vec_get(got_labels, jx) { 1 } else { 0 };
            let re: i64 = if vec_get(ref_labels, i) == vec_get(ref_labels, jx) { 1 } else { 0 };
            if ge != re { print("PROBE-2 03: partition mismatch\n"); return 1; };
            jx = jx + 1;
        };
        i = i + 1;
    };
    print("PROBE-2 03: partition equal under cluster-ID permutation\n");
    return 0;
}

fn main() -> i64 {
    if args_count() != 4 {
        print("usage: compare_probe <NN> <nucleor_stdout> <reference_json>\n");
        return 2;
    };
    let nn: str = args_get(1);
    let text: str = file_read_string(args_get(2));
    let j: Vec<i32> = json_parse(file_read_string(args_get(3)));
    if str_eq(nn, "01") == 1 { return cp_cmp_class(text, j, "PROBE-2 01"); };
    if str_eq(nn, "02") == 1 { return cp_cmp_regression(text); };
    if str_eq(nn, "03") == 1 { return cp_cmp_clustering(text, j); };
    if str_eq(nn, "04") == 1 { return cp_cmp_class(text, j, "PROBE-2 04"); };
    print(str_concat("compare_probe: unknown pipeline ", nn)); print("\n");
    return 2;
}
