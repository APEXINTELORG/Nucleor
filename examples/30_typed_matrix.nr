// 30_typed_matrix.nr — Typed newtype wrapper over the linalg rod.
//
// The stdlib linalg rod exposes its API as `i64` handles — fast, but
// loses type information at the call site (`let m: i64 = linalg_new(...)`
// reads as "an integer"). This example shows the recommended pattern
// for typing those handles: a one-field struct that costs nothing at
// runtime but carries intent in the type signature.
//
// Build: nuc build examples/30_typed_matrix.nr -o typed_matrix
// Run:   ./typed_matrix

import "stdlib/rods/linalg.nr"
import "stdlib/rods/complex.nr"

// Newtype wrapper. Compiles to the same i64 the raw API uses; the
// only effect is at the type-check layer where `Matrix` and `i64`
// are now distinct, so you can't accidentally pass an unrelated
// integer where a matrix handle was expected, and vice versa.
struct Matrix {
    handle: i64,
}

fn mat_new(rows: i64, cols: i64) -> Matrix {
    return Matrix { handle: linalg_new(rows, cols) };
}

fn mat_eye(n: i64) -> Matrix {
    return Matrix { handle: linalg_eye(n) };
}

fn mat_get(m: &Matrix, r: i64, c: i64) -> i64 {
    return linalg_get(m.handle, r, c);
}

fn mat_set(m: &Matrix, r: i64, c: i64, v: i64) {
    linalg_set(m.handle, r, c, v);
}

fn mat_trace(m: &Matrix) -> i64 {
    return linalg_trace(m.handle);
}

fn mat_det(m: &Matrix) -> i64 {
    return linalg_det(m.handle);
}

fn mat_mul(a: &Matrix, b: &Matrix) -> Matrix {
    return Matrix { handle: linalg_mul(a.handle, b.handle) };
}

fn mat_solve(a: &Matrix, b: &Matrix) -> Matrix {
    return Matrix { handle: linalg_solve(a.handle, b.handle) };
}

fn main() -> i64 {
    // Build a 3x3 matrix using the typed API.
    let A: Matrix = mat_new(3, 3);
    mat_set(&A, 0, 0, f64_from_int(4)); mat_set(&A, 0, 1, f64_from_int(1)); mat_set(&A, 0, 2, f64_from_int(0));
    mat_set(&A, 1, 0, f64_from_int(1)); mat_set(&A, 1, 1, f64_from_int(3)); mat_set(&A, 1, 2, f64_from_int(1));
    mat_set(&A, 2, 0, f64_from_int(0)); mat_set(&A, 2, 1, f64_from_int(1)); mat_set(&A, 2, 2, f64_from_int(2));

    let b: Matrix = mat_new(3, 1);
    mat_set(&b, 0, 0, f64_from_int(1));
    mat_set(&b, 1, 0, f64_from_int(2));
    mat_set(&b, 2, 0, f64_from_int(3));

    let x: Matrix = mat_solve(&A, &b);
    print("Ax = b with typed Matrix wrapper:");
    print(str_concat("  trace(A) = ", f64_to_str(mat_trace(&A))));
    print(str_concat("  det(A)   = ", f64_to_str(mat_det(&A))));
    print(str_concat("  x[0]     = ", f64_to_str(mat_get(&x, 0, 0))));
    print(str_concat("  x[1]     = ", f64_to_str(mat_get(&x, 1, 0))));
    print(str_concat("  x[2]     = ", f64_to_str(mat_get(&x, 2, 0))));

    return 0;
}
