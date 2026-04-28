# External Roadmap Input — Integrated 2026-04-28

**Source:** `Nucleor_ML_Suite_ParallelAgent_Mainline/docs/NUCLEOR_WORLD_CLASS_LANGUAGE_ROADMAP_2026-04-27.md`
(local consulting artifact, not external publication)

**Provenance:** the parallel ML Suite agent produced a 16.7 KB Top-15
roadmap during the 2026-04-26..27 work window. This doc triages those
15 items against our existing v0.4-v0.8 milestones and integrates the
picks that aren't already on our trajectory.

## Triage method

For each of the parallel agent's Top 15:
- **Already in v0.4-v0.8 milestone:** noted, no action.
- **Tractable + high-value + not yet tracked:** picked, mapped to a
  milestone, item added to the relevant tracker via cross-link.
- **Too far-out or low-fit for current trajectory:** skipped with
  rationale.

Append-only. Existing milestone trackers keep their structure; each
affected tracker gets one new "External roadmap input (2026-04-28)"
section that points back here for context.

## Already in milestones (no action)

| Item | Where it already lives |
|---|---|
| #1 Cross-platform release | RFC-0022 (v0.3 partial / v0.4 finish; env-blocked from Windows) |
| #2 Package manager / registry / lockfile / semver | RFC-0019 (v0.2 partial / v0.5 continuation) |
| #4 Type-level shapes (Tensor<T,Shape,Device>) | RFC-0010 partial; blocked on RFC-0024 generics (v0.4) |
| #5 Memory safety / allocator model | RFC-0001 / RFC-0002 (v0.3 / v0.4); arena/pool/TLSF in v0.5 |
| #11 Robotics RT + ROS 2 / Isaac integration | v0.5 milestone theme |

## Heavy crossover: Nucleor_Translate (active project)

Picks A / C / D have substantial overlap with the **Nucleor_Translate**
project (`C:\Users\JoeWe\Desktop\Nucleor_Translate`, spec phase
2026-04-26). Translate is a translator that ingests 10 source
languages (Python, Rust, C, C++, C#, Go, Java, JS/TS, Swift, Kotlin)
and emits Nucleor `.nr` source / rods / exes.

| External Pick | Nucleor_Translate overlap |
|---|---|
| **D — `nuc port` Python** | Translate's **Phase A Python front-end** is exactly this. Likely correct move: make `nuc port` the CLI surface over the Translate engine, not a parallel implementation. |
| **C — RFC-0031 native capsule signing** | Translate's coordination item #1 (`.nucleor_provenance` PE/ELF section emitted by `nuc build`) is a subset. RFC-0031 is the bigger story. |
| **A — `nuc fmt` + LSP** | Translate emits Nucleor source; building `nuc fmt` first means emitted code can self-format instead of every Translate rod re-implementing layout. |

**Action:** before starting Picks A / C / D in the v0.5 cycle, read
`Nucleor_Translate\docs\superpowers\specs\2026-04-26-nucleor-translate-design.md`
to confirm dependency graph and avoid duplicate implementation paths.

## Picked — 6 items integrated into milestones

### Pick A — `nuc fmt` + LSP MVP → v0.5.0

**Source item #3** — First-class developer tooling.

**Why pick:** language quality is judged through the editor before
users read the compiler architecture. Aligns with the parallel
agent's "What Not To Do #5" (don't let docs drift from binary). Two
sub-deliverables both fit MVP scope:

- `nuc fmt`: AST→text serializer that respects existing rod conventions
- LSP server (VS Code first): hover, goto-def, completion, diagnostics

**Why v0.5.0 (not v0.4):** v0.4 is already loaded with RFC-0023..0029
language extensions and the Linux/macOS bootstrap. Tooling fits cleanly
in the v0.5.0 "Robotics + DbC + atomics" cycle as the adopter-facing
parallel work.

**Deliverable:** added to `v0.5.0.md` under a new "Developer tooling
MVP (from external roadmap)" section.

### Pick B — Public benchmark / conformance program → v0.4.0 success criteria

**Source item #13** — Public benchmark and conformance program.

**Why pick:** sharpens claim discipline; aligns with the existing
"no-speed-overclaim" rule in our memory + the parallel agent's What
Not To Do #1 ("Do not claim speed leadership until backend dispatch
and public benchmarks prove it"). Doesn't need new compiler features —
it's a CI + reporting program built on top of existing verify gate
data. The local `tools/verify_timings.csv` already provides per-step
timing data per release; this would publish it.

**Why v0.4.0 (not later):** the data already exists in the verify
CSV and the rod count / test count / fixed-point bytes are already
tracked per release. v0.4 just needs the publishing layer.

**Deliverable:** added to `v0.4.0.md` Success criteria as
"Public benchmark dashboard separates parity / performance / claim".

### Pick C — Capsules / SBOM in compiler (not Python) → v0.5.0 or v0.6.0

**Source item #12** — Capsules, signing, SBOM, reproducibility as
core product.

**Why pick:** the parallel agent's ecosystem_blueprints subdirectory
(NCAP signing spec + capsule verifier mocks) shows this is design-ready.
The work is moving today's Python-side hashing/signing into Nucleor
proper. This productizes one of our strongest differentiators.

**Why v0.5.0 (or v0.6.0 if scope grows):** v0.5 already targets the
robotics RT theme where reproducibility evidence is most demanded.
Capsule signing native to nuc fits with `nuc capsule verify` as a
first-class command.

**Deliverable:** added to `v0.5.0.md` as a new RFC stub "RFC-0031
Capsule signing native to compiler" (numbering picks up after
RFC-0023..0030 already used in v0.4).

### Pick D — Python migration funnel (`nuc port`) → v0.5.0+

**Source item #14** — Python migration and interop funnel.

**Why pick:** the parallel agent already produced
`port_plan.md` and `python_port_smoke` examples. Migration funnel
is concrete: analyze Python projects, emit migration plans, convert
low-risk modules. Adoption-critical because Python's installed base is
the battlefield.

**Why v0.5.0+:** v0.4 lacks the generics + frame-typed values to
support faithful port targets. v0.5 ships those, making port output
high-quality. Could spill to v0.6 if scope grows.

**Deliverable:** added to `v0.5.0.md` as a new line item "`nuc port`
Python migration MVP (from external roadmap)".

### Pick E — `nuc serve model.ncap` → v0.6.0

**Source item #10** — Real model interchange and serving.

**Why pick:** the wedge for AI adoption. The ML Suite already has
GGUF/safetensors/ONNX manifests; making `nuc serve` execute them
end-to-end (streaming decode, batching, KV cache, mmap) closes the
demo loop. Adoption story: "from hf model → nuc serve → curl" in
under five minutes.

**Why v0.6.0 (not earlier):** depends on type-level shapes (#4) and
some kernel work to be production-quality. v0.6 is where embedded
targets land — model serving on edge fits.

**Deliverable:** added to `v0.6.0.md` as a new line item
"`nuc serve model.ncap` MVP (from external roadmap)".

### Pick F — Flagship app list (5 concrete) → v0.6.0 / v0.7.0

**Source item #15** — Flagship end-to-end applications.

**Why pick:** the parallel agent specified 5 concrete flagship apps
(local LLM server, ROS 2 robot perception-control, differentiable
physics, dataframe→model pipeline, reproducible regulated artifact).
These are CONCRETE — not vague aspirations. Distributing them across
v0.6 and v0.7 milestones gives each a deliverable home.

**Deliverable:** added to v0.6.0 and v0.7.0 milestones as a new
"Flagship apps from external roadmap" section listing the 5 items
with assignment to milestones.

## Deferred — 4 items, with rationale

### Defer — #6 MLIR/IREE backend strategy → post-v0.8

Multi-quarter compiler-architecture change. Current LLVM textual IR
path works. Reconsider for v0.9+ when heterogeneous-AI hardware
deployment becomes the dominant target.

### Defer — #7 Triton/Mojo-class kernel DSL → after #6

Depends on backend strategy. Keep the rod-scalar + FFI path until
backend is decided.

### Defer — #8 Composable autodiff (jit/grad/vmap) → after RFC-0024

Depends on type-level shapes / generics being production-quality.
Reconsider after RFC-0024 ships in v0.4 / v0.5.

### Defer — #9 Production tensor / dataframe / model libraries → ML_Suite scope

Scope overlap with `Nucleor_ML_Suite` repos. OSS compiler/runtime is
the substrate; the ML Suite is the library home. Keep the split clean.
