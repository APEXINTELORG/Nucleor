# Helper1 QM-7 Property Micro-Suite v0836

Branch: `fix/helper1-qm6-mps-joint-prob-v0831`
Base: `origin/fix/main-qm7-surface-code-v0827`
Scope: Queue 6 Scope V, QM-7 bounded Clifford property micro-suite.

## Result

Added a deterministic, bounded Clifford property micro-suite:

- `tests/features/qm7_clifford_property_micro_suite.nr`

The fixture covers:

- clone/reset isolation after Bell-state construction;
- a small H^2 / X^2 / CNOT^2 identity sequence;
- repeatable [[5,1,3]] perfect-code rebuilds;
- stable code distance `3`;
- `15/15` single-qubit detectable-error count;
- single-error detectability;
- non-detectability of logical `XXXXX` and `ZZZZZ`;
- five-qubit stabilizer/logical weight-count consistency using the bounded
  enumerator helpers.

## Docs Updated

- `stdlib/rods/clifford.nr::clifford_limitations`
- `tests/features/clifford_disclosure_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

QM-7 now has deterministic evidence for Bell/GHZ, gate identities,
reset/rebuild, [[5,1,3]] distance, Surface-17 d=3 behavior, bounded
weight-enumerator behavior, and a bounded property micro-suite.

Remaining QM-7 gaps:

- QASM/OpenQASM2 interop.
- Optional external citation-backed published weight-enumerator parity if
  launch docs require a row against a published table.
- Broad randomized stabilizer property testing remains intentionally out of
  scope for this helper slice.

## Validation

Direct focused build/run:

```powershell
.\bin\nucleor.exe build tests\features\qm7_clifford_property_micro_suite.nr -o target\_qm7_property --no-cache
.\target\_qm7_property.exe
```

Result: PASS.

Focused verify gates:

```bash
tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_property_micro_suite"
tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_weight_enumerator_smoke"
tools/verify.sh --sequential-fixtures --only "test features/clifford_disclosure_smoke"
```

Result for each: `PASS: 1`, `SKIP: 1153`.

Whitespace:

```powershell
git diff --check
```

Result: PASS.

## Residual Note

The compiler Tier-C informational diagnostic printed during direct builds still
contains stale text saying published weight-enumerator validation remains open
until enumerator APIs exist. That is now stale because the bounded APIs exist on
this branch. Updating that text is a compiler diagnostic wording edit and should
be handled by main during integration or a compiler-owned diagnostic pass.
