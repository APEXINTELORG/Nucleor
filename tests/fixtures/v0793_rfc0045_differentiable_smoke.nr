// v0.7.93 RFC-0045 Phase A smoke fixture — fn-level
// differentiability metadata registry. Validates:
//   - Mode tags return stable IDs + name lookup
//   - register / count / name / mode round-trip
//   - register_full with explicit mode (forward / mixed)
//   - lookup / is predicates
//   - idempotent re-registration (same name → same idx,
//     mode update)
//   - JSON serialization smoke
//   - clear resets the registry
import "stdlib/rods/differentiable.nr"

fn main() -> i64 {
    differentiable_clear();

    if diff_mode_reverse() != 1 { return 1; };
    if diff_mode_forward() != 2 { return 2; };
    if str_eq(diff_mode_name(1), "reverse") == 0 { return 3; };
    if str_eq(diff_mode_name(2), "forward") == 0 { return 4; };

    differentiable_register("loss");
    differentiable_register("forward_pass");
    differentiable_register_full("custom_grad", diff_mode_mixed());

    if differentiable_count() != 3 { return 5; };

    let n0: str = differentiable_name(0);
    if str_eq(n0, "loss") == 0 { return 6; };
    if differentiable_mode(0) != diff_mode_reverse() { return 7; };

    if differentiable_mode(2) != diff_mode_mixed() { return 8; };

    if differentiable_is("loss") != 1 { return 9; };
    if differentiable_is("not_registered") != 0 { return 10; };

    let idx: i64 = differentiable_lookup("custom_grad");
    if idx != 2 { return 11; };

    // Idempotent re-register: same name, different mode → updates,
    // doesn't duplicate.
    let re_idx: i64 = differentiable_register_full("loss", diff_mode_forward());
    if re_idx != 0 { return 12; };
    if differentiable_count() != 3 { return 13; };
    if differentiable_mode(0) != diff_mode_forward() { return 14; };

    // JSON smoke.
    let j: str = differentiable_to_json(0);
    if str_len(j) < 20 { return 15; };

    let all: str = differentiable_all_to_json();
    if str_len(all) < 50 { return 16; };

    differentiable_clear();
    if differentiable_count() != 0 { return 17; };

    return 0;
}
