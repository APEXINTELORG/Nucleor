// Probe: tensor_get OOB should PANIC by default
fn main() -> i64 {
    let t: i64 = tensor_zeros(2, 3);
    tensor_set(t, 0, 0, 11);
    let v: i64 = tensor_get(t, 5, 5);  // OOB (2,3) shape
    println!("{}", v);
    return 0;
}
