// rigid_body_rt.c — Rigid Body Physics Simulation for Nucleor
// Bodies, forces, torques, collision detection, constraints.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/rigid_body_rt.c -o target/rigid_body_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _rb_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _rb_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  Rigid Body
// ================================================================

#define RB_MAX_BODIES 256

typedef struct {
    double mass, inv_mass;
    double inertia, inv_inertia;
    double px, py, pz;     // position
    double vx, vy, vz;     // velocity
    double angle;           // 2D rotation (radians)
    double angular_vel;
    double fx, fy, fz;     // accumulated force
    double torque;
    int active;
} RigidBody;

static RigidBody rb_bodies[RB_MAX_BODIES];
static int rb_count = 0;
static double rb_gx = 0, rb_gy = -9.81, rb_gz = 0;

long long nuc_rb_new(long long mass_bits, long long inertia_bits) {
    if (rb_count >= RB_MAX_BODIES) return -1;
    int id = rb_count++;
    RigidBody *b = &rb_bodies[id];
    memset(b, 0, sizeof(RigidBody));
    b->mass = _rb_i2f(mass_bits);
    b->inv_mass = (b->mass > 1e-15) ? 1.0 / b->mass : 0.0;
    b->inertia = _rb_i2f(inertia_bits);
    b->inv_inertia = (b->inertia > 1e-15) ? 1.0 / b->inertia : 0.0;
    b->active = 1;
    return (long long)id;
}

void nuc_rb_set_pos(long long id, long long x_bits, long long y_bits, long long z_bits) {
    RigidBody *b = &rb_bodies[(int)id];
    b->px = _rb_i2f(x_bits); b->py = _rb_i2f(y_bits); b->pz = _rb_i2f(z_bits);
}

void nuc_rb_set_vel(long long id, long long vx_bits, long long vy_bits, long long vz_bits) {
    RigidBody *b = &rb_bodies[(int)id];
    b->vx = _rb_i2f(vx_bits); b->vy = _rb_i2f(vy_bits); b->vz = _rb_i2f(vz_bits);
}

void nuc_rb_set_rot(long long id, long long angle_bits, long long omega_bits) {
    RigidBody *b = &rb_bodies[(int)id];
    b->angle = _rb_i2f(angle_bits); b->angular_vel = _rb_i2f(omega_bits);
}

long long nuc_rb_get_px(long long id) { return _rb_f2i(rb_bodies[(int)id].px); }
long long nuc_rb_get_py(long long id) { return _rb_f2i(rb_bodies[(int)id].py); }
long long nuc_rb_get_pz(long long id) { return _rb_f2i(rb_bodies[(int)id].pz); }
long long nuc_rb_get_vx(long long id) { return _rb_f2i(rb_bodies[(int)id].vx); }
long long nuc_rb_get_vy(long long id) { return _rb_f2i(rb_bodies[(int)id].vy); }
long long nuc_rb_get_angle(long long id) { return _rb_f2i(rb_bodies[(int)id].angle); }

// ================================================================
//  Forces
// ================================================================

void nuc_rb_apply_force(long long id, long long fx_bits, long long fy_bits, long long fz_bits) {
    RigidBody *b = &rb_bodies[(int)id];
    b->fx += _rb_i2f(fx_bits); b->fy += _rb_i2f(fy_bits); b->fz += _rb_i2f(fz_bits);
}

void nuc_rb_apply_torque(long long id, long long torque_bits) {
    rb_bodies[(int)id].torque += _rb_i2f(torque_bits);
}

void nuc_rb_gravity(long long gx_bits, long long gy_bits, long long gz_bits) {
    rb_gx = _rb_i2f(gx_bits); rb_gy = _rb_i2f(gy_bits); rb_gz = _rb_i2f(gz_bits);
}

// ================================================================
//  Step simulation (semi-implicit Euler)
// ================================================================

void nuc_rb_step(long long dt_bits) {
    double dt = _rb_i2f(dt_bits);

    for (int i = 0; i < rb_count; i++) {
        RigidBody *b = &rb_bodies[i];
        if (!b->active || b->inv_mass == 0) continue;

        // Add gravity
        b->fx += b->mass * rb_gx;
        b->fy += b->mass * rb_gy;
        b->fz += b->mass * rb_gz;

        // Linear
        b->vx += b->fx * b->inv_mass * dt;
        b->vy += b->fy * b->inv_mass * dt;
        b->vz += b->fz * b->inv_mass * dt;
        b->px += b->vx * dt;
        b->py += b->vy * dt;
        b->pz += b->vz * dt;

        // Angular
        b->angular_vel += b->torque * b->inv_inertia * dt;
        b->angle += b->angular_vel * dt;

        // Clear forces
        b->fx = 0; b->fy = 0; b->fz = 0; b->torque = 0;
    }
}

// ================================================================
//  Sphere-Sphere Collision Detection
//  Returns 1 if colliding, 0 otherwise. Sets collision normal.
// ================================================================

long long nuc_rb_collide_spheres(long long id_a, long long id_b,
                                  long long radius_a_bits, long long radius_b_bits) {
    RigidBody *a = &rb_bodies[(int)id_a], *b = &rb_bodies[(int)id_b];
    double ra = _rb_i2f(radius_a_bits), rb_r = _rb_i2f(radius_b_bits);

    double dx = b->px - a->px, dy = b->py - a->py, dz = b->pz - a->pz;
    double dist = sqrt(dx * dx + dy * dy + dz * dz);
    double overlap = ra + rb_r - dist;

    if (overlap <= 0) return 0;

    // Separate bodies
    if (dist > 1e-10) {
        double nx = dx / dist, ny = dy / dist, nz = dz / dist;
        double sep = overlap * 0.5;
        if (a->inv_mass > 0) { a->px -= nx * sep; a->py -= ny * sep; a->pz -= nz * sep; }
        if (b->inv_mass > 0) { b->px += nx * sep; b->py += ny * sep; b->pz += nz * sep; }

        // Elastic impulse
        double rel_vx = b->vx - a->vx, rel_vy = b->vy - a->vy, rel_vz = b->vz - a->vz;
        double rel_v_n = rel_vx * nx + rel_vy * ny + rel_vz * nz;
        if (rel_v_n < 0) {
            double e = 0.8; // coefficient of restitution
            double j = -(1 + e) * rel_v_n / (a->inv_mass + b->inv_mass);
            a->vx -= j * a->inv_mass * nx; a->vy -= j * a->inv_mass * ny;
            b->vx += j * b->inv_mass * nx; b->vy += j * b->inv_mass * ny;
        }
    }
    return 1;
}

// ================================================================
//  Reset simulation
// ================================================================

void nuc_rb_reset(void) {
    rb_count = 0;
    rb_gx = 0; rb_gy = -9.81; rb_gz = 0;
}
