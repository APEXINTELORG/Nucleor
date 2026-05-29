import "stdlib/rods/ml/ship_facade.nr"

fn main() -> i64 {
    let manifest = ship_manifest(
        "tiny_decoder_fixture.ncap",
        "ncap",
        "native_capsule_artifact",
        "nucleor.ncap.package.v0",
        "unsigned_reproducible_package",
        "none_unsigned_smoke",
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        0,
        0
    );

    ship_manifest_print(&manifest);
    ship_manifest_emit_jsonl(&manifest);
    ship_manifest_emit_status(1);
    if ship_native_available() != 0 { panic("ship_facade falsely advertises a native backend"); };
    return 0;
}
