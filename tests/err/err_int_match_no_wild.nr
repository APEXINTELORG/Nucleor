// EXPECT: error[MATCH-001] non-exhaustive integer match
// v0.4.109: int/str match without `_` arm is provably non-exhaustive.
// Pre-fix `match x { 1 => 10, 2 => 20 }` for x=5 silently fell
// through to 0 — same hazard class as the v0.4.59 enum match-as-expr
// close, but the existing exhaustiveness check explicitly excluded
// __int/__str patterns at lines 9760/10060 so int/str matches escaped
// MATCH-001 entirely. Now any int/str match without `_` is MATCH-001.

fn main() -> i32 {
    let x: i32 = 5;
    let y: i32 = match x {
        1 => 10,
        2 => 20,
    };
    print_int(y);
    0
}
