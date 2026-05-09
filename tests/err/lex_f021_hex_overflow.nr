// EXPECT: NUM-021 hex literal exceeds u64::MAX
// Lane 4 audit close: F-021 (Critical, silent miscompile).
// Pre-fix `0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF` silently wrapped via the
// wrapping_mul/add accumulator, producing a meaningless bit pattern.
// Mirrors the existing decimal NUM-021 check.
fn main() -> i32 { let x: i64 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF; return 0; }
