# Track B 3e.1 LLVM Overflow Intrinsic Spike

Date: 2026-04-30

Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_b`

Branch: `v05-spike-3e1`

Base: `a75bb22 v0.4.227: v0.5 residual sequencing doc - sub-ships scoped + ordered`

Status: local spike complete. No push. Main checkout was not edited.

## Scope

This spike wires env-gated signed LLVM overflow-intrinsic arithmetic for integer `+`, `-`, and `*`.

Gate: `NUCLEOR_INT_STRICT_INTRIN=1`

Off path: normal arithmetic lowering remains selected, and generated IR has no overflow-intrinsic calls, declarations, or panic message global.

On path:

- IR opcodes 35/36/37 mirror add/sub/mul.
- `tid` carries width, with `0` meaning i64.
- `extra` carries the trap label; the continuation label is `trap + 1`.
- LLVM emission calls `@llvm.s{add,sub,mul}.with.overflow.iN`, extracts result and flag, branches on the flag, calls `__nucleor_panic(ptr @.nuc_overflow_intrin_msg)`, then continues from the non-overflow label.
- DCE marks operands live and treats these ops as side-effecting by leaving them out of removable pure-op candidates.

## Validation

All compiles below used the repo's process-tree memory e-stop script with a 1024 MB budget.

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\measure_peak_build.ps1 -Source compiler/nucleor_s1_compiler.nr -OutName nuc_s1_track_b -BudgetMb 1024 -TimeoutSec 180
OK: compiler/nucleor_s1_compiler.nr peak 454 MB / 1024 MB budget, wall 3.985s
```

The rebuilt compiler was promoted only inside this Track B worktree:

```text
Copy-Item .\target\nuc_s1_track_b.exe .\bin\nucleor.exe -Force
```

Env-on smoke compile:

```text
$env:NUCLEOR_INT_STRICT_INTRIN='1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\measure_peak_build.ps1 -Source target\track_b_intrin_smoke.nr -OutName track_b_intrin_smoke -BudgetMb 1024 -TimeoutSec 60
OK: target\track_b_intrin_smoke.nr peak 0 MB / 1024 MB budget, wall 0.848s
```

Env-on IR evidence:

```text
357: @.nuc_overflow_intrin_msg = private unnamed_addr constant [17 x i8] c"integer overflow\00"
883: %r.6.ov = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %r.4, i64 %r.5)
884: %r.6 = extractvalue { i64, i1 } %r.6.ov, 0
885: %r.6.of = extractvalue { i64, i1 } %r.6.ov, 1
886: br i1 %r.6.of, label %L0, label %L1
888: %r.6.panic = call i64 @__nucleor_panic(ptr @.nuc_overflow_intrin_msg)
904: %r.6.ov = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %r.4, i64 %r.5)
925: %r.6.ov = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %r.4, i64 %r.5)
```

Env-off smoke compile:

```text
Remove-Item Env:\NUCLEOR_INT_STRICT_INTRIN -ErrorAction SilentlyContinue
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\measure_peak_build.ps1 -Source target\track_b_intrin_smoke.nr -OutName track_b_intrin_smoke_off -BudgetMb 1024 -TimeoutSec 60
OK: target\track_b_intrin_smoke.nr peak 0 MB / 1024 MB budget, wall 0.977s
```

Env-off IR gate evidence:

```text
overflow_call_count=0
overflow_decl_or_msg_count=0
```

Runtime trap smoke:

```text
$env:NUCLEOR_INT_STRICT_INTRIN='1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\measure_peak_build.ps1 -Source target\track_b_overflow_trap.nr -OutName track_b_overflow_trap -BudgetMb 1024 -TimeoutSec 60
OK: target\track_b_overflow_trap.nr peak 0 MB / 1024 MB budget, wall 0.7s

.\target\track_b_overflow_trap.exe
exit_code=1
stderr=PANIC: integer overflow\n
```

Clean diff check:

```text
git diff --check
exit 0
```

Full `tools/verify.sh` was not run for this spike pass. The Windows checkout currently has only `bin\nucleor.exe`, while `verify.sh` selects `bin/nucleor` under MINGW/CYGWIN. The targeted checks above cover the changed compiler path, the env-off gate, linking, and the actual overflow panic behavior.

## Memory And Perf Notes

- No compile exceeded the 1024 MB e-stop budget.
- Self-build peak under process-tree monitoring was 454 MB for the final compiler build.
- The smoke compiles completed too quickly for the 100 ms poller to catch non-zero RSS; the guard still watched and would have killed an over-budget process tree.
- `tools/check_perf_regression.ps1` was not used because it kills all `nucleor*` and `clang*` processes globally before measuring and its built-in peak check watches the root process, not the process tree. For this shared-machine spike, `tools/measure_peak_build.ps1` was the safer guardrail.

## Open Questions

- The handoff mentioned `__nucleor_panic_overflow`, but this checkout only has the generic `__nucleor_panic(ptr)` plus operation-specific `panic_*_i64` helpers. This spike uses `__nucleor_panic(ptr @.nuc_overflow_intrin_msg)` so no runtime C changes were needed.
- The smoke fixture produced i64 intrinsic calls. The declarations are ready for i8/i16/i32/i64, but typed narrow coverage should be folded into the phase 3 typed-width fixture pass rather than overclaiming here.
- This worktree was cut from clean `HEAD` (`a75bb22`), not from the dirty main checkout. Integrating after 3span work will require applying this against whatever substrate lands there.

## Raw Diff

```diff
diff --git a/compiler/nucleor_s1_compiler.nr b/compiler/nucleor_s1_compiler.nr
index 233b929..daea068 100644
--- a/compiler/nucleor_s1_compiler.nr
+++ b/compiler/nucleor_s1_compiler.nr
@@ -3113,6 +3113,18 @@ fn ir_binop(iop: i64, d: i64, a: i64, b: i64) -> Vec<i32> { return ir_inst(iop,
 // reads tid: 0 stays at i64 (byte-identical fast path); >0 emits
 // `<op> iN`. Caller is lower_expr kind 4 narrow path.
 fn ir_binop_t(iop: i64, d: i64, a: i64, b: i64, w: i64) -> Vec<i32> { return ir_inst(iop, d, w, a, b, 0); }
+// v0.5 3e.1 spike: signed LLVM overflow-intrinsic arithmetic.
+// Opcodes 35/36/37 mirror add/sub/mul. tid carries width (0 => i64),
+// extra carries the trap label; the continuation label is trap + 1.
+fn ir_add_with_overflow(d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> Vec<i32> { return ir_inst(35, d, w, a, b, trap_lbl); }
+fn ir_sub_with_overflow(d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> Vec<i32> { return ir_inst(36, d, w, a, b, trap_lbl); }
+fn ir_mul_with_overflow(d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> Vec<i32> { return ir_inst(37, d, w, a, b, trap_lbl); }
+fn ir_binop_overflow(iop: i64, d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> Vec<i32> {
+    if iop == 2 { return ir_add_with_overflow(d, a, b, w, trap_lbl); };
+    if iop == 3 { return ir_sub_with_overflow(d, a, b, w, trap_lbl); };
+    if iop == 4 { return ir_mul_with_overflow(d, a, b, w, trap_lbl); };
+    return ir_binop_t(iop, d, a, b, w);
+}
 fn ir_cmpop(iop: i64, d: i64, a: i64, b: i64) -> Vec<i32> { return ir_inst(iop, d, 0, a, b, 0); }
 fn ir_alloca(d: i64) -> Vec<i32> { return ir_inst(16, d, 0, 0, 0, 0); }
 fn ir_load(d: i64, ptr: i64) -> Vec<i32> { return ir_inst(17, d, 0, ptr, 0, 0); }
@@ -3501,6 +3513,9 @@ fn opt_dce_block(blk: Vec<i32>) -> i64 {
         // Collect register operands that are used
         if op >= 2 && op <= 15 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
         else if op == 23 || op == 24 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
+        // Overflow-intrinsic arithmetic is side-effecting from the optimizer's
+        // point of view because it emits a flag branch plus panic path.
+        else if op == 35 || op == 36 || op == 37 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
         else if op == 17 { used.push(ir_op1(inst)); }
         else if op == 18 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
         // v0.4.209: sext/zext/trunc ops use ir_op1 as source register.
@@ -5194,6 +5209,38 @@ fn emit_arith_w(sb: i64, on: str, d: i64, a: i64, b: i64, w: i64) -> i64 {
     sb_append(sb, ", %r."); sb_append(sb, str_from_int(b));
     sb_append(sb, "\n"); return 0;
 }
+fn emit_overflow_arith(sb: i64, on: str, d: i64, a: i64, b: i64, w: i64, trap_lbl: i64) -> i64 {
+    let bw: i64 = if w == 0 { 64 } else { w };
+    let ty: str = width_to_llvm_type(bw);
+    let ds: str = str_from_int(d);
+    let a_s: str = str_from_int(a);
+    let b_s: str = str_from_int(b);
+    let trap_s: str = str_from_int(trap_lbl);
+    let cont_s: str = str_from_int(trap_lbl + 1);
+    sb_append(sb, "  %r."); sb_append(sb, ds);
+    sb_append(sb, ".ov = call { "); sb_append(sb, ty);
+    sb_append(sb, ", i1 } @llvm.s"); sb_append(sb, on);
+    sb_append(sb, ".with.overflow."); sb_append(sb, ty);
+    sb_append(sb, "("); sb_append(sb, ty); sb_append(sb, " %r.");
+    sb_append(sb, a_s); sb_append(sb, ", "); sb_append(sb, ty);
+    sb_append(sb, " %r."); sb_append(sb, b_s); sb_append(sb, ")\n");
+    sb_append(sb, "  %r."); sb_append(sb, ds);
+    sb_append(sb, " = extractvalue { "); sb_append(sb, ty);
+    sb_append(sb, ", i1 } %r."); sb_append(sb, ds);
+    sb_append(sb, ".ov, 0\n");
+    sb_append(sb, "  %r."); sb_append(sb, ds);
+    sb_append(sb, ".of = extractvalue { "); sb_append(sb, ty);
+    sb_append(sb, ", i1 } %r."); sb_append(sb, ds);
+    sb_append(sb, ".ov, 1\n");
+    sb_append(sb, "  br i1 %r."); sb_append(sb, ds);
+    sb_append(sb, ".of, label %L"); sb_append(sb, trap_s);
+    sb_append(sb, ", label %L"); sb_append(sb, cont_s);
+    sb_append(sb, "\nL"); sb_append(sb, trap_s); sb_append(sb, ":\n");
+    sb_append(sb, "  %r."); sb_append(sb, ds);
+    sb_append(sb, ".panic = call i64 @__nucleor_panic(ptr @.nuc_overflow_intrin_msg)\n");
+    sb_append(sb, "  unreachable\nL"); sb_append(sb, cont_s); sb_append(sb, ":\n");
+    return 0;
+}
 fn find_extern_idx(pool: Vec<i32>, externs: Vec<i32>, name: str) -> i64 {
     let mut i: i64 = 0;
     while i < vec_len(externs) {
@@ -5353,6 +5400,9 @@ fn emit_inst(inst: Vec<i32>, sb: i64, pool: Vec<i32>, externs: Vec<i32>) -> i64
         sb_append(sb, " %r."); sb_append(sb, str_from_int(ir_op1(inst)));
         sb_append(sb, " to i64\n");
     }
+    else if op == 35 { emit_overflow_arith(sb, "add", d, ir_op1(inst), ir_op2(inst), ir_tid(inst), ir_extra(inst)); }
+    else if op == 36 { emit_overflow_arith(sb, "sub", d, ir_op1(inst), ir_op2(inst), ir_tid(inst), ir_extra(inst)); }
+    else if op == 37 { emit_overflow_arith(sb, "mul", d, ir_op1(inst), ir_op2(inst), ir_tid(inst), ir_extra(inst)); }
     else if op == 19 {
         let fn_name: str = ir_op1(inst); let argc: i64 = ir_op2(inst); let args: Vec<i32> = ir_extra(inst);
         let ext_idx: i64 = find_extern_idx(pool, externs, fn_name);
@@ -5844,6 +5894,22 @@ fn emit_externs() -> str {
     sb_append(sb, "declare i64 @__nucleor_assert_eq(i64, i64)\n");
     sb_append(sb, "declare i64 @__nucleor_assert_ne(i64, i64)\n");
     sb_append(sb, "declare i64 @__nucleor_panic(ptr)\n");
+    let strict_intrin: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "");
+    if str_eq(strict_intrin, "1") == 1 {
+        sb_append(sb, "@.nuc_overflow_intrin_msg = private unnamed_addr constant [17 x i8] c\"integer overflow\\00\"\n");
+        sb_append(sb, "declare { i8, i1 } @llvm.sadd.with.overflow.i8(i8, i8)\n");
+        sb_append(sb, "declare { i16, i1 } @llvm.sadd.with.overflow.i16(i16, i16)\n");
+        sb_append(sb, "declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32)\n");
+        sb_append(sb, "declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64)\n");
+        sb_append(sb, "declare { i8, i1 } @llvm.ssub.with.overflow.i8(i8, i8)\n");
+        sb_append(sb, "declare { i16, i1 } @llvm.ssub.with.overflow.i16(i16, i16)\n");
+        sb_append(sb, "declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32)\n");
+        sb_append(sb, "declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64)\n");
+        sb_append(sb, "declare { i8, i1 } @llvm.smul.with.overflow.i8(i8, i8)\n");
+        sb_append(sb, "declare { i16, i1 } @llvm.smul.with.overflow.i16(i16, i16)\n");
+        sb_append(sb, "declare { i32, i1 } @llvm.smul.with.overflow.i32(i32, i32)\n");
+        sb_append(sb, "declare { i64, i1 } @llvm.smul.with.overflow.i64(i64, i64)\n");
+    };
     sb_append(sb, "declare i64 @__nucleor_as_i8(i64)\n");
     sb_append(sb, "declare i64 @__nucleor_as_i16(i64)\n");
     sb_append(sb, "declare i64 @__nucleor_as_i32(i64)\n");
@@ -14329,7 +14395,7 @@ fn detect_narrow_chain(pool: Vec<i32>, nid: i64, sym: Vec<i32>, fir: Vec<i32>) -
 // Pre-condition: detect_narrow_chain(pool, nid, sym, fir) returned
 // the same `tw`. Caller is the only entry point — this fn does no
 // re-validation.
-fn lower_expr_narrow(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, tw: i64) -> Vec<i32> {
+fn lower_expr_narrow(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, tw: i64) -> Vec<i32> {
     let aw: i64 = if tw > 0 { tw } else { 0 - tw };
     let k: i64 = node_kind(pool, nid);
     if k == 1 {
@@ -14349,14 +14415,21 @@ fn lower_expr_narrow(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, sy
     };
     if k == 4 {
         let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
-        let mut lp: Vec<i32> = lower_expr_narrow(pool, node_field(pool, nid, 2), blk, regs, sym, fir, tw);
+        let mut lp: Vec<i32> = lower_expr_narrow(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, tw);
         let lr: i64 = lx_reg(lp);
         let mut blk2: Vec<i32> = lx_blk(lp);
-        let mut rp: Vec<i32> = lower_expr_narrow(pool, node_field(pool, nid, 3), blk2, regs, sym, fir, tw);
+        let mut rp: Vec<i32> = lower_expr_narrow(pool, node_field(pool, nid, 3), blk2, regs, lbls, sym, fir, tw);
         let rr: i64 = lx_reg(rp);
         let mut blk3: Vec<i32> = lx_blk(rp);
         let nr: i64 = ctr_next(regs);
-        ir_block_add(blk3, ir_binop_t(iop, nr, lr, rr, aw));
+        let strict_intrin: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "");
+        if str_eq(strict_intrin, "1") == 1 && (iop == 2 || iop == 3 || iop == 4) {
+            let trap_lbl: i64 = ctr_next(lbls);
+            let cont_lbl: i64 = ctr_next(lbls);
+            ir_block_add(blk3, ir_binop_overflow(iop, nr, lr, rr, aw, trap_lbl));
+        } else {
+            ir_block_add(blk3, ir_binop_t(iop, nr, lr, rr, aw));
+        };
         return lx_new(nr, blk3);
     };
     // Unreachable if detect_narrow_chain is correct. Fail-safe: return -1.
@@ -14624,7 +14697,7 @@ fn lower_expr(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec
         let v213_w: i64 = detect_narrow_chain(pool, nid, sym, fir);
         if v213_w != 0 {
             let v213_aw: i64 = if v213_w > 0 { v213_w } else { 0 - v213_w };
-            let mut v213_p: Vec<i32> = lower_expr_narrow(pool, nid, blk, regs, sym, fir, v213_w);
+            let mut v213_p: Vec<i32> = lower_expr_narrow(pool, nid, blk, regs, lbls, sym, fir, v213_w);
             let v213_nr: i64 = lx_reg(v213_p);
             let mut v213_blk: Vec<i32> = lx_blk(v213_p);
             let v213_wr: i64 = ctr_next(regs);
@@ -14878,7 +14951,12 @@ fn lower_expr(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec
                     if iop == 24 { sh = "panic_shr"; };
                 };
             };
-            if str_len(sh) > 0 {
+            let strict_intrin: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "");
+            if str_eq(strict_intrin, "1") == 1 && (iop == 2 || iop == 3 || iop == 4) {
+                let trap_lbl: i64 = ctr_next(lbls);
+                let cont_lbl: i64 = ctr_next(lbls);
+                ir_block_add(cur, ir_binop_overflow(iop, r, lr, rr, 0, trap_lbl));
+            } else if str_len(sh) > 0 {
                 let mut sa: Vec<i32> = Vec::new();
                 sa.push(lr); sa.push(rr);
                 ir_block_add(cur, ir_call_ex(r, sh, sa));
```
