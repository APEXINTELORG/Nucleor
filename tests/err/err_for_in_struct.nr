// EXPECT: error[TYP-011] `for <var> in <Point>` is not supported — struct
// v0.4.163: extends the v0.4.152 TYP-011 family. `for v in <struct value>`
// was silently accepted and the kind-49 (for-collection) codegen called
// `vec_len` / `vec_get` on the struct's storage. With homogeneous fields
// it printed plausible-looking field values; with heterogeneous fields it
// type-punned bit patterns (e.g. an `f64 = 3.14` field surfaced as the
// integer 4614253070214989087, the IEEE-754 bit pattern); with `Vec<T>` /
// `String` / `&T` fields it leaked heap pointers as integers. None of those
// surfaced a diagnostic. Same hazard class as v0.4.152 — non-iterable in
// the iterand position. Closes findings/inbox/2026-04-30-for-on-struct-*.
// s1-only.

struct Point { x: i32, y: i32 }

fn main() -> i32 {
    let p: Point = Point { x: 1, y: 2 };
    for v in p {
        print_int(v);
    }
    0
}
