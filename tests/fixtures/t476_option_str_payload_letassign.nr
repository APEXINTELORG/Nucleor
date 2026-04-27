// Probe v0.4.4 — Option<str> Some(s) binding flows through to
// non-macro contexts (let assignment, str_eq, etc).
pub struct Import {
    name: str,
    alias: Option<str>,
}

fn main() -> i64 {
    let with_alias: Import = Import { name: "bar", alias: Some("b") };

    let extracted: str = match with_alias.alias {
        None => "(none)",
        Some(s) => s,
    };

    if str_eq(extracted, "b") != 1 { return 1; };

    let no_alias: Import = Import { name: "foo", alias: None };
    let none_check: str = match no_alias.alias {
        None => "(none)",
        Some(s) => s,
    };
    if str_eq(none_check, "(none)") != 1 { return 1; };

    return 0;
}
