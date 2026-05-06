// gen_releases_index.nr — Native Nucleor port of tools/gen_releases_index.py.
//
// Reads CHANGELOG.md, parses release headings (`## [X.Y.Z] — YYYY-MM-DD`),
// extracts each release's first **bold** line (or fallback first text line)
// as a one-line summary, sorts versions descending, groups by major.minor,
// emits RELEASES.md.
//
// RFC-0063 Phase 1.4 / Track C step C2: this is the first port of a
// dev-time Python generator to native Nucleor. Removes a Python
// dependency from `tools/check_compiler_drift.sh`.
//
// Usage: nuc run tools/gen_releases_index.nr [output_path]
//   defaults output_path to "RELEASES.md".
//
// Output is byte-equivalent to the Python version where possible. The
// Python version uses Python regex semantics; this port uses
// line-by-line scanning so the equivalence is structural (same headings
// found, same summaries extracted) rather than literal regex match.

// ---------- helpers ----------

// Pack X.Y.Z into a single i64 sort key:
//   major*1_000_000 + minor*1_000 + patch
// Max observed v0.8.322 fits comfortably under 1000 per part.
fn parse_version_key(v: str) -> i64 {
    let parts: Vec<str> = str_split(v, ".");
    let n: i64 = vec_len(parts);
    let mut major: i64 = 0;
    let mut minor: i64 = 0;
    let mut patch: i64 = 0;
    if n >= 1 { major = str_to_i64(vec_get(parts, 0)); };
    if n >= 2 { minor = str_to_i64(vec_get(parts, 1)); };
    if n >= 3 { patch = str_to_i64(vec_get(parts, 2)); };
    return major * 1000000 + minor * 1000 + patch;
}

fn major_minor_of(v: str) -> str {
    let parts: Vec<str> = str_split(v, ".");
    let n: i64 = vec_len(parts);
    if n >= 2 {
        return str_concat(vec_get(parts, 0), str_concat(".", vec_get(parts, 1)));
    };
    return v;
}

// Find the YYYY-MM-DD date in a line. Scans for a 10-char run matching
// digit{4}-digit{2}-digit{2}. Returns the run, or "" if not found.
fn extract_date(line: str) -> str {
    let n: i64 = str_len(line);
    let mut i: i64 = 0;
    while i + 10 <= n {
        let c0: i64 = str_char_at(line, i);
        if c0 >= 48 && c0 <= 57 {
            let c1: i64 = str_char_at(line, i + 1);
            let c2: i64 = str_char_at(line, i + 2);
            let c3: i64 = str_char_at(line, i + 3);
            let c4: i64 = str_char_at(line, i + 4);
            let c5: i64 = str_char_at(line, i + 5);
            let c6: i64 = str_char_at(line, i + 6);
            let c7: i64 = str_char_at(line, i + 7);
            let c8: i64 = str_char_at(line, i + 8);
            let c9: i64 = str_char_at(line, i + 9);
            if c1 >= 48 && c1 <= 57 && c2 >= 48 && c2 <= 57 && c3 >= 48 && c3 <= 57
                && c4 == 45
                && c5 >= 48 && c5 <= 57 && c6 >= 48 && c6 <= 57
                && c7 == 45
                && c8 >= 48 && c8 <= 57 && c9 >= 48 && c9 <= 57 {
                return str_substring(line, i, i + 10);
            };
        };
        i = i + 1;
    };
    return "";
}

// Find first **...** pair in body. Returns text between, "" if none.
fn extract_first_bold(body: str) -> str {
    let n: i64 = str_len(body);
    if n < 4 { return ""; };
    let mut i: i64 = 0;
    while i + 1 < n {
        if str_char_at(body, i) == 42 && str_char_at(body, i + 1) == 42 {
            // Opening ** found at i. Look for closing ** after it.
            let mut j: i64 = i + 2;
            while j + 1 < n {
                if str_char_at(body, j) == 42 && str_char_at(body, j + 1) == 42 {
                    return str_substring(body, i + 2, j);
                };
                j = j + 1;
            };
            return ""; // unterminated **
        };
        i = i + 1;
    };
    return "";
}

// Fallback summary: first line that isn't blank, bullet (- or *),
// heading (#), or table row (|).
fn extract_first_text_line(body: str) -> str {
    let lines: Vec<str> = str_lines(body);
    let n: i64 = vec_len(lines);
    let mut i: i64 = 0;
    while i < n {
        let raw: str = vec_get(lines, i);
        let line: str = str_trim(raw);
        if str_len(line) > 0 {
            let c: i64 = str_char_at(line, 0);
            // 45=- 42=* 35=# 124=|
            // For -/*, only skip if followed by a space (real bullet)
            if c == 35 || c == 124 {
                // skip
            } else if (c == 45 || c == 42) && str_len(line) >= 2 && str_char_at(line, 1) == 32 {
                // skip bullet
            } else {
                return line;
            };
        };
        i = i + 1;
    };
    return "";
}

// Trim trailing period if present.
fn rstrip_period(s: str) -> str {
    let n: i64 = str_len(s);
    if n > 0 && str_char_at(s, n - 1) == 46 {
        return str_substring(s, 0, n - 1);
    };
    return s;
}

// Replace `|` with `\|` for markdown table escaping.
fn md_pipe_escape(s: str) -> str {
    let n: i64 = str_len(s);
    let mut out: str = "";
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(s, i);
        if c == 124 {
            out = str_concat(out, "\\|");
        } else {
            out = str_concat(out, str_substring(s, i, i + 1));
        };
        i = i + 1;
    };
    return out;
}

// ---------- main ----------

fn main() -> i64 {
    let in_path: str = "CHANGELOG.md";
    let out_path: str = "RELEASES.md";

    let text: str = file_read_string(in_path);
    if str_len(text) == 0 {
        print("ERROR: gen_releases_index: cannot read CHANGELOG.md");
        return 1;
    };

    let lines: Vec<str> = str_lines(text);
    let n_lines: i64 = vec_len(lines);

    // Pass 1: collect parallel arrays (versions, dates, summaries) keyed
    // by insertion index. Parallel-array shape avoids needing Vec<Tuple<...>>.
    let version_keys: Vec<i64> = vec_new();
    let version_strs: Vec<str> = vec_new();
    let dates: Vec<str> = vec_new();
    let summaries: Vec<str> = vec_new();

    let mut i: i64 = 0;
    while i < n_lines {
        let line: str = vec_get(lines, i);
        if str_starts_with(line, "## [") == 1 {
            let close_idx: i64 = str_index_of(line, "]");
            if close_idx > 4 {
                let version: str = str_substring(line, 4, close_idx);
                let date: str = extract_date(line);

                // Accumulate body lines until next "## [" heading.
                let mut body_acc: str = "";
                let mut j: i64 = i + 1;
                while j < n_lines {
                    let lj: str = vec_get(lines, j);
                    if str_starts_with(lj, "## [") == 1 { break; };
                    body_acc = str_concat(body_acc, lj);
                    body_acc = str_concat(body_acc, "\n");
                    j = j + 1;
                };

                let bold: str = extract_first_bold(body_acc);
                let mut summary: str = "(no summary parsed)";
                if str_len(bold) > 0 {
                    summary = rstrip_period(str_trim(bold));
                } else {
                    let plain: str = extract_first_text_line(body_acc);
                    if str_len(plain) > 0 {
                        summary = rstrip_period(plain);
                    };
                };

                vec_push(version_keys, parse_version_key(version));
                vec_push(version_strs, version);
                vec_push(dates, date);
                vec_push(summaries, summary);
            };
        };
        i = i + 1;
    };

    let total: i64 = vec_len(version_keys);
    if total == 0 {
        print("ERROR: gen_releases_index: no releases parsed from CHANGELOG.md");
        return 1;
    };

    // Sort by version DESC. Pack (version_key, original_idx) into a
    // single i64 for vec_sort_i64. Bound: version_key < 1B, total < 100K,
    // so version_key * 1_000_000 + idx fits in i64 easily.
    let packed: Vec<i64> = vec_new();
    let mut k: i64 = 0;
    while k < total {
        let vkey: i64 = vec_get(version_keys, k);
        vec_push(packed, vkey * 1000000 + k);
        k = k + 1;
    };
    vec_sort_i64(packed);

    // Build major.minor groups in iteration order (descending versions).
    // Use parallel arrays groups_keys (Vec<str>) + groups_lines (Vec<Vec<str>>)?
    // Simpler: emit on the fly, tracking current group key.
    let mut out: str = "";
    out = str_concat(out, "# Releases\n");
    out = str_concat(out, "\n");
    out = str_concat(out, "Tag-only navigable index of every Nucleor release. Generated by `tools/gen_releases_index.nr` from `CHANGELOG.md`.\n");
    out = str_concat(out, "\n");
    out = str_concat(out, "For full per-release notes (changes, gate status, fixed point), see [`CHANGELOG.md`](CHANGELOG.md). For RFC-by-RFC status see [`docs/rfcs/README.md`](docs/rfcs/README.md). For the v0.2 shipped/deferred rollup see [`docs/status/v0.2-shipped-and-deferred.md`](docs/status/v0.2-shipped-and-deferred.md).\n");
    out = str_concat(out, "\n");
    out = str_concat(out, str_concat("**Total releases:** ", str_concat(int_to_str(total), "\n")));
    out = str_concat(out, "\n");
    out = str_concat(out, "GitHub tag URLs follow the pattern `https://github.com/APEXINTELORG/Nucleor/releases/tag/vX.Y.Z`.\n");
    out = str_concat(out, "\n");

    // Walk sorted packed[] in DESCENDING order (last-to-first since
    // vec_sort_i64 sorts ascending).
    let mut current_group: str = "";
    let mut idx_p: i64 = vec_len(packed) - 1;
    while idx_p >= 0 {
        let pack: i64 = vec_get(packed, idx_p);
        let orig_idx: i64 = pack - (pack / 1000000) * 1000000;
        let v: str = vec_get(version_strs, orig_idx);
        let d: str = vec_get(dates, orig_idx);
        let s: str = vec_get(summaries, orig_idx);
        let mm: str = major_minor_of(v);

        if str_eq(mm, current_group) == 0 {
            // Close previous group and open new
            if str_len(current_group) > 0 {
                out = str_concat(out, "\n");
            };
            out = str_concat(out, str_concat("## v", str_concat(mm, ".x\n")));
            out = str_concat(out, "\n");
            out = str_concat(out, "| Version | Date | Summary |\n");
            out = str_concat(out, "|---|---|---|\n");
            current_group = mm;
        };

        let s_esc: str = md_pipe_escape(s);
        out = str_concat(out, str_concat("| **v", str_concat(v, str_concat("** | ", str_concat(d, str_concat(" | ", str_concat(s_esc, " |\n")))))));

        idx_p = idx_p - 1;
    };
    if str_len(current_group) > 0 {
        out = str_concat(out, "\n");
    };

    file_write_string(out_path, out);

    let mut no_summary: i64 = 0;
    let mut q: i64 = 0;
    while q < total {
        if str_eq(vec_get(summaries, q), "(no summary parsed)") == 1 {
            no_summary = no_summary + 1;
        };
        q = q + 1;
    };
    print(str_concat("Wrote ", out_path));
    print(str_concat("Total releases: ", int_to_str(total)));
    if no_summary > 0 {
        print(str_concat(str_concat("WARN: ", int_to_str(no_summary)), " entries had no parseable summary (fix CHANGELOG.md and re-run)"));
    };
    return 0;
}
