// v0.7.66 consolidated negative fixture — RFC 2795 format-arg halt
// family. Replaces 3 single-form fixtures (v0741 inline, v0742
// positional, v0743 named) with one file.
//
// All three halts fire in `expand_format_macros` at the format-string
// scan, distinguished by the spec-shape inside the braces:
//   {name}        v0.7.41 — alpha-prefix → inline-arg halt
//   {0} / {N}     v0.7.42 — digit-only   → positional-arg halt
//   {} ... x = v  v0.7.43 — `=` in args  → named-arg halt
//
// To validate a different form, swap the body line.
fn main() -> i64 {
    // v0.7.41 inline-arg form (alpha-prefix in spec)
    let n: i64 = 42;
    let s: str = format!("{n}");
    print(s);
    return 0;
}
