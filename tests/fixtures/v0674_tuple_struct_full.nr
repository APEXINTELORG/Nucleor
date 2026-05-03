// v0.6.74 RFC V1.1 steps 2 + 3: full tuple-struct support shipped.
// Constructor `P(a, b)` + positional access `p.0`/`p.1`.
struct Pair(i64, i64);
struct Triple(str, i64, i64);

fn main() -> i32 {
    let p: Pair = Pair(5, 10);
    print_int(p.0 as i32);
    print_int(p.1 as i32);
    let t: Triple = Triple("hello", 42, 99);
    print(t.0);
    print_int(t.1 as i32);
    print_int(t.2 as i32);
    return 0;
}
