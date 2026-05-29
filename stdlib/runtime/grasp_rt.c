// grasp_rt.c — Grasp quality metrics for a 2-finger parallel-jaw
// gripper (the most common end-effector type in industrial and
// research robotics).
//
// A grasp is specified by two contact points and their outward-
// pointing surface normals (i.e., normals pointing AWAY from the
// object's interior). The standard quality metrics:
//
// - Antipodal score: how aligned the grip-direction is with
//   the contact normals. A perfect antipodal grasp (grip line
//   exactly between the two surface normals) scores +1; a
//   completely tangential "grasp" scores -1.
//
// - Force closure (under Coulomb friction): the contact
//   forces (which must lie in the friction cones at each contact)
//   can together resist any external wrench applied to the object.
//   For the 2-contact case, this reduces to a closed-form check:
//   both contact normals must lie within the friction cone of the
//   line connecting the two contact points.
//
// Foundation for grasp synthesis (sample candidate grasps, score
// them, pick the best) and for control-time grasp validation
// (reject planned grasps that the friction model says will slip).
//
// Limitations (full convex-hull-of-friction-cone wrench-space
// metric, multi-finger generalizations, and grasp-stability
// margins land in v0.6 if needed):
// - 2-finger / 2-contact only.
// - Coulomb friction with single coefficient (no anisotropic
//   friction, no separate static / kinetic μ).
// - Point contacts (no soft / surface contacts).
//
// Compile: clang -c stdlib/runtime/grasp_rt.c -o target/grasp.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

static void _normalize3(double *v) {
    double s = sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    if (s > 1e-18) { v[0] /= s; v[1] /= s; v[2] /= s; }
}

// Antipodal grasp quality: returns min((-n0)·g, n1·g) where
// g = (c1 - c0)/|c1 - c0|. Score in [-1, 1]; +1 is perfect antipodal.
//
// Both `n0` and `n1` are caller-provided outward surface normals
// (pointing AWAY from the object's interior at the contact). The
// function normalizes them internally for safety; if either has
// zero magnitude, returns 0.
long long nuc_grasp_antipodal_score(
    long long c0_x, long long c0_y, long long c0_z,
    long long n0_x, long long n0_y, long long n0_z,
    long long c1_x, long long c1_y, long long c1_z,
    long long n1_x, long long n1_y, long long n1_z)
{
    double c0[3] = { _i2f(c0_x), _i2f(c0_y), _i2f(c0_z) };
    double c1[3] = { _i2f(c1_x), _i2f(c1_y), _i2f(c1_z) };
    double n0[3] = { _i2f(n0_x), _i2f(n0_y), _i2f(n0_z) };
    double n1[3] = { _i2f(n1_x), _i2f(n1_y), _i2f(n1_z) };
    _normalize3(n0);
    _normalize3(n1);
    double g[3] = { c1[0] - c0[0], c1[1] - c0[1], c1[2] - c0[2] };
    double glen = sqrt(g[0]*g[0] + g[1]*g[1] + g[2]*g[2]);
    if (glen < 1e-18) return _f2i(0.0);
    g[0] /= glen; g[1] /= glen; g[2] /= glen;
    // -n0 · g  (we want -n0 to point along +g for ideal antipodal).
    double a = -(n0[0]*g[0] + n0[1]*g[1] + n0[2]*g[2]);
    // n1 · g  (we want n1 to point along +g, which is from c0 to c1,
    // so the gripper jaw at c1 pushes back toward c0).
    double b =  (n1[0]*g[0] + n1[1]*g[1] + n1[2]*g[2]);
    double s = (a < b) ? a : b;
    return _f2i(s);
}

// Force-closure check under Coulomb friction with coefficient μ.
// For a 2-contact grasp, force closure exists iff the line c0-c1
// lies within the friction cone at BOTH contacts — i.e., the
// angle between -n at c0 and +g is ≤ atan(μ), and similarly
// between n at c1 and +g.
//
// Returns 1 if the grasp is force-closure under the given μ; 0
// otherwise. With μ = 0 (frictionless) this requires perfect
// antipodal alignment (only a perfectly aligned grasp can resist
// external forces under no friction).
long long nuc_grasp_force_closure(
    long long c0_x, long long c0_y, long long c0_z,
    long long n0_x, long long n0_y, long long n0_z,
    long long c1_x, long long c1_y, long long c1_z,
    long long n1_x, long long n1_y, long long n1_z,
    long long mu_b)
{
    double c0[3] = { _i2f(c0_x), _i2f(c0_y), _i2f(c0_z) };
    double c1[3] = { _i2f(c1_x), _i2f(c1_y), _i2f(c1_z) };
    double n0[3] = { _i2f(n0_x), _i2f(n0_y), _i2f(n0_z) };
    double n1[3] = { _i2f(n1_x), _i2f(n1_y), _i2f(n1_z) };
    double mu = _i2f(mu_b);
    if (mu < 0) mu = 0;
    _normalize3(n0);
    _normalize3(n1);
    double g[3] = { c1[0] - c0[0], c1[1] - c0[1], c1[2] - c0[2] };
    double glen = sqrt(g[0]*g[0] + g[1]*g[1] + g[2]*g[2]);
    if (glen < 1e-18) return 0;
    g[0] /= glen; g[1] /= glen; g[2] /= glen;
    // cos_angle for -n0 to +g, and n1 to +g. Both must be ≥ cos(atan(μ)).
    double a = -(n0[0]*g[0] + n0[1]*g[1] + n0[2]*g[2]);
    double b =  (n1[0]*g[0] + n1[1]*g[1] + n1[2]*g[2]);
    // cos(atan(μ)) = 1 / sqrt(1 + μ²).
    double cone_cos = 1.0 / sqrt(1.0 + mu * mu);
    return (a >= cone_cos && b >= cone_cos) ? 1 : 0;
}

// Approach-vector quality: how well-aligned is the gripper's
// approach direction (typically the gripper-frame +z axis, but
// generalized here to any user-supplied 3-vector) with the local
// surface normal at the contact. Maximum +1 when the approach
// direction is exactly antiparallel to the surface normal (i.e.,
// approaching head-on into the surface); 0 when tangential; -1
// when approaching from behind the surface.
long long nuc_grasp_approach_alignment(
    long long n_x, long long n_y, long long n_z,
    long long ax_x, long long ax_y, long long ax_z)
{
    double n[3]  = { _i2f(n_x),  _i2f(n_y),  _i2f(n_z)  };
    double ax[3] = { _i2f(ax_x), _i2f(ax_y), _i2f(ax_z) };
    _normalize3(n);
    _normalize3(ax);
    double dot = n[0]*ax[0] + n[1]*ax[1] + n[2]*ax[2];
    // Approach is "into" the surface, so we want approach · (-n) ≥ 0
    // → -approach · n. Map to [-1, 1].
    return _f2i(-dot);
}
