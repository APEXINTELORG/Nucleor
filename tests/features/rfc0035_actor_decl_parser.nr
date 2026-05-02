// RFC-0035 first-pass positive: field-only actor declarations parse
// through the contextual actor -> struct expander.

actor Counter {
    n: i64,
}

impl Counter {
    fn read(self) -> i64 {
        return self.n;
    }
}

fn main() -> i32 {
    let c: Counter = Counter { n: 42 };
    if c.read() != 42 { print("FAIL rfc0035_actor_decl_parser\n"); return 1; };
    print("OK rfc0035_actor_decl_parser\n");
    return 0;
}
