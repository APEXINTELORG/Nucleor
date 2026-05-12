# RFC-0013 — URDF-Aware Compile-Time Frame Chain Verification

| Field | Value |
|---|---|
| **Number** | 0013 |
| **Title** | URDF-aware compile-time frame chain verification |
| **Status** | Draft |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.5.0 ("Production Robotics") |
| **Depends on** | RFC-0003 (typed frames) |

---

## 1. Summary

Read URDF (Unified Robot Description Format) at compile time,
synthesize `Frame` impls for every link, and verify that
`tf.lookup::<A, B>()` calls reference frame pairs that exist in the
URDF tree. Failed lookups become **compile errors**, not runtime
errors.

```nucleor
#[urdf = "robots/ur5.urdf"]
mod ur5 { }    // synthesizes Frame impls: ur5::BaseLink, ur5::Shoulder, ...

fn check(tf: &Tf2Buffer) {
    tf.lookup::<ur5::Shoulder, ur5::Tool0>();    // OK at compile time
    tf.lookup::<ur5::Tool0, World>();            // ERROR: World not in ur5 URDF tree
}
```

This **closes the last runtime gap** in the typed-frames story
(RFC-0003): even cross-frame lookups can fail at compile time if the
TF graph is statically known.

---

## 2. Motivation

RFC-0003 catches frame mismatches in arithmetic and function calls
at compile time, but `tf.lookup::<From, To>()` is still a runtime
call — it can fail if the frame chain doesn't exist (typo, missing
URDF inclusion, etc.).

For static-graph robots (industrial arms, fixed-base manipulators,
mostly-static mobile robots), the URDF defines the entire frame
graph at build time. We can verify lookups against it.

---

## 3. Design

### 3.1 The `#[urdf = "path"]` module attribute

```nucleor
#[urdf = "robots/ur5.urdf"]
mod ur5 { }
```

At compile time, `nuc-urdf-import` (a tool) reads the URDF, parses
links and joints, and emits:

```nucleor
mod ur5 {
    pub struct BaseLink;        impl Frame for BaseLink { const NAME: &str = "ur5/base_link"; }
    pub struct Shoulder;        impl Frame for Shoulder { const NAME: &str = "ur5/shoulder_link"; }
    pub struct UpperArm;        impl Frame for UpperArm { const NAME: &str = "ur5/upper_arm_link"; }
    pub struct Forearm;         impl Frame for Forearm { const NAME: &str = "ur5/forearm_link"; }
    pub struct Wrist1;          impl Frame for Wrist1 { const NAME: &str = "ur5/wrist_1_link"; }
    pub struct Wrist2;          impl Frame for Wrist2 { const NAME: &str = "ur5/wrist_2_link"; }
    pub struct Wrist3;          impl Frame for Wrist3 { const NAME: &str = "ur5/wrist_3_link"; }
    pub struct Tool0;           impl Frame for Tool0 { const NAME: &str = "ur5/tool0"; }

    // Also: a static map of frame edges
    pub const FRAME_TREE: FrameTree = FrameTree { edges: &[
        (BaseLink::NAME, Shoulder::NAME),
        (Shoulder::NAME, UpperArm::NAME),
        (UpperArm::NAME, Forearm::NAME),
        // ...
    ] };
}
```

### 3.2 Static lookup verification

`tf.lookup<A, B>()` becomes verified against `FRAME_TREE` at compile
time:

```nucleor
tf.lookup::<ur5::Shoulder, ur5::Tool0>();   // path: Shoulder→UpperArm→Forearm→Wrist1→Wrist2→Wrist3→Tool0; OK
tf.lookup::<ur5::Tool0, World>();           // World not in ur5::FRAME_TREE; ERROR URDF-001
```

### 3.3 Multiple URDFs

Robotics scenarios mix multiple URDFs (mobile base + arm + sensor
mount). Each module imports its own:

```nucleor
#[urdf = "robots/ur5.urdf"]
mod arm {}

#[urdf = "robots/ridgeback.urdf"]
mod base {}

// World ↔ base ↔ arm via mounting transform
fn check(tf: &Tf2Buffer) {
    tf.lookup::<base::Chassis, arm::Tool0>();   // verified across two URDFs
}
```

The compiler unifies the per-URDF trees by their root-frame
attachment points (must be declared explicitly via
`#[urdf_attach(parent = base::Chassis, child = arm::BaseLink)]`).

### 3.4 Joint type metadata

URDF specifies joint types (revolute, prismatic, fixed, continuous,
floating). Generated frames carry this metadata:

```nucleor
impl ur5::Shoulder {
    pub const JOINT_TYPE: JointType = JointType::Revolute;
    pub const AXIS: Vec3 = Vec3 { x: 0.0, y: 0.0, z: 1.0 };
    pub const LIMITS: JointLimits = JointLimits { lower: -PI, upper: PI, velocity: 3.14, effort: 150.0 };
}
```

This unlocks compile-time-verifiable joint-limit checks (`#[ensure(joint_target.within(ur5::Shoulder::LIMITS))]`).

### 3.5 SDF / xacro / URDF-XML support

URDF is XML; xacro is XML with macros expanded at parse time. SDF
(Simulation Description Format, used by Gazebo) is XML with richer
semantics.

v0.5 ships URDF + xacro support. SDF in v0.6.

### 3.6 Diagnostics

| Code | Meaning |
|---|---|
| URDF-001 | `tf.lookup<A, B>` — no path from A to B in any imported URDF |
| URDF-002 | `tf.lookup<A, B>` — A and B are in different URDFs without `#[urdf_attach]` |
| URDF-003 | Cycle in URDF tree (malformed input) |
| URDF-004 | URDF file not found |
| URDF-005 | URDF parse error |
| URDF-006 | Joint limit violated (when used with `#[ensure]`) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `#[urdf = "path"]` module attribute | ~80 |
| `nuc-urdf-import` tool | URDF/xacro XML parser, frame synthesis | ~1500 |
| Compiler | Static FRAME_TREE lookup verification | ~300 |
| Diagnostics | URDF-001…006 | ~200 |
| **Total** | | **~2080** |

---

## 5. Alternatives considered

- **Runtime URDF loading (current ROS approach)** — works but
  defeats compile-time guarantee.
- **In-line frame graph declaration** (don't read URDF) — duplicates
  info that already exists in URDF; recipe for drift.
- **Separate manifest (TOML/YAML)** instead of URDF — fragments
  ecosystem; URDF is the standard.
- **Skip URDF entirely** — leaves runtime gap for the lookup case.

## 6. Open questions

1. URDF macros (xacro) — invoke xacro tool at compile time? Recommend
   yes via `xacro --inorder`.
2. Joint state queries (`tf.transform_at_joint_state`)? Out of scope;
   v0.6.
3. URDF v2 (proposed) — spec not stable. Stay with v1 + xacro for
   v0.5; revisit for v0.7.
4. SDF support timing — v0.6 or v0.7? Recommend v0.6 since Gazebo
   integration matters.
5. Time-varying transforms (e.g., joint motion) still need runtime
   TF buffer; that's expected.

## 7. Definition of done

- [ ] `#[urdf]` parses and synthesizes `Frame` impls
- [ ] Static lookup verification works across single and multiple
      URDFs
- [ ] Joint metadata (type, axis, limits) accessible
- [ ] Demo: UR5 IK request, frame chain verified at compile time
- [ ] CHANGELOG documents URDF integration

## 8. Future extensions

- SDF support (v0.6)
- Joint state queries (v0.6)
- URDF v2 (when stable)
- Visual / collision mesh import (v0.7+, for sim integration)
- Inertia / mass parameters from URDF for dynamics-aware control
  generation (v0.7+)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.5 schedule and RFC-0003
- [ ] LOC budget ~2080 fits
- [ ] Pitch survives ("the URDF-tree typo that crashed your robot
      becomes a compile error")
