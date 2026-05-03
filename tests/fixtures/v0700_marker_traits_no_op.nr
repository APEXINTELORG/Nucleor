// v0.7.0 (canonical-Rust acceptance): Rust marker traits
// `Sized`, `Send`, `Sync`, `Unpin`, `RefUnwindSafe`, `UnwindSafe`,
// `Copy`, `Clone` are no-ops under Nucleor's i64-everywhere ABI
// (all values pass as i64, which is Sized + Send + Sync at the ABI
// level). Pre-fix bounds like `<T: ?Sized>` and `<T: Send + Sync>`
// fired TYP-019 / TYP-025 because the marker traits aren't declared
// or impl'd. Now the bound-check + impl-check both skip these
// markers — adopters porting Rust generic-fn code with these
// standard bounds get a clean build.
fn worker<T: Send + Sync>(t: T) -> i32 {
    return 0;
}

fn boxed<T: ?Sized>(t: &T) -> i32 {
    return 1;
}

fn copy_clone<T: Copy + Clone>(t: T) -> i32 {
    return 2;
}

fn main() -> i32 {
    print_int(worker(42));
    print_int(copy_clone(7));
    return 0;
}
