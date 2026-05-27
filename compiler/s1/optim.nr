// =====================================================
// OPTIMIZER PASSES (S6)
// =====================================================

// --- Constant map: tracks register -> constant value ---
#[manual_drop]
fn cmap_new() -> Vec<i32> { let mut m: Vec<i32> = Vec::new(); return m; }
#[manual_drop]
fn cmap_set(m: Vec<i32>, reg: i64, val: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { vec_set(m, i + 1, val); return 0; };
        i = i + 2;
    };
    m.push(reg); m.push(val); return 0;
}
#[manual_drop]
fn cmap_get(m: Vec<i32>, reg: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { return vec_get(m, i + 1); };
        i = i + 2;
    };
    return 0 - 9999999;
}
#[manual_drop]
fn cmap_has(m: Vec<i32>, reg: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { return 1; };
        i = i + 2;
    };
    return 0;
}

// --- Pass 1: Constant Folding ---
// Scans instructions in a block. When both operands of an arithmetic/comparison
// op are known constants, replaces the instruction with a const_int.
#[manual_drop]
fn opt_fold_block(blk: Vec<i32>) -> i64 {
    let mut cm: Vec<i32> = cmap_new();
    let ic: i64 = ir_block_inst_count(blk);
    let insts: Vec<i32> = vec_get(blk, 1);
    let mut folded: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        // Track const_int values
        if op == 0 {
            cmap_set(cm, d, ir_op1(inst));
        }
        // Fold arithmetic: add(2), sub(3), mul(4), div(5), mod(6).
        // div/mod by zero must NOT fold. Pre-v0.3.145, the
        // `else { i = i + 1; }` branch on `vb == 0` pre-incremented `i`
        // (so the outer `i = i + 1` at the bottom of the loop skipped
        // the next instruction entirely) AND fell through to the
        // vec_set lines that replaced the divide with `const_int 0`.
        // Two compounding bugs: (a) silent miscompute — `100 / 0` became
        // const 0 instead of trapping at runtime, (b) the very next
        // IR instruction silently disappeared from the block. Adopters
        // who wrote any literal `x / 0` (typically as a deliberate
        // panic test or a bug introduced during refactoring) saw the
        // program return 0 and silently skip whatever statement
        // followed.
        // Fix: when divisor is zero, skip the fold entirely (leave the
        // div/mod instruction in place — at runtime LLVM `sdiv i64 X, 0`
        // is undefined behavior, typically SIGFPE, which is a loud
        // failure the adopter actually sees). Do NOT touch `i`.
        else if op >= 2 && op <= 6 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut do_fold: i64 = 1;
                let mut result: i64 = 0;
                // use wrapping_* in the fold so the
                // compiler's own constant-folding pass doesn't
                // panic when both operands are known and the
                // result overflows. Strict-mode runtime emit will
                // still panic at runtime; the fold matches that
                // bit-pattern (so folded == unfolded for any
                // computable constant pair).
                if op == 2 { result = wrapping_add(va, vb); }
                else if op == 3 { result = wrapping_sub(va, vb); }
                else if op == 4 { result = wrapping_mul(va, vb); }
                else if op == 5 {
                    if vb != 0 { result = va / vb; } else { do_fold = 0; };
                }
                else if op == 6 {
                    if vb != 0 { result = va - (va / vb) * vb; } else { do_fold = 0; };
                };
                if do_fold == 1 {
                    vec_set(inst, 0, 0);
                    vec_set(inst, 3, result);
                    vec_set(inst, 4, 0);
                    vec_set(inst, 5, 0);
                    cmap_set(cm, d, result);
                    folded = folded + 1;
                };
            };
        }
        // Fold comparisons: eq(7), ne(8), slt(9), sgt(10), sle(11), sge(12)
        else if op >= 7 && op <= 12 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut result: i64 = 0;
                if op == 7 { if va == vb { result = 1; }; }
                else if op == 8 { if va != vb { result = 1; }; }
                else if op == 9 { if va < vb { result = 1; }; }
                else if op == 10 { if va > vb { result = 1; }; }
                else if op == 11 { if va <= vb { result = 1; }; }
                else if op == 12 { if va >= vb { result = 1; }; };
                vec_set(inst, 0, 0);
                vec_set(inst, 3, result);
                vec_set(inst, 4, 0);
                vec_set(inst, 5, 0);
                cmap_set(cm, d, result);
                folded = folded + 1;
            };
        }
        // Lane 1 audit fix (2026-05-08) — close C-001 / C-007. Unsigned
        // compare iops 38..41 fold using the sign-bit-flip trick so the
        // i64 cmap entries are ordered as unsigned. Pre-fix this branch
        // didn't exist and the compiler's own const-fold path skipped
        // unsigned comparisons (the lowering site would still have
        // emitted the right runtime IR, but constant-folded comparisons
        // with one or both u64 high-bit operands silently fell back to
        // the signed-compare branch above, which gave the WRONG fold
        // result and so the wrong dead-code-elimination decision later).
        else if op >= 38 && op <= 41 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                // XOR with i64::MIN reorders the signed range so signed
                // compare matches unsigned compare. va_u = va XOR (1<<63);
                // since `^` is a bitwise op already wired through iop 15
                // at lower-time but we don't have the helper here at
                // const-fold time, simulate via wrapping_add — same effect
                // for the sign bit: adding 2^63 (== i64::MIN as a signed
                // value, or via wrapping) flips the high bit.
                let msb_v0508: i64 = const_i64_min();
                let va_u: i64 = wrapping_add(va, msb_v0508);
                let vb_u: i64 = wrapping_add(vb, msb_v0508);
                let mut result: i64 = 0;
                if op == 38 { if va_u < vb_u { result = 1; }; }
                else if op == 39 { if va_u > vb_u { result = 1; }; }
                else if op == 40 { if va_u <= vb_u { result = 1; }; }
                else if op == 41 { if va_u >= vb_u { result = 1; }; };
                vec_set(inst, 0, 0);
                vec_set(inst, 3, result);
                vec_set(inst, 4, 0);
                vec_set(inst, 5, 0);
                cmap_set(cm, d, result);
                folded = folded + 1;
            };
        }
        // Fold bitwise: and(13), or(14), xor(15). Pre-v0.3.103
        // ops 13/14 were folded with LOGICAL semantics (`va != 0 && vb != 0`
        // → 1 or 0), which matched the historical interpretation of
        // these iops as `&&`/`||`. But the runtime LLVM emit for these
        // iops is `and i64`/`or i64` — pure bitwise — so the const-fold
        // was diverging from what the un-folded code would compute. With
        // bitwise `&` `|` `^` now wired through these iops too, fold
        // bitwise so both paths produce identical answers for constant
        // inputs (e.g. 255 & 15 → 15, not 1 from "both truthy").
        // Fold bitwise: and(13), or(14), xor(15).
        // fold through the same bitwise
        // operators that lowering emits. The old self-host emulation used
        // division-based LSB extraction and had to skip negative operands;
        // that kept runtime results correct but left the fold path
        // untested for all-ones sentinels and high-bit masks.
        else if op == 13 || op == 14 || op == 15 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut result: i64 = 0;
                if op == 13 { result = va & vb; }
                else if op == 14 { result = va | vb; }
                else { result = va ^ vb; };
                vec_set(inst, 0, 0);
                vec_set(inst, 3, result);
                vec_set(inst, 4, 0);
                vec_set(inst, 5, 0);
                cmap_set(cm, d, result);
                folded = folded + 1;
            };
        };
        i = i + 1;
    };
    return folded;
}

// --- Pass 2: Dead Code Elimination ---
// Removes instructions whose dest register is never used by any later instruction.
// Side-effecting ops (store, call, ret, br, br_cond, alloca) are never removed.
// Ownership transfer: `new_insts` is stored INTO
// `blk` via `vec_set(blk, 1, new_insts)`. Default-flip auto-drop
// would dangle blk's instruction pointer.
#[manual_drop]
fn opt_dce_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic == 0 { return 0; };
    let last_op: i64 = ir_op(vec_get(insts, ic - 1));
    // This pass is block-local only. Once a block branches, its pure values may
    // still be consumed in successor blocks, so intra-block liveness is unsafe.
    if last_op == 21 || last_op == 22 { return 0; };
    // Build used-register set: scan all instructions for operand references
    let mut used: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        // Collect register operands that are used
        if op >= 2 && op <= 15 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 23 || op == 24 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        // Overflow-intrinsic arithmetic is side-effecting from the optimizer's
        // point of view because it emits a flag branch plus panic path.
        else if op == 35 || op == 36 || op == 37 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 17 { used.push(ir_op1(inst)); }
        else if op == 18 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        // sext/zext/trunc ops use ir_op1 as source register.
        // Pre-fix DCE missed this and removed the source load when its
        // only consumer was a sext/zext, breaking typed-IR var-ref reads.
        else if op == 32 || op == 33 || op == 34 { used.push(ir_op1(inst)); }
        else if op == 20 { used.push(ir_op1(inst)); }
        else if op == 22 { used.push(ir_op1(inst)); }
        else if op == 28 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); used.push(ir_extra(inst)); }
        else if op == 30 { used.push(ir_op1(inst)); let cargs: Vec<i32> = vec_get(inst, 5); let mut ci: i64 = 0; while ci < vec_len(cargs) { used.push(vec_get(cargs, ci)); ci = ci + 1; }; }
        else if op == 19 || op == 31 {
            // Call: args are in the args Vec (index 5)
            let args: Vec<i32> = vec_get(inst, 5);
            let ac: i64 = vec_len(args);
            let mut ai: i64 = 0;
            while ai < ac { used.push(vec_get(args, ai)); ai = ai + 1; };
        };
        i = i + 1;
    };
    // Now remove dead instructions (rebuild insts list)
    let mut new_insts: Vec<i32> = Vec::new();
    let mut removed: i64 = 0;
    i = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        let mut keep: i64 = 1;
        // Only consider removing pure value-producing ops
        if op == 0 || (op >= 2 && op <= 15) || op == 17 || op == 23 || op == 24 || op == 26 || op == 27 || op == 28 || op == 29 || op == 32 || op == 33 || op == 34 {
            if d > 0 {
                // Check if d is in used set
                let mut found: i64 = 0;
                let uc: i64 = vec_len(used);
                let mut ui: i64 = 0;
                while ui < uc {
                    if vec_get(used, ui) == d { found = 1; ui = uc; };
                    ui = ui + 1;
                };
                if found == 0 { keep = 0; };
            };
        };
        if keep == 1 { new_insts.push(inst); }
        else { removed = removed + 1; };
        i = i + 1;
    };
    // Replace instruction list
    if removed > 0 { vec_set(blk, 1, new_insts); };
    return removed;
}

// --- Pass 3: Store-Load Constant Propagation ---
// Propagates known constants through store/load chains within a block.
// If a constant is stored to a slot and later loaded, replaces the load with const_int.
#[manual_drop]
fn opt_prop_block(blk: Vec<i32>) -> i64 {
    let mut cm: Vec<i32> = cmap_new();
    let mut sv: Vec<i32> = cmap_new();
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        if op == 0 { cmap_set(cm, d, ir_op1(inst)); }
        else if op == 18 {
            let val: i64 = ir_op1(inst);
            let ptr: i64 = ir_op2(inst);
            if cmap_has(cm, val) == 1 { cmap_set(sv, ptr, cmap_get(cm, val)); }
            else { cmap_set(sv, ptr, 0 - 9999999); };
        }
        else if op == 17 {
            let ptr: i64 = ir_op1(inst);
            if cmap_has(sv, ptr) == 1 {
                let cv: i64 = cmap_get(sv, ptr);
                if cv != 0 - 9999999 {
                    vec_set(inst, 0, 0);
                    vec_set(inst, 3, cv);
                    vec_set(inst, 4, 0);
                    vec_set(inst, 5, 0);
                    cmap_set(cm, d, cv);
                    count = count + 1;
                };
            };
        }
        else if op == 19 || op == 30 || op == 31 { sv = cmap_new(); };
        i = i + 1;
    };
    return count;
}

// --- Pass 4: Dead Store Elimination ---
// Removes stores that are overwritten before being read within the same block.
// Ownership transfer: same pattern as opt_dce_block.
#[manual_drop]
fn opt_dead_store_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic == 0 { return 0; };
    let mut last_store: Vec<i32> = cmap_new();
    let mut dead: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        if op == 18 {
            let ptr: i64 = ir_op2(inst);
            if cmap_has(last_store, ptr) == 1 {
                let prev_idx: i64 = cmap_get(last_store, ptr);
                if prev_idx >= 0 { dead.push(prev_idx); };
            };
            cmap_set(last_store, ptr, i);
        }
        else if op == 17 {
            let ptr: i64 = ir_op1(inst);
            cmap_set(last_store, ptr, 0 - 1);
        }
        else if op == 19 || op == 20 || op == 21 || op == 22 || op == 30 || op == 31 {
            last_store = cmap_new();
        };
        i = i + 1;
    };
    if vec_len(dead) == 0 { return 0; };
    let mut new_insts: Vec<i32> = Vec::new();
    let mut removed: i64 = 0;
    i = 0;
    while i < ic {
        let mut is_dead: i64 = 0;
        let dc: i64 = vec_len(dead);
        let mut di: i64 = 0;
        while di < dc {
            if vec_get(dead, di) == i { is_dead = 1; di = dc; };
            di = di + 1;
        };
        if is_dead == 0 { new_insts.push(vec_get(insts, i)); }
        else { removed = removed + 1; };
        i = i + 1;
    };
    if removed > 0 { vec_set(blk, 1, new_insts); };
    return removed;
}

// --- Pass 5: Common Subexpression Elimination ---
// Deduplicates identical pure computations within a block.
// When a duplicate is found, rewrites all uses of its dest to the original dest.
// Ownership transfer: same pattern as opt_dce_block.
#[manual_drop]
fn opt_cse_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic < 2 { return 0; };
    let mut seen_op: Vec<i32> = Vec::new();
    let mut seen_o1: Vec<i32> = Vec::new();
    let mut seen_o2: Vec<i32> = Vec::new();
    let mut seen_dst: Vec<i32> = Vec::new();
    let mut rewrites: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        let o1: i64 = ir_op1(inst);
        let o2: i64 = ir_op2(inst);
        if op == 0 || (op >= 2 && op <= 14) || op == 27 {
            let sc: i64 = vec_len(seen_op);
            let mut found: i64 = 0 - 1;
            let mut si: i64 = 0;
            while si < sc {
                if vec_get(seen_op, si) == op && vec_get(seen_o1, si) == o1 && vec_get(seen_o2, si) == o2 {
                    found = vec_get(seen_dst, si); si = sc;
                };
                si = si + 1;
            };
            if found >= 0 {
                // Rewrite all forward uses of d to found (opcode-aware)
                let mut j: i64 = i + 1;
                while j < ic {
                    let jinst: Vec<i32> = vec_get(insts, j);
                    let jop: i64 = ir_op(jinst);
                    if jop == 19 {
                        let args: Vec<i32> = vec_get(jinst, 5);
                        let ac: i64 = vec_len(args);
                        let mut ai: i64 = 0;
                        while ai < ac {
                            if vec_get(args, ai) == d { vec_set(args, ai, found); };
                            ai = ai + 1;
                        };
                    }
                    else if jop >= 2 && jop <= 14 {
                        // arithmetic/cmp/logic: op1 and op2 are registers
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                    }
                    else if jop == 17 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 18 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                    }
                    else if jop == 20 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 22 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 28 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                        if ir_extra(jinst) == d { vec_set(jinst, 5, found); };
                    }
                    else if jop == 30 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        let jargs: Vec<i32> = vec_get(jinst, 5);
                        let jac: i64 = vec_len(jargs);
                        let mut jai: i64 = 0;
                        while jai < jac {
                            if vec_get(jargs, jai) == d { vec_set(jargs, jai, found); };
                            jai = jai + 1;
                        };
                    };
                    // ops 0, 16, 21, 26, 27, 29: no register operands to rewrite
                    j = j + 1;
                };
                rewrites = rewrites + 1;
            } else {
                seen_op.push(op); seen_o1.push(o1); seen_o2.push(o2); seen_dst.push(d);
            };
        };
        i = i + 1;
    };
    return rewrites;
}

// R14-D2 Phase 1 (v0.8.265) — metadata-only law-rewrite pass (no-op).
// Algebraic-law canonicalization:
// the optimizer must have a slot for law-aware rewrites that ONLY
// fires under a proof flag. Phase 1 ships the pass-list slot as a
// no-op; Phase 2 wires law metadata (stored at @law lex-capture +
// AST node attachment) into the body so the pass actually
// reassociates / commutes per a verified law.
// Acceptance criteria (this Phase 1):
//   - the pass exists in opt_fn's pass list (observable scaffold);
//   - returns 0 rewrites (no-op — matches "implement metadata-only
//     no-op pass" from build plan §1 R14-D2 ship sequence);
//   - "false law never triggers rewrite" trivially holds because
//     no law triggers any rewrite yet.
// Phase 2 will: (1) consume law metadata from a side table populated
// at lex/parse time; (2) gate behind a proof flag (e.g. property-test
// passed) so unverified laws can't drive unsound rewrites; (3) enable
// one identity rewrite (`f(a, identity) → a`) as the first concrete
// optimization.
// Rollback: replace opt_fn's call to opt_law_rewrite_block with a
// no-op (0) and keep this fn definition in place for future phases.

// Explicit phase-2 proof sentinel. Future
// rewrite logic in `opt_law_rewrite_block` MUST consult this before
// applying any law metadata. Phase 1 returns 0 unconditionally so the
// no-op contract is locked at the IR level too — even if a Phase-2
// contributor adds rewrite logic without consulting the source-text
// `@audit(law_opt_required)` + `@audit(check_laws_passed)` predicate
// pair, this sentinel keeps the rewrite from firing. Phase 2 wires
// this to consult per-fn validation metadata produced by
// `nuc test --check-laws`.
// `fn_law_id` is reserved for Phase 2 use; today no metadata is
// plumbed in, so the parameter is unused. Keeping it in the signature
// now means Phase 2 doesn't need to update every call site.
#[manual_drop]
fn law_opt_phase2_proof_validated(fn_law_id: i64) -> i64 {
    return 0;
}

#[manual_drop]
fn opt_law_rewrite_block(blk: Vec<i32>) -> i64 {
    // Explicit IR-level fail-closed guard.
    // Even though the body below is empty, future Phase 2 logic must
    // pass through this guard. Until `law_opt_phase2_proof_validated`
    // returns 1, no rewrites fire.
    if law_opt_phase2_proof_validated(0) == 0 { return 0; };
    // Phase 1: observe-only pass slot. No metadata to consume yet,
    // so no rewrites fire. Phase 2 populates the body BELOW this
    // guard (never above it).
    return 0;
}

// --- Optimizer driver: runs all passes on an entire function ---
#[manual_drop]
fn opt_fn(f: Vec<i32>) -> i64 {
    let mut total: i64 = 0;
    let mut bi: i64 = 0;
    // Iteration 1: fold → prop → fold → CSE → dead store → DCE → law (no-op Phase 1)
    let mut bc: i64 = ir_fn_block_count(f);
    bi = 0;
    while bi < bc {
        let blk: Vec<i32> = ir_fn_get_block(f, bi);
        total = total + opt_fold_block(blk);
        total = total + opt_prop_block(blk);
        total = total + opt_fold_block(blk);
        total = total + opt_cse_block(blk);
        total = total + opt_dead_store_block(blk);
        total = total + opt_dce_block(blk);
        total = total + opt_law_rewrite_block(blk);
        bi = bi + 1;
    };
    // Block merging disabled — predecessor counting doesn't account for
    // new predecessors created when a merged block's terminator branches elsewhere.
    // Iteration 2: re-run per-block passes on merged blocks
    bc = ir_fn_block_count(f);
    bi = 0;
    while bi < bc {
        let blk: Vec<i32> = ir_fn_get_block(f, bi);
        total = total + opt_fold_block(blk);
        total = total + opt_prop_block(blk);
        total = total + opt_fold_block(blk);
        total = total + opt_dead_store_block(blk);
        total = total + opt_dce_block(blk);
        total = total + opt_law_rewrite_block(blk);
        bi = bi + 1;
    };
    return total;
}

