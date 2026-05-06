// gen_rod_manifest.nr — Native Nucleor port of tools/gen_rod_manifest.py.
//
// Walks stdlib/rods/*.nr, extracts per-rod metadata, emits
// docs/rfcs/rod_manifest.toml.
//
// Per-row fields:
//   name            - bare rod name (e.g. "math")
//   path            - relative path
//   description     - first non-blank descriptive line from leading
//                     comment block (or "" if absent)
//   function_count  - number of `fn` definitions (top-level)
//   cfile_count     - number of `#cfile` directives
//   imports         - rod names referenced via import "stdlib/rods/<name>.nr"
//   loc             - non-blank, non-pure-comment line count
//
// RFC-0063 Phase 5.1 / Track C C3: second port of a Python dev-time
// generator to native Nucleor (after gen_releases_index.nr from
// commit d298ee8). Removes another dev-time Python dep.

// ---------- helpers ----------

// True (1) if line `s` (already trimmed) starts with prefix `p`.
fn line_starts_with(s: str, p: str) -> i64 {
    return str_starts_with(s, p);
}

// Strip leading "//" + any whitespace from a comment line.
fn strip_comment_prefix(s: str) -> str {
    let trimmed: str = str_trim(s);
    if str_len(trimmed) < 2 { return ""; };
    if str_starts_with(trimmed, "//") == 0 { return trimmed; };
    let after: str = str_substring(trimmed, 2, str_len(trimmed));
    return str_trim(after);
}

// Returns 1 if `s` is purely "=" / "-" / "*" runs (decorative line).
fn is_decoration_line(s: str) -> i64 {
    let n: i64 = str_len(s);
    if n == 0 { return 1; };
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(s, i);
        if c != 61 && c != 45 && c != 42 && c != 32 { return 0; };  // = - * space
        i = i + 1;
    };
    return 1;
}

// Find the first informative description line in the leading comment block.
// Skips "rods/X" titles (extract the part after the dash if present),
// "import:", "depends:", "provides:", "see ", "#cfile" meta lines, and
// pure decoration. Returns "" if nothing found.
fn extract_description(content: str) -> str {
    let lines: Vec<str> = str_lines(content);
    let n: i64 = vec_len(lines);
    let mut i: i64 = 0;
    let mut in_header: i64 = 1;
    while i < n && in_header == 1 {
        let raw: str = vec_get(lines, i);
        let trimmed: str = str_trim(raw);
        if str_len(trimmed) == 0 {
            i = i + 1;
            continue;
        };
        if str_starts_with(trimmed, "//") == 0 {
            // First non-blank non-comment line ends the header
            in_header = 0;
            break;
        };
        let inner: str = strip_comment_prefix(trimmed);
        if str_len(inner) == 0 || is_decoration_line(inner) == 1 {
            i = i + 1;
            continue;
        };
        // "rods/<name> — <description>" form
        if str_starts_with(inner, "rods/") == 1 {
            let dash_idx: i64 = str_index_of(inner, " — ");
            if dash_idx > 0 {
                return str_trim(str_substring(inner, dash_idx + 5, str_len(inner)));
            };
            let dash2: i64 = str_index_of(inner, " - ");
            if dash2 > 0 {
                return str_trim(str_substring(inner, dash2 + 3, str_len(inner)));
            };
            let colon: i64 = str_index_of(inner, ": ");
            if colon > 0 {
                return str_trim(str_substring(inner, colon + 2, str_len(inner)));
            };
            i = i + 1;
            continue;
        };
        // Skip meta lines
        if str_starts_with(inner, "Import:") == 1
            || str_starts_with(inner, "import:") == 1
            || str_starts_with(inner, "Depends:") == 1
            || str_starts_with(inner, "depends:") == 1
            || str_starts_with(inner, "Provides:") == 1
            || str_starts_with(inner, "provides:") == 1
            || str_starts_with(inner, "See ") == 1
            || str_starts_with(inner, "see ") == 1
            || str_starts_with(inner, "#cfile") == 1 {
            i = i + 1;
            continue;
        };
        return inner;
    };
    return "";
}

// Count top-level fn definitions: lines starting with `fn ` or `pub fn ` (after trim).
fn count_fns(content: str) -> i64 {
    let lines: Vec<str> = str_lines(content);
    let n: i64 = vec_len(lines);
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let trimmed: str = str_trim(vec_get(lines, i));
        if str_starts_with(trimmed, "fn ") == 1 || str_starts_with(trimmed, "pub fn ") == 1 {
            count = count + 1;
        };
        i = i + 1;
    };
    return count;
}

// Count lines starting with `#cfile`.
fn count_cfiles(content: str) -> i64 {
    let lines: Vec<str> = str_lines(content);
    let n: i64 = vec_len(lines);
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let trimmed: str = str_trim(vec_get(lines, i));
        if str_starts_with(trimmed, "#cfile") == 1 {
            count = count + 1;
        };
        i = i + 1;
    };
    return count;
}

// Count non-blank, non-pure-comment lines.
fn count_loc(content: str) -> i64 {
    let lines: Vec<str> = str_lines(content);
    let n: i64 = vec_len(lines);
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let trimmed: str = str_trim(vec_get(lines, i));
        if str_len(trimmed) > 0 && str_starts_with(trimmed, "//") == 0 {
            count = count + 1;
        };
        i = i + 1;
    };
    return count;
}

// Find `import "stdlib/rods/<name>.nr"` directives. Populates `out` (Vec<str>)
// with sorted unique rod names.
fn collect_imports(content: str, out: Vec<str>) -> i64 {
    let lines: Vec<str> = str_lines(content);
    let n: i64 = vec_len(lines);
    let needle: str = "import \"stdlib/rods/";
    let suffix: str = ".nr\"";
    let mut i: i64 = 0;
    let seen: i64 = hashmap_new();
    while i < n {
        let line: str = vec_get(lines, i);
        let pos: i64 = str_index_of(line, needle);
        if pos >= 0 {
            let after: i64 = pos + str_len(needle);
            let suffix_pos: i64 = str_index_of(str_substring(line, after, str_len(line)), suffix);
            if suffix_pos > 0 {
                let name: str = str_substring(line, after, after + suffix_pos);
                if hashmap_contains(seen, name) == 0 {
                    hashmap_insert(seen, name, 1);
                    vec_push(out, name);
                };
            };
        };
        i = i + 1;
    };
    return vec_len(out);
}

// Sort Vec<str> in place via packed (hash:idx) sort. Lexicographic via byte-wise
// fnv1a hash works approximately but isn't stable for true alphabetical sort.
// Use a different approach: insertion sort by string compare.
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

// Return 1 if a < b (byte-wise lexicographic).
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

// Escape a description string for TOML (backslash + quote).
fn toml_escape(s: str) -> str {
    let n: i64 = str_len(s);
    let mut out: str = "";
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(s, i);
        if c == 92 { out = str_concat(out, "\\\\"); }       // \
        else if c == 34 { out = str_concat(out, "\\\""); }  // "
        else { out = str_concat(out, str_substring(s, i, i + 1)); };
        i = i + 1;
    };
    return out;
}

// ---------- main ----------

fn main() -> i64 {
    let rods_dir: str = "stdlib/rods";
    let out_path: str = "docs/rfcs/rod_manifest.toml";

    let entries: Vec<str> = fs_list_dir(rods_dir);
    let n_entries: i64 = vec_len(entries);
    if n_entries == 0 {
        print(str_concat("ERROR: gen_rod_manifest: cannot list ", rods_dir));
        return 1;
    };

    // Filter to .nr files only and sort.
    let nr_files: Vec<str> = vec_new();
    let mut i: i64 = 0;
    while i < n_entries {
        let name: str = vec_get(entries, i);
        if str_ends_with(name, ".nr") == 1 {
            vec_push(nr_files, name);
        };
        i = i + 1;
    };
    sort_strs(nr_files);
    let n_rods: i64 = vec_len(nr_files);

    // Per-rod parallel arrays.
    let names: Vec<str> = vec_new();
    let paths: Vec<str> = vec_new();
    let descriptions: Vec<str> = vec_new();
    let fn_counts: Vec<i32> = vec_new();
    let cfile_counts: Vec<i32> = vec_new();
    let locs: Vec<i32> = vec_new();
    let imports_per_rod: Vec<str> = vec_new();   // packed CSV of import names per rod

    let mut total_fn: i64 = 0;
    let mut total_loc: i64 = 0;
    let mut no_desc_count: i64 = 0;
    let no_desc_names: Vec<str> = vec_new();

    let mut k: i64 = 0;
    while k < n_rods {
        let fname: str = vec_get(nr_files, k);
        // bare name = strip ".nr"
        let bare: str = str_substring(fname, 0, str_len(fname) - 3);
        let path: str = str_concat("stdlib/rods/", fname);
        let content: str = file_read_string(path);

        let desc: str = extract_description(content);
        let fn_n: i64 = count_fns(content);
        let cfile_n: i64 = count_cfiles(content);
        let loc_n: i64 = count_loc(content);
        let imps: Vec<str> = vec_new();
        collect_imports(content, imps);
        sort_strs(imps);
        // Pack imports into a single CSV string (avoids Vec<Vec<str>>)
        let mut imp_csv: str = "";
        let mut q: i64 = 0;
        let nq: i64 = vec_len(imps);
        while q < nq {
            if q > 0 { imp_csv = str_concat(imp_csv, ","); };
            imp_csv = str_concat(imp_csv, vec_get(imps, q));
            q = q + 1;
        };

        vec_push(names, bare);
        vec_push(paths, path);
        vec_push(descriptions, desc);
        vec_push(fn_counts, fn_n as i32);
        vec_push(cfile_counts, cfile_n as i32);
        vec_push(locs, loc_n as i32);
        vec_push(imports_per_rod, imp_csv);

        total_fn = total_fn + fn_n;
        total_loc = total_loc + loc_n;
        if str_len(desc) == 0 {
            no_desc_count = no_desc_count + 1;
            vec_push(no_desc_names, bare);
        };

        k = k + 1;
    };

    // Build output.
    let mut out: str = "";
    out = str_concat(out, "# rod_manifest.toml\n");
    out = str_concat(out, "#\n");
    out = str_concat(out, "# Source-of-truth catalog for every user-facing rod in\n");
    out = str_concat(out, "# stdlib/rods/. Generated by tools/gen_rod_manifest.nr from\n");
    out = str_concat(out, "# the .nr files themselves. Do not edit by hand — re-run the\n");
    out = str_concat(out, "# generator after adding any rod.\n");
    out = str_concat(out, "#\n");
    out = str_concat(out, "# Schema: see docs/rfcs/rod_manifest_schema.md\n");
    out = str_concat(out, "# Companion: docs/rfcs/helper_manifest.toml (ABI surface)\n");
    out = str_concat(out, str_concat("# Total rods: ", str_concat(int_to_str(n_rods), "\n")));
    out = str_concat(out, str_concat("# Total fn definitions: ", str_concat(int_to_str(total_fn), "\n")));
    out = str_concat(out, str_concat("# Total LOC: ", str_concat(int_to_str(total_loc), "\n")));
    out = str_concat(out, "\n");

    if no_desc_count > 0 {
        out = str_concat(out, "# ============================================================\n");
        out = str_concat(out, "# REVIEW REQUIRED — rods with no extractable description\n");
        out = str_concat(out, "# ============================================================\n");
        out = str_concat(out, "# Add a leading '// rods/<name> — <description>' line to fix.\n");
        let mut r: i64 = 0;
        while r < vec_len(no_desc_names) {
            out = str_concat(out, str_concat("#   ", str_concat(vec_get(no_desc_names, r), "\n")));
            r = r + 1;
        };
        out = str_concat(out, "\n");
    };

    let mut p: i64 = 0;
    while p < n_rods {
        let bare: str = vec_get(names, p);
        let path: str = vec_get(paths, p);
        let desc: str = vec_get(descriptions, p);
        let fn_n: i64 = vec_get(fn_counts, p) as i64;
        let cfile_n: i64 = vec_get(cfile_counts, p) as i64;
        let loc_n: i64 = vec_get(locs, p) as i64;
        let imp_csv: str = vec_get(imports_per_rod, p);

        out = str_concat(out, "[[rod]]\n");
        out = str_concat(out, str_concat("name           = \"", str_concat(bare, "\"\n")));
        out = str_concat(out, str_concat("path           = \"", str_concat(path, "\"\n")));
        out = str_concat(out, str_concat("description    = \"", str_concat(toml_escape(desc), "\"\n")));
        out = str_concat(out, str_concat("function_count = ", str_concat(int_to_str(fn_n), "\n")));
        out = str_concat(out, str_concat("cfile_count    = ", str_concat(int_to_str(cfile_n), "\n")));
        out = str_concat(out, str_concat("loc            = ", str_concat(int_to_str(loc_n), "\n")));
        if str_len(imp_csv) == 0 {
            out = str_concat(out, "imports        = []\n");
        } else {
            // Split CSV and emit as TOML list
            let parts: Vec<str> = str_split(imp_csv, ",");
            let np: i64 = vec_len(parts);
            out = str_concat(out, "imports        = [");
            let mut j: i64 = 0;
            while j < np {
                if j > 0 { out = str_concat(out, ", "); };
                out = str_concat(out, str_concat("\"", str_concat(vec_get(parts, j), "\"")));
                j = j + 1;
            };
            out = str_concat(out, "]\n");
        };
        // Blank line BETWEEN rod blocks, not after the last one (matches
        // the Python version's "\n".join(out_lines) behavior with a
        // trailing "" sentinel). Skip the trailing newline on the last rod.
        if p < n_rods - 1 {
            out = str_concat(out, "\n");
        };

        p = p + 1;
    };

    file_write_string(out_path, out);

    print(str_concat("Wrote ", out_path));
    print(str_concat("Total rods: ", int_to_str(n_rods)));
    print(str_concat("Total fn: ", int_to_str(total_fn)));
    print(str_concat("Total LOC: ", int_to_str(total_loc)));
    print(str_concat("Without description: ", int_to_str(no_desc_count)));
    return 0;
}
