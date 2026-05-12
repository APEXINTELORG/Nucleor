# RFC-0003 — Typed Coordinate Frames

| Field | Value |
|---|---|
| **Number** | 0003 |
| **Title** | Typed Coordinate Frames — `Pose<F: Frame>`, `Vector3<F: Frame>`, compile-time TF correctness |
| **Status** | Draft |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.4.0 ("Robotics Stack") |
| **Depends on** | RFC-0001 (attribute infrastructure for `#[frame]`) — soft. Independent of RFC-0002. |

---

## 1. Summary

Make the **coordinate frame** a type parameter on every spatial value
(pose, vector, transform, twist, wrench). Today a programmer writes
`fn move_to(target: Pose)` and *hopes* `target` is in the same frame
as the robot's base. Under this RFC:

```nucleor
fn move_to(target: Pose<Frame::BaseLink>) { … }

let p_world: Pose<Frame::World>     = sensor.read();
let p_base:  Pose<Frame::BaseLink>  = tf.transform::<World, BaseLink>(p_world);

move_to(p_world);  // ERROR: Pose<World> != Pose<BaseLink>
move_to(p_base);   // OK
```

Adding a `Pose<World>` and a `Pose<BaseLink>` is a **compile error**.
The user is forced to call `tf.transform()` to convert. The transform
function is provided by `rod/tf2.nr` and looks up the World→BaseLink
transform at runtime.

This eliminates **the #1 source of bugs in robotics**: silently mixing
coordinate frames. NASA's Mars Climate Orbiter is the most famous unit
bug; the equivalent *every-week* bug in robotics is putting a
camera-frame point into a base-frame planner.

**No other robotics language ships this.** ROS 2's `tf2` library
catches the bug *at runtime*, after the value has been used. Nucleor
catches it *at compile time*.

---

## 2. Motivation

### 2.1 The problem

Every robot has many coordinate frames:

```
world
└── map
    └── odom
        └── base_footprint
            └── base_link
                ├── camera_optical
                ├── lidar_link
                ├── arm_base
                │   └── shoulder
                │       └── elbow
                │           └── wrist
                │               └── end_effector
                │                   └── tool0
                └── ...
```

10–50 frames is common. ~10% of robotics bugs come from passing a
value in the wrong frame. The bug is catastrophic — a planner told
"the object is at (1.2, 0.0, 0.5)" in camera frame when it expected
base frame will plan a motion that crashes the arm into the camera.

### 2.2 What other languages do

| System | Approach | Limitation |
|---|---|---|
| **ROS 1 / ROS 2 (tf / tf2)** | Runtime frame lookup. Every spatial value has a `frame_id` string field. | Runtime check; missed transforms produce wrong-frame outputs that look correct |
| **C++** | Convention. Sometimes a wrapper class `PoseInFrame { frame_id: string; pose: Pose; }`. | String-typed; `transform("base_link", ...)` typo causes silent failure |
| **Eigen / glm / nalgebra** | Generic-over-scalar, but frames are not types. | Designed for math, not robotics |
| **Drake** | C++ template-based — `RigidTransform<T>` is generic over frame *names* via tag types. | Closest prior art. C++-specific. Nobody else has copied it. |
| **MATLAB** | `rigidtform3d` with frame names; runtime checked. | Same as ROS — runtime only |

**Drake's tag-type approach is the right model**, but it's locked in
C++ template metaprogramming. Nucleor can ship the same idea as a
first-class language feature with sane syntax and full compiler
support.

### 2.3 What we want

```nucleor
let cam_to_base: Transform<Frame::CameraOptical, Frame::BaseLink> = …;
let world_to_base: Transform<Frame::World, Frame::BaseLink> = …;

let obj_in_cam: Point3<Frame::CameraOptical> = perception.detect();
let obj_in_base: Point3<Frame::BaseLink> = cam_to_base.apply(obj_in_cam);

// Try to use without transforming:
planner.move_to(obj_in_cam);    // ERROR
planner.move_to(obj_in_base);   // OK

// Try to compose mismatched transforms:
let bad = cam_to_base * world_to_base;   // ERROR — cam→base then world→base doesn't compose
let good = cam_to_base * cam_to_world;   // ERROR if cam_to_world doesn't exist
let good = world_to_base * cam_to_world; // OK: cam→world→base
```

The compiler catches:
- Frame mismatch on function calls.
- Adding/multiplying values in different frames.
- Composing transforms that don't compose (output of A doesn't match
  input of B).
- Forgetting to transform.

---

## 3. Design

### 3.1 The `Frame` trait

```nucleor
trait Frame {
    const NAME: &'static str;
}
```

Frames are zero-sized **tag types**. Users (and stdlib) define their
own frames by implementing `Frame`:

```nucleor
struct World;       impl Frame for World       { const NAME: &str = "world"; }
struct BaseLink;    impl Frame for BaseLink    { const NAME: &str = "base_link"; }
struct CameraOptical; impl Frame for CameraOptical { const NAME: &str = "camera_optical"; }
```

`stdlib/rods/tf_common.nr` ships ~30 standard frames covering the
ROS 2 / REP-105 / REP-103 conventions (`world`, `map`, `odom`,
`base_link`, `base_footprint`, `camera_optical`, `lidar_link`, etc.).
Users add their own as needed.

### 3.2 The spatial types

```nucleor
struct Point3<F: Frame> { x: f64, y: f64, z: f64 }
struct Vector3<F: Frame> { x: f64, y: f64, z: f64 }
struct Quat<F: Frame> { x: f64, y: f64, z: f64, w: f64 }
struct Pose<F: Frame> { translation: Point3<F>, rotation: Quat<F> }
struct Twist<F: Frame> { linear: Vector3<F>, angular: Vector3<F> }
struct Wrench<F: Frame> { force: Vector3<F>, torque: Vector3<F> }
struct Transform<From: Frame, To: Frame> { … }
```

All are `#[no_alloc, no_panic]`-friendly (POD-ish, no heap, no
panic-on-arithmetic).

### 3.3 Operator semantics

| Operation | Allowed? | Result type |
|---|---|---|
| `Point3<F> + Vector3<F>` | yes (translate point) | `Point3<F>` |
| `Point3<F> + Point3<F>` | NO (mathematically meaningless) | error |
| `Point3<F> - Point3<F>` | yes (point difference is a vector) | `Vector3<F>` |
| `Vector3<F> + Vector3<F>` | yes | `Vector3<F>` |
| `Pose<F> * Pose<G>` (composition) | NO (they're absolute, not relative) | error |
| `Transform<A, B> * Transform<B, C>` | yes | `Transform<A, C>` |
| `Transform<A, B> * Pose<A>` | yes (apply transform) | `Pose<B>` |
| `Transform<A, B> * Pose<C>` (C ≠ A) | NO | error |
| `Transform<A, B>.inverse()` | yes | `Transform<B, A>` |

Diagnostic for the most common mistake:

```
error[FRAME-001]: cannot add values in different coordinate frames
  --> src/planner.nr:42:21
   |
40 | let cam_pt: Point3<CameraOptical> = …;
41 | let base_pt: Point3<BaseLink> = …;
42 | let bad = cam_pt + base_pt;
   |                    ^^^^^^^ expected Point3<CameraOptical>, found Point3<BaseLink>
   |
   = note: cannot add Point3<CameraOptical> and Point3<BaseLink> directly
   = help: transform first: tf.lookup::<CameraOptical, BaseLink>(time).apply(cam_pt) + base_pt
```

### 3.4 The `tf2` rod — runtime transform lookup

```nucleor
struct Tf2Buffer { … }   // wraps ROS 2's tf2 buffer or our own native impl

impl Tf2Buffer {
    /// Look up the transform from `From` to `To` at the given time.
    /// Returns Err if the transform is unknown or the frame chain
    /// has gaps.
    fn lookup<From: Frame, To: Frame>(&self, t: Instant)
        -> Result<Transform<From, To>, TfError>;

    /// Look up the latest transform (use most recent data).
    fn lookup_latest<From: Frame, To: Frame>(&self)
        -> Result<Transform<From, To>, TfError>;
}
```

Runtime: TF buffer maintains a graph of frame-to-frame transforms
keyed by `(from_name, to_name, time)`. Lookups resolve the frame
chain (e.g., `World → Map → Odom → BaseLink`) via Dijkstra-style path
finding.

The compile-time `From: Frame` and `To: Frame` types correspond at
runtime to the `From::NAME` / `To::NAME` strings, which are what the
TF buffer indexes by. Type parameters are erased after monomorphization;
the runtime call uses the strings.

**Composition with `#[no_alloc]`:** TF lookup may allocate (graph
search uses a priority queue). Mark `Tf2Buffer::lookup` as
`may_alloc`. RT users should pre-fetch transforms outside the control
loop:

```nucleor
fn pre_fetch_transforms(tf: &Tf2Buffer, t: Instant) -> Transforms {
    Transforms {
        cam_to_base:   tf.lookup::<CameraOptical, BaseLink>(t).unwrap(),
        world_to_base: tf.lookup::<World, BaseLink>(t).unwrap(),
        // ...
    }
}

#[no_alloc, deadline = 1ms]
fn control_step(s: &mut State, tx: &Transforms, obs: &Observation) {
    let obj_base: Point3<BaseLink> = tx.cam_to_base.apply(obs.detection);
    s.controller.update(obj_base);
}
```

### 3.5 Static frame chains (compile-time inference)

In some scenarios the frame chain is known at compile time (URDF
defines a static tree). For these, the compiler can verify that a
chain `tf.lookup::<A, C>()` exists by reading the URDF at compile
time and checking the tree.

```nucleor
#[urdf = "robots/ur5.urdf"]
mod robot { … }

// The compiler reads ur5.urdf and synthesizes:
//   Frame impls for every link
//   A static-known chain map base_link ↔ shoulder ↔ ... ↔ tool0
//   Compile-time verification that lookup<A, C> has a path

fn check() {
    tf.lookup::<robot::ShoulderLink, robot::Tool0>();   // OK at compile time
    tf.lookup::<robot::Tool0, World>();                 // ERROR: World not in URDF tree
}
```

This is a stretch goal for v0.4. v0.4 ships dynamic-only TF; v0.5
adds URDF-aware compile-time verification.

### 3.6 The `Stamped<T>` wrapper

ROS messages typically pair a value with a timestamp and frame:

```nucleor
struct Stamped<T> {
    value: T,
    stamp: Instant,
    // The frame is encoded in T's type parameter, so no string field.
}

// e.g., Stamped<Point3<CameraOptical>> replaces ROS's PointStamped
```

Removes the runtime frame-string overhead from ROS-derived APIs.

### 3.7 Composition with `tainted<T>`

DDS/ROS messages arrive as `tainted<T>`. After parsing, they have a
runtime frame string but no compile-time frame type. To use them in
typed code:

```nucleor
fn into_typed<F: Frame>(t: tainted<PointStamped>) -> Result<Point3<F>, FrameMismatch> {
    if t.frame_id != F::NAME {
        return Err(FrameMismatch { expected: F::NAME, found: t.frame_id });
    }
    Ok(Point3 { x: t.x, y: t.y, z: t.z })
}
```

This is the **trust boundary**: untyped (`tainted<T>` with frame
string) on the wire, typed (`Point3<F>`) inside the program. Lossy
in one direction (typed → tainted just drops the type), checked in
the other (tainted → typed verifies the frame string).

### 3.8 Erasure for FFI

When passing a `Pose<F>` to a C function:

```nucleor
extern fn solve_ik(
    target: *const PoseRaw,   // C struct, no frame
    out:    *mut JointAngles
) -> i32;

fn ik(target: Pose<Frame::BaseLink>, out: &mut JointAngles) -> i32 {
    let raw: PoseRaw = target.erase();   // strip frame type
    unsafe { solve_ik(&raw, out) }
}
```

`Pose<F>::erase()` is the explicit downcast; the user is asserting
that the C function will use the data correctly. Compile-time frame
checking cannot extend across FFI; this is the escape hatch.

### 3.9 Dynamic frames — when types aren't known at compile time

Sometimes the frame is data-driven (e.g., a multi-camera system where
the active camera is selected at runtime). For these:

```nucleor
struct DynPoint3 {
    x: f64, y: f64, z: f64,
    frame: FrameId,    // runtime string
}

impl DynPoint3 {
    fn into_typed<F: Frame>(self) -> Result<Point3<F>, FrameMismatch> { … }
    fn from_typed<F: Frame>(p: Point3<F>) -> DynPoint3 { … }
}
```

This is the dynamic-frame escape hatch. Use sparingly; lose the
compile-time guarantee.

---

## 4. Implementation

### 4.1 Compiler changes

| Component | Change | LOC est. |
|---|---|---|
| Type checker | Reject mismatched-frame operators | ~150 |
| Codegen | Erase frame parameters at monomorphization | ~50 |
| Diagnostics | FRAME-001…FRAME-005 with span tracking | ~150 |
| URDF reader (v0.5) | Parse URDF, synthesize Frame impls + static chain map | ~400 |
| Const-frame chain verification (v0.5) | Static path-find in URDF tree | ~150 |
| **Total v0.4** | | **~350** |
| **Total v0.5 (URDF)** | | **+550** |

Note: this RFC is *small* in compiler work. The leverage comes from
generic types + trait bounds, both of which already exist in the
language. We're adding a marker trait + diagnostic tweaks.

### 4.2 Runtime changes

| Component | Change | LOC est. |
|---|---|---|
| `runtime/tf2_rt.c` | Frame graph + Dijkstra path-find + interpolation | ~800 |
| `runtime/quat_rt.c` | Quaternion math (slerp, normalize, etc.) | ~250 |
| `runtime/transform_rt.c` | Transform composition / application | ~150 |
| **Total** | | **~1200** |

### 4.3 Stdlib changes

| Rod | Status |
|---|---|
| `stdlib/rods/frame.nr` | NEW — `Frame` trait, REP-105 frame defs |
| `stdlib/rods/spatial.nr` | NEW — `Point3<F>`, `Vector3<F>`, `Pose<F>`, `Twist<F>`, `Wrench<F>` |
| `stdlib/rods/transform.nr` | NEW — `Transform<From, To>`, composition rules |
| `stdlib/rods/tf2.nr` | NEW — `Tf2Buffer`, runtime lookup |
| `stdlib/rods/quat.nr` | NEW — quaternion math (currently in linalg) |
| `stdlib/rods/dyn_spatial.nr` | NEW — `DynPoint3`, `DynPose`, etc. |

### 4.4 Test plan

- **Unit tests:**
  - `tests/lang/frame_basic.nr` — define a frame, construct
    `Point3<F>`, verify it works.
  - `tests/lang/frame_transform.nr` — apply a transform, compose
    transforms.
- **Negative tests:**
  - `tests/err/err_frame_add_mismatch.nr`
  - `tests/err/err_frame_compose_mismatch.nr`
  - `tests/err/err_frame_apply_mismatch.nr`
- **Integration test:**
  - `tests/features/typed_tf_loop.nr` — full perception → planning
    pipeline with all frame transitions explicit.
- **Showcase:**
  - `examples/14_typed_frames.nr` — visual demo of the type-safety
    win. Includes commented-out code showing the diagnostic for each
    common mistake.

### 4.5 Migration

This is purely additive. Existing code (which uses untyped `Pose`)
continues to work — `Pose` becomes an alias for
`Pose<Frame::Unknown>`, where `Unknown` is a wildcard frame that
permits any operation (with a warning). Users opt into typed frames
by switching to explicit `Pose<F>`.

In v0.5 we deprecate `Frame::Unknown` and require explicit frames
everywhere. v0.6 removes `Unknown`.

---

## 5. Alternatives considered

### 5.1 String-typed frames (current ROS approach)

Just adopt `frame_id: String` as a struct field. Runtime check.

**Rejected:** that's exactly what ROS does and exactly the problem
we're trying to fix. Compile-time is the win.

### 5.2 Const-string generics

`Pose<const FRAME: &'static str>` — frame is a const string parameter.

**Rejected:** const-string generics are a heavy compiler feature
(Rust didn't get them until 1.79). Tag types are simpler and at least
as expressive.

### 5.3 Macro-generated frame types

Frame definitions via a macro: `frames! { World, BaseLink, ... }`.

**Possible additive:** v0.5 can add such a macro, but the underlying
mechanism is still the `Frame` trait. Macro is sugar.

### 5.4 Inferred frames from URDF only

Only allow frames that come from a URDF file. No user-defined.

**Rejected:** too restrictive. Many robotics scenarios (mobile,
multi-robot) define frames outside any URDF.

---

## 6. Open questions

1. **What about 2D frames?**
   Mobile robots often work in `Pose2D = (x, y, theta)`. Should we
   ship `Pose2D<F>` separately, or use `Pose<F>` with z=0?

   Recommend **separate `Pose2D<F>` type**. 2D math has its own
   gotchas (theta wrap-around) and overloading the 3D type adds
   confusion.

2. **Frame inheritance / hierarchy.**
   Should `Frame::CameraOptical` "inherit from" `Frame::BaseLink`
   (since it's a child in the TF tree)? This would allow implicit
   conversions but breaks the compile-time guarantee.

   Recommend **no inheritance**. Frames are tags; transforms are
   explicit. Implicit conversion is the bug source we're trying to
   eliminate.

3. **What does `Pose<F>::default()` mean?**
   The identity pose? In which frame? Defaulting to a frame is
   semantically dubious.

   Recommend **`Pose::<F>::identity()` (explicit) only**. No
   `default()`.

4. **Should transforms time-stamp?**
   Real TF transforms are time-varying. `Transform<From, To>` doesn't
   capture this; should we add `Stamped<Transform<...>>` everywhere?

   Recommend **separate types**:
   - `Transform<From, To>` — time-instantaneous, used in code.
   - `TimedTransform<From, To>` — has a `stamp: Instant`, used by TF
     buffer.
   `Tf2Buffer::lookup(...)` returns `Transform`, having pinned the
   time at lookup.

5. **Performance impact.**
   Each frame is a separate monomorphization. Could explode binary
   size for code that uses many frames in many functions.

   Recommend **mitigate via `Allocator`-style erasure**: provide
   `dyn Frame`-style runtime-typed `DynPose` for code that doesn't
   need compile-time guarantees in some sections, with explicit
   conversion at the boundaries.

6. **Composition with optimization.**
   The optimizer should constant-fold `Transform<A, B>::identity() *
   Transform<B, C>::identity()` to `Transform<A, C>::identity()`.
   Make sure the algebraic-laws system handles this.

   Recommend **add `@law(left_identity, right_identity)` to
   transform composition**. CTFE handles the rest.

---

## 7. Definition of done

- [ ] `Frame` trait spec'd and lives in `stdlib/rods/frame.nr`
- [ ] 30+ REP-105 standard frames ship in `stdlib/rods/frame_std.nr`
- [ ] `Point3<F>`, `Vector3<F>`, `Pose<F>`, `Quat<F>`, `Twist<F>`,
      `Wrench<F>`, `Transform<From, To>` parse, type-check, codegen
- [ ] Operator type rules from §3.3 enforced; FRAME-001…005
      diagnostics fire correctly
- [ ] `Tf2Buffer::lookup<From, To>(t)` returns `Transform<From, To>`
      with runtime frame-graph traversal
- [ ] `tests/lang/frame_*.nr` and `tests/err/err_frame_*.nr` pass
- [ ] `tests/features/typed_tf_loop.nr` compiles and runs end-to-end
      using simulated TF data
- [ ] `examples/14_typed_frames.nr` ships
- [ ] CHANGELOG documents the typed-frames feature and migration story
- [ ] `Frame::Unknown` exists in v0.4 with deprecation warning;
      removed in v0.6

---

## 8. Future extensions

- **URDF-aware static frame chains** (v0.5 — see §3.5).
- **Velocity transform automation** — `Twist<F>` cross-frame is more
  subtle than `Pose<F>` (involves the relative velocity of the
  frames). Auto-derive from TF chain in v0.6.
- **Force/torque transform** — `Wrench<F>` cross-frame likewise.
- **Probabilistic frames** — `PoseWithCovariance<F>` and proper
  covariance propagation through transforms (v0.7).
- **Inertial / accelerated frames** for control theory (Coriolis,
  centrifugal corrections) — research territory; v0.8+.
- **2D frame variant** (`Pose2D<F>`) — open question 1.
- **Compile-time typed frame chains for transforms via const generics
  + trait specialization** — research; not for v0.x.

---

## 9. Acceptance checklist

- [ ] Maintainer (Joseph Wescott) approves the design
- [ ] No conflicts with RFC-0001 (RT attributes) or RFC-0002
      (allocators)
- [ ] Compatible with v0.4 release schedule
- [ ] LOC estimates (~350 compiler v0.4 + ~1200 runtime + 6 new rods)
      fit budget
- [ ] Migration story (Frame::Unknown deprecation across v0.4-0.6) is
      acceptable
- [ ] Pitch survives ("compile-time TF correctness — no other
      robotics language ships this")
