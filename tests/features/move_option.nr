// Phase 2a: Move semantics — Option/Result values move

struct Payload { data: i32 }

fn main() -> i32 {
    // Option moves
    let opt: Option<i32> = Some(42);
    let opt2: Option<i32> = opt;   // opt moves to opt2
    // opt is now moved — can't use it
    let val: i32 = match opt2 {
        Some { value } => value,
        None => 0,
    };
    print_int(val);

    // Result moves
    let res: Result<i32, i32> = Ok(100);
    let res2: Result<i32, i32> = res;  // res moves to res2
    let val2: i32 = match res2 {
        Ok { value } => value,
        Err { value } => value,
    };
    print_int(val2);

    // Copy types inside Some don't prevent Option from moving
    let a: Option<i32> = Some(7);
    let b: Option<i32> = a;    // a moves
    let c: i32 = match b {
        Some { value } => value,
        None => 0,
    };
    print_int(c);

    0
}
