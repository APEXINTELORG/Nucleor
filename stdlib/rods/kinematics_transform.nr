// rods/kinematics_transform — RFC-0046 Phase B / ROBO-7 v0845
// typed transform facade.
//
// Builds on `stdlib/rods/kinematics_frame.nr` (Frame_* marker
// structs) and the existing handle-level pose math
// (`stdlib/rods/kinematics.nr`). Exposes a `Transform<From, To>`
// type whose phantom From / To frame parameters drive the
// compiler's TYP-008 / FRAME-001 frame-mismatch diagnostics across
// composition, inversion, and pose application.
//
// Today the v0840 ROBO-7 Wave 2 compiler check enforces phantom
// frame mismatches at let-bindings, fn-call argument positions,
// struct-init, binop, return, and tail-return sites for Pose<F>;
// v0845 lane 5 / queue 5A confirms the same multi-param phantom
// support at TWO frame parameters via empirical probe (see
// findings/inbox/main_lane5_5A_typed_transform_facade_v0845_2026-05-07.md).
//
// Design note: the underlying `Transform` struct has no generic
// parameters — the From/To phantoms are compile-time only.
// Memory layout matches the existing Pose / handle-pair shape, so
// the facade is genuinely zero-cost: same loads, same stores, same
// cache footprint as untagged Pose math. All math goes through the
// kinematics.nr `pose_*` wrappers which already declare the
// underlying nuc_* externs — re-declaring them here would emit
// duplicate `declare` entries in the LLVM IR.

import "stdlib/rods/kinematics_frame.nr"
import "stdlib/rods/kinematics.nr"

// Phantom-frame transform facade. The translation and rotation
// fields are existing Vec3 / Quat handles; the From / To frame
// parameters are compile-time only and drive FRAME-001 diagnostics
// at Transform<F, T> boundaries.
struct Transform { translation: i64, rotation: i64 }

// === Construction ===

fn transform_new<F, T>(t: i64, q: i64) -> Transform<F, T> {
    return Transform { translation: t, rotation: q };
}

// Identity transform on a single frame: Transform<F, F>. Adopters
// who need a "no-op" transform inside a frame can use this without
// constructing a fresh Vec3 + Quat.
fn transform_identity<F>() -> Transform<F, F> {
    let zero_t: i64 = vec3(0, 0, 0);
    let id_q: i64 = quat_identity();
    return Transform { translation: zero_t, rotation: id_q };
}

// === Inversion ===
//
// SE(3) inverse: Transform<From, To> swapped to Transform<To, From>.
// The phantom signature mirrors the math: inverting a base-to-camera
// transform yields a camera-to-base transform. Compiler enforces
// the swap at every binding / call / return site.
fn transform_invert<F, T>(tf: Transform<F, T>) -> Transform<T, F> {
    let h: i64 = pose(tf.translation, tf.rotation);
    let inv: i64 = pose_inverse(h);
    let inv_t: i64 = pose_pos(inv);
    let inv_q: i64 = pose_quat(inv);
    pose_free(h);
    pose_free(inv);
    return Transform { translation: inv_t, rotation: inv_q };
}

// === Composition ===
//
// Frame-typed composition: Transform<A, B> composed with
// Transform<B, C> yields Transform<A, C>. The middle frame B must
// match across the two arguments — if an adopter passes
// Transform<A, X> and Transform<Y, C> with X != Y, the compiler
// emits FRAME-001 at the call site.
fn transform_compose<A, B, C>(
    ab: Transform<A, B>,
    bc: Transform<B, C>
) -> Transform<A, C> {
    let ah: i64 = pose(ab.translation, ab.rotation);
    let bh: i64 = pose(bc.translation, bc.rotation);
    let ch: i64 = pose_compose(ah, bh);
    let pos_h: i64 = pose_pos(ch);
    let rot_h: i64 = pose_quat(ch);
    pose_free(ah);
    pose_free(bh);
    pose_free(ch);
    return Transform { translation: pos_h, rotation: rot_h };
}

// === Pose application ===
//
// Apply a Transform<F, T> to a Pose<F> to get a Pose<T>. This is
// the canonical "transform a point/pose from one frame to another"
// operation — the Mars-Climate-Orbiter class of bug it prevents.
fn transform_apply<F, T>(tf: Transform<F, T>, p: Pose<F>) -> Pose<T> {
    let tfh: i64 = pose(tf.translation, tf.rotation);
    let ph: i64 = pose(p.translation, p.rotation);
    let out_h: i64 = pose_compose(tfh, ph);
    let out_t: i64 = pose_pos(out_h);
    let out_q: i64 = pose_quat(out_h);
    pose_free(tfh);
    pose_free(ph);
    pose_free(out_h);
    return Pose { translation: out_t, rotation: out_q };
}

// === Field accessors ===
//
// Adopter ergonomics for reading the underlying handles without
// peeking at the struct directly.
fn transform_translation<F, T>(tf: Transform<F, T>) -> i64 {
    return tf.translation;
}

fn transform_rotation<F, T>(tf: Transform<F, T>) -> i64 {
    return tf.rotation;
}
