import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_ridge_multioutput_predict_f64",
        "scikit-learn fitted Ridge multi-output predict",
        "nuc::learn::linear_multioutput_f64_predict",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0); xd.push(-1.0);
    xd.push(0.5); xd.push(-0.5); xd.push(2.0);
    xd.push(3.0); xd.push(0.0); xd.push(1.0);
    xd.push(-1.0); xd.push(1.0); xd.push(0.5);
    let x: TensorF64 = tensor_f64_from_vec(4, 3, xd);

    let mut wd: Vec<f64> = Vec::new();
    wd.push(1.2); wd.push(-0.4); wd.push(0.5);
    wd.push(-0.7); wd.push(0.3); wd.push(1.1);
    let weights: TensorF64 = tensor_f64_from_vec(2, 3, wd);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(0.25); bd.push(-0.1);
    let bias: TensorF64 = tensor_f64_from_vec(1, 2, bd);

    let model: LinearMultiOutputModelF64 = linear_multioutput_model_f64(weights, bias);
    let pred: TensorF64 = linear_multioutput_f64_predict(&model, &x);
    tensor_f64_print_flat("ridge multi-output prediction:", &pred);
    return 0;
}
