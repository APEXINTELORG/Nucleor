import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_kmeans_predict_f64",
        "scikit-learn fitted KMeans transform predict inertia",
        "nuc::learn::kmeans_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.0); xd.push(0.0);
    xd.push(1.0); xd.push(1.0);
    xd.push(5.0); xd.push(4.0);
    xd.push(6.0); xd.push(5.0);
    let x: TensorF64 = tensor_f64_from_vec(4, 2, xd);

    let mut cd: Vec<f64> = Vec::new();
    cd.push(0.0); cd.push(0.5);
    cd.push(5.5); cd.push(4.5);
    let centers: TensorF64 = tensor_f64_from_vec(2, 2, cd);
    let model: KMeansF64 = kmeans_f64(centers);

    let distances: TensorF64 = kmeans_f64_transform(&model, &x);
    tensor_f64_print_flat("kmeans transform distances:", &distances);

    let labels: TensorI64 = kmeans_f64_predict(&model, &x);
    tensor_i64_print_flat("kmeans labels:", &labels);

    print("kmeans inertia:");
    print_f64(kmeans_f64_inertia(&model, &x));
    return 0;
}
