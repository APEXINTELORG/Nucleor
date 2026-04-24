// rods/dynamics — verify rod wrapper compiles + links (v0.2.207 ship).
// Build a 1-joint chain, instantiate dynamics, exercise the
// configuration setters; correctness coverage in the direct C
// test (single-pendulum gravity torque, 2-link arm).
import "stdlib/rods/dynamics.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;
    let chain: i64 = fk_chain_new();
    let _j: i64 = fk_chain_add_dh_joint(chain,
        f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));

    let dyn: i64 = dyn_new(chain);
    if dyn == 0 { print("FAIL dyn_new"); return 1; };

    dyn_set_link_mass(dyn, 0, f64_to_bits(2.0));
    dyn_set_link_com(dyn, 0,
        f64_to_bits(0.5), f64_to_bits(0.0), f64_to_bits(0.0));
    dyn_set_link_inertia(dyn, 0,
        f64_to_bits(0.01), f64_to_bits(0.01), f64_to_bits(0.01),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    dyn_set_gravity(dyn,
        f64_to_bits(0.0), f64_to_bits(0.0 - 9.81), f64_to_bits(0.0));

    dyn_free(dyn);
    fk_chain_free(chain);

    if fail == 0 { print("OK dynamics_smoke"); };
    return fail;
}
