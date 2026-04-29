// repro_v90_option_result_method_dispatch.nr — v0.4.90 CRITICAL fix.
// Pre-fix even typed Option/Result receivers (`let x: Option<i64> =
// Some(42); x.unwrap()`) hit the v0.4.53 "non-Option receiver"
// panic-guard because the dispatch chain had no Option/Result
// receiver branch. Adopters could not call any Option/Result method
// in v0.4.74 .. v0.4.89 without falling back to manual `match`.
//
// v0.4.90:
//   - Adds C runtime helpers __nucleor_option_unwrap, _is_some,
//     _is_none, _unwrap_or, _expect; same for result_*.
//   - Adds dispatch route in compiler that recognizes Option/Result
//     via either expr_struct_type chain OR direct __type_<var>
//     lookup at the v0.4.53 panic-guard fallback.
//
// Tag layout (per nucleor_s1_compiler.nr line 6793-6808):
//   Option: Some=0  None=1
//   Result: Ok=1    Err=0
//
// EXPECT runtime output:
//   42
//   1
//   0
//   10
//   1
//   0
//   7
//   9

fn main() -> i64 {
    let x: Option<i64> = Some(42);
    println!("{}", x.unwrap());
    println!("{}", x.is_some());
    println!("{}", x.is_none());

    let y: Result<i64, i64> = Ok(10);
    println!("{}", y.unwrap());
    println!("{}", y.is_ok());
    println!("{}", y.is_err());

    let n: Option<i64> = None;
    println!("{}", n.unwrap_or(7));

    let e: Result<i64, i64> = Err(99);
    println!("{}", e.unwrap_or(9));

    return 0;
}
