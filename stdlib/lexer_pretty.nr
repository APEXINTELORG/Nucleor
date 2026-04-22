// Test: pretty-print tokens with 30-branch if-else (was crashing before opt_level=speed)

const TK_EOF: i32 = 0;
const TK_INT: i32 = 1;
const TK_IDENT: i32 = 4;
const TK_FN: i32 = 10;
const TK_LET: i32 = 11;
const TK_STRUCT: i32 = 19;
const TK_TRUE: i32 = 24;
const TK_FALSE: i32 = 25;
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_PLUS: i32 = 50;
const TK_MINUS: i32 = 51;
const TK_STAR: i32 = 52;
const TK_EQ: i32 = 55;
const TK_EQEQ: i32 = 56;
const TK_ARROW: i32 = 62;
const TK_COLON: i32 = 66;
const TK_SEMICOLON: i32 = 68;
const TK_COMMA: i32 = 69;
const TK_LT: i32 = 72;
const TK_GT: i32 = 73;

fn print_token(kind: i32) -> i32 {
    if kind == TK_EOF { print("EOF"); }
    else if kind == TK_INT { print("INT"); }
    else if kind == TK_IDENT { print("IDENT"); }
    else if kind == TK_FN { print("fn"); }
    else if kind == TK_LET { print("let"); }
    else if kind == TK_STRUCT { print("struct"); }
    else if kind == TK_TRUE { print("true"); }
    else if kind == TK_FALSE { print("false"); }
    else if kind == TK_LPAREN { print("("); }
    else if kind == TK_RPAREN { print(")"); }
    else if kind == TK_LBRACE { print("{"); }
    else if kind == TK_RBRACE { print("}"); }
    else if kind == TK_PLUS { print("+"); }
    else if kind == TK_MINUS { print("-"); }
    else if kind == TK_STAR { print("*"); }
    else if kind == TK_EQ { print("="); }
    else if kind == TK_EQEQ { print("=="); }
    else if kind == TK_ARROW { print("->"); }
    else if kind == TK_COLON { print(":"); }
    else if kind == TK_SEMICOLON { print(";"); }
    else if kind == TK_COMMA { print(","); }
    else if kind == TK_LT { print("<"); }
    else if kind == TK_GT { print(">"); }
    else { print("?"); };
    0
}

fn main() -> i32 {
    // Test every token kind
    print_token(TK_FN);
    print_token(TK_IDENT);
    print_token(TK_LPAREN);
    print_token(TK_RPAREN);
    print_token(TK_ARROW);
    print_token(TK_IDENT);
    print_token(TK_LBRACE);
    print_token(TK_LET);
    print_token(TK_IDENT);
    print_token(TK_COLON);
    print_token(TK_IDENT);
    print_token(TK_EQ);
    print_token(TK_INT);
    print_token(TK_SEMICOLON);
    print_token(TK_IDENT);
    print_token(TK_PLUS);
    print_token(TK_INT);
    print_token(TK_RBRACE);
    print_token(TK_EOF);
    print("---done---");
    0
}
