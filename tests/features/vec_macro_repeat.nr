// vec_macro_repeat.nr — v0.6.41 regression fixture (positive).
//
// Closes probe finding 2026-05-01-vec-repeat-syntax-ignores-count.
// Pre-fix `vec![X; N]` ignored N — produced a 1-element Vec
// regardless of the requested count. Adopters writing canonical
// `vec![0; capacity]` got a length-1 vector. v0.6.41 detects the
// top-level `;` separator in the vec! macro and emits a while-
// loop that pushes X N times.
//
// EXPECT: builds + runs to print "5 7 7 3 0" (one per line).

fn main() -> i32 {
    let v: Vec<i64> = vec![7; 5];
    print_int(vec_len(&v) as i32);    // 5
    print_int(vec_get(&v, 0) as i32); // 7
    print_int(vec_get(&v, 4) as i32); // 7
    let v2: Vec<i64> = vec![1, 2, 3];
    print_int(vec_len(&v2) as i32);   // 3
    let v3: Vec<i64> = vec![];
    print_int(vec_len(&v3) as i32);   // 0
    0
}
