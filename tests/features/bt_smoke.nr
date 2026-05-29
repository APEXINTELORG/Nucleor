// v0.8.231 stdlib/rods/bt.nr first test coverage.
//
// Behavior tree for robot behavior coordination — sequence,
// selector, parallel, inverter, action, condition. Pre-v0.8.231:
// zero coverage on the standalone rod.
//
// Locks four lifecycle invariants. Action/condition leaves take
// fn pointer callbacks which would require Nucleor closure
// surface; the composite/decorator construction is testable
// without ticking.
//
//   1. Empty tree — bt_new → bt_node_count == 0.
//   2. Single composite root — sequence at root → count 1.
//   3. Composite with multiple composite children — root
//      sequence + 3 sequence children → count 4.
//   4. Inverter is a node — adding inverter increments count.
//
// Expected: rc=0.

import "stdlib/rods/bt.nr"

fn check_empty() -> i64 {
    let h: i64 = bt_new();
    if bt_node_count(h) != 0 { bt_free(h); return 1; };
    bt_free(h);
    return 0;
}

fn check_single_root() -> i64 {
    let h: i64 = bt_new();
    bt_add_sequence(h, 0 - 1);  // -1 = root
    if bt_node_count(h) != 1 { bt_free(h); return 2; };
    bt_free(h);
    return 0;
}

fn check_composite_chain() -> i64 {
    let h: i64 = bt_new();
    let root: i64 = bt_add_sequence(h, 0 - 1);
    bt_add_sequence(h, root);
    bt_add_selector(h, root);
    bt_add_parallel(h, root, 1);
    if bt_node_count(h) != 4 { bt_free(h); return 4; };
    bt_free(h);
    return 0;
}

fn check_inverter_adds_node() -> i64 {
    let h: i64 = bt_new();
    let root: i64 = bt_add_sequence(h, 0 - 1);
    let before: i64 = bt_node_count(h);
    bt_add_inverter(h, root);
    let after: i64 = bt_node_count(h);
    bt_free(h);
    if (after - before) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_single_root();
    fails = fails + check_composite_chain();
    fails = fails + check_inverter_adds_node();
    return fails;
}
