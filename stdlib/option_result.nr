// Nucleor stdlib: option_result
// Option and Result helpers for bootstrap compiler.

fn unwrap_or(opt: Option<i32>, default: i32) -> i32 {
    match opt {
        Some { value } => value,
        None => default,
    }
}

fn result_unwrap_or(res: Result<i32, i32>, default: i32) -> i32 {
    match res {
        Ok { value } => value,
        Err { value } => default,
    }
}

fn main() -> i32 {
    // Each value used exactly once (move semantics)
    let a: Option<i32> = Some(42);
    print_int(unwrap_or(a, 0));

    let b: Option<i32> = None;
    print_int(unwrap_or(b, -1));

    let ok: Result<i32, i32> = Ok(100);
    print_int(result_unwrap_or(ok, 0));

    let err: Result<i32, i32> = Err(99);
    print_int(result_unwrap_or(err, 0));
    0
}
