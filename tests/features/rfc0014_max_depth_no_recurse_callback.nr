// RFC-0014 extension positive: fn-pointer callback params are
// conservative unless the parameter is explicitly marked no_recurse.

fn touch(x: i64) -> i64 {
    return x + 1;
}

#[max_depth = 5]
fn callback_walk(depth: i64, #[no_recurse] cb: fn(i64) -> i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    let ignored: i64 = cb(depth);
    return callback_walk(depth + 1, cb);
}

fn main() -> i64 {
    let got: i64 = callback_walk(0, touch);
    if got != 4 { return 1; };
    print("OK rfc0014_max_depth_no_recurse_callback");
    return 0;
}
