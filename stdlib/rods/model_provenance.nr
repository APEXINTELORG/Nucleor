// rods/model_provenance — RFC-0051 Phase A: foundation-model
// provenance-tracking surface (rod-only).
//
// The RFC-0051 thesis: ML / VLA / agent applications increasingly
// need to track WHICH foundation model is loaded, HOW it was
// trained, WHAT its safety eval said, and HOW it was quantized —
// at the type level. The full ship phantom-types
// `Model<Arch, weights_hash, dataset, license, safety_eval, quant>`
// with string-literal generic params + type-checker enforcement
// (~400 LOC compiler-side, deferred). Phase A (this rod) delivers
// the canonical provenance struct + verification helpers as
// runtime values today.
//
// Sister to RFC-0046 / 47 / 48 / 49 / 50 Phase A — closes the V2
// frontier Tier-A easy-win lane with all six items shipped
// stdlib-first (compiler enforcement remains Phase B for each).
//
// Workflow today:
//
//   import "stdlib/rods/model_provenance.nr"
//
//   let p: ModelProvenance = model_provenance(
//       model_arch_llm(),
//       "abc123...",       // SHA-256 of weights file
//       "dataset_v1.7",    // dataset lineage pointer / DSSE blob
//       "Apache-2.0",      // SPDX license id
//       "safety_v3.json",  // safety-eval result pointer
//       model_quant_fp4()  // quantization tag
//   );
//   model_provenance_register(p);
//
//   // Later (audit / CI gate):
//   if model_provenance_license_is(p, "Apache-2.0") == 1 { ... };
//   if model_provenance_license_commercial_ok(p) == 1 { ... };

#cfile "../runtime/model_provenance_rt.c"

extern fn nuc_model_prov_register(arch_id: i64, weights_hash: str, dataset_lineage: str,
                                   license: str, safety_eval: str, quant_id: i64) -> i64;
extern fn nuc_model_prov_count() -> i64;
extern fn nuc_model_prov_arch(idx: i64) -> i64;
extern fn nuc_model_prov_weights_hash(idx: i64) -> str;
extern fn nuc_model_prov_dataset(idx: i64) -> str;
extern fn nuc_model_prov_license(idx: i64) -> str;
extern fn nuc_model_prov_safety_eval(idx: i64) -> str;
extern fn nuc_model_prov_quant(idx: i64) -> i64;
extern fn nuc_model_prov_clear() -> i64;

// =====================================================
// Architecture tags (stable IDs).
// =====================================================
fn model_arch_llm()       -> i64 { return 1; }
fn model_arch_vla()       -> i64 { return 2; }   // vision-language-action
fn model_arch_diffusion() -> i64 { return 3; }
fn model_arch_detector()  -> i64 { return 4; }
fn model_arch_segment()   -> i64 { return 5; }
fn model_arch_classify()  -> i64 { return 6; }
fn model_arch_speech()    -> i64 { return 7; }
fn model_arch_embedding() -> i64 { return 8; }
fn model_arch_unknown()   -> i64 { return 0; }

fn model_arch_name(id: i64) -> str {
    if id == 1 { return "LLM"; };
    if id == 2 { return "VLA"; };
    if id == 3 { return "Diffusion"; };
    if id == 4 { return "Detector"; };
    if id == 5 { return "Segment"; };
    if id == 6 { return "Classify"; };
    if id == 7 { return "Speech"; };
    if id == 8 { return "Embedding"; };
    return "Unknown";
}

// =====================================================
// Quantization tags.
// =====================================================
fn model_quant_fp32()    -> i64 { return 32; }
fn model_quant_fp16()    -> i64 { return 16; }
fn model_quant_bf16()    -> i64 { return 17; }
fn model_quant_int8()    -> i64 { return 8; }
fn model_quant_fp8()     -> i64 { return 9; }
fn model_quant_fp4()     -> i64 { return 4; }
fn model_quant_int4()    -> i64 { return 5; }
fn model_quant_ternary() -> i64 { return 3; }
fn model_quant_binary()  -> i64 { return 1; }
fn model_quant_unknown() -> i64 { return 0; }

fn model_quant_name(id: i64) -> str {
    if id == 32 { return "fp32"; };
    if id == 16 { return "fp16"; };
    if id == 17 { return "bf16"; };
    if id == 8  { return "int8"; };
    if id == 9  { return "fp8"; };
    if id == 4  { return "fp4"; };
    if id == 5  { return "int4"; };
    if id == 3  { return "ternary"; };
    if id == 1  { return "binary"; };
    return "unknown";
}

// =====================================================
// ModelProvenance struct — the rod-level analog of the RFC's
// phantom-typed Model<Arch, ...> generic.
// =====================================================
struct ModelProvenance {
    arch:           i64,
    weights_hash:   str,
    dataset_lineage: str,
    license:        str,
    safety_eval:    str,
    quantization:   i64,
}

fn model_provenance(arch: i64, weights_hash: str, dataset: str,
                    license: str, safety_eval: str, quant: i64) -> ModelProvenance {
    return ModelProvenance {
        arch: arch,
        weights_hash: weights_hash,
        dataset_lineage: dataset,
        license: license,
        safety_eval: safety_eval,
        quantization: quant,
    };
}

fn model_provenance_register(p: &ModelProvenance) -> i64 {
    return nuc_model_prov_register(p.arch, p.weights_hash, p.dataset_lineage,
                                    p.license, p.safety_eval, p.quantization);
}

fn model_provenance_count() -> i64 { return nuc_model_prov_count(); }

fn model_provenance_get(idx: i64) -> ModelProvenance {
    return ModelProvenance {
        arch:            nuc_model_prov_arch(idx),
        weights_hash:    nuc_model_prov_weights_hash(idx),
        dataset_lineage: nuc_model_prov_dataset(idx),
        license:         nuc_model_prov_license(idx),
        safety_eval:     nuc_model_prov_safety_eval(idx),
        quantization:    nuc_model_prov_quant(idx),
    };
}

fn model_provenance_clear() -> i64 { return nuc_model_prov_clear(); }

// =====================================================
// Helper queries — the kind of audit / gating predicates real
// adopter code wants. Phase B promotes these to type-level
// constraints; Phase A runs them at runtime.
// =====================================================
fn model_provenance_license_is(p: &ModelProvenance, want: str) -> i64 {
    if str_eq(p.license, want) == 1 { return 1; };
    return 0;
}

// v1.0.1 (audit-pass-1 integrator): borrow-form accessors so OWN-001
// (now error-severity) doesn't false-fire when adopters call multiple
// accessors on the same ModelProvenance.
fn model_provenance_license_commercial_ok(p: &ModelProvenance) -> i64 {
    if str_eq(p.license, "Apache-2.0") == 1 { return 1; };
    if str_eq(p.license, "MIT") == 1 { return 1; };
    if str_eq(p.license, "BSD-3-Clause") == 1 { return 1; };
    if str_eq(p.license, "BSD-2-Clause") == 1 { return 1; };
    if str_eq(p.license, "MPL-2.0") == 1 { return 1; };
    if str_eq(p.license, "0BSD") == 1 { return 1; };
    return 0;
}

fn model_provenance_arch_is(p: &ModelProvenance, want: i64) -> i64 {
    if p.arch == want { return 1; };
    return 0;
}

fn model_provenance_quant_is(p: &ModelProvenance, want: i64) -> i64 {
    if p.quantization == want { return 1; };
    return 0;
}

fn model_provenance_to_json(p: &ModelProvenance) -> str {
    let mut out: str = "{\"arch\":\"";
    out = str_concat(out, model_arch_name(p.arch));
    out = str_concat(out, "\",\"weights_hash\":\"");
    out = str_concat(out, p.weights_hash);
    out = str_concat(out, "\",\"dataset_lineage\":\"");
    out = str_concat(out, p.dataset_lineage);
    out = str_concat(out, "\",\"license\":\"");
    out = str_concat(out, p.license);
    out = str_concat(out, "\",\"safety_eval\":\"");
    out = str_concat(out, p.safety_eval);
    out = str_concat(out, "\",\"quantization\":\"");
    out = str_concat(out, model_quant_name(p.quantization));
    out = str_concat(out, "\"}");
    return out;
}
