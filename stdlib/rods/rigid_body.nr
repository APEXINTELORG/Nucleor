// =====================================================
// rods/rigid_body — 3D Rigid Body Physics
// =====================================================
// Import: import "stdlib/rods/rigid_body.nr"
// Provides: body creation, set/get position, velocity, rotation,
//   apply force/torque, global gravity, integration step,
//   sphere-sphere collision.
// =====================================================

#cfile "../runtime/rigid_body_rt.c"

extern fn nuc_rb_new(mass: i64, inertia: i64) -> i64;
extern fn nuc_rb_set_pos(id: i64, x: i64, y: i64, z: i64);
extern fn nuc_rb_set_vel(id: i64, vx: i64, vy: i64, vz: i64);
extern fn nuc_rb_set_rot(id: i64, angle: i64, omega: i64);
extern fn nuc_rb_get_px(id: i64) -> i64;
extern fn nuc_rb_get_py(id: i64) -> i64;
extern fn nuc_rb_get_pz(id: i64) -> i64;
extern fn nuc_rb_get_vx(id: i64) -> i64;
extern fn nuc_rb_get_vy(id: i64) -> i64;
extern fn nuc_rb_get_angle(id: i64) -> i64;
extern fn nuc_rb_apply_force(id: i64, fx: i64, fy: i64, fz: i64);
extern fn nuc_rb_apply_torque(id: i64, torque: i64);
extern fn nuc_rb_gravity(gx: i64, gy: i64, gz: i64);
extern fn nuc_rb_step(dt: i64);
extern fn nuc_rb_collide_spheres(id_a: i64, id_b: i64, radius_a: i64, radius_b: i64) -> i64;
extern fn nuc_rb_reset();

fn rb_new(mass: i64, inertia: i64) -> i64 { return nuc_rb_new(mass, inertia); }
fn rb_set_pos(id: i64, x: i64, y: i64, z: i64) { nuc_rb_set_pos(id, x, y, z); }
fn rb_set_vel(id: i64, vx: i64, vy: i64, vz: i64) { nuc_rb_set_vel(id, vx, vy, vz); }
fn rb_set_rot(id: i64, angle: i64, omega: i64) { nuc_rb_set_rot(id, angle, omega); }
fn rb_get_px(id: i64) -> i64 { return nuc_rb_get_px(id); }
fn rb_get_py(id: i64) -> i64 { return nuc_rb_get_py(id); }
fn rb_get_pz(id: i64) -> i64 { return nuc_rb_get_pz(id); }
fn rb_get_vx(id: i64) -> i64 { return nuc_rb_get_vx(id); }
fn rb_get_vy(id: i64) -> i64 { return nuc_rb_get_vy(id); }
fn rb_get_angle(id: i64) -> i64 { return nuc_rb_get_angle(id); }
fn rb_apply_force(id: i64, fx: i64, fy: i64, fz: i64) { nuc_rb_apply_force(id, fx, fy, fz); }
fn rb_apply_torque(id: i64, torque: i64) { nuc_rb_apply_torque(id, torque); }
fn rb_gravity(gx: i64, gy: i64, gz: i64) { nuc_rb_gravity(gx, gy, gz); }
fn rb_step(dt: i64) { nuc_rb_step(dt); }
fn rb_collide_spheres(a: i64, b: i64, ra: i64, rb: i64) -> i64 { return nuc_rb_collide_spheres(a, b, ra, rb); }
fn rb_reset() { nuc_rb_reset(); }
