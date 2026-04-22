// Nucleor stdlib: checker_core
// Type checking primitives for bootstrap compiler.
// Handles type compatibility, move tracking, and effect checking.

// Type compatibility matrix
const TY_I32: i32 = 0;
const TY_I64: i32 = 1;
const TY_F64: i32 = 2;
const TY_BOOL: i32 = 3;
const TY_STR: i32 = 4;
const TY_VOID: i32 = 5;
const TY_STRUCT: i32 = 10;
const TY_ENUM: i32 = 11;
const TY_VEC: i32 = 12;
const TY_OPTION: i32 = 13;
const TY_RESULT: i32 = 14;
const TY_REF: i32 = 15;

fn types_compatible(a: i32, b: i32) -> bool {
    if a == b { true }
    // Integer promotion: i32 compatible with i64
    else if (a == TY_I32 && b == TY_I64) || (a == TY_I64 && b == TY_I32) { true }
    // Void compatible with anything (for Option<Void> → Option<T>)
    else if a == TY_VOID || b == TY_VOID { true }
    else { false }
}

fn is_numeric_type(ty: i32) -> bool {
    ty == TY_I32 || ty == TY_I64 || ty == TY_F64
}

fn is_copy_type(ty: i32) -> bool {
    ty == TY_I32 || ty == TY_I64 || ty == TY_F64 || ty == TY_BOOL || ty == TY_STR || ty == TY_VOID
}

fn is_resource_type(ty: i32) -> bool {
    ty >= 10
}

// Binary op type inference
fn binop_result_type(op: i32, lhs: i32, rhs: i32) -> i32 {
    // Comparison ops always return bool
    if op >= 5 && op <= 10 { TY_BOOL }
    // Logical ops return bool
    else if op == 11 || op == 12 { TY_BOOL }
    // Arithmetic: promote to wider type
    else if lhs == TY_F64 || rhs == TY_F64 { TY_F64 }
    else if lhs == TY_I64 || rhs == TY_I64 { TY_I64 }
    else { TY_I32 }
}

// Move tracking
struct MoveState {
    moved_count: i32,
    borrow_count: i32,
    scope_depth: i32,
}

fn move_state_new() -> MoveState {
    MoveState { moved_count: 0, borrow_count: 0, scope_depth: 0 }
}

fn enter_scope(depth: i32) -> i32 {
    depth + 1
}

fn exit_scope(depth: i32) -> i32 {
    if depth > 0 { depth - 1 } else { 0 }
}

// Effect tracking
const EFF_NONE: i32 = 0;
const EFF_IO: i32 = 1;
const EFF_SYNC: i32 = 2;
const EFF_RAND: i32 = 4;
const EFF_MEM: i32 = 8;
const EFF_UNSAFE: i32 = 16;
const EFF_ALL: i32 = 31;

fn has_effect(effects: i32, eff: i32) -> bool {
    (effects / eff) % 2 == 1
}

fn add_effect(effects: i32, eff: i32) -> i32 {
    if has_effect(effects, eff) { effects }
    else { effects + eff }
}

fn effects_denied_by_pure() -> i32 {
    EFF_ALL
}

fn main() -> i32 {
    // Type compatibility
    print_bool(types_compatible(TY_I32, TY_I32));
    print_bool(types_compatible(TY_I32, TY_I64));
    print_bool(types_compatible(TY_I32, TY_BOOL));
    print_bool(is_numeric_type(TY_F64));
    print_bool(is_copy_type(TY_STR));
    print_bool(is_resource_type(TY_VEC));

    // Binop inference
    print_int(binop_result_type(0, TY_I32, TY_I32));
    print_int(binop_result_type(0, TY_I32, TY_F64));
    print_int(binop_result_type(5, TY_I32, TY_I32));

    // Scope tracking
    let d: i32 = enter_scope(0);
    print_int(d);
    print_int(exit_scope(d));

    // Effect tracking
    let eff: i32 = add_effect(EFF_NONE, EFF_IO);
    let eff2: i32 = add_effect(eff, EFF_RAND);
    print_bool(has_effect(eff2, EFF_IO));
    print_bool(has_effect(eff2, EFF_SYNC));
    print_bool(has_effect(eff2, EFF_RAND));
    0
}
