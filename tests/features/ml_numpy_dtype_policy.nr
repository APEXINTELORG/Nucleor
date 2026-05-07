import "stdlib/rods/ml/tensor_facade.nr"

fn main() -> i32 {
    print("dtype policy surface:");
    print(dtype_name(dtype_i64()));
    print(dtype_name(dtype_f16()));
    print(dtype_name(dtype_bf16()));
    print(dtype_name(dtype_f32()));
    print(dtype_name(dtype_f64()));
    print(dtype_name(dtype_qint8()));
    print(dtype_name(dtype_nf4()));

    print("default accumulators:");
    print(dtype_name(dtype_default_accumulator(dtype_i64())));
    print(dtype_name(dtype_default_accumulator(dtype_bf16())));
    print(dtype_name(dtype_default_accumulator(dtype_f32())));
    print(dtype_name(dtype_default_accumulator(dtype_f64())));
    print(dtype_name(dtype_default_accumulator(dtype_qint8())));
    print(dtype_name(dtype_default_accumulator(dtype_nf4())));

    let i: TensorI64 = tensor_i64_full(2, 3, 7);
    tensor_i64_print_flat("i64 tensor result:", &i);
    return 0;
}
