// EXPECT: LEX-NUM-FLOAT-OVERFLOW non-finite float literal
// Lane 4 audit close: F-028 (Critical, silent miscompile).
// Pre-fix `1e400` strtod-parsed to +Inf and the bit pattern was
// stored silently. Adopters got Inf/NaN propagating through their
// numeric pipeline with no diagnostic.
fn main() -> i32 { let x: f64 = 1e400; return 0; }
