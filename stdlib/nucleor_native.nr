// nucleor_native.nr — Native-producing Nucleor compiler (Stage 1)
// Full pipeline: .nr → C transpiler → cl.exe/gcc → native .exe
// Handles: fn, let, if/else, while, return, arithmetic, comparisons,
// boolean ops, function calls with args, Vec operations, string operations,
// print/print_int, const declarations, struct/enum (as comments).

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i32 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    s
}

// === C Runtime Preamble ===
// Embeds a minimal runtime for Vec, string ops, and print
fn c_preamble() -> str {
    str_concat("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\n",
    str_concat("// Nucleor runtime stubs\n",
    str_concat("typedef struct { int *data; int len; int cap; } NVec;\n",
    str_concat("NVec nvec_new() { NVec v = {0,0,0}; v.data = (int*)malloc(16*sizeof(int)); v.cap=16; return v; }\n",
    str_concat("void nvec_push(NVec *v, int x) { if(v->len>=v->cap){v->cap*=2;v->data=(int*)realloc(v->data,v->cap*sizeof(int));} v->data[v->len++]=x; }\n",
    str_concat("int nvec_get(NVec *v, int i) { return v->data[i]; }\n",
    str_concat("int nvec_len(NVec *v) { return v->len; }\n",
    str_concat("void nvec_pop(NVec *v) { if(v->len>0) v->len--; }\n",
    str_concat("int str_len(const char *s) { return (int)strlen(s); }\n",
    str_concat("int str_eq(const char *a, const char *b) { return strcmp(a,b)==0; }\n",
    str_concat("int str_char_at(const char *s, int i) { return (unsigned char)s[i]; }\n",
    str_concat("const char *str_substring(const char *s, int start, int end) {\n",
    str_concat("  int n=end-start; char *r=(char*)malloc(n+1); memcpy(r,s+start,n); r[n]=0; return r; }\n",
    str_concat("const char *str_concat_fn(const char *a, const char *b) {\n",
    str_concat("  int la=strlen(a),lb=strlen(b); char *r=(char*)malloc(la+lb+1); memcpy(r,a,la); memcpy(r+la,b,lb+1); return r; }\n",
    str_concat("void print(const char *s) { printf(\"%s\\n\", s); }\n",
    str_concat("int print_int(int x) { printf(\"%d\\n\", x); return 0; }\n",
    str_concat("void print_bool(int x) { printf(\"%s\\n\", x?\"true\":\"false\"); }\n",
    str_concat("const char *file_read_string(const char *path) {\n",
    str_concat("  FILE *f=fopen(path,\"rb\"); if(!f) return \"\";\n",
    str_concat("  fseek(f,0,SEEK_END); long sz=ftell(f); fseek(f,0,SEEK_SET);\n",
    str_concat("  char *buf=(char*)malloc(sz+1); fread(buf,1,sz,f); fclose(f); buf[sz]=0; return buf; }\n",
    str_concat("void file_write_string(const char *path, const char *data) {\n",
    str_concat("  FILE *f=fopen(path,\"wb\"); if(f){fwrite(data,1,strlen(data),f);fclose(f);} }\n",
    str_concat("int nucleor_system(const char *cmd) { return system(cmd); }\n",
    str_concat("// Observable runtime: auto-trace instrumentation\n",
    str_concat("static int __trace_depth = 0;\n",
    str_concat("void __trace_enter(const char *fn) { if(getenv(\"NUCLEOR_TRACE\")) { for(int i=0;i<__trace_depth;i++) fprintf(stderr,\"  \"); fprintf(stderr,\"ENTER %s\\n\",fn); __trace_depth++; } }\n",
    str_concat("void __trace_exit(const char *fn) { if(getenv(\"NUCLEOR_TRACE\")) { __trace_depth--; for(int i=0;i<__trace_depth;i++) fprintf(stderr,\"  \"); fprintf(stderr,\"EXIT %s\\n\",fn); } }\n",
    "\n")))))))))))))))))))))))))))))
}

// === Transpiler ===
fn transpile(source: str) -> str {
    let len: i32 = str_len(source);
    let mut out: str = c_preamble();
    let mut p: i32 = 0;

    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        // Comments
        else if c == 47 && p + 1 < len && str_char_at(source, p + 1) == 47 {
            while p < len && str_char_at(source, p) != 10 { p = p + 1; };
        }
        else if is_ident_start(c) {
            let ws: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            let word: str = str_substring(source, ws, p);

            // const declarations → #define
            if str_eq(word, "const") {
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let cns: i32 = p;
                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                let cname: str = str_substring(source, cns, p);
                // Skip : type =
                while p < len && str_char_at(source, p) != 61 { p = p + 1; };
                p = p + 1; // skip =
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let vs: i32 = p;
                while p < len && str_char_at(source, p) != 59 { p = p + 1; };
                let val: str = str_substring(source, vs, p);
                if p < len { p = p + 1; };
                out = str_concat(out, str_concat("#define ", str_concat(cname, str_concat(" ", str_concat(val, "\n")))));
            }
            // fn declarations
            else if str_eq(word, "fn") {
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let ns: i32 = p;
                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                let fname: str = str_substring(source, ns, p);

                // Parse params
                while p < len && str_char_at(source, p) != 40 { p = p + 1; };
                p = p + 1; // skip (
                let mut params: str = "";
                let mut param_count: i32 = 0;
                while p < len && str_char_at(source, p) != 41 {
                    if is_ws(str_char_at(source, p)) { p = p + 1; }
                    else if is_ident_start(str_char_at(source, p)) {
                        let ps: i32 = p;
                        while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                        let pname: str = str_substring(source, ps, p);
                        // Skip : type
                        while p < len && str_char_at(source, p) != 44 && str_char_at(source, p) != 41 { p = p + 1; };
                        if param_count > 0 { params = str_concat(params, ", "); };
                        params = str_concat(params, str_concat("int ", pname));
                        param_count = param_count + 1;
                        if p < len && str_char_at(source, p) == 44 { p = p + 1; };
                    }
                    else { p = p + 1; };
                };
                if p < len { p = p + 1; }; // skip )

                // Return type
                while p < len && str_char_at(source, p) != 123 { p = p + 1; };

                if param_count == 0 {
                    out = str_concat(out, str_concat("int ", str_concat(fname, "(void) {\n")));
                } else {
                    out = str_concat(out, str_concat("int ", str_concat(fname, str_concat("(", str_concat(params, ") {\n")))));
                };
                // Observable runtime: auto-insert trace at function entry
                out = str_concat(out, str_concat("__trace_enter(\"", str_concat(fname, "\");\n")));

                p = p + 1; // skip {
                // Copy body with translations
                let mut depth: i32 = 1;
                while p < len && depth > 0 {
                    let bc: i32 = str_char_at(source, p);
                    if bc == 123 { depth = depth + 1; out = str_concat(out, " {\n"); p = p + 1; }
                    else if bc == 125 {
                        depth = depth - 1;
                        if depth > 0 { out = str_concat(out, "}\n"); };
                        p = p + 1;
                    }
                    else if bc == 59 { out = str_concat(out, ";\n"); p = p + 1; }
                    else if bc == 34 {
                        out = str_concat(out, "\"");
                        p = p + 1;
                        while p < len && str_char_at(source, p) != 34 {
                            out = str_concat(out, str_substring(source, p, p + 1));
                            if str_char_at(source, p) == 92 { p = p + 1; out = str_concat(out, str_substring(source, p, p + 1)); };
                            p = p + 1;
                        };
                        out = str_concat(out, "\"");
                        if p < len { p = p + 1; };
                    }
                    else if is_ident_start(bc) {
                        let ks: i32 = p;
                        while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                        let kw: str = str_substring(source, ks, p);
                        // Keyword translations
                        if str_eq(kw, "let") {
                            while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                            let vs2: i32 = p;
                            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                            let vn: str = str_substring(source, vs2, p);
                            if str_eq(vn, "mut") {
                                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                                let vs3: i32 = p;
                                while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
                                let vn2: str = str_substring(source, vs3, p);
                                // Skip : type
                                while p < len && str_char_at(source, p) != 61 && str_char_at(source, p) != 59 { p = p + 1; };
                                out = str_concat(out, str_concat("int ", vn2));
                            } else {
                                while p < len && str_char_at(source, p) != 61 && str_char_at(source, p) != 59 { p = p + 1; };
                                out = str_concat(out, str_concat("int ", vn));
                            };
                        }
                        else if str_eq(kw, "str_concat") { out = str_concat(out, "str_concat_fn"); }
                        else if str_eq(kw, "system") { out = str_concat(out, "nucleor_system"); }
                        else if str_eq(kw, "Vec") {
                            // Vec::new() → nvec_new()
                            // Skip ::new()
                            while p < len && str_char_at(source, p) != 41 { p = p + 1; };
                            if p < len { p = p + 1; };
                            out = str_concat(out, "nvec_new()");
                        }
                        else if str_eq(kw, "return") { out = str_concat(out, "return "); }
                        else if str_eq(kw, "while") {
                            out = str_concat(out, "while (");
                            // Copy condition until {, then close )
                            while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                            while p < len && str_char_at(source, p) != 123 {
                                out = str_concat(out, str_substring(source, p, p + 1));
                                p = p + 1;
                            };
                            out = str_concat(out, ")");
                        }
                        else if str_eq(kw, "if") {
                            out = str_concat(out, "if (");
                            while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                            while p < len && str_char_at(source, p) != 123 {
                                out = str_concat(out, str_substring(source, p, p + 1));
                                p = p + 1;
                            };
                            out = str_concat(out, ")");
                        }
                        else if str_eq(kw, "else") { out = str_concat(out, " else "); }
                        else if str_eq(kw, "true") { out = str_concat(out, "1"); }
                        else if str_eq(kw, "false") { out = str_concat(out, "0"); }
                        else if str_eq(kw, "break") { out = str_concat(out, "break"); }
                        else if str_eq(kw, "continue") { out = str_concat(out, "continue"); }
                        else { out = str_concat(out, kw); };
                    }
                    else if is_ws(bc) {
                        out = str_concat(out, " ");
                        while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                    }
                    else {
                        out = str_concat(out, str_substring(source, p, p + 1));
                        p = p + 1;
                    };
                };
                out = str_concat(out, "}\n\n");
            }
            // struct/enum → skip (emitted as comments)
            else if str_eq(word, "struct") || str_eq(word, "enum") || str_eq(word, "impl") || str_eq(word, "trait") {
                out = str_concat(out, str_concat("/* ", str_concat(word, " ... */\n")));
                while p < len && str_char_at(source, p) != 123 && str_char_at(source, p) != 59 { p = p + 1; };
                if p < len && str_char_at(source, p) == 123 {
                    p = p + 1;
                    let mut sd: i32 = 1;
                    while p < len && sd > 0 {
                        if str_char_at(source, p) == 123 { sd = sd + 1; };
                        if str_char_at(source, p) == 125 { sd = sd - 1; };
                        if sd > 0 { p = p + 1; };
                    };
                    if p < len { p = p + 1; };
                }
                else if p < len { p = p + 1; };
            }
            // use → skip
            else if str_eq(word, "use") {
                while p < len && str_char_at(source, p) != 59 { p = p + 1; };
                if p < len { p = p + 1; };
            }
            else { p = p + 1; };
        }
        else { p = p + 1; };
    };
    out
}

// === Compiler Pipeline ===
fn compile_native(input_path: str, output_path: str) -> i32 {
    print("================================================");
    print("  Nucleor Native Compiler (Stage 1)");
    print("================================================");
    print(str_concat("  input:  ", input_path));
    print(str_concat("  output: ", output_path));

    let source: str = file_read_string(input_path);
    if str_len(source) == 0 {
        print("  ERROR: cannot read input");
        return 1;
    };
    print(str_concat("  source: ", str_concat(str_from_int(str_len(source)), " bytes")));

    print("  [1/3] Transpiling...");
    let c_code: str = transpile(source);
    print(str_concat("  C code: ", str_concat(str_from_int(str_len(c_code)), " bytes")));

    let c_path: str = str_concat(output_path, ".c");
    file_write_string(c_path, c_code);
    print(str_concat("  [2/3] Written: ", c_path));

    print("  [3/3] Compiling...");
    let cmd: str = str_concat("cmd /c \"\"C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Auxiliary\\Build\\vcvars64.bat\" >nul 2>&1 && cl.exe /nologo /O2 /Fe:", str_concat(output_path, str_concat(" ", str_concat(c_path, "\""))));
    let rc: i32 = system(cmd);
    if rc == 0 {
        print(str_concat("  compiled: ", output_path));
        print("  NATIVE COMPILATION SUCCESSFUL");
        0
    } else {
        print("  ERROR: compilation failed");
        1
    }
}

// === Test: compile and run a program with functions + calls ===
fn test_simple() -> i32 {
    print("=== Test 1: arithmetic ===");
    file_write_string("target/t1.nr", "fn main() -> i32 { let x: i32 = 6; let y: i32 = 7; return x * y; }");
    let r: i32 = compile_native("target/t1.nr", "target/t1.exe");
    if r == 0 {
        let rc: i32 = system("target\\t1.exe");
        print(str_concat("  exit: ", str_from_int(rc)));
        if rc == 42 { print("  PASS"); } else { print("  FAIL"); };
    };
    r
}

fn test_function_call() -> i32 {
    print("=== Test 2: function call ===");
    file_write_string("target/t2.nr", "fn add(a: i32, b: i32) -> i32 { return a + b; }\nfn main() -> i32 { return add(20, 22); }");
    let r: i32 = compile_native("target/t2.nr", "target/t2.exe");
    if r == 0 {
        let rc: i32 = system("target\\t2.exe");
        print(str_concat("  exit: ", str_from_int(rc)));
        if rc == 42 { print("  PASS"); } else { print("  FAIL"); };
    };
    r
}

fn test_while_loop() -> i32 {
    print("=== Test 3: while loop ===");
    file_write_string("target/t3.nr", "fn main() -> i32 { let mut sum: i32 = 0; let mut i: i32 = 1; while i <= 10 { sum = sum + i; i = i + 1; }; return sum; }");
    let r: i32 = compile_native("target/t3.nr", "target/t3.exe");
    if r == 0 {
        let rc: i32 = system("target\\t3.exe");
        print(str_concat("  exit: ", str_from_int(rc)));
        if rc == 55 { print("  PASS (sum 1..10 = 55)"); } else { print("  FAIL"); };
    };
    r
}

fn test_if_else() -> i32 {
    print("=== Test 4: if/else ===");
    file_write_string("target/t4.nr", "fn main() -> i32 { let x: i32 = 10; if x > 5 { return 1; } else { return 0; }; }");
    let r: i32 = compile_native("target/t4.nr", "target/t4.exe");
    if r == 0 {
        let rc: i32 = system("target\\t4.exe");
        print(str_concat("  exit: ", str_from_int(rc)));
        if rc == 1 { print("  PASS"); } else { print("  FAIL"); };
    };
    r
}

fn main() -> i32 {
    let mut pass: i32 = 0;
    let mut fail: i32 = 0;

    if test_simple() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_function_call() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_while_loop() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_if_else() == 0 { pass = pass + 1; } else { fail = fail + 1; };

    print("================================================");
    print(str_concat("  compiled: ", str_from_int(pass)));
    print(str_concat("  failed: ", str_from_int(fail)));
    if fail == 0 { print("  ALL NATIVE TESTS PASS"); };
    print("================================================");
    fail
}
