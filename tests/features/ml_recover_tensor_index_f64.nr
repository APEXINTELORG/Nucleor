import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_index_f64 — flat index computation:
// for a (3, 4) tensor, index(2, 3) should return 2*4 + 3 = 11.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let mut ad: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < 12 {
        ad.push(i as f64);
        i = i + 1;
    };
    let a: TensorF64 = tensor_f64_from_vec(3, 4, ad);

    if tensor_f64_index(&a, 0, 0) != 0 { print("FAIL idx 0,0"); fail = fail + 1; };
    if tensor_f64_index(&a, 1, 0) != 4 { print("FAIL idx 1,0"); fail = fail + 1; };
    if tensor_f64_index(&a, 2, 3) != 11 { print("FAIL idx 2,3"); fail = fail + 1; };

    if tensor_f64_len(&a) != 12 { print("FAIL len"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_index_f64"); return 0; };
    print("FAIL ml_recover_tensor_index_f64");
    return 1;
}
