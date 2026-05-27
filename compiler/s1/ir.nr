// =====================================================
// IR DATA STRUCTURES (from T29, extended)
// =====================================================
#[manual_drop]
fn ir_inst(op: i64, d: i64, tid: i64, o1: i64, o2: i64, ex: i64) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6); ii.push(op); ii.push(d); ii.push(tid); ii.push(o1); ii.push(o2); ii.push(ex); return ii;
}
#[manual_drop]
fn ir_op(ii: Vec<i32>) -> i64 { return vec_get(ii, 0); }
#[manual_drop]
fn ir_dest(ii: Vec<i32>) -> i64 { return vec_get(ii, 1); }
// slot 2 is a width tag for IR ops that
// reference a typed memory slot (alloca/load/store). 0 = "i64" default
// (current behavior); 8/16/32 select narrower LLVM types. Other ops
// leave the slot 0; emit dispatch only consults it for ops 16/17/18.
#[manual_drop]
fn ir_tid(ii: Vec<i32>) -> i64 { return vec_get(ii, 2); }
#[manual_drop]
fn ir_op1(ii: Vec<i32>) -> i64 { return vec_get(ii, 3); }
#[manual_drop]
fn ir_op2(ii: Vec<i32>) -> i64 { return vec_get(ii, 4); }
#[manual_drop]
fn ir_extra(ii: Vec<i32>) -> i64 { return vec_get(ii, 5); }

// width → LLVM integer type. Default 0
// means "no explicit width" → i64 (matches all pre-phase-3 emits).
#[manual_drop]
fn width_to_llvm_type(w: i64) -> str {
    if w == 8  { return "i8"; };
    if w == 16 { return "i16"; };
    if w == 32 { return "i32"; };
    if w == 1  { return "i1"; };
    return "i64";
}

#[manual_drop]
fn is_atomic_ordered_builtin(name: str) -> i64 {
    if str_starts_with(name, "atomic_i64_load_") == 1 {
        if str_ends_with(name, "_relaxed") == 1 || str_ends_with(name, "_acquire") == 1 || str_ends_with(name, "_seqcst") == 1 { return 1; };
        return 0;
    };
    if str_starts_with(name, "atomic_i64_store_") == 1 {
        if str_ends_with(name, "_relaxed") == 1 || str_ends_with(name, "_release") == 1 || str_ends_with(name, "_seqcst") == 1 { return 1; };
        return 0;
    };
    let mut fetch_family: i64 = 0;
    if str_starts_with(name, "atomic_i64_fetch_add_") == 1 { fetch_family = 1; };
    if str_starts_with(name, "atomic_i64_fetch_sub_") == 1 { fetch_family = 1; };
    if str_starts_with(name, "atomic_i64_fetch_and_") == 1 { fetch_family = 1; };
    if str_starts_with(name, "atomic_i64_fetch_or_") == 1 { fetch_family = 1; };
    if str_starts_with(name, "atomic_i64_fetch_xor_") == 1 { fetch_family = 1; };
    if fetch_family == 1 {
        if str_ends_with(name, "_relaxed") == 1 || str_ends_with(name, "_acquire") == 1 || str_ends_with(name, "_release") == 1 || str_ends_with(name, "_acqrel") == 1 || str_ends_with(name, "_seqcst") == 1 { return 1; };
        return 0;
    };
    if str_starts_with(name, "atomic_i64_swap_") == 1 {
        if str_ends_with(name, "_relaxed") == 1 || str_ends_with(name, "_acquire") == 1 || str_ends_with(name, "_release") == 1 || str_ends_with(name, "_acqrel") == 1 || str_ends_with(name, "_seqcst") == 1 { return 1; };
        return 0;
    };
    if str_starts_with(name, "atomic_i64_compare_exchange_") == 1 {
        if str_ends_with(name, "_relaxed_relaxed") == 1 { return 1; };
        if str_ends_with(name, "_acquire_relaxed") == 1 || str_ends_with(name, "_acquire_acquire") == 1 { return 1; };
        if str_ends_with(name, "_release_relaxed") == 1 { return 1; };
        if str_ends_with(name, "_acqrel_relaxed") == 1 || str_ends_with(name, "_acqrel_acquire") == 1 { return 1; };
        if str_ends_with(name, "_seqcst_relaxed") == 1 || str_ends_with(name, "_seqcst_acquire") == 1 || str_ends_with(name, "_seqcst_seqcst") == 1 { return 1; };
        return 0;
    };
    return 0;
}

#[manual_drop]
fn atomic_tail_order_llvm(name: str) -> str {
    if str_contains(name, "_seqcst") == 1 { return "seq_cst"; };
    if str_contains(name, "_acqrel") == 1 { return "acq_rel"; };
    if str_contains(name, "_release") == 1 { return "release"; };
    if str_contains(name, "_acquire") == 1 { return "acquire"; };
    return "monotonic";
}

#[manual_drop]
fn atomic_cmpxchg_success_order_llvm(name: str) -> str {
    if str_contains(name, "compare_exchange_seqcst_") == 1 { return "seq_cst"; };
    if str_contains(name, "compare_exchange_acqrel_") == 1 { return "acq_rel"; };
    if str_contains(name, "compare_exchange_release_") == 1 { return "release"; };
    if str_contains(name, "compare_exchange_acquire_") == 1 { return "acquire"; };
    return "monotonic";
}

#[manual_drop]
fn atomic_cmpxchg_failure_order_llvm(name: str) -> str {
    if str_contains(name, "_seqcst_seqcst") == 1 { return "seq_cst"; };
    if str_contains(name, "_acquire_acquire") == 1 { return "acquire"; };
    if str_contains(name, "_acqrel_acquire") == 1 { return "acquire"; };
    if str_contains(name, "_seqcst_acquire") == 1 { return "acquire"; };
    return "monotonic";
}

#[manual_drop]
fn atomic_rmw_op_llvm(name: str) -> str {
    // Order matters: check `swap` before the fetch_* family. The new
    // ordered helper `atomic_i64_swap_<order>` lowers to `atomicrmw
    // xchg`. Default fall-through is `add` for fetch_add (no infix).
    if str_contains(name, "_swap_") == 1 { return "xchg"; };
    if str_contains(name, "fetch_sub") == 1 { return "sub"; };
    if str_contains(name, "fetch_and") == 1 { return "and"; };
    if str_contains(name, "fetch_or") == 1 { return "or"; };
    if str_contains(name, "fetch_xor") == 1 { return "xor"; };
    return "add";
}

#[manual_drop]
fn emit_atomic_ordered_call(sb: i64, name: str, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let ds: str = str_from_int(d);
    if argc <= 0 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
        return 0;
    };
    sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".atomic.ptr = inttoptr i64 %r.");
    sb_append(sb, str_from_int(vec_get(args, 0))); sb_append(sb, " to ptr\n");
    if str_starts_with(name, "atomic_i64_load_") == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = load atomic i64, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".atomic.ptr "); sb_append(sb, atomic_tail_order_llvm(name));
        sb_append(sb, ", align 8\n");
        return 0;
    };
    if str_starts_with(name, "atomic_i64_store_") == 1 {
        if argc > 1 {
            sb_append(sb, "  store atomic i64 %r."); sb_append(sb, str_from_int(vec_get(args, 1)));
            sb_append(sb, ", ptr %r."); sb_append(sb, ds); sb_append(sb, ".atomic.ptr ");
            sb_append(sb, atomic_tail_order_llvm(name)); sb_append(sb, ", align 8\n");
        };
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
        return 0;
    };
    if str_starts_with(name, "atomic_i64_compare_exchange_") == 1 {
        if argc >= 3 {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".atomic.pair = cmpxchg ptr %r.");
            sb_append(sb, ds); sb_append(sb, ".atomic.ptr, i64 %r.");
            sb_append(sb, str_from_int(vec_get(args, 1))); sb_append(sb, ", i64 %r.");
            sb_append(sb, str_from_int(vec_get(args, 2))); sb_append(sb, " ");
            sb_append(sb, atomic_cmpxchg_success_order_llvm(name)); sb_append(sb, " ");
            sb_append(sb, atomic_cmpxchg_failure_order_llvm(name)); sb_append(sb, "\n");
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = extractvalue { i64, i1 } %r.");
            sb_append(sb, ds); sb_append(sb, ".atomic.pair, 0\n");
        } else {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
        };
        return 0;
    };
    if argc > 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = atomicrmw ");
        sb_append(sb, atomic_rmw_op_llvm(name)); sb_append(sb, " ptr %r."); sb_append(sb, ds);
        sb_append(sb, ".atomic.ptr, i64 %r."); sb_append(sb, str_from_int(vec_get(args, 1)));
        sb_append(sb, " "); sb_append(sb, atomic_tail_order_llvm(name)); sb_append(sb, "\n");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    };
    return 0;
}

// Raw-memory codegen intrinsics. Recognized by name and lowered inline
// to LLVM ops directly; no extern symbol is emitted. Used by the
// closure-environment helpers in stdlib/runtime/core_closures.nr to
// allocate and access closure capture records without a C runtime
// helper. The names below are reserved by the leading `__nuc_raw_`
// prefix (the language reserves all `__`-prefixed identifiers).
#[manual_drop]
fn is_nuc_raw_intrinsic(name: str) -> i64 {
    if str_eq(name, "__nuc_raw_alloc_i64s") == 1 { return 1; };
    if str_eq(name, "__nuc_raw_free") == 1 { return 1; };
    if str_eq(name, "__nuc_raw_load_i64") == 1 { return 1; };
    if str_eq(name, "__nuc_raw_store_i64") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn emit_nuc_raw_call(sb: i64, name: str, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let ds: str = str_from_int(d);
    if str_eq(name, "__nuc_raw_alloc_i64s") == 1 && argc == 1 {
        let cnt: str = str_from_int(vec_get(args, 0));
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".alloc.nbytes = mul i64 %r.");
        sb_append(sb, cnt); sb_append(sb, ", 8\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".alloc.p = call ptr @malloc(i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".alloc.nbytes)\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".alloc.null = icmp eq ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".alloc.p, null\n");
        sb_append(sb, "  br i1 %r."); sb_append(sb, ds);
        sb_append(sb, ".alloc.null, label %L_raw_oom_"); sb_append(sb, ds);
        sb_append(sb, ", label %L_raw_ok_"); sb_append(sb, ds); sb_append(sb, "\n");
        sb_append(sb, "L_raw_oom_"); sb_append(sb, ds); sb_append(sb, ":\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".alloc.panic = call i64 @__nucleor_panic(ptr @.nuc_closure_oom_msg)\n");
        sb_append(sb, "  unreachable\n");
        sb_append(sb, "L_raw_ok_"); sb_append(sb, ds); sb_append(sb, ":\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = ptrtoint ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".alloc.p to i64\n");
        return 0;
    };
    if str_eq(name, "__nuc_raw_free") == 1 && argc == 1 {
        let p: str = str_from_int(vec_get(args, 0));
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".free.p = inttoptr i64 %r.");
        sb_append(sb, p); sb_append(sb, " to ptr\n");
        sb_append(sb, "  call void @free(ptr %r."); sb_append(sb, ds); sb_append(sb, ".free.p)\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
        return 0;
    };
    if str_eq(name, "__nuc_raw_load_i64") == 1 && argc == 2 {
        let p: str = str_from_int(vec_get(args, 0));
        let off: str = str_from_int(vec_get(args, 1));
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".load.p = inttoptr i64 %r.");
        sb_append(sb, p); sb_append(sb, " to ptr\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".load.gep = getelementptr i64, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".load.p, i64 %r."); sb_append(sb, off); sb_append(sb, "\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = load i64, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".load.gep, align 8\n");
        return 0;
    };
    if str_eq(name, "__nuc_raw_store_i64") == 1 && argc == 3 {
        let p: str = str_from_int(vec_get(args, 0));
        let off: str = str_from_int(vec_get(args, 1));
        let v: str = str_from_int(vec_get(args, 2));
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".store.p = inttoptr i64 %r.");
        sb_append(sb, p); sb_append(sb, " to ptr\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".store.gep = getelementptr i64, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".store.p, i64 %r."); sb_append(sb, off); sb_append(sb, "\n");
        sb_append(sb, "  store i64 %r."); sb_append(sb, v); sb_append(sb, ", ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".store.gep, align 8\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 %r."); sb_append(sb, v); sb_append(sb, ", 0\n");
        return 0;
    };
    sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    return 0;
}

// typed allocas/loads/stores. Existing
// untyped builders (ir_alloca, ir_load, ir_store) call these with
// width=0 to preserve byte-identical IR output for current call sites.
#[manual_drop]
fn ir_alloca_t(d: i64, w: i64) -> Vec<i32> { return ir_inst(16, d, w, 0, 0, 0); }
#[manual_drop]
fn ir_load_t(d: i64, ptr: i64, w: i64) -> Vec<i32> { return ir_inst(17, d, w, ptr, 0, 0); }
#[manual_drop]
fn ir_store_t(v: i64, ptr: i64, w: i64) -> Vec<i32> { return ir_inst(18, 0, w, v, ptr, 0); }

// sext + trunc IR ops for crossing
// the narrower-slot ↔ i64-arith boundary. Used by future call sites
// that wire typed allocas: load narrower value with `ir_load_t(reg,
// slot, w)`, then `ir_sext(wide, reg, w)` to widen for arith. Symmetric
// trunc on the store side: `ir_trunc(narrow, val, w)` then
// `ir_store_t(narrow, slot, w)`. Encoding: op 32 = sext, op 33 = trunc;
// slot 2 carries the SOURCE width (sext) or TARGET width (trunc).
// emit_inst dispatch reads the width tag and emits the right LLVM op.
#[manual_drop]
fn ir_sext(d: i64, src: i64, src_w: i64) -> Vec<i32> { return ir_inst(32, d, src_w, src, 0, 0); }
// zext companion to ir_sext for
// unsigned narrow types (u8/u16). Same shape as ir_sext but emits
// `zext iX %S to i64` (zero-extension, top bits cleared) instead of
// `sext` (sign-extension). Required because u16 max (65535) sext'd
// to i64 becomes -1; zext'd it stays 65535. Op 34.
#[manual_drop]
fn ir_zext(d: i64, src: i64, src_w: i64) -> Vec<i32> { return ir_inst(34, d, src_w, src, 0, 0); }
#[manual_drop]
fn ir_trunc(d: i64, src: i64, dst_w: i64) -> Vec<i32> { return ir_inst(33, d, dst_w, src, 0, 0); }

#[manual_drop]
fn ir_const_int(d: i64, v: i64) -> Vec<i32> { return ir_inst(0, d, 0, v, 0, 0); }
#[manual_drop]
fn ir_binop(iop: i64, d: i64, a: i64, b: i64) -> Vec<i32> { return ir_inst(iop, d, 0, a, b, 0); }
// typed binop. Same op codes as ir_binop
// (2..6 for arith, 7..12 for cmp, 13..15 + 23..24 for bitwise/shift)
// but slot 2 carries the operand width (8/16/32). emit_inst dispatch
// reads tid: 0 stays at i64 (byte-identical fast path); >0 emits
// `<op> iN`. Caller is lower_expr kind 4 narrow path.
#[manual_drop]
fn ir_binop_t(iop: i64, d: i64, a: i64, b: i64, w: i64) -> Vec<i32> { return ir_inst(iop, d, w, a, b, 0); }
// v0.5 3e.1 spike: signed LLVM overflow-intrinsic arithmetic.
// Opcodes 35/36/37 mirror add/sub/mul. tid carries width (0 => i64),
// extra carries the trap label; the continuation label is trap + 1.
#[manual_drop]
fn ir_add_with_overflow(d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> Vec<i32> { return ir_inst(35, d, w, a, b, trap_lbl); }
#[manual_drop]
fn ir_sub_with_overflow(d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> Vec<i32> { return ir_inst(36, d, w, a, b, trap_lbl); }
#[manual_drop]
fn ir_mul_with_overflow(d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> Vec<i32> { return ir_inst(37, d, w, a, b, trap_lbl); }
#[manual_drop]
fn ir_binop_overflow(iop: i64, d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> Vec<i32> {
    if iop == 2 { return ir_add_with_overflow(d, a, b, w, trap_lbl); };
    if iop == 3 { return ir_sub_with_overflow(d, a, b, w, trap_lbl); };
    if iop == 4 { return ir_mul_with_overflow(d, a, b, w, trap_lbl); };
    return ir_binop_t(iop, d, a, b, w);
}
#[manual_drop]
fn ir_cmpop(iop: i64, d: i64, a: i64, b: i64) -> Vec<i32> { return ir_inst(iop, d, 0, a, b, 0); }
#[manual_drop]
fn ir_alloca(d: i64) -> Vec<i32> { return ir_inst(16, d, 0, 0, 0, 0); }
#[manual_drop]
fn ir_load(d: i64, ptr: i64) -> Vec<i32> { return ir_inst(17, d, 0, ptr, 0, 0); }
#[manual_drop]
fn ir_store(v: i64, ptr: i64) -> Vec<i32> { return ir_inst(18, 0, 0, v, ptr, 0); }
#[manual_drop]
fn ir_ret(v: i64) -> Vec<i32> { return ir_inst(20, 0, 0, v, 0, 0); }
#[manual_drop]
fn ir_br(lbl: i64) -> Vec<i32> { return ir_inst(21, 0, 0, lbl, 0, 0); }
#[manual_drop]
fn ir_br_cond(cond: i64, t: i64, f: i64) -> Vec<i32> { return ir_inst(22, 0, 0, cond, t, f); }
#[manual_drop]
fn ir_param_ref(d: i64, pidx: i64) -> Vec<i32> { return ir_inst(26, d, 0, pidx, 0, 0); }
#[manual_drop]
fn ir_const_str(d: i64, str_idx: i64) -> Vec<i32> { return ir_inst(27, d, 0, str_idx, 0, 0); }
#[manual_drop]
fn ir_call_ex(d: i64, fn_name: str, args: Vec<i32>) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6);
    ii.push(19); ii.push(d); ii.push(0); ii.push(fn_name); ii.push(vec_len(args)); ii.push(args);
    return ii;
}

// ir_user_call — bypass the runtime-helper name lookup
// in emit_inst so a user-defined fn that happens to share a name
// with a runtime helper (e.g. user `pow(base, exp)`) dispatches
// to `@pow` (the user-emitted definition) instead of being
// hijacked by `@__nucleor_pow` (the f64 floating-point helper).
// Pre-v0.3.126 the runtime helper always won — silent miscompute
// with NO diagnostic for the very-common pattern of writing a
// math helper named the same as a builtin.
#[manual_drop]
fn ir_user_call(d: i64, fn_name: str, args: Vec<i32>) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6);
    ii.push(31); ii.push(d); ii.push(0); ii.push(fn_name); ii.push(vec_len(args)); ii.push(args);
    return ii;
}

#[manual_drop]
fn ir_fn_ptr(d: i64, fn_name: str) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6);
    ii.push(29); ii.push(d); ii.push(0); ii.push(fn_name); ii.push(0); ii.push(0);
    return ii;
}
#[manual_drop]
fn ir_indirect_call(d: i64, closure_reg: i64, args: Vec<i32>) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6);
    ii.push(30); ii.push(d); ii.push(0); ii.push(closure_reg); ii.push(vec_len(args)); ii.push(args);
    return ii;
}

#[manual_drop]
fn ir_block_new(lbl: i64) -> Vec<i32> {
    let mut b: Vec<i32> = Vec::with_capacity(2); b.push(lbl);
    let mut insts: Vec<i32> = Vec::new(); b.push(insts); return b;
}
#[manual_drop]
fn ir_block_label(b: Vec<i32>) -> i64 { return vec_get(b, 0); }
#[manual_drop]
fn ir_block_add(b: Vec<i32>, inst: Vec<i32>) -> i64 { let mut insts: Vec<i32> = vec_get(b, 1); insts.push(inst); return 0; }
#[manual_drop]
fn ir_block_inst_count(b: Vec<i32>) -> i64 { let insts: Vec<i32> = vec_get(b, 1); return vec_len(insts); }
#[manual_drop]
fn ir_block_get_inst(b: Vec<i32>, idx: i64) -> Vec<i32> { let insts: Vec<i32> = vec_get(b, 1); return vec_get(insts, idx); }

#[manual_drop]
fn ir_fn_new(name: str, pc: i64) -> Vec<i32> {
    let mut f: Vec<i32> = Vec::with_capacity(5); f.push(name); f.push(pc);
    let mut entry_allocas: Vec<i32> = Vec::new(); f.push(entry_allocas);
    let mut blocks: Vec<i32> = Vec::new(); f.push(blocks);
    // v0.4.209 RFC-0015 phase 3a-step-3 (Option F-light): per-fn
    // widths-by-reg table. Slot 4 stores a Vec<i32> indexed by
    // alloca-reg id; values are sign-encoded narrow widths
    // (positive=signed, negative=unsigned, 0=untyped/i64). Grows
    // on demand at set time. Read at every var-ref load + store
    // for typed-IR dispatch. Two vec_gets per read on the hot path
    // — no str_concat, no sym_get hash.
    let mut widths_by_reg: Vec<i32> = Vec::new(); f.push(widths_by_reg);
    return f;
}
#[manual_drop]
fn ir_fn_set_width(f: Vec<i32>, reg: i64, w: i64) -> i64 {
    let mut widths: Vec<i32> = vec_get(f, 4);
    while vec_len(widths) <= reg { widths.push(0); };
    vec_set(widths, reg, w);
    return 0;
}
#[manual_drop]
fn ir_fn_get_width(f: Vec<i32>, reg: i64) -> i64 {
    let widths: Vec<i32> = vec_get(f, 4);
    if reg >= vec_len(widths) { return 0; };
    return vec_get(widths, reg);
}
#[manual_drop]
fn ir_fn_set_strtab_aux(f: Vec<i32>, aux: Vec<i32>) -> i64 {
    while vec_len(f) <= 5 { f.push(0); };
    vec_set(f, 5, aux);
    return 0;
}
#[manual_drop]
fn ir_fn_strtab_aux(f: Vec<i32>) -> Vec<i32> {
    if vec_len(f) > 5 { return vec_get(f, 5); };
    let mut aux: Vec<i32> = Vec::new();
    aux.push(0);
    aux.push(0);
    ir_fn_set_strtab_aux(f, aux);
    return aux;
}
#[manual_drop]
fn ir_fn_name(f: Vec<i32>) -> str { return vec_get(f, 0); }
#[manual_drop]
fn ir_fn_param_count(f: Vec<i32>) -> i64 { return vec_get(f, 1); }
#[manual_drop]
fn ir_fn_add_block(f: Vec<i32>, blk: Vec<i32>) -> i64 { let mut b: Vec<i32> = vec_get(f, 3); b.push(blk); return 0; }
#[manual_drop]
fn ir_fn_block_count(f: Vec<i32>) -> i64 { let b: Vec<i32> = vec_get(f, 3); return vec_len(b); }
#[manual_drop]
fn ir_fn_get_block(f: Vec<i32>, idx: i64) -> Vec<i32> { let b: Vec<i32> = vec_get(f, 3); return vec_get(b, idx); }
#[manual_drop]
fn ir_fn_add_entry_alloca(f: Vec<i32>, reg: i64) -> i64 {
    let mut ea: Vec<i32> = vec_get(f, 2);
    ea.push(ir_alloca(reg));
    return 0;
}

// typed entry-alloca for narrower-
// width bindings. Caller is lower_stmt kind-20 (let) when the binding's
// declared type is i8/i16/u8/u16/etc. width=0 falls back to untyped
// (i64) for back-compat.
#[manual_drop]
fn ir_fn_add_entry_alloca_t(f: Vec<i32>, reg: i64, w: i64) -> i64 {
    let mut ea: Vec<i32> = vec_get(f, 2);
    if w == 0 { ea.push(ir_alloca(reg)); } else { ea.push(ir_alloca_t(reg, w)); };
    return 0;
}

#[manual_drop]
fn free_ir_inst(ii: Vec<i32>) -> i64 {
    let op: i64 = ir_op(ii);
    if op == 19 || op == 30 || op == 31 {
        let args: Vec<i32> = vec_get(ii, 5);
        vec_free(args);
    };
    vec_free(ii);
    return 0;
}

#[manual_drop]
fn free_ir_fn(f: Vec<i32>) -> i64 {
    let entry_allocas: Vec<i32> = vec_get(f, 2);
    let mut ai: i64 = 0;
    while ai < vec_len(entry_allocas) {
        free_ir_inst(vec_get(entry_allocas, ai));
        ai = ai + 1;
    };
    vec_free(entry_allocas);
    let blocks: Vec<i32> = vec_get(f, 3);
    let mut bi: i64 = 0;
    while bi < vec_len(blocks) {
        let blk: Vec<i32> = vec_get(blocks, bi);
        let insts: Vec<i32> = vec_get(blk, 1);
        let mut ii: i64 = 0;
        while ii < vec_len(insts) {
            free_ir_inst(vec_get(insts, ii));
            ii = ii + 1;
        };
        vec_free(insts);
        vec_free(blk);
        bi = bi + 1;
    };
    vec_free(blocks);
    vec_free(f);
    return 0;
}

#[manual_drop]
fn free_ir_fns(fns: Vec<i32>) -> i64 {
    let mut fi: i64 = 0;
    while fi < vec_len(fns) {
        free_ir_fn(vec_get(fns, fi));
        fi = fi + 1;
    };
    vec_free(fns);
    return 0;
}

#[manual_drop]
fn block_has_term(blk: Vec<i32>) -> i64 {
    let ic: i64 = ir_block_inst_count(blk);
    if ic == 0 { return 0; };
    let op: i64 = ir_op(ir_block_get_inst(blk, ic - 1));
    if op == 20 || op == 21 || op == 22 { return 1; }; return 0;
}

