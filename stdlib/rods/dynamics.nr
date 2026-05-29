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
// Limitations (full Featherstone spatial-vector formulation
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

// Per-joint friction model (v0.2.218). Adds
// τ_friction = μ_v · qd + μ_c · sign(qd) to the inverse-dynamics
// output for joint `i`. All RNEA-derived entry points (computed
// torque, Cartesian impedance, gravity comp, mass matrix
// extraction, forward dynamics) account for it automatically.
// Default 0 / 0 (frictionless). Skipped for fixed joints.
extern fn nuc_dyn_set_joint_friction(h: i64, i: i64,
    mu_v_b: i64, mu_c_b: i64);

// Per-joint reflected motor inertia (v0.2.221). The caller supplies
// `I_rotor · gear_ratio²` — the rotor inertia "as seen at the joint
// shaft". Augments the joint-space mass matrix diagonal:
// `τ += I_motor · qdd`. Default 0 (no reflection). Critical for
// high-fidelity dynamics on geared robots.
extern fn nuc_dyn_set_motor_inertia(h: i64, i: i64, I_b: i64);
extern fn nuc_dyn_inverse(h: i64,
    q_ptr: i64, qd_ptr: i64, qdd_ptr: i64, tau_out_ptr: i64) -> i64;
extern fn nuc_dyn_gravity(h: i64, q_ptr: i64, tau_out_ptr: i64) -> i64;

// Mass matrix M(q) extraction (v0.2.211). Computes the joint-space
// mass matrix at the given configuration q via n+1 RNEA calls
// (gravity bias + one column per joint). `out_M_ptr` is a caller-
// allocated `double[n*n]` row-major buffer.
extern fn nuc_dyn_mass_matrix(h: i64, q_ptr: i64, out_M_ptr: i64) -> i64;

// Forward dynamics (v0.2.211): given torques, compute resulting
// joint accelerations via qdd = M⁻¹·(tau − C·qd − g). Internally
// runs RNEA for the bias term, computes M via `nuc_dyn_mass_matrix`,
// inverts it via Gauss-Jordan. Returns -1 if M is singular.
extern fn nuc_dyn_forward(h: i64,
    q_ptr: i64, qd_ptr: i64, tau_ptr: i64, qdd_out_ptr: i64) -> i64;

// Inverse dynamics with applied tip wrench (v0.2.212). Same as
// `nuc_dyn_inverse` but the backward pass starts with the given
// world-frame force + torque applied at the end-effector tip
// instead of zero. Use cases:
// - Modeling environment contact (peg-in-hole, surface tracking).
// - Computing torques to resist a known external load.
// - Force-controlled simulation.
//
// Sign convention: positive force is what the *environment*
// applies to the robot.
extern fn nuc_dyn_inverse_with_wrench(h: i64,
    q_ptr: i64, qd_ptr: i64, qdd_ptr: i64,
    fx_b: i64, fy_b: i64, fz_b: i64,
    tx_b: i64, ty_b: i64, tz_b: i64,
    tau_out_ptr: i64) -> i64;

// Joint-space computed-torque controller (v0.2.214). Classical
// inverse-dynamics control for trajectory tracking:
//
//     qdd_cmd = qdd_des + Kp·(q_des − q) + Kd·(qd_des − qd)
//     tau     = M(q)·qdd_cmd + C(q,qd)·qd + g(q)   ← packaged via RNEA
//
// Closes the loop on tracking error: e = q_des − q follows the
// linear ODE ë + Kd·ė + Kp·e = 0. Tune Kp / Kd in error-space:
// Kp = ω², Kd = 2·ζ·ω for natural frequency ω and damping ζ.
//
// `Kp_ptr` / `Kd_ptr` are caller-allocated `double[n_joints]`
// diagonal gain vectors. Pass 0 for either to disable that term
// (e.g., feedforward-only with Kp=0, Kd=0).
extern fn nuc_dyn_computed_torque(h: i64,
    q_ptr: i64, qd_ptr: i64,
    q_des_ptr: i64, qd_des_ptr: i64, qdd_des_ptr: i64,
    Kp_ptr: i64, Kd_ptr: i64,
    tau_out_ptr: i64) -> i64;

// 6-DOF Cartesian impedance (v0.2.215). Extends `nuc_dyn_cartesian_
// impedance` from 3-DOF position to 6-DOF pose. Angular error is
// computed as the quaternion log-map of `q_des · q_cur⁻¹`. Jacobian
// is 6×n. K and D are 6-vectors (Kx, Ky, Kz, Krx, Kry, Krz) in
// world frame; rotational entries have units N·m/rad.
extern fn nuc_dyn_cartesian_impedance_6d(h: i64,
    q_ptr: i64, qd_ptr: i64,
    pdes_x_b: i64, pdes_y_b: i64, pdes_z_b: i64,
    qdes_w_b: i64, qdes_x_b: i64, qdes_y_b: i64, qdes_z_b: i64,
    K_ptr: i64, D_ptr: i64,
    include_gravity: i64,
    tau_out_ptr: i64) -> i64;

// Operational-space inverse dynamics (v0.2.219). Khatib-style
// task-space control: given a desired Cartesian acceleration
// `xdd_des` for the end-effector, computes the joint torques that
// produce it via the simplified joint-space-mapping form:
//
//     qdd_des = J⁺(q) · xdd_des
//     τ       = M(q)·qdd_des + C(q,qd)·qd + g(q)   ← packaged via RNEA
//
// `damping_b` is the damping factor for the pseudoinverse
// `J⁺ = Jᵀ·(J·Jᵀ + λ²I)⁻¹` — same role as in the IK solver.
// 0.01-0.1 typical.
//
// Different from `dyn_cartesian_impedance` (v0.2.212): impedance
// controls task-space STIFFNESS / DAMPING (force-driven); this
// entry point controls task-space ACCELERATION (motion-driven).
extern fn nuc_dyn_op_space_inverse(h: i64,
    q_ptr: i64, qd_ptr: i64,
    xdd_des_x_b: i64, xdd_des_y_b: i64, xdd_des_z_b: i64,
    damping_b: i64,
    tau_out_ptr: i64) -> i64;

// Cartesian impedance / operational-space PD controller (v0.2.212).
// Computes joint torques for a position-task PD in Cartesian space:
//
//     F_cart = K · (p_des − p_actual) − D · (J · qd)
//     tau    = Jᵀ · F_cart [+ g(q) if include_gravity]
//
// K and D are diagonal stiffness and damping in world frame.
// `include_gravity` adds gravity-compensation torques.
extern fn nuc_dyn_cartesian_impedance(h: i64,
    q_ptr: i64, qd_ptr: i64,
    pdes_x_b: i64, pdes_y_b: i64, pdes_z_b: i64,
    kx_b: i64, ky_b: i64, kz_b: i64,
    dx_b: i64, dy_b: i64, dz_b: i64,
    include_gravity: i64,
    tau_out_ptr: i64) -> i64;

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

// Per-joint friction (v0.2.218). `mu_v` is the viscous coefficient
// (units: N·m·s/rad for revolute, N·s/m for prismatic); `mu_c` is
// the Coulomb / dry-friction torque magnitude. Default 0 / 0.
fn dyn_set_joint_friction(h: i64, i: i64, mu_v_b: i64, mu_c_b: i64) {
    nuc_dyn_set_joint_friction(h, i, mu_v_b, mu_c_b);
}

// Per-joint reflected motor inertia (v0.2.221). Caller supplies
// `I_rotor · gear_ratio²`. Default 0.
fn dyn_set_motor_inertia(h: i64, i: i64, I_b: i64) {
    nuc_dyn_set_motor_inertia(h, i, I_b);
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

fn dyn_mass_matrix(h: i64, q_ptr: i64, out_M_ptr: i64) -> i64 {
    return nuc_dyn_mass_matrix(h, q_ptr, out_M_ptr);
}

fn dyn_forward(h: i64,
    q_ptr: i64, qd_ptr: i64, tau_ptr: i64, qdd_out_ptr: i64) -> i64 {
    return nuc_dyn_forward(h, q_ptr, qd_ptr, tau_ptr, qdd_out_ptr);
}

fn dyn_inverse_with_wrench(h: i64,
    q_ptr: i64, qd_ptr: i64, qdd_ptr: i64,
    fx_b: i64, fy_b: i64, fz_b: i64,
    tx_b: i64, ty_b: i64, tz_b: i64,
    tau_out_ptr: i64) -> i64
{
    return nuc_dyn_inverse_with_wrench(h, q_ptr, qd_ptr, qdd_ptr,
        fx_b, fy_b, fz_b, tx_b, ty_b, tz_b, tau_out_ptr);
}

fn dyn_cartesian_impedance(h: i64,
    q_ptr: i64, qd_ptr: i64,
    pdes_x_b: i64, pdes_y_b: i64, pdes_z_b: i64,
    kx_b: i64, ky_b: i64, kz_b: i64,
    dx_b: i64, dy_b: i64, dz_b: i64,
    include_gravity: i64,
    tau_out_ptr: i64) -> i64
{
    return nuc_dyn_cartesian_impedance(h, q_ptr, qd_ptr,
        pdes_x_b, pdes_y_b, pdes_z_b,
        kx_b, ky_b, kz_b, dx_b, dy_b, dz_b,
        include_gravity, tau_out_ptr);
}

fn dyn_computed_torque(h: i64,
    q_ptr: i64, qd_ptr: i64,
    q_des_ptr: i64, qd_des_ptr: i64, qdd_des_ptr: i64,
    Kp_ptr: i64, Kd_ptr: i64,
    tau_out_ptr: i64) -> i64
{
    return nuc_dyn_computed_torque(h, q_ptr, qd_ptr,
        q_des_ptr, qd_des_ptr, qdd_des_ptr,
        Kp_ptr, Kd_ptr, tau_out_ptr);
}

fn dyn_op_space_inverse(h: i64,
    q_ptr: i64, qd_ptr: i64,
    xdd_des_x_b: i64, xdd_des_y_b: i64, xdd_des_z_b: i64,
    damping_b: i64,
    tau_out_ptr: i64) -> i64
{
    return nuc_dyn_op_space_inverse(h, q_ptr, qd_ptr,
        xdd_des_x_b, xdd_des_y_b, xdd_des_z_b,
        damping_b, tau_out_ptr);
}

fn dyn_cartesian_impedance_6d(h: i64,
    q_ptr: i64, qd_ptr: i64,
    pdes_x_b: i64, pdes_y_b: i64, pdes_z_b: i64,
    qdes_w_b: i64, qdes_x_b: i64, qdes_y_b: i64, qdes_z_b: i64,
    K_ptr: i64, D_ptr: i64,
    include_gravity: i64,
    tau_out_ptr: i64) -> i64
{
    return nuc_dyn_cartesian_impedance_6d(h, q_ptr, qd_ptr,
        pdes_x_b, pdes_y_b, pdes_z_b,
        qdes_w_b, qdes_x_b, qdes_y_b, qdes_z_b,
        K_ptr, D_ptr, include_gravity, tau_out_ptr);
}

fn dyn_free(h: i64) { nuc_dyn_free(h); }
