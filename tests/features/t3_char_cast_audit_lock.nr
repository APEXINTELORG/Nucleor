// v0.8.78 T-3 Phase 1 lock-in. Locks the v0.8.46 char-cast
// audit-pass info diagnostic. Source contains `as char` casts;
// the build emits info[T-3-CAST] counting them.
//
// Phase 2b will validate codepoint range at the cast site
// (reject 0xD800-0xDFFF surrogates and >0x10FFFF). Phase 4
// promotes to hard error per RFC T-3. Until then this fixture
// asserts the audit-pass exists so any refactor that drops
// the audit gets caught.
//
// Expected: rc=130, build emits info[T-3-CAST] with non-zero count.
// (Audit is a textual scanner; comment hits also count — locking
//  on existence-of-info-line, not exact count.)

fn main() -> i64 {
    let a: char = 65 as char;       // 'A'
    let b: char = 0x41 as char;     // 'A' via hex
    let c: char = 0x42 as char;     // 'B'
    let na: i64 = a as i64;
    let nb: i64 = b as i64;
    let _nc: i64 = c as i64;
    return na + nb;                  // 65 + 65 = 130 (fits exit code)
}
