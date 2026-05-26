// Closure capture reproducer — recursive higher-order capture.
//
// Demonstrates that __nucleor_capture_set / __nucleor_capture_get use a
// static per-closure-literal table, so re-entering a capturing closure
// overwrites the outer activation's slot.
//
// Expected (correct) output:
//   k=10 -> 20
//   k=100 -> 200
// Observed (today): outer call observes inner call's k value.

fn apply(f: i64, x: i64) -> i64 { return f(x); }

fn make_doubler(k: i64) -> i64 {
    // Captures k by reference. The runtime stores k in slot
    // (clo_id_of_this_literal, 0).
    let g: i64 = |x| x * k;
    return g;
}

fn main() -> i64 {
    let g10: i64 = make_doubler(10);
    let g100: i64 = make_doubler(100);

    // Each apply call invokes one of the closures; if capture_set is
    // re-emitted at each indirect call site (current codegen behavior)
    // then g10 and g100 share the same (clo_id, 0) slot and the second
    // make_doubler stomped the first.
    let a: i64 = apply(g10, 2);    // expect 20
    let b: i64 = apply(g100, 2);   // expect 200

    print("expect: a=20, b=200");
    print(str_concat("got a=", str_concat(int_to_str(a), str_concat(", b=", int_to_str(b)))));
    let mut fail: i64 = 0;
    if a != 20 { print("FAIL a (capture stomped — outer closure's k overwritten)"); fail = fail + 1; };
    if b != 200 { print("FAIL b"); fail = fail + 1; };
    if fail == 0 { print("OK closure_capture_recursion"); return 0; };
    return 1;
}
