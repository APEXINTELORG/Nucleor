// =====================================================
// LLVM STRING ESCAPING (NEW in T30)
// =====================================================
#[manual_drop]
fn hex_digit(v: i64) -> str {
    if v == 0 { return "0"; }; if v == 1 { return "1"; }; if v == 2 { return "2"; };
    if v == 3 { return "3"; }; if v == 4 { return "4"; }; if v == 5 { return "5"; };
    if v == 6 { return "6"; }; if v == 7 { return "7"; }; if v == 8 { return "8"; };
    if v == 9 { return "9"; }; if v == 10 { return "A"; }; if v == 11 { return "B"; };
    if v == 12 { return "C"; }; if v == 13 { return "D"; }; if v == 14 { return "E"; };
    if v == 15 { return "F"; }; return "0";
}
#[manual_drop]
fn hex_byte(v: i64) -> str {
    let hi: i64 = v / 16;
    let lo: i64 = v - hi * 16;
    return str_concat(hex_digit(hi), hex_digit(lo));
}
#[manual_drop]
fn escape_llvm_str(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut esb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 92 { sb_append(esb, "\\5C"); }
        else if c == 34 { sb_append(esb, "\\22"); }
        else if c == 10 { sb_append(esb, "\\0A"); }
        else if c == 13 { sb_append(esb, "\\0D"); }
        else if c == 9 { sb_append(esb, "\\09"); }
        else if c == 0 { sb_append(esb, "\\00"); }
        else if c >= 32 && c <= 126 { sb_append_char(esb, c); }
        else { sb_append(esb, "\\"); sb_append(esb, hex_byte(c)); };
        i = i + 1;
    };
    return sb_to_str(esb);
}

// =====================================================
// EMISSION (from T29, extended for builtins + strings)
// =====================================================
#[manual_drop]
fn emit_cmp(sb: i64, cn: str, d: i64, a: i64, b: i64) -> i64 {
    // Perf experiment: tried adding an
    // `sb_append_int` runtime helper that writes int digits directly
    // into the SB buffer (eliminates the str_from_int malloc).
    // Wall-time delta on this site was within the natural variance
    // band (~0.4s spread on cold runs). Peak-mem dropped ~25 MB but
    // the change wasn't worth the runtime helper + ABI surface.
    // Reverted; helper removed.
    sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, ".cmp = icmp "); sb_append(sb, cn);
    sb_append(sb, " i64 %r."); sb_append(sb, str_from_int(a));
    sb_append(sb, ", %r."); sb_append(sb, str_from_int(b));
    sb_append(sb, "\n  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, " = zext i1 %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, ".cmp to i64\n"); return 0;
}
#[manual_drop]
fn emit_arith(sb: i64, on: str, d: i64, a: i64, b: i64) -> i64 {
    sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, " = "); sb_append(sb, on);
    sb_append(sb, " i64 %r."); sb_append(sb, str_from_int(a));
    sb_append(sb, ", %r."); sb_append(sb, str_from_int(b));
    sb_append(sb, "\n"); return 0;
}
// typed arith — `<op> iN %a, %b` instead
// of `<op> i64`. Called from emit_inst dispatch when ir_tid is non-zero.
#[manual_drop]
fn emit_arith_w(sb: i64, on: str, d: i64, a: i64, b: i64, w: i64) -> i64 {
    sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, " = "); sb_append(sb, on);
    sb_append(sb, " "); sb_append(sb, width_to_llvm_type(w));
    sb_append(sb, " %r."); sb_append(sb, str_from_int(a));
    sb_append(sb, ", %r."); sb_append(sb, str_from_int(b));
    sb_append(sb, "\n"); return 0;
}
#[manual_drop]
fn emit_overflow_arith(sb: i64, on: str, d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> i64 {
    // w is sign-encoded — positive = signed, negative =
    // unsigned, 0 = i64 ABI (treated as signed for trap purposes
    // since i64 has no narrower-unsigned distinction at the LLVM
    // intrinsic level). Derive absolute width for the type and
    // signedness prefix for the intrinsic name. Pre-fix, all
    // overflow intrinsics emitted as signed (`@llvm.sadd.with...`)
    // regardless of operand type — unsigned arithmetic that wraps
    // legitimately under unsigned semantics fired signed-overflow
    // traps. v0.4.240 routes unsigned widths through the matching
    // `uadd/usub/umul.with.overflow.iN` intrinsics.
    let aw: i64 = if w >= 0 { w } else { 0 - w };
    let bw: i64 = if aw == 0 { 64 } else { aw };
    let signed_p: i64 = if w >= 0 { 1 } else { 0 };
    let sign_prefix: str = if signed_p == 1 { "s" } else { "u" };
    let ty: str = width_to_llvm_type(bw);
    let ds: str = str_from_int(d);
    let a_s: str = str_from_int(a);
    let b_s: str = str_from_int(b);
    let trap_s: str = str_from_int(trap_lbl);
    let cont_s: str = str_from_int(trap_lbl + 1);
    sb_append(sb, "  %r."); sb_append(sb, ds);
    sb_append(sb, ".ov = call { "); sb_append(sb, ty);
    sb_append(sb, ", i1 } @llvm."); sb_append(sb, sign_prefix); sb_append(sb, on);
    sb_append(sb, ".with.overflow."); sb_append(sb, ty);
    sb_append(sb, "("); sb_append(sb, ty); sb_append(sb, " %r.");
    sb_append(sb, a_s); sb_append(sb, ", "); sb_append(sb, ty);
    sb_append(sb, " %r."); sb_append(sb, b_s); sb_append(sb, ")\n");
    sb_append(sb, "  %r."); sb_append(sb, ds);
    sb_append(sb, " = extractvalue { "); sb_append(sb, ty);
    sb_append(sb, ", i1 } %r."); sb_append(sb, ds);
    sb_append(sb, ".ov, 0\n");
    sb_append(sb, "  %r."); sb_append(sb, ds);
    sb_append(sb, ".of = extractvalue { "); sb_append(sb, ty);
    sb_append(sb, ", i1 } %r."); sb_append(sb, ds);
    sb_append(sb, ".ov, 1\n");
    sb_append(sb, "  br i1 %r."); sb_append(sb, ds);
    sb_append(sb, ".of, label %L"); sb_append(sb, trap_s);
    sb_append(sb, ", label %L"); sb_append(sb, cont_s);
    sb_append(sb, "\nL"); sb_append(sb, trap_s); sb_append(sb, ":\n");
    sb_append(sb, "  %r."); sb_append(sb, ds);
    sb_append(sb, ".panic = call i64 @__nucleor_panic(ptr @.nuc_overflow_intrin_msg)\n");
    sb_append(sb, "  unreachable\nL"); sb_append(sb, cont_s); sb_append(sb, ":\n");
    return 0;
}
#[manual_drop]
fn find_extern_idx(pool: Vec<i32>, externs: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(externs) {
        if str_eq(node_field(pool, vec_get(externs, i), 1), name) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn emit_extern_call(sb: i64, pool: Vec<i32>, externs: Vec<i32>, ext_idx: i64, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let nid: i64 = vec_get(externs, ext_idx);
    let name: str = node_field(pool, nid, 1);
    let plist: i64 = node_field(pool, nid, 2);
    let rtype: str = node_field(pool, nid, 3);
    let ds: str = str_from_int(d);
    let lr: str = nr_type_to_llvm(rtype);
    // Step 1: convert args from i64 to target types
    let mut ai: i64 = 0;
    while ai < argc {
        let pnid: i64 = list_get(pool, plist, ai);
        let ptype: str = node_field(pool, pnid, 2);
        let as2: str = str_from_int(ai);
        if is_ptr_type(ptype) == 1 {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = inttoptr i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to ptr\n");
        } else if str_eq(ptype, "i32") {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = trunc i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to i32\n");
        } else if str_eq(ptype, "f64") {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = sitofp i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to double\n");
        };
        ai = ai + 1;
    };
    // Step 2: emit call
    if str_eq(lr, "void") {
        sb_append(sb, "  call void @"); sb_append(sb, name); sb_append(sb, "(");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".rv = call "); sb_append(sb, lr);
        sb_append(sb, " @"); sb_append(sb, name); sb_append(sb, "(");
    };
    // Step 3: emit args with correct types
    ai = 0;
    while ai < argc {
        if ai > 0 { sb_append(sb, ", "); };
        let pnid: i64 = list_get(pool, plist, ai);
        let ptype: str = node_field(pool, pnid, 2);
        let lt: str = nr_type_to_llvm(ptype);
        if is_ptr_type(ptype) == 1 || str_eq(ptype, "i32") || str_eq(ptype, "f64") {
            sb_append(sb, lt); sb_append(sb, " %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
        } else {
            sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
        };
        ai = ai + 1;
    };
    sb_append(sb, ")\n");
    // Step 4: convert return from target type to i64
    if str_eq(lr, "void") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    } else if str_eq(lr, "ptr") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = ptrtoint ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else if str_eq(lr, "i32") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = sext i32 %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else if str_eq(lr, "double") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = fptosi double %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".rv, 0\n");
    };
    return 0;
}

#[manual_drop]
fn emit_inst(inst: Vec<i32>, sb: i64, pool: Vec<i32>, externs: Vec<i32>) -> i64 {
    let op: i64 = ir_op(inst); let d: i64 = ir_dest(inst);
    if op == 0 { sb_append(sb, "  %r."); sb_append(sb, str_from_int(d)); sb_append(sb, " = add i64 "); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", 0\n"); }
    else if op == 2 { let bw: i64 = ir_tid(inst); if bw == 0 { emit_arith(sb, "add", d, ir_op1(inst), ir_op2(inst)); } else { emit_arith_w(sb, "add", d, ir_op1(inst), ir_op2(inst), bw); }; }
    else if op == 3 { let bw: i64 = ir_tid(inst); if bw == 0 { emit_arith(sb, "sub", d, ir_op1(inst), ir_op2(inst)); } else { emit_arith_w(sb, "sub", d, ir_op1(inst), ir_op2(inst), bw); }; }
    else if op == 4 { let bw: i64 = ir_tid(inst); if bw == 0 { emit_arith(sb, "mul", d, ir_op1(inst), ir_op2(inst)); } else { emit_arith_w(sb, "mul", d, ir_op1(inst), ir_op2(inst), bw); }; }
    else if op == 5 { let bw: i64 = ir_tid(inst); if bw == 0 { emit_arith(sb, "sdiv", d, ir_op1(inst), ir_op2(inst)); } else { emit_arith_w(sb, "sdiv", d, ir_op1(inst), ir_op2(inst), bw); }; }
    else if op == 6 { let bw: i64 = ir_tid(inst); if bw == 0 { emit_arith(sb, "srem", d, ir_op1(inst), ir_op2(inst)); } else { emit_arith_w(sb, "srem", d, ir_op1(inst), ir_op2(inst), bw); }; }
    else if op == 7 { emit_cmp(sb, "eq", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 8 { emit_cmp(sb, "ne", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 9 { emit_cmp(sb, "slt", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 10 { emit_cmp(sb, "sgt", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 11 { emit_cmp(sb, "sle", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 12 { emit_cmp(sb, "sge", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 13 { emit_arith(sb, "and", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 14 { emit_arith(sb, "or", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 15 { emit_arith(sb, "xor", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 23 { emit_arith(sb, "shl", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 24 { emit_arith(sb, "ashr", d, ir_op1(inst), ir_op2(inst)); }
    // Lane 1 audit fix (2026-05-08) — close C-002. iop 25 = unsigned
    // logical right shift (`lshr`), used when LHS is u64. Pre-fix `>>`
    // emitted iop 24 (ashr) regardless of signedness, so a u64 with bit
    // 63 set sign-extended on shift instead of zero-filling.
    else if op == 25 { emit_arith(sb, "lshr", d, ir_op1(inst), ir_op2(inst)); }
    // Lane 1 audit fix (2026-05-08) — close C-001 / C-007. iops 38..41
    // are the unsigned analogues of slt/sgt/sle/sge (iops 9..12). The
    // lowering site picks unsigned iops when binop_u64_type returns 1
    // for either operand. eq/ne (iops 7/8) are signedness-agnostic
    // (raw bit compare) and stay unchanged.
    else if op == 38 { emit_cmp(sb, "ult", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 39 { emit_cmp(sb, "ugt", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 40 { emit_cmp(sb, "ule", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 41 { emit_cmp(sb, "uge", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 16 {
        // alloca uses tid for width.
        // tid=0 fast path keeps the pre-phase-3 byte-identical emit
        // (and avoids the width_to_llvm_type call + concat overhead
        // on the hot path; today every alloca uses tid=0).
        let atid: i64 = ir_tid(inst);
        if atid == 0 {
            sb_append(sb, "  %r."); sb_append(sb, str_from_int(d)); sb_append(sb, " = alloca i64\n");
        } else {
            sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
            sb_append(sb, " = alloca "); sb_append(sb, width_to_llvm_type(atid)); sb_append(sb, "\n");
        };
    }
    else if op == 17 {
        // load uses tid for width.
        // tid=0 fast path; tid != 0 path is for phase 3b/3c future use.
        let ltid: i64 = ir_tid(inst);
        if ltid == 0 {
            sb_append(sb, "  %r."); sb_append(sb, str_from_int(d)); sb_append(sb, " = load i64, ptr %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, "\n");
        } else {
            sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
            sb_append(sb, " = load "); sb_append(sb, width_to_llvm_type(ltid));
            sb_append(sb, ", ptr %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, "\n");
        };
    }
    else if op == 18 {
        // store uses tid for width.
        let stid: i64 = ir_tid(inst);
        if stid == 0 {
            sb_append(sb, "  store i64 %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", ptr %r."); sb_append(sb, str_from_int(ir_op2(inst))); sb_append(sb, "\n");
        } else {
            sb_append(sb, "  store "); sb_append(sb, width_to_llvm_type(stid));
            sb_append(sb, " %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", ptr %r.");
            sb_append(sb, str_from_int(ir_op2(inst))); sb_append(sb, "\n");
        };
    }
    else if op == 32 {
        // sext narrower → i64.
        // tid carries SOURCE width (8/16/32). Emits:
        //   %r.D = sext iX %r.S to i64
        let sxw: str = width_to_llvm_type(ir_tid(inst));
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = sext "); sb_append(sb, sxw);
        sb_append(sb, " %r."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, " to i64\n");
    }
    else if op == 33 {
        // trunc i64 → narrower.
        // tid carries TARGET width (8/16/32). Emits:
        //   %r.D = trunc i64 %r.S to iX
        let tcw: str = width_to_llvm_type(ir_tid(inst));
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = trunc i64 %r."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, " to "); sb_append(sb, tcw); sb_append(sb, "\n");
    }
    else if op == 34 {
        // zext narrower → i64
        // for unsigned types. Same encoding as op 32 (sext) but
        // emits `zext` for u8/u16 to keep the i64 ABI bit-correct.
        let zxw: str = width_to_llvm_type(ir_tid(inst));
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = zext "); sb_append(sb, zxw);
        sb_append(sb, " %r."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, " to i64\n");
    }
    else if op == 35 { emit_overflow_arith(sb, "add", d, ir_op1(inst), ir_op2(inst), ir_tid(inst), ir_extra(inst)); }
    else if op == 36 { emit_overflow_arith(sb, "sub", d, ir_op1(inst), ir_op2(inst), ir_tid(inst), ir_extra(inst)); }
    else if op == 37 { emit_overflow_arith(sb, "mul", d, ir_op1(inst), ir_op2(inst), ir_tid(inst), ir_extra(inst)); }
    else if op == 19 {
        let fn_name: str = ir_op1(inst); let argc: i64 = ir_op2(inst); let args: Vec<i32> = ir_extra(inst);
        if is_nuc_raw_intrinsic(fn_name) == 1 {
            emit_nuc_raw_call(sb, fn_name, d, argc, args);
        } else if is_atomic_ordered_builtin(fn_name) == 1 {
            emit_atomic_ordered_call(sb, fn_name, d, argc, args);
        } else {
            let ext_idx: i64 = find_extern_idx(pool, externs, fn_name);
            if ext_idx >= 0 {
                emit_extern_call(sb, pool, externs, ext_idx, d, argc, args);
            } else {
                let rn: str = get_rt_name(fn_name);
                if str_eq(rn, "") {
                    // Regular (non-builtin, non-extern) call — all i64
                    sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
                    sb_append(sb, " = call i64 @"); sb_append(sb, fn_name); sb_append(sb, "(");
                    let mut ai: i64 = 0;
                    while ai < argc { if ai > 0 { sb_append(sb, ", "); }; sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); ai = ai + 1; };
                    sb_append(sb, ")\n");
                } else {
                    // Builtin call with ABI conversion
                    emit_builtin_call(sb, fn_name, rn, d, argc, args);
                };
            };
        };
    }
    else if op == 31 {
        // user-fn call — bypasses get_rt_name lookup so
        // user-defined fns shadow runtime helpers of the same name.
        // Always emits `call i64 @<fn_name>(...)` directly.
        let fn_name: str = ir_op1(inst); let argc: i64 = ir_op2(inst); let args: Vec<i32> = ir_extra(inst);
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = call i64 @"); sb_append(sb, fn_name); sb_append(sb, "(");
        let mut ai: i64 = 0;
        while ai < argc { if ai > 0 { sb_append(sb, ", "); }; sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); ai = ai + 1; };
        sb_append(sb, ")\n");
    }
    else if op == 20 { sb_append(sb, "  ret i64 %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, "\n"); }
    else if op == 21 { sb_append(sb, "  br label %L"); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, "\n"); }
    else if op == 22 {
        sb_append(sb, "  %br."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, ".cond = icmp ne i64 %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", 0\n");
        sb_append(sb, "  br i1 %br."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, ".cond, label %L"); sb_append(sb, str_from_int(ir_op2(inst)));
        sb_append(sb, ", label %L"); sb_append(sb, str_from_int(ir_extra(inst))); sb_append(sb, "\n");
    }
    else if op == 26 { sb_append(sb, "  %r."); sb_append(sb, str_from_int(d)); sb_append(sb, " = add i64 %p."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", 0\n"); }
    else if op == 27 {
        // const_str: ptrtoint ptr @.str.IDX to i64
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = ptrtoint ptr @.str."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, " to i64\n");
    }
    else if op == 28 {
        // select: result = select i1 (cond != 0), i64 then_val, i64 else_val
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, ".sel = icmp ne i64 %r."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, ", 0\n  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = select i1 %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, ".sel, i64 %r."); sb_append(sb, str_from_int(ir_op2(inst)));
        sb_append(sb, ", i64 %r."); sb_append(sb, str_from_int(ir_extra(inst)));
        sb_append(sb, "\n");
    }
    else if op == 29 {
        // fn_ptr: ptrtoint ptr @fn_name to i64
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = ptrtoint ptr @"); sb_append(sb, ir_op1(inst));
        sb_append(sb, " to i64\n");
    }
    else if op == 30 {
        // Indirect call with tag-bit dispatch.
        // The i64 closure value's low bit distinguishes:
        //   bit 0 = 1 → closure: env_ptr | 1; call body(env, args...)
        //   bit 0 = 0 → bare fn-ptr; call directly with just args
        // MEM-5: HARD ABI REQUIREMENT — closure env pointers and bare
        // fn-ptr text addresses MUST be >=2-byte aligned so bit 0 is free
        // for the tag. This holds on every supported target: `malloc`
        // guarantees >=8-byte (max_align_t) alignment for the env block,
        // and x86_64 / aarch64 function entry points are >=4-byte aligned.
        // Any future custom env allocator MUST preserve >=2-byte alignment,
        // or this dispatch silently mis-routes (an odd env reads bit 0 = 0
        // and is misdispatched as a bare fn-ptr). Never construct a closure
        // value from an unaligned pointer.
        let clo_reg: i64 = ir_op1(inst);
        let argc: i64 = ir_op2(inst);
        let args: Vec<i32> = ir_extra(inst);
        let ds: str = str_from_int(d);
        let crs: str = str_from_int(clo_reg);
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".tag = and i64 %r.");
        sb_append(sb, crs); sb_append(sb, ", 1\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".is_clo = icmp ne i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".tag, 0\n");
        sb_append(sb, "  br i1 %r."); sb_append(sb, ds);
        sb_append(sb, ".is_clo, label %L_clo_"); sb_append(sb, ds);
        sb_append(sb, ", label %L_fnp_"); sb_append(sb, ds); sb_append(sb, "\n");
        // Closure path
        sb_append(sb, "L_clo_"); sb_append(sb, ds); sb_append(sb, ":\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".env = and i64 %r.");
        sb_append(sb, crs); sb_append(sb, ", -2\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".envp = inttoptr i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".env to ptr\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".fnoff = getelementptr i64, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".envp, i64 1\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".fpi = load i64, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".fnoff, align 8\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".fp_clo = inttoptr i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".fpi to ptr\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".cres = call i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".fp_clo(i64 %r."); sb_append(sb, ds); sb_append(sb, ".env");
        let mut ai: i64 = 0;
        while ai < argc {
            sb_append(sb, ", i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
            ai = ai + 1;
        };
        sb_append(sb, ")\n");
        sb_append(sb, "  br label %L_join_"); sb_append(sb, ds); sb_append(sb, "\n");
        // Bare fn-ptr path
        sb_append(sb, "L_fnp_"); sb_append(sb, ds); sb_append(sb, ":\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".fp_bare = inttoptr i64 %r.");
        sb_append(sb, crs); sb_append(sb, " to ptr\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".fres = call i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".fp_bare(");
        ai = 0;
        while ai < argc {
            if ai > 0 { sb_append(sb, ", "); };
            sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
            ai = ai + 1;
        };
        sb_append(sb, ")\n");
        sb_append(sb, "  br label %L_join_"); sb_append(sb, ds); sb_append(sb, "\n");
        // Join
        sb_append(sb, "L_join_"); sb_append(sb, ds); sb_append(sb, ":\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = phi i64 [ %r.");
        sb_append(sb, ds); sb_append(sb, ".cres, %L_clo_"); sb_append(sb, ds);
        sb_append(sb, " ], [ %r."); sb_append(sb, ds); sb_append(sb, ".fres, %L_fnp_");
        sb_append(sb, ds); sb_append(sb, " ]\n");
    };
    return 0;
}

#[manual_drop]
fn emit_fn(f: Vec<i32>, pool: Vec<i32>, externs: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let fname: str = ir_fn_name(f);
    let is_main: i64 = str_eq(fname, "main");
    if is_main == 1 {
        // main gets argc/argv and calls init_args before user body
        sb_append(sb, "define i64 @main(i32 %__argc, ptr %__argv) {\n");
        sb_append(sb, "bb.entry:\n");
        sb_append(sb, "  call void @__nucleor_init_args(i32 %__argc, ptr %__argv)\n");
    } else {
        sb_append(sb, "define i64 @"); sb_append(sb, fname); sb_append(sb, "(");
        let pc: i64 = ir_fn_param_count(f); let mut pi: i64 = 0;
        while pi < pc { if pi > 0 { sb_append(sb, ", "); }; sb_append(sb, "i64 %p."); sb_append(sb, str_from_int(pi)); pi = pi + 1; };
        sb_append(sb, ") {\n");
    };
    // Emit entry-block allocas first (hoisted from loop/branch bodies)
    let ea: Vec<i32> = vec_get(f, 2);
    let eac: i64 = vec_len(ea);
    let bc: i64 = ir_fn_block_count(f); let mut bi: i64 = 0;
    while bi < bc {
        let blk: Vec<i32> = ir_fn_get_block(f, bi);
        if bi == 0 {
            if is_main == 0 { sb_append(sb, "bb.entry:\n"); };
            // For main, bb.entry was already emitted above with init_args
            // Emit hoisted entry allocas before any other instructions
            let mut eai: i64 = 0;
            while eai < eac { emit_inst(vec_get(ea, eai), sb, pool, externs); eai = eai + 1; };
        }
        else { sb_append(sb, "L"); sb_append(sb, str_from_int(ir_block_label(blk))); sb_append(sb, ":\n"); };
        let ic: i64 = ir_block_inst_count(blk); let mut jj: i64 = 0;
        while jj < ic { emit_inst(ir_block_get_inst(blk, jj), sb, pool, externs); jj = jj + 1; };
        bi = bi + 1;
    };
    sb_append(sb, "}\n"); return sb_to_str(sb);
}

#[manual_drop]
fn emit_externs() -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "declare void @__nucleor_print_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_putchar(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_len(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_eq(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_char_at(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_char_at_strict(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_substring(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_concat(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_intern(ptr)\n");
    sb_append(sb, "declare void @__nucleor_str_free(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_arena_new()\n");
    sb_append(sb, "declare void @__nucleor_str_arena_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_arena_bytes(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_arena_concat(i64, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_arena_substring(i64, ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_file_read_string(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_file_read_string_or_panic(ptr)\n");
    sb_append(sb, "declare void @__nucleor_file_write_string(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_file_bytes_equal(ptr, ptr)\n");
    sb_append(sb, "declare void @__nucleor_init_args(i32, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_system(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_new()\n");
    sb_append(sb, "declare ptr @__nucleor_vec_with_capacity(i64)\n");
    sb_append(sb, "declare void @__nucleor_vec_push(ptr, i64)\n");
    // ptr_is_null intrinsic.
    sb_append(sb, "declare i64 @__nucleor_ptr_is_null(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_get(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_len(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_pop(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_free(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_set(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_first(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_last(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_is_empty(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_swap(ptr, i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_vec_extend(ptr, ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_remove_at(ptr, i64)\n");
    sb_append(sb, "declare void @__nucleor_vec_insert_at(ptr, i64, i64)\n");
    // Option<T> / Result<T,E> method helpers.
    sb_append(sb, "declare i64 @__nucleor_option_unwrap(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_option_unwrap_or(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_option_is_some(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_option_is_none(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_option_expect(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_result_unwrap(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_result_unwrap_err(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_result_unwrap_or(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_result_is_ok(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_result_is_err(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_result_ok(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_result_err(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_result_expect(ptr, ptr)\n");
    // Option/Result fn-arg helpers.
    sb_append(sb, "declare ptr @__nucleor_option_map(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_option_and_then(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_option_unwrap_or_else(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_result_map(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_result_and_then(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_result_unwrap_or_else(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_result_or_else(ptr, i64)\n");
    // recursive Debug formatters.
    sb_append(sb, "declare ptr @__nucleor_vec_to_debug_str_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_to_debug_str_str(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_to_debug_str_option_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_option_to_debug_str_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_result_to_debug_str_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_sb_new()\n");
    sb_append(sb, "declare void @__nucleor_sb_append(i64, ptr)\n");
    sb_append(sb, "declare void @__nucleor_sb_append_char(i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_sb_append_char_at(i64, ptr, i64)\n");
    sb_append(sb, "declare void @__nucleor_sb_append_range(i64, ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sb_new_with_cap(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_sb_to_str(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_args_count()\n");
    sb_append(sb, "declare ptr @__nucleor_args_get(i64)\n");
    sb_append(sb, "declare void @__nucleor_print_bool(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_read_line()\n");
    sb_append(sb, "declare i64 @__nucleor_read_i64()\n");
    sb_append(sb, "declare i64 @__nucleor_read_byte()\n");
    sb_append(sb, "declare ptr @__nucleor_format_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_int(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_int_strict(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_bool(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f64_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f32_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f64_to_str_prec(i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f32_to_str_prec(i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_bool_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_hex(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_bin(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_oct(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_str_force_sign(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_hex_upper(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f64_to_str_sci(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f64_to_str_sci_upper(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f64_to_str_sci_prec(i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f64_to_str_sci_prec_upper(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_i64_radix(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_parse_hex(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_parse_bin(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_pad_left(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_pad_right(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_center(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_join(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_lines(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_chars(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format_str(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format_hex(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_ii(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_si(ptr, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_ss(ptr, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_is(ptr, i64, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_ff(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_fi(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_if(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_fff(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format_f64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dyn_box_make(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dyn_box_type(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dyn_box_data(i64)\n");
    sb_append(sb, "declare void @__nucleor_dyn_box_free(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_iter_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_collect_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_count_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_take_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_chain_i64(ptr, ptr)\n");
    // extended iter surface
    sb_append(sb, "declare i64 @__nucleor_vec_position_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_product_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_step_by_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_nth_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_reduce_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_skip_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_map_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_filter_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_fold_i64(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_each_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_sum_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_min_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_max_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_contains_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_index_of_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_reverse_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_sort_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_clone_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_clear_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_sum_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_min_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_max_f64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_to_lower(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_to_upper(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_trim(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_trim_start(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_trim_end(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_is_empty(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_count(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_reverse(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_starts_with(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_ends_with(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_index_of(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_contains(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_replace(ptr, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_repeat(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_split(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format_bool(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iii(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sii(ptr, ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iss(ptr, i64, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sss(ptr, ptr, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_ssi(ptr, ptr, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sis(ptr, ptr, i64, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iis(ptr, i64, i64, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_isi(ptr, i64, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iif(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iff(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sff(ptr, ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_ssf(ptr, ptr, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sif(ptr, ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_isf(ptr, i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_avg_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_dot_i64(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_count_eq_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_any_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_all_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_alpha(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_digit(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_alnum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_whitespace(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_upper(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_lower(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_hex_digit(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_punct(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_ascii(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_to_upper(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_to_lower(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_digit_value(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rng_int(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rng_uniform()\n");
    sb_append(sb, "declare i64 @__nucleor_rng_normal()\n");
    sb_append(sb, "declare i64 @__nucleor_rng_bernoulli(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rng_exponential(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_hashmap_keys(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_hashmap_values(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_time_iso_now()\n");
    sb_append(sb, "declare ptr @__nucleor_time_format_iso(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fnv1a_64_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fnv1a_64_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_murmur3_64(i64)\n");
    sb_append(sb, "declare void @__nucleor_print_raw(ptr)\n");
    sb_append(sb, "declare void @__nucleor_eprint_raw(ptr)\n");
    sb_append(sb, "declare void @__nucleor_file_append_string(ptr, ptr)\n");
    sb_append(sb, "declare void @__nucleor_sb_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_now_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_isatty_stdout()\n");
    sb_append(sb, "declare ptr @__nucleor_chr(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_getcwd()\n");
    sb_append(sb, "declare ptr @__nucleor_getenv(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_pipe_create(ptr)\n");
    sb_append(sb, "declare void @__nucleor_pipe_write(i64, ptr)\n");
    sb_append(sb, "declare void @__nucleor_pipe_close(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_sha256(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_thread_spawn(i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_thread_join(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_async_spawn(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_async_await(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_mutex_new()\n");
    sb_append(sb, "declare void @__nucleor_mutex_lock(i64)\n");
    sb_append(sb, "declare void @__nucleor_mutex_unlock(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_channel_new(i64)\n");
    sb_append(sb, "declare void @__nucleor_channel_send(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_channel_recv(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_channel_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_load(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_cpu_count()\n");
    // HashMap runtime
    sb_append(sb, "declare i64 @__nucleor_hashmap_new()\n");
    sb_append(sb, "declare void @__nucleor_hashmap_insert(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_contains(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_contains_key(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sym_aux_get(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sym_aux_create(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sym_linear_lookup(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sym_linear_lookup_idx(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_own_put_i_full(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sym_aux_built_at(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sym_aux_set_built_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_compile_src_set(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_compile_src_get()\n");
    sb_append(sb, "declare i64 @__nucleor_compile_src_clear()\n");
    // Lane 4 / F-002: parse-depth side table.
    sb_append(sb, "declare i64 @__nucleor_parse_depth_inc()\n");
    sb_append(sb, "declare i64 @__nucleor_parse_depth_dec()\n");
    sb_append(sb, "declare i64 @__nucleor_parse_depth_get()\n");
    sb_append(sb, "declare i64 @__nucleor_parse_depth_reset()\n");
    // C-side preflight bare-CR scan.
    sb_append(sb, "declare i64 @__nucleor_source_bare_cr_offset(ptr)\n");
    // generic str-keyed source-cache
    sb_append(sb, "declare ptr @__nucleor_str_cache_get(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_cache_put(ptr, ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_cache_put_miss(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_cache_is_miss_marker(ptr)\n");
    // V2: parallelism runtime
    sb_append(sb, "declare i64 @__nucleor_par_map(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_par_fold(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_par_reduce(i64, i64)\n");
    // V2: region/arena
    sb_append(sb, "declare i64 @__nucleor_region_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_region_alloc(i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_region_free(i64)\n");
    sb_append(sb, "declare void @__nucleor_region_reset(i64)\n");
    // f64 (always available via nucleor_llvm_rt.c)
    sb_append(sb, "declare void @__nucleor_print_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_from_scaled(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_from_scaled(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_from_bits(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_bits(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_from_bits(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_bits(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32_to_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fabs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fmod(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sqrt(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_cos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_pow(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_floor(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_ceil(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_round(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_exp(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_log(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sigmoid(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tanh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_relu(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_gelu(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_min(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_max(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_clamp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_assert(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_contract_require(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_contract_ensure(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_contract_invariant(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_profile_start(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_profile_end(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_ambient_random()\n");
    sb_append(sb, "declare i64 @__nucleor_rng_seed(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_random_uniform(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_random_normal(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_random_int(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_random_bool()\n");
    sb_append(sb, "declare i64 @__nucleor_random_choice(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_shuffle(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_sample(ptr, i64)\n");
    sb_append(sb, "declare void @__nucleor_random_fill(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_mean_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_median_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_variance_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_stddev_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_range_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_percentile_f64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_arena_reset(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_device_alloc(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_device_transfer(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_device_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_view(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_py_eval(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_new(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_append(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_read_prefix(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_evict(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_compact(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvprefix_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_simd_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_simd_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_simd_fma(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_fma(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_broadcast(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_reduce_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_iter(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_take(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_skip(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_chain(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_map(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_filter(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_any(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_all(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_count(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_fold(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rods_f64_encode(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rods_f64_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rods_f64_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rods_f64_div(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrap_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sat_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_ambient_scheduler()\n");
    sb_append(sb, "declare i64 @__nucleor_mutex_new_value(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_mutex_lock_value(i64)\n");
    sb_append(sb, "declare void @__nucleor_mutex_unlock_value(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rwlock_new(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rwlock_read(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rwlock_write(i64)\n");
    sb_append(sb, "declare void @__nucleor_rwlock_unlock(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_cancel_token_new(i64)\n");
    sb_append(sb, "declare void @__nucleor_cancel_token_cancel(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_cancel_token_is_cancelled(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_arena_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_arena_alloc(i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_arena_destroy(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_assert_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_assert_ne(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic(ptr)\n");
    // Closure-environment / raw-memory intrinsics: declare libc
    // malloc/free for use by the __nuc_raw_* codegen primitives,
    // and the OOM panic message they share. Both symbols are
    // libc; no new dependency. Tagged unique so they don't collide
    // with anything else in the emitted IR.
    sb_append(sb, "declare ptr @malloc(i64)\n");
    sb_append(sb, "declare void @free(ptr)\n");
    sb_append(sb, "@.nuc_closure_oom_msg = private unnamed_addr constant [38 x i8] c\"out of memory: closure env allocation\\00\"\n");
    let strict_intrin: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
    if str_eq(strict_intrin, "1") == 1 {
        sb_append(sb, "@.nuc_overflow_intrin_msg = private unnamed_addr constant [17 x i8] c\"integer overflow\\00\"\n");
        sb_append(sb, "declare { i8, i1 } @llvm.sadd.with.overflow.i8(i8, i8)\n");
        sb_append(sb, "declare { i16, i1 } @llvm.sadd.with.overflow.i16(i16, i16)\n");
        sb_append(sb, "declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32)\n");
        sb_append(sb, "declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64)\n");
        sb_append(sb, "declare { i8, i1 } @llvm.ssub.with.overflow.i8(i8, i8)\n");
        sb_append(sb, "declare { i16, i1 } @llvm.ssub.with.overflow.i16(i16, i16)\n");
        sb_append(sb, "declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32)\n");
        sb_append(sb, "declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64)\n");
        sb_append(sb, "declare { i8, i1 } @llvm.smul.with.overflow.i8(i8, i8)\n");
        sb_append(sb, "declare { i16, i1 } @llvm.smul.with.overflow.i16(i16, i16)\n");
        sb_append(sb, "declare { i32, i1 } @llvm.smul.with.overflow.i32(i32, i32)\n");
        sb_append(sb, "declare { i64, i1 } @llvm.smul.with.overflow.i64(i64, i64)\n");
        sb_append(sb, "declare { i8, i1 } @llvm.uadd.with.overflow.i8(i8, i8)\n");
        sb_append(sb, "declare { i16, i1 } @llvm.uadd.with.overflow.i16(i16, i16)\n");
        sb_append(sb, "declare { i32, i1 } @llvm.uadd.with.overflow.i32(i32, i32)\n");
        sb_append(sb, "declare { i64, i1 } @llvm.uadd.with.overflow.i64(i64, i64)\n");
        sb_append(sb, "declare { i8, i1 } @llvm.usub.with.overflow.i8(i8, i8)\n");
        sb_append(sb, "declare { i16, i1 } @llvm.usub.with.overflow.i16(i16, i16)\n");
        sb_append(sb, "declare { i32, i1 } @llvm.usub.with.overflow.i32(i32, i32)\n");
        sb_append(sb, "declare { i64, i1 } @llvm.usub.with.overflow.i64(i64, i64)\n");
        sb_append(sb, "declare { i8, i1 } @llvm.umul.with.overflow.i8(i8, i8)\n");
        sb_append(sb, "declare { i16, i1 } @llvm.umul.with.overflow.i16(i16, i16)\n");
        sb_append(sb, "declare { i32, i1 } @llvm.umul.with.overflow.i32(i32, i32)\n");
        sb_append(sb, "declare { i64, i1 } @llvm.umul.with.overflow.i64(i64, i64)\n");
    };
    sb_append(sb, "declare i64 @__nucleor_as_i8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_f64(i64)\n");
    // T1.1 Phase 3a: sizeof_<T>() primitive byte-size builtins.
    sb_append(sb, "declare i64 @__nucleor_sizeof_i8()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_i16()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_i32()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_i64()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_i128()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u8()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u16()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u32()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u64()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u128()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_usize()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_isize()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_f16()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_bf16()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_f32()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_f64()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_bool()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_char()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_ptr()\n");
    // T1.1 Phase 5: native f64 arithmetic for inline + - * /
    sb_append(sb, "declare i64 @__nucleor_f64_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_div(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_lt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_gt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ge(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ne(i64, i64)\n");
    // T1.1 Phase 4: full as-cast matrix — float↔int converters.
    sb_append(sb, "declare i64 @__nucleor_f32_to_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_u64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_u64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_to_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_overflow_flag()\n");
    sb_append(sb, "declare i64 @__nucleor_checked_div_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_rem_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_neg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_div_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_rem_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_neg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_neg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_div_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_rem_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_neg_i64(i64)\n");
    // narrow-width div/rem panic helpers (probe finding
    // 2026-05-01-i32-min-div-neg-one-windows-exception). Args/return
    // are i64-typed per the call-site ABI; the helpers truncate to
    // native iN internally for the iN_MIN/-1 + zero checks.
    sb_append(sb, "declare i64 @__nucleor_panic_div_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_rem_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_div_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_rem_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_div_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_rem_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_shl_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_shr_i64(i64, i64)\n");
    // Lane 1 audit fix (2026-05-08) — close C-002 / C-003 (u64 shr/div/rem
    // were silently routing through the signed helpers).
    sb_append(sb, "declare i64 @__nucleor_panic_shr_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_div_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic_rem_u64(i64, i64)\n");
    // Lane 1 audit fix — F-019 / F-026 clean diagnostic exit.
    sb_append(sb, "declare i64 @__nucleor_diag_exit()\n");
    // Lane 1 audit fix — F-NUM-001 f-to-narrow saturating-truncate.
    sb_append(sb, "declare i64 @__nucleor_f64_to_i8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_u8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_i16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_u16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_i8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_u8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_i16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_u16(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_infer_var_type(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_infer_fn_return_type(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_substring_strict(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_hex(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_bin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_push(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_set(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_push_bits(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_get_bits(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_from_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_div(i64, i64)\n");
    // T1.1 Phase 5: f32 le/ne (lt/gt/eq already declared below).
    sb_append(sb, "declare i64 @__nucleor_f32_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_ge(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_ne(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_neg(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sqrt(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_exp(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_log(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_cos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_pow(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_lt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_gt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_from_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_from_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_mul(i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f16_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_bf16_to_str(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f8e4m3_from_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f8e5m2_from_f32(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f8e4m3_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f8e5m2_to_str(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f8e4m3_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f8e5m2_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_eprint_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_eprint_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_new(i64, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_splat(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_div(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_dot(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_max(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_min(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_new(i64, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_splat(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_new()\n");
    sb_append(sb, "declare i64 @__nucleor_string_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_from_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_push_byte(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_push_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_get_byte(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_as_ptr(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_print(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_eq_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_starts_with(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_ends_with(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_clone(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_free(i64)\n");
    // extended String surface
    sb_append(sb, "declare i64 @__nucleor_string_is_empty(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_to_uppercase(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_to_lowercase(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_trim(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_trim_start(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_trim_end(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_find(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_substring(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_char_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_as_str(i64)\n");
    // HashMap extras — new/insert/get/contains already declared in the
    // header block above; extras live here.
    sb_append(sb, "declare i64 @__nucleor_hashmap_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_is_empty(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_get_or(i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_merge(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_clone(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_ns()\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_us()\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_deadline_enter(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_deadline_exit()\n");
    sb_append(sb, "declare i64 @__nucleor_deadline_poll()\n");
    sb_append(sb, "declare i64 @__nucleor_deadline_check(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_max_depth_enter(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_max_depth_exit(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_ns()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_us()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_seconds()\n");
    sb_append(sb, "declare i64 @__nucleor_time_year(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_month(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_day(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_hour(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_minute(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_second(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_weekday(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_day_of_year(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_elapsed_ms(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sleep_ms(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sleep_us(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_env_get(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_get_or(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_set(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_unset(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_has(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_env_keys()\n");
    sb_append(sb, "declare i64 @__nucleor_process_id()\n");
    sb_append(sb, "declare i64 @__nucleor_os_family()\n");
    sb_append(sb, "declare i64 @__nucleor_os_pointer_width()\n");
    // RFC-0017 phase 4: VecDeque + HashSet
    sb_append(sb, "declare i64 @__nucleor_vecdeque_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_push_back(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_push_front(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_pop_front(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_pop_back(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_set(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_new()\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_insert(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_new()\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_insert(i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_get(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_contains_key(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_key_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_val_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_new()\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_insert(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_exists(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_is_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_is_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_size(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_mtime(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_create_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_create_dir_all(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_remove_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_rename(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_list_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_join(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_basename(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_dirname(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_extension(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_temp_dir()\n");
    sb_append(sb, "declare i64 @__nucleor_fs_current_dir()\n");
    sb_append(sb, "declare i64 @__nucleor_fs_remove_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_copy_file(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_canonicalize(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_separator()\n");
    sb_append(sb, "declare i64 @__nucleor_path_is_absolute(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_normalize(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_with_extension(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_strip_extension(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_components(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_parse_string(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_parse_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_get_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_get_int(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_has(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_manifest_validate(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_manifest_report(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u16_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u16_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u32_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u32_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u64_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u64_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u16_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u16_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u32_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u32_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u64_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u64_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_nil(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_bool(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_uint(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_crc32(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_crc32_update(i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sha256_hex(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_base64_encode(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_base64_decode(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_uuid_v4()\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_load(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_store(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_and(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_or(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_xor(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_swap(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_cas(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_popcount(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_leading_zeros(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_trailing_zeros(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_byte_swap(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rotate_left(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rotate_right(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_count_ones(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_count_zeros(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_min(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_max(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_clamp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_sign(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_pow(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_isqrt(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_gcd(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_lcm(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_cos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_asin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_acos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_atan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_atan2(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sinh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_cosh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tanh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_exp(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_erf(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_erfc(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_lgamma(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tgamma(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_betainc(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_student_t_sf2(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_norm_cdf(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_norm_sf(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_exp2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log10(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_pow_v(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_floor(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ceil(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_round(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_trunc(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_fmod(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_hypot(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_clamp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_min(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_max(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sign(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_copy_sign(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_lerp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_nan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_inf(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_finite(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_pi()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tau()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_e()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sqrt2()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ln2()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ln10()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_deg_to_rad(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_rad_to_deg(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_zeros(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_fill(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_ones(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_rows(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_cols(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_get(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_set(i64, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_mean(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_max(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_min(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_variance(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_stddev(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_matmul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_transpose(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_l1(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_l2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_normalize_l2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_zscore(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_clip(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_greedy(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_topk_temp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_nucleus_temp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_median(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_percentile(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_mad(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_entropy(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_top2_gap(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_minmax(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_center(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_eps(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_rank(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_gumbel(i64, i64)\n");
    sb_append(sb, "\n");
    return sb_to_str(sb);
}

#[manual_drop]
fn strtab_intern(strtab: Vec<i32>, fir: Vec<i32>, s: str) -> i64 {
    let n: i64 = vec_len(strtab);
    if n >= 128 {
        let strtab_aux: Vec<i32> = ir_fn_strtab_aux(fir);
        let mut h: i64 = vec_get(strtab_aux, 0);
        if h <= 0 {
            h = __nucleor_hashmap_new();
            vec_set(strtab_aux, 0, h);
        };
        let mut built: i64 = vec_get(strtab_aux, 1);
        while built < n {
            __nucleor_hashmap_insert(h, vec_get(strtab, built), built);
            built = built + 1;
        };
        vec_set(strtab_aux, 1, built);
        if __nucleor_hashmap_contains(h, s) == 1 { return __nucleor_hashmap_get(h, s); };
        strtab.push(s);
        __nucleor_hashmap_insert(h, s, n);
        vec_set(strtab_aux, 1, n + 1);
        return n;
    };
    let mut i: i64 = n - 1;
    while i >= 0 {
        if str_eq(vec_get(strtab, i), s) == 1 { return i; };
        i = i - 1;
    };
    strtab.push(s);
    return n;
}

#[manual_drop]
fn emit_str_constants(strtab: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(strtab) {
        let s: str = vec_get(strtab, i);
        sb_append(sb, "@.str."); sb_append(sb, str_from_int(i));
        sb_append(sb, " = private unnamed_addr constant [");
        sb_append(sb, str_from_int(str_len(s) + 1));
        sb_append(sb, " x i8] c\"");
        sb_append(sb, escape_llvm_str(s));
        sb_append(sb, "\\00\"\n");
        i = i + 1;
    };
    if vec_len(strtab) > 0 { sb_append(sb, "\n"); };
    return sb_to_str(sb);
}

// emit a `.nucleor_provenance` PE/ELF section
// in every binary the compiler produces. External tooling (e.g.
// Nucleor_Translate) populates this with a SLSA-compatible JSON
// attestation describing source-language provenance. Empty by
// default (1-byte placeholder so the section exists in the linked
// output); populated when the env var NUCLEOR_PROVENANCE_PATH is
// set (the --provenance <path> CLI flag sets it).
// LLVM IR shape:
//   @.nucleor_provenance_data = constant [N x i8] c"...", section ".nucprov"
//   @llvm.used = appending global [1 x ptr] [ptr @.nucleor_provenance_data], section "llvm.metadata"
// llvm.used keeps the linker from dropping the section when nothing
// else references it. clang on both -fuse-ld=link (PE/COFF) and
// -fuse-ld=lld (ELF) honors the section attribute and produces the
// named section in the output binary. Section name length (>8 chars)
// is handled by clang's COFF string-table mechanism automatically.
#[manual_drop]
fn emit_provenance_section() -> str {
    let mut sb: i64 = sb_new();
    let path: str = env_get_or("NUCLEOR_PROVENANCE_PATH", "");
    let mut content: str = "";
    let mut content_len: i64 = 0;
    if str_len(path) > 0 {
        content = file_read_string(path);
        content_len = str_len(content);
    };
    // Always emit the section. Empty case = 1-byte null placeholder so
    // the section is present in the linked binary even with no payload.
    if content_len == 0 {
        sb_append(sb, "@.nucleor_provenance_data = constant [1 x i8] c\"\\00\", section \".nucprov\", align 1\n");
    } else {
        sb_append(sb, "@.nucleor_provenance_data = constant [");
        sb_append(sb, str_from_int(content_len));
        sb_append(sb, " x i8] c\"");
        sb_append(sb, escape_llvm_str(content));
        sb_append(sb, "\", section \".nucprov\", align 1\n");
    };
    // llvm.used pin so the linker keeps the section even though nothing
    // in user code references it.
    sb_append(sb, "@llvm.used = appending global [1 x ptr] [ptr @.nucleor_provenance_data], section \"llvm.metadata\"\n\n");
    return sb_to_str(sb);
}

#[manual_drop]
fn nr_type_to_llvm(t: str) -> str {
    if str_eq(t, "str") { return "ptr"; };
    if str_eq(t, "ptr") { return "ptr"; };
    if str_eq(t, "void") { return "void"; };
    // Integer widths (RFC-0015 phase 2)
    if str_eq(t, "i8") { return "i8"; };
    if str_eq(t, "i16") { return "i16"; };
    if str_eq(t, "i32") { return "i32"; };
    if str_eq(t, "i64") { return "i64"; };
    if str_eq(t, "i128") { return "i128"; };
    if str_eq(t, "u8") { return "i8"; };
    if str_eq(t, "u16") { return "i16"; };
    if str_eq(t, "u32") { return "i32"; };
    if str_eq(t, "u64") { return "i64"; };
    if str_eq(t, "u128") { return "i128"; };
    // Pointer-width: 64-bit on x86_64/aarch64; treat as i64 for now,
    // RFC-0022 cross-compile will adjust per target triple.
    if str_eq(t, "isize") { return "i64"; };
    if str_eq(t, "usize") { return "i64"; };
    // Floats
    if str_eq(t, "f16") { return "half"; };
    if str_eq(t, "bf16") { return "bfloat"; };
    if str_eq(t, "f32") { return "float"; };
    if str_eq(t, "f64") { return "double"; };
    // FP8 — software-emulated; lower as i8 storage with conversion fns.
    if str_eq(t, "f8e4m3") { return "i8"; };
    if str_eq(t, "f8e5m2") { return "i8"; };
    // Char — Unicode scalar value, 32-bit
    if str_eq(t, "char") { return "i32"; };
    if str_eq(t, "bool") { return "i1"; };
    return "i64";
}

// RFC-0015: numeric type predicates
#[manual_drop]
fn is_int_type(t: str) -> i64 {
    if str_eq(t, "i8") == 1 { return 1; };
    if str_eq(t, "i16") == 1 { return 1; };
    if str_eq(t, "i32") == 1 { return 1; };
    if str_eq(t, "i64") == 1 { return 1; };
    if str_eq(t, "i128") == 1 { return 1; };
    if str_eq(t, "isize") == 1 { return 1; };
    if str_eq(t, "u8") == 1 { return 1; };
    if str_eq(t, "u16") == 1 { return 1; };
    if str_eq(t, "u32") == 1 { return 1; };
    if str_eq(t, "u64") == 1 { return 1; };
    if str_eq(t, "u128") == 1 { return 1; };
    if str_eq(t, "usize") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn is_unsigned_type(t: str) -> i64 {
    if str_eq(t, "u8") == 1 { return 1; };
    if str_eq(t, "u16") == 1 { return 1; };
    if str_eq(t, "u32") == 1 { return 1; };
    if str_eq(t, "u64") == 1 { return 1; };
    if str_eq(t, "u128") == 1 { return 1; };
    if str_eq(t, "usize") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn is_float_type(t: str) -> i64 {
    if str_eq(t, "f16") == 1 { return 1; };
    if str_eq(t, "bf16") == 1 { return 1; };
    if str_eq(t, "f32") == 1 { return 1; };
    if str_eq(t, "f64") == 1 { return 1; };
    if str_eq(t, "f8e4m3") == 1 { return 1; };
    if str_eq(t, "f8e5m2") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn is_numeric_type(t: str) -> i64 {
    if is_int_type(t) == 1 { return 1; };
    if is_float_type(t) == 1 { return 1; };
    return 0;
}

// Bit-width of a numeric type. Returns 0 for non-numerics.
#[manual_drop]
fn type_bit_width(t: str) -> i64 {
    if str_eq(t, "i8") == 1 || str_eq(t, "u8") == 1 { return 8; };
    if str_eq(t, "i16") == 1 || str_eq(t, "u16") == 1 { return 16; };
    if str_eq(t, "i32") == 1 || str_eq(t, "u32") == 1 { return 32; };
    if str_eq(t, "i64") == 1 || str_eq(t, "u64") == 1 { return 64; };
    if str_eq(t, "i128") == 1 || str_eq(t, "u128") == 1 { return 128; };
    if str_eq(t, "isize") == 1 || str_eq(t, "usize") == 1 { return 64; };
    if str_eq(t, "f8e4m3") == 1 || str_eq(t, "f8e5m2") == 1 { return 8; };
    if str_eq(t, "f16") == 1 || str_eq(t, "bf16") == 1 { return 16; };
    if str_eq(t, "f32") == 1 { return 32; };
    if str_eq(t, "f64") == 1 { return 64; };
    if str_eq(t, "char") == 1 { return 32; };
    if str_eq(t, "bool") == 1 { return 1; };
    return 0;
}
#[manual_drop]
fn is_ptr_type(t: str) -> i64 {
    if str_eq(t, "str") { return 1; };
    if str_eq(t, "ptr") { return 1; };
    return 0;
}

#[manual_drop]
fn emit_user_externs(pool: Vec<i32>, externs: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(externs) {
        let nid: i64 = vec_get(externs, i);
        let name: str = node_field(pool, nid, 1);
        // detect `extern fn __nucleor_*`
        // declarations that conflict with the compiler-emitted runtime
        // helper IR `declare`s. The runtime helpers all use the
        // i64-everywhere ABI (i64 args, i64 return, even for f64/str
        // payloads which are passed as bit-cast i64). A user `extern fn
        // __nucleor_f64_erf(x: f64) -> f64` declares `declare double @...
        // (double)` -- which then conflicts with the compiler's already-
        // emitted `declare i64 @__nucleor_f64_erf(i64)` and clang fails
        // with `invalid redefinition of function`. The trap I hit on
        // first NUC-FEEDBACK-011 attempt -- saved here for adopters.
        if str_starts_with(name, "__nucleor_") == 1 {
            let bare: str = str_substring(name, 10, str_len(name));
            let mapped: str = get_rt_name(bare);
            // If the bare name maps to this same prefixed name in the
            // runtime table, the compiler already declared it. User's
            // re-declaration is the wrong shape (i64 ABI vs typed).
            if str_eq(mapped, name) == 1 {
                print(str_concat("ERROR: extern fn name '", str_concat(name, "' conflicts with the compiler runtime helper of the same name.")));
                print("  The compiler emits `declare i64 @<name>(i64, ...)` for");
                print("  every runtime helper (i64-everywhere ABI -- f64/str/etc are");
                print("  passed bit-cast through i64). Your typed extern fn declaration");
                print("  emits a second `declare` with conflicting types and clang");
                print("  fails to link with `invalid redefinition of function`.");
                print(str_concat("  Workaround: drop the `extern fn` and just call the bare-name helper directly: `", str_concat(bare, "(...)`.")));
                print("  The compiler's get_rt_name table already maps the bare name");
                print(str_concat("  to `", str_concat(name, "` for you (i64 ABI applied automatically).")));
                panic(str_concat("extern fn redeclares runtime helper: ", name));
            };
        };
        let plist: i64 = node_field(pool, nid, 2);
        let rtype: str = node_field(pool, nid, 3);
        let pc: i64 = list_len(pool, plist);
        sb_append(sb, "declare ");
        sb_append(sb, nr_type_to_llvm(rtype));
        sb_append(sb, " @"); sb_append(sb, name); sb_append(sb, "(");
        let mut pi: i64 = 0;
        while pi < pc {
            if pi > 0 { sb_append(sb, ", "); };
            let pnid: i64 = list_get(pool, plist, pi);
            let ptype: str = node_field(pool, pnid, 2);
            sb_append(sb, nr_type_to_llvm(ptype));
            pi = pi + 1;
        };
        sb_append(sb, ")\n");
        i = i + 1;
    };
    return sb_to_str(sb);
}

// DCE at rod-import boundary.
// Collect the set of fn names reachable from roots:
//   - "main" (the entry point)
//   - All #[export]-marked fns (callable from C/C++ via FFI)
//   - All fns whose address is taken (op 29 = fn_ptr)
// Walks the call graph via op 19 (rt-call) and op 31 (user-call)
// edges. Returns the set of reachable fn names. Use case: programs
// that `use stdlib::rods::heavy_rod;` but only call one of its 50 fns
// — pre-DCE all 50 emit, post-DCE only the 1 + transitive callees +
// roots emit. Library-only compiles (no main, no #[export]) skip DCE
// and keep all fns to avoid breaking the link.
#[manual_drop]
fn dce_collect_reachable(fns: Vec<i32>, src: str) -> Vec<i32> {
    let nf: i64 = vec_len(fns);
    let mut visited: Vec<i32> = Vec::new();
    if nf == 0 { return visited; };
    let mut worklist: Vec<i32> = Vec::new();
    worklist.push("main");
    let empty_repr: Vec<i32> = Vec::new();
    let exports: Vec<i32> = collect_export_fns_and_sigs(src, empty_repr);
    let nexp: i64 = vec_len(exports);
    let mut ei: i64 = 0;
    while ei + 2 < nexp {
        worklist.push(vec_get(exports, ei));
        ei = ei + 3;
    };
    // RFC-0008: ISR roots are externally entered by the vector table,
    // so DCE must retain them even when `main` does not call them.
    let isr_roots: Vec<i32> = collect_isr_fns(src);
    let mut isri: i64 = 0;
    while isri < vec_len(isr_roots) {
        worklist.push(vec_get(isr_roots, isri));
        isri = isri + 1;
    };
    // Pre-scan all fns for op 29 (fn_ptr) — addressed fns must be kept.
    let mut fi: i64 = 0;
    while fi < nf {
        let f: Vec<i32> = vec_get(fns, fi);
        let nblocks: i64 = ir_fn_block_count(f);
        let mut bi: i64 = 0;
        while bi < nblocks {
            let blk: Vec<i32> = ir_fn_get_block(f, bi);
            let nins: i64 = ir_block_inst_count(blk);
            let mut ii: i64 = 0;
            while ii < nins {
                let inst: Vec<i32> = ir_block_get_inst(blk, ii);
                if ir_op(inst) == 29 { worklist.push(ir_op1(inst)); };
                ii = ii + 1;
            };
            bi = bi + 1;
        };
        fi = fi + 1;
    };
    // BFS over call edges.
    while vec_len(worklist) > 0 {
        let name: str = vec_get(worklist, vec_len(worklist) - 1);
        vec_pop(worklist);
        let nv: i64 = vec_len(visited);
        let mut already: i64 = 0;
        let mut vi: i64 = 0;
        while vi < nv {
            if str_eq(vec_get(visited, vi), name) == 1 { already = 1; vi = nv; };
            vi = vi + 1;
        };
        if already == 1 { continue; };
        visited.push(name);
        let mut found_idx: i64 = 0 - 1;
        let mut sf: i64 = 0;
        while sf < nf {
            let cf: Vec<i32> = vec_get(fns, sf);
            if str_eq(ir_fn_name(cf), name) == 1 { found_idx = sf; sf = nf; };
            sf = sf + 1;
        };
        if found_idx < 0 { continue; };
        let f: Vec<i32> = vec_get(fns, found_idx);
        let nblocks: i64 = ir_fn_block_count(f);
        let mut bi: i64 = 0;
        while bi < nblocks {
            let blk: Vec<i32> = ir_fn_get_block(f, bi);
            let nins: i64 = ir_block_inst_count(blk);
            let mut ii: i64 = 0;
            while ii < nins {
                let inst: Vec<i32> = ir_block_get_inst(blk, ii);
                let op: i64 = ir_op(inst);
                if op == 19 || op == 31 || op == 29 {
                    worklist.push(ir_op1(inst));
                };
                ii = ii + 1;
            };
            bi = bi + 1;
        };
    };
    return visited;
}

#[manual_drop]
// Closure-environment runtime. Emitted as LLVM function definitions
// into every program's .ll output (DCE elides them if unused).
// Layout (i64 offset → field):
//   0  refcount    (1 at construction; incremented on retain, decremented
//                   on release; env is freed when release brings it to 0)
//   1  fn_ptr      (address of the closure body function)
//   2  cap_count   (number of capture slots)
//   3+ caps        (i64 each)
// Closure value at the surface is `env_ptr | 1` (low-bit tag). The bare
// `env_ptr` (the heap address) is what these helpers operate on; box/unbox
// is the conversion between the surface value and the env pointer.
// Thread safety: non-atomic. Closures inherit the language's existing
// "shared mutable state is the caller's responsibility" rule (matches
// Vec/str). Documented in docs/internals/closures.md.
#[manual_drop]
fn emit_closure_runtime() -> str {
    let mut sb: i64 = sb_new();

    sb_append(sb, "define i64 @nuc_closure_env_new(i64 %fn_ptr, i64 %cap_count) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %total_slots = add i64 %cap_count, 3\n");
    sb_append(sb, "  %nbytes = mul i64 %total_slots, 8\n");
    sb_append(sb, "  %p = call ptr @malloc(i64 %nbytes)\n");
    sb_append(sb, "  %is_null = icmp eq ptr %p, null\n");
    sb_append(sb, "  br i1 %is_null, label %oom, label %ok\n");
    sb_append(sb, "oom:\n");
    sb_append(sb, "  %nul.panic = call i64 @__nucleor_panic(ptr @.nuc_closure_oom_msg)\n");
    sb_append(sb, "  unreachable\n");
    sb_append(sb, "ok:\n");
    sb_append(sb, "  store i64 1, ptr %p, align 8\n");
    sb_append(sb, "  %off_fn = getelementptr i64, ptr %p, i64 1\n");
    sb_append(sb, "  store i64 %fn_ptr, ptr %off_fn, align 8\n");
    sb_append(sb, "  %off_cnt = getelementptr i64, ptr %p, i64 2\n");
    sb_append(sb, "  store i64 %cap_count, ptr %off_cnt, align 8\n");
    sb_append(sb, "  %env = ptrtoint ptr %p to i64\n");
    sb_append(sb, "  ret i64 %env\n");
    sb_append(sb, "}\n");

    sb_append(sb, "define i64 @nuc_closure_env_retain(i64 %env) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %p = inttoptr i64 %env to ptr\n");
    sb_append(sb, "  %rc_old = load i64, ptr %p, align 8\n");
    sb_append(sb, "  %rc_new = add i64 %rc_old, 1\n");
    sb_append(sb, "  store i64 %rc_new, ptr %p, align 8\n");
    sb_append(sb, "  ret i64 %env\n");
    sb_append(sb, "}\n");

    sb_append(sb, "define i64 @nuc_closure_env_release(i64 %env) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %is_zero = icmp eq i64 %env, 0\n");
    sb_append(sb, "  br i1 %is_zero, label %ret_zero, label %check_rc\n");
    sb_append(sb, "ret_zero:\n");
    sb_append(sb, "  ret i64 0\n");
    sb_append(sb, "check_rc:\n");
    sb_append(sb, "  %p = inttoptr i64 %env to ptr\n");
    sb_append(sb, "  %rc = load i64, ptr %p, align 8\n");
    sb_append(sb, "  %is_last = icmp sle i64 %rc, 1\n");
    sb_append(sb, "  br i1 %is_last, label %do_free, label %dec\n");
    sb_append(sb, "do_free:\n");
    sb_append(sb, "  call void @free(ptr %p)\n");
    sb_append(sb, "  ret i64 0\n");
    sb_append(sb, "dec:\n");
    sb_append(sb, "  %rc_new = sub i64 %rc, 1\n");
    sb_append(sb, "  store i64 %rc_new, ptr %p, align 8\n");
    sb_append(sb, "  ret i64 %rc_new\n");
    sb_append(sb, "}\n");

    sb_append(sb, "define i64 @nuc_closure_env_set_cap(i64 %env, i64 %idx, i64 %val) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %p = inttoptr i64 %env to ptr\n");
    sb_append(sb, "  %off = add i64 %idx, 3\n");
    sb_append(sb, "  %slot = getelementptr i64, ptr %p, i64 %off\n");
    sb_append(sb, "  store i64 %val, ptr %slot, align 8\n");
    sb_append(sb, "  ret i64 %val\n");
    sb_append(sb, "}\n");

    sb_append(sb, "define i64 @nuc_closure_env_get_cap(i64 %env, i64 %idx) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %p = inttoptr i64 %env to ptr\n");
    sb_append(sb, "  %off = add i64 %idx, 3\n");
    sb_append(sb, "  %slot = getelementptr i64, ptr %p, i64 %off\n");
    sb_append(sb, "  %v = load i64, ptr %slot, align 8\n");
    sb_append(sb, "  ret i64 %v\n");
    sb_append(sb, "}\n");

    sb_append(sb, "define i64 @nuc_closure_env_fn_ptr(i64 %env) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %p = inttoptr i64 %env to ptr\n");
    sb_append(sb, "  %off = getelementptr i64, ptr %p, i64 1\n");
    sb_append(sb, "  %fn = load i64, ptr %off, align 8\n");
    sb_append(sb, "  ret i64 %fn\n");
    sb_append(sb, "}\n");

    sb_append(sb, "define i64 @nuc_closure_box(i64 %env) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %r = or i64 %env, 1\n");
    sb_append(sb, "  ret i64 %r\n");
    sb_append(sb, "}\n");

    sb_append(sb, "define i64 @nuc_closure_unbox(i64 %raw) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %r = and i64 %raw, -2\n");
    sb_append(sb, "  ret i64 %r\n");
    sb_append(sb, "}\n");

    // Auto-drop helper: accepts a boxed closure value (env_ptr | 1),
    // unboxes, and releases the env. Safe on zero (env=0 → release
    // short-circuits). Tag-checked: if low bit is 0 (not a closure
    // value), no-op — so the helper is safe to wire to any i64 local
    // even if the binding doesn't actually hold a closure (the binding
    // would only do that if mis-registered; we don't do that, but the
    // check is cheap insurance).
    sb_append(sb, "define i64 @nuc_closure_release_boxed(i64 %raw) {\n");
    sb_append(sb, "entry:\n");
    sb_append(sb, "  %tag = and i64 %raw, 1\n");
    sb_append(sb, "  %is_clo = icmp ne i64 %tag, 0\n");
    sb_append(sb, "  br i1 %is_clo, label %do_release, label %skip\n");
    sb_append(sb, "do_release:\n");
    sb_append(sb, "  %env = and i64 %raw, -2\n");
    sb_append(sb, "  %rcr = call i64 @nuc_closure_env_release(i64 %env)\n");
    sb_append(sb, "  ret i64 0\n");
    sb_append(sb, "skip:\n");
    sb_append(sb, "  ret i64 0\n");
    sb_append(sb, "}\n");

    return sb_to_str(sb);
}

#[manual_drop]
fn emit_module_ext(fns: Vec<i32>, strtab: Vec<i32>, pool: Vec<i32>, externs: Vec<i32>, src: str) -> str {
    // Pre-size the IR builder to ~2 MB. The s1 self-host produces
    // 2.7 MB of IR; without pre-sizing the SB grows from 256 B
    // through 14 reallocs (256→512→…→4M), each copying the
    // previous buffer. With 2 MB initial we hit at most 1 realloc
    // for the final stretch, saving ~10 MB of cumulative
    // allocator churn per self-host compile.
    let mut sb: i64 = sb_new_with_cap(2097152);
    sb_append(sb, emit_externs());
    sb_append(sb, emit_user_externs(pool, externs));
    sb_append(sb, emit_str_constants(strtab));
    sb_append(sb, emit_closure_runtime());
    // always-emit .nucleor_provenance section
    sb_append(sb, emit_provenance_section());
    // detect same-name pub fn collisions across
    // imported modules BEFORE clang sees the IR. Pre-fix, two modules
    // both declaring `pub fn error_kind_to_str` (with different param
    // types -- structural typing erases that at IR level) emitted two
    // `define i64 @error_kind_to_str(...)` blocks; clang failed with
    // `invalid redefinition of function`. The diagnostic landed in
    // clang's compile log, far away from the actual culprits. Now we
    // catch it at compile time with a precise message naming the
    // duplicate symbol; user can resolve by renaming one definition
    // (already the recommended naming convention).
    // DCE filter. With main or any #[export], only
    // emit reachable fns. Library-only compiles (no roots) keep all to
    // avoid breaking the link.
    let dce_set: Vec<i32> = dce_collect_reachable(fns, src);
    let dce_active: i64 = if vec_len(dce_set) > 0 { 1 } else { 0 };
    let mut dce_skipped: i64 = 0;
    let mut seen_fns: Vec<i32> = Vec::new();
    let isr_entries: Vec<i32> = collect_isr_entries(src);
    let isr_target: str = isr_target_for_compile();
    let mut fi: i64 = 0;
    while fi < vec_len(fns) {
        let f: Vec<i32> = vec_get(fns, fi);
        let fn_name: str = ir_fn_name(f);
        if dce_active == 1 && str_len(fn_name) > 0 {
            let mut keep: i64 = 0;
            let nds: i64 = vec_len(dce_set);
            let mut di: i64 = 0;
            while di < nds {
                if str_eq(vec_get(dce_set, di), fn_name) == 1 { keep = 1; di = nds; };
                di = di + 1;
            };
            if keep == 0 {
                dce_skipped = dce_skipped + 1;
                free_ir_fn(f);
                fi = fi + 1;
                continue;
            };
        };
        // skip empty / generated names (they get unique numeric suffixes)
        if str_len(fn_name) > 0 && str_eq(fn_name, "main") == 0 {
            let mut sj: i64 = 0;
            while sj < vec_len(seen_fns) {
                if str_eq(vec_get(seen_fns, sj), fn_name) == 1 {
                    //  when fn_name has
                    // shape `<Type>__<method>`, the collision is most
                    // likely two trait impls of the same method name on
                    // the same struct (Rust E0034 territory) — NOT a
                    // cross-module duplicate. The pre-fix diag misled
                    // adopters who hit Rust's canonical "ambiguous
                    // method dispatch" pattern by suggesting a
                    // workaround ("rename one of the definitions") that
                    // doesn't apply (the names are forced by the trait
                    // signatures). Detect the `Type__method` shape and
                    // emit a UFCS-disambiguation diag instead.
                    let mut dunder_pos: i64 = 0 - 1;
                    let fnlen_v060: i64 = str_len(fn_name);
                    let mut sii: i64 = 0;
                    while sii < fnlen_v060 - 1 {
                        if str_char_at(fn_name, sii) == 95 && str_char_at(fn_name, sii + 1) == 95 {
                            dunder_pos = sii;
                            sii = fnlen_v060;
                        } else {
                            sii = sii + 1;
                        };
                    };
                    let looks_like_method: i64 = if dunder_pos > 0 && dunder_pos < fnlen_v060 - 2 { 1 } else { 0 };
                    let first_char_upper: i64 = if fnlen_v060 > 0 {
                        let fc_v060: i64 = str_char_at(fn_name, 0);
                        if fc_v060 >= 65 && fc_v060 <= 90 { 1 } else { 0 }
                    } else { 0 };
                    if looks_like_method == 1 && first_char_upper == 1 {
                        let type_name_v060: str = str_substring(fn_name, 0, dunder_pos);
                        let method_name_v060: str = str_substring(fn_name, dunder_pos + 2, fnlen_v060);
                        // Lane 1 audit fix (2026-05-08) — partial close
                        // of F-019. Pre-fix the original message was
                        // "ERROR: ambiguous method ..." with no
                        // diagnostic code; this revision routes through
                        // the canonical `error[TYP-043]:` shape so
                        // downstream tooling can match it. The trailing
                        // PANIC line below remains cosmetic — eliminating
                        // it requires a new runtime helper + bootstrap
                        // re-iteration which the current shipping binary
                        // can't yet resolve at build-time. Tracked for
                        // forward-roadmap (PANIC-as-diagnostic anti-
                        // pattern documented as CL-4 in the typesystem
                        // audit).
                        print(str_concat("error[TYP-043]: ambiguous method `", str_concat(type_name_v060, str_concat("::", str_concat(method_name_v060, "()` — two trait impls on the same struct define this method name (Rust E0034)")))));
                        print(str_concat("  `", str_concat(type_name_v060, str_concat("` has two impls defining `", str_concat(method_name_v060, "()`. Nucleor mangles trait-impl method names as `<Type>__<method>` for the LLVM symbol, so two impls of the same method name on the same struct collide at link time."))))));
                        print(str_concat("  Workaround until full UFCS lands: rename one trait's method (e.g. `", str_concat(method_name_v060, str_concat("_v1` / `", str_concat(method_name_v060, "_v2`), or split the impls across distinct concrete types so the mangled symbols differ."))))));
                        print("  This is Rust's E0034 \"multiple applicable items in scope\" territory — the long-term fix is UFCS disambiguation `<Type as Trait>::method(&self)` but Nucleor's lowering doesn't yet support that surface (forward-roadmap).");
                        // route through __nucleor_diag_exit so the trailing
                        // "PANIC:" line is suppressed in favor of a clean
                        // exit(1). The runtime helper was staged by Lane 1;
                        // this bootstrap iteration wires the call site.
                        diag_exit();
                        panic(str_concat("ambiguous method dispatch: ", fn_name));
                    };
                    print(str_concat("ERROR: duplicate top-level fn name '", str_concat(fn_name, "'")));
                    print("  Two modules in this compile unit both declare a `pub fn` with");
                    print("  this name. Nucleor emits one LLVM `define @<name>` per fn and");
                    print("  doesn't namespace by source module, so the link fails.");
                    print("  Workaround: rename one of the definitions (convention");
                    print("  `<module>_<fn>`, e.g. `config_error_kind_to_str` /");
                    print("  `pipeline_error_kind_to_str`) until module-prefixed lowering");
                    print("  lands in a future release (RFC-NRT-004 §H).");
                    panic(str_concat("duplicate pub fn name across modules: ", fn_name));
                };
                sj = sj + 1;
            };
            seen_fns.push(fn_name);
        };
        if name_in_isr_entries(isr_entries, fn_name) == 1 {
            sb_append(sb, "; nucleor.isr target=");
            sb_append(sb, isr_target);
            sb_append(sb, " fn @");
            sb_append(sb, fn_name);
            sb_append(sb, " interrupt_cc\n");
        };
        sb_append(sb, emit_fn(f, pool, externs)); sb_append(sb, "\n");
        free_ir_fn(f);
        fi = fi + 1;
    };
    if dce_active == 1 && dce_skipped > 0 {
        print(str_concat("  DCE: ", str_concat(str_from_int(dce_skipped),
            str_concat(" of ", str_concat(str_from_int(vec_len(fns)),
                " fns elided as unreachable")))));
    };
    let out: str = sb_to_str(sb);
    vec_free(dce_set);
    vec_free(seen_fns);
    vec_free(isr_entries);
    return out;
}
