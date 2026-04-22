// Nucleor stdlib: ast_core
// AST node definitions for the bootstrap Nucleor-in-Nucleor parser.
// Uses integer tags for node kinds (no recursive enums yet in bootstrap subset).

use "token_core.nr";

// AST node kinds
const AST_INT_LIT: i32 = 1;
const AST_FLOAT_LIT: i32 = 2;
const AST_BOOL_LIT: i32 = 3;
const AST_STRING_LIT: i32 = 4;
const AST_IDENT: i32 = 5;
const AST_BINOP: i32 = 10;
const AST_UNARYOP: i32 = 11;
const AST_CALL: i32 = 12;
const AST_FIELD_ACCESS: i32 = 13;
const AST_INDEX_ACCESS: i32 = 14;
const AST_BLOCK: i32 = 20;
const AST_IF: i32 = 21;
const AST_WHILE: i32 = 22;
const AST_FOR: i32 = 23;
const AST_MATCH: i32 = 24;
const AST_RETURN: i32 = 25;
const AST_BREAK: i32 = 26;
const AST_CONTINUE: i32 = 27;
const AST_LET: i32 = 30;
const AST_ASSIGN: i32 = 31;
const AST_FN_DECL: i32 = 40;
const AST_STRUCT_DECL: i32 = 41;
const AST_ENUM_DECL: i32 = 42;
const AST_IMPL_DECL: i32 = 43;
const AST_TRAIT_DECL: i32 = 44;
const AST_USE_DECL: i32 = 45;
const AST_CONST_DECL: i32 = 46;
const AST_TYPE_ALIAS: i32 = 47;
const AST_EXTERN_FN: i32 = 48;

// Binary operator kinds (matches parser BinOpKind)
const BOP_ADD: i32 = 0;
const BOP_SUB: i32 = 1;
const BOP_MUL: i32 = 2;
const BOP_DIV: i32 = 3;
const BOP_MOD: i32 = 4;
const BOP_EQ: i32 = 5;
const BOP_NEQ: i32 = 6;
const BOP_LT: i32 = 7;
const BOP_GT: i32 = 8;
const BOP_LTEQ: i32 = 9;
const BOP_GTEQ: i32 = 10;
const BOP_AND: i32 = 11;
const BOP_OR: i32 = 12;

// A flat AST node: kind + up to 4 integer fields + span
struct AstNode {
    kind: i32,
    f0: i32,
    f1: i32,
    f2: i32,
    f3: i32,
    start: i32,
    end: i32,
}

fn ast_node(kind: i32, start: i32, end: i32) -> AstNode {
    AstNode { kind: kind, f0: 0, f1: 0, f2: 0, f3: 0, start: start, end: end }
}

fn ast_int_lit(value: i32, start: i32, end: i32) -> AstNode {
    AstNode { kind: AST_INT_LIT, f0: value, f1: 0, f2: 0, f3: 0, start: start, end: end }
}

fn ast_binop(op: i32, lhs_idx: i32, rhs_idx: i32, start: i32, end: i32) -> AstNode {
    AstNode { kind: AST_BINOP, f0: op, f1: lhs_idx, f2: rhs_idx, f3: 0, start: start, end: end }
}

fn ast_call(func_idx: i32, arg_count: i32, start: i32, end: i32) -> AstNode {
    AstNode { kind: AST_CALL, f0: func_idx, f1: arg_count, f2: 0, f3: 0, start: start, end: end }
}

fn ast_fn_decl(name_idx: i32, param_count: i32, body_idx: i32, start: i32, end: i32) -> AstNode {
    AstNode { kind: AST_FN_DECL, f0: name_idx, f1: param_count, f2: body_idx, f3: 0, start: start, end: end }
}

fn is_expression(node: AstNode) -> bool {
    node.kind >= 1 && node.kind < 30
}

fn is_statement(node: AstNode) -> bool {
    node.kind >= 30 && node.kind < 40
}

fn is_declaration(node: AstNode) -> bool {
    node.kind >= 40
}

fn main() -> i32 {
    let lit: AstNode = ast_int_lit(42, 0, 2);
    print_int(lit.kind);
    print_int(lit.f0);
    print_bool(is_expression(lit));

    let add: AstNode = ast_binop(BOP_ADD, 0, 1, 0, 5);
    print_int(add.kind);
    print_int(add.f0);
    print_bool(is_expression(add));

    let decl: AstNode = ast_fn_decl(0, 2, 5, 0, 50);
    // Access fields before passing to function (struct moves on call)
    let decl_params: i32 = decl.f1;
    print_bool(is_declaration(decl));
    print_int(decl_params);
    0
}
