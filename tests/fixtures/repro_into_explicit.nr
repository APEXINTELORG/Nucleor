// v0.4 parallel lane: generic trait impl headers keep explicit Into<T> dispatch wired.

struct ParseErr {
    code: i64,
}

struct AppErr {
    code: i64,
}

impl Into<AppErr> for ParseErr {
    fn into(self) -> AppErr {
        return AppErr { code: self.code + 9 };
    }
}

fn main() -> i64 {
    let p: ParseErr = ParseErr { code: 3 };
    let a: AppErr = p.into();
    return a.code;
}
