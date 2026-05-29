import "stdlib/rods/ml/vllm_facade.nr"

fn main() -> i32 {
    let manifest: VllmManifest = vllm_manifest(
        "tiny_vllm_scheduler_fixture",
        "continuous_batching_contract",
        "paged_kv_cache_contract",
        "fp16_kv_f32_logits",
        8,
        512,
        16,
        64,
        1,
        2,
        1,
        8,
        1,
        1,
        1,
        1,
        1
    );
    vllm_manifest_print(&manifest);
    vllm_manifest_emit_jsonl(&manifest);
    vllm_manifest_emit_status(1);
    if vllm_native_available() != 0 { panic("vllm_facade falsely advertises a native backend"); };
    return 0;
}
