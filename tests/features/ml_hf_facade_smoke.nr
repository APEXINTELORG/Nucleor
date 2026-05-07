import "stdlib/rods/ml/hf_facade.nr"

fn main() -> i64 {
    let manifest = hf_manifest(
        "nuc_hf_frontend_v0",
        "tiny_decoder_hf_fixture",
        "text_generation",
        "config_json_generation_config_model_card",
        "tokenizer_json_tokenizer_config_vocab_merges",
        "safetensors_ncap",
        "lora_peft",
        "local_artifact_first_zero_python",
        4,
        3,
        4,
        2,
        3,
        2,
        1,
        1,
        6,
        1,
        1,
        0,
        1
    );

    hf_manifest_print(&manifest);
    hf_manifest_emit_jsonl(&manifest);
    hf_manifest_emit_status(1);
    return 0;
}
