# Helper1 QM-7 Weight Enumerator Closure v0835

Branch: `fix/helper1-qm6-mps-joint-prob-v0831`
Base: `origin/fix/main-qm7-surface-code-v0827`
Scope: Queue 6 Scope U, QM-7 Clifford weight-enumerator feasibility and closure.

## Result

Implemented a bounded Clifford weight-enumerator surface for small-code release
evidence:

- `cliff_weight_enumerator_max_qubits()`
- `cliff_stabilizer_weight_count(h, weight)`
- `cliff_logical_weight_count(h, n_logical, weight)`

The runtime implementation reuses the existing stabilizer commutation,
stabilizer-group membership, and Pauli-weight machinery in
`stdlib/runtime/clifford_rt.c`. The enumeration is intentionally capped at
12 qubits so it cannot become a broad search path or accidental stress test.

## Fixture

Added:

- `tests/features/qm7_clifford_weight_enumerator_smoke.nr`

The fixture rebuilds the existing rotated Surface-17 d=3 stabilizer set and
checks exact internal exhaustive counts:

| Bucket | Expected counts |
|---|---|
| Stabilizer weights 0,2,4,6,8 | `1, 4, 22, 100, 129` |
| Stabilizer total | `256` |
| Nontrivial logical weights 3,5,7,9 | `24, 192, 408, 144` |
| Nontrivial logical total | `768` |
| Logical weights 0,1,2,4,6,8 | `0` |

These are internal exhaustive counts over the explicit in-tree generator set.
They are not presented as external published-value parity because the exact
published enumerator table/citation is not currently present in the repo.

## Docs Updated

- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- `stdlib/rods/clifford.nr::clifford_limitations`
- `tests/features/clifford_disclosure_smoke.nr`

QM-7 is now materially closed for deterministic small-code evidence. Remaining
QM-7 gaps are QASM/OpenQASM2 interop and optional external citation-backed
published enumerator parity.

## Validation

Direct focused build/run:

```powershell
.\bin\nucleor.exe build tests\features\qm7_clifford_weight_enumerator_smoke.nr -o target\_qm7_weight_enum --no-cache
.\target\_qm7_weight_enum.exe
```

Result: PASS.

Focused verify gates:

```bash
tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_weight_enumerator_smoke"
tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_surface_d3_smoke"
tools/verify.sh --sequential-fixtures --only "test features/clifford_disclosure_smoke"
```

Result for each: `PASS: 1`, `SKIP: 1152`.

Whitespace:

```powershell
git diff --check
```

Result: PASS.

## Residual Note

The compiler Tier-C informational diagnostic still says published
weight-enumerator validation remains open until the rod exposes enumerator
APIs. That text is now stale with respect to this helper branch. Updating it
requires a compiler diagnostic edit, which is outside this helper slice's
allowed stdlib/runtime/test/docs/report scope. Main should update that text
when integrating or in the next compiler-owned diagnostic wording pass.
