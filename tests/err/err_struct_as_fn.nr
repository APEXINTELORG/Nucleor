// EXPECT: error[TYP-022] `P(...)` is not how struct values are constructed in Nucleor
// v0.4.148: struct name called like a fn (`P(42)`) silently
// emitted `call i64 @P(...)` and failed late at clang link
// with `error: use of undefined value '@P'`. The v0.4.106 lift
// suppresses uppercase callees from TYP-005 surface (most are
// kind-12 type-prefixed mangled calls), so adopters got the raw
// clang error pointing at compiler-emitted IR. Sister to
// v0.4.138 (struct-as-value at kind-3) — same TYP-022 family,
// detected at the kind-7 (call) site via struct_find_type.
// Mirrored to nucleor_tools_suite.nr.

struct P { x: i64 }

fn main() -> i32 {
    let p = P(42);
    print_int(p.x);
    0
}
