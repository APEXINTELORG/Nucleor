// Probe: typed Option<str> println via macro, after v0.4.9.
fn main() -> i64 {
    let alias: Option<str> = Some("hello");
    match alias {
        None => println!("alias: <none>"),
        Some(s) => println!("alias: {}", s),
    };

    let result: Result<i64, str> = Err("bad input");
    match result {
        Ok(v) => println!("ok: {}", v),
        Err(e) => println!("err: {}", e),
    };
    return 0;
}
