import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

// ml_tensor_facade_smoke — exercises the parity-flavored TensorF64 surface
// from stdlib/rods/ml/tensor_facade.nr: matmul, broadcast-add-row,
// reductions, transpose, reshape. Self-contained: no external CSV
// fixtures. Deeper NumPy parity claims live in subsequent batches.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // f64 2x2 matmul: [[1,2],[3,4]] x [[5,6],[7,8]] = [[19,22],[43,50]]
    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(2.0);
    ad.push(3.0); ad.push(4.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 2, ad);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(5.0); bd.push(6.0);
    bd.push(7.0); bd.push(8.0);
    let b: TensorF64 = tensor_f64_from_vec(2, 2, bd);

    let c: TensorF64 = tensor_f64_matmul(&a, &b);
    if close_f64(tensor_f64_at(&c, 0, 0), 19.0, eps) != 1 { print("FAIL matmul 00"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&c, 0, 1), 22.0, eps) != 1 { print("FAIL matmul 01"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&c, 1, 0), 43.0, eps) != 1 { print("FAIL matmul 10"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&c, 1, 1), 50.0, eps) != 1 { print("FAIL matmul 11"); fail = fail + 1; };

    // Row broadcast add + axis reductions on a 2x3 tensor.
    let mut md: Vec<f64> = Vec::new();
    md.push(1.0); md.push(2.0); md.push(3.0);
    md.push(4.0); md.push(5.0); md.push(6.0);
    let m: TensorF64 = tensor_f64_from_vec(2, 3, md);

    let mut rd: Vec<f64> = Vec::new();
    rd.push(10.0); rd.push(20.0); rd.push(30.0);
    let row: TensorF64 = tensor_f64_from_vec(1, 3, rd);

    let bc: TensorF64 = tensor_f64_broadcast_add_row(&m, &row);
    if close_f64(tensor_f64_at(&bc, 0, 0), 11.0, eps) != 1 { print("FAIL bcast 00"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&bc, 1, 2), 36.0, eps) != 1 { print("FAIL bcast 12"); fail = fail + 1; };

    let r0: TensorF64 = tensor_f64_reduce_axis0(&m);
    if close_f64(tensor_f64_at(&r0, 0, 0), 5.0, eps) != 1 { print("FAIL r0 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r0, 0, 2), 9.0, eps) != 1 { print("FAIL r0 2"); fail = fail + 1; };

    // Transpose 2x3 -> 3x2.
    let t: TensorF64 = tensor_f64_transpose(&m);
    if t.shape.rows != 3 { print("FAIL T rows"); fail = fail + 1; };
    if t.shape.cols != 2 { print("FAIL T cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&t, 2, 1), 6.0, eps) != 1 { print("FAIL T val"); fail = fail + 1; };

    // Reshape preserves data.
    let rs: TensorF64 = tensor_f64_reshape(&m, 3, 2);
    if rs.shape.rows != 3 { print("FAIL rs rows"); fail = fail + 1; };
    if rs.shape.cols != 2 { print("FAIL rs cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&rs, 2, 1), 6.0, eps) != 1 { print("FAIL rs val"); fail = fail + 1; };

    // Cross-rod parity manifest emit.
    let manifest: ParityManifest = parity_manifest(
        "ml_tensor_facade_smoke",
        "internal",
        "stdlib::rods::ml::tensor_facade",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        2,
        eps
    );
    parity_manifest_print(&manifest);

    if fail == 0 {
        print("OK ml_tensor_facade_smoke");
        return 0;
    };
    print("FAIL ml_tensor_facade_smoke");
    return 1;
}
