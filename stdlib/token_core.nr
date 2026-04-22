// Nucleor stdlib: token_core
// Token definitions for the bootstrap Nucleor-in-Nucleor lexer.
// This is the first piece of the self-hosted compiler.

// Token kinds as integer constants
const TK_EOF: i32 = 0;
const TK_INT: i32 = 1;
const TK_FLOAT: i32 = 2;
const TK_STRING: i32 = 3;
const TK_IDENT: i32 = 4;
const TK_FN: i32 = 10;
const TK_LET: i32 = 11;
const TK_MUT: i32 = 12;
const TK_RETURN: i32 = 13;
const TK_IF: i32 = 14;
const TK_ELSE: i32 = 15;
const TK_WHILE: i32 = 16;
const TK_FOR: i32 = 17;
const TK_IN: i32 = 18;
const TK_STRUCT: i32 = 19;
const TK_ENUM: i32 = 20;
const TK_MATCH: i32 = 21;
const TK_IMPL: i32 = 22;
const TK_TRAIT: i32 = 23;
const TK_TRUE: i32 = 24;
const TK_FALSE: i32 = 25;
const TK_PURE: i32 = 26;
const TK_USE: i32 = 27;
const TK_CONST: i32 = 28;
const TK_TYPE: i32 = 29;
const TK_BREAK: i32 = 30;
const TK_CONTINUE: i32 = 31;
const TK_EXTERN: i32 = 32;
const TK_SCOPE: i32 = 33;
const TK_SPAWN: i32 = 34;
// Operators
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_LBRACKET: i32 = 44;
const TK_RBRACKET: i32 = 45;
const TK_PLUS: i32 = 50;
const TK_MINUS: i32 = 51;
const TK_STAR: i32 = 52;
const TK_SLASH: i32 = 53;
const TK_PERCENT: i32 = 54;
const TK_EQ: i32 = 55;
const TK_EQEQ: i32 = 56;
const TK_BANGEQ: i32 = 57;
const TK_LT: i32 = 58;
const TK_GT: i32 = 59;
const TK_LTEQ: i32 = 60;
const TK_GTEQ: i32 = 61;
const TK_ARROW: i32 = 62;
const TK_FATARROW: i32 = 63;
const TK_DOT: i32 = 64;
const TK_DOTDOT: i32 = 65;
const TK_COLON: i32 = 66;
const TK_COLONCOLON: i32 = 67;
const TK_SEMICOLON: i32 = 68;
const TK_COMMA: i32 = 69;
const TK_AMP: i32 = 70;
const TK_AMPAMP: i32 = 71;
const TK_PIPE: i32 = 72;
const TK_PIPEPIPE: i32 = 73;
const TK_BANG: i32 = 74;
const TK_AT: i32 = 75;
const TK_HASH: i32 = 76;

struct Token {
    kind: i32,
    start: i32,
    end: i32,
}

fn token_new(kind: i32, start: i32, end: i32) -> Token {
    Token { kind: kind, start: start, end: end }
}

fn is_keyword(kind: i32) -> bool {
    kind >= 10 && kind < 40
}

fn is_operator(kind: i32) -> bool {
    kind >= 40
}

fn is_literal(kind: i32) -> bool {
    kind >= 1 && kind <= 4
}

fn main() -> i32 {
    let t: Token = token_new(TK_FN, 0, 2);
    print_bool(is_keyword(t.kind));
    print_bool(is_operator(TK_PLUS));
    print_bool(is_literal(TK_INT));
    print_int(t.start);
    0
}
