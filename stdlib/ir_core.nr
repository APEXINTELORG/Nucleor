// Nucleor stdlib: ir_core
// IR definitions for the bootstrap code generator.
// Flat representation: nodes stored in Vec with index references.

// IR instruction kinds
const IR_CONST_I64: i32 = 0;
const IR_CONST_F64: i32 = 1;
const IR_CONST_BOOL: i32 = 2;
const IR_PARAM: i32 = 3;
const IR_LOCAL_GET: i32 = 4;
const IR_BINOP: i32 = 10;
const IR_UNARYOP: i32 = 11;
const IR_CALL: i32 = 12;
const IR_IF: i32 = 20;
const IR_BLOCK: i32 = 21;
const IR_WHILE: i32 = 22;
const IR_RETURN: i32 = 23;
const IR_BREAK: i32 = 24;
const IR_CONTINUE: i32 = 25;
const IR_LET: i32 = 30;
const IR_ASSIGN: i32 = 31;
const IR_DROP: i32 = 32;
const IR_STRUCT_LIT: i32 = 40;
const IR_FIELD_ACCESS: i32 = 41;
const IR_ENUM_LIT: i32 = 42;
const IR_ENUM_TAG: i32 = 43;
const IR_ARRAY_LIT: i32 = 44;
const IR_INDEX: i32 = 45;

// IR type tags
const IRTY_I32: i32 = 0;
const IRTY_I64: i32 = 1;
const IRTY_F64: i32 = 2;
const IRTY_BOOL: i32 = 3;
const IRTY_VOID: i32 = 4;
const IRTY_STR: i32 = 5;
const IRTY_STRUCT: i32 = 10;
const IRTY_ENUM: i32 = 11;

// Overflow modes
const OVF_TRAP: i32 = 0;
const OVF_WRAP: i32 = 1;
const OVF_SAT: i32 = 2;

struct IrNode {
    kind: i32,
    type_tag: i32,
    f0: i32,
    f1: i32,
    f2: i32,
}

fn ir_const_i64(value: i32) -> IrNode {
    IrNode { kind: IR_CONST_I64, type_tag: IRTY_I64, f0: value, f1: 0, f2: 0 }
}

fn ir_binop(op: i32, lhs: i32, rhs: i32, overflow: i32) -> IrNode {
    IrNode { kind: IR_BINOP, type_tag: IRTY_I64, f0: op, f1: lhs, f2: rhs }
}

fn ir_call(func_idx: i32, arg_count: i32, ret_type: i32) -> IrNode {
    IrNode { kind: IR_CALL, type_tag: ret_type, f0: func_idx, f1: arg_count, f2: 0 }
}

fn ir_local_get(local_id: i32, type_tag: i32) -> IrNode {
    IrNode { kind: IR_LOCAL_GET, type_tag: type_tag, f0: local_id, f1: 0, f2: 0 }
}

fn ir_let(local_id: i32, value_idx: i32, type_tag: i32) -> IrNode {
    IrNode { kind: IR_LET, type_tag: type_tag, f0: local_id, f1: value_idx, f2: 0 }
}

fn ir_return(value_idx: i32) -> IrNode {
    IrNode { kind: IR_RETURN, type_tag: IRTY_VOID, f0: value_idx, f1: 0, f2: 0 }
}

fn is_terminator(node: IrNode) -> bool {
    node.kind == IR_RETURN || node.kind == IR_BREAK || node.kind == IR_CONTINUE
}

fn main() -> i32 {
    // Build a simple IR: let x = 1 + 2; return x;
    let c1: IrNode = ir_const_i64(1);
    let c2: IrNode = ir_const_i64(2);
    let add: IrNode = ir_binop(0, 0, 1, OVF_TRAP);
    let bind: IrNode = ir_let(0, 2, IRTY_I64);
    let get: IrNode = ir_local_get(0, IRTY_I64);
    let ret: IrNode = ir_return(4);

    print_int(c1.kind);
    print_int(add.kind);
    print_bool(is_terminator(ret));
    print_bool(is_terminator(add));
    0
}
