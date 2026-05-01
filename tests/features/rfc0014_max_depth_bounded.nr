// RFC-0014 positive fixture: explicit depth counter + entry guard.
// EXPECT: build success, runtime exit 0, output "OK rfc0014_max_depth_bounded".

#[max_depth = 5]
fn bounded_walk(depth: i64) -> i64 {
    if depth >= 4 {
        return depth;
    };
    return bounded_walk(depth + 1);
}

fn main() -> i64 {
    let got: i64 = bounded_walk(0);
    if got != 4 {
        return 1;
    };
    print("OK rfc0014_max_depth_bounded");
    return 0;
}
