// repro_v76_not_on_int.nr — v0.4.76 TYP-002 extension.
// Pre-fix `let r: bool = !x;` for `x: i64` typed-checked as ok
// (kind 6 just returned inner type "i64", and types_compatible(
// "bool", "i64") returns 1 — i64-truthiness convention). The
// lower emitted i64_xor with 1 against the i64 value, producing
// "no" for any non-zero x rather than a type error. Adopters
// writing canonical Rust got E0600.
//
// v0.4.76 catches `!` on non-bool at type-check time. `!` in Rust
// is bitwise on integers (returns same type), never bool — and
// Nucleor's i64-truthiness convention does NOT extend to `!`
// since the desired meaning is unambiguously `x == 0`.
//
// EXPECT: build fails with TYP-002 (msg contains "unary `!`").

fn main() -> i64 {
    let x: i64 = 5;
    let r: bool = !x;
    if r { println!("yes"); } else { println!("no"); };
    return 0;
}
