// 11_pid.nr — A PID controller drives a noisy plant toward a setpoint.

use std::control;
use std::complex;

fn ex_int_to_str(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = ""; let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 { let d: i64 = v - (v / 10) * 10; s = str_concat(str_substring("0123456789", d, d + 1), s); v = v / 10; };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

fn ex_f64_to_str(val: i64) -> str {
    let is_neg: i64 = f64_lt(val, f64_from_int(0));
    let av: i64 = f64_abs(val);
    let ip: i64 = f64_to_int(f64_floor(av));
    let frac: i64 = f64_sub(av, f64_from_int(ip));
    let fs: i64 = f64_to_int(f64_floor(f64_mul(frac, f64_from_int(1000000))));
    let mut fstr: str = ex_int_to_str(fs);
    while str_len(fstr) < 6 { fstr = str_concat("0", fstr); };
    let mut r: str = str_concat(ex_int_to_str(ip), str_concat(".", fstr));
    if is_neg == 1 { r = str_concat("-", r); };
    return r;
}

fn main() -> i64 {
    let pid: i64 = pid_new(f64(0, 500000), f64(0, 50000), f64(0, 100000));
    let setpoint: i64 = f64_from_int(10);
    let dt: i64 = f64(0, 100000);

    let mut y: i64 = f64_from_int(0);
    let mut step: i64 = 0;
    print("PID controller driving plant toward setpoint = 10.0");
    print("step  measurement  controller_output");
    while step < 8 {
        let u: i64 = pid_update(pid, setpoint, y, dt);
        y = f64_add(y, f64_mul(u, dt));
        print(str_concat(ex_int_to_str(step + 1),
              str_concat("    ", str_concat(ex_f64_to_str(y),
              str_concat("    ", ex_f64_to_str(u))))));
        step = step + 1;
    };
    return 0;
}
