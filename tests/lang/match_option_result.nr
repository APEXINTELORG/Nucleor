// match_option_result.nr — RFC-0016 partial: native match on enum Some/None/Ok/Err
// Generic Option<T>/Result<T,E> ship in v0.4; v0.2 ships the i64-payload form
// using user-declared enums. The compiler match/destructure already works on
// these — this test verifies the parser+typechecker+codegen end-to-end.

enum Opt {
    None,
    Some(i64),
}

enum Res {
    Ok(i64),
    Err(i64),
}

fn classify_opt(o: Opt) -> i64 {
    match o {
        Opt::Some(x) => { return x * 2; },
        Opt::None => { return 0; },
    };
}

fn classify_res(r: Res) -> i64 {
    match r {
        Res::Ok(v)  => { return v + 100; },
        Res::Err(e) => { return 0 - e; },
    };
}

fn main() -> i32 {
    let mut fail: i64 = 0;

    if classify_opt(Opt::Some(42)) != 84 { fail = fail + 1; print("FAIL: classify_opt Some\n"); };
    if classify_opt(Opt::None) != 0 { fail = fail + 1; print("FAIL: classify_opt None\n"); };
    if classify_res(Res::Ok(5)) != 105 { fail = fail + 1; print("FAIL: classify_res Ok\n"); };
    if classify_res(Res::Err(3)) != (0 - 3) { fail = fail + 1; print("FAIL: classify_res Err\n"); };

    if fail == 0 { print("OK match_option_result\n"); return 0; };
    return 1;
}
