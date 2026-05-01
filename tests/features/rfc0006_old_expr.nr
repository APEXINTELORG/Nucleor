// RFC-0006 Design by Contract — `old(expr)` snapshot in
// #[ensure(...)] postconditions.
//
// v0.4.251: text-level rewriter walks each ensure attribute's
// expression text, finds `old(EXPR)` patterns (paren-balanced,
// string-literal aware), and rewrites them to synthesized
// binding names `__old_<fn_name>_<idx>`. Each inner expression
// gets lex+parsed into the AST pool; lower_fn pre-evaluates them
// at fn entry (when input args are still in their entry state),
// stores to alloca slots, and binds the synth names in sym. The
// rewritten predicate's `__old_*` var-refs resolve via this
// binding to a load from the snapshot slot when evaluated at
// fn exit — comparing entry vs exit state.
//
// EXPECT: build success, runtime exit 0, output "OK rfc0006_old_expr".

#[ensure(result == old(x) + 1)]
fn inc(x: i64) -> i64 {
    x + 1
}

#[ensure(result == old(a) * 2)]
fn double(a: i64) -> i64 {
    a + a
}

#[ensure(result >= old(n))]
fn at_least_input(n: i64) -> i64 {
    if n < 0 { 0 } else { n + 100 }
}

fn main() -> i64 {
    let a: i64 = inc(5);
    if a != 6 { print("FAIL inc(5)"); return 1; };

    let b: i64 = inc(0);
    if b != 1 { print("FAIL inc(0)"); return 1; };

    let c: i64 = double(7);
    if c != 14 { print("FAIL double(7)"); return 1; };

    let d: i64 = at_least_input(0 - 5);
    if d != 0 { print("FAIL at_least_input(-5)"); return 1; };

    let e: i64 = at_least_input(50);
    if e != 150 { print("FAIL at_least_input(50)"); return 1; };

    print("OK rfc0006_old_expr");
    0
}
