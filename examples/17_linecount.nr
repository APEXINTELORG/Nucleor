// 17_linecount.nr - A wc-style line/word/char counter.
//
// Counts lines, words, and characters across one or more files. With a single
// file, prints a one-line summary; with multiple, prints per-file rows plus
// a total. File list comes from $NUC_LC_FILES (semicolon-separated) or a
// bundled list of repo files.
//
// Demonstrates env vars, file IO, string splitting, trimming, and
// padded tabular output.
//
// Build: nuc build examples/17_linecount.nr -o linecount
// Run:   ./linecount.exe                                # bundled file list
//        NUC_LC_FILES="README.md;CHANGELOG.md" ./linecount.exe

fn count_words(line: str) -> i64 {
    let n: i64 = str_len(line);
    let mut count: i64 = 0;
    let mut in_word: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(line, i);
        let is_ws: i64 = if c == 32 || c == 9 || c == 10 || c == 13 { 1 } else { 0 };
        if is_ws == 1 {
            in_word = 0;
        } else {
            if in_word == 0 {
                count = count + 1;
                in_word = 1;
            };
        };
        i = i + 1;
    };
    return count;
}

fn analyze(path: str) -> Vec<i64> {
    // Returns [lines, words, chars] for the file at `path`. Missing or
    // empty files come back as [0, 0, 0]; callers can detect missing
    // separately via fs_exists if they care.
    let out: Vec<i64> = vec_new();
    if fs_exists(path) != 1 {
        vec_push(out, 0); vec_push(out, 0); vec_push(out, 0);
        return out;
    };
    let body: str = file_read_string(path);
    let total_chars: i64 = str_len(body);
    let lines: Vec<str> = str_lines(body);
    let total_lines: i64 = vec_len(lines);
    let mut total_words: i64 = 0;
    let mut i: i64 = 0;
    while i < total_lines {
        total_words = total_words + count_words(vec_get(lines, i));
        i = i + 1;
    };
    vec_push(out, total_lines);
    vec_push(out, total_words);
    vec_push(out, total_chars);
    return out;
}

fn read_file_list() -> Vec<str> {
    let out: Vec<str> = vec_new();
    if env_has("NUC_LC_FILES") == 1 {
        let raw: str = env_get("NUC_LC_FILES");
        if str_len(raw) > 0 {
            let parts: Vec<str> = str_split(raw, ";");
            let mut i: i64 = 0;
            while i < vec_len(parts) {
                let p: str = str_trim(vec_get(parts, i));
                if str_len(p) > 0 { vec_push(out, p); };
                i = i + 1;
            };
            return out;
        };
    };
    // Bundled default: scan a few well-known files in the repo so the
    // demo works out of the box from any CWD relative to the source tree.
    vec_push(out, "README.md");
    vec_push(out, "CHANGELOG.md");
    vec_push(out, "LICENSE");
    return out;
}

fn print_row(label: str, lines: i64, words: i64, chars: i64) {
    let path_w: i64 = 32;
    let num_w: i64 = 10;
    let line: str = str_concat(
        str_concat(str_pad_right(label, path_w, 32), str_pad_left(int_to_str(lines), num_w, 32)),
        str_concat(str_pad_left(int_to_str(words), num_w, 32), str_pad_left(int_to_str(chars), num_w, 32))
    );
    print(line);
}

fn main() -> i64 {
    print("=== Nucleor linecount demo ===");

    let files: Vec<str> = read_file_list();
    let n: i64 = vec_len(files);
    if n == 0 {
        print("ERROR: no files specified");
        return 1;
    };

    print("");
    let path_w: i64 = 32;
    let num_w: i64 = 10;
    let head: str = str_concat(
        str_concat(str_pad_right("file", path_w, 32), str_pad_left("lines", num_w, 32)),
        str_concat(str_pad_left("words", num_w, 32), str_pad_left("chars", num_w, 32))
    );
    print(head);
    let mut bar: str = "";
    let mut b: i64 = 0;
    let total_w: i64 = path_w + 3 * num_w;
    while b < total_w { bar = str_concat(bar, "-"); b = b + 1; };
    print(bar);

    let mut t_lines: i64 = 0;
    let mut t_words: i64 = 0;
    let mut t_chars: i64 = 0;
    let mut found: i64 = 0;
    let mut missing: i64 = 0;

    let mut i: i64 = 0;
    while i < n {
        let path: str = vec_get(files, i);
        let stats: Vec<i64> = analyze(path);
        let lines: i64 = vec_get(stats, 0);
        let words: i64 = vec_get(stats, 1);
        let chars: i64 = vec_get(stats, 2);
        if fs_exists(path) == 1 {
            print_row(path, lines, words, chars);
            t_lines = t_lines + lines;
            t_words = t_words + words;
            t_chars = t_chars + chars;
            found = found + 1;
        } else {
            print_row(str_concat(path, "  (missing)"), 0, 0, 0);
            missing = missing + 1;
        };
        i = i + 1;
    };

    if n > 1 {
        print(bar);
        print_row("TOTAL", t_lines, t_words, t_chars);
    };

    print("");
    if missing > 0 {
        print(str_concat(str_concat("Note: ", int_to_str(missing)), " file(s) missing."));
    };
    print(str_concat(str_concat("Counted ", int_to_str(found)), " files."));
    return 0;
}
