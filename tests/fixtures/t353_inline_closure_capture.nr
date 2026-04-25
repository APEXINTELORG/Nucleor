// t353_inline_closure_capture.nr — v0.3.78 regression fixture.
//
// Pins inline-closure-with-capture support at .map / .filter call
// sites. Pre-v0.3.78, the textual closure preprocessor hoisted
// arg-position closures into top-level fns without capture detection,
// so `v.map(|x| x * factor)` produced the cryptic clang link error
// `use of undefined value '@factor'`. v0.3.78 disables the textual
// hoisting entirely, routing arg-position closures through the AST
// kind 42 path that has full capture support (v0.3.72 runtime).
//
// This closes the documented v1 boundary from the v0.3.72 ship.
//
// Returns 0 on success; non-zero exit is the specific check that failed
// (91 = no-capture, 92 = single, 93 = multi, 94 = filter, 95 = stored).

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1); v.push(2); v.push(3);

    // 1) No capture — must still work (regression check)
    let m1: Vec<i64> = v.map(|x| x * 2);
    if m1[2] != 6 { return 91; };

    // 2) Single capture (the original v1 boundary case)
    let factor: i64 = 5;
    let m2: Vec<i64> = v.map(|x| x * factor);
    if m2[2] != 15 { return 92; };

    // 3) Multiple captures
    let off: i64 = 100;
    let m3: Vec<i64> = v.map(|x| x * factor + off);
    if m3[2] != 115 { return 93; };

    // 4) Filter with capture (different iter method, same dispatch)
    let threshold: i64 = 1;
    let m4: Vec<i64> = v.filter(|x| x > threshold);
    if vec_len(m4) != 2 { return 94; };

    // 5) Stored closure with capture (regression check — must still work)
    let mul = |x: i64| x * factor;
    if mul(7) != 35 { return 95; };

    return 0;
}
