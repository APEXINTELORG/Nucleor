// rods/ml/vllm_facade — vLLM-style serving contract (scheduler policy, paged KV cache, block table, eviction policy)
//
import "stdlib/rods/jsonl.nr"

// vllm_facade.nr - vLLM-style serving manifest surface.
//
// This MVP records serving scheduler and paged KV-cache contract metadata. It
// does not claim a native vLLM engine, paged-attention kernel, or
// OpenAI-compatible serving stack yet.

#[repr(C)]
struct VllmManifest {
    model_name: str,
    scheduler_policy: str,
    kv_cache_policy: str,
    dtype_policy: str,
    max_sequence_count: i64,
    max_batched_token_count: i64,
    block_size: i64,
    kv_cache_block_count: i64,
    waiting_queue_count: i64,
    admission_policy_count: i64,
    preemption_policy_count: i64,
    block_table_count: i64,
    kv_eviction_policy_count: i64,
    prefill_route_count: i64,
    decode_route_count: i64,
    paged_attention_count: i64,
    external_runtime_count: i64
}

fn vllm_manifest(
    model_name: str,
    scheduler_policy: str,
    kv_cache_policy: str,
    dtype_policy: str,
    max_sequence_count: i64,
    max_batched_token_count: i64,
    block_size: i64,
    kv_cache_block_count: i64,
    waiting_queue_count: i64,
    admission_policy_count: i64,
    preemption_policy_count: i64,
    block_table_count: i64,
    kv_eviction_policy_count: i64,
    prefill_route_count: i64,
    decode_route_count: i64,
    paged_attention_count: i64,
    external_runtime_count: i64
) -> VllmManifest {
    return VllmManifest {
        model_name: model_name,
        scheduler_policy: scheduler_policy,
        kv_cache_policy: kv_cache_policy,
        dtype_policy: dtype_policy,
        max_sequence_count: max_sequence_count,
        max_batched_token_count: max_batched_token_count,
        block_size: block_size,
        kv_cache_block_count: kv_cache_block_count,
        waiting_queue_count: waiting_queue_count,
        admission_policy_count: admission_policy_count,
        preemption_policy_count: preemption_policy_count,
        block_table_count: block_table_count,
        kv_eviction_policy_count: kv_eviction_policy_count,
        prefill_route_count: prefill_route_count,
        decode_route_count: decode_route_count,
        paged_attention_count: paged_attention_count,
        external_runtime_count: external_runtime_count
    };
}

fn vllm_manifest_print(m: &VllmManifest) -> i64 {
    print("vllm manifest:");
    print("model_name:");
    print(m.model_name);
    print("scheduler_policy:");
    print(m.scheduler_policy);
    print("kv_cache_policy:");
    print(m.kv_cache_policy);
    print("dtype_policy:");
    print(m.dtype_policy);
    print("max_sequence_count:");
    print_int(m.max_sequence_count);
    print("max_batched_token_count:");
    print_int(m.max_batched_token_count);
    print("block_size:");
    print_int(m.block_size);
    print("kv_cache_block_count:");
    print_int(m.kv_cache_block_count);
    print("waiting_queue_count:");
    print_int(m.waiting_queue_count);
    print("admission_policy_count:");
    print_int(m.admission_policy_count);
    print("preemption_policy_count:");
    print_int(m.preemption_policy_count);
    print("block_table_count:");
    print_int(m.block_table_count);
    print("kv_eviction_policy_count:");
    print_int(m.kv_eviction_policy_count);
    print("prefill_route_count:");
    print_int(m.prefill_route_count);
    print("decode_route_count:");
    print_int(m.decode_route_count);
    print("paged_attention_count:");
    print_int(m.paged_attention_count);
    print("external_runtime_count:");
    print_int(m.external_runtime_count);
    return 0;
}

fn vllm_manifest_emit_jsonl(m: &VllmManifest) -> i64 {
    emit_json_run_meta(
        m.model_name,
        "nucleor_vllm",
        "nuc::vllm::manifest",
        m.dtype_policy,
        m.max_sequence_count,
        m.max_batched_token_count,
        m.scheduler_policy
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"vllm_contract\",\"scheduler_policy\":");
    sb_append(sb, jsonl_quote(m.scheduler_policy));
    sb_append(sb, ",\"kv_cache_policy\":");
    sb_append(sb, jsonl_quote(m.kv_cache_policy));
    sb_append(sb, ",\"dtype_policy\":");
    sb_append(sb, jsonl_quote(m.dtype_policy));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("block_size", m.block_size);
    emit_json_metric_i64("kv_cache_block_count", m.kv_cache_block_count);
    emit_json_metric_i64("waiting_queue_count", m.waiting_queue_count);
    emit_json_metric_i64("admission_policy_count", m.admission_policy_count);
    emit_json_metric_i64("preemption_policy_count", m.preemption_policy_count);
    emit_json_metric_i64("block_table_count", m.block_table_count);
    emit_json_metric_i64("kv_eviction_policy_count", m.kv_eviction_policy_count);
    emit_json_metric_i64("prefill_route_count", m.prefill_route_count);
    emit_json_metric_i64("decode_route_count", m.decode_route_count);
    emit_json_metric_i64("paged_attention_count", m.paged_attention_count);
    emit_json_metric_i64("external_runtime_count", m.external_runtime_count);
    return 0;
}

fn vllm_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native vllm engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn vllm_native_available() -> i64 {
    return 0;
}
