# Audit Fix Coordination — 2026-05-08

Master coordination doc for the parallel cloud lanes that close findings from `docs/audit/findings/audit_recon_pass1_*_2026-05-08.md`.

## Lanes

| Lane | Theme | Brief | Branch | Owner |
|---|---|---|---|---|
| L1 | Type flow + codegen u64 | [LANE_1_TYPE_FLOW_CODEGEN.md](LANE_1_TYPE_FLOW_CODEGEN.md) | `fix/audit-lane-1-type-flow-codegen-2026-05-08` | cloud (Linux) |
| L2 | Memory safety + handle encapsulation | [LANE_2_MEMORY_SAFETY_ENCAPSULATION.md](LANE_2_MEMORY_SAFETY_ENCAPSULATION.md) | `fix/audit-lane-2-memory-safety-2026-05-08` | cloud (Linux) |
| L3 | Verify harness + diagnostics | [LANE_3_VERIFY_HARNESS_DIAGNOSTICS.md](LANE_3_VERIFY_HARNESS_DIAGNOSTICS.md) | `fix/audit-lane-3-verify-harness-2026-05-08` | cloud (Linux) |
| L4 | Lexer/parser robustness | [LANE_4_LEXER_PARSER_ROBUSTNESS.md](LANE_4_LEXER_PARSER_ROBUSTNESS.md) | `fix/audit-lane-4-lexer-parser-2026-05-08` | cloud (Linux) |
| L5 | Stdlib correctness | [LANE_5_STDLIB_CORRECTNESS.md](LANE_5_STDLIB_CORRECTNESS.md) | `fix/audit-lane-5-stdlib-correctness-2026-05-08` | cloud (Linux) |
| L6 | Runtime ABI + RT + effects wiring | [LANE_6_RUNTIME_ABI_RT_EFFECTS.md](LANE_6_RUNTIME_ABI_RT_EFFECTS.md) | `fix/audit-lane-6-runtime-abi-rt-2026-05-08` | cloud (Linux) |
| L7 | Docs + user surface | [LANE_7_DOCS_USER_SURFACE.md](LANE_7_DOCS_USER_SURFACE.md) | `fix/audit-lane-7-docs-user-surface-2026-05-08` | cloud (Linux) |
| (local) | Windows platform parity | F-CONC-006, F-CONC-007 | `fix/audit-local-windows-parity-2026-05-08` | integrator (Windows) |

## Verify policy (all lanes)

- Run `bash tools/verify.sh` ONCE at end of batch.
- If FAIL=0 → push branch.
- If FAIL>0 due to legitimate cross-lane breakage (e.g., Lane 3 hardens negative-test runner, exposes other lanes' issues) → document and push with `[PARTIAL]` flag.
- If FAIL>0 due to this-lane regression → fix-forward up to 2 retries; if still failing, push with full report and flag for integrator review.
- **No verify after every micro-fix. Batch and ship.**

## Cross-lane coordination

- **Lane 2 ↔ Lane 6:** Effects framework gate logic (Lane 2) and runtime ABI manifest wiring (Lane 6) overlap. Lane 2 owns gate; Lane 6 owns manifest.
- **Lane 1 ↔ Lane 6:** `__nucleor_panic_div_u64` / `_rem_u64` runtime helpers needed by Lane 1 — Lane 6 may add the helpers; Lane 1 wires the codegen call sites.
- **Lane 3 ↔ Lane 7:** Lane 3 has the diagnostic-code inventory; Lane 7 uses it for `nuc explain` database entries.
- **Lane 5 ↔ Lane 6:** `direct_ffi` enforcement upgrade — Lane 6 owns; Lane 5 prepares Rust bridge externs with annotations.
- **Lane 4 ↔ Lane 1:** Type-position parser fix (Lane 4) interacts with type system (Lane 1). Coordinate diagnostic codes.

If a lane hits a cross-lane dependency mid-batch, the lane agent should:
1. Mark the dependent finding `[BLOCKED-ON-LANE-N]` in their report.
2. Apply only the local-scope portion of the fix.
3. Continue with other findings in their lane.
Do not synchronize between lanes mid-execution.

## Cherry-pick / merge order (integrator-side, post-completion)

Once all lanes complete, integrator (local Windows) cherry-picks in this order to minimize conflict resolution:

1. **L3 first** — verify harness + diagnostics. Establishes the gate that subsequent lanes' fixes get measured against.
2. **L7** — docs + CLI. Mostly disjoint from compiler fixes.
3. **L4** — lexer/parser. Foundation for everything below.
4. **L1** — type flow + codegen. Builds on L4.
5. **L2** — memory safety. Depends on L3 (harness) and L1 (type-flow for some checks).
6. **L6** — runtime ABI + RT. Depends on L1 (helpers), L2 (effects framework).
7. **L5** — stdlib correctness. Last because it depends on the rest of the toolchain being clean.
8. **(local)** — Windows platform parity. Integrator-resident; merged last.

After each cherry-pick: regen seed + bin if compiler changed; verify gate locally on Windows; commit if clean; proceed to next lane.

## Status (live — agents update on completion)

Updated by integrator as agents land:

- L1: pending
- L2: pending
- L3: pending
- L4: pending
- L5: pending
- L6: pending
- L7: pending
- (local): pending
