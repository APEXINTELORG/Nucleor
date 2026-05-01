// EXPECT: error[DEPTH-001] analysis cannot bound callback or function-pointer path

fn touch_unknown(x: i64) -> i64 {
    return x + 1;
}

#[max_depth = 4]
fn callback_unknown(depth: i64, cb: fn(i64) -> i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    let ignored: i64 = cb(depth);
    return callback_unknown(depth + 1, cb);
}

fn main() -> i64 {
    return callback_unknown(0, touch_unknown);
}
