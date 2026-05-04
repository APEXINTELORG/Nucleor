// v0.7.90 RFC-0051 Phase A smoke fixture — foundation-model
// provenance tracking. Validates:
//   - Architecture + quantization tags return stable IDs
//   - ModelProvenance struct constructs cleanly
//   - register / count / get round-trip preserves all fields
//   - License predicates: license_is + commercial_ok
//   - JSON serialization smoke
//   - Clear resets the registry
import "stdlib/rods/model_provenance.nr"

fn main() -> i64 {
    model_provenance_clear();

    if model_arch_llm() != 1 { return 1; };
    if model_arch_vla() != 2 { return 2; };
    if model_quant_fp4() != 4 { return 3; };
    if model_quant_fp16() != 16 { return 4; };

    let p1: ModelProvenance = model_provenance(
        model_arch_llm(),
        "abc123",
        "dataset_v1.7",
        "Apache-2.0",
        "safety_v3.json",
        model_quant_fp4()
    );

    let p2: ModelProvenance = model_provenance(
        model_arch_vla(),
        "def456",
        "internal-only",
        "Proprietary",
        "n/a",
        model_quant_int8()
    );

    model_provenance_register(p1);
    model_provenance_register(p2);

    if model_provenance_count() != 2 { return 5; };

    let g0: ModelProvenance = model_provenance_get(0);
    if g0.arch != model_arch_llm() { return 6; };
    if str_eq(g0.weights_hash, "abc123") == 0 { return 7; };
    if str_eq(g0.license, "Apache-2.0") == 0 { return 8; };

    if model_provenance_license_is(p1, "Apache-2.0") != 1 { return 9; };
    if model_provenance_license_is(p1, "MIT") != 0 { return 10; };
    if model_provenance_license_commercial_ok(p1) != 1 { return 11; };
    if model_provenance_license_commercial_ok(p2) != 0 { return 12; };

    if model_provenance_arch_is(p1, model_arch_llm()) != 1 { return 13; };
    if model_provenance_arch_is(p1, model_arch_vla()) != 0 { return 14; };
    if model_provenance_quant_is(p1, model_quant_fp4()) != 1 { return 15; };

    let n: str = model_arch_name(model_arch_diffusion());
    if str_eq(n, "Diffusion") == 0 { return 16; };

    let qn: str = model_quant_name(model_quant_int8());
    if str_eq(qn, "int8") == 0 { return 17; };

    let json: str = model_provenance_to_json(p1);
    if str_len(json) < 50 { return 18; };

    model_provenance_clear();
    if model_provenance_count() != 0 { return 19; };

    return 0;
}
