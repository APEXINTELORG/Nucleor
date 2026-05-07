import "stdlib/rods/ml/ncap_facade.nr"

fn main() -> i64 {
    let manifest = ncap_package_manifest(
        "tiny_decoder_fixture.ncap",
        "nucleor.ncap.package.v0",
        "tiny_decoder_fixture",
        "ncap",
        2,
        120,
        79,
        0,
        0
    );

    ncap_package_manifest_print(&manifest);
    ncap_package_manifest_emit_jsonl(&manifest);
    ncap_package_manifest_emit_status(1);
    return 0;
}
