# Helper1 ROBO-7 Stdlib Migration Ledger v0841

Branch: `fix/helper1-robo7-stdlib-frame-migration-v0841`

Base: `origin/main` at `4fa86e027a08f5e83dbc6e931dd42e1234894a21`

Assignment:
`C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_helper2_wave5_v0840\findings\_helper1_assignment_v0828_r11_qsim_auto_entangle_2026-05-06.md`

## Result

ROBO-7 stdlib migration advanced from compiler-only diagnostic coverage to
an adopter-facing `kinematics.nr` typed pose facade. Existing handle-level
`pose_*` APIs remain unchanged. `tf.nr` and `se3.nr` were reviewed and
intentionally deferred because their public surfaces are raw frame IDs or
raw pointer tuples, not `Pose` values; full migration there needs the
`Transform<From, To>` / FRAME-002 / FRAME-003 surface.

## Candidate Signature Ledger

| File | Public candidate | Decision | Reason | Fixture / evidence |
|---|---|---|---|---|
| `stdlib/rods/kinematics.nr` | `struct Pose { translation: i64, rotation: i64 }` | Migrated | Adds zero-cost phantom-frame type position over existing Vec3 / Quat handles. | `tests/features/robo7_kinematics_typed_pose_smoke.nr` |
| `stdlib/rods/kinematics.nr` | `kinematics_pose(pos, quat) -> Pose<Frame_Unknown>` | Migrated | Backwards-compatible migration constructor; `Frame_Unknown` keeps untagged adopters moving. | Positive smoke: unknown -> camera -> unknown |
| `stdlib/rods/kinematics.nr` | `kinematics_pose_pos(Pose<Frame_Unknown>) -> i64` | Migrated | Typed field accessor without changing runtime ABI. | Positive smoke checks composed x translation |
| `stdlib/rods/kinematics.nr` | `kinematics_pose_quat(Pose<Frame_Unknown>) -> i64` | Migrated | Typed field accessor without changing runtime ABI. | Covered by successful build of typed facade |
| `stdlib/rods/kinematics.nr` | `kinematics_pose_compose(Pose<Frame_Unknown>, Pose<Frame_Unknown>) -> Pose<Frame_Unknown>` | Migrated | Explicit typed composition wrapper around existing pose math; wildcard return preserves migration compatibility. | Positive smoke uses transform wrappers backed by compose |
| `stdlib/rods/kinematics.nr` | `kinematics_transform(Pose<Frame_Unknown>, Pose<Frame_Unknown>) -> Pose<Frame_Unknown>` | Migrated | Canonical explicit-transform spelling matching FRAME-001 fix guidance. | Successful typed smoke build |
| `stdlib/rods/kinematics.nr` | `kinematics_transform_camera_to_base(Pose<Frame_Camera>, Pose<Frame_Unknown>) -> Pose<Frame_Base>` | Migrated | First explicit frame-changing public API; gives call-site FRAME-001 on wrong input frame. | Positive smoke; negative mismatch fixture |
| `stdlib/rods/kinematics.nr` | `kinematics_transform_base_to_camera(Pose<Frame_Base>, Pose<Frame_Unknown>) -> Pose<Frame_Camera>` | Migrated | Symmetric explicit frame-changing public API for the common base/camera path. | Positive smoke |
| `stdlib/rods/kinematics.nr` | Legacy `pose`, `pose_identity`, `pose_pos`, `pose_quat`, `pose_compose`, `pose_inverse`, `pose_apply`, `pose_free` | Left intentionally untagged | These are the existing i64 handle-level API and must remain ABI/backwards compatible. New typed facade is additive. | Existing kinematics fixtures still build/run |
| `stdlib/rods/kinematics.nr` | Vec3 and quaternion helpers | Not applicable | These do not carry pose/frame semantics yet. Future Point3/Quat frame typing belongs to the broader RFC-0003 surface. | Not part of this queue |
| `stdlib/rods/tf.nr` | `tf_add_frame`, `tf_add_frame_at`, `tf_set_pose`, `tf_set_pose_at`, `tf_lookup`, `tf_lookup_at` | Deferred | Public API is integer frame IDs plus raw t/q buffers. Annotating as `Pose<Frame_Unknown>` would be a source-breaking API replacement, not a local migration. | Existing typed runtime ID wrappers remain |
| `stdlib/rods/tf.nr` | `tf_add_frame_typed`, `tf_set_pose_typed`, `tf_lookup_typed` | Left intentionally untagged | These are runtime ID validation wrappers. Compile-time `Transform<From, To>` typing is a separate FRAME-002/003 surface. | `tests/features/tf_typed_frame_smoke.nr` remains the current coverage |
| `stdlib/rods/se3.nr` | `se3_compose`, `se3_inverse`, `se3_apply`, `se3_relative`, `se3_interpolate`, `se3_log`, `se3_exp`, `se3_distance` | Deferred | Public API is raw pointer buffers; no `Pose` value exists to annotate. Adding a duplicate typed pose here would fragment the kinematics surface. | Future work should layer on `kinematics.nr` typed `Pose` or a new `Transform` type |

## New Fixtures

- `tests/features/robo7_kinematics_typed_pose_smoke.nr`
  - `Frame_Unknown` migration survives stdlib constructor/accessor use.
  - `kinematics_transform_camera_to_base` accepts `Pose<Frame_Camera>` and returns `Pose<Frame_Base>`.
  - `kinematics_transform_base_to_camera` accepts `Pose<Frame_Base>` and returns `Pose<Frame_Camera>`.
  - The transform wrappers use existing runtime pose composition, not a metadata-only retag.

- `tests/err/err_robo7_kinematics_transform_call_mismatch.nr`
  - Passing `Pose<Frame_Base>` to `kinematics_transform_camera_to_base` fails at the stdlib API boundary with `error[FRAME-001]`.

## Remaining Work Before ROBO-7 Phase 4

1. Add a real `Transform<From, To>` type once the compiler supports and diagnoses two-frame transform parameters.
2. Migrate `tf.nr` lookups to return transform values rather than only writing raw output buffers.
3. Add FRAME-002 transform composition checks.
4. Add FRAME-003 transform-application checks.
5. Deprecate `Frame_Unknown` only after adopters have explicit transforms for the major robotics rods.

## Validation

Validation was run after implementation; see heartbeat and final handoff for exact command results.
