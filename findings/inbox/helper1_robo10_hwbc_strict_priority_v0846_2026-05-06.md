# helper1 ROBO-10 -- HWBC strict-priority evidence (v0846)

## Status

Phase 1 evidence complete on helper branch
`fix/helper1-qm6-mps-joint-prob-v0831`.

## What changed

- Added `tests/features/hwbc_strict_priority_smoke.nr`.
- Updated the robotics gap analysis, gap README, and v1 punchlist to mark the
  strict-priority portion of ROBO-10 as evidenced.

## Evidence

The fixture creates a 2-DOF hierarchical WBC:

- Task 0, highest priority: command `qdot0 = 1`.
- Task 1, lower priority and conflicting: command `qdot0 = 0`.
- Task 2, lower priority but independent: command `qdot1 = 2`.

Expected and validated:

- `qdot0` remains near `1.0`.
- Task 1 retains a large residual, proving it did not override Task 0.
- `qdot1` reaches `2.0`, proving usable lower-priority null-space motion.

## Remaining work

- Box-constrained strict-priority hierarchy.
- Torque-level / dynamics-coupled control for legged robots and torque-control
  arms.
