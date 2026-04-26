// t452_match_multi_payload_per_idx.nr -- v0.3.186 regression
// fixture.
//
// Removes the v0.3.185 limitation: multi-payload variants like
// `Variant(str, i64)` only got the str dispatch on the FIRST
// binding -- the rest defaulted to i64. SIGSEGV on the second
// binding when print(i64_var) was called and the dispatch
// (incorrectly given str type) treated it as a string pointer.
//
// Wait actually pre-fix the issue was reverse -- ALL bindings
// shared the SAME payload type (the first one). For
// `Mixed(str, i64)`, both s and n got "str" type, and print(n)
// (where n is i64) dispatched to print_str which dereferenced
// the i64 value as a char* -- SIGSEGV.
//
// Same hazard class as v0.3.184/185 -- match arm bindings
// dispatched by wrong type.
//
// Fix (v0.3.186):
--   1. enum_populate_sym now stores ALL payload types per
--      variant as __epayload<i>_<ename>_<vname> (instead of
--      just __epayload0_).
--   2. New match_bind_payloads_per_idx looks up each binding's
--      specific payload type by index. Per-binding __type_<name>
--      registration replaces the v0.3.185 single-type-for-all.

enum Pair {
    Mixed(str, i64),
    Triple(str, i64, str),
}

fn main() -> i64 {
    let p: Pair = Pair::Mixed("name", 42);
    match p {
        Pair::Mixed(s, n) => {
            print(s);     // pre-fix SIGSEGV on n (or wrong type for s)
            print(n);
        },
        Pair::Triple(a, b, c) => {
            print(a); print(b); print(c);
        },
    }
    let t: Pair = Pair::Triple("alpha", 7, "omega");
    match t {
        Pair::Mixed(s, n) => { print(s); print(n); },
        Pair::Triple(a, b, c) => {
            print(a);     // str
            print(b);     // i64
            print(c);     // str
        },
    }
    return 42;
}
