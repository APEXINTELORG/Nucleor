// Nucleor stdlib: codegen_core
// Code generation helpers for bootstrap compiler.
// Maps IR nodes to output instructions (integer-encoded for bootstrap).

// Output instruction kinds (abstract machine)
const OUT_LOAD_CONST: i32 = 0;
const OUT_LOAD_LOCAL: i32 = 1;
const OUT_STORE_LOCAL: i32 = 2;
const OUT_ADD: i32 = 10;
const OUT_SUB: i32 = 11;
const OUT_MUL: i32 = 12;
const OUT_DIV: i32 = 13;
const OUT_MOD: i32 = 14;
const OUT_CMP_EQ: i32 = 20;
const OUT_CMP_LT: i32 = 21;
const OUT_CMP_GT: i32 = 22;
const OUT_JUMP: i32 = 30;
const OUT_JUMP_IF_FALSE: i32 = 31;
const OUT_CALL: i32 = 40;
const OUT_RETURN: i32 = 41;
const OUT_NOP: i32 = 50;

struct Instruction {
    opcode: i32,
    operand: i32,
}

fn emit_load_const(value: i32) -> Instruction {
    Instruction { opcode: OUT_LOAD_CONST, operand: value }
}

fn emit_load_local(slot: i32) -> Instruction {
    Instruction { opcode: OUT_LOAD_LOCAL, operand: slot }
}

fn emit_store_local(slot: i32) -> Instruction {
    Instruction { opcode: OUT_STORE_LOCAL, operand: slot }
}

fn emit_binop(op: i32) -> Instruction {
    let opcode: i32 = if op == 0 { OUT_ADD }
        else if op == 1 { OUT_SUB }
        else if op == 2 { OUT_MUL }
        else if op == 3 { OUT_DIV }
        else if op == 4 { OUT_MOD }
        else { OUT_NOP };
    Instruction { opcode: opcode, operand: 0 }
}

fn emit_call(func_id: i32) -> Instruction {
    Instruction { opcode: OUT_CALL, operand: func_id }
}

fn emit_return() -> Instruction {
    Instruction { opcode: OUT_RETURN, operand: 0 }
}

fn emit_jump(target: i32) -> Instruction {
    Instruction { opcode: OUT_JUMP, operand: target }
}

fn emit_jump_if_false(target: i32) -> Instruction {
    Instruction { opcode: OUT_JUMP_IF_FALSE, operand: target }
}

fn is_terminator_instr(instr: Instruction) -> bool {
    instr.opcode == OUT_RETURN || instr.opcode == OUT_JUMP
}

fn is_branch(instr: Instruction) -> bool {
    instr.opcode == OUT_JUMP || instr.opcode == OUT_JUMP_IF_FALSE
}

fn main() -> i32 {
    // Emit a simple sequence: load 1, load 2, add, store x, return x
    let i0: Instruction = emit_load_const(1);
    let i1: Instruction = emit_load_const(2);
    let i2: Instruction = emit_binop(0);
    let i3: Instruction = emit_store_local(0);
    let i4: Instruction = emit_load_local(0);
    let i5: Instruction = emit_return();
    let i5_opcode: i32 = i5.opcode;

    print_int(i0.opcode);
    print_int(i0.operand);
    print_int(i2.opcode);
    print_bool(is_terminator_instr(i5));
    print_bool(i5_opcode == OUT_JUMP);

    // Test jump emission
    let jmp: Instruction = emit_jump_if_false(10);
    let jmp_operand: i32 = jmp.operand;
    print_bool(is_branch(jmp));
    print_int(jmp_operand);
    0
}
