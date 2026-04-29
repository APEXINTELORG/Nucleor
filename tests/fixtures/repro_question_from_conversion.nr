// v0.4 parallel lane: `?` converts Result error payloads through From<Src> for Dst.

struct ParseErr {
    code: i64,
}

struct AppErr {
    code: i64,
}

impl From<ParseErr> for AppErr {
    fn from(e: ParseErr) -> AppErr {
        return AppErr { code: e.code + 100 };
    }
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
