// T3.37 (v0.3.62) — regression test for fixed-size array
// indexing in inline f64 binops, fixed in v0.3.62.
//
// Pre-v0.3.62: `arr[0] + arr[1]` where arr: [f64; 3]
// returned `nan`. The v0.3.55 kind==10 fix only handled
// `Vec<T>`; fixed-size arrays `[T; N]` use the same AST kind
// (parser shares the `[]` indexing path) but `__fulltype_arr`
// stores the full array shape `[f64; 3]` which my v0.3.55
// pattern matcher's `Vec<` prefix check missed. v0.3.62
// extends the kind==10 dispatcher to also recognize the
// `[T; N]` shape and extract T.
//
// Production-relevant: fixed-size state vectors / sensor
// batches with known length are common in robotics
// (`[f64; 6]` for SE(3) pose, `[f64; 3]` for accelerometer
// readings, etc.).
//
// Verify gate (T3.37) asserts the four primary ops on
// fixed-size f64 array indexing produce correct values.

fn main() -> i32 {
    let arr: [f64; 4] = [1.0, 4.0, 8.0, 2.0];

    let r1: f64 = arr[0] + arr[1];   // 5.0
    print_f64(r1);

    let r2: f64 = arr[0] - arr[1];   // -3.0
    print_f64(r2);

    let r3: f64 = arr[0] * arr[1];   // 4.0
    print_f64(r3);

    let r4: f64 = arr[2] / arr[1];   // 2.0
    print_f64(r4);

    // Nested: arr[0]*arr[1] + arr[2]*arr[3] = 4 + 16 = 20.
    let r5: f64 = arr[0] * arr[1] + arr[2] * arr[3];
    print_f64(r5);
    0
}
