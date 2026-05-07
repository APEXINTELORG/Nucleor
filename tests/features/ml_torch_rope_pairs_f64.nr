import "stdlib/rods/ml/ai_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_rope_pairs_f64",
        "torch pairwise rotary position embedding over f64 tensors",
        "nuc::ai::rope_pairs_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        3,
        4,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.2); xd.push(-0.1); xd.push(0.3); xd.push(0.4);
    xd.push(0.0); xd.push(0.3); xd.push(-0.2); xd.push(0.1);
    xd.push(0.5); xd.push(0.4); xd.push(0.0); xd.push(-0.3);
    let x: TensorF64 = tensor_f64_from_vec(3, 4, xd);

    let mut cd: Vec<f64> = Vec::new();
    cd.push(0.995004); cd.push(0.980067);
    cd.push(0.955336); cd.push(0.921061);
    cd.push(0.877583); cd.push(0.825336);
    let cos: TensorF64 = tensor_f64_from_vec(3, 2, cd);

    let mut sd: Vec<f64> = Vec::new();
    sd.push(0.099833); sd.push(0.198669);
    sd.push(0.295520); sd.push(0.389418);
    sd.push(0.479426); sd.push(0.564642);
    let sin: TensorF64 = tensor_f64_from_vec(3, 2, sd);

    let out: TensorF64 = ai_rope_pairs_f64(&x, &cos, &sin);
    tensor_f64_print_flat("rope:", &out);
    return 0;
}
