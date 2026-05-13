// 20_rt_motor_ffi.nr - Motor-control kernel using RT-safe extern markers.
//
// The L1 RT stack from 19_rt_pid.nr (#[no_alloc] + #[no_panic]
// + #[no_dyn] + #[deadline]) plus FFI markers to a C-side
// motor driver. Without the markers, calling extern fn from
// the #[deadline] body would fire warning[RT-005] for every
// extern call. With both markers, the RT-005 check considers
// the externs RT-safe.
//
// See examples/README.md and docs/language-reference.md for the marker
// matrix; tests/fixtures/t324_ffi_no_alloc.nr is the verify
// gate fixture proving the markers work; this file shows the
// same pattern in a runnable application example.

#cfile "../stdlib/runtime/example_motor_rt.c"

#[ffi_no_alloc]
#[ffi_no_panic]
extern fn host_motor_read_encoder() -> i64;

#[ffi_no_alloc]
#[ffi_no_panic]
extern fn host_motor_write_torque(cmd: i64) -> i64;

#[ffi_no_alloc]
#[ffi_no_panic]
extern fn host_get_clock_us() -> i64;

// Motor control kernel - full RT stack plus FFI to driver.
// Both #[ffi_no_*] markers required on each extern because
// A marked extern is RT-safe only when it carries both
// #[ffi_no_alloc] and #[ffi_no_panic]. Drop either marker on any
// extern and RT-005 fires for that extern.
#[no_alloc]
#[no_panic]
#[no_dyn]
#[deadline = 200]
fn motor_step(setpoint: i64, kp: i64) -> i64 {
    let pos: i64 = host_motor_read_encoder();
    let err: i64 = setpoint - pos;
    let cmd: i64 = kp * err;
    let _: i64 = host_motor_write_torque(cmd);
    return cmd;
}

// Note: the C-side stub models a pure integrator with no
// damping, so high gains diverge. Real motors include
// friction + back-EMF; for the demo we pick kp small enough
// that the loop stays bounded across the printed steps.
fn main() -> i64 {
    let setpoint: i64 = 100;
    let kp: i64 = 1;  // critically tuned for the no-damping stub
    print("Motor control loop with #[ffi_no_*] markers");
    print("step  encoder  cmd  t_us");
    let mut step: i64 = 0;
    while step < 6 {
        let t0: i64 = host_get_clock_us();
        let cmd: i64 = motor_step(setpoint, kp);
        let pos: i64 = host_motor_read_encoder();
        let line: str = str_concat(int_to_str(step + 1),
            str_concat("    ", str_concat(int_to_str(pos),
                str_concat("    ", str_concat(int_to_str(cmd),
                    str_concat("    ", int_to_str(t0)))))));
        print(line);
        step = step + 1;
    };
    return 0;
}
