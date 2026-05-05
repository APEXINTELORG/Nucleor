// v0.8.223 stdlib/rods/rigid_body.nr first test coverage.
//
// 3-D rigid-body physics — bodies, forces, torque, gravity,
// integration, sphere-sphere collision. Pre-v0.8.223: zero
// coverage on the standalone rod.
//
// Locks four physics-integration invariants:
//
//   1. **Set/get position round-trip** — set (1,2,3) → get
//      px=1, py=2, pz=3.
//   2. **Free-fall under gravity** — body at rest with g=-9.81
//      → after dt=1s, vy ≈ -9.81 (Euler integration).
//   3. **Sphere collision detection** — two unit spheres at
//      distance 1.5 collide; at distance 3.0 they don't.
//   4. **Reset clears all bodies** — after rb_reset, new IDs
//      restart from 0.
//
// Expected: rc=0.

import "stdlib/rods/rigid_body.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_pos_round_trip() -> i64 {
    rb_reset();
    let id: i64 = rb_new(f64_to_bits(1.0), f64_to_bits(1.0));
    rb_set_pos(id, f64_to_bits(1.0), f64_to_bits(2.0), f64_to_bits(3.0));
    if close(rb_get_px(id), f64_to_bits(1.0), 1e-9) != 1 { return 1; };
    if close(rb_get_py(id), f64_to_bits(2.0), 1e-9) != 1 { return 2; };
    if close(rb_get_pz(id), f64_to_bits(3.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_free_fall() -> i64 {
    rb_reset();
    let id: i64 = rb_new(f64_to_bits(1.0), f64_to_bits(1.0));
    rb_set_pos(id, f64_to_bits(0.0), f64_to_bits(100.0), f64_to_bits(0.0));
    rb_set_vel(id, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    rb_gravity(f64_to_bits(0.0), f64_to_bits(0.0 - 9.81), f64_to_bits(0.0));
    rb_step(f64_to_bits(1.0));
    let vy: i64 = rb_get_vy(id);
    let vyf: f64 = f64_from_bits(vy);
    if vyf > 0.0 - 9.5 { return 8; };
    if vyf < 0.0 - 10.5 { return 16; };
    return 0;
}

fn check_sphere_collision() -> i64 {
    rb_reset();
    let a: i64 = rb_new(f64_to_bits(1.0), f64_to_bits(1.0));
    let b: i64 = rb_new(f64_to_bits(1.0), f64_to_bits(1.0));
    rb_set_pos(a, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    rb_set_pos(b, f64_to_bits(1.5), f64_to_bits(0.0), f64_to_bits(0.0));
    if rb_collide_spheres(a, b, f64_to_bits(1.0), f64_to_bits(1.0)) != 1 { return 32; };
    rb_set_pos(b, f64_to_bits(3.0), f64_to_bits(0.0), f64_to_bits(0.0));
    if rb_collide_spheres(a, b, f64_to_bits(1.0), f64_to_bits(1.0)) != 0 { return 64; };
    return 0;
}

fn check_reset_restarts_ids() -> i64 {
    rb_reset();
    let id1: i64 = rb_new(f64_to_bits(1.0), f64_to_bits(1.0));
    rb_reset();
    let id2: i64 = rb_new(f64_to_bits(1.0), f64_to_bits(1.0));
    if id1 != id2 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_pos_round_trip();
    fails = fails + check_free_fall();
    fails = fails + check_sphere_collision();
    fails = fails + check_reset_restarts_ids();
    return fails;
}
