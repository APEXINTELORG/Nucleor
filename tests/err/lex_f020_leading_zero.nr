// EXPECT: LEX-NUM-005 leading-zero decimal literal
// Lane 4 audit close: F-020 (High, leading-zero `007` silent accept).
// Per the lane brief, when the language ref is silent we default
// stricter — reject. Adopters porting C/Java code who expect octal
// semantics get a clean error and an explicit `0o` workaround.
fn main() -> i32 { let x: i64 = 007; return 0; }
