// EXPECT: error[TYP-027] type annotation required

fn make<T>() -> Vec<T> {
    Vec<T>::new()
}

fn main() -> i32 {
    let v = make();
    print_int(0);
    0
}
