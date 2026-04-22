// nucleor_fmt.nr — Nucleor source formatter (Phase 9 tooling)
// Reads a .nr file and outputs formatted source code.
// Handles indentation, brace placement, and whitespace normalization.

fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }
fn is_ident_cont(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95 }

fn indent(depth: i32) -> str {
    let mut s: str = "";
    let mut i: i32 = 0;
    while i < depth { s = str_concat(s, "    "); i = i + 1; };
    s
}

fn format_source(source: str) -> str {
    let len: i32 = str_len(source);
    let mut out: str = "";
    let mut p: i32 = 0;
    let mut depth: i32 = 0;
    let mut line_start: bool = true;
    let mut in_string: bool = false;

    while p < len {
        let c: i32 = str_char_at(source, p);

        if in_string {
            out = str_concat(out, str_substring(source, p, p + 1));
            if c == 34 { in_string = false; };
            if c == 92 && p + 1 < len { p = p + 1; out = str_concat(out, str_substring(source, p, p + 1)); };
            p = p + 1;
        }
        else if c == 34 {
            if line_start { out = str_concat(out, indent(depth)); line_start = false; };
            out = str_concat(out, "\"");
            in_string = true;
            p = p + 1;
        }
        else if c == 123 { // {
            out = str_concat(out, " {\n");
            depth = depth + 1;
            line_start = true;
            p = p + 1;
        }
        else if c == 125 { // }
            depth = depth - 1;
            if depth < 0 { depth = 0; };
            out = str_concat(out, str_concat(indent(depth), "}\n"));
            line_start = true;
            p = p + 1;
        }
        else if c == 59 { // ;
            out = str_concat(out, ";\n");
            line_start = true;
            p = p + 1;
        }
        else if c == 10 || c == 13 {
            // Skip existing newlines (we add our own)
            p = p + 1;
        }
        else if is_ws(c) {
            // Normalize whitespace to single space
            if !line_start { out = str_concat(out, " "); };
            while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
        }
        else {
            if line_start { out = str_concat(out, indent(depth)); line_start = false; };
            // Copy token
            let s: i32 = p;
            if is_ident_cont(c) {
                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            } else { p = p + 1; };
            out = str_concat(out, str_substring(source, s, p));
        };
    };
    out
}

fn main() -> i32 {
    print("================================================");
    print("  Nucleor Formatter (Phase 9)");
    print("================================================");

    // Format a messy program
    let messy: str = "fn main()->i32{let x:i32=42;if x>0{print_int(x);}else{print_int(0);};return x;}";
    print("=== Before: ===");
    print(messy);
    print("=== After: ===");
    let formatted: str = format_source(messy);
    print(formatted);

    // Format from file
    print("=== Formatting examples/hello.nr: ===");
    let source: str = file_read_string("examples/hello.nr");
    let fmt: str = format_source(source);
    print(fmt);

    print("================================================");
    print("  FORMATTER COMPLETE");
    print("================================================");
    0
}
