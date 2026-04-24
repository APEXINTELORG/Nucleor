// rods/dynamics — Robot inverse dynamics via the Recursive
// Newton-Euler Algorithm (RNEA, Luh-Walker-Paul 1980).
//
// Given joint positions q, velocities qd, and accelerations qdd,
// computes the joint torques tau required to produce that motion
// against gravity. Standard equation:
//
//     tau = M(q)·qdd + C(q, qd)·qd + g(q)
//
// where M is the mass matrix, C the Coriolis/centrifugal terms,
// and g(q) the gravity-induced torques. RNEA computes tau directly
// in O(n) without explicitly forming M or C.
//
// Workflow:
//   let dyn = dyn_new(fk_chain_handle);    // wraps an existing FK chain
//   dyn_set_link_mass(dyn, link_idx, m);
//   dyn_set_link_com(dyn, link_idx, cx, cy, cz);
//   dyn_set_link_inertia(dyn, link_idx, ixx, iyy, izz, ixy, ixz, iyz);
//   dyn_set_gravity(dyn, gx, gy, gz);   // default (0, 0, -9.81)
//   dyn_inverse(dyn, q_ptr, qd_ptr, qdd_ptr, tau_out_ptr);
//   // ... or for gravity comp only ...
//   dyn_gravity(dyn, q_ptr, tau_out_ptr);
//
// **Limitations** (full Featherstone spatial-vector formulation
// lands in v0.6 if needed for big chains or deep recursion):
// - Serial chain only (no branching trees — same restriction as
//   the URDF parser).
// - Revolute and prismatic joints only.
// - Inertia tensors must be expressed in the link's body-fixed
//   frame at the link's center of mass.
//
// See `stdlib/runtime/dynamics_rt.c`.
#cfile "../runtime/dynamics_rt.c"

// dynamics_rt.c reads from the FK chain runtime; importing fk_chain
// chains its #cfile so both translation units link together.
import "stdlib/rods/fk_chain.nr"

extern fn nuc_dyn_new(fk_handle: i64) -> i64;
extern fn nuc_dyn_set_link_mass(h: i64, i: i64, mass_b: i64);
extern fn nuc_dyn_set_link_com(h: i64, i: i64, cx_b: i64, cy_b: i64, cz_b: i64);
extern fn nuc_dyn_set_link_inertia(h: i64, i: i64,
    ixx_b: i64, iyy_b: i64, izz_b: i64,
    ixy_b: i64, ixz_b: i64, iyz_b: i64);
extern fn nuc_dyn_set_gravity(h: i64, gx_b: i64, gy_b: i64, gz_b: i64);
extern fn nuc_dyn_inverse(h: i64,
    q_ptr: i64, qd_ptr: i64, qdd_ptr: i64, tau_out_ptr: i64) -> i64;
extern fn nuc_dyn_gravity(h: i64, q_ptr: i64, tau_out_ptr: i64) -> i64;
extern fn nuc_dyn_free(h: i64);

// Create a dynamics solver bound to an existing FK chain handle.
// Defaults each link to mass 1.0 kg, identity inertia 0.01 along
// the diagonal, CoM at link origin, gravity (0, 0, -9.81).
fn dyn_new(fk_handle: i64) -> i64 { return nuc_dyn_new(fk_handle); }

fn dyn_set_link_mass(h: i64, i: i64, mass_b: i64) {
    nuc_dyn_set_link_mass(h, i, mass_b);
}

// Center of mass offset for link `i`, expressed in the link's
// body-fixed frame (i.e., relative to the link origin).
fn dyn_set_link_com(h: i64, i: i64, cx_b: i64, cy_b: i64, cz_b: i64) {
    nuc_dyn_set_link_com(h, i, cx_b, cy_b, cz_b);
}

// Inertia tensor for link `i`, expressed in the link's body-fixed
// frame at the link's center of mass. Stored as the 6-element
// upper triangle: (Ixx, Iyy, Izz, Ixy, Ixz, Iyz).
fn dyn_set_link_inertia(h: i64, i: i64,
    ixx_b: i64, iyy_b: i64, izz_b: i64,
    ixy_b: i64, ixz_b: i64, iyz_b: i64)
{
    nuc_dyn_set_link_inertia(h, i, ixx_b, iyy_b, izz_b, ixy_b, ixz_b, iyz_b);
}

// World-frame gravity vector. Default (0, 0, -9.81).
fn dyn_set_gravity(h: i64, gx_b: i64, gy_b: i64, gz_b: i64) {
    nuc_dyn_set_gravity(h, gx_b, gy_b, gz_b);
}

// Inverse dynamics: compute joint torques `tau` for the (q, qd, qdd)
// triplet. All four pointers are caller-owned `double[n_joints]`
// buffers. Returns 0 on success.
fn dyn_inverse(h: i64,
    q_ptr: i64, qd_ptr: i64, qdd_ptr: i64, tau_out_ptr: i64) -> i64 {
    return nuc_dyn_inverse(h, q_ptr, qd_ptr, qdd_ptr, tau_out_ptr);
}

// Gravity-compensation torques: the qd = qdd = 0 case. Useful for
// commanding the controller to "hold position against gravity"
// without inducing motion.
fn dyn_gravity(h: i64, q_ptr: i64, tau_out_ptr: i64) -> i64 {
    return nuc_dyn_gravity(h, q_ptr, tau_out_ptr);
}

fn dyn_free(h: i64) { nuc_dyn_free(h); }
