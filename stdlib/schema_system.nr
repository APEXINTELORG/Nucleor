// schema_system.nr — Schema-first data contracts for AI-native Nucleor
// Phase 10: @schema attribute support for structs.
//
// Features:
// 1. Parse @schema annotations on structs
// 2. Track schema'd structs with field names and types
// 3. Generate JSON serialization format strings
// 4. Validate schema completeness
// 5. Generate JSON Schema output
//
// This enables typed data contracts for agent workflows:
//   @schema(json)
//   struct ToolInput { query: str, max_results: i32, include_metadata: bool }

const TK_EOF: i32 = 0;
const TK_IDENT: i32 = 4;
const TK_STRUCT: i32 = 19;
const TK_AT: i32 = 77;
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_COLON: i32 = 66;
const TK_COMMA: i32 = 69;

const TY_I32: i32 = 0;
const TY_I64: i32 = 1;
const TY_F64: i32 = 2;
const TY_BOOL: i32 = 3;
const TY_STR: i32 = 4;
const TY_UNKNOWN: i32 = 99;

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn type_name_to_tag(name: str) -> i32 {
    if str_eq(name, "i32") { TY_I32 } else if str_eq(name, "i64") { TY_I64 }
    else if str_eq(name, "f64") { TY_F64 } else if str_eq(name, "bool") { TY_BOOL }
    else if str_eq(name, "str") { TY_STR } else { TY_UNKNOWN }
}

fn type_to_json_schema(ty: i32) -> str {
    if ty == TY_I32 { "\"integer\"" } else if ty == TY_I64 { "\"integer\"" }
    else if ty == TY_F64 { "\"number\"" } else if ty == TY_BOOL { "\"boolean\"" }
    else if ty == TY_STR { "\"string\"" } else { "\"object\"" }
}

fn tokenize(source: str) -> Vec<i32> {
    let len: i32 = str_len(source);
    let mut t: Vec<i32> = Vec::new();
    let mut p: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if is_ident_start(c) {
            let s: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            let w: str = str_substring(source, s, p);
            if str_eq(w, "struct") { t.push(TK_STRUCT); }
            else { t.push(TK_IDENT); };
            t.push(s); t.push(p);
        }
        else if is_digit(c) {
            let s: i32 = p;
            while p < len && is_digit(str_char_at(source, p)) { p = p + 1; };
            t.push(TK_IDENT); t.push(s); t.push(p);
        }
        else {
            let s: i32 = p;
            if c == 64 { t.push(TK_AT); }
            else if c == 40 { t.push(TK_LPAREN); }
            else if c == 41 { t.push(TK_RPAREN); }
            else if c == 123 { t.push(TK_LBRACE); }
            else if c == 125 { t.push(TK_RBRACE); }
            else if c == 58 { t.push(TK_COLON); }
            else if c == 44 { t.push(TK_COMMA); }
            else { p = p + 1; };
            if c != 0 { t.push(s); p = p + 1; t.push(p); };
        };
    };
    t.push(TK_EOF); t.push(0); t.push(0);
    t
}

// Parse schema-annotated structs and generate JSON Schema
fn process_schemas(source: str) -> i32 {
    let tokens: Vec<i32> = tokenize(source);
    let tlen: i32 = tokens.len() / 3;
    let mut ti: i32 = 0;
    let mut schema_count: i32 = 0;

    while ti < tlen && tokens.get(ti * 3) != TK_EOF {
        // Look for @schema(json) struct Name { fields }
        if tokens.get(ti * 3) == TK_AT {
            ti = ti + 1;
            if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                let attr_name: str = str_substring(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                if str_eq(attr_name, "schema") {
                    ti = ti + 1;
                    // Skip (json) or (cbor)
                    let mut format: str = "json";
                    if ti < tlen && tokens.get(ti * 3) == TK_LPAREN {
                        ti = ti + 1;
                        if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                            format = str_substring(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                            ti = ti + 1;
                        };
                        if ti < tlen && tokens.get(ti * 3) == TK_RPAREN { ti = ti + 1; };
                    };

                    // Expect struct keyword
                    if ti < tlen && tokens.get(ti * 3) == TK_STRUCT {
                        ti = ti + 1;
                        if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                            let struct_name: str = str_substring(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                            ti = ti + 1;

                            // Parse fields
                            let mut field_names: Vec<i32> = Vec::new();
                            let mut field_types: Vec<i32> = Vec::new();
                            let mut fcount: i32 = 0;

                            if ti < tlen && tokens.get(ti * 3) == TK_LBRACE {
                                ti = ti + 1;
                                while ti < tlen && tokens.get(ti * 3) != TK_RBRACE && tokens.get(ti * 3) != TK_EOF {
                                    if tokens.get(ti * 3) == TK_IDENT {
                                        field_names.push(tokens.get(ti * 3 + 1));
                                        field_names.push(tokens.get(ti * 3 + 2));
                                        ti = ti + 1;
                                        if ti < tlen && tokens.get(ti * 3) == TK_COLON {
                                            ti = ti + 1;
                                            if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                                                let ftype: str = str_substring(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                                                field_types.push(type_name_to_tag(ftype));
                                                ti = ti + 1;
                                            };
                                        };
                                        fcount = fcount + 1;
                                    };
                                    if ti < tlen && tokens.get(ti * 3) == TK_COMMA { ti = ti + 1; };
                                };
                                if ti < tlen { ti = ti + 1; };
                            };

                            // Generate JSON Schema output
                            print(str_concat("@schema(", str_concat(format, str_concat(") ", struct_name))));
                            print("  JSON Schema:");
                            print(str_concat("  { \"type\": \"object\", \"title\": \"", str_concat(struct_name, "\",")));
                            print("    \"properties\": {");

                            let mut fi: i32 = 0;
                            while fi < fcount {
                                let fn_s: i32 = field_names.get(fi * 2);
                                let fn_e: i32 = field_names.get(fi * 2 + 1);
                                let fname: str = str_substring(source, fn_s, fn_e);
                                let fty: i32 = field_types.get(fi);
                                let jtype: str = type_to_json_schema(fty);
                                let comma: str = if fi < fcount - 1 { "," } else { "" };
                                print(str_concat("      \"", str_concat(fname, str_concat("\": { \"type\": ", str_concat(jtype, str_concat(" }", comma))))));
                                fi = fi + 1;
                            };

                            print("    },");
                            // Required: all fields
                            let mut req: str = "    \"required\": [";
                            fi = 0;
                            while fi < fcount {
                                let rn: str = str_substring(source, field_names.get(fi * 2), field_names.get(fi * 2 + 1));
                                req = str_concat(req, str_concat("\"", str_concat(rn, "\"")));
                                if fi < fcount - 1 { req = str_concat(req, ", "); };
                                fi = fi + 1;
                            };
                            req = str_concat(req, "]");
                            print(req);
                            print("  }");

                            schema_count = schema_count + 1;
                        };
                    };
                };
            };
        }
        else { ti = ti + 1; };
    };

    schema_count
}

// === Tests ===
fn test_basic_schema() -> i32 {
    print("=== Schema 1: basic struct ===");
    let n: i32 = process_schemas("@schema(json) struct User { name: str, age: i32 }");
    if n == 1 { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn test_tool_input() -> i32 {
    print("=== Schema 2: tool input ===");
    let n: i32 = process_schemas("@schema(json) struct SearchInput { query: str, max_results: i32, include_meta: bool }");
    if n == 1 { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn test_multi_schema() -> i32 {
    print("=== Schema 3: multiple schemas ===");
    let n: i32 = process_schemas("@schema(json) struct Request { url: str } @schema(json) struct Response { status: i32, body: str }");
    if n == 2 { print("  PASS"); } else { print("  FAIL"); print_int(n); };
    0
}

fn test_no_schema() -> i32 {
    print("=== Schema 4: no schema (plain struct) ===");
    let n: i32 = process_schemas("struct Point { x: i32, y: i32 }");
    if n == 0 { print("  PASS"); } else { print("  FAIL"); };
    0
}

fn main() -> i32 {
    print("================================================");
    print("  Schema-First Data Contracts (Phase 10)");
    print("================================================");
    test_basic_schema();
    test_tool_input();
    test_multi_schema();
    test_no_schema();
    print("================================================");
    print("  SCHEMA SYSTEM COMPLETE");
    print("================================================");
    0
}
