// rods/bt — Behavior tree for robot behavior coordination.
//
// THE standard pattern for modern robot behavior orchestration
// (Colledanchise & Ögren 2018). A tree of composite + decorator +
// leaf nodes ticked from the root each control cycle.
//
// Composite nodes:
//   SEQUENCE  — children in order; FAIL on first failure, SUCCESS
//               only when all succeed.
//   SELECTOR  — children in order; SUCCESS on first success, FAIL
//               only when all fail.
//   PARALLEL  — tick all; SUCCESS when k of n succeed, FAIL when
//               n - k + 1 fail.
//
// Decorators:
//   INVERTER  — flips SUCCESS ↔ FAILURE of single child.
//
// Leaves (user-supplied callbacks):
//   ACTION    — returns SUCCESS / FAILURE / RUNNING.
//   CONDITION — returns SUCCESS / FAILURE.
//
// Status codes: 0 = SUCCESS, 1 = FAILURE, 2 = RUNNING.
//
// Foundation for: pick-and-place sequencing, reactive obstacle
// avoidance, task scheduling, error recovery, multi-step
// behaviors with long-running actions.
//
// Workflow:
//   let bt = bt_new();
//   let root  = bt_add_sequence(bt, 0 - 1);          // -1 = root
//   let _cond = bt_add_condition(bt, root, check_fp);
//   let _act1 = bt_add_action(bt, root, action1_fp);
//   let _act2 = bt_add_action(bt, root, action2_fp);
//
//   // At each control cycle:
//   let status = bt_tick(bt, root, ctx_ptr);
//
//   bt_free(bt);
//
// Limitations (blackboard-style data sharing between nodes
// + dynamic tree restructuring land in v0.6 if needed):
// - No blackboard; user passes shared state via the `ctx` pointer.
// - Static tree — built once, ticked many times.
//
// See `stdlib/runtime/bt_rt.c`.
#cfile "../runtime/bt_rt.c"

extern fn nuc_bt_new() -> i64;
extern fn nuc_bt_add_sequence(h: i64, parent: i64) -> i64;
extern fn nuc_bt_add_selector(h: i64, parent: i64) -> i64;
extern fn nuc_bt_add_parallel(h: i64, parent: i64, k: i64) -> i64;
extern fn nuc_bt_add_inverter(h: i64, parent: i64) -> i64;
extern fn nuc_bt_add_action(h: i64, parent: i64, callback_fp: i64) -> i64;
extern fn nuc_bt_add_condition(h: i64, parent: i64, callback_fp: i64) -> i64;
extern fn nuc_bt_tick(h: i64, root_idx: i64, ctx: i64) -> i64;
extern fn nuc_bt_node_count(h: i64) -> i64;
extern fn nuc_bt_free(h: i64);

fn bt_new() -> i64 { return nuc_bt_new(); }

// Pass parent = -1 for root nodes (no parent to attach to).
fn bt_add_sequence(h: i64, parent: i64) -> i64 {
    return nuc_bt_add_sequence(h, parent);
}
fn bt_add_selector(h: i64, parent: i64) -> i64 {
    return nuc_bt_add_selector(h, parent);
}
fn bt_add_parallel(h: i64, parent: i64, k: i64) -> i64 {
    return nuc_bt_add_parallel(h, parent, k);
}
fn bt_add_inverter(h: i64, parent: i64) -> i64 {
    return nuc_bt_add_inverter(h, parent);
}
fn bt_add_action(h: i64, parent: i64, callback_fp: i64) -> i64 {
    return nuc_bt_add_action(h, parent, callback_fp);
}
fn bt_add_condition(h: i64, parent: i64, callback_fp: i64) -> i64 {
    return nuc_bt_add_condition(h, parent, callback_fp);
}

// Tick the tree from `root_idx`. Returns status:
//   0 = SUCCESS, 1 = FAILURE, 2 = RUNNING.
// `ctx` is passed as-is to every leaf callback.
fn bt_tick(h: i64, root_idx: i64, ctx: i64) -> i64 {
    return nuc_bt_tick(h, root_idx, ctx);
}

fn bt_node_count(h: i64) -> i64 { return nuc_bt_node_count(h); }
fn bt_free(h: i64) { nuc_bt_free(h); }
