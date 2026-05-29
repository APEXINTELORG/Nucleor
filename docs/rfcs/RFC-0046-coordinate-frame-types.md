# RFC-0046 — Coordinate-Frame Types `Pose<F: Frame>`

**Status:** Draft (frontier easy-win — V2.1)
**Date:** 2026-05-03
**Predecessor:** RFC-0003 deferred to v0.6 milestone — promote.

## Motivation

The Mars Climate Orbiter shipped without compile-time frame checking. Robotics, AR/VR, autonomy, and SLAM stacks routinely mix coordinate frames — base, world, camera, IMU, gripper, lidar — and the bug is a silent transformation that produces a plausible-looking wrong answer.

Today Nucleor's `kinematics` / `tf` / `se3` rods carry frame information at the value level (a `Pose` struct with a `frame: str` field), but the type system doesn't enforce that an op only mixes compatible frames. Adopters can pass a `Pose<"camera">` to a function expecting `Pose<"base">` and the compiler is silent.

## Design

Introduce `Pose<F>` as a generic over a phantom frame parameter F. The parameter is a compile-time string (or enum variant of a `Frame` trait).

```nucleor
struct Frame_World;
struct Frame_Base;
struct Frame_Camera;
struct Frame_Lidar;

// All four are zero-cost marker types — no runtime storage.

struct Pose<F> {
    translation: Vec3,
    rotation: Quat,
}
// Phantom-typed: the F parameter exists in the type system,
// not in the runtime layout. `Pose<F>` and `Pose<G>` have identical
// memory representation but are different types to the type-checker.

fn transform<From, To>(p: Pose<From>, t: Transform<From, To>) -> Pose<To> { ... }
```

Mixing operation:
```nucleor
let camera_to_base: Transform<Frame_Camera, Frame_Base> = lookup_tf();
let p_camera: Pose<Frame_Camera> = ...;
let p_base: Pose<Frame_Base> = transform(p_camera, camera_to_base);  // ✓
let bad: Pose<Frame_Base> = transform(p_camera, /* wrong-direction tf */);  // ← TYP-008 frame mismatch
```

## Implementation

- Type-check: `Pose<F>` types compare by both base name AND F parameter. `types_compatible(Pose<Camera>, Pose<Base>)` returns 0.
- Codegen: zero-cost — phantom F doesn't materialize. `Pose<Camera>` and `Pose<Base>` lower to identical `{Vec3, Quat}` storage.
- Stdlib: `kinematics` / `tf` / `se3` rods extend their existing `Pose` to the parameterized form. Backward-compat via type alias `type Pose = Pose<Frame_Unknown>;` for adopters who don't care.

## Cost

~200 LOC compiler-side (mostly type-string parsing for the phantom param). Stdlib rod updates ~150 LOC.

## Hot-path risk

None. Phantom-typed = no runtime cost.

## Frontier connection

This is the simplest concrete instance of the frontier writeup's "physical units and coordinate frames as types" thesis. Pairs with **RFC-0047 typed units** (same architectural pattern — phantom dimensional type parameter).

## Closure criteria

- `Pose<Frame_Camera>` and `Pose<Frame_Base>` are distinct types at the type-checker.
- `transform()` enforces the from-frame matches the binding's declared frame.
- Stdlib `kinematics` rod migrates to parameterized form without breaking existing fixtures.
- Round-2 self-host fixed-point holds.
