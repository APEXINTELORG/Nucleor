# Nucleor v1.x Hardening Strategy

**Date:** 2026-05-08
**Status:** Strategy doc; lives on archive `main`. Items get promoted to public Nucleor only as concrete deliverables ship.
**Scope:** Six work streams discussed 2026-05-08 — residuals, independent audit, preemptive fixes, certification, provenance/anti-theft, legal posture (ITAR/EAR + disclaimers + licensing + trademark).

This doc synthesizes the research from four parallel deep-dives and wires the streams into one phased plan with cross-dependencies surfaced. The recommendation throughout is **measured, evidence-based, and aligned with what comparable mature OSS projects (Drake, ROS, Ferrocene, Rust, LLVM) actually do** — not aspirational over-engineering.

**This is not legal advice.** Several items below specifically need an attorney; those are flagged.

---

## 0. Executive Summary

**Top recommendation: stay Apache-2.0. Add trademark, attribution rigor, provenance manifest, contributor agreement, and a Ferrocene-style certified-build commercial tier.** This is the path most mature compiler projects converge on, and it scores highest on all four of your stated priorities (attribution, monetization optionality, brand control, embeddability).

**Cross-cutting insight:** the provenance manifest (Topic 5) is *also* the legal attribution channel under Apache-2.0 §4(d) (Topic 6). Building it once buys you both. Likewise, the work to close residuals (Topic 1) is the same work that prepares the codebase for an external audit (Topic 2/3) and for OpenSSF Badge / SLSA / OSTIF (Topic 4).

**What NOT to do (saves significant effort):**
- Do not relicense to GPL/BUSL/SSPL/ELv2/Commons Clause — every recent move in this direction (Redis→Valkey, Terraform→OpenTofu, Elasticsearch→OpenSearch) has triggered a damaging fork. Wrong threat model for a compiler.
- Do not pursue ISO 27001, FIPS 140-3, Common Criteria, CIS Benchmarks, or DO-178C qualification on upstream Nucleor at v1.x. All are wrong-shaped or only justified by a paying customer.
- Do not add click-through gates on individual rods or "no military use" clauses — both poison adoption without changing actual misuse.
- Do not over-engineer EU CRA compliance now — obligations don't bind until late 2027 and the OSS carve-out is still being clarified.

**Phased plan summary (full plan in §7):**

| Phase | Window | Theme |
|---|---|---|
| **Phase 0** | This week | Residuals close-out, attribution audit, cheap legal/safety notices, OpenSSF Badge passing, Sigstore on releases |
| **Phase 1** | Next ~30 days | Provenance manifest v1, trademark filing, CLA setup, SLSA L2, NOTICE+License rigor, advisory DB scaffold |
| **Phase 2** | ~30-90 days | Independent audit protocol + preemptive findings sweep, signed manifests, SLSA L3, OpenSSF silver, NIST SSDF self-attestation |
| **Phase 3** | ~3-12 months | OSTIF/Alpha-Omega audit application, reproducible builds tracker listing, OpenSSF gold, Ferrocene-style certified-build tier scaffolding |

---

## 1. Residuals Close-Out

The v1.0 CHANGELOG documents five residuals carried into v1.x maintenance. Closing them is the prerequisite for any external audit being meaningful.

### Inventory

1. **`tools_suite` SIG_MATCH_BODY_DIFFERS (69) + SIG_DIFFERS (16) duplicates** — large-body fns and adapter-required call-site updates from RFC-0063. Per-fn review work.
2. **6 drift-protected fns intentionally LOCAL in `tools_suite`** (`get_rt_name`, `is_ptr_ret`, `is_ptr_arg`, `emit_externs`, `emit_user_externs`, `compiler_version_label`) — closing requires teaching `tools/check_compiler_drift.sh` to follow imports rather than direct grep.
3. **s1 local-copy elimination** — bootstrap-affecting; deferred per Phase B scope at v1.0 cut.
4. **macOS native bootstrap** — pending hardware availability for the CI gate.
5. **Per-rod `#[effect(...)]` retrofit** — 216 `.nr` files / 1786 extern decls in `stdlib/`. Adopter-incremental opt-in; framework already gated behind file-level opt-in.

### Close-out approach

These are Phase 1-2 work. Each gets cherry-picked to local `main` from archive feature branches as it lands clean, then batched into release commits per `docs/MAINTAINER_RELEASE_WORKFLOW.md`.

- **Items 1-2** (compiler/tool dups + drift script): pure compiler/tooling work. Sequence: drift script teaches imports first (item 2), then bulk SIG_MATCH closure (item 1) becomes feasible. Estimate: substantial; suitable for cloud-agent batched cycles.
- **Item 3** (s1 local-copy): bootstrap-affecting. Needs careful staging and re-verify with full T1.7/T1.8 fixed-point gate.
- **Item 4** (macOS): blocked on hardware. Add `Darwin/aarch64` and `Darwin/x86_64` as CI matrix entries; flag as "blocked on infra" in roadmap.
- **Item 5** (rod effect retrofit): adopter-incremental. Convert 5-10 rods per release as exemplars; ship a `nuc fix --add-effects` migration aid. Don't try to bulk-convert all 1786 — that defeats the opt-in design.

### Promotion triggers

A residual is "closed" when:
- The fix is on archive `main`
- Verify gate passes locally and on cloud
- A v1.x.y release commit batches it (per maintainer workflow)
- CHANGELOG residuals section drops the line

### Open question for you

Do you want to attack residuals in priority order I just listed, or batch them differently? My recommendation: **items 1-2 first** (highest reduction in audit findings later), then **item 5** (incremental rod retrofit improves credibility), then **item 3** (bootstrap touch), then **item 4** (blocked anyway).

---

## 2 + 3. Independent Audit + Validation Protocol with Preemptive Findings Closure

You asked for these as separate topics, but they're a single workflow: write the audit protocol, run it ourselves first, fix what it finds, then publish/run it for real. This gives you the credibility of an external-style audit *without* surprises.

### Why this works

External auditors (Trail of Bits, NCC Group, OSTIF-funded) charge $100-500K and 4-12 weeks. If they find things you could have found yourself, you wasted half the audit budget. The mature pattern is: **run your own version of the audit first**, fix everything you can, then bring in the external party for the parts you can't grade yourself (memory-safety formal verification, novel attack surface, supply-chain compromise simulation).

### Audit protocol — internal version

A reproducible, scriptable audit protocol that anyone (us, then later an outside party) can run against Nucleor. Living spec at `docs/NUCLEOR_AUDIT_PROTOCOL.md`. Sections:

1. **Build integrity**
   - Self-host fixed-point validation (T1.7 / T1.8 — already exists)
   - Bootstrap seed reproducibility from declared sources
   - Bin reproducibility on identical toolchain (target SLSA L3 prerequisite)
   - Source manifest verification (Phase 1 provenance)

2. **Memory safety / borrow checker**
   - All G-1..G-11 hard-error gates exercise tests pass (already in verify)
   - Negative test corpus per gate (each diagnostic code has at least 3 negative tests)
   - Fuzz a subset of the type checker / borrow checker on randomly mutated `.nr` inputs (introduces fuzzing target, OSS-Fuzz integration candidate)

3. **Effect system**
   - Every `#[effect(...)]` annotation in stdlib has documentation
   - Cross-module effect propagation tests (already partial in cloud cycles)
   - Adopter migration story for rods without effects yet (item 5 from §1)

4. **FFI surface**
   - Every `direct_ffi` call site has `#[allow_effect(direct_ffi)]` attestation
   - `rust_bridge` round-trip ABI tests (already covered)
   - C runtime helper inventory (`__nucleor_*` ABI symbols) matches manifest
   - All 875 ABI symbols mapped to a justification

5. **Determinism / reproducibility**
   - Same source + same toolchain = same output (compiler is deterministic)
   - Build timestamps, file ordering, locale, and address-dependent symbol ordering audited
   - `SOURCE_DATE_EPOCH` honored

6. **Numeric correctness**
   - `tests/numeric/` parity tests against C/Python references
   - ML PROBE-2 4-pipeline parity gate (already in verify)
   - Quantum simulation cross-checks against literature (already partial)

7. **Documentation correctness**
   - Every diagnostic code has at least one example in docs
   - Every public API has a doc comment
   - README install instructions actually work on a clean VM (manual gate, not scriptable)
   - No dead links, no stale version references (drift gates already cover some)

8. **Supply chain**
   - All third-party deps pinned with hashes (LLVM, Rust crates in rust_bridge)
   - SBOM published per release (CycloneDX 1.6)
   - Provenance manifest on every release artifact (Phase 1 provenance)
   - Sigstore signature on every release (Phase 0)

9. **Security disclosure**
   - SECURITY.md with PGP key and disclosure address
   - Triage SLA documented
   - Hall-of-fame credit policy
   - 90-day advisory cadence

10. **Stability / API surface**
    - Public-API enumeration (every `pub fn`, `pub struct`, `pub trait` in stdlib)
    - Diff between v1.0 and v1.x.y catches breaking changes
    - Deprecation policy

### Preemptive findings sweep

Before any external party sees the audit protocol, we run it ourselves:

- **Step 1:** Write the protocol as a runnable script (`tools/nuc_audit.sh` or similar — extends `verify.sh` with audit-only checks)
- **Step 2:** Run it. Every finding goes into `docs/audit/findings/internal_<date>.md`
- **Step 3:** Triage findings into: (a) fix immediately, (b) accept-with-justification (documented), (c) deferred to specific release
- **Step 4:** Close (a) items in batched release cycles
- **Step 5:** Re-run audit to confirm clean
- **Step 6:** *Then* apply to OSTIF / Alpha-Omega for funded external audit, with the protocol and our own findings doc as the starting context

This is a real differentiator. Most OSS projects bring in auditors blind. Showing up with a documented internal audit dramatically improves the auditor's signal-to-noise and reduces the dollar cost.

### Open questions for you

- Do you want me to draft `NUCLEOR_AUDIT_PROTOCOL.md` v0.1 as a near-term action? It'd be ~500-800 lines but mostly assembling existing knowledge.
- For finding-handling: are accept-with-justification entries OK with you, or do you want all-or-nothing fix posture? (Recommend allow accept-with-justification — some findings are intentional design choices that an auditor would re-flag forever.)

---

## 4. Codebase Certification Strategy

The certification landscape is rich but most options are wrong-shaped for an OSS compiler. The following are the **right-shaped** options, sequenced by impact-per-effort:

### Phase 0 (this week)
- **OpenSSF Best Practices Badge — passing.** Self-attestation of ~66 criteria. Free. We already meet most of them. 1-3 days of checklist work.
- **OpenSSF Scorecard ≥ 7.** Automated. Enable Dependabot, branch protection on `main` (public), pin Action SHAs, signed tags. ~1 weekend.
- **Sigstore/cosign on releases.** Keyless signing via GitHub OIDC. ~half-day on a release workflow. Verifies via Rekor public log; no key management.
- **CycloneDX SBOM** generated per release. Aligns with federal SBOM requirements. ~half-day.
- **SECURITY.md** with disclosure address + PGP key. ~1 hour.

### Phase 1 (~30 days)
- **SLSA L2 provenance** via `slsa-framework/slsa-github-generator`. ~1 day.
- **`nucleor-advisory-db`** repo in RustSec format + `nuc audit` subcommand. Lightweight, decentralized, authoritative model — and it's free differentiator since few language ecosystems have it organized this way at v1.0.

### Phase 2 (~30-90 days)
- **SLSA L3** (hardened, non-forgeable provenance via the SLSA generator's L3 mode).
- **OpenSSF Badge — silver.** Requires signed releases, threat-model doc, two-person review on critical changes (loosely interpretable for a small project — pair-review via cloud-agent + integrator pattern arguably qualifies).
- **NIST SSDF self-attestation** (CISA Form 1 format). Even if not selling to feds, the document forces good hygiene and is required for any future fed integrator.

### Phase 3 (~3-12 months)
- **Reproducible builds** — fix the determinism gaps, then apply to the reproducible-builds.org tracker. High differentiator for a compiler.
- **OpenSSF Badge — gold.** Requires reproducibility + governance maturity.
- **Apply to OSTIF and OpenSSF Alpha-Omega** for funded third-party audit. Selection slow; apply early. Budget alternative: $100-300K direct engagement with Trail of Bits / Cure53 / Atredis / Quarkslab if business case justifies.
- **CNA status** — only if and when there's a sustained track record of well-handled advisories (recommend defer to year 2).

### Explicitly skip at v1.x
- ISO 27001 / 9001 (org-level, wrong shape for a small OSS compiler)
- FIPS 140-3 / Common Criteria (only if a paying federal customer demands a specific crypto rod)
- CIS Benchmarks (not applicable to compilers)
- DO-178C / ISO 26262 / IEC 61508 tool qualification on upstream — **Ferrocene model**: maintain a *separately qualified branch* if a customer pays, not on upstream

### Why this sequencing

The Phase 0 items are pure-credibility wins for trivial effort — every comparable language project has these. The Phase 1-2 items move you from "self-attested" to "transparency-log-attested," which is the credibility ceiling self-attestation reaches. Phase 3 is the third-party-attested bar that takes Nucleor from "well-engineered" to "audited." The sequence avoids paying for certifications you can't yet support (CNA without a security team, gold without reproducibility).

---

## 5. Provenance / Anti-Theft Strategy

Goal: not DRM. Establish "this binary came from this Nucleor installation, compiled from these sources" as a verifiable fact, with enough structural deterrent that casual rebrand/strip is unprofitable.

### What survives a determined attacker

Nothing. A determined fork will strip everything in a weekend. The realistic goal is:

1. Honest users can prove provenance (signed manifests, Sigstore log)
2. Casual attribution-stripping is unprofitable (rebuild compiler + runtime + stdlib + lose CFG birthmarks)
3. Forks are forced to declare themselves (because the cost of full re-fingerprinting is high enough that they leave traces)
4. **Attribution-stripped binaries violate Apache-2.0 §4(d)** — the manifest becomes a legal hook, not just a technical fingerprint

### Phase 1 (ship in next ~30 days) — Manifest-based provenance

**1-2 days of compiler work.** Adds a `.nucleor` PE/ELF section to every output:

```json
{
  "schema": "nucleor.provenance/v1",
  "nucleor_version": "1.0.0",
  "compiler_sha256": "<hash of the producing nucleor.exe>",
  "build_timestamp_utc": "2026-05-08T14:32:01Z",
  "source_files": [{"path": "src/main.nr", "sha256": "..."}],
  "rod_dependencies": [{"name": "std", "version": "1.0.0", "sha256": "..."}]
}
```

Plus `nuc verify-binary <path>` subcommand to dump and verify.

Plus `SHA256SUMS` published with every release.

**Deterrent value:** establishes provenance for honest users; casual rebrand will leave the section in place. Strippable but visible removal effort.

### Phase 2 (~30-90 days) — Signed manifests + release signing

**1-2 weeks of work.** Adds:

1. **Release ed25519 keypair**, public key embedded in compiler source (`const RELEASE_PUBKEY: [u8; 32] = [...]`)
2. **Per-installation key** generated on first run (`~/.nucleor/install_key`) — public key signed by the release key the first time the installation is online (or self-attested for offline installs)
3. **Manifest signed** with per-installation key; signature verified offline against the embedded release pubkey
4. **Sigstore Cosign bundle** on the release tarball (no key management — uses GitHub OIDC)
5. **Authenticode signing** of `nucleor.exe` itself if budget allows (Sectigo/DigiCert OV cert ~$200-500/yr)

**Deterrent value:** moves from "metadata" to "tamper-evident metadata." A fork has to either (a) remove the manifest entirely (detectable by a runtime ABI mismatch check we can add to stdlib), or (b) re-sign with their own key (in which case verification fails and the fork has declared itself).

### Phase 3 (~3-6 months) — SLSA L3+ + reproducible builds

**3-6 weeks.** Adds:
- Make the Nucleor build fully reproducible (fix `SOURCE_DATE_EPOCH`, file ordering, locale, `--build-id` flags, etc.)
- `slsa-github-generator` produces in-toto attestations on every release, published to Rekor
- End-to-end verification chain documented: source commit → reproducible build → SLSA attestation → release artifact → output binary manifest

This is the credibility ceiling for compiler provenance. Matches Sigstore-itself, Tekton, Kubernetes.

### Watermarks / birthmarks (already in place — costs nothing)

The `nuc_*` and `__nucleor_*` symbol prefixes throughout the runtime ABI are emergent birthmarks: any binary using Nucleor's runtime carries them after `strip` (because they're needed for relocations and runtime lookups). Renaming requires modifying both compiler and runtime in lockstep — non-trivial.

This is "free deterrent" — already there; document the design intent in the manifest spec so it's clear it's not accidental.

### Bootstrap chain (chicken-and-egg)

The first signed `nucleor.exe` must come from somewhere. Resolution:
1. Generate the release keypair offline, one-time
2. Sign the v1.0 release with it (hand-roll for v1.0; CI for subsequent)
3. Publish the public key with strong distribution (release notes, well-known URL on `nucleor.org`, DNSSEC TXT, Rekor entry of the pubkey)
4. v1.x onward: each release signed by previous, building a chain of signed manifests
5. Optionally: m-of-n maintainer signing (cosign multi-sig) once there's a maintainer team

### Anti-theft realism

You said "I don't want it to be weird about this." Every measure above is a standard technique used by compiler/runtime projects (Go, Rust, Apple, MS, Sigstore, SLSA). None is unusual or paranoid. Together they put Nucleor at parity with the most-respected OSS toolchains.

### Open questions for you

- Sigstore-only vs Sigstore+Authenticode? Authenticode = ~$300/yr + better Windows UX. Sigstore = free + technically equivalent provenance. **Recommend: Sigstore now, Authenticode if user-experience complaints come in.**
- Should the per-installation key auto-enroll online by default (sends pubkey to a registry) or stay fully offline by default (self-attested)? **Recommend: offline-by-default with optional `nuc enroll` for users who want a public-registry entry (research citation, enterprise audit).**

---

## 6. Legal Posture: Export Control, Disclaimers, Licensing, Trademark

### 6a. ITAR / EAR (export control)

**Current posture is correct but undocumented.** Robotics/quantum/CUDA primitives in Nucleor are general-purpose math, not "specially designed for a defense article." This means:

- **ITAR (22 CFR 120-130):** does not apply. General-purpose IK/SE(3)/URDF parsing is not on the USML. The §120.34 "public domain" question doesn't even arise because ITAR jurisdiction never attaches.
- **EAR (15 CFR 730-774):** §734.7 "publicly available" exclusion applies. By publishing on GitHub without access controls, the published source is **not subject to the EAR**. Best self-classification is **EAR99 / NLR** for what's redistributed, with the standard caveats (no encryption EI, no specific knowledge of bad-actor end use, OFAC sanctions overlay separate).

**Action items (Phase 0):**

1. **Add an "Export & Trade Compliance" section to README** with the §734.7 publication posture and EAR99/NLR good-faith classification. Boilerplate paragraph — Linux Foundation has well-tested wording.
2. **Audit module-level documentation for inadvertently defense-flavored language.** Strip phrases like "weapons-grade," "targeting," "strike," "munitions," "fire control" from doc comments and READMEs. Cheap, real reduction in scrutiny risk.
3. **Add NOTICE file paragraph** referencing publication-route status — travels with derivative works.

**2024-2025 watch items:**
- **AI Diffusion Rule (Jan 2025)** added new ECCNs for AI model weights above ~10²⁶ training-compute threshold. Generic CUDA helpers don't trigger it but the rule is unsettled — keep a one-page memo for counsel.
- **Quantum hardware/software (ECCN 4D906/4E906 emerged late 2024)** — generic state-vector simulation isn't covered, but the area is moving. One-page counsel memo recommended.
- **EU Cyber Resilience Act (effective Dec 2027)** — open-source steward carve-out exists but is narrower than initially hoped. Monitor; don't over-engineer.

**Where you genuinely need an attorney** (not this research):
- Whether any specific rod could be argued "specially designed" for a USML article — only DDTC can definitively resolve via Commodity Jurisdiction request
- Whether the quantum simulation surface brushes 4D906/4E906 — moving target
- Whether any contributor or downstream redistributor in a sanctioned region creates OFAC exposure
- EU PLD / AI Act exposure if Nucleor sees commercial EU deployment

### 6b. Liability disclaimers

Apache-2.0 §7-§8 already disclaim warranty and limit liability. Gaps that matter for robotics:

1. Statutory liability that cannot be disclaimed (gross negligence, certain consumer-protection regimes, **EU Product Liability Directive 2024/2853** which now expressly covers software)
2. Personal-injury / wrongful-death — many U.S. states limit disclaimer scope
3. Tort claims by **non-licensees** — bystander injured by a robot running Nucleor was never offered the license
4. Third-party patent claims (Apache §3 patent grant is narrow)

**Action items (Phase 0):**

1. **Add "Safety & Liability" section to README** with the standard "research and development purposes; not certified for safety-critical use (ISO 26262 / IEC 61508 / DO-178C / ISO 13849)" language. Mirror Drake/MoveIt/ROS phrasing — these projects have absorbed this exact issue and converged on this wording.
2. **Real-time scheduling disclaimer:** "Nucleor's RT primitives provide best-effort deadline enforcement on commodity OSes; they do not constitute hard real-time guarantees."
3. **No on-point case law** exists where an OSS author was successfully sued over downstream physical/financial harm. Risk is theoretical, but the disclaimers reduce the surface materially in litigation triage.
4. **Indemnification:** OSS authors generally cannot require it from users via the license. *Can* require it in a separate commercial side-license (Phase 3 commercial tier).

### 6c. Licensing — stay Apache-2.0

The research is unambiguous: **stay Apache-2.0**. Reasons (full case in the licensing research dispatch):

- **Every major language launched since ~2009 chose permissive** (Go BSD, Rust MIT/Apache, Swift Apache, Kotlin Apache, Zig MIT, Julia MIT, Crystal Apache). LLVM relicensed *toward* Apache to reduce friction.
- **Source-available is unstable for infrastructure projects** — every recent move (Redis→Valkey, Terraform→OpenTofu, Elastic→OpenSearch, HashiCorp→IBM acquisition with OpenTofu still gaining) triggered a damaging fork. The 2024-2025 reversals (Redis adding AGPL back, Elastic adding AGPL back) confirm the lesson.
- **GPL/LGPL** kills language adoption. The runtime-exception complexity is real engineering work for marginal benefit.
- **Dual-licensing only generates revenue when the OSS license has real obligations adopters want to escape.** Apache-2.0 has almost none, so a "pay to escape Apache" license sells nothing. Hence why no major compiler dual-licenses.

**Where revenue actually comes from** (all compatible with Apache-2.0):

1. **Certified releases (Ferrocene model)** — Apache-2.0 + paid certification + paid LTS. Best fit for Nucleor's robotics/embedded surface. Ferrocene shipped qualified Rust to Lockheed, NXP, others.
2. **Hosted service** — playground, cloud build farm. Independent of compiler license.
3. **Paid support** — Red Hat / Canonical model. Long ramp; needs ~$10M ARR to be a real business.
4. **Trademark licensing** — "Nucleor-Certified" badge program. Postgres community does this informally; CNCF Kubernetes Conformance is the gold-standard model.
5. **Enterprise indemnification tier** — Apache has no warranty/indemnity; some enterprises will pay for a separate commercial agreement adding those.
6. **Sponsorship** — GitHub Sponsors, OpenCollective, Polar.sh. Passive baseline; rarely material on its own.

### 6d. Trademark — single highest-leverage action

**Trademark is more important than license for control.** Apache-2.0 explicitly excludes trademark grant. Trademark gives you:

- Anyone can fork the code (Apache permits this)
- Nobody can call their fork "Nucleor"
- Forks must rename: this is why Iceweasel existed, why Valkey is not Redis, why OpenTofu is not Terraform, why MariaDB is not MySQL, why Rocky/Alma exist instead of RHEL

**Action items (Phase 1):**

1. **Free TESS clearance search** for "Nucleor" in International Class 9 (computer software) and Class 42 (SaaS). DIY at uspto.gov.
2. **If clean, file TEAS Plus with USPTO:** ~$250 Class 9 + ~$250 Class 42 = ~$500 self-filed, or ~$1,500 attorney-filed (recommend attorney for first filing). 8-14 months from filing to registration.
3. **Use ™ symbol** on all Nucleor branding immediately; ® only after registration.
4. **Reserve domains** if not already: nucleor.org, nucleor.dev, nucleor-lang.org.
5. **Trademark policy doc** (1-2 pages, model on Rust's and Postgres's): permitted uses ("supports Nucleor," "Nucleor-compatible"), reserved uses (product names, logos, "Official Nucleor"), nominative-use guidance.

### 6e. CLA vs DCO

Why this matters: if you ever want to add a commercial tier (Ferrocene-style certified-build), you need authority over contributor copyrights. Adopting a CLA at v1.0 (small contributor count) is far easier than retroactively at v3.0.

**Recommendation: lightweight CLA** via Apache ICLA template through cla-assistant.io. Wire into GitHub repo; automatic check on every PR. Document the rationale in CONTRIBUTING.md ("preserves option for a certified-build commercial tier; does not change Apache-2.0 of the codebase").

DCO (`Signed-off-by:`) is sufficient *only* if you commit to never relicensing. Nucleor's roadmap (certified-build tier) means CLA is the correct choice.

**Friction:** CLA-Assistant adds a one-time signature on first PR. Studies show 5-15% drop in casual first-time PRs. For established contributors, friction is one-time and minor. **Worth it.**

### 6f. NOTICE / attribution mechanics

Apache-2.0 §4(d) requires redistributors to preserve NOTICE contents — if they "normally appear" in a generated artifact, they must continue to. **This is the legal hook for the provenance manifest.**

**Action items (Phase 0):**

1. **Per-file SPDX header** on every source file: `// SPDX-License-Identifier: Apache-2.0` + copyright line. Script-driven, ~1 hour for 50K LOC.
2. **Top-level NOTICE file** with project copyright, third-party attributions (LLVM, etc.), and explicit clause:

   > "Nucleor-compiled binaries include a provenance manifest (in the `.nucleor` PE/ELF section). This manifest constitutes an attribution notice under §4(d) of the Apache License 2.0; redistributors of Nucleor-compiled binaries must preserve it."

   This converts a technical feature into a legal attribution lever.
3. **README footer** with copyright + link to LICENSE/NOTICE.
4. **`nuc --version` / `nuc --license`** output prints copyright + license summary.

---

## 7. Integrated Phased Plan

Cross-stream phasing — items that share dependencies are grouped.

### Phase 0 — This Week (compress where possible)

Theme: cheap, high-leverage wins; parallelize across streams.

| # | Item | Stream | Effort |
|---|---|---|---|
| 0.1 | Audit module docs for defense-flavored language | Legal | 2-4 hrs |
| 0.2 | README "Export & Trade Compliance" section | Legal | 1 hr |
| 0.3 | README "Safety & Liability" section | Legal | 1 hr |
| 0.4 | NOTICE file rewrite + provenance attribution clause | Legal | 1 hr |
| 0.5 | SPDX headers on all source files | Legal | 1-2 hrs scripted |
| 0.6 | `nuc --license` subcommand | Legal | 1 hr |
| 0.7 | OpenSSF Best Practices Badge — passing | Cert | 1-3 days |
| 0.8 | OpenSSF Scorecard tuning to ≥7 | Cert | 1 weekend |
| 0.9 | SECURITY.md with PGP key + disclosure address | Cert | 1 hr |
| 0.10 | CycloneDX SBOM in release CI | Cert | half-day |
| 0.11 | Sigstore cosign on releases (keyless via GH OIDC) | Provenance + Cert | half-day |
| 0.12 | Drift-script imports-following design doc | Residuals | 2-4 hrs |

All Phase 0 items target the **next public release** (which would be v1.0.1 — a docs/process release). Bundles cleanly. Verify gate must pass; CHANGELOG block per maintainer workflow.

### Phase 1 — Next ~30 days

Theme: provenance v1, trademark filing, CLA, residuals start.

| # | Item | Stream | Effort |
|---|---|---|---|
| 1.1 | Provenance manifest v1 (`.nucleor` section in PE/ELF) | Provenance | 1-2 days compiler work |
| 1.2 | `nuc verify-binary` subcommand | Provenance | 1 day |
| 1.3 | SHA256SUMS + manifest published per release | Provenance | Half-day |
| 1.4 | SLSA L2 provenance via slsa-github-generator | Cert + Provenance | 1 day |
| 1.5 | TESS clearance search for "Nucleor" | Trademark | 1 hr |
| 1.6 | USPTO TEAS Plus filing (Class 9 + Class 42) | Trademark | 1 day with counsel |
| 1.7 | Reserve nucleor.org / .dev / -lang.org if not done | Trademark | 1 hr |
| 1.8 | CLA-Assistant integration on GitHub repos | Licensing | 2 hrs |
| 1.9 | CONTRIBUTING.md updated with CLA rationale | Licensing | 1 hr |
| 1.10 | `nucleor-advisory-db` repo + `nuc audit` subcommand | Cert | 2-3 days |
| 1.11 | Drift-script teaches imports (closes residual #2) | Residuals | 2-3 days |
| 1.12 | Begin per-rod `#[effect(...)]` retrofit (5-10 rods) | Residuals | Per-rod incremental |

This phase ships as a string of v1.0.x releases per the maintainer workflow.

### Phase 2 — ~30-90 days

Theme: signed provenance, audit protocol, certification climb.

| # | Item | Stream | Effort |
|---|---|---|---|
| 2.1 | Release ed25519 keypair generated + pubkey embedded in compiler | Provenance | 1 day |
| 2.2 | Per-installation key + signed manifests | Provenance | 3-5 days |
| 2.3 | Authenticode cert acquired + signing wired (optional) | Provenance | 1-2 days + ~$300/yr |
| 2.4 | `docs/NUCLEOR_AUDIT_PROTOCOL.md` v0.1 drafted | Audit | 2-3 days |
| 2.5 | `tools/nuc_audit.sh` runnable harness | Audit | 3-5 days |
| 2.6 | Internal audit run + findings doc | Audit | 1-2 weeks |
| 2.7 | Preemptive findings closure (batched releases) | Audit + Residuals | Iterative |
| 2.8 | SLSA L3 hardened build | Cert | 2-3 days |
| 2.9 | OpenSSF Badge — silver | Cert | 1 week |
| 2.10 | NIST SSDF self-attestation (CISA Form 1) | Cert | 1 week |
| 2.11 | `tools_suite` SIG_MATCH bulk closure (residual #1) | Residuals | Iterative cloud-agent cycles |
| 2.12 | Trademark policy doc published | Trademark | 1-2 days |
| 2.13 | Trademark badge program ("Nucleor-Certified") spec | Trademark + Monetization | 2-3 days |

### Phase 3 — ~3-12 months

Theme: third-party audits, reproducible builds, commercial tier scaffolding.

| # | Item | Stream | Effort |
|---|---|---|---|
| 3.1 | Reproducible-builds posture statement + fixes | Provenance + Cert | 2-4 weeks |
| 3.2 | Apply for reproducible-builds tracker listing | Cert | 1 day + ongoing |
| 3.3 | OpenSSF Badge — gold | Cert | Iterative |
| 3.4 | OSTIF / Alpha-Omega audit application | Audit | 1 week + months of waiting |
| 3.5 | s1 local-copy elimination (residual #3) | Residuals | 2-3 weeks careful work |
| 3.6 | Ferrocene-style certified-build tier scaffolding | Monetization | 4-8 weeks |
| 3.7 | "Nucleor Certified" page on nucleor.org | Monetization | 2-3 days |
| 3.8 | "Commercial Use" page documenting offramps | Monetization | 1 day |
| 3.9 | macOS native bootstrap when hardware available (residual #4) | Residuals | Blocked on hardware |
| 3.10 | Counsel engagement — quantum/AI-diffusion memos | Legal | 1-2 weeks counsel time |

### Beyond Phase 3 (year 2+)

- CNA application (only after sustained advisory track record)
- Diversified maintainer team (m-of-n release signing)
- DO-178C/ISO 26262 separately qualified branch (only when customer pays)
- EU CRA compliance work as obligations bind (late 2027)
- International trademark registrations via Madrid Protocol

---

## 8. Open Questions for You

Decision points where I need your input before proceeding:

1. **Phase 0 — go ahead now?** Most of Phase 0 is small enough to ship as a single v1.0.1 release. Do you want me to start that batch tonight? It would include items 0.1-0.6 and 0.9 immediately; 0.7-0.10 within a few days.

2. **Trademark filing — pro se or attorney?** Self-filing saves ~$1000 but office actions are likely on a novel mark. Attorney recommended for first filing. **Recommend attorney.**

3. **Authenticode in Phase 2?** ~$300/yr (Sectigo OV) for better Windows UX, or skip and rely on Sigstore alone? **Recommend Sigstore-only for now; add Authenticode if user complaints come in.**

4. **CLA mandatory at v1.0.1?** This is the easiest moment to add it; harder at v3.0. **Recommend yes.**

5. **Audit protocol drafting — separate session or alongside Phase 0?** It's substantial (500-800 lines). Separate session might be cleaner. **Recommend separate.**

6. **Residual sequencing (per §1):** confirm items 1-2 → 5 → 3 → 4? Or different order?

7. **Per-installation key — auto-enroll online by default, or fully offline?** **Recommend offline-by-default with optional `nuc enroll`.**

8. **External audit funding strategy:** OSTIF/Alpha-Omega application (free, slow, competitive) vs direct Trail-of-Bits engagement ($100-300K, faster)? **Recommend OSTIF/Alpha-Omega application now; defer direct engagement decision until Phase 3 when audit-readiness is proven.**

---

## 9. Cross-Cutting Risks

Things that could derail the plan if not watched:

- **Reproducible builds is a deep rabbit hole.** Some compilers spend years on it. Time-box to 4 weeks; if not converged, defer to year 2.
- **CLA friction** could measurably reduce contributions. Mitigate with clear rationale + lightweight ICLA + no copyright assignment (license grant only).
- **Provenance manifest churn** if v1 schema changes. Define `schema: "nucleor.provenance/v1"` from day one; schema bumps require dual-write transition.
- **OSTIF/Alpha-Omega selection is competitive.** Could be rejected. Have a backup of "self-funded budget engagement at $50-100K" planned for Phase 3.
- **Trademark filing rejection** is possible. Have alternative names in mind. (Unlikely for "Nucleor" — uncommon mark — but plan for it.)
- **AI-diffusion rule landscape moves.** Quantum + CUDA self-classification memos protect us; keep both updated quarterly.

---

## 10. Recommended Immediate Next Step

Start Phase 0. Specifically:

1. Audit docs for defense-flavored language (~30 min)
2. Draft README "Export & Trade Compliance" + "Safety & Liability" sections (~1 hr)
3. Rewrite NOTICE file with provenance-attribution clause (~30 min)
4. Add SPDX headers to all source files (script, ~1 hr)
5. Bundle as v1.0.1 release with verify gate, push to public per workflow

This delivers the legal posture improvements *and* exercises the maintainer-release workflow once before more substantial Phase 1 items land.

Items 0.7-0.11 (badges, SBOM, Sigstore, Scorecard) follow over the next several days.

Let me know which open questions need decisions and which Phase 0 items to start tonight.
