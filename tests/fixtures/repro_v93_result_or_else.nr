// repro_v93_result_or_else.nr — v0.4.93 small extension.
// Adds Result.or_else(f) — recovers from Err by calling f on the
// err payload to produce a new Result. Pre-fix fell through
// vec_<mname> with no helper → linker fail.
//
// EXPECT runtime output:
//   70    // Err(7).or_else(recover).unwrap() where recover returns Ok(e*10)
//   42    // Ok(42).or_else(recover).unwrap() — Ok passes through

fn recover(e: i64) -> Result<i64, i64> { return Ok(e * 10); }

fn main() -> i64 {
    let x: Result<i64, i64> = Err(7);
    let y: Result<i64, i64> = x.or_else(recover);
    println!("{}", y.unwrap());

    let a: Result<i64, i64> = Ok(42);
    let b: Result<i64, i64> = a.or_else(recover);
    println!("{}", b.unwrap());

    return 0;
}
