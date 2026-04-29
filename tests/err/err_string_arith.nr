// EXPECT: error[TYP-011] `String + <other>` arithmetic is not meaningful
// v0.4.150: String + scalar (or other-side) arith silently
// lowered to i64_add on the String heap pointer + scalar,
// producing a wild pointer that SIGSEGVed on next use. Sister
// to v0.4.51 (str + str), v0.4.66 (mixed str/int arith), and
// v0.4.61 (Vec arith). Two fixes: (1) kind-12 type_expr now
// returns "String" for String::new / String::with_capacity (was
// "" — the let-stmt logic stored "" in tenv even with an
// explicit annotation, breaking every downstream type check on
// `s: String`), (2) kind-4 binop check fires when either side
// has type_base_name == "String" for arith ops 20-24. Same
// kind-12 fix was extended to Vec/HashMap/HashSet/BTreeMap/
// BTreeSet/VecDeque so their constructors propagate types too.

fn main() -> i32 {
    let s: String = String::new();
    let r = s + 5;
    print_int(0);
    0
}
