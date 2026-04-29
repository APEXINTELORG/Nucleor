// repro_v92_option_result_fn_arg_methods.nr — v0.4.92.
// Extends v0.4.90 Option/Result method dispatch to fn-arg methods:
// .map(f), .and_then(f), .unwrap_or_else(f).
//
// Pre-fix:
//   .map fell through iter_method_for_vec → vec_map_i64 (link fail)
//   .unwrap_or_else hit the v0.4.90 var-ref fallback but no helper
//   existed for it; vec_unwrap_or_else doesn't exist (link fail).
//
// EXPECT runtime output:
//   10            // Some(5).map(double).unwrap()
//   99            // None.unwrap_or_else(fallback)
//   42            // Ok(42).map(identity).unwrap()
//   77            // Err(0).unwrap_or_else(err_to_77)

fn double(x: i64) -> i64 { return x * 2; }
fn identity(x: i64) -> i64 { return x; }
fn fallback() -> i64 { return 99; }
fn err_to_77(e: i64) -> i64 { return 77; }

fn main() -> i64 {
    let a: Option<i64> = Some(5);
    let b: Option<i64> = a.map(double);
    println!("{}", b.unwrap());

    let n: Option<i64> = None;
    println!("{}", n.unwrap_or_else(fallback));

    let r: Result<i64, i64> = Ok(42);
    let r2: Result<i64, i64> = r.map(identity);
    println!("{}", r2.unwrap());

    let e: Result<i64, i64> = Err(0);
    println!("{}", e.unwrap_or_else(err_to_77));

    return 0;
}
