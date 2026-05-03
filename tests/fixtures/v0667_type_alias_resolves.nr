// v0.6.67 (probe finding 2026-05-02-module-scope-decl-silent-noop-gaps-
// type-mod-union-use, type-alias sub-gap): `type Name = T;` decls now
// resolve at use sites. Pre-fix accepted at parse but TYP-006 fired on
// every use because types_compatible didn't know about the alias.
type MyInt = i64;
type Counter = MyInt;
type StrAlias = str;

fn process(c: Counter, label: StrAlias) -> MyInt {
    print(label);
    return c + 1;
}

fn main() -> i32 {
    let n: MyInt = 42;
    let c: Counter = n + 1;
    let r: i64 = process(c, "result:");
    print_int(r as i32);
    return 0;
}
