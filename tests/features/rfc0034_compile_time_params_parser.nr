// RFC-0034 first-pass parser fixture: compile-time [] params parse and
// erase cleanly for now; runtime parameter lowering remains unchanged.

extern fn host_ct[N: usize](x: i64) -> i64;

fn ct_inc[N: usize](x: i64) -> i64 {
    return x + 1;
}

fn ct_default[N: usize, TILE: usize = 16](x: i64) -> i64 {
    return x + 16;
}

fn ct_type_and_value<T>[N: usize](x: i64) -> i64 {
    return x;
}

fn runtime_only(x: i64) -> i64 {
    return x + 2;
}

fn main() -> i32 {
    let a: i64 = ct_inc(41);
    let b: i64 = runtime_only(5);
    if a == 42 {
        if b == 7 {
            print("OK rfc0034_compile_time_params_parser");
            return 0;
        }
    }
    return 1;
}
