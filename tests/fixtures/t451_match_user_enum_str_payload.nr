// t451_match_user_enum_str_payload.nr -- v0.3.185 regression
// fixture.
//
// Generalizes v0.3.184 (Result::Err only) to ALL user-defined
// enum variants. Pre-v0.3.185, `enum Msg { Text(str), Num(i64) }`
// match arm `Msg::Text(s) => print(s)` defaulted s's type to i64
// (per v0.3.176) and printed the str pointer as int.
//
// v0.3.184 special-cased Result::Err -> "str" but didn't help
// user-defined enums.
//
// Same hazard class as the v0.3.181/182 vec_get/hashmap_get str
// fixes -- the i64 default was too aggressive.
//
// Fix (v0.3.185):
//   1. enum_populate_sym now stores the first payload's type per
//      variant as __epayload0_<ename>_<vname>. The ptypes list
//      stores type strings directly (per parse_enum_decl), so
//      list_get returns the string with no node_field unwrap.
//   2. New match_bind_payload_type_lookup(sym, ename, vname)
--      consults the stored payload type first; falls back to the
--      v0.3.184 Result::Err -> str special case; then i64 default.
--   3. Match arm dispatch uses the lookup helper.

enum Msg {
    Empty,
    Text(str),
    Num(i64),
}

fn main() -> i64 {
    let m: Msg = Msg::Text("hello");
    match m {
        Msg::Empty => print(0),
        Msg::Text(s) => print(s),     // pre-fix pointer, post-fix "hello"
        Msg::Num(n) => print(n),
    }
    let m2: Msg = Msg::Num(99);
    match m2 {
        Msg::Empty => print(0),
        Msg::Text(s) => print(s),
        Msg::Num(n) => print(n),       // i64 still works
    }
    return 42;
}
