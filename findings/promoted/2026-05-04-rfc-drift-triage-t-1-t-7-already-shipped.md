---
title: RFC drift triage — T-1 (width-tagged ops) and T-7 (derive(PartialEq) wiring) gap-RFC text describes pre-fix state; both already largely shipped on v0.4.180
severity: wrong-error
probe_file: probes/types/t_1_width_tag_violation.nr, probes/types/t_1_width_compare_and_struct.nr, probes/types/t_7_derive_partialeq_wiring.nr, probes/types/t_7_no_derive_partialeq.nr
diagnostic_actual: T-1 widths preserve correctly under non-strict mode; T-7 #[derive(PartialEq)] correctly wires `==`; non-derive structs fire TYP-011 with helpful explainer
diagnostic_expected: per RFC, T-1 and T-7 are CRITICAL/HIGH gaps with concrete failing examples
discovered_against: v0.4.180
commit: 03fa84fe
status: NEW (drift-triage; main agent should consider re-grading these in v1_PUNCHLIST)
---

## Summary

Two of the type-system gap RFC's CRITICAL/HIGH items reproduce **incorrectly** when probed against current source:

- **T-1 — IR width-tagged ops** (RFC: CRITICAL). Concrete RFC example `let a: u8 = 200; let b: u8 = 200; let c: u8 = a + b;` — RFC predicts `c` holds 400 silently. v0.4.180 actually produces `c == 144` (correct u8 wrap) under `NUCLEOR_INT_STRICT_INTRIN=0`, OR PANICs under default strict mode. Width preservation also confirmed across function returns, struct fields, comparisons, and Vec elements. Either path matches RFC-0015; neither matches RFC T-1's silent-miscompute description.

- **T-7 — `#[derive(PartialEq)]` does not wire `==`** (RFC: HIGH). v0.4.180 with `#[derive(PartialEq)] struct Point { x: i64, y: i64 }` correctly evaluates `Point{1,2} == Point{1,2}` → true and `Point{1,2} == Point{1,3}` → false. Without `#[derive(PartialEq)]`, the compiler fires `TYP-011` with a clear explainer pointing at field-wise comparison or the derive macro. Both modes match the RFC's *desired* end-state, not its *current-state* description.

The TYP-011 explainer text itself documents the closure: "v0.6.84+ which auto-generates the field-walk helper AND v0.6.85 routes `==`/`!=` directly to it." This means T-7 was closed before v0.6.85 — which is months/many-versions before the gap RFC's 2026-05-04 draft date.

## Repro evidence

### T-1 (width preservation works under non-strict)

```
$ NUCLEOR_INT_STRICT_INTRIN=0 ./target/t_1_width_tag_violation.exe
u8 200 + 200 stored in u8 c:
144                                  <- correct u8 wrap (400 mod 256)
u16 50000 + 50000 stored in u16 z:
34464                                <- correct u16 wrap
i8 100 + 100 stored in i8 k:
-56                                  <- correct i8 wrap (200 mod 256 - 256)
rc=0
```

```
$ NUCLEOR_INT_STRICT_INTRIN=0 ./target/t_1_width_compare_and_struct.exe
add_u8(200, 200) = 144               <- function return narrows
Pair.x + Pair.y = 144                <- struct field narrows
OK: u8 0 != i64 256                  <- comparison honors widths
v[0] + v[1] = 144                    <- Vec<u8> element narrows
rc=0
```

### T-7 (derive wires `==`)

```
$ ./target/t_7_derive_partialeq_wiring.exe
a == b (correct semantics)           <- structurally equal -> true
a != c (correct)                     <- structurally unequal -> false
rc=0
```

```
$ bin/nucleor.exe build probes/types/t_7_no_derive_partialeq.nr
error[TYP-011]: `Point == Point` does pointer comparison. ... Compare
  fields explicitly ... OR add `#[derive(PartialEq)]` (v0.6.84+)
  which auto-generates the field-walk helper AND v0.6.85 routes
  `==`/`!=` directly to it.
```

## Suggested action

Per the v1_PUNCHLIST sequencing under "Wave 1 critical silent-miscompute findings" — T-1 and T-7 are listed as launch-blockers (T-1 specifically as part of `T-3, T-4` cluster).

- **T-1**: re-grade from CRITICAL to **DONE / RFC-stale**. The RFC's failing example does not reproduce. Residual concerns from the RFC (per-fn `#[strict_arith]` annotation; v0.4.199's reverted 1.4× regression) are real Phase 4 polish but not silent-miscompute risks today.
- **T-7**: re-grade from HIGH to **DONE / RFC-stale**. The auto-derive wiring shipped at v0.6.84 / v0.6.85 (per the TYP-011 explainer's own documentation). The RFC's other derive entries (`Eq`, `Hash`, `Default`, `Copy`, `Clone`) may still be silently dropped via DERIVE-001 — those should be probed separately if main agent wants to confirm.

## Why this matters for main agent

The 14 gap RFCs were drafted on 2026-05-04 (same day as this probe) but their gap descriptions appear to be a snapshot of an *earlier* compiler state. T-1 and T-7 are not the only items that may be RFC-stale; a sweep across all 14 RFCs to verify each "current symptom" against current binary would close the credibility gap and reduce wasted Wave 1 ship cycles.

If main agent is shipping audit-pass info diagnostics for already-closed gaps (analogous to the v0.8.44 NUM-G1 false-positive issue I reported separately), the Wave 1 `Phase 1 ship → Phase 2 ship` cadence is paying for cleanup that doesn't move the silent-miscompute needle.

## Cross-ref

- v1_PUNCHLIST §"CRITICAL silent-miscompute / launch-blocker (Tier-A)" — T-1 isn't directly listed but flows through "T-3, T-4 — Type system silent fallthrough" framing. T-7 is also conspicuously absent from the punchlist's CRITICAL section despite the RFC HIGH grade.
- Companion NUM-G1 finding: same RFC-drift pattern (audit-pass info text describes pre-fix state; current source already has the >6-digit strtod escape).
- RFC `docs/rfcs/gap-analyses/Nucleor_Type_System_Gap_Analysis_and_RFC_2026-05-04.md` §T-1, §T-7

## Notes for main agent

Recommend a quick sweep: probe agent files a drift-triage entry per RFC item that doesn't reproduce on v0.4.180. Main agent then reconciles v1_PUNCHLIST severity grades. Net effect is more accurate sequencing — Wave 1 ships target items that *actually* miscompute, not items whose RFC drafts are stale.

A focused candidate set for the next probe tick:
- T-2 (lifetimes — almost certainly still live; parser-only)
- T-5 (generic monomorphization — I expect still live but worth probing)
- T-13 (associated types — RFC says halts; quick syntax probe)
- T-14 (`dyn Trait` — RFC says deferred; quick syntax probe)
- T-16 (closure types not inferred — partially probed via T-4; full probe outstanding)
- T-17 (`#[repr(C)]` propagation — easy probe)
