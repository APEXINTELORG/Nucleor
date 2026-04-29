// EXPECT: error[TYP-022] `E` is a struct type, not a value
// v0.4.138: bare struct name in value position lowered to
// `ptrtoint ptr @<Name> to i64`, failing late at clang link with
// `error: use of undefined value '@<Name>'`. The v0.4.106 lift
// suppresses uppercase-leading names from TYP-005 surface
// (because most are legitimate type-prefixed mangled calls
// handled via kind 12), so adopters got the raw clang error
// pointing at compiler-emitted IR rather than their source.
// Detect at kind-3 type-check: name is not in tenv AND matches
// a defined struct → TYP-022. Mirrored to nucleor_tools_suite.nr.

struct E {
    x: i64,
}

fn main() -> i32 {
    let e: E = E;
    print_int(e.x);
    0
}
