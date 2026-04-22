// =====================================================
// rods/math — Integer math utilities
// =====================================================
// Import: import "stdlib/rods/math.nr"
// Provides: math_abs, math_min, math_max, math_clamp, math_pow_int,
//   math_sqrt_int, math_gcd, math_lcm, math_is_even, math_is_odd
// =====================================================

fn math_abs(n: i64) -> i64 {
    if n < 0 { return 0 - n; };
    return n;
}

fn math_min(a: i64, b: i64) -> i64 {
    if a < b { return a; };
    return b;
}

fn math_max(a: i64, b: i64) -> i64 {
    if a > b { return a; };
    return b;
}

fn math_clamp(val: i64, lo: i64, hi: i64) -> i64 {
    if val < lo { return lo; };
    if val > hi { return hi; };
    return val;
}

fn math_pow_int(base: i64, exp: i64) -> i64 {
    if exp < 0 { return 0; };
    if exp == 0 { return 1; };
    let mut result: i64 = 1;
    let mut i: i64 = 0;
    while i < exp {
        result = result * base;
        i = i + 1;
    };
    return result;
}

fn math_sqrt_int(n: i64) -> i64 {
    if n <= 0 { return 0; };
    if n == 1 { return 1; };
    let mut x: i64 = n;
    let mut y: i64 = (x + 1) / 2;
    while y < x {
        x = y;
        y = (x + n / x) / 2;
    };
    return x;
}

fn math_gcd(a: i64, b: i64) -> i64 {
    let mut x: i64 = math_abs(a);
    let mut y: i64 = math_abs(b);
    while y != 0 {
        let t: i64 = y;
        y = x - (x / y) * y;
        x = t;
    };
    return x;
}

fn math_lcm(a: i64, b: i64) -> i64 {
    if a == 0 || b == 0 { return 0; };
    let g: i64 = math_gcd(a, b);
    return math_abs(a / g * b);
}

fn math_is_even(n: i64) -> i64 {
    let half: i64 = n / 2;
    if half * 2 == n { return 1; };
    return 0;
}

fn math_is_odd(n: i64) -> i64 {
    if math_is_even(n) == 1 { return 0; };
    return 1;
}
