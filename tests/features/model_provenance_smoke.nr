// v0.8.211 stdlib/rods/model_provenance.nr first test coverage.
//
// RFC-0051 Phase A: foundation-model provenance-tracking surface.
// Pre-v0.8.211: regression gate token-presence gate (v0.8.181) covers
// import; this fixture guards behavior. Phase B promotes the
// helpers to type-level constraints (~400 LOC compiler-side,
// deferred); the rod-runtime semantics here are the
// pre-enforcement contract.
//
// Locks four invariants Phase B compiler enforcement must NOT
// regress:
//
//   1. **Stable arch / quant tag IDs** — LLM=1, VLA=2, ...; FP32=32,
//      FP16=16, FP4=4, ... (audit / CI gates depend on stability).
//   2. **Construct + register round-trip** — register(p) returns
//      idx; provenance_get(idx) returns equal arch / quant.
//   3. **License predicates** — Apache-2.0 / MIT → commercial_ok 1;
//      "GPL-3.0-only" → commercial_ok 0.
//   4. **arch_is / quant_is** — predicate matches the registered
//      values.
//
// Expected: rc=0.

import "stdlib/rods/model_provenance.nr"

fn check_stable_tag_ids() -> i64 {
    if model_arch_llm() != 1 { return 1; };
    if model_arch_vla() != 2 { return 2; };
    if model_arch_diffusion() != 3 { return 4; };
    if model_quant_fp32() != 32 { return 8; };
    if model_quant_fp16() != 16 { return 16; };
    if model_quant_fp4() != 4 { return 32; };
    if model_quant_binary() != 1 { return 64; };
    return 0;
}

fn check_register_round_trip() -> i64 {
    model_provenance_clear();
    let p: ModelProvenance = model_provenance(
        model_arch_llm(),
        "abc123",
        "dataset_v1.7",
        "Apache-2.0",
        "safety_v3.json",
        model_quant_fp4()
    );
    let idx: i64 = model_provenance_register(p);
    if idx < 0 { return 128; };
    let g: ModelProvenance = model_provenance_get(idx);
    if g.arch != model_arch_llm() { return 256; };
    if g.quantization != model_quant_fp4() { return 512; };
    return 0;
}

fn check_license_predicates() -> i64 {
    let p_apache: ModelProvenance = model_provenance(
        model_arch_llm(), "h", "d", "Apache-2.0", "s", model_quant_fp16()
    );
    if model_provenance_license_commercial_ok(p_apache) != 1 { return 1024; };
    if model_provenance_license_is(p_apache, "Apache-2.0") != 1 { return 2048; };

    let p_gpl: ModelProvenance = model_provenance(
        model_arch_llm(), "h", "d", "GPL-3.0-only", "s", model_quant_fp16()
    );
    if model_provenance_license_commercial_ok(p_gpl) != 0 { return 4096; };
    return 0;
}

fn check_arch_quant_predicates() -> i64 {
    let p: ModelProvenance = model_provenance(
        model_arch_diffusion(), "h", "d", "MIT", "s", model_quant_int8()
    );
    if model_provenance_arch_is(p, model_arch_diffusion()) != 1 { return 8192; };
    if model_provenance_arch_is(p, model_arch_llm()) != 0 { return 16384; };
    if model_provenance_quant_is(p, model_quant_int8()) != 1 { return 32768; };
    if model_provenance_quant_is(p, model_quant_fp4()) != 0 { return 65536; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_stable_tag_ids();
    fails = fails + check_register_round_trip();
    fails = fails + check_license_predicates();
    fails = fails + check_arch_quant_predicates();
    return fails;
}
