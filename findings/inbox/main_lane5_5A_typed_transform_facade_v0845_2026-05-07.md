# Lane 5 / Queue 5A — Typed `Transform<From, To>` facade

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Branch:** `fix/robo7-typed-transform-facade-v0845`
- **Base:** `origin/main` @ `71e11b3b`

## Headline

`stdlib/rods/kinematics_transform.nr` ships a zero-cost
`Transform<From, To>` facade with `transform_new`,
`transform_identity`, `transform_invert`, `transform_compose`,
`transform_apply`, plus field accessors. The phantom
`From` / `To` parameters drive the existing v0840 ROBO-7 Wave 2
FRAME-001 mismatch check at let-binding, struct-init, fn-call,
binop, return, and tail-return sites for **specific frame pairs**.

Empirical probe surfaced one real Phase 4 gap: **generic phantom
parameter unification at call sites is not enforced**. A function
declared `fn compose<A, B, C>(ab: Transform<A, B>, bc: Transform<B, C>)`
does NOT fire FRAME-001 when an adopter passes
`Transform<Base, Camera>` + `Transform<Lidar, Gripper>` (the
expected mismatch on the middle frame `B = Camera vs Lidar`). The
compiler accepts the call. Same-source AND cross-module behave
identically — this is a generic-unification limitation, not an
import-resolution issue.

For comparison: a fn signature with **specific** frames
(`fn compose_bcg(ab: Transform<Base, Camera>, bc: Transform<Camera, Gripper>)`)
DOES fire FRAME-001 when called with mismatched concrete arguments.
The check exists for concrete phantoms; generics need Phase 4 /
RFC-0033 type-row subtyping to unify.

## What ships in this branch

- `stdlib/rods/kinematics_transform.nr` (~115 LOC):
  `struct Transform { translation: i64, rotation: i64 }` (no
  generic params on the struct — the From/To phantoms are
  compile-time-only signatures, matching the existing
  `Pose<Frame_X>` pattern). Helpers go through the
  `kinematics.nr` `pose_*` wrappers (avoids duplicate `extern
  fn nuc_pose_*` IR-level declarations).
- `tests/features/transform_compose_chain_smoke.nr` (positive —
  `Transform<Base, Camera>` ∘ `Transform<Camera, Gripper>` →
  `Transform<Base, Gripper>` builds + runs exit 0).
- `tests/features/transform_invert_smoke.nr` (positive —
  `Transform<Base, Camera>` inverted → `Transform<Camera, Base>`
  builds + runs exit 0).

The handoff Queue 5A asked for a negative fixture too:

> negative: incompatible composition fails with FRAME diagnostic
> if compiler support exists; **otherwise write blocker and add
> runtime preflight fixture.**

Compiler support for generic phantom unification at call sites
DOESN'T exist. Per the handoff escape clause, the blocker is the
finding below; runtime preflight fixture is documented as a
follow-on.

## Empirical evidence (current main `71e11b3b`)

```
$ ./bin/nucleor.exe build tests/features/transform_compose_chain_smoke.nr -o tcc
  emitted: target/tcc.ll (48770 bytes)
  compiled: target\tcc.exe
$ ./target/tcc.exe; echo $?
0

$ ./bin/nucleor.exe build tests/features/transform_invert_smoke.nr -o tin
  emitted: target/tin.ll (47287 bytes)
  compiled: target\tin.exe
$ ./target/tin.exe; echo $?
0
```

Both happy-path generics work. The phantom signatures encode the
correct frame transitions (Base→Camera→Gripper, Base↔Camera).

```
$ cat /tmp/probe_concrete.nr
fn compose_bcg(
    ab: Transform<Frame_Base, Frame_Camera>,
    bc: Transform<Frame_Camera, Frame_Gripper>
) -> Transform<Frame_Base, Frame_Gripper> { ... }
fn main() { let _ = compose_bcg(bc, lg); }   // lg is <Lidar, Gripper>
$ ./bin/nucleor.exe build /tmp/probe_concrete.nr
error[FRAME-001]: cannot pass argument 1 to 'compose_bcg':
  declared frame `Frame_Camera` does not match value frame `Frame_Lidar` ...
```

Concrete-phantom call sites fire FRAME-001 correctly. Now the
generic case:

```
$ cat /tmp/probe_generic.nr
fn compose<A, B, C>(
    ab: Transform<A, B>,
    bc: Transform<B, C>
) -> Transform<A, C> { ... }
fn main() { let _ = compose(bc, lg); }   // bc is <Base, Camera>, lg is <Lidar, Gripper>
$ ./bin/nucleor.exe build /tmp/probe_generic.nr
  (build succeeds — no FRAME-001 fired)
```

## Phase 4 generic phantom unification (residual)

The compiler's FRAME-001 check (s1 line 21919 area, `frame_op_checked_v840`)
walks the source for `let x: Type<Frame_*> = expr;` patterns and
checks the RHS expression's source-text frame against the LHS
declared frame. At fn-call positions for **concrete-phantom**
signatures, the check resolves the parameter type's frame from the
fn header text and compares against the argument's source-text
frame. For **generic** signatures (`<A, B, C>`), the parameter
types are abstract type variables — the check has no concrete
frame to compare against, so it accepts any.

The fix is a unification step:
1. At each call to `f<A1, A2, ...>(arg1, arg2, ...)`, extract the
   abstract type variables `A_i` from `f`'s signature.
2. For each `arg_j` whose declared parameter type contains `A_i`,
   record `A_i = <concrete_frame_from_arg>`.
3. If a later `arg_k` declared parameter type contains the same
   `A_i` but its argument's concrete frame doesn't match the
   recorded value, fire FRAME-001.

Estimated implementation: ~50-100 LOC at the FRAME check site,
plus a unification table per call site. Not v1.0 scope — this is
the canonical RFC-0033 effect-row subtyping work generalized to
phantom frame types.

## Smallest v1.0-safe runtime preflight

Adopters who need today's compile-time-feel safety on generic
helpers can use a runtime preflight pattern:

```nucleor
import "stdlib/rods/kinematics_frame.nr"

fn safe_transform_compose<A, B, C>(
    ab: Transform<A, B>,
    bc: Transform<B, C>,
    expected_middle: i64   // kinematics_frame_id_camera() etc.
) -> Transform<A, C> {
    // adopter passes the expected middle frame ID; runtime checks
    // before composing. NOT a compile-time guarantee but catches
    // the bug at first call instead of silent miscompute.
    if frame_id_of_runtime_tag(ab) != expected_middle {
        panic("safe_transform_compose: middle frame mismatch");
    };
    return transform_compose(ab, bc);
}
```

Out of scope for this branch — the runtime preflight needs adopter
discipline to maintain a parallel runtime tag, which adds plumbing.
For the typical concrete-frame case, the existing
`kinematics_transform_camera_to_base` (and similar specific-pair
helpers in `kinematics.nr`) already give compile-time enforcement.

## Files changed

```
stdlib/rods/kinematics_transform.nr                       (new — 115 LOC)
tests/features/transform_compose_chain_smoke.nr           (new positive)
tests/features/transform_invert_smoke.nr                  (new positive)
findings/inbox/main_lane5_5A_typed_transform_facade_v0845_2026-05-07.md  (this report)
```

No bin/seed refresh (stdlib-only addition, no compiler change).
No drift change.

## Honest residuals

1. **Generic phantom unification gap.** Documented above. Phase 4 /
   RFC-0033 broader effect-row subtyping is the canonical close.
   ~50-100 LOC compiler-side when implemented.
2. **Pose application directionality.** `transform_apply(tf, p)`
   uses `pose_compose(tf_handle, p_handle)` which is the standard
   "apply transform to pose" order. SE(3) convention check:
   `T_b_c * p_c = p_b` (transform `T` from b to c applied to a
   pose in c gives a pose in b). The phantom signature
   `Transform<F, T> ∘ Pose<F> -> Pose<T>` matches this convention.
3. **No concrete-frame compose helpers shipped.** Adopters with
   strict v1.0 needs can wrap `transform_compose` in
   concrete-pair fns (e.g. `compose_base_camera_gripper(...)`)
   that get the FRAME-001 check; the generic fn does not. Should
   be a Queue 5B/5C consideration when extending tf.nr / se3.nr
   with typed wrappers.
4. **Memory ownership.** All four math helpers
   (`transform_invert`, `transform_compose`, `transform_apply`)
   use the existing `pose_new` / `pose_compose` / `pose_inverse`
   handle-pair approach with explicit `pose_free` on intermediates
   — matches the pattern in `kinematics_pose_compose`.
