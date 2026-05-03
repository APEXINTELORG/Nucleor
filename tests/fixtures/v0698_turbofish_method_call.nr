// v0.6.98 RFC V1.7-ext: turbofish syntax `.method::<TypeArgs>(args)`
// (e.g. `.collect::<Vec<i64>>()`). Pre-fix surfaced as wrong-class
// `NR020: parse_primary cannot start expression at token kind 46`
// because parse_postfix had no `::<` branch. Now: skip the
// balanced `<...>` type-args (advisory under today's mangling)
// and parse the trailing `(args)` as a regular method call.
fn main() -> i32 {
    let v: Vec<i64> = [1, 2, 3];
    let doubled: Vec<i64> = v.iter().map(|x| x * 2).collect::<Vec<i64>>();
    print_int(vec_len(&doubled) as i32);
    return 0;
}
