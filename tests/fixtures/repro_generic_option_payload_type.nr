fn main() -> i64 {
    let opt: Option<str> = Some("hello");
    match opt {
        Some(s) => {
            let bad: i64 = s;
            return bad;
        },
        None => return 0,
    };
    return 0;
}
