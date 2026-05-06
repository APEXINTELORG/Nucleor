# Cloud Claude Dispatch v0838: ROBO-7 Frame Typing

Audience: Cloud Claude / Opus agent.

Purpose: advance ROBO-7 frame typing without colliding with active Codex lanes.

Active parallel lanes:

- Cloud Codex: `fix/helper2-native-linux-pkg-r06-closure-v0837`
  - PKG-1 native Linux signed publish proof.
  - R06 native POSIX rust_bridge proof.
- Local helper1: `fix/helper1-rt-laws-closure-v0838`
  - RT determinism and algebraic laws.
- Local helper2: `fix/helper2-rfc0063-tools-suite-wave1-v0838`
  - RFC-0063 parser/tools-suite Wave 1.

Do not work those lanes from this branch.

## Start

Use a fresh branch from current `origin/main`:

```bash
git fetch origin --prune
git checkout -B fix/cloud-claude-robo7-frame-typing-v0838 origin/main
git status --short --branch
git merge-base HEAD origin/main
```

Expected assignment-time base:

```text
origin/main: 9448f335178cb7ecac9b3b7700e132c9c80507e8
```

If `origin/main` has advanced, use current `origin/main` and record the actual
base in the report.

## Read First

```text
docs/rfcs/RFC-0003-typed-frames.md
docs/rfcs/RFC-0013-urdf-static-frames.md
docs/rfcs/RFC-0046-coordinate-frame-types.md
docs/rfcs/RFC-0047-typed-units-7vector.md
docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md
docs/rfcs/v1_PUNCHLIST.md
docs/rfcs/v1_REMAINING_PUNCHLIST_CLOUD_DISPATCH_v0834_2026-05-06.md
```

Relevant current status:

- ROBO-7 is still open.
- Current robotics rods have many Phase 1 runtime surfaces, but compiler-level
  frame consistency is not closed.
- Unit archive guard is fail-closed, not a real typed-frame implementation.

## Mission

Ship the smallest coherent ROBO-7 progress slice that moves from advisory
frame comments toward compiler-visible frame typing.

Prefer a real, focused implementation plus fixtures. If the compiler/type
representation is too large for one safe branch, produce a design-to-code
blocker report with exact source anchors and a Phase 1 implementation plan.

## Allowed Write Scope

Preferred:

```text
compiler/nucleor_s1_compiler.nr
tests/features/robo7_*.nr
tests/err/err_robo7_*.nr
docs/rfcs/Nucleor_Error_Codes.md
docs/rfcs/v1_PUNCHLIST.md
findings/inbox/cloud_claude_robo7_frame_typing_v0838_2026-05-06.md
```

Only if needed for fixture ergonomics:

```text
stdlib/rods/kinematics.nr
stdlib/rods/fk_chain.nr
stdlib/rods/trajectory.nr
stdlib/rods/urdf.nr
```

Do not touch:

```text
compiler/nucleor_tools_suite.nr
tools/check_compiler_drift.sh
tools/verify.sh
tools/verify.ps1
bin/
bootstrap/
PKG-1/R06 Linux proof files
RT/law fixtures owned by helper1
```

If a change to `compiler/nucleor_tools_suite.nr` appears necessary, stop and
write a blocker. Parser/tools-suite unification is helper2's lane.

## Scope A: design-to-code survey

Answer these from source, not from roadmap text alone:

- What type metadata structure currently represents named types, structs,
  aliases, generics, and units?
- Where would frame tags naturally attach with the least cold-compile cost?
- Which robotics APIs currently pass frame-sensitive values without compiler
  checking?
- What positive and negative fixtures can be expressed today?
- What diagnostic code should be used for frame mismatch?

Write the survey into the report before implementing.

## Scope B: minimal compiler-visible frame tag

Implement only if it is small and locally testable.

Acceptable Phase 1 shapes:

- parse and preserve a lightweight frame marker annotation on type aliases or
  structs;
- enforce mismatch for a deliberately small operation surface, such as assigning
  or combining two frame-tagged pose/vector values with different tags;
- emit a clear diagnostic for a frame mismatch while preserving existing
  untagged robotics code.

Non-goals:

- full dependent types;
- full unit algebra;
- URDF-wide static frame graph inference;
- runtime-heavy frame registries;
- broad stdlib rewrites.

The branch must not add noticeable cold compile or memory overhead. Avoid a
global scan when a local type-check hook is sufficient.

## Scope C: fixtures

Add focused fixtures:

```text
tests/features/robo7_frame_positive_smoke.nr
tests/err/err_robo7_frame_mismatch.nr
```

If the exact filenames already exist, extend them instead of creating
duplicates.

Positive fixture should prove a same-frame operation compiles. Negative fixture
should prove a cross-frame operation fails with the selected diagnostic.

## Scope D: report and status

Create:

```text
findings/inbox/cloud_claude_robo7_frame_typing_v0838_2026-05-06.md
```

Include:

```text
Branch:
HEAD:
Base:
Merge-base:
Survey findings:
Implemented surface:
Positive fixture:
Negative fixture:
Diagnostics:
Files changed:
Validation:
Remaining blockers:
Whether main needs drift/self-host/perf/full verify:
```

Update `docs/rfcs/v1_PUNCHLIST.md` only for proven behavior.

## Validation

Always run:

```bash
git diff --check
```

If compiler source changes:

```bash
bash tools/check_compiler_drift.sh
```

Run focused fixture commands and record exact output. If the verify script has
a named ROBO/frame step, use it; otherwise use direct `bin/nucleor` compile
commands.

Run perf if type-check traversal changes materially:

```powershell
pwsh -NoProfile -File tools/check_perf_regression.ps1
```

Do not run full verify by default.

## Deliverable

Push:

```text
fix/cloud-claude-robo7-frame-typing-v0838
```

If implementation blocks, push the same branch with the report only and exact
blocker details. Do not overclaim ROBO-7 closure.
