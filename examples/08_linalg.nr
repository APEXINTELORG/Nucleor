// 08_linalg.nr — Solve a linear system Ax = b, then compute its trace and det.
// Build: nuc build examples/08_linalg.nr -o linalg_demo
// Run:   ./linalg_demo.exe

// `use std::*` would be the shorter form, but the use-std-* path has a
// known cfile-collection bug that drops rod-side C files from the clang
// link line. Explicit import composes the correct link set; tracked
// separately as a compiler issue.
import "stdlib/rods/linalg.nr"
import "stdlib/rods/complex.nr"

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
    let A: i64 = linalg_new(3, 3);
    linalg_set(A, 0, 0, f64_from_int(4)); linalg_set(A, 0, 1, f64_from_int(1)); linalg_set(A, 0, 2, f64_from_int(0));
    linalg_set(A, 1, 0, f64_from_int(1)); linalg_set(A, 1, 1, f64_from_int(3)); linalg_set(A, 1, 2, f64_from_int(1));
    linalg_set(A, 2, 0, f64_from_int(0)); linalg_set(A, 2, 1, f64_from_int(1)); linalg_set(A, 2, 2, f64_from_int(2));

    let b: i64 = linalg_new(3, 1);
    linalg_set(b, 0, 0, f64_from_int(1));
    linalg_set(b, 1, 0, f64_from_int(2));
    linalg_set(b, 2, 0, f64_from_int(3));

    let x: i64 = linalg_solve(A, b);
    print("Solving Ax = b for");
    print("  A = [[4,1,0],[1,3,1],[0,1,2]]");
    print("  b = [1, 2, 3]");
    print(str_concat("Solution x[0] = ", ex_f64_to_str(linalg_get(x, 0, 0))));
    print(str_concat("Solution x[1] = ", ex_f64_to_str(linalg_get(x, 1, 0))));
    print(str_concat("Solution x[2] = ", ex_f64_to_str(linalg_get(x, 2, 0))));
    print(str_concat("trace(A) = ", ex_f64_to_str(linalg_trace(A))));
    print(str_concat("det(A)   = ", ex_f64_to_str(linalg_det(A))));
    return 0;
}
