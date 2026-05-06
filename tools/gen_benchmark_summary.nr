// gen_benchmark_summary.nr — Native Nucleor port of
// tools/gen_benchmark_summary.py.
//
// Reads tools/verify_timings.csv (gitignored, per-machine timing data
// emitted by verify.sh) and emits docs/BENCHMARK.md — a per-release
// verify-gate performance + parity dashboard.
//
// Per-row CSV columns (matches verify.sh shape):
//   run_iso, idx, secs, status, step_name
//
// RFC-0063 Phase 5.x / Track C C4: third port of a Python dev-time
// generator to native Nucleor. Removes another dev-time Python dep.
//
// Note: this generator is NOT gated by check_compiler_drift.sh
// (input CSV is gitignored, so the canonical output isn't reproducible
// from a clean checkout). Run after a verify pass to refresh
// docs/BENCHMARK.md before commit.

// ---------- helpers ----------

// Format a non-negative f64 with 2 decimal places. Handles negative via
// caller-side sign emission.
fn format_f64_2dp(x: f64) -> str {
    let neg: i64 = if x < 0.0 { 1 } else { 0 };
    let abs_x: f64 = if neg == 1 { 0.0 - x } else { x };
    // Round-half-up at 2 dp: scale to centi, add 0.5, truncate.
    let scaled: f64 = abs_x * 100.0 + 0.5;
    let scaled_int: i64 = scaled as i64;
    let int_part: i64 = scaled_int / 100;
    let frac_part: i64 = scaled_int - (int_part * 100);
    let frac_str: str = if frac_part < 10 {
        str_concat("0", int_to_str(frac_part))
    } else {
        int_to_str(frac_part)
    };
    let body: str = str_concat(int_to_str(int_part), str_concat(".", frac_str));
    if neg == 1 { return str_concat("-", body); };
    return body;
}

// Format f64 with 1 decimal place. Same approach.
fn format_f64_1dp(x: f64) -> str {
    let neg: i64 = if x < 0.0 { 1 } else { 0 };
    let abs_x: f64 = if neg == 1 { 0.0 - x } else { x };
    let scaled: f64 = abs_x * 10.0 + 0.5;
    let scaled_int: i64 = scaled as i64;
    let int_part: i64 = scaled_int / 10;
    let frac_part: i64 = scaled_int - (int_part * 10);
    let body: str = str_concat(int_to_str(int_part), str_concat(".", int_to_str(frac_part)));
    if neg == 1 { return str_concat("-", body); };
    return body;
}

// Parse f64 from a string. Simple — splits on '.', does i64 of each side.
// Returns 0.0 on parse failure.
fn parse_f64_simple(s: str) -> f64 {
    let n: i64 = str_len(s);
    if n == 0 { return 0.0; };
    let dot: i64 = str_index_of(s, ".");
    if dot < 0 {
        // No decimal — just integer
        return (str_to_i64(s)) as f64;
    };
    let int_str: str = str_substring(s, 0, dot);
    let frac_str: str = str_substring(s, dot + 1, n);
    let int_part: i64 = str_to_i64(int_str);
    let frac_part: i64 = str_to_i64(frac_str);
    let frac_len: i64 = str_len(frac_str);
    let mut divisor: f64 = 1.0;
    let mut k: i64 = 0;
    while k < frac_len { divisor = divisor * 10.0; k = k + 1; };
    let neg: i64 = if str_starts_with(int_str, "-") == 1 { 1 } else { 0 };
    let abs_int: f64 = if neg == 1 { (0 - int_part) as f64 } else { int_part as f64 };
    let abs_frac: f64 = (frac_part as f64) / divisor;
    let abs_total: f64 = abs_int + abs_frac;
    if neg == 1 { return 0.0 - abs_total; };
    return abs_total;
}

// Strip surrounding double quotes if present.
fn strip_quotes(s: str) -> str {
    let n: i64 = str_len(s);
    if n >= 2 && str_char_at(s, 0) == 34 && str_char_at(s, n - 1) == 34 {
        return str_substring(s, 1, n - 1);
    };
    return s;
}

// Split a CSV line into Vec<str> with quote-aware comma handling.
// verify_timings.csv has step names like
// "self-host memory budget (<= 770 MB; tight cap, see ...)" where the
// comma inside quotes must NOT split the field.
fn csv_split_line(line: str) -> Vec<str> {
    let n: i64 = str_len(line);
    let out: Vec<str> = vec_new();
    let mut start: i64 = 0;
    let mut in_quote: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(line, i);
        if c == 34 {                          // "
            in_quote = 1 - in_quote;
        } else if c == 44 && in_quote == 0 {  // ,
            let field: str = str_substring(line, start, i);
            vec_push(out, strip_quotes(field));
            start = i + 1;
        };
        i = i + 1;
    };
    let last: str = str_substring(line, start, n);
    vec_push(out, strip_quotes(last));
    return out;
}

// Insertion sort Vec<str> ascending (lexicographic byte-wise).
fn sort_strs_asc(v: Vec<str>) -> i64 {
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

// ---------- main ----------

fn main() -> i64 {
    let csv_path: str = "tools/verify_timings.csv";
    let out_path: str = "docs/BENCHMARK.md";

    let csv_text: str = file_read_string(csv_path);
    if str_len(csv_text) == 0 {
        print(str_concat("error: ", str_concat(csv_path, " not found")));
        print("hint: run `bash tools/verify.sh` to populate it");
        return 1;
    };

    // Parse CSV into per-run aggregates. We use parallel arrays keyed
    // by `run_iso` via a hashmap to avoid Vec<Vec<...>> nesting.
    //   run_iso (str)  -> idx into per-run stats arrays
    //   pass_counts[idx], fail_counts[idx], skip_counts[idx]
    //   total_secs_x1m[idx]   — accumulate ×100 to keep i64 precision
    //   slowest_secs_x1m[idx] — track slowest step's secs ×100
    //   slowest_names[idx]     — name of slowest PASS step
    //   step_counts[idx]       — count of timed steps (PASS+FAIL only)
    //   step_secs_x1m_packed[idx] / step_names_packed[idx]
    //     — packed CSV: secs ×100 stored as i64 sequence; names as
    //       newline-separated str. Used to compute top-5 for the
    //       latest run.

    let runs_idx: i64 = hashmap_new();
    let run_keys: Vec<str> = vec_new();
    let pass_counts: Vec<i32> = vec_new();
    let fail_counts: Vec<i32> = vec_new();
    let skip_counts: Vec<i32> = vec_new();
    let total_secs_x1m: Vec<i64> = vec_new();
    let slowest_secs_x1m: Vec<i64> = vec_new();
    let slowest_names: Vec<str> = vec_new();
    let step_counts: Vec<i32> = vec_new();
    // Per-run packed step data: i64 array of secs_x1m, str of newline-
    // separated names. Same idx maps to both.
    let step_secs_packed: Vec<str> = vec_new();   // ascii i64 numbers, comma-separated
    let step_names_packed: Vec<str> = vec_new();  // newline-separated names

    let lines: Vec<str> = str_lines(csv_text);
    let n_lines: i64 = vec_len(lines);
    let mut li: i64 = 0;
    let mut header_seen: i64 = 0;
    while li < n_lines {
        let line: str = vec_get(lines, li);
        if str_len(str_trim(line)) == 0 { li = li + 1; continue; };
        if header_seen == 0 {
            header_seen = 1;
            li = li + 1;
            continue;
        };
        let fields: Vec<str> = csv_split_line(line);
        if vec_len(fields) < 5 { li = li + 1; continue; };
        let run_iso: str = vec_get(fields, 0);
        let secs_str: str = vec_get(fields, 2);
        let status: str = vec_get(fields, 3);
        let name: str = vec_get(fields, 4);
        let secs_f: f64 = parse_f64_simple(secs_str);
        let secs_x1m: i64 = (secs_f * 1000000.0 + 0.5) as i64;

        let mut idx: i64 = 0;
        if hashmap_contains(runs_idx, run_iso) == 0 {
            idx = vec_len(run_keys);
            hashmap_insert(runs_idx, run_iso, idx);
            vec_push(run_keys, run_iso);
            vec_push(pass_counts, 0);
            vec_push(fail_counts, 0);
            vec_push(skip_counts, 0);
            vec_push(total_secs_x1m, 0);
            vec_push(slowest_secs_x1m, 0);
            vec_push(slowest_names, "");
            vec_push(step_counts, 0);
            vec_push(step_secs_packed, "");
            vec_push(step_names_packed, "");
        } else {
            idx = hashmap_get(runs_idx, run_iso);
        };

        if str_eq(status, "PASS") == 1 {
            vec_set(pass_counts, idx, (vec_get(pass_counts, idx) as i64 + 1) as i32);
            vec_set(total_secs_x1m, idx, vec_get(total_secs_x1m, idx) + secs_x1m);
            vec_set(step_counts, idx, (vec_get(step_counts, idx) as i64 + 1) as i32);
            // Append step
            let cur_secs: str = vec_get(step_secs_packed, idx);
            let cur_names: str = vec_get(step_names_packed, idx);
            vec_set(step_secs_packed, idx,
                if str_len(cur_secs) == 0 { int_to_str(secs_x1m) }
                else { str_concat(cur_secs, str_concat(",", int_to_str(secs_x1m))) });
            vec_set(step_names_packed, idx,
                if str_len(cur_names) == 0 { name }
                else { str_concat(cur_names, str_concat("\n", name)) });
            // Update slowest
            if secs_x1m > vec_get(slowest_secs_x1m, idx) {
                vec_set(slowest_secs_x1m, idx, secs_x1m);
                vec_set(slowest_names, idx, name);
            };
        } else if str_eq(status, "FAIL") == 1 {
            vec_set(fail_counts, idx, (vec_get(fail_counts, idx) as i64 + 1) as i32);
            vec_set(total_secs_x1m, idx, vec_get(total_secs_x1m, idx) + secs_x1m);
            vec_set(step_counts, idx, (vec_get(step_counts, idx) as i64 + 1) as i32);
            let cur_secs2: str = vec_get(step_secs_packed, idx);
            let cur_names2: str = vec_get(step_names_packed, idx);
            vec_set(step_secs_packed, idx,
                if str_len(cur_secs2) == 0 { int_to_str(secs_x1m) }
                else { str_concat(cur_secs2, str_concat(",", int_to_str(secs_x1m))) });
            vec_set(step_names_packed, idx,
                if str_len(cur_names2) == 0 { name }
                else { str_concat(cur_names2, str_concat("\n", name)) });
        } else if str_eq(status, "SKIP") == 1 {
            vec_set(skip_counts, idx, (vec_get(skip_counts, idx) as i64 + 1) as i32);
        };
        li = li + 1;
    };

    let n_runs: i64 = vec_len(run_keys);
    if n_runs == 0 {
        print(str_concat("error: no runs found in ", csv_path));
        return 1;
    };

    // Sort run keys ascending (chronological)
    sort_strs_asc(run_keys);
    // Build a sorted_idx map: position in sorted -> orig idx via the hashmap.

    let latest: str = vec_get(run_keys, n_runs - 1);
    let prev_exists: i64 = if n_runs >= 2 { 1 } else { 0 };
    let prev: str = if prev_exists == 1 { vec_get(run_keys, n_runs - 2) } else { "" };
    let latest_idx: i64 = hashmap_get(runs_idx, latest);

    let l_pass: i64 = vec_get(pass_counts, latest_idx) as i64;
    let l_fail: i64 = vec_get(fail_counts, latest_idx) as i64;
    let l_skip: i64 = vec_get(skip_counts, latest_idx) as i64;
    let l_total_x1m: i64 = vec_get(total_secs_x1m, latest_idx);
    let l_total_f: f64 = (l_total_x1m as f64) / 1000000.0;
    let l_step_count: i64 = vec_get(step_counts, latest_idx) as i64;
    let l_slowest_name: str = vec_get(slowest_names, latest_idx);
    let l_slowest_x1m: i64 = vec_get(slowest_secs_x1m, latest_idx);
    let l_slowest_f: f64 = (l_slowest_x1m as f64) / 1000000.0;

    let mut out: str = "";
    out = str_concat(out, "# Verify-Gate Benchmark Summary\n");
    out = str_concat(out, "\n");
    out = str_concat(out, str_concat("**Source:** `", str_concat(csv_path, str_concat("` (", str_concat(int_to_str(n_runs), " runs recorded)")))));
    out = str_concat(out, "\n\n");
    out = str_concat(out, "Per-release verify-gate performance and parity. Generated by\n");
    out = str_concat(out, "`tools/gen_benchmark_summary.nr` from local timing CSV. The CSV\n");
    out = str_concat(out, "itself is gitignored (per-machine output); this distillation\n");
    out = str_concat(out, "is the publishable per-release record.\n");
    out = str_concat(out, "\n");
    out = str_concat(out, "## Latest run\n\n");
    out = str_concat(out, str_concat("- **Run:** `", str_concat(latest, "`\n")));
    out = str_concat(out, str_concat("- **Result:** ", str_concat(int_to_str(l_pass), str_concat(" PASS · ", str_concat(int_to_str(l_fail), str_concat(" FAIL · ", str_concat(int_to_str(l_skip), " SKIP\n")))))));
    out = str_concat(out, str_concat("- **Total wall time:** ", str_concat(format_f64_2dp(l_total_f), str_concat("s across ", str_concat(int_to_str(l_step_count), " timed steps\n")))));
    out = str_concat(out, str_concat("- **Slowest step:** `", str_concat(l_slowest_name, str_concat("` (", str_concat(format_f64_2dp(l_slowest_f), "s)\n")))));
    if prev_exists == 1 {
        let prev_idx: i64 = hashmap_get(runs_idx, prev);
        let p_total_x1m: i64 = vec_get(total_secs_x1m, prev_idx);
        let p_total_f: f64 = (p_total_x1m as f64) / 1000000.0;
        let delta_f: f64 = l_total_f - p_total_f;
        let pct_f: f64 = if p_total_f > 0.0 { 100.0 * delta_f / p_total_f } else { 0.0 };
        let sign: str = if delta_f >= 0.0 { "+" } else { "" };
        out = str_concat(out, str_concat("- **vs previous run** (`", str_concat(prev, str_concat("`): ", str_concat(sign, str_concat(format_f64_2dp(delta_f), str_concat("s (", str_concat(sign, str_concat(format_f64_1dp(pct_f), "%)\n")))))))));
    };
    out = str_concat(out, "\n");

    // Top 5 slowest in latest run.
    out = str_concat(out, "## Top 5 slowest steps in latest run\n\n");
    out = str_concat(out, "| Time | Step |\n");
    out = str_concat(out, "|---|---|\n");
    let secs_csv: str = vec_get(step_secs_packed, latest_idx);
    let names_nl: str = vec_get(step_names_packed, latest_idx);
    if str_len(secs_csv) > 0 {
        let secs_parts: Vec<str> = str_split(secs_csv, ",");
        let names_parts: Vec<str> = str_split(names_nl, "\n");
        let n_steps: i64 = vec_len(secs_parts);
        // Pack secs+idx into i64 for sort
        let packed: Vec<i64> = vec_new();
        let mut s: i64 = 0;
        while s < n_steps {
            let secs_val: i64 = str_to_i64(vec_get(secs_parts, s));
            // packed = secs_x1m * 1_000_000 + idx (n_steps fits well under 1M)
            vec_push(packed, secs_val * 1000000 + s);
            s = s + 1;
        };
        vec_sort_i64(packed);
        let mut top: i64 = vec_len(packed) - 1;
        let mut shown: i64 = 0;
        while top >= 0 && shown < 5 {
            let pk: i64 = vec_get(packed, top);
            let orig: i64 = pk - (pk / 1000000) * 1000000;
            let secs_x1m_val: i64 = pk / 1000000;
            let secs_f_val: f64 = (secs_x1m_val as f64) / 1000000.0;
            let nm: str = vec_get(names_parts, orig);
            out = str_concat(out, str_concat("| ", str_concat(format_f64_2dp(secs_f_val), str_concat("s | `", str_concat(nm, "` |\n")))));
            top = top - 1;
            shown = shown + 1;
        };
    };
    out = str_concat(out, "\n");

    // All recorded runs chronological.
    out = str_concat(out, "## All recorded runs (chronological)\n\n");
    out = str_concat(out, "| Run (UTC) | Pass | Fail | Steps | Total | Slowest |\n");
    out = str_concat(out, "|---|---|---|---|---|---|\n");
    let mut r: i64 = 0;
    while r < n_runs {
        let ts: str = vec_get(run_keys, r);
        let ridx: i64 = hashmap_get(runs_idx, ts);
        let rp: i64 = vec_get(pass_counts, ridx) as i64;
        let rf: i64 = vec_get(fail_counts, ridx) as i64;
        let rs: i64 = vec_get(step_counts, ridx) as i64;
        let rt_f: f64 = (vec_get(total_secs_x1m, ridx) as f64) / 1000000.0;
        let mut rsn: str = vec_get(slowest_names, ridx);
        if str_len(rsn) > 40 {
            rsn = str_concat(str_substring(rsn, 0, 37), "...");
        };
        out = str_concat(out, str_concat("| `", str_concat(ts, str_concat("` | ", str_concat(int_to_str(rp), str_concat(" | ", str_concat(int_to_str(rf), str_concat(" | ", str_concat(int_to_str(rs), str_concat(" | ", str_concat(format_f64_2dp(rt_f), str_concat("s | `", str_concat(rsn, "` |\n")))))))))))));
        r = r + 1;
    };
    out = str_concat(out, "\n");
    out = str_concat(out, "## Notes\n\n");
    out = str_concat(out, "- **Parity:** PASS / FAIL counts. v0.4.x baseline is 467/467 at v0.4.41.\n");
    out = str_concat(out, "- **Performance:** total wall time. v0.4.28 baseline was ~314s; v0.4.39\n");
    out = str_concat(out, "  + v0.4.30 optimizations brought the floor to ~295s.\n");
    out = str_concat(out, "- **Claim separation:** this dashboard does NOT claim absolute\n");
    out = str_concat(out, "  performance comparisons against other languages — those require\n");
    out = str_concat(out, "  controlled hardware + the public benchmark program (RFC-TBD).\n");
    out = str_concat(out, "  This is the verify-gate cycle time on the local developer box.\n");

    file_write_string(out_path, out);

    print(str_concat("Wrote ", out_path));
    print(str_concat(str_concat("  Runs: ", int_to_str(n_runs)), str_concat(" · Latest: ", str_concat(latest, str_concat(" · ", str_concat(format_f64_2dp(l_total_f), str_concat("s / ", str_concat(int_to_str(l_pass), str_concat(" pass / ", str_concat(int_to_str(l_fail), " fail")))))))));
    return 0;
}
