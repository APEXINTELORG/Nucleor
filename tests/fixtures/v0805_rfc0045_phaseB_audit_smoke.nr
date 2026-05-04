// v0.8.5 RFC-0045 Phase B step-1 smoke fixture — @differentiable
// audit. Tags 3 fns; the build emits a one-line audit summary
// "audit: @differentiable fns in build: 3" before lower starts.
// rc=0 confirms the fns parse cleanly with the attribute (the
// lex-time skip already handles them).

@differentiable
fn loss(x: i64, y: i64) -> i64 {
    let d: i64 = x - y;
    return d * d;
}

@differentiable
fn forward_pass(x: i64) -> i64 {
    return x * 2;
}

@differentiable
fn gradient(x: i64) -> i64 {
    return 2;
}

fn main() -> i64 {
    let l: i64 = loss(5, 3);          // 4
    let f: i64 = forward_pass(7);     // 14
    let g: i64 = gradient(99);        // 2
    return l + f + g;                  // 20
}
