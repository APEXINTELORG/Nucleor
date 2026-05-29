import "stdlib/rods/ml/gguf_facade.nr"

fn main() -> i32 {
    let manifest: GgufManifest = gguf_manifest(
        "tiny_decoder_gguf_fixture",
        "llama",
        24,
        9,
        3,
        18,
        6,
        6,
        4096,
        2,
        1,
        1
    );
    gguf_manifest_print(&manifest);
    gguf_manifest_emit_jsonl(&manifest);
    gguf_manifest_emit_status(1);
    if gguf_native_available() != 0 { panic("gguf_facade falsely advertises a native backend"); };
    return 0;
}
