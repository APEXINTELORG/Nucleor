// EXPECT: error[MATCH-011] string literal arm in `match` on integer scrutinee
// v0.4.140: heterogeneous match arm literal types — `match n: i64
// { 1 => ..., "a" => ..., _ => ... }` SIGSEGV'd at runtime when
// the scrutinee didn't match an earlier int arm. The str-literal
// arm lowered to `str_eq(<scrut_i64>, "a")` which dereferences
// the scrutinee value as a char ptr — for n=2 that reads memory
// at address 0x2 and crashes. Symmetric hazard for `match s: str
// { 1 => ... }` (silent miscompare). Catch both at type-check.
// MATCH-011 (MATCH-002 already used for unreachable-after-wild,
// MATCH-010 for @-binding name collision).

fn main() -> i32 {
    let n: i64 = 2;
    let r: i64 = match n { 1 => 100, "a" => 200, _ => 300 };
    print_int(r);
    0
}
