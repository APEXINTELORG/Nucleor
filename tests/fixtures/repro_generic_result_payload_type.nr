fn main() -> i64 {
    let res: Result<i64, str> = Err("bad");
    match res {
        Ok(v) => return v,
        Err(e) => {
            let bad: i64 = e;
            return bad;
        },
    };
    return 0;
}
