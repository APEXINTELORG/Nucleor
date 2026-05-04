# RFC-0051 — Foundation-Model Provenance Type `Model<...>`

**Status:** Draft (frontier easy-win — V2.6)
**Date:** 2026-05-03

## Motivation

ML / VLA / agent applications increasingly need to track WHICH foundation model is loaded, HOW it was trained, WHAT its safety eval said, and HOW it was quantized — at the type level. The frontier writeup proposes `Model<VLA, embodiment=humanoid>` with required safety filter layer; we generalize to a typed-provenance-tuple form that any ML-app code can use.

V2 had `@authored(by, tool, date)` as the file-level analog. This RFC extends to model-level: a typed wrapper that carries provenance through the API boundary.

## Design

```nucleor
struct Model<
    Arch,                       // type-tag: VLA, LLM, Diffusion, Detector, ...
    weights_hash: str,          // SHA-256 of the weights file at load
    dataset_lineage: str,       // pointer into provenance store (or inline DSSE blob)
    license: str,               // SPDX license id of the weights
    safety_eval: str,           // pointer to safety-eval result blob
    quantization: str,          // "fp16", "int8", "fp4", "ternary", ...
    >
{
    handle: i64,                // opaque runtime handle
}
```

Loading a model requires asserting the provenance:
```nucleor
let m: Model<LLM, "abc123...", "dataset_v1.7", "Apache-2.0", "safety_v3.json", "fp4"> =
    load_model("path/to/weights.bin",
               weights_hash: "abc123...",
               dataset_lineage: "dataset_v1.7",
               license: "Apache-2.0",
               safety_eval: "safety_v3.json",
               quantization: "fp4");
```

The runtime helper verifies the hash matches the actual file; on mismatch, panics with provenance-mismatch diag. The string params are then BAKED INTO THE TYPE — downstream fns can require `Model<LLM, _, _, "Apache-2.0", _, _>` (commercial-license-required) and the type-checker enforces it.

## Implementation

- **Parser:** `Model<...>` accepts mixed type-and-string-literal generic params. Reuses existing generic-param parser (extended to accept string-literal arguments alongside type names).
- **Type-check:** string-literal generic params compare by value at type-equality time. Mismatched provenance fails TYP-008 with a clean "model provenance mismatch on field X" diag.
- **Codegen:** the params are phantom (zero-cost). The runtime handle dispatches per Arch tag.
- **Stdlib:** new `model` rod with `load_model`, `infer`, `dispose`, plus `verify_provenance` runtime helper.

## Cost

~400 LOC compiler-side (string-literal generic params are new — current generic params are type-only). ~300 LOC stdlib `model` rod.

## Hot-path risk

None. Phantom params; runtime sees only the i64 handle.

## Frontier connection

Direct frontier writeup §3.2.4 "Foundation model as typed object with provenance." Pairs with the (deferred) governance attributes work — `@authored` at file level, `Model<...>` at runtime-handle level.

## Closure criteria

- `Model<LLM, "hash", "lineage", "license", "safety", "quant">` parses and type-checks.
- Runtime `verify_provenance` panics on hash mismatch.
- Downstream fn with declared license-restriction param rejects model with wrong license.
- Round-2 self-host fixed-point holds.
