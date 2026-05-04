# RFC-0060 — `governance.nr` Rod (Optional Governance Surface)

**Status:** Draft (V1.15 — promoted from `SPEC-governance-attributes.md` placeholder)
**Date:** 2026-05-03
**Source:** `Desktop/Nucleor_Governance_Rod_Spec_2026-05-03.md` (v0.1, Joe-approved)
**Decision:** Governance ships as an **optional rod** (Shape B), not as language-level enforcement. Provenance/policy/evidence is a feature available to users who want it, not a tax on every Nucleor program.

## Summary

Replaces `SPEC-governance-attributes.md` (placeholder). Pulls the V2 governance attributes (`@authored` / `@policy` / `@schema` / `nuc certify` / `nuc evidence`) into OSS as a **rod**, NOT as compiler-level attributes. The s1 compiler stays as-is. The `requires [...]` / `restricts [...]` keywords pulled in v0.3.139/140 stay pulled.

## Locked design constraints

1. **Optional, not mandatory.** Programs that don't `import "stdlib/rods/governance.nr"` pay zero cost.
2. **No new compiler-level attribute enforcement.** Rod uses existing `source_rule_check` (GOV-001/GOV-002) machinery in `compiler/nucleor_tools_suite.nr`.
3. **NS_Sage is unrelated.** Zero connection to that broken project.
4. **Build on what's already shipped.** The CLI verbs `nuc audit` / `nuc evidence` / `nuc certify` / `nuc policy` already exist. Rod populates currently-`null` JSON fields and provides ergonomic wrappers.

## Surface (full detail in source spec)

- `AuthorRecord` / `PolicyDecl` / `SchemaDecl` / `EvidenceBundle` types
- `governance_register_authored()` / `governance_declare_policy()` / `governance_check_policies()` / `governance_assemble_evidence()` / `governance_sign_evidence()` / `governance_verify_evidence()` runtime fns
- `nuc gov authored / policy / check / evidence / sign / verify / status` CLI verbs (thin shim over existing surface)

## Implementation phases

1. **Phase 1 prerequisite — ✅ CLOSED 2026-05-03 (v0.7.14 + verified post-v0.7.16):** `tools/native_release.ps1` restored (1016 LOC, full ssh-ed25519 sign/verify pipeline). End-to-end validation: `nuc publish --sign` produces signed bundle (`Nucleor.publish.signature.json` with valid ssh-ed25519 signature, key_id `default-local`, mode `openssh-y-sign`), and `nuc release package-verify` accepts the roundtrip. Key store at `%USERPROFILE%/.nucleor/{release-signing-keys,trusted-release-keys}/`.
2. **Phase 2a — ✅ CLOSED 2026-05-03 (v0.7.18):** AuthorRecord registry surface. Files: `stdlib/rods/governance.nr` (~95 LOC), `stdlib/runtime/governance_rt.c` (~80 LOC), `tests/rods/governance_smoke.nr`, verify gate `v0.7.18 governance rod Phase 2a — AuthorRecord registry round-trip (RFC-0060)`. Provides AuthorRecord struct + register/count/get/clear + JSON serialization.
3. Phase 2b — `PolicyDecl` + `check_policies` wired to existing `source_rule_check` pass in `compiler/nucleor_tools_suite.nr` (extends GOV-001/GOV-002 substring checks with `NoExtern`, `NoSystem`, `PureOnly`, `NoIO`, `AuditedExternsOnly`).
4. Phase 2c — `SchemaDecl` + `EvidenceBundle` + sign/verify wrappers (uses Phase 1 `tools/native_release.ps1`).
6. Phase 3: wire-up to existing CLI verbs.
7. Phase 4: `nuc gov` CLI subcommand registration.
8. Phase 5: docs + RFC promotion.
9. Phase 6: signing hardening (Ed25519 evidence bundles — Phase 1 already provides ssh-ed25519 sign/verify; Phase 6 extends to evidence bundle envelope).

## Out of scope (explicit)

- Compile-time `@authored` value extraction in s1 (would violate no-attribute-enforcement constraint)
- Compile-time `@policy(...)` blocking of `nuc build` (would violate same)
- `Model<...>` provenance type (RFC-0051 — separate language feature)
- Cross-package `requires_authored` IR-level metadata threading

## Cross-references

- Source spec: `Desktop/Nucleor_Governance_Rod_Spec_2026-05-03.md`
- Replaces: `SPEC-governance-attributes.md` (placeholder)
- Sister RFC: `RFC-0051-model-provenance-type.md` (model-level provenance, separate)
- Sister broken-project memo: `feedback_ns_sage_broken.md` (NS_Sage is NOT this and never was)

## Acceptance criteria

Per source spec §5:
1. Imported rod populates `authored` arrays in `nuc evidence` output (no longer `null`).
2. `governance_declare_policy(NoUnsafe)` + `unsafe { ... }` produces `severity: "deny"` finding.
3. `nuc gov check <file>` exits non-zero on `deny`-severity findings.
4. `nuc gov sign <evidence.json>` produces a bundle that `nuc gov verify` accepts.
5. Programs not importing the rod produce identical output and binary as today (zero-cost).
6. s1 compiler binary size and self-build time unchanged.
7. `tools/verify.sh` and `tools/verify.ps1` gates pass.
