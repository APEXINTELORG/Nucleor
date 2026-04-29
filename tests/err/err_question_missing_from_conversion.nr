// EXPECT: TRAIT-001 missing From conversion for ?

struct ParseErr {
    code: i64,
}

struct AppErr {
    code: i64,
}

fn parse_fail() -> Result<i64, ParseErr> {
    return Err(ParseErr { code: 7 });
}

fn pipeline() -> Result<i64, AppErr> {
    let v: i64 = parse_fail()?;
    return Ok(v);
}

fn main() -> i64 {
    let r: Result<i64, AppErr> = pipeline();
    return match r {
        Ok(v) => v,
        Err(e) => e.code,
    };
}
