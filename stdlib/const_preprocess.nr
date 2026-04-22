// const_preprocess.nr — Preprocessor that substitutes const values in Nucleor source
// Reads input file, replaces const NAME refs with literal values, writes output file.
// Usage: compile this, then run: const_preprocess.exe
//   (hardcoded paths for now, will accept args when args_get works)

fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || (c >= 48 && c <= 57) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn skip_ws(source: str, pos: i32, len: i32) -> i32 {
    let mut p: i32 = pos;
    while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
    return p;
}

fn read_ident_end(source: str, pos: i32, len: i32) -> i32 {
    let mut p: i32 = pos;
    while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
    return p;
}

fn skip_string(source: str, pos: i32, len: i32) -> i32 {
    let mut p: i32 = pos + 1;
    while p < len && str_char_at(source, p) != 34 {
        if str_char_at(source, p) == 92 && p + 1 < len { p = p + 2; }
        else { p = p + 1; };
    };
    if p < len { p = p + 1; };
    return p;
}

fn lookup(cmap: str, name: str) -> str {
    let mlen: i32 = str_len(cmap);
    let search: str = str_concat(name, "=");
    let slen: i32 = str_len(search);
    let mut pos: i32 = 0;
    while pos + slen <= mlen {
        if str_eq(str_substring(cmap, pos, pos + slen), search) {
            let vs: i32 = pos + slen;
            let mut ve: i32 = vs;
            while ve < mlen && str_char_at(cmap, ve) != 44 { ve = ve + 1; };
            return str_substring(cmap, vs, ve);
        };
        while pos < mlen && str_char_at(cmap, pos) != 44 { pos = pos + 1; };
        if pos < mlen { pos = pos + 1; };
    };
    return "";
}

fn preprocess(source: str) -> str {
    let len: i32 = str_len(source);
    let mut cmap: str = "";
    let mut fp: i32 = 0;
    while fp < len {
        let fc: i32 = str_char_at(source, fp);
        if is_ws(fc) { fp = fp + 1; }
        else if is_ident_start(fc) {
            let fws: i32 = fp;
            fp = read_ident_end(source, fp, len);
            if str_eq(str_substring(source, fws, fp), "const") {
                fp = skip_ws(source, fp, len);
                let cns: i32 = fp;
                fp = read_ident_end(source, fp, len);
                let cn: str = str_substring(source, cns, fp);
                while fp < len && str_char_at(source, fp) != 61 { fp = fp + 1; };
                fp = fp + 1;
                fp = skip_ws(source, fp, len);
                let cvs: i32 = fp;
                while fp < len && str_char_at(source, fp) != 59 { fp = fp + 1; };
                cmap = str_concat(cmap, str_concat(cn, str_concat("=", str_concat(str_substring(source, cvs, fp), ","))));
                fp = fp + 1;
            };
        }
        else { fp = fp + 1; };
    };
    if str_len(cmap) == 0 { return source; };
    let mut out: str = "";
    let mut sp: i32 = 0;
    while sp < len {
        let sc: i32 = str_char_at(source, sp);
        if sc == 34 {
            let ss: i32 = sp;
            sp = skip_string(source, sp, len);
            out = str_concat(out, str_substring(source, ss, sp));
        }
        else if sc == 47 && sp + 1 < len && str_char_at(source, sp + 1) == 47 {
            let cs: i32 = sp;
            while sp < len && str_char_at(source, sp) != 10 { sp = sp + 1; };
            out = str_concat(out, str_substring(source, cs, sp));
        }
        else if is_ident_start(sc) {
            let ids: i32 = sp;
            sp = read_ident_end(source, sp, len);
            let it: str = str_substring(source, ids, sp);
            if str_eq(it, "const") {
                // Skip entire const declaration (already collected)
                // Copy as comment so line numbers don't shift
                out = str_concat(out, "// ");
                out = str_concat(out, it);
                while sp < len && str_char_at(source, sp) != 59 && str_char_at(source, sp) != 10 {
                    out = str_concat(out, str_substring(source, sp, sp + 1));
                    sp = sp + 1;
                };
                if sp < len && str_char_at(source, sp) == 59 {
                    out = str_concat(out, ";");
                    sp = sp + 1;
                };
            } else {
                let cv: str = lookup(cmap, it);
                if str_len(cv) > 0 { out = str_concat(out, cv); }
                else { out = str_concat(out, it); };
            };
        }
        else { out = str_concat(out, str_substring(source, sp, sp + 1)); sp = sp + 1; };
    };
    return out;
}

fn main() -> i32 {
    // Test inline
    let test: str = "const X: i32 = 42;\nfn main() -> i32 { return X; }";
    let result: str = preprocess(test);
    print(result);
    // Process a real file if provided
    let input: str = file_read_string("target/const_test_input.nr");
    if str_len(input) > 0 {
        let pp: str = preprocess(input);
        file_write_string("target/const_test_output.nr", pp);
        print("Preprocessed file written");
        print_int(str_len(pp));
    };
    return 0;
}
