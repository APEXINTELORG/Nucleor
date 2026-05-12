// v0.8.30 RFC-0062 G-3 Phase 2a signal fixture — exercises
// `Vec<&` patterns to ensure the ALIAS-G3 regression gate info fires
// on a build with Vec-of-references.
//
// Build emits `info[ALIAS-G3]: Vec-of-reference patterns in
// build: N` (N>=1). rc=42 (sentinel; the Vec<&str> is declared
// for the regression gate scan, never indexed at runtime).

fn collect_two_strs<'a>(a: &'a str, b: &'a str) -> Vec<&'a str> {
    let mut v: Vec<&'a str> = Vec::new();
    return v;
}

fn main() -> i64 {
    let _v: Vec<&str> = collect_two_strs("x", "y");
    return 42;
}
