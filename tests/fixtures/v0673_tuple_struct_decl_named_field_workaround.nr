// v0.6.73 RFC V1.1 step 1: tuple-struct decl `struct P(T1, T2);` now
// parses, synthesizing field names `__0`, `__1`. Construction +
// `.0`/`.1` access wire in subsequent ships; for now use named-field
// syntax with synthetic names.
struct Pair(i64, i64);
struct Triple(str, i64, i64);

fn main() -> i32 {
    let p: Pair = Pair { __0: 5, __1: 10 };
    print_int(p.__0 as i32);
    print_int(p.__1 as i32);
    let t: Triple = Triple { __0: "label", __1: 42, __2: 99 };
    print(t.__0);
    print_int(t.__1 as i32);
    print_int(t.__2 as i32);
    return 0;
}
