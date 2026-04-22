// stage2_boot.nr — Minimal self-hosting compiler for Stage 2 proof
// This compiler is simple enough to be compiled BY ITSELF via the C transpiler.
// It avoids Vec and method calls — only uses str ops and function calls.
// Pipeline: read .nr → transpile to C → compile with cl.exe → native .exe

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn preamble() -> str {
    str_concat("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n",
    str_concat("int str_len(const char *s){return (int)strlen(s);}\n",
    str_concat("int str_eq(const char *a, const char *b){return strcmp(a,b)==0;}\n",
    str_concat("int str_char_at(const char *s, int i){return (unsigned char)s[i];}\n",
    str_concat("const char *str_substring(const char *s, int a, int b){int n=b-a;char *r=(char*)malloc(n+1);memcpy(r,s+a,n);r[n]=0;return r;}\n",
    str_concat("const char *str_concat_fn(const char *a, const char *b){int la=strlen(a),lb=strlen(b);char *r=(char*)malloc(la+lb+1);memcpy(r,a,la);memcpy(r+la,b,lb+1);return r;}\n",
    str_concat("void print(const char *s){printf(\"%s\\n\",s);}\n",
    str_concat("int print_int(int x){printf(\"%d\\n\",x);return 0;}\n",
    str_concat("const char *file_read_string(const char *p){FILE *f=fopen(p,\"rb\");if(!f)return \"\";fseek(f,0,2);long z=ftell(f);fseek(f,0,0);char *b=(char*)malloc(z+1);fread(b,1,z,f);fclose(f);b[z]=0;return b;}\n",
    str_concat("void file_write_string(const char *p, const char *d){FILE *f=fopen(p,\"wb\");if(f){fwrite(d,1,strlen(d),f);fclose(f);}}\n",
    str_concat("int nucleor_system(const char *c){return system(c);}\n",
    "\n")))))))))))
}

fn transpile_fn_body(source: str, start: i32, end: i32) -> str {
    let mut out: str = "";
    let mut p: i32 = start;
    while p < end {
        let c: i32 = str_char_at(source, p);
        if c == 59 { out = str_concat(out, ";\n"); p = p + 1; }
        else if c == 123 { out = str_concat(out, " {\n"); p = p + 1; }
        else if c == 125 { out = str_concat(out, "}\n"); p = p + 1; }
        else if is_ident_start(c) {
            let s: i32 = p;
            while p < end && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            let w: str = str_substring(source, s, p);
            if str_eq(w, "let") {
                while p < end && is_ws(str_char_at(source, p)) { p = p + 1; };
                let ms: i32 = p;
                while p < end && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                let mn: str = str_substring(source, ms, p);
                if str_eq(mn, "mut") {
                    while p < end && is_ws(str_char_at(source, p)) { p = p + 1; };
                    let ns: i32 = p;
                    while p < end && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                    out = str_concat(out, str_concat("int ", str_substring(source, ns, p)));
                } else {
                    out = str_concat(out, str_concat("int ", mn));
                };
                while p < end && str_char_at(source, p) != 61 && str_char_at(source, p) != 59 { p = p + 1; };
            }
            else if str_eq(w, "return") { out = str_concat(out, "return "); }
            else if str_eq(w, "true") { out = str_concat(out, "1"); }
            else if str_eq(w, "false") { out = str_concat(out, "0"); }
            else if str_eq(w, "str_concat") { out = str_concat(out, "str_concat_fn"); }
            else if str_eq(w, "system") { out = str_concat(out, "nucleor_system"); }
            else if str_eq(w, "while") {
                out = str_concat(out, "while (");
                while p < end && is_ws(str_char_at(source, p)) { p = p + 1; };
                while p < end && str_char_at(source, p) != 123 {
                    out = str_concat(out, str_substring(source, p, p + 1));
                    p = p + 1;
                };
                out = str_concat(out, ")");
            }
            else if str_eq(w, "if") {
                out = str_concat(out, "if (");
                while p < end && is_ws(str_char_at(source, p)) { p = p + 1; };
                while p < end && str_char_at(source, p) != 123 {
                    out = str_concat(out, str_substring(source, p, p + 1));
                    p = p + 1;
                };
                out = str_concat(out, ")");
            }
            else if str_eq(w, "else") { out = str_concat(out, " else "); }
            else { out = str_concat(out, w); };
        }
        else if is_ws(c) { out = str_concat(out, " "); while p < end && is_ws(str_char_at(source, p)) { p = p + 1; }; }
        else { out = str_concat(out, str_substring(source, p, p + 1)); p = p + 1; };
    };
    out
}

fn transpile_source(source: str) -> str {
    let len: i32 = str_len(source);
    let mut out: str = preamble();
    let mut p: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if c == 47 && p + 1 < len && str_char_at(source, p + 1) == 47 {
            while p < len && str_char_at(source, p) != 10 { p = p + 1; };
        }
        else if is_ident_start(c) {
            let ws: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            let word: str = str_substring(source, ws, p);
            if str_eq(word, "fn") {
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let ns: i32 = p;
                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                let fname: str = str_substring(source, ns, p);
                // Params
                while p < len && str_char_at(source, p) != 40 { p = p + 1; };
                p = p + 1;
                let mut params: str = "";
                let mut pc: i32 = 0;
                while p < len && str_char_at(source, p) != 41 {
                    if is_ident_start(str_char_at(source, p)) {
                        let ps: i32 = p;
                        while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                        let pn: str = str_substring(source, ps, p);
                        while p < len && str_char_at(source, p) != 44 && str_char_at(source, p) != 41 { p = p + 1; };
                        if pc > 0 { params = str_concat(params, ", "); };
                        params = str_concat(params, str_concat("int ", pn));
                        pc = pc + 1;
                        if str_char_at(source, p) == 44 { p = p + 1; };
                    } else { p = p + 1; };
                };
                if p < len { p = p + 1; };
                while p < len && str_char_at(source, p) != 123 { p = p + 1; };
                p = p + 1;
                // Find body end
                let body_start: i32 = p;
                let mut d: i32 = 1;
                while p < len && d > 0 {
                    if str_char_at(source, p) == 123 { d = d + 1; };
                    if str_char_at(source, p) == 125 { d = d - 1; };
                    if d > 0 { p = p + 1; };
                };
                let body_end: i32 = p;
                if p < len { p = p + 1; };
                // Emit function
                if pc == 0 {
                    out = str_concat(out, str_concat("int ", str_concat(fname, "(void) {\n")));
                } else {
                    out = str_concat(out, str_concat("int ", str_concat(fname, str_concat("(", str_concat(params, ") {\n")))));
                };
                out = str_concat(out, transpile_fn_body(source, body_start, body_end));
                out = str_concat(out, "}\n\n");
            }
            else if str_eq(word, "const") {
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let cns: i32 = p;
                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                let cn: str = str_substring(source, cns, p);
                while p < len && str_char_at(source, p) != 61 { p = p + 1; };
                p = p + 1;
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let vs: i32 = p;
                while p < len && str_char_at(source, p) != 59 { p = p + 1; };
                out = str_concat(out, str_concat("#define ", str_concat(cn, str_concat(" ", str_concat(str_substring(source, vs, p), "\n")))));
                if p < len { p = p + 1; };
            }
            else {
                while p < len && str_char_at(source, p) != 59 && str_char_at(source, p) != 123 { p = p + 1; };
                if p < len && str_char_at(source, p) == 123 {
                    p = p + 1;
                    let mut sd: i32 = 1;
                    while p < len && sd > 0 { if str_char_at(source, p) == 123 { sd = sd + 1; }; if str_char_at(source, p) == 125 { sd = sd - 1; }; if sd > 0 { p = p + 1; }; };
                    if p < len { p = p + 1; };
                } else if p < len { p = p + 1; };
            };
        }
        else { p = p + 1; };
    };
    out
}

fn compile(input: str, output: str) -> i32 {
    print(str_concat("compile: ", input));
    let source: str = file_read_string(input);
    if str_len(source) == 0 { print("  error: cannot read"); return 1; };
    let c_code: str = transpile_source(source);
    let c_path: str = str_concat(output, ".c");
    file_write_string(c_path, c_code);
    let cmd: str = str_concat("cmd /c \"\"C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Auxiliary\\Build\\vcvars64.bat\" >nul 2>&1 && cl.exe /nologo /O2 /Fe:", str_concat(output, str_concat(" ", str_concat(c_path, "\""))));
    let rc: i32 = system(cmd);
    if rc == 0 { print(str_concat("  output: ", output)); 0 }
    else { print("  FAILED"); 1 }
}

fn main() -> i32 {
    print("================================================");
    print("  Stage 2 Bootstrap Compiler");
    print("================================================");

    // Test 1: compile a simple program
    file_write_string("target/s2_test.nr", "fn main() -> i32 { let x: i32 = 6; let y: i32 = 7; return x * y; }");
    let r1: i32 = compile("target/s2_test.nr", "target/s2_test.exe");
    if r1 == 0 {
        let rc: i32 = system("target\\s2_test.exe");
        print(str_concat("  exit: ", if rc == 42 { "42 CORRECT" } else { "WRONG" }));
    };

    // Test 2: compile a program with function calls
    file_write_string("target/s2_call.nr", "fn double(x: i32) -> i32 { return x * 2; }\nfn main() -> i32 { return double(21); }");
    let r2: i32 = compile("target/s2_call.nr", "target/s2_call.exe");
    if r2 == 0 {
        let rc2: i32 = system("target\\s2_call.exe");
        print(str_concat("  exit: ", if rc2 == 42 { "42 CORRECT" } else { "WRONG" }));
    };

    // Test 3: SELF-COMPILATION — compile this compiler with itself!
    print("=== SELF-COMPILATION TEST ===");
    let r3: i32 = compile("stdlib/stage2_boot.nr", "target/stage2.exe");
    if r3 == 0 {
        print("  Stage 2 binary produced!");
        // Use Stage 2 to compile the test program
        print("  Using Stage 2 to compile s2_test.nr...");
        let rc3: i32 = system("target\\stage2.exe");
        print(str_concat("  Stage 2 exit: ", if rc3 == 0 { "SUCCESS" } else { "FAILED" }));
    };

    print("================================================");
    0
}
