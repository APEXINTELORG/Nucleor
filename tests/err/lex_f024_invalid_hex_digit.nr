// EXPECT: LEX-NUM-003 hex literal `0x` has no hex digits
// Lane 4 audit close: F-024 (High, `0xZ` invalid hex digit silent
// consume). Pre-fix `0x` consumed (no digits) and `Z` lexed as a
// separate ident. Now: F-016 fix catches the no-digit `0x` first,
// closing this finding too.
fn main() -> i32 { let x: i64 = 0xZ; return 0; }
