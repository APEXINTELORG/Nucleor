// =====================================================
// OPTIMIZER PASSES (S6)
// =====================================================

// --- Constant map: tracks register -> constant value ---
// --- Pass 1: Constant Folding ---
// Scans instructions in a block. When both operands of an arithmetic/comparison
// op are known constants, replaces the instruction with a const_int.

// --- Pass 2: Dead Code Elimination ---
// Removes instructions whose dest register is never used by any later instruction.
// Side-effecting ops (store, call, ret, br, br_cond, alloca) are never removed.
// Ownership transfer: same pattern as compiler.nr.

// --- Pass 3: Store-Load Constant Propagation ---
// Propagates known constants through store/load chains within a block.
// If a constant is stored to a slot and later loaded, replaces the load with const_int.

// --- Pass 4: Dead Store Elimination ---
// Removes stores that are overwritten before being read within the same block.
// Ownership transfer: same pattern as opt_dce_block.

// --- Pass 5: Common Subexpression Elimination ---
// Deduplicates identical pure computations within a block.
// When a duplicate is found, rewrites all uses of its dest to the original dest.
// Ownership transfer: same pattern as opt_dce_block.
#[manual_drop]
// --- Pass 6: Block Merging ---
// Merges blocks: if a block ends with unconditional br to a target that has
// exactly one predecessor, inline the target's instructions and remove the branch.
// Ownership transfer: vec_set on `f` likely stores
// merged block lists. Same pattern as opt_dce_block.
#[manual_drop]
fn opt_merge_blocks(f: Vec<i32>) -> i64 {
    let blocks: Vec<i32> = vec_get(f, 3);
    let bc: i64 = vec_len(blocks);
    if bc <= 1 { return 0; };
    // Count predecessors for each label
    let mut pred_cnt: Vec<i32> = cmap_new();
    let mut bi: i64 = 0;
    while bi < bc {
        let blk: Vec<i32> = vec_get(blocks, bi);
        let ic: i64 = ir_block_inst_count(blk);
        if ic > 0 {
            let last: Vec<i32> = ir_block_get_inst(blk, ic - 1);
            let lop: i64 = ir_op(last);
            if lop == 21 {
                let tgt: i64 = ir_op1(last);
                let mut cur: i64 = 0;
                if cmap_has(pred_cnt, tgt) == 1 { cur = cmap_get(pred_cnt, tgt); };
                cmap_set(pred_cnt, tgt, cur + 1);
            } else if lop == 22 {
                let tgt_t: i64 = ir_op2(last);
                let tgt_f: i64 = ir_extra(last);
                let mut ct: i64 = 0;
                if cmap_has(pred_cnt, tgt_t) == 1 { ct = cmap_get(pred_cnt, tgt_t); };
                cmap_set(pred_cnt, tgt_t, ct + 1);
                let mut cf: i64 = 0;
                if cmap_has(pred_cnt, tgt_f) == 1 { cf = cmap_get(pred_cnt, tgt_f); };
                cmap_set(pred_cnt, tgt_f, cf + 1);
            };
        };
        bi = bi + 1;
    };
    // Merge eligible blocks
    let mut merged: i64 = 0;
    let mut skip_lbl: Vec<i32> = Vec::new();
    bi = 0;
    while bi < bc {
        let blk: Vec<i32> = vec_get(blocks, bi);
        let ic: i64 = ir_block_inst_count(blk);
        if ic > 0 {
            let last: Vec<i32> = ir_block_get_inst(blk, ic - 1);
            if ir_op(last) == 21 {
                let tgt: i64 = ir_op1(last);
                let mut pc: i64 = 0;
                if cmap_has(pred_cnt, tgt) == 1 { pc = cmap_get(pred_cnt, tgt); };
                if pc == 1 {
                    // Find target block
                    let mut ti: i64 = 0;
                    while ti < bc {
                        let tblk: Vec<i32> = vec_get(blocks, ti);
                        if ir_block_label(tblk) == tgt {
                            // Merge: remove br, append target's instructions
                            let cur_insts: Vec<i32> = vec_get(blk, 1);
                            let mut new_insts: Vec<i32> = Vec::new();
                            let mut ni: i64 = 0;
                            while ni < ic - 1 { new_insts.push(vec_get(cur_insts, ni)); ni = ni + 1; };
                            let tic: i64 = ir_block_inst_count(tblk);
                            let tinsts: Vec<i32> = vec_get(tblk, 1);
                            ni = 0;
                            while ni < tic { new_insts.push(vec_get(tinsts, ni)); ni = ni + 1; };
                            vec_set(blk, 1, new_insts);
                            skip_lbl.push(tgt);
                            merged = merged + 1;
                            ti = bc;
                        };
                        ti = ti + 1;
                    };
                };
            };
        };
        bi = bi + 1;
    };
    // Rebuild blocks list excluding merged-away blocks
    if merged > 0 {
        let mut new_blocks: Vec<i32> = Vec::new();
        bi = 0;
        while bi < bc {
            let blk: Vec<i32> = vec_get(blocks, bi);
            let lbl: i64 = ir_block_label(blk);
            let mut should_skip: i64 = 0;
            let slc: i64 = vec_len(skip_lbl);
            let mut si: i64 = 0;
            while si < slc {
                if vec_get(skip_lbl, si) == lbl { should_skip = 1; si = slc; };
                si = si + 1;
            };
            if should_skip == 0 { new_blocks.push(blk); };
            bi = bi + 1;
        };
        vec_set(f, 3, new_blocks);
    };
    return merged;
}

// --- Optimizer driver: runs all passes on an entire function ---

