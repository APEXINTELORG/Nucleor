// T3.6 (v0.3.5) #[no_dyn] positive smoke. Two fns marked
// #[no_dyn] that contain only static-dispatch code. Compiler
// should accept the build and the test framework should run
// the assertions to PASS.

#[no_dyn]
fn pid_step_static_int(err: i64, integral: i64) -> i64 {
    let kp: i64 = 5;
    let ki: i64 = 1;
    return kp * err + ki * integral;
}

#[no_dyn]
fn fk_step_static_int(theta: i64, length: i64) -> i64 {
    return length * theta;
}

#[test]
fn test_no_dyn_pid_static_dispatch() {
    let r: i64 = pid_step_static_int(10, 4);
    // 5 * 10 + 1 * 4 = 54
    assert_eq(r, 54);
}

#[test]
fn test_no_dyn_fk_static_dispatch() {
    let r: i64 = fk_step_static_int(3, 7);
    assert_eq(r, 21);
}
