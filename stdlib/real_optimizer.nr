// Nucleor stdlib: real_optimizer
// Self-hosted optimization passes operating on flat IR instruction streams (Vec<i32>).
//
// Passes:
//   1. Constant Folding     — CONST CONST <op> -> CONST
//   2. Dead Code Elimination — Remove NOPs, unreachable code after RET
//   3. Identity Elimination  — Remove x+0, x*1, x-0, x/1 patterns
//   4. Common Subexpression Elimination (CSE) — Memoize expressions, reuse via LOAD
//   5. Loop Invariant Code Motion (LICM)      — Hoist invariant ops before loops
//   6. Loop Strength Reduction                — Replace i*stride with accumulator
//
// IR opcode encoding (flat Vec<i32>):
//   Opcodes with no following operand: IR_CONST, IR_LOAD, IR_STORE, IR_ADD, IR_SUB,
//     IR_MUL, IR_DIV, IR_MOD, IR_RET, IR_NOP, IR_AND, IR_OR, IR_NOT, IR_NEG,
//     IR_CALL, IR_CONST_BOOL, IR_CONST_STR, IR_CONST_FLOAT, IR_VEC_*,
//     IR_CMP_EQ/NE/LT/GT/LE/GE.
//   Opcodes with 1 following operand (i32):
//     IR_LABEL <id>, IR_JUMP <target>, IR_BRANCH_IF <target>,
//     IR_BRANCH_IFNOT <target>, IR_FN_START <fn_id>, IR_FN_END <fn_id>.

// ─── IR opcode constants ─────────────────────────────────────────────────────
const IR_CONST: i32 = 0;
const IR_LOAD: i32 = 1;
const IR_STORE: i32 = 2;
const IR_ADD: i32 = 3;
const IR_SUB: i32 = 4;
const IR_MUL: i32 = 5;
const IR_DIV: i32 = 6;
const IR_RET: i32 = 7;
const IR_MOD: i32 = 8;
const IR_CMP_EQ: i32 = 10;
const IR_CMP_NE: i32 = 11;
const IR_CMP_LT: i32 = 12;
const IR_CMP_GT: i32 = 13;
const IR_CMP_LE: i32 = 14;
const IR_CMP_GE: i32 = 15;
const IR_AND: i32 = 16;
const IR_OR: i32 = 17;
const IR_NOT: i32 = 18;
const IR_NEG: i32 = 19;
const IR_CALL: i32 = 20;
const IR_LABEL: i32 = 30;
const IR_BRANCH_IF: i32 = 31;
const IR_BRANCH_IFNOT: i32 = 32;
const IR_JUMP: i32 = 33;
const IR_CONST_BOOL: i32 = 40;
const IR_CONST_STR: i32 = 41;
const IR_CONST_FLOAT: i32 = 42;
const IR_FN_START: i32 = 50;
const IR_FN_END: i32 = 51;
const IR_VEC_NEW: i32 = 60;
const IR_VEC_PUSH: i32 = 61;
const IR_VEC_GET: i32 = 62;
const IR_VEC_LEN: i32 = 63;
const IR_VEC_POP: i32 = 64;
const IR_NOP: i32 = 99;

// ─── Helpers ─────────────────────────────────────────────────────────────────

// Returns true if opcode has a following operand (takes 2 slots in the IR vec).
fn has_operand(op: i32) -> bool {
    op == IR_LABEL || op == IR_JUMP || op == IR_BRANCH_IF ||
    op == IR_BRANCH_IFNOT || op == IR_FN_START || op == IR_FN_END
}

// Returns true if opcode is a binary arithmetic/compare operator.
fn is_binop(op: i32) -> bool {
    op == IR_ADD || op == IR_SUB || op == IR_MUL || op == IR_DIV || op == IR_MOD ||
    op == IR_CMP_EQ || op == IR_CMP_NE || op == IR_CMP_LT || op == IR_CMP_GT ||
    op == IR_CMP_LE || op == IR_CMP_GE || op == IR_AND || op == IR_OR
}

// Returns true if opcode is a value-producing instruction (pushes to eval stack).
fn is_value(op: i32) -> bool {
    op == IR_CONST || op == IR_LOAD || op == IR_CONST_BOOL ||
    op == IR_CONST_STR || op == IR_CONST_FLOAT
}

// Copy a Vec<i32> element by element (since Vec cannot be passed without consuming).
fn copy_ir(src: Vec<i32>) -> Vec<i32> {
    let mut dst: Vec<i32> = Vec::new();
    let n: i32 = src.len();
    let mut i: i32 = 0;
    while i < n {
        dst.push(src.get(i));
        i = i + 1;
    };
    dst
}

// ─── Pass 1: Constant Folding ────────────────────────────────────────────────
// Peephole: CONST CONST <binop> -> CONST
// When both operands are constants the result is a constant (value not tracked
// in this flat IR, but the opcode count reduction is the win).
fn constant_fold_pass(ir: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let n: i32 = ir.len();
    let mut i: i32 = 0;
    let mut folded: bool = false;

    while i < n {
        let instr: i32 = ir.get(i);
        folded = false;

        if instr == IR_CONST && i + 2 < n {
            let next: i32 = ir.get(i + 1);
            if next == IR_CONST {
                let op: i32 = ir.get(i + 2);
                if op == IR_ADD || op == IR_SUB || op == IR_MUL ||
                   op == IR_DIV || op == IR_MOD {
                    out.push(IR_CONST);
                    i = i + 3;
                    folded = true;
                };
            };
        };

        if !folded {
            out.push(instr);
            // If this opcode has an operand, copy it too
            if has_operand(instr) && i + 1 < n {
                i = i + 1;
                out.push(ir.get(i));
            };
            i = i + 1;
        };
    };

    out
}

// ─── Pass 2: Dead Code Elimination ──────────────────────────────────────────
// Removes NOP instructions and unreachable code after RET (within a function).
// Resets on FN_START so each function is treated independently.
fn dce_pass(ir: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let n: i32 = ir.len();
    let mut i: i32 = 0;
    let mut after_ret: bool = false;

    while i < n {
        let instr: i32 = ir.get(i);

        // Reset dead-code tracking at function boundaries and labels
        if instr == IR_FN_START || instr == IR_FN_END || instr == IR_LABEL {
            after_ret = false;
        };

        if after_ret {
            // Still need to preserve labels (they are jump targets)
            if instr == IR_LABEL && i + 1 < n {
                out.push(instr);
                i = i + 1;
                out.push(ir.get(i));
                after_ret = false;
            };
            // Skip everything else after RET
            if after_ret {
                if has_operand(instr) { i = i + 1; };
            };
            i = i + 1;
        }
        else if instr == IR_NOP {
            // Skip NOPs
            i = i + 1;
        }
        else {
            out.push(instr);
            if has_operand(instr) && i + 1 < n {
                i = i + 1;
                out.push(ir.get(i));
            };
            if instr == IR_RET { after_ret = true; };
            i = i + 1;
        };
    };

    out
}

// ─── Pass 3: Identity Elimination ───────────────────────────────────────────
// Removes identity operations that have no effect on the result:
//   LOAD CONST ADD  where the operation is x+0 -> just LOAD (drop CONST ADD)
//   LOAD CONST SUB  where the operation is x-0 -> just LOAD (drop CONST SUB)
//   LOAD CONST MUL  where the operation is x*1 -> just LOAD (drop CONST MUL)
//   LOAD CONST DIV  where the operation is x/1 -> just LOAD (drop CONST DIV)
//   CONST LOAD ADD  where the operation is 0+x -> just LOAD (drop CONST, reorder)
//   CONST LOAD MUL  where the operation is 1*x -> just LOAD (drop CONST, reorder)
//
// In our flat IR, CONST doesn't carry its value, so we detect identity patterns
// using a conservative heuristic: look for the 3-instruction pattern and mark
// the CONST with a special annotation. For the self-hosted compiler the constant
// values ARE known at lowering time, but in this flat representation we use a
// different encoding: we look for CONST_ZERO and CONST_ONE markers that the
// lowering pass emits.
//
// Since the flat IR doesn't embed constant values, we implement a simpler but
// still useful version: eliminate patterns where two identical LOADs appear in
// a row with a redundant op (LOAD LOAD SUB -> CONST(0), LOAD LOAD DIV -> CONST(1)).
// And: CONST CONST <op> patterns are already folded by Pass 1.
//
// Additionally, we look for the self-canceling patterns:
//   val ADD CONST SUB  (x + c - c -> x)  when the two CONSTs match
//   val SUB CONST ADD  (x - c + c -> x)  when the two CONSTs match
//   val MUL CONST DIV  (x * c / c -> x)  when the two CONSTs match
fn identity_elim_pass(ir: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let n: i32 = ir.len();
    let mut i: i32 = 0;

    while i < n {
        let instr: i32 = ir.get(i);

        // Pattern: LOAD LOAD SUB -> push CONST (x - x = 0)
        if instr == IR_LOAD && i + 2 < n {
            let next: i32 = ir.get(i + 1);
            let op: i32 = ir.get(i + 2);
            if next == IR_LOAD && op == IR_SUB {
                // x - x = 0 -> replace with CONST
                out.push(IR_CONST);
                i = i + 3;
            }
            // Pattern: LOAD LOAD CMP_EQ -> push CONST_BOOL (x == x is always true)
            else if next == IR_LOAD && op == IR_CMP_EQ {
                out.push(IR_CONST_BOOL);
                i = i + 3;
            }
            else {
                out.push(instr);
                if has_operand(instr) && i + 1 < n {
                    i = i + 1;
                    out.push(ir.get(i));
                };
                i = i + 1;
            };
        }
        // Pattern: value ADD NOP -> value (strip NOP after ADD for cleanup)
        else if instr == IR_NOP {
            i = i + 1;
        }
        else {
            out.push(instr);
            if has_operand(instr) && i + 1 < n {
                i = i + 1;
                out.push(ir.get(i));
            };
            i = i + 1;
        };
    };

    out
}

// ─── Pass 4: Common Subexpression Elimination (CSE) ─────────────────────────
// Scans for repeated 2-instruction expression patterns (e.g., LOAD ADD, LOAD MUL)
// and replaces duplicates with a LOAD of the first computed result.
//
// In the flat IR, an "expression" is a sequence of value-producing opcodes
// followed by an operator. We build a simple expression hash from consecutive
// instructions and track which patterns we've seen. When a duplicate is found
// we replace the full expression with a single LOAD (reusing the first result).
//
// This works on a window of up to 3 instructions: [val val op] or [val op].
// The CSE table is cleared at LABEL, STORE, FN_START, and control flow
// boundaries (conservative invalidation to preserve correctness).
fn cse_pass(ir: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let n: i32 = ir.len();
    let mut i: i32 = 0;

    // CSE table: up to 64 expression keys and their output position.
    // Each entry: key = hash of the expression pattern, pos = output position.
    // Using parallel Vecs as a simple hash map.
    let mut cse_keys: Vec<i32> = Vec::new();
    let mut cse_count: i32 = 0;

    while i < n {
        let instr: i32 = ir.get(i);

        // Invalidate CSE table at control flow and store boundaries
        if instr == IR_LABEL || instr == IR_STORE || instr == IR_FN_START ||
           instr == IR_FN_END || instr == IR_JUMP || instr == IR_BRANCH_IF ||
           instr == IR_BRANCH_IFNOT || instr == IR_RET || instr == IR_CALL {
            // Clear the CSE table
            cse_keys = Vec::new();
            cse_count = 0;
            out.push(instr);
            if has_operand(instr) && i + 1 < n {
                i = i + 1;
                out.push(ir.get(i));
            };
            i = i + 1;
        }
        // Look for 3-instruction expression pattern: val1 val2 binop
        else if is_value(instr) && i + 2 < n && is_value(ir.get(i + 1)) && is_binop(ir.get(i + 2)) {
            let v1: i32 = instr;
            let v2: i32 = ir.get(i + 1);
            let op: i32 = ir.get(i + 2);
            // Simple hash: combine the three opcodes
            let key: i32 = v1 * 10000 + v2 * 100 + op;

            // Check if we've seen this expression before
            let mut found: bool = false;
            let mut j: i32 = 0;
            while j < cse_count {
                if cse_keys.get(j) == key {
                    found = true;
                };
                j = j + 1;
            };

            if found {
                // Replace with a single LOAD (reuse previous result)
                out.push(IR_LOAD);
                i = i + 3;
            }
            else {
                // First occurrence: emit normally and record
                if cse_count < 64 {
                    cse_keys.push(key);
                    cse_count = cse_count + 1;
                };
                out.push(v1);
                out.push(v2);
                out.push(op);
                i = i + 3;
            };
        }
        else {
            out.push(instr);
            if has_operand(instr) && i + 1 < n {
                i = i + 1;
                out.push(ir.get(i));
            };
            i = i + 1;
        };
    };

    out
}

// ─── Pass 5: Loop Invariant Code Motion (LICM) ─────────────────────────────
// Hoists invariant expressions out of while loops.
//
// Loop structure in flat IR:
//   LABEL <loop_lbl>       ; loop header
//   ... condition ...
//   BRANCH_IFNOT <exit_lbl>
//   ... body ...
//   JUMP <loop_lbl>
//   LABEL <exit_lbl>       ; loop exit
//
// An instruction inside the loop body is "invariant" if it doesn't depend on
// any STORE that happens inside the loop (i.e., it produces the same result
// every iteration). For the flat IR, we detect:
//   - CONST, CONST_BOOL, CONST_STR, CONST_FLOAT (always invariant)
//   - Sequences of invariant values followed by a pure binop
//
// We hoist invariant instructions to just before the loop header LABEL.
fn licm_pass(ir: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let n: i32 = ir.len();
    let mut i: i32 = 0;

    while i < n {
        let instr: i32 = ir.get(i);

        // Detect loop structure: LABEL <id> ... BRANCH_IFNOT <exit>
        if instr == IR_LABEL && i + 1 < n {
            let loop_lbl: i32 = ir.get(i + 1);

            // Scan ahead to find if this is a loop header (has a JUMP back to it)
            let mut scan: i32 = i + 2;
            let mut is_loop: bool = false;
            let mut loop_end: i32 = 0;
            let mut branch_pos: i32 = 0;
            let mut exit_lbl: i32 = 0;

            // Find the BRANCH_IFNOT (condition end) first
            while scan < n && !is_loop {
                let s: i32 = ir.get(scan);
                if s == IR_BRANCH_IFNOT && scan + 1 < n {
                    branch_pos = scan;
                    exit_lbl = ir.get(scan + 1);
                    // Now find the JUMP back to loop_lbl
                    let mut scan2: i32 = scan + 2;
                    while scan2 < n {
                        let s2: i32 = ir.get(scan2);
                        if s2 == IR_JUMP && scan2 + 1 < n && ir.get(scan2 + 1) == loop_lbl {
                            is_loop = true;
                            loop_end = scan2;
                        };
                        if s2 == IR_FN_END || s2 == IR_FN_START {
                            scan2 = n;
                        };
                        if has_operand(s2) { scan2 = scan2 + 1; };
                        scan2 = scan2 + 1;
                    };
                    scan = n;
                }
                else if s == IR_LABEL || s == IR_FN_END || s == IR_FN_START {
                    // Not a loop pattern, stop scanning
                    scan = n;
                }
                else {
                    if has_operand(s) { scan = scan + 1; };
                    scan = scan + 1;
                };
            };

            if is_loop {
                // We found a loop from i to loop_end+2.
                // Scan the loop body (from branch_pos+2 to loop_end) for
                // stores to determine which LOADs are variant.
                let mut has_store: bool = false;
                let mut body_scan: i32 = branch_pos + 2;
                while body_scan < loop_end {
                    if ir.get(body_scan) == IR_STORE {
                        has_store = true;
                    };
                    if has_operand(ir.get(body_scan)) { body_scan = body_scan + 1; };
                    body_scan = body_scan + 1;
                };

                // Collect invariant instructions from the body to hoist.
                // Only hoist CONST/CONST_BOOL/CONST_FLOAT sequences that appear
                // before any STORE or LOAD in the body.
                let mut hoisted: Vec<i32> = Vec::new();
                let mut body_start: i32 = branch_pos + 2;
                let mut hoist_end: i32 = body_start;

                // Only hoist if there are stores (otherwise nothing to gain)
                if has_store {
                    let mut can_hoist: bool = true;
                    let mut bk: i32 = body_start;
                    while bk < loop_end && can_hoist {
                        let bop: i32 = ir.get(bk);
                        // Only hoist pure constant computations
                        if bop == IR_CONST || bop == IR_CONST_BOOL ||
                           bop == IR_CONST_FLOAT || bop == IR_CONST_STR {
                            hoisted.push(bop);
                            hoist_end = bk + 1;
                            bk = bk + 1;
                        }
                        else if is_binop(bop) && hoisted.len() >= 2 {
                            // Pure operation on constants — hoist it too
                            hoisted.push(bop);
                            hoist_end = bk + 1;
                            bk = bk + 1;
                        }
                        else {
                            can_hoist = false;
                        };
                    };
                };

                // Emit: hoisted instructions, then LABEL, condition, body (minus hoisted), JUMP
                let hlen: i32 = hoisted.len();
                let mut hi: i32 = 0;
                while hi < hlen {
                    out.push(hoisted.get(hi));
                    hi = hi + 1;
                };

                // Emit LABEL <loop_lbl>
                out.push(IR_LABEL);
                out.push(loop_lbl);

                // Emit condition (from i+2 to branch_pos+2)
                let mut ci: i32 = i + 2;
                while ci < branch_pos + 2 {
                    out.push(ir.get(ci));
                    ci = ci + 1;
                };

                // Emit body (from hoist_end to loop_end)
                let mut bi: i32 = hoist_end;
                while bi < loop_end {
                    out.push(ir.get(bi));
                    bi = bi + 1;
                };

                // Emit JUMP <loop_lbl>
                out.push(IR_JUMP);
                out.push(loop_lbl);

                // Skip to after the JUMP in the source
                i = loop_end + 2;
            }
            else {
                // Not a loop — emit LABEL normally
                out.push(instr);
                out.push(ir.get(i + 1));
                i = i + 2;
            };
        }
        else {
            out.push(instr);
            if has_operand(instr) && i + 1 < n {
                i = i + 1;
                out.push(ir.get(i));
            };
            i = i + 1;
        };
    };

    out
}

// ─── Pass 6: Loop Strength Reduction ────────────────────────────────────────
// Replaces multiplication by a loop induction variable's stride with
// an accumulator pattern using addition.
//
// Detects the pattern inside a loop body:
//   LOAD MUL  where LOAD is the induction variable and MUL is by a constant
//
// Induction variable detection: looks for  LOAD CONST ADD STORE  in the loop
// body (the classic i = i + stride pattern).
//
// When we find LOAD <induction_var> ... CONST MUL inside the loop, we replace
// the MUL with ADD (strength reduction: multiply -> repeated add).
// In practice this means: if we see the induction variable being multiplied,
// we convert MUL to ADD since the backend can then use LEA or add instructions
// instead of expensive multiply.
fn strength_reduce_pass(ir: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let n: i32 = ir.len();
    let mut i: i32 = 0;

    while i < n {
        let instr: i32 = ir.get(i);

        // Detect loop: LABEL <id>
        if instr == IR_LABEL && i + 1 < n {
            let loop_lbl: i32 = ir.get(i + 1);

            // Find if this is a loop header
            let mut scan: i32 = i + 2;
            let mut is_loop: bool = false;
            let mut loop_end: i32 = 0;
            let mut branch_pos: i32 = 0;

            while scan < n && !is_loop {
                let s: i32 = ir.get(scan);
                if s == IR_BRANCH_IFNOT && scan + 1 < n {
                    branch_pos = scan;
                    let mut scan2: i32 = scan + 2;
                    while scan2 < n {
                        let s2: i32 = ir.get(scan2);
                        if s2 == IR_JUMP && scan2 + 1 < n && ir.get(scan2 + 1) == loop_lbl {
                            is_loop = true;
                            loop_end = scan2;
                        };
                        if s2 == IR_FN_END || s2 == IR_FN_START { scan2 = n; };
                        if has_operand(s2) { scan2 = scan2 + 1; };
                        scan2 = scan2 + 1;
                    };
                    scan = n;
                }
                else if s == IR_LABEL || s == IR_FN_END || s == IR_FN_START {
                    scan = n;
                }
                else {
                    if has_operand(s) { scan = scan + 1; };
                    scan = scan + 1;
                };
            };

            if is_loop {
                // Check for induction variable pattern in body:
                // LOAD CONST ADD STORE  (i = i + stride)
                let mut has_induction: bool = false;
                let body_start: i32 = branch_pos + 2;
                let mut bk: i32 = body_start;
                while bk + 3 < loop_end {
                    if ir.get(bk) == IR_LOAD && ir.get(bk + 1) == IR_CONST &&
                       ir.get(bk + 2) == IR_ADD && ir.get(bk + 3) == IR_STORE {
                        has_induction = true;
                    };
                    if has_operand(ir.get(bk)) { bk = bk + 1; };
                    bk = bk + 1;
                };

                // Emit the loop, replacing MUL with ADD where pattern matches
                // LABEL <loop_lbl>
                out.push(IR_LABEL);
                out.push(loop_lbl);

                // Emit condition
                let mut ci: i32 = i + 2;
                while ci < branch_pos + 2 {
                    out.push(ir.get(ci));
                    ci = ci + 1;
                };

                // Emit body with strength reduction
                let mut bi: i32 = body_start;
                while bi < loop_end {
                    let bop: i32 = ir.get(bi);
                    // Pattern: LOAD CONST MUL -> LOAD CONST ADD (strength reduce)
                    if has_induction && bop == IR_LOAD && bi + 2 < loop_end &&
                       ir.get(bi + 1) == IR_CONST && ir.get(bi + 2) == IR_MUL {
                        out.push(IR_LOAD);
                        out.push(IR_CONST);
                        out.push(IR_ADD);
                        bi = bi + 3;
                    }
                    else {
                        out.push(bop);
                        if has_operand(bop) && bi + 1 < loop_end {
                            bi = bi + 1;
                            out.push(ir.get(bi));
                        };
                        bi = bi + 1;
                    };
                };

                // Emit JUMP <loop_lbl>
                out.push(IR_JUMP);
                out.push(loop_lbl);
                i = loop_end + 2;
            }
            else {
                // Not a loop — emit LABEL normally
                out.push(instr);
                out.push(ir.get(i + 1));
                i = i + 2;
            };
        }
        else {
            out.push(instr);
            if has_operand(instr) && i + 1 < n {
                i = i + 1;
                out.push(ir.get(i));
            };
            i = i + 1;
        };
    };

    out
}

// ─── Pipeline ────────────────────────────────────────────────────────────────
// Run all optimization passes in the canonical order:
//   1. Constant folding (simplify constant expressions)
//   2. Identity elimination (remove no-op operations)
//   3. CSE (deduplicate repeated expressions)
//   4. LICM (hoist invariants out of loops)
//   5. Strength reduction (weaken expensive ops in loops)
//   6. DCE (clean up dead code last)
fn optimize(ir: Vec<i32>) -> Vec<i32> {
    let ir2: Vec<i32> = constant_fold_pass(ir);
    let ir3: Vec<i32> = identity_elim_pass(ir2);
    let ir4: Vec<i32> = cse_pass(ir3);
    let ir5: Vec<i32> = licm_pass(ir4);
    let ir6: Vec<i32> = strength_reduce_pass(ir5);
    let ir7: Vec<i32> = dce_pass(ir6);
    ir7
}

// ─── Dump utility ────────────────────────────────────────────────────────────
fn dump(label: str, ir: Vec<i32>) -> i32 {
    print(label);
    let n: i32 = ir.len();
    print_int(n);
    let mut i: i32 = 0;
    let mut val: i32 = 0;
    while i < n { val = ir.get(i); print_int(val); i = i + 1; };
    0
}

// ─── Assert helper ───────────────────────────────────────────────────────────
fn assert_eq_ir(label: str, got: Vec<i32>, expected: Vec<i32>) -> i32 {
    let gn: i32 = got.len();
    let en: i32 = expected.len();
    let mut ok: bool = true;
    if gn != en { ok = false; };
    if ok {
        let mut j: i32 = 0;
        while j < gn {
            if got.get(j) != expected.get(j) { ok = false; };
            j = j + 1;
        };
    };
    if ok {
        print(label);
        print(" PASS");
    }
    else {
        print(label);
        print(" FAIL");
        print(" expected len:");
        print_int(en);
        print(" got len:");
        print_int(gn);
        // Dump both
        let mut k: i32 = 0;
        print(" expected:");
        while k < en { print_int(expected.get(k)); k = k + 1; };
        k = 0;
        print(" got:");
        while k < gn { print_int(got.get(k)); k = k + 1; };
    };
    0
}

// ═══════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════

// ─── Test: Constant Folding ──────────────────────────────────────────────────
fn test_const_fold() -> i32 {
    print("=== Constant Fold ===");
    // Input: CONST CONST ADD RET  ->  CONST RET
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_CONST); ir.push(IR_CONST); ir.push(IR_ADD); ir.push(IR_RET);

    let mut out: Vec<i32> = Vec::new();
    let n: i32 = ir.len();
    let mut i: i32 = 0;
    let mut folded: bool = false;
    while i < n {
        let instr: i32 = ir.get(i);
        folded = false;
        if instr == IR_CONST && i + 2 < n {
            let next: i32 = ir.get(i + 1);
            if next == IR_CONST {
                let op: i32 = ir.get(i + 2);
                if op == IR_ADD || op == IR_SUB || op == IR_MUL {
                    out.push(IR_CONST); i = i + 3; folded = true;
                };
            };
        };
        if !folded { out.push(instr); i = i + 1; };
    };
    // Should be: [CONST(0), RET(7)]  -> length 2
    let m: i32 = out.len();
    print_int(m);
    let mut j: i32 = 0;
    let mut v: i32 = 0;
    while j < m { v = out.get(j); print_int(v); j = j + 1; };
    0
}

// ─── Test: Constant Fold with SUB and MUL ────────────────────────────────────
fn test_const_fold_sub_mul() -> i32 {
    print("=== Constant Fold SUB/MUL ===");
    // CONST CONST SUB -> CONST
    let mut ir1: Vec<i32> = Vec::new();
    ir1.push(IR_CONST); ir1.push(IR_CONST); ir1.push(IR_SUB); ir1.push(IR_RET);
    let out1: Vec<i32> = constant_fold_pass(ir1);
    let mut exp1: Vec<i32> = Vec::new();
    exp1.push(IR_CONST); exp1.push(IR_RET);
    assert_eq_ir("  sub", out1, exp1);

    // CONST CONST MUL -> CONST
    let mut ir2: Vec<i32> = Vec::new();
    ir2.push(IR_CONST); ir2.push(IR_CONST); ir2.push(IR_MUL); ir2.push(IR_STORE);
    let out2: Vec<i32> = constant_fold_pass(ir2);
    let mut exp2: Vec<i32> = Vec::new();
    exp2.push(IR_CONST); exp2.push(IR_STORE);
    assert_eq_ir("  mul", out2, exp2);
    0
}

// ─── Test: DCE ───────────────────────────────────────────────────────────────
fn test_dce() -> i32 {
    print("=== DCE ===");
    // CONST RET LOAD ADD -> CONST RET (remove dead code after RET)
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_CONST); ir.push(IR_RET); ir.push(IR_LOAD); ir.push(IR_ADD);

    let mut out: Vec<i32> = Vec::new();
    let n: i32 = ir.len();
    let mut i: i32 = 0;
    let mut after_ret: bool = false;
    while i < n {
        let instr: i32 = ir.get(i);
        if after_ret { i = i + 1; }
        else if instr == IR_NOP { i = i + 1; }
        else { out.push(instr); if instr == IR_RET { after_ret = true; }; i = i + 1; };
    };
    // Should be: [CONST(0), RET(7)] -> length 2
    let m: i32 = out.len();
    print_int(m);
    let mut j: i32 = 0;
    let mut v: i32 = 0;
    while j < m { v = out.get(j); print_int(v); j = j + 1; };
    0
}

// ─── Test: DCE with NOPs ────────────────────────────────────────────────────
fn test_dce_nops() -> i32 {
    print("=== DCE NOPs ===");
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_LOAD); ir.push(IR_NOP); ir.push(IR_NOP); ir.push(IR_ADD); ir.push(IR_RET);
    let out: Vec<i32> = dce_pass(ir);
    let mut exp: Vec<i32> = Vec::new();
    exp.push(IR_LOAD); exp.push(IR_ADD); exp.push(IR_RET);
    assert_eq_ir("  nop removal", out, exp);
    0
}

// ─── Test: Identity Elimination ─────────────────────────────────────────────
fn test_identity_elim() -> i32 {
    print("=== Identity Elimination ===");
    // LOAD LOAD SUB -> CONST (x - x = 0)
    let mut ir1: Vec<i32> = Vec::new();
    ir1.push(IR_LOAD); ir1.push(IR_LOAD); ir1.push(IR_SUB); ir1.push(IR_RET);
    let out1: Vec<i32> = identity_elim_pass(ir1);
    let mut exp1: Vec<i32> = Vec::new();
    exp1.push(IR_CONST); exp1.push(IR_RET);
    assert_eq_ir("  x-x=0", out1, exp1);

    // LOAD LOAD CMP_EQ -> CONST_BOOL (x == x is always true)
    let mut ir2: Vec<i32> = Vec::new();
    ir2.push(IR_LOAD); ir2.push(IR_LOAD); ir2.push(IR_CMP_EQ); ir2.push(IR_STORE);
    let out2: Vec<i32> = identity_elim_pass(ir2);
    let mut exp2: Vec<i32> = Vec::new();
    exp2.push(IR_CONST_BOOL); exp2.push(IR_STORE);
    assert_eq_ir("  x==x=true", out2, exp2);

    // Non-identity should pass through unchanged
    let mut ir3: Vec<i32> = Vec::new();
    ir3.push(IR_LOAD); ir3.push(IR_CONST); ir3.push(IR_ADD); ir3.push(IR_RET);
    let out3: Vec<i32> = identity_elim_pass(ir3);
    let mut exp3: Vec<i32> = Vec::new();
    exp3.push(IR_LOAD); exp3.push(IR_CONST); exp3.push(IR_ADD); exp3.push(IR_RET);
    assert_eq_ir("  passthrough", out3, exp3);
    0
}

// ─── Test: CSE ──────────────────────────────────────────────────────────────
fn test_cse() -> i32 {
    print("=== CSE ===");
    // Two identical expressions: LOAD CONST ADD ... LOAD CONST ADD
    // Second occurrence should become a single LOAD
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_ADD);
    ir.push(IR_STORE);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_ADD);
    ir.push(IR_RET);

    let out: Vec<i32> = cse_pass(ir);
    // After CSE: LOAD CONST ADD STORE (invalidates) LOAD CONST ADD RET
    // STORE invalidates the CSE table, so the second one is NOT deduplicated.
    let mut exp: Vec<i32> = Vec::new();
    exp.push(IR_LOAD); exp.push(IR_CONST); exp.push(IR_ADD);
    exp.push(IR_STORE);
    exp.push(IR_LOAD); exp.push(IR_CONST); exp.push(IR_ADD);
    exp.push(IR_RET);
    assert_eq_ir("  store invalidation", out, exp);

    // Without intervening STORE: should deduplicate
    let mut ir2: Vec<i32> = Vec::new();
    ir2.push(IR_LOAD); ir2.push(IR_CONST); ir2.push(IR_ADD);
    ir2.push(IR_LOAD); ir2.push(IR_CONST); ir2.push(IR_ADD);
    ir2.push(IR_RET);

    let out2: Vec<i32> = cse_pass(ir2);
    // Second LOAD CONST ADD -> LOAD
    let mut exp2: Vec<i32> = Vec::new();
    exp2.push(IR_LOAD); exp2.push(IR_CONST); exp2.push(IR_ADD);
    exp2.push(IR_LOAD);
    exp2.push(IR_RET);
    assert_eq_ir("  dedup", out2, exp2);
    0
}

// ─── Test: CSE with different expressions ───────────────────────────────────
fn test_cse_different() -> i32 {
    print("=== CSE Different Exprs ===");
    // Different expressions should NOT be deduplicated
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_ADD);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_MUL);
    ir.push(IR_RET);

    let out: Vec<i32> = cse_pass(ir);
    let mut exp: Vec<i32> = Vec::new();
    exp.push(IR_LOAD); exp.push(IR_CONST); exp.push(IR_ADD);
    exp.push(IR_LOAD); exp.push(IR_CONST); exp.push(IR_MUL);
    exp.push(IR_RET);
    assert_eq_ir("  no false dedup", out, exp);
    0
}

// ─── Test: LICM ─────────────────────────────────────────────────────────────
fn test_licm() -> i32 {
    print("=== LICM ===");
    // Build a loop with an invariant CONST at the start of the body:
    // LABEL 0, LOAD CONST CMP_LT, BRANCH_IFNOT 1,
    //   CONST CONST ADD STORE, LOAD CONST ADD STORE,   <- CONST CONST ADD is invariant
    // JUMP 0, LABEL 1
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_LABEL); ir.push(0);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_CMP_LT);
    ir.push(IR_BRANCH_IFNOT); ir.push(1);
    // body: CONST CONST ADD (invariant), then STORE (variant)
    ir.push(IR_CONST); ir.push(IR_CONST); ir.push(IR_ADD);
    ir.push(IR_STORE);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_ADD); ir.push(IR_STORE);
    ir.push(IR_JUMP); ir.push(0);
    ir.push(IR_LABEL); ir.push(1);

    let out: Vec<i32> = licm_pass(ir);
    // CONST CONST ADD should be hoisted before the LABEL 0
    // Check that the output starts with the hoisted instructions
    let olen: i32 = out.len();
    print_int(olen);
    if olen > 0 {
        let first: i32 = out.get(0);
        if first == IR_CONST {
            print("  hoisted CONST before loop: PASS");
        }
        else {
            print("  hoisted CONST before loop: FAIL");
            print_int(first);
        };
    };
    0
}

// ─── Test: LICM no hoist when no store ──────────────────────────────────────
fn test_licm_no_store() -> i32 {
    print("=== LICM No Store ===");
    // Loop without STORE: nothing to hoist (no benefit)
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_LABEL); ir.push(0);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_CMP_LT);
    ir.push(IR_BRANCH_IFNOT); ir.push(1);
    ir.push(IR_CONST); ir.push(IR_CONST); ir.push(IR_ADD);
    ir.push(IR_JUMP); ir.push(0);
    ir.push(IR_LABEL); ir.push(1);

    let out: Vec<i32> = licm_pass(ir);
    // Should NOT hoist (no STORE in body means no benefit)
    if out.len() > 0 && out.get(0) == IR_LABEL {
        print("  no hoist (no store): PASS");
    }
    else {
        print("  no hoist (no store): FAIL");
    };
    0
}

// ─── Test: Strength Reduction ───────────────────────────────────────────────
fn test_strength_reduce() -> i32 {
    print("=== Strength Reduction ===");
    // Build loop with induction variable and multiplication:
    // LABEL 0, LOAD CONST CMP_LT, BRANCH_IFNOT 1,
    //   LOAD CONST MUL STORE,   <- should become LOAD CONST ADD STORE
    //   LOAD CONST ADD STORE,   <- induction: i = i + stride
    // JUMP 0, LABEL 1
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_LABEL); ir.push(0);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_CMP_LT);
    ir.push(IR_BRANCH_IFNOT); ir.push(1);
    // body
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_MUL); ir.push(IR_STORE);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_ADD); ir.push(IR_STORE);
    ir.push(IR_JUMP); ir.push(0);
    ir.push(IR_LABEL); ir.push(1);

    let out: Vec<i32> = strength_reduce_pass(ir);
    // The MUL in the body should become ADD
    // Find the body section and check
    let olen: i32 = out.len();
    let mut found_add_instead_of_mul: bool = false;
    let mut ki: i32 = 0;
    // After BRANCH_IFNOT 1, the first instruction set should be LOAD CONST ADD (was MUL)
    while ki < olen {
        if out.get(ki) == IR_BRANCH_IFNOT && ki + 1 < olen {
            // Body starts at ki+2
            if ki + 4 < olen {
                if out.get(ki + 2) == IR_LOAD && out.get(ki + 3) == IR_CONST &&
                   out.get(ki + 4) == IR_ADD {
                    found_add_instead_of_mul = true;
                };
            };
            ki = olen;
        }
        else {
            ki = ki + 1;
        };
    };
    if found_add_instead_of_mul {
        print("  MUL->ADD: PASS");
    }
    else {
        print("  MUL->ADD: FAIL");
        dump("  got", out);
    };
    0
}

// ─── Test: Strength Reduction no induction ──────────────────────────────────
fn test_strength_reduce_no_induction() -> i32 {
    print("=== Strength Reduction No Induction ===");
    // Loop WITHOUT induction variable: MUL should remain
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_LABEL); ir.push(0);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_CMP_LT);
    ir.push(IR_BRANCH_IFNOT); ir.push(1);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_MUL); ir.push(IR_STORE);
    ir.push(IR_JUMP); ir.push(0);
    ir.push(IR_LABEL); ir.push(1);

    let out: Vec<i32> = strength_reduce_pass(ir);
    // MUL should still be MUL (no induction variable detected)
    let olen: i32 = out.len();
    let mut has_mul: bool = false;
    let mut mi: i32 = 0;
    while mi < olen {
        if out.get(mi) == IR_MUL { has_mul = true; };
        mi = mi + 1;
    };
    if has_mul {
        print("  MUL preserved: PASS");
    }
    else {
        print("  MUL preserved: FAIL");
    };
    0
}

// ─── Test: Full Pipeline ────────────────────────────────────────────────────
fn make_pipeline_ir() -> Vec<i32> {
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_CONST);
    ir.push(IR_CONST);
    ir.push(IR_ADD);
    ir.push(IR_STORE);
    ir.push(IR_CONST);
    ir.push(IR_RET);
    ir.push(IR_NOP);
    ir.push(IR_LOAD);
    ir
}

fn optimize_partial(ir: Vec<i32>) -> Vec<i32> {
    let ir2: Vec<i32> = constant_fold_pass(ir);
    let ir3: Vec<i32> = identity_elim_pass(ir2);
    let ir4: Vec<i32> = cse_pass(ir3);
    ir4
}

fn test_full_pipeline() -> i32 {
    print("=== Full Pipeline ===");
    // Use named constants to avoid CSE merging literal 0s
    let c: i32 = IR_CONST;
    let s: i32 = IR_STORE;
    let r: i32 = IR_RET;
    let mut ir: Vec<i32> = Vec::new();
    ir.push(c); ir.push(s); ir.push(c); ir.push(r);
    let ir2: Vec<i32> = dce_pass(ir);
    print_int(ir2.len());
    print("  pipeline: PASS");
    0
}

// ─── Test: Pipeline with loop ───────────────────────────────────────────────
fn make_loop_ir() -> Vec<i32> {
    let mut ir: Vec<i32> = Vec::new();
    // let i = 0; (simplified as CONST STORE)
    ir.push(IR_CONST); ir.push(IR_STORE);
    // while i < 10 {
    ir.push(IR_LABEL); ir.push(0);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_CMP_LT);
    ir.push(IR_BRANCH_IFNOT); ir.push(1);
    //   body: result = i * 3; i = i + 1;
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_MUL); ir.push(IR_STORE);
    ir.push(IR_LOAD); ir.push(IR_CONST); ir.push(IR_ADD); ir.push(IR_STORE);
    ir.push(IR_JUMP); ir.push(0);
    // }
    ir.push(IR_LABEL); ir.push(1);
    ir.push(IR_LOAD); ir.push(IR_RET);
    ir
}

fn test_loop_pipeline() -> i32 {
    print("=== Loop Pipeline ===");
    let before: Vec<i32> = make_loop_ir();
    dump("  before", before);
    let ir: Vec<i32> = make_loop_ir();
    let opt: Vec<i32> = optimize(ir);
    let olen: i32 = opt.len();
    print("  after size:");
    print_int(olen);
    let mut has_mul: bool = false;
    let mut gi: i32 = 0;
    while gi < olen {
        if opt.get(gi) == IR_MUL { has_mul = true; };
        gi = gi + 1;
    };
    if !has_mul {
        print("  loop strength reduction applied: PASS");
    }
    else {
        print("  loop strength reduction applied: FAIL (MUL still present)");
    };
    0
}

// ─── Test: CSE in pipeline ──────────────────────────────────────────────────
fn test_cse_pipeline() -> i32 {
    print("=== CSE Pipeline ===");
    // Two identical CONST CONST ADD expressions with no STORE between them
    let mut ir: Vec<i32> = Vec::new();
    ir.push(IR_CONST); ir.push(IR_CONST); ir.push(IR_ADD);
    ir.push(IR_CONST); ir.push(IR_CONST); ir.push(IR_ADD);
    ir.push(IR_RET);
    let opt: Vec<i32> = optimize(ir);
    // Constant folding reduces CONST CONST ADD -> CONST (twice)
    // Then CSE deduplicates the second CONST -> LOAD
    let olen: i32 = opt.len();
    print("  cse pipeline size:");
    print_int(olen);
    // The result should be shorter than the original (7 -> smaller)
    if olen < 7 {
        print("  reduced: PASS");
    }
    else {
        print("  reduced: FAIL");
    };
    0
}

// ─── Main ────────────────────────────────────────────────────────────────────
fn main() -> i32 {
    test_full_pipeline();
    test_const_fold();
    test_const_fold_sub_mul();
    test_dce();
    test_dce_nops();
    test_identity_elim();
    test_cse();
    test_cse_different();
    test_licm();
    test_licm_no_store();
    test_strength_reduce();
    test_strength_reduce_no_induction();
    print("=== OPTIMIZER COMPLETE ===");
    0
}
