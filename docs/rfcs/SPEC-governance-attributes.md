# SPEC — Governance Attributes (`@authored` / `@policy` / `@schema` + `nuc certify` / `nuc evidence`)

**Status:** PLACEHOLDER (pending governance workstream articulation by user)
**Date:** 2026-05-03
**Predecessor:** Nucleor V2 had a full governance pipeline; OSS parses-and-discards the attributes. The original "stay separate to NS_Sage" rationale is invalidated (NS_Sage is broken — see `feedback_ns_sage_broken.md`). Governance is being respec'd as its own workstream.

## Why this is a placeholder

The user has indicated that:
- NS_Sage is NOT the governance system and never was.
- Governance is a separate workstream the user is articulating.
- The V2 governance attributes (`@authored` / `@policy` / `@schema`) and CLI (`nuc certify` / `nuc evidence`) MAY be the right reinstatement target, but the shape needs to be decided based on the governance model, not auto-restored.

This spec exists as a tracking document. It will be filled in once the user articulates:
1. **What governance means** in the Nucleor context (audit trail? policy-as-code? formal verification? supply-chain attestation? all of the above?).
2. **What's enforced at compile time** vs **what's emitted as metadata** for downstream tools.
3. **Whether the V2 implementation is the right starting point** or if a fresh spec is warranted.

## V2 surface (for reference, may be discarded)

### Attributes (parsed-and-discarded in OSS today; line 238 of compiler)

```nucleor
@authored(by="Joe Wescott", tool="claude-opus-4.7", date="2026-05-03")
@policy(RequireAuthored | NoUnsafe | PureOnly)
@schema(version="1.2.0", changelog="...")
struct CriticalRecord { ... }
```

In V2:
- `@authored` recorded provenance metadata in IR.
- `@policy(NoUnsafe)` rejected `unsafe { ... }` blocks at compile time inside the annotated scope.
- `@policy(RequireAuthored)` rejected callers that didn't carry `@authored` themselves.
- `@policy(PureOnly)` rejected I/O / heap-alloc / mutation in the annotated scope.
- `@schema` emitted as metadata for downstream schema-evolution tools.

### CLI subcommands (absent in OSS)

- `nuc certify <project>` — verify all `@policy` constraints across the build, emit a certification report.
- `nuc evidence <project>` — collect provenance + attestation chain into a DSSE-signed bundle.
- `nuc audit <project>` — diff the current build against a previous certified build.

## Open questions for user articulation

1. **Scope.** Per-fn? Per-module? Per-build? Per-release?
2. **Enforcement model.** Hard error on policy violation (block the build) or soft warning (emit + continue)?
3. **Attestation chain.** Inline DSSE signatures on the binary? Separate sidecar files? Both?
4. **Audit trail granularity.** Every IR transform? Every fn? Every commit?
5. **Integration with existing `@hot` / `@const_fn` / `#[no_alloc]` family.** Is governance an orthogonal layer, or does it reuse the existing attribute machinery?
6. **Foundation-model provenance** (RFC-0051 `Model<...>`). Does that count as "governance" or is it a separate concern?

## Action

Hold this spec open. When the user has the governance shape, this becomes a real RFC. Until then: parse-and-discard remains the OSS state, `feedback_ns_sage_broken.md` is the canonical "do not blame NS_Sage" pointer.

## Closure criteria

(Pending articulation.)
