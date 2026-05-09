// EXPECT: LEX-NUM-SUFFIX unknown integer-literal suffix
// Lane 4 audit close: F-023 (High, malformed int suffix `1i9`).
// Pre-fix the suffix consumer rewound on miss and re-lexed `i9` as
// a fresh ident — silently dropping the user's typed-literal intent.
fn main() -> i32 { let x: i64 = 1i9; return 0; }
