// stage2_proof.nr — Self-compiling Nucleor compiler for Stage 2 proof
// Translates Nucleor to C using long long (V) for all values.
// Can compile simple programs AND itself.

fn is_digit(c: i32) -> bool { return c >= 48 && c <= 57; }
fn is_alpha(c: i32) -> bool { return (c >= 65 && c <= 90) || (c >= 97 && c <= 122); }
fn is_id(c: i32) -> bool { return is_alpha(c) || is_digit(c) || c == 95; }
fn is_ws(c: i32) -> bool { return c == 32 || c == 10 || c == 13 || c == 9; }

fn emit_preamble() -> str {
    return "#include \"nucleor_rt.h\"\n\n";
}

fn write_runtime_header(dir: str) -> i32 {
    let header: str = str_concat("#ifndef NUCLEOR_RT_H\n#define NUCLEOR_RT_H\n",
    str_concat("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n",
    str_concat("typedef long long V;\n",
    str_concat("V _slen(V s){return(V)strlen((char*)s);}\n",
    str_concat("V _seq(V a,V b){return strcmp((char*)a,(char*)b)==0;}\n",
    str_concat("V _scat(V a,V b){size_t la=strlen((char*)a),lb=strlen((char*)b);char*r=(char*)malloc(la+lb+1);memcpy(r,(char*)a,la);memcpy(r+la,(char*)b,lb+1);return(V)r;}\n",
    str_concat("V _schar(V s,V i){return((unsigned char*)(char*)s)[(int)i];}\n",
    str_concat("V _ssub(V s,V a,V b){int n=(int)b-(int)a;char*r=(char*)malloc(n+1);memcpy(r,(char*)(char*)s+(int)a,n);r[n]=0;return(V)r;}\n",
    str_concat("void _pr(V s){printf(\"%s\\n\",(char*)s);}\n",
    str_concat("V _pi(V x){printf(\"%lld\\n\",(long long)x);return 0;}\n",
    str_concat("V _pb(V x){printf(\"%s\\n\",x?\"true\":\"false\");return 0;}\n",
    str_concat("V _frd(V p){FILE*f=fopen((char*)p,\"rb\");if(!f)return(V)\"\";fseek(f,0,2);long z=ftell(f);fseek(f,0,0);char*b=(char*)malloc(z+1);fread(b,1,z,f);fclose(f);b[z]=0;return(V)b;}\n",
    str_concat("void _fwr(V p,V d){FILE*f=fopen((char*)p,\"wb\");if(f){fwrite((char*)d,1,strlen((char*)d),f);fclose(f);}}\n",
    str_concat("V _sys(V c){return(V)system((char*)c);}\n",
    str_concat("// Aliases for self-compilation (names may survive untranslated)\n",
    str_concat("V str_len(V s){return _slen(s);}\n",
    str_concat("V str_eq(V a,V b){return _seq(a,b);}\n",
    str_concat("V str_char_at(V s,V i){return _schar(s,i);}\n",
    str_concat("const char *str_substring(V s,V a,V b){return(const char*)_ssub(s,a,b);}\n",
    str_concat("V str_concat(V a,V b){return _scat(a,b);}\n",
    "#endif\n"))))))))))))))))))));
    file_write_string(str_concat(dir, "/nucleor_rt.h"), header);
    return 0;
}

fn translate(source: str) -> str {
    let len: i32 = str_len(source);
    let mut out: str = emit_preamble();
    let mut p: i32 = 0;
    let mut brace_depth: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if c == 10 { out = str_concat(out, "\n"); p = p + 1; }
        else if is_ws(c) { out = str_concat(out, " "); while p < len && is_ws(str_char_at(source, p)) { p = p + 1; }; }
        else if c == 47 && p + 1 < len && str_char_at(source, p + 1) == 47 {
            while p < len && str_char_at(source, p) != 10 { p = p + 1; };
        }
        else if c == 34 {
            out = str_concat(out, "(V)\"");
            p = p + 1;
            while p < len && str_char_at(source, p) != 34 {
                out = str_concat(out, str_substring(source, p, p + 1));
                if str_char_at(source, p) == 92 { p = p + 1; out = str_concat(out, str_substring(source, p, p + 1)); };
                p = p + 1;
            };
            out = str_concat(out, "\"");
            if p < len { p = p + 1; };
        }
        else if is_alpha(c) || c == 95 {
            let s: i32 = p;
            while p < len && is_id(str_char_at(source, p)) { p = p + 1; };
            let w: str = str_substring(source, s, p);
            if str_eq(w, "fn") {
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let ns: i32 = p;
                while p < len && is_id(str_char_at(source, p)) { p = p + 1; };
                let nm: str = str_substring(source, ns, p);
                while p < len && str_char_at(source, p) != 40 { p = p + 1; };
                p = p + 1;
                let mut prm: str = "";
                let mut pc: i32 = 0;
                while p < len && str_char_at(source, p) != 41 {
                    if is_alpha(str_char_at(source, p)) || str_char_at(source, p) == 95 {
                        let ps: i32 = p;
                        while p < len && is_id(str_char_at(source, p)) { p = p + 1; };
                        let pn: str = str_substring(source, ps, p);
                        while p < len && str_char_at(source, p) != 44 && str_char_at(source, p) != 41 { p = p + 1; };
                        if pc > 0 { prm = str_concat(prm, ","); };
                        prm = str_concat(prm, str_concat("V ", pn));
                        pc = pc + 1;
                        if p < len && str_char_at(source, p) == 44 { p = p + 1; };
                    } else { p = p + 1; };
                };
                if p < len { p = p + 1; };
                while p < len && str_char_at(source, p) != 123 { p = p + 1; };
                if pc == 0 { out = str_concat(out, str_concat("V ", str_concat(nm, "(void)"))); }
                else { out = str_concat(out, str_concat("V ", str_concat(nm, str_concat("(", str_concat(prm, ")"))))); };
            }
            else if str_eq(w, "let") {
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                let ms: i32 = p;
                while p < len && is_id(str_char_at(source, p)) { p = p + 1; };
                let mn: str = str_substring(source, ms, p);
                if str_eq(mn, "mut") {
                    while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                    let ns2: i32 = p;
                    while p < len && is_id(str_char_at(source, p)) { p = p + 1; };
                    out = str_concat(out, str_concat("V ", str_substring(source, ns2, p)));
                } else { out = str_concat(out, str_concat("V ", mn)); };
                // Skip : type annotation (everything between name and = or ;)
                // But DON'T skip the = — let the main loop handle the init expression
                while p < len && str_char_at(source, p) != 61 && str_char_at(source, p) != 59 && str_char_at(source, p) != 10 { p = p + 1; };
                // Now p is at = or ; — let the main loop handle it
            }
            else if str_eq(w, "while") {
                out = str_concat(out, "while(");
                // Translate condition tokens properly (not char-by-char)
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                while p < len && str_char_at(source, p) != 123 {
                    if str_char_at(source, p) == 34 {
                        out = str_concat(out, "(V)\"");
                        p = p + 1;
                        while p < len && str_char_at(source, p) != 34 {
                            out = str_concat(out, str_substring(source, p, p + 1));
                            if str_char_at(source, p) == 92 { p = p + 1; out = str_concat(out, str_substring(source, p, p + 1)); };
                            p = p + 1;
                        };
                        out = str_concat(out, "\"");
                        if p < len { p = p + 1; };
                    }
                    else if is_alpha(str_char_at(source, p)) || str_char_at(source, p) == 95 {
                        let ws2: i32 = p;
                        while p < len && is_id(str_char_at(source, p)) { p = p + 1; };
                        let ww: str = str_substring(source, ws2, p);
                        if str_eq(ww, "str_char_at") { out = str_concat(out, "_schar"); }
                        else if str_eq(ww, "str_eq") { out = str_concat(out, "_seq"); }
                        else if str_eq(ww, "str_len") { out = str_concat(out, "_slen"); }
                        else if str_eq(ww, "str_substring") { out = str_concat(out, "_ssub"); }
                        else if str_eq(ww, "str_concat") { out = str_concat(out, "_scat"); }
                        else if str_eq(ww, "file_read_string") { out = str_concat(out, "_frd"); }
                        else if str_eq(ww, "file_write_string") { out = str_concat(out, "_fwr"); }
                        else if str_eq(ww, "system") { out = str_concat(out, "_sys"); }
                        else if str_eq(ww, "print") { out = str_concat(out, "_pr"); }
                        else if str_eq(ww, "print_int") { out = str_concat(out, "_pi"); }
                        else if str_eq(ww, "true") { out = str_concat(out, "1"); }
                        else if str_eq(ww, "false") { out = str_concat(out, "0"); }
                        else { out = str_concat(out, ww); };
                    }
                    else { out = str_concat(out, str_substring(source, p, p + 1)); p = p + 1; };
                };
                out = str_concat(out, ")");
            }
            else if str_eq(w, "if") {
                out = str_concat(out, "if(");
                while p < len && is_ws(str_char_at(source, p)) { p = p + 1; };
                while p < len && str_char_at(source, p) != 123 {
                    if str_char_at(source, p) == 34 {
                        out = str_concat(out, "(V)\"");
                        p = p + 1;
                        while p < len && str_char_at(source, p) != 34 {
                            out = str_concat(out, str_substring(source, p, p + 1));
                            if str_char_at(source, p) == 92 { p = p + 1; out = str_concat(out, str_substring(source, p, p + 1)); };
                            p = p + 1;
                        };
                        out = str_concat(out, "\"");
                        if p < len { p = p + 1; };
                    }
                    else if is_alpha(str_char_at(source, p)) || str_char_at(source, p) == 95 {
                        let ws3: i32 = p;
                        while p < len && is_id(str_char_at(source, p)) { p = p + 1; };
                        let ww2: str = str_substring(source, ws3, p);
                        if str_eq(ww2, "str_char_at") { out = str_concat(out, "_schar"); }
                        else if str_eq(ww2, "str_eq") { out = str_concat(out, "_seq"); }
                        else if str_eq(ww2, "str_len") { out = str_concat(out, "_slen"); }
                        else if str_eq(ww2, "str_substring") { out = str_concat(out, "_ssub"); }
                        else if str_eq(ww2, "str_concat") { out = str_concat(out, "_scat"); }
                        else if str_eq(ww2, "file_read_string") { out = str_concat(out, "_frd"); }
                        else if str_eq(ww2, "file_write_string") { out = str_concat(out, "_fwr"); }
                        else if str_eq(ww2, "system") { out = str_concat(out, "_sys"); }
                        else if str_eq(ww2, "print") { out = str_concat(out, "_pr"); }
                        else if str_eq(ww2, "print_int") { out = str_concat(out, "_pi"); }
                        else if str_eq(ww2, "true") { out = str_concat(out, "1"); }
                        else if str_eq(ww2, "false") { out = str_concat(out, "0"); }
                        else { out = str_concat(out, ww2); };
                    }
                    else { out = str_concat(out, str_substring(source, p, p + 1)); p = p + 1; };
                };
                out = str_concat(out, ")");
            }
            else if str_eq(w, "return") { out = str_concat(out, "return "); }
            else if str_eq(w, "else") { out = str_concat(out, "else "); }
            else if str_eq(w, "true") { out = str_concat(out, "1"); }
            else if str_eq(w, "false") { out = str_concat(out, "0"); }
            else if str_eq(w, "break") { out = str_concat(out, "break"); }
            else if str_eq(w, "str_concat") { out = str_concat(out, "_scat"); }
            else if str_eq(w, "str_len") { out = str_concat(out, "_slen"); }
            else if str_eq(w, "str_eq") { out = str_concat(out, "_seq"); }
            else if str_eq(w, "str_char_at") { out = str_concat(out, "_schar"); }
            else if str_eq(w, "str_substring") { out = str_concat(out, "_ssub"); }
            else if str_eq(w, "print") { out = str_concat(out, "_pr"); }
            else if str_eq(w, "print_int") { out = str_concat(out, "_pi"); }
            else if str_eq(w, "print_bool") { out = str_concat(out, "_pb"); }
            else if str_eq(w, "file_read_string") { out = str_concat(out, "_frd"); }
            else if str_eq(w, "file_write_string") { out = str_concat(out, "_fwr"); }
            else if str_eq(w, "system") { out = str_concat(out, "_sys"); }
            else { out = str_concat(out, w); };
        }
        else if c == 123 { brace_depth = brace_depth + 1; out = str_concat(out, "{\n"); p = p + 1; }
        else if c == 125 {
            brace_depth = brace_depth - 1;
            out = str_concat(out, ";}\n");
            p = p + 1;
        }
        else { out = str_concat(out, str_substring(source, p, p + 1)); p = p + 1; };
    };
    return out;
}

fn cc(c_path: str, exe_path: str) -> i32 {
    let cmd: str = str_concat("cmd /c \"\"C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Auxiliary\\Build\\vcvars64.bat\" >nul 2>&1 && cl.exe /nologo /O2 /I target /Fe:", str_concat(exe_path, str_concat(" ", str_concat(c_path, "\""))));
    return system(cmd);
}

fn compile_file(input: str, output: str) -> i32 {
    let source: str = file_read_string(input);
    if str_len(source) == 0 { print("error: cannot read file"); return 1; };
    let c_code: str = translate(source);
    let c_path: str = str_concat(output, ".c");
    file_write_string(c_path, c_code);
    write_runtime_header("target");
    return cc(c_path, output);
}

fn main() -> i32 {
    print("=== Stage 2 Self-Compilation Proof ===");

    // Test 1: simple arithmetic
    file_write_string("target/s2t1.nr", "fn main() -> i32 { let a: i32 = 6; let b: i32 = 7; return a * b; }");
    if compile_file("target/s2t1.nr", "target/s2t1.exe") == 0 {
        let r1: i32 = system("target\\s2t1.exe");
        if r1 == 42 { print("Test 1: 6*7=42 PASS"); } else { print("Test 1: FAIL"); };
    } else { print("Test 1: compile FAIL"); };

    // Test 2: function with params
    file_write_string("target/s2t2.nr", "fn add(a: i32, b: i32) -> i32 { return a + b; }\nfn main() -> i32 { return add(20, 22); }");
    if compile_file("target/s2t2.nr", "target/s2t2.exe") == 0 {
        let r2: i32 = system("target\\s2t2.exe");
        if r2 == 42 { print("Test 2: add(20,22)=42 PASS"); } else { print("Test 2: FAIL"); };
    } else { print("Test 2: compile FAIL"); };

    // Test 3: SELF-COMPILATION
    print("--- Self-compilation ---");
    if compile_file("stdlib/stage2_proof.nr", "target/stage3.exe") == 0 {
        print("Stage 2 binary PRODUCED!");
        // Run Stage 2 on the same test
        print("Running Stage 2...");
        system("target\\stage2.exe");
    } else { print("Self-compilation: FAIL"); };

    print("=== DONE ===");
    return 0;
}
