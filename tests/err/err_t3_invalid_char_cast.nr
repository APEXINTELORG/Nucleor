// EXPECT: error[TYP-026]
// T-3 Phase 2b narrow guard: const-foldable `as char` casts must not
// accept Unicode-invalid codepoints. Runtime/IR char distinctness stays
// queued; this locks the build-path scalar-value check.

fn main() -> i64 {
    let c: char = 0x110000 as char;
    if c as i64 == 0 { return 1; };
    return 0;
}
