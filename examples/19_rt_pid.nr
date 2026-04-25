// 19_rt_pid.nr — Fully RT-annotated PID step.
//
// Demonstrates the full v0.3 robotics attribute stack working
// together on a single tight inner loop:
//
//   #[no_alloc]    — no Vec / String / format alloc allowed
//   #[no_panic]    — no panic-prone calls (assert, unwrap, ...)
//   #[no_dyn]      — no dynamic dispatch (Box<dyn>, &dyn)
//   #[deadline =N] — wall-clock budget; runtime + static checks
//
// Together these statically gate the inner control step against
// the four most common deadline-busters before the binary ever
// leaves the build host. The inner step takes the gain triple
// and error trio as scalars (instead of a struct by value) so
// the ownership checker doesn't fire OWN-001 in the loop driver.
//
// The outer driver (main) is intentionally NOT RT-annotated:
// it sets up state, calls the RT step in a loop, and prints
// results. println!/format! allocate, so they can't live inside
// a #[no_alloc] body.

#[no_alloc]
#[no_panic]
#[no_dyn]
#[deadline = 100]
fn pid_step_rt(kp: i64, ki: i64, kd: i64, err: i64, integral: i64, last_err: i64) -> i64 {
    let derivative: i64 = err - last_err;
    let p_term: i64 = kp * err;
    let i_term: i64 = ki * (integral + err);
    let d_term: i64 = kd * derivative;
    return p_term + i_term + d_term;
}

fn main() -> i64 {
    let kp: i64 = 5;
    let ki: i64 = 1;
    let kd: i64 = 2;
    let setpoint: i64 = 100;
    let mut measured: i64 = 0;
    let mut integral: i64 = 0;
    let mut last_err: i64 = 0;
    let mut step: i64 = 0;
    print("RT-annotated PID step driving toward setpoint = 100");
    print("step  measured  control_output");
    while step < 6 {
        let err: i64 = setpoint - measured;
        let u: i64 = pid_step_rt(kp, ki, kd, err, integral, last_err);
        // Fake plant: integrate scaled control output into the
        // measurement. Saturated against absurd magnitudes so the
        // demo stays readable without a real f64 path.
        let mut applied: i64 = u / 50;
        if applied > 25 { applied = 25; };
        if applied < (0 - 25) { applied = 0 - 25; };
        measured = measured + applied;
        integral = integral + (setpoint - measured);
        last_err = err;
        let line: str = str_concat(int_to_str(step + 1), str_concat("    ", str_concat(int_to_str(measured), str_concat("    ", int_to_str(u)))));
        print(line);
        step = step + 1;
    };
    return 0;
}
