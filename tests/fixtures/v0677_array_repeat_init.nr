// v0.6.77 RFC V1.11: `[VAL; N]` array-literal repeat-init.
// Pre-fix `let buf: Vec<i64> = [0; 4];` rejected with the wrong-class
// `error[NR020]: parse error at byte K: expected ',', got ';'` —
// the bracket-list parser had no `;` branch. Now after parsing the
// first item, peek for `;`; if present parse the count (literal int)
// and emit an N-item kind-47 array (vec_new + N pushes).
fn main() -> i32 {
    let buf: Vec<i64> = [0; 4];
    print_int(vec_len(&buf) as i32);
    let zeros: Vec<i64> = [42; 3];
    print_int(vec_get(&zeros, 0) as i32);
    print_int(vec_get(&zeros, 1) as i32);
    print_int(vec_get(&zeros, 2) as i32);
    return 0;
}
