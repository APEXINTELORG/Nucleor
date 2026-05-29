import "stdlib/rods/ml/serve_facade.nr"

fn main() -> i32 {
    let manifest: ServeManifest = serve_manifest(
        "tiny_decoder_fixture",
        "ncap",
        "nf4",
        "char_i64",
        "scalar_nucleor_facade",
        128,
        4,
        8787,
        2,
        0
    );
    serve_manifest_print(&manifest);
    serve_manifest_emit_jsonl(&manifest);
    serve_manifest_emit_status(1);
    if serve_native_available() != 0 { panic("serve_facade falsely advertises a native backend"); };
    return 0;
}
