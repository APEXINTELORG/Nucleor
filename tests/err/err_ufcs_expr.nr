// EXPECT: nucleor: UFCS expression form not yet supported
// v0.6.60 — UFCS halts cleanly at parse (was wrong-class NR020 token kind 32)
struct S { x: i64 }
trait Foo { fn f(self) -> i64; }
impl Foo for S { fn f(self) -> i64 { return self.x; } }
fn main() -> i32 {
    let s: S = S { x: 5 };
    let r: i64 = <S as Foo>::f(&s);
    return r as i32;
}
