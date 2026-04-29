// repro_v89_str_more_methods.nr — v0.4.89 dispatch extension.
// Adds 7 more str methods to the v0.4.88 receiver-type-aware
// dispatch: to_lower, to_upper, trim, trim_start, trim_end,
// substring, char_at. Pre-fix all 7 fell through to vec_<mname>
// and clang-link-failed. Runtime helpers (str_to_lower etc) all
// existed; only the dispatch was missing.
//
// EXPECT: build succeeds + each method returns correct value.

fn main() -> i64 {
    let s: str = "  Hello, World  ";
    let t: str = s.trim();
    let u: str = t.to_upper();
    let l: str = t.to_lower();
    let sub: str = u.substring(0, 5);
    let c: i64 = sub.char_at(0);
    println!("{}", t);
    println!("{}", u);
    println!("{}", l);
    println!("{}", sub);
    println!("{}", c);
    return 0;
}
