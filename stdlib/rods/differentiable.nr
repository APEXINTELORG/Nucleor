// rods/differentiable — RFC-0045 Phase A: differentiability
// metadata registry (rod-only). Closes the V1.14 drift-
// restoration lane.
//
// The full RFC-0045 ship parses `@differentiable` as a fn-decl
// attribute and emits a `__nucleor_diff_<fn>` symbol alias for
// the autodiff runtime to discover differentiable fns at link
// time (~50 LOC compiler-side, deferred). Phase A (this rod)
// provides a runtime registry surface adopters call from fn
// bodies to declare differentiability programmatically — same
// metadata-only V1.x advisory scope.
//
// This is the third and final drift-restoration ship of the
// V1.12-V1.14 lane:
//   - RFC-0043 Phase A — fixed-point Q-format helpers (v0.7.91)
//   - RFC-0044 Phase A — overflow-mode helpers (v0.7.92)
//   - RFC-0045 Phase A — differentiable metadata (this ship)
//
// The autodiff rod (`stdlib/rods/autodiff.nr`) is fully shipped
// with reverse-mode AD + tape reset + checkpointing; this rod
// adds the *discovery* layer Phase B will wire to symbol-table
// dispatch.
//
// Workflow today:
//
//   import "stdlib/rods/differentiable.nr"
//
//   fn loss(x: i64, y: i64) -> i64 {
//       differentiable_register("loss");
//       return (x - y) * (x - y);
//   }
//
//   // Audit: list every fn that's been declared differentiable
//   // in this process.
//   let n: i64 = differentiable_count();
//   let i: i64 = 0;
//   while i < n {
//       print(differentiable_name(i));
//       i = i + 1;
//   };

#cfile "../runtime/differentiable_rt.c"

extern fn nuc_diff_register(name: str, mode_id: i64) -> i64;
extern fn nuc_diff_count() -> i64;
extern fn nuc_diff_name(idx: i64) -> str;
extern fn nuc_diff_mode(idx: i64) -> i64;
extern fn nuc_diff_lookup(name: str) -> i64;
extern fn nuc_diff_clear() -> i64;

// =====================================================
// Differentiation mode tags (stable IDs).
// =====================================================
fn diff_mode_reverse() -> i64 { return 1; }   // reverse-mode AD (matches today's autodiff rod)
fn diff_mode_forward() -> i64 { return 2; }   // forward-mode AD (future)
fn diff_mode_mixed()   -> i64 { return 3; }   // mixed forward/reverse (future)
fn diff_mode_unknown() -> i64 { return 0; }

fn diff_mode_name(id: i64) -> str {
    if id == 1 { return "reverse"; };
    if id == 2 { return "forward"; };
    if id == 3 { return "mixed"; };
    return "unknown";
}

// =====================================================
// Registry surface — primary entry point. The bare form
// defaults to reverse-mode (matches the autodiff rod's
// substrate); use _full for forward / mixed.
// =====================================================
fn differentiable_register(fn_name: str) -> i64 {
    return nuc_diff_register(fn_name, diff_mode_reverse());
}

fn differentiable_register_full(fn_name: str, mode_id: i64) -> i64 {
    return nuc_diff_register(fn_name, mode_id);
}

fn differentiable_count() -> i64 { return nuc_diff_count(); }

fn differentiable_name(idx: i64) -> str { return nuc_diff_name(idx); }

fn differentiable_mode(idx: i64) -> i64 { return nuc_diff_mode(idx); }

// Returns 1 if `fn_name` has been registered as differentiable
// anywhere in this process, else 0. Phase B's call-graph
// enforcement pass will use this same predicate.
fn differentiable_is(fn_name: str) -> i64 {
    let idx: i64 = nuc_diff_lookup(fn_name);
    if idx >= 0 { return 1; };
    return 0;
}

fn differentiable_lookup(fn_name: str) -> i64 {
    return nuc_diff_lookup(fn_name);
}

fn differentiable_clear() -> i64 { return nuc_diff_clear(); }

// =====================================================
// JSON serialization (mirrors v0.7.79 governance + v0.7.89
// energy/thermal + v0.7.90 model-provenance rod surfaces).
// =====================================================
fn differentiable_to_json(idx: i64) -> str {
    let mut out: str = "{\"name\":\"";
    out = str_concat(out, differentiable_name(idx));
    out = str_concat(out, "\",\"mode\":\"");
    out = str_concat(out, diff_mode_name(differentiable_mode(idx)));
    out = str_concat(out, "\"}");
    return out;
}

fn differentiable_all_to_json() -> str {
    let n: i64 = differentiable_count();
    let mut out: str = "[";
    let mut i: i64 = 0;
    while i < n {
        if i > 0 { out = str_concat(out, ","); };
        out = str_concat(out, differentiable_to_json(i));
        i = i + 1;
    };
    out = str_concat(out, "]");
    return out;
}
