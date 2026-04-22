// Nucleor stdlib: parser_core
// Recursive descent parser skeleton for bootstrap compiler.
// Uses token stream + AST node Vec as flat indexed structures.

const TK_EOF: i32 = 0;
const TK_INT: i32 = 1;
const TK_IDENT: i32 = 4;
const TK_FN: i32 = 10;
const TK_LET: i32 = 11;
const TK_RETURN: i32 = 13;
const TK_IF: i32 = 14;
const TK_ELSE: i32 = 15;
const TK_WHILE: i32 = 16;
const TK_STRUCT: i32 = 19;
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_PLUS: i32 = 50;
const TK_MINUS: i32 = 51;
const TK_STAR: i32 = 52;
const TK_SLASH: i32 = 53;
const TK_EQEQ: i32 = 56;
const TK_LT: i32 = 58;
const TK_GT: i32 = 59;
const TK_ARROW: i32 = 62;
const TK_COLON: i32 = 66;
const TK_SEMICOLON: i32 = 68;
const TK_COMMA: i32 = 69;
const TK_EQ: i32 = 55;

// Parser state: position in token stream
struct ParserState {
    pos: i32,
    token_count: i32,
    error_count: i32,
}

fn parser_new(token_count: i32) -> ParserState {
    ParserState { pos: 0, token_count: token_count, error_count: 0 }
}

fn parser_at_end(ps: ParserState) -> bool {
    ps.pos >= ps.token_count
}

fn parser_advance(pos: i32) -> i32 {
    pos + 1
}

// Precedence levels for expression parsing
const PREC_NONE: i32 = 0;
const PREC_OR: i32 = 1;
const PREC_AND: i32 = 2;
const PREC_EQUALITY: i32 = 3;
const PREC_COMPARISON: i32 = 4;
const PREC_ADDITIVE: i32 = 5;
const PREC_MULTIPLICATIVE: i32 = 6;
const PREC_UNARY: i32 = 7;
const PREC_CALL: i32 = 8;
const PREC_PRIMARY: i32 = 9;

fn operator_precedence(tok_kind: i32) -> i32 {
    if tok_kind == TK_PLUS || tok_kind == TK_MINUS { PREC_ADDITIVE }
    else if tok_kind == TK_STAR || tok_kind == TK_SLASH { PREC_MULTIPLICATIVE }
    else if tok_kind == TK_EQEQ { PREC_EQUALITY }
    else if tok_kind == TK_LT || tok_kind == TK_GT { PREC_COMPARISON }
    else { PREC_NONE }
}

fn is_binary_operator(tok_kind: i32) -> bool {
    operator_precedence(tok_kind) > PREC_NONE
}

// Map token kind to BinOp kind
fn token_to_binop(tok_kind: i32) -> i32 {
    if tok_kind == TK_PLUS { 0 }
    else if tok_kind == TK_MINUS { 1 }
    else if tok_kind == TK_STAR { 2 }
    else if tok_kind == TK_SLASH { 3 }
    else if tok_kind == TK_EQEQ { 5 }
    else if tok_kind == TK_LT { 7 }
    else if tok_kind == TK_GT { 8 }
    else { -1 }
}

fn main() -> i32 {
    // Test precedence
    print_int(operator_precedence(TK_PLUS));
    print_int(operator_precedence(TK_STAR));
    print_bool(operator_precedence(TK_STAR) > operator_precedence(TK_PLUS));

    // Test binary op detection
    print_bool(is_binary_operator(TK_PLUS));
    print_bool(is_binary_operator(TK_LPAREN));

    // Test binop mapping
    print_int(token_to_binop(TK_PLUS));
    print_int(token_to_binop(TK_STAR));

    // Test parser state
    let ps: ParserState = parser_new(50);
    print_bool(parser_at_end(ps));
    print_int(parser_advance(3));
    0
}
