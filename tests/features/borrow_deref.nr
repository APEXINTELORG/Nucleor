// Phase 2b: Dereference &i32 to get i32

fn add_via_ref(a: &i32, b: &i32) -> i32 {
    *a + *b
}

fn main() -> i32 {
    let x: i32 = 10;
    let y: i32 = 20;
    let rx: &i32 = &x;
    let ry: &i32 = &y;
    let sum: i32 = *rx + *ry;
    print_int(sum);

    let result: i32 = add_via_ref(&x, &y);
    print_int(result);
    0
}
