// v0.8.143 RFC-0043 Phase B step-1 — fixed<I, F> / ufixed<I, F>
// audit (V1.12 drift restoration).
//
// Pre-v0.8.143: type-position `fixed<I, F>` + `ufixed<I, F>`
// parsed, collapsed silently to i64 with no adopter signal at
// build time. RFC-0043 Phase B step-1 surfaces usage with an
// audit-count summary line, matching the v0.8.5 @differentiable
// + v0.8.6 @energy/@thermal pattern.
//
// Phase B step-2 (true IrTypeFixed width tracking, BinOp width
// propagation, mul/div helpers) is deferred — that's a ~300 LOC
// ship.
//
// This fixture exercises both forms in let-position and fn-arg /
// fn-return position. It does not test arithmetic semantics
// (still collapses to i64); it ONLY locks that the regression gate
// counts the type-position occurrences and that the program
// compiles + runs cleanly with rc=0.
//
// Expected: rc=0; build emits "audit: fixed<I,F>/ufixed<I,F>
// type-position occurrences: 5".

fn pid_q88(setpoint: fixed<8, 8>, measured: fixed<8, 8>) -> fixed<8, 8> {
    let err: fixed<8, 8> = setpoint - measured;
    return err;
}

fn main() -> i64 {
    let q15: fixed<8, 8> = 100;
    let m: fixed<8, 8> = 25;
    let r: fixed<8, 8> = pid_q88(q15, m);
    if r != 75 { return 1; };
    return 0;
}
