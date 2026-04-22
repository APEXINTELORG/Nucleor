// hash_helpers — RFC-0017 stdlib enrichment.
//
//   fnv1a_64_str(s)  -> i64  deterministic 64-bit hash of a string
//   fnv1a_64_i64(v)  -> i64  same on i64 input bytes
//   murmur3_64(v)    -> i64  fast bit-mixing finalizer (no state)
//
// Plus print/eprint without trailing newline:
//   print_raw(s)  / eprint_raw(s)

fn main() -> i64 {
    let mut fail: i64 = 0;

    let h1: i64 = fnv1a_64_str("hello");
    let h2: i64 = fnv1a_64_str("hello");
    if h1 != h2 { fail = fail + 1; print("FAIL fnv det"); };
    let h3: i64 = fnv1a_64_str("world");
    if h1 == h3 { fail = fail + 1; print("FAIL fnv collision"); };

    let i1: i64 = fnv1a_64_i64(42);
    let i2: i64 = fnv1a_64_i64(42);
    if i1 != i2 { fail = fail + 1; print("FAIL fnv_i64 det"); };
    if fnv1a_64_i64(42) == fnv1a_64_i64(43) { fail = fail + 1; print("FAIL fnv_i64 collision"); };

    let m1: i64 = murmur3_64(42);
    let m2: i64 = murmur3_64(42);
    if m1 != m2 { fail = fail + 1; print("FAIL murmur det"); };
    if murmur3_64(42) == murmur3_64(43) { fail = fail + 1; print("FAIL murmur collision"); };

    // print_raw shouldn't add a newline. We can't directly assert on
    // stdout here, but we can at least confirm the call type-checks
    // and the program completes without error.
    print_raw("");

    if fail == 0 { print("OK hash_helpers"); return 0; };
    return 1;
}
