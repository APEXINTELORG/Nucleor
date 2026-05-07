// rods/ml/hf_facade — Hugging Face local-first frontend contract (transformers, tokenizers, datasets, safetensors, no Python runtime)
//
import "stdlib/rods/jsonl.nr"

// hf_facade.nr - Hugging Face-compatible frontend manifest.
//
// The MVP records the local-first surfaces needed to make Python users feel at
// home: from_pretrained-style config discovery, tokenizer artifacts,
// safetensors/NCAP weights, generation controls, dataset/diffusers/PEFT hooks,
// and explicit zero-Python-runtime accounting.

#[repr(C)]
struct HfManifest {
    stack_name: str,
    model_id: str,
    task_name: str,
    config_formats: str,
    tokenizer_formats: str,
    weight_formats: str,
    adapter_formats: str,
    policy: str,
    pipe_count: i64,
    cfg_count: i64,
    tok_count: i64,
    weight_count: i64,
    gen_count: i64,
    data_count: i64,
    diff_count: i64,
    peft_count: i64,
    fixture_count: i64,
    safe_required: i64,
    local_only: i64,
    hub_count: i64,
    zero_py_runtime: i64
}

fn hf_manifest(
    stack_name: str,
    model_id: str,
    task_name: str,
    config_formats: str,
    tokenizer_formats: str,
    weight_formats: str,
    adapter_formats: str,
    policy: str,
    pipe_count: i64,
    cfg_count: i64,
    tok_count: i64,
    weight_count: i64,
    gen_count: i64,
    data_count: i64,
    diff_count: i64,
    peft_count: i64,
    fixture_count: i64,
    safe_required: i64,
    local_only: i64,
    hub_count: i64,
    zero_py_runtime: i64
) -> HfManifest {
    return HfManifest {
        stack_name: stack_name,
        model_id: model_id,
        task_name: task_name,
        config_formats: config_formats,
        tokenizer_formats: tokenizer_formats,
        weight_formats: weight_formats,
        adapter_formats: adapter_formats,
        policy: policy,
        pipe_count: pipe_count,
        cfg_count: cfg_count,
        tok_count: tok_count,
        weight_count: weight_count,
        gen_count: gen_count,
        data_count: data_count,
        diff_count: diff_count,
        peft_count: peft_count,
        fixture_count: fixture_count,
        safe_required: safe_required,
        local_only: local_only,
        hub_count: hub_count,
        zero_py_runtime: zero_py_runtime
    };
}

fn hf_manifest_print(m: &HfManifest) -> i64 {
    print("hugging face manifest:");
    print("stack_name:");
    print(m.stack_name);
    print("model_id:");
    print(m.model_id);
    print("task_name:");
    print(m.task_name);
    print("config_formats:");
    print(m.config_formats);
    print("tokenizer_formats:");
    print(m.tokenizer_formats);
    print("weight_formats:");
    print(m.weight_formats);
    print("adapter_formats:");
    print(m.adapter_formats);
    print("policy:");
    print(m.policy);
    print("pipe_count:");
    print_int(m.pipe_count);
    print("cfg_count:");
    print_int(m.cfg_count);
    print("tok_count:");
    print_int(m.tok_count);
    print("weight_count:");
    print_int(m.weight_count);
    print("gen_count:");
    print_int(m.gen_count);
    print("data_count:");
    print_int(m.data_count);
    print("diff_count:");
    print_int(m.diff_count);
    print("peft_count:");
    print_int(m.peft_count);
    print("fixture_count:");
    print_int(m.fixture_count);
    print("safe_required:");
    print_int(m.safe_required);
    print("local_only:");
    print_int(m.local_only);
    print("hub_count:");
    print_int(m.hub_count);
    print("zero_py_runtime:");
    print_int(m.zero_py_runtime);
    return 0;
}

fn hf_manifest_emit_jsonl(m: &HfManifest) -> i64 {
    emit_json_run_meta(
        m.model_id,
        "nucleor_hf",
        "nuc::hf::manifest",
        m.weight_formats,
        m.pipe_count,
        m.gen_count,
        m.policy
    );
    emit_json_metric_i64("config_format_count", m.cfg_count);
    emit_json_metric_i64("tokenizer_format_count", m.tok_count);
    emit_json_metric_i64("weight_format_count", m.weight_count);
    emit_json_metric_i64("dataset_surface_count", m.data_count);
    emit_json_metric_i64("diffusers_surface_count", m.diff_count);
    emit_json_metric_i64("peft_surface_count", m.peft_count);
    emit_json_metric_i64("local_fixture_file_count", m.fixture_count);
    emit_json_metric_i64("safetensors_required", m.safe_required);
    emit_json_metric_i64("local_files_only", m.local_only);
    emit_json_metric_i64("hub_download_count", m.hub_count);
    emit_json_metric_i64("zero_python_runtime", m.zero_py_runtime);
    return 0;
}

fn hf_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}
