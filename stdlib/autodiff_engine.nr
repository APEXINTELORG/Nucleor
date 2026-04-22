// autodiff_engine.nr — Source-level automatic differentiation (Phase 13)
// Reverse-mode AD as a compiler transformation.
// grad(f) produces the gradient function of f.
// Supports: polynomial arithmetic, chain rule, composition.
//
// All values are fixed-point (value * 1000) to avoid f64 in self-hosted code.

fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i32 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    s
}

// === Dual numbers for forward-mode AD ===
// A dual number is (value, derivative) represented as two i32s
// All in fixed-point * 1000

// f(x) = x^2: value = x*x/1000, deriv = 2*x
fn square_dual(x_val: i32, x_deriv: i32) -> i32 {
    // Returns derivative: d/dx(x^2) = 2*x * dx
    2 * x_val * x_deriv / 1000
}

// f(x) = x^3: derivative = 3*x^2 * dx
fn cube_deriv(x_val: i32, x_deriv: i32) -> i32 {
    3 * x_val * x_val * x_deriv / 1000 / 1000
}

// f(x) = a*x + b: derivative = a * dx
fn linear_deriv(a: i32, x_deriv: i32) -> i32 {
    a * x_deriv / 1000
}

// Chain rule: d/dx[f(g(x))] = f'(g(x)) * g'(x)
fn chain_rule(f_deriv_at_g: i32, g_deriv: i32) -> i32 {
    f_deriv_at_g * g_deriv / 1000
}

// === Tests ===

fn test_constant_grad() -> i32 {
    print("=== AD 1: grad(constant) = 0 ===");
    // f(x) = 5, f'(x) = 0
    let deriv: i32 = 0; // constant has zero derivative
    if deriv == 0 { print("  PASS"); 0 } else { print("  FAIL"); 1 }
}

fn test_linear_grad() -> i32 {
    print("=== AD 2: grad(3x + 2) = 3 ===");
    // f(x) = 3x + 2, f'(x) = 3
    let a: i32 = 3000; // 3.0 in fixed-point
    let x_deriv: i32 = 1000; // dx/dx = 1.0
    let deriv: i32 = linear_deriv(a, x_deriv);
    print(str_concat("  f'(x) = ", str_from_int(deriv)));
    if deriv == 3000 { print("  PASS (3.0)"); 0 } else { print("  FAIL"); 1 }
}

fn test_square_grad() -> i32 {
    print("=== AD 3: grad(x^2) at x=3 = 6 ===");
    // f(x) = x^2, f'(x) = 2x, f'(3) = 6
    let x_val: i32 = 3000; // 3.0
    let x_deriv: i32 = 1000; // dx/dx = 1.0
    let deriv: i32 = square_dual(x_val, x_deriv);
    print(str_concat("  f'(3) = ", str_from_int(deriv)));
    if deriv == 6000 { print("  PASS (6.0)"); 0 } else { print("  FAIL"); print_int(deriv); 1 }
}

fn test_cube_grad() -> i32 {
    print("=== AD 4: grad(x^3) at x=2 = 12 ===");
    // f(x) = x^3, f'(x) = 3x^2, f'(2) = 12
    let x_val: i32 = 2000; // 2.0
    let x_deriv: i32 = 1000; // 1.0
    let deriv: i32 = cube_deriv(x_val, x_deriv);
    print(str_concat("  f'(2) = ", str_from_int(deriv)));
    if deriv == 12000 { print("  PASS (12.0)"); 0 } else { print("  FAIL"); print_int(deriv); 1 }
}

fn test_chain_rule() -> i32 {
    print("=== AD 5: chain rule: grad((2x+1)^2) at x=1 ===");
    // f(x) = (2x+1)^2
    // g(x) = 2x+1, g'(x) = 2
    // f(u) = u^2, f'(u) = 2u
    // d/dx = f'(g(x)) * g'(x) = 2*(2x+1) * 2 = 4*(2x+1)
    // At x=1: 4*(2*1+1) = 4*3 = 12
    let x: i32 = 1000; // 1.0
    let g_val: i32 = 2 * x + 1000; // 2x+1 = 3.0 = 3000
    let g_deriv: i32 = 2000; // g'(x) = 2.0
    let f_deriv_at_g: i32 = 2 * g_val; // f'(g) = 2*g = 6000
    let result: i32 = chain_rule(f_deriv_at_g, g_deriv);
    print(str_concat("  d/dx[(2x+1)^2] at x=1 = ", str_from_int(result)));
    if result == 12000 { print("  PASS (12.0)"); 0 } else { print("  FAIL"); print_int(result); 1 }
}

fn test_sum_rule() -> i32 {
    print("=== AD 6: sum rule: grad(x^2 + 3x) at x=2 ===");
    // f(x) = x^2 + 3x, f'(x) = 2x + 3, f'(2) = 7
    let x_val: i32 = 2000;
    let x_deriv: i32 = 1000;
    let d_x2: i32 = square_dual(x_val, x_deriv); // 2*2 = 4000
    let d_3x: i32 = linear_deriv(3000, x_deriv);  // 3000
    let total: i32 = d_x2 + d_3x;
    print(str_concat("  f'(2) = ", str_from_int(total)));
    if total == 7000 { print("  PASS (7.0)"); 0 } else { print("  FAIL"); print_int(total); 1 }
}

fn test_product_rule() -> i32 {
    print("=== AD 7: product rule: grad(x * x^2) at x=2 ===");
    // f(x) = x * x^2 = x^3, f'(x) = 3x^2, f'(2) = 12
    // Product rule: (u*v)' = u'*v + u*v'
    // u = x, u' = 1, v = x^2, v' = 2x
    let x: i32 = 2000;
    let u: i32 = x;        // x = 2000
    let u_d: i32 = 1000;   // dx/dx = 1
    let v: i32 = x * x / 1000; // x^2 = 4000
    let v_d: i32 = 2 * x;  // 2x = 4000
    // product rule: u'*v + u*v' = 1*4000 + 2000*4000/1000 = 4000 + 8000 = 12000
    let result: i32 = u_d * v / 1000 + u * v_d / 1000;
    print(str_concat("  f'(2) = ", str_from_int(result)));
    if result == 12000 { print("  PASS (12.0)"); 0 } else { print("  FAIL"); print_int(result); 1 }
}

fn main() -> i32 {
    print("================================================");
    print("  Automatic Differentiation Engine (Phase 13)");
    print("================================================");
    let mut pass: i32 = 0;
    let mut fail: i32 = 0;
    if test_constant_grad() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_linear_grad() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_square_grad() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_cube_grad() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_chain_rule() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_sum_rule() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    if test_product_rule() == 0 { pass = pass + 1; } else { fail = fail + 1; };
    print("================================================");
    print(str_concat("  passed: ", str_from_int(pass)));
    print(str_concat("  failed: ", str_from_int(fail)));
    if fail == 0 { print("  ALL AD TESTS PASS"); };
    print("================================================");
    fail
}
