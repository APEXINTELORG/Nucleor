# Helper Schema Inventory & Population — Contract

> **Source:** User-provided contract `Helpers.md` (2026-04-22).
> **Status (2026-04-23, v0.2.132):** **Phase 1 + Phase 2 shipped;
> population at 95.1%.** Numbers below are unchanged since v0.2.78
> — the v0.2.79–132 sub-chain has been audit-pattern hardening
> (gate steps, doc fixes, diagnostic-code coverage closure) on top
> of the populated manifest, not new helper additions.
>
> - **Phase 1 echo on record:** chat transcript ending v0.2.32.
> - **Phase 1 walk approved:** user authorized "go" → walk
>   completed v0.2.41 (taxonomy: 13 classes covering 676 helpers).
> - **Phase 2 mechanism:** `tools/gen_helper_manifest.py` shipped
>   v0.2.41; populates `docs/rfcs/helper_manifest.toml` from the
>   canonical s1-compiler ABI tables + runtime C source. It was later
>   replaced by native `tools/gen_helper_manifest.nr`; drift-gate
>   enforcement remains via `tools/check_compiler_drift.sh`.
> - **Phase 2 population:** 643 of 676 helpers (95.1%) carry
>   populated `effects` / `taint` / `proof_obligation` fields as
>   of v0.2.78. Remaining 33 are intentional v0.4 placeholders
>   (TensorOps GPU/device + 3 ToolingMeta stubs).
> - **Going-forward constraint:** live since v0.2.42 — drift gate
>   blocks any helper change that doesn't include a regenerated
>   manifest. (Manifest mech shipped v0.2.41; drift-gate
>   enforcement landed v0.2.42 per the v0.2.33 promise.)

## Goal

Produce a single source-of-truth schema map for every helper in the
Nucleor_OSS project, grouped and sorted by class. No code changes to
helpers themselves. This is a cataloging pass, not a refactor.

## Scope

Entire repo. Every `.nr` file, every ABI table, every runtime entry.
If something looks like a helper and you're not sure, include it and
flag it — do not silently drop.

## Definition of "helper"

Any named callable that is **(a)** referenced by symbol from compiler
codegen, **OR (b)** listed in an ABI table, **OR (c)** lives in
`stdlib/runtime` and is called by generated code rather than user
code. If a function is only called from user-space Nucleor programs
via normal `import`s, it is NOT a helper for this purpose — it is
**stdlib API**.

## Phase 1 — Inventory & Classification (echo before acting)

Walk the repo and produce ONLY a summary report (in chat — no file
writes) with:

- Total helper count
- Proposed class taxonomy (propose classes from what's actually
  found — do not invent classes for things not present)
- Count per class
- 3 example helper names per class
- A list of any helpers not confidently classified

**Candidate classes to consider** (use only those that apply, add
others if the code demands it):

- `PureMath` — no effects, no taint, passthrough units
- `PanickingArith` — can panic: div-by-zero, overflow, etc.
- `Allocation` — alloc, free, realloc, GC interface
- `IO` — read/write/print, effectful
- `EffectMachinery` — effect handler stack, resume, reify
- `TaintOps` — taint propagation, sink/source marking
- `UnitOps` — SI coercion, dimensional analysis
- `ProofEmit` — Sage_NS interval ops, certificate emission
- `Concurrency` — atomics, fences, locks, memory ordering
- `StringFormat` — formatting, conversion, parsing
- `CompilerIntrinsic` — must-inline: stack probe, bounds check,
  overflow check
- `VectorOps` — `vec_*` batch
- `Unclassified` — flag for human review (DO NOT GUESS)

**STOP AFTER PHASE 1.** Wait for explicit approval of the taxonomy
before any file writes. Do not draft schema rows yet. Do not edit
any file in Phase 1 except to produce the report.

## Phase 2 — Schema + Population (only after approval)

Schema (one row per helper, TOML, sorted by class then name):

```toml
[[helper]]
name             = "<short name, e.g. vec_mean_f64>"
class            = "<one of approved classes>"
symbol           = "<linker symbol, e.g. __nucleor_vec_mean_f64>"
dispatch         = "Inline" | "RuntimeCall" | "Intrinsic"
abi              = "<signature, e.g. (ptr, usize) -> f64>"
effects          = []                 # list of effect tags
taint            = "passthrough" | "propagates" | "breaks"
units            = "passthrough" | "carries" | "strips"
proof_obligation = "none" | "emits" | "consumes"
stability        = "stable" | "unstable" | "experimental"
since            = "<version introduced, e.g. 0.2.18>"
notes            = ""                 # free text, optional
```

**Output file:** `docs/rfcs/helper_manifest.toml`
**Also emit:** `docs/rfcs/helper_manifest_schema.md` — one-page,
field-by-field meaning, valid values, and a worked example.

If a helper's policy is non-obvious (anything touching certificates,
panics, allocation, effects, units, or taint), **DO NOT GUESS** —
emit the row with fields marked `TODO` and list the helper at the
top of the file under a `# REVIEW REQUIRED` comment block.

## Negative list — DO NOT

- Do not modify any helper implementation.
- Do not modify any ABI table.
- Do not rename anything.
- Do not merge or de-duplicate helpers even if they look redundant.
- Do not skip helpers because their policy is unclear — flag them.
- Do not invent policy (e.g., don't claim `effects = []` unless
  you verified it by reading the implementation).
- Do not run the drift gate or compile; this pass produces docs only.
- Do not commit. Leave the working tree dirty for human review.

## Echo-before-acting

Before starting Phase 1, reply with:

1. Your understanding of what counts as a helper in this repo
2. Which directories you will walk
3. Which file types you will scan
4. What you will NOT touch

Wait for "go" before the walk.

## Going-forward constraint (added v0.2.33, drift-enforced v0.2.42)

- Any helper added to the codebase from v0.2.33 onward MUST also
  add a row to `helper_manifest.toml` in the same commit.
- Any helper *used* in a new example or stdlib path triggers the
  same manifest-row obligation if the helper isn't already cataloged.
- Drift-gate enforcement is **live since v0.2.42**:
  `tools/check_compiler_drift.sh` runs `gen_helper_manifest.nr`
  in dry-run mode and compares the output to the committed file;
  any divergence (new helper added to s1, runtime, or tools-suite
  without a regenerated manifest) blocks the verify gate.

(Timeline: v0.2.40 shipped the initial manifest with 144
REVIEW REQUIRED rows; v0.2.41 audit pass dropped that to 0 by
extending the generator's `INTENTIONAL_PLACEHOLDER` allowlist
+ macro-expansion regex; v0.2.42 wired the drift-gate
enforcement promised in the v0.2.33 going-forward constraint.)

## Success criteria

- Every helper in the repo appears exactly once in the manifest.
- Every row is either fully populated or flagged `REVIEW REQUIRED`.
- Schema doc page exists and is self-contained.
- Working tree is not committed (during the cataloging pass itself).
- Phase 1 report was approved before Phase 2 ran.
