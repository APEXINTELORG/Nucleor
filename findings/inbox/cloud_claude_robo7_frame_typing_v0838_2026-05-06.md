# Cloud Claude — ROBO-7 Frame Typing v0838 (2026-05-06)

Dispatch source:
`docs/rfcs/CLOUD_CLAUDE_ROBO7_FRAME_TYPING_DISPATCH_v0838_2026-05-06.md`

## Header

```text
Branch:        claude/review-robo7-frame-typing-Yw8uB (user-assigned)
HEAD:          (post-commit; see git log)
Base:          15bff516417e18be2dd028d5850ffdbe5c5fb114
Merge-base:    15bff516417e18be2dd028d5850ffdbe5c5fb114 (HEAD pre-edit)
origin/main:   advanced past the dispatch SHA between assignment and
               commit; this branch records the actual base above. Merge
               into main is non-conflicting against the slice's surface.
```

## Survey findings (Scope A — design-to-code)

Answers to the dispatch questions, sourced from `compiler/nucleor_s1_compiler.nr`:

1. **Type metadata structure.** Types are stored as canonical strings
   throughout the compiler (no first-class node IDs for types). Generic
   forms are preserved as `Name<arg1, arg2>` strings — `Vec<i32>`,
   `Box<T>`, `HashMap<K, V>`, etc. — produced by `parse_type` (line
   2933). The struct registry indexes by base name only (line 4263
   `parse_struct_decl`). Type-aliases (kind 51) are resolved via
   `type_alias_resolve` at line 19672. Type compatibility is decided
   by `types_compatible(expected, actual)` at line 19430 (string-keyed,
   with explicit Vec/Option/Result/Box arg-recursion paths plus a
   base-name catch-all at line 19618).

2. **Where frame tags naturally attach.** Inside the existing string
   type representation. `parse_type` already accepts arbitrary
   `Name<T1, T2, ...>` shapes, so `Pose<Frame_Camera>` parses without
   any parser change and the binding's stored type-string preserves the
   phantom argument. The cheapest enforcement point is the catch-all
   in `types_compatible` — adding a single early-reject before the
   `same-base = compatible` fall-through is enough to make
   `Pose<Frame_Camera>` and `Pose<Frame_Base>` distinct types.

3. **Robotics APIs that pass frame-sensitive values without check.**
   `stdlib/rods/kinematics_frame.nr` already ships zero-cost
   `Frame_World` / `Frame_Base` / `Frame_Camera` / `Frame_Lidar` /
   `Frame_IMU` / `Frame_Gripper` / `Frame_Map` / `Frame_Odom` /
   `Frame_Unknown` marker structs plus a runtime numeric-ID surface
   (`kinematics_frame_id_camera()`, `kinematics_frame_compatible_strict`,
   `kinematics_frame_assert`, `kinematics_frame_require`,
   `kinematics_frame_check_pair`). The runtime checkers (Phase 1 of
   R07-D1) gate adopter pose-pair operations dynamically, but the bare
   `Pose` and `Vec3` shapes in `stdlib/rods/kinematics.nr` /
   `stdlib/rods/tf.nr` / `stdlib/rods/se3.nr` carry no compile-time
   frame information — the Mars-Climate-Orbiter case sails through the
   type checker.

4. **Positive and negative fixtures expressible today.** Yes, with the
   slice below. Positive fixture exercises five invariants (same-frame
   binding, `Frame_Unknown` left/right migration sentinel, untagged →
   tagged opt-in flow, multi-link chain). Negative fixture proves the
   `Pose<Frame_Camera> = Pose<Frame_Base>` rejection.

5. **Diagnostic code.** `FRAME-001` was already reserved in the
   compiler's recognized-codes list (line 10995) AND the
   `nucleor_tools_suite.nr` explain registry (lines 11439, 11692,
   11918) — title text, short explain text, and detailed explain text
   were all in place but the code never fired. v0838 wires the first
   firing site at the let-binding `TYP-008` location, upgrading the
   diagnostic from generic binding-mismatch to FRAME-001 with the
   canonical Mars-Climate-Orbiter framing and a `kinematics_transform`
   fix pointer.

## Implemented surface (Scope B — minimal compiler-visible frame tag)

Three additions in `compiler/nucleor_s1_compiler.nr`:

1. **`type_frame_tag(t: str) -> str`** (around line 10079) — extracts
   the `Frame_*` phantom tag from the first generic argument of a type
   string, or `""` if the type carries no recognizable frame tag. Hot-path
   skipped instantly on bare types (no `<`).

2. **`frame_mismatch_visible(expected: str, actual: str) -> i64`** —
   returns 1 only when both types have distinct `Frame_*` tags on
   matching base names and neither side is `Frame_Unknown`. Conservative
   by construction: untagged code is unaffected, the migration sentinel
   passes through, base-name mismatches are deferred to the existing
   checks.

3. **`types_compatible` early-reject** (line ~19490) —
   `if frame_mismatch_visible(expected, actual) == 1 { return 0; };`
   inserted before the same-base catch-all. Makes the rejection global
   (every callsite of `types_compatible` benefits) without disturbing
   any other compatibility rule.

4. **FRAME-001 emit at let-binding TYP-008 site** (line ~22577) —
   when the binding type-check fails AND the mismatch is specifically a
   frame mismatch, fire `error[FRAME-001]` with the Mars-Climate-Orbiter
   framing instead of generic `TYP-008`. Untagged-type mismatches
   continue to fire TYP-008 unchanged.

5. **Audit-pass narrative refresh** (lines ~31028, 31294) — the
   `info[QM-7-ROBO-7]` narrative previously stated "Phase B compiler-side
   TYP-008 frame-mismatch check is NOT yet shipped — Mars-Climate-Orbiter
   failure mode live"; refreshed to describe the v0838 ship surface
   accurately so the compiler does not contradict itself in its own info
   stream.

## Positive fixture

`tests/features/robo7_frame_positive_smoke.nr` — five invariants:

1. Same-frame let binding compiles (`Pose<Frame_Camera>` →
   `Pose<Frame_Camera>`).
2. `Frame_Unknown` on the source side flows into `Pose<Frame_Camera>`
   (migration sentinel, RFC-0046 §migration).
3. `Pose<Frame_Lidar>` flows into `Pose<Frame_Unknown>` (sink-side
   migration sentinel).
4. Untagged `Pose` flows into `Pose<Frame_Base>` (one-sided opt-in:
   adopters tag without breaking every existing call site).
5. Three-link same-frame chain (`Pose<Frame_Gripper>` ×3) preserves the
   tag through each link.

Result: build OK, `target/_robo7_pos` rc=0.

## Negative fixture

`tests/err/err_robo7_frame_mismatch.nr` — `Pose<Frame_Camera>` declared
binding initialized from a `Pose<Frame_Base>` value. Result:

```text
error[FRAME-001]: cannot initialize binding 'p_camera': declared
frame `Frame_Camera` does not match value frame `Frame_Base` (declared
type `Pose<Frame_Camera>` vs value type `Pose<Frame_Base>`). Mixing
coordinate frames at runtime is the Mars-Climate-Orbiter failure mode
— apply the explicit transform (e.g. `kinematics_transform` from
stdlib/rods/kinematics.nr) or annotate the binding with the source
frame, and re-check.
```

## Diagnostics

- **FRAME-001** — first firing site landed v0838. Code was already
  registered in the recognized-codes list and the explain registry;
  no new wiring required in `nucleor_tools_suite.nr`.
- **TYP-008** — unchanged for non-frame mismatches. Verified by
  re-running `tests/err/err_unit_assign.nr`,
  `tests/err/err_struct_int_to_bool.nr`,
  `tests/err/err_fixed_width_mismatch.nr` — all still fire TYP-008
  with their original message bodies.

## Files changed

```text
compiler/nucleor_s1_compiler.nr           (+~70 lines: helpers, hook, emit, narrative refresh)
docs/rfcs/v1_PUNCHLIST.md                 (ROBO-7 entry rewritten with proven status)
docs/spec/Nucleor_Error_Codes.md          (FRAME series gains LIVE/RESERVED status column + firing surface notes)
tools/audit_dup_fns_report.csv            (regenerated via tools/audit_dup_fns.nr — line counts grew for types_compatible / type_check_stmt)
tests/features/robo7_frame_positive_smoke.nr   (NEW — 5 invariants)
tests/err/err_robo7_frame_mismatch.nr          (NEW — FRAME-001 fires)
findings/inbox/cloud_claude_robo7_frame_typing_v0838_2026-05-06.md  (this file)
```

No edits to `compiler/nucleor_tools_suite.nr`, `bin/`, `bootstrap/`,
`tools/check_compiler_drift.sh`, or `tools/verify*.{sh,ps1}` — the
dispatch's "do not touch" list is honored.

## Validation

```text
git diff --check                                  : clean
bash tools/check_compiler_drift.sh                : OK on every gate that
                                                    matters for a compiler
                                                    edit (ABI parity,
                                                    compiler-identity,
                                                    audit_dup_fns_report,
                                                    manifests, CHANGELOG ↔
                                                    git-tag, version
                                                    label). Pre-existing
                                                    parser-divergence
                                                    WARNs unchanged
                                                    (RFC-0063 Phase 2.0).
                                                    Linux-only caveat:
                                                    when bin/nucleor.exe
                                                    is present alongside
                                                    bin/nucleor (Linux
                                                    ELF), the script
                                                    prefers the .exe and
                                                    fails the version
                                                    probe — re-running
                                                    with the .exe
                                                    out-of-path passes
                                                    the version gate.
                                                    Pre-existing platform
                                                    issue, not from this
                                                    slice.
self-host stage-2 rebuild                         : clean compile,
                                                    `target/nucleor_s2`
                                                    promoted to
                                                    bin/nucleor for the
                                                    fixture runs.
tests/features/robo7_frame_positive_smoke.nr      : build OK, run rc=0
tests/err/err_robo7_frame_mismatch.nr             : build emits
                                                    error[FRAME-001]
                                                    with the documented
                                                    framing
existing fixture regression (7 frame-related)     : kinematics_frame_smoke,
                                                    pose_frame_audit_smoke,
                                                    pose_frame_check_smoke,
                                                    robotics_typed_pose_chain_smoke,
                                                    tf_typed_frame_smoke,
                                                    robo14_end_to_end_smoke,
                                                    robo_limitations_smoke
                                                    — all build + run rc=0
existing fixture regression (30 tests/lang)       : 30/30 build + run rc=0
existing TYP-008 fixtures                         : err_unit_assign,
                                                    err_struct_int_to_bool,
                                                    err_fixed_width_mismatch
                                                    — all still emit
                                                    error[TYP-008] with
                                                    original messages
```

Perf check (`tools/check_perf_regression.sh`) was NOT run because the
type-check traversal change is bounded to a single early-reject branch
keyed on a cheap `type_first_arg` + `str_starts_with("Frame_")` probe
on types that already passed the `<`-presence check inside
`type_first_arg`. The hot-path overhead on non-frame code is two
short-circuited string comparisons per `types_compatible` call. If
follow-up work expands the firing surface across struct-init / call /
binop sites the perf gate should be rerun.

## Remaining blockers

None for the dispatched slice. Follow-on work surfaced during the
survey:

1. **Phase B step-3 — broaden firing surface beyond let-binding.**
   `frame_mismatch_visible` is already wired into the global
   `types_compatible`, so cross-frame mismatches at struct-init,
   function-call argument, and binop operand sites will be REJECTED
   correctly today — but the diagnostic emitted is the generic
   site-specific TYP-008/TYP-013/TYP-017/etc. instead of FRAME-001 with
   the canonical framing. Each of those sites needs the same
   `frame_mismatch_visible` pre-check + FRAME-001 emit upgrade applied
   to the let-binding site in v0838.
2. **Stdlib-rod migration.** `stdlib/rods/kinematics.nr`,
   `stdlib/rods/tf.nr`, `stdlib/rods/se3.nr` still expose bare `Pose`
   in their function signatures. Migrating to `Pose<Frame_Unknown>`
   (with explicit `Pose<From> → Pose<To>` overloads at transform call
   sites) is the v1.0 hardening path; FRAME-002 / FRAME-003 will fire
   from those sites once `Transform<From, To>` parses + type-checks.
3. **URDF-aware static frame chains** (RFC-0003 §3.5, RFC-0013) and
   **typed dimensional units** (RFC-0047) are sister substrates with
   the same architectural pattern — phantom type parameter on a
   spatial / dimensional value — and benefit from the same
   `types_compatible` early-reject convention.
4. **Bootstrap seed refresh.** This slice changes the compiler IR;
   `bootstrap/nucleor_s1_seed.ll` is the Windows-emitted seed and was
   not refreshed by this branch. The seed must be regenerated from a
   Windows host and committed before the next OSS distribution rev
   (`bootstrap/README.md` documents the procedure).

## Whether main needs drift / self-host / perf / full verify

- **drift:** The four checks that gate compiler edits all pass on this
  branch (ABI parity, version label, manifests, audit_dup_fns_report).
- **self-host:** Stage-2 rebuild succeeds and the promoted binary
  re-rebuilds itself cleanly. Fixed-point check vs. the committed seed
  is OPEN until the Windows host refreshes
  `bootstrap/nucleor_s1_seed.ll`.
- **perf:** Not required for this slice (single early-reject branch on
  a cheap probe). Recommended if Phase B step-3 expands the firing
  surface.
- **full verify:** Not required for this slice. Recommended on main
  after seed refresh + Phase B step-3 land.
