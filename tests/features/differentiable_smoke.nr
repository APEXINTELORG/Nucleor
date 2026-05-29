// v0.8.189 stdlib/rods/differentiable.nr first test coverage.
//
// RFC-0045 Phase A — differentiability metadata registry.
// Sister to v0.8.5 audit (counts @differentiable fn-attribute
// usage in source) and v0.8.181 audit gating. This rod is the
// runtime registry adopters call from fn bodies.
//
// Pre-v0.8.189: zero coverage.
//
// Locks five textbook registry invariants:
//   1. Mode IDs stable: reverse=1, forward=2, mixed=3.
//   2. Mode-name round-trip: name(1) == "reverse".
//   3. Empty registry: count == 0 after clear; lookup of
//      non-registered fn returns -1.
//   4. Register + count + lookup: register("loss") → count
//      becomes >0, lookup returns >= 0.
//   5. JSON round-trip: serializes name + mode field.
//
// Expected: rc=0.

import "stdlib/rods/differentiable.nr"
import "stdlib/rods/strings.nr"

fn check_mode_ids() -> i64 {
    if diff_mode_reverse() != 1 { return 1; };
    if diff_mode_forward() != 2 { return 2; };
    if diff_mode_mixed() != 3 { return 4; };
    if diff_mode_unknown() != 0 { return 8; };
    return 0;
}

fn check_mode_name() -> i64 {
    if str_eq(diff_mode_name(1), "reverse") != 1 { return 16; };
    if str_eq(diff_mode_name(2), "forward") != 1 { return 32; };
    if str_eq(diff_mode_name(3), "mixed") != 1 { return 64; };
    if str_eq(diff_mode_name(99), "unknown") != 1 { return 128; };
    return 0;
}

fn check_empty_registry() -> i64 {
    differentiable_clear();
    if differentiable_count() != 0 { return 256; };
    if differentiable_is("nonexistent") != 0 { return 512; };
    return 0;
}

fn check_register_and_lookup() -> i64 {
    differentiable_clear();
    differentiable_register("loss");
    if differentiable_count() != 1 { return 1024; };
    if differentiable_is("loss") != 1 { return 2048; };
    if differentiable_lookup("loss") < 0 { return 4096; };
    return 0;
}

fn check_json_round_trip() -> i64 {
    differentiable_clear();
    differentiable_register("model_loss");
    let json: str = differentiable_to_json(0);
    // Should contain both name + mode field
    let h: i64 = strings_index_of(json, "model_loss");
    if h < 0 { return 8192; };
    let m: i64 = strings_index_of(json, "reverse");
    if m < 0 { return 16384; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mode_ids();
    fails = fails + check_mode_name();
    fails = fails + check_empty_registry();
    fails = fails + check_register_and_lookup();
    fails = fails + check_json_round_trip();
    return fails;
}
