import "stdlib/rods/ml/sbom_facade.nr"

fn main() -> i64 {
    let manifest = sbom_manifest(
        "nucleor_ml_suite",
        "nucleor_sbom_v0",
        "tiny_decoder_fixture.ncap",
        "source_tool_dependency_inventory",
        12,
        4,
        2,
        5,
        0,
        1,
        1,
        1
    );

    sbom_manifest_print(&manifest);
    sbom_manifest_emit_jsonl(&manifest);
    sbom_manifest_emit_status(1);
    return 0;
}
