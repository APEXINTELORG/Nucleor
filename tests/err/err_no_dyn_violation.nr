// EXPECT: RT-003 dynamic dispatch
// T3.6 (v0.3.5) negative — fn marked #[no_dyn] whose source
// contains the literal `dyn ` token. Production code would
// have `&dyn Trait` in the signature; this fixture uses a
// string literal so the v1 text-scan check has something to
// catch without dragging in trait method dispatch (which
// arrives in v0.4 RFC-0026 v2).

#[no_dyn]
fn dispatch_handler(x: i64) -> i64 {
    let kind: str = "dyn handler mode";
    return x;
}

fn main() -> i64 {
    return 0;
}
