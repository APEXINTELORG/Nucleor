// codegen_c.nr — C code generator for self-hosted Nucleor compiler
// Transpiles Nucleor source to C code.
// Stage 1 pipeline: read .nr → lex → parse → generate C → write .c
//
// Supports: fn declarations, let bindings, if/else, while, return,
// arithmetic, comparisons, boolean ops, function calls, print.

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

// Generate C code from a simple Nucleor program.
// For now, handles: fn main() -> i32 { ... } with let, if, while, return.
// Outputs C source as a string built from str_concat.
fn generate_c(source: str) -> str {
    let len: i32 = str_len(source);
    let mut out: str = "#include <stdio.h>\n#include <stdlib.h>\n\n";

    // Scan for fn declarations and translate each
    let mut p: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if c == 47 && p + 1 < len && str_char_at(source, p + 1) == 47 {
            // Skip comment
            while p < len && str_char_at(source, p) != 10 { p = p + 1; };
        }
        else if is_ident_start(c) {
            let ws: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            let word: str = str_substring(source, ws, p);

            if str_eq(word, "fn") {
                // Parse: fn NAME(params) -> TYPE { body }
                // Skip whitespace
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                // Get function name
                let ns: i32 = p;
                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                let fname: str = str_substring(source, ns, p);

                // Skip to return type
                while p < len && str_char_at(source, p) != 62 && str_char_at(source, p) != 123 { p = p + 1; };
                let mut ret_type: str = "int";
                if str_char_at(source, p) == 62 {
                    // Found -> skip to type
                    p = p + 1;
                    while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                    let ts: i32 = p;
                    while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                    let tname: str = str_substring(source, ts, p);
                    if str_eq(tname, "bool") { ret_type = "int"; }
                    else if str_eq(tname, "str") { ret_type = "const char*"; }
                    else { ret_type = "int"; };
                };

                // Generate C function header
                out = str_concat(out, str_concat(ret_type, str_concat(" ", str_concat(fname, "(void) {\n"))));

                // Find body { ... }
                while p < len && str_char_at(source, p) != 123 { p = p + 1; };
                p = p + 1; // skip {

                // Copy body verbatim with basic translations
                let mut depth: i32 = 1;
                let mut body: str = "";
                while p < len && depth > 0 {
                    let bc: i32 = str_char_at(source, p);
                    if bc == 123 { depth = depth + 1; body = str_concat(body, "{"); p = p + 1; }
                    else if bc == 125 {
                        depth = depth - 1;
                        if depth > 0 { body = str_concat(body, "}"); };
                        p = p + 1;
                    }
                    else if is_ident_start(bc) {
                        let ks: i32 = p;
                        while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                        let kw: str = str_substring(source, ks, p);
                        // Translate keywords
                        if str_eq(kw, "let") {
                            // Skip optional mut
                            while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                            let vs: i32 = p;
                            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                            let vname: str = str_substring(source, vs, p);
                            if str_eq(vname, "mut") {
                                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                                let vs2: i32 = p;
                                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                                body = str_concat(body, str_concat("    int ", str_substring(source, vs2, p)));
                            } else {
                                body = str_concat(body, str_concat("    int ", vname));
                            };
                            // Skip : type
                            while p < len && str_char_at(source, p) != 61 && str_char_at(source, p) != 59 { p = p + 1; };
                        }
                        else if str_eq(kw, "print") {
                            body = str_concat(body, "    printf(\"%s\\n\", ");
                        }
                        else if str_eq(kw, "print_int") {
                            body = str_concat(body, "    printf(\"%d\\n\", ");
                        }
                        else if str_eq(kw, "true") { body = str_concat(body, "1"); }
                        else if str_eq(kw, "false") { body = str_concat(body, "0"); }
                        else if str_eq(kw, "return") { body = str_concat(body, "    return"); }
                        else { body = str_concat(body, kw); };
                    }
                    else {
                        body = str_concat(body, str_substring(source, p, p + 1));
                        p = p + 1;
                    };
                };

                out = str_concat(out, str_concat(body, "\n}\n\n"));
            }
            else if str_eq(word, "const") {
                // const NAME: TYPE = VALUE;
                while p < len && str_char_at(source, p) != 59 { p = p + 1; };
                if p < len { p = p + 1; };
                // Skip consts for now (they're inlined in Nucleor)
            };
        }
        else { p = p + 1; };
    };

    out
}

fn main() -> i32 {
    print("================================================");
    print("  Nucleor → C Transpiler");
    print("================================================");

    // Transpile a simple program
    let source: str = "fn main() -> i32 { let x: i32 = 42; return x; }";
    let c_code: str = generate_c(source);
    print("=== Input Nucleor: ===");
    print(source);
    print("=== Output C: ===");
    print(c_code);

    // Transpile from file
    print("=== Transpiling examples/hello.nr ===");
    let hello_src: str = file_read_string("examples/hello.nr");
    let hello_c: str = generate_c(hello_src);
    print(hello_c);

    // Write C output to file
    file_write_string("target/hello_transpiled.c", hello_c);
    print("  Written to target/hello_transpiled.c");

    print("================================================");
    print("  TRANSPILER COMPLETE");
    print("================================================");
    0
}
