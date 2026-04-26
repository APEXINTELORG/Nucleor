// t432_print_binop_dispatch.nr -- v0.3.165 regression fixture.
//
// Pre-v0.3.165, the print() type-aware dispatch handled AST kinds
// 1 (int lit), 71/72 (f64 lit), 3 (var ref), 7 (fn call), 9
// (struct field), and 10 (index). Binop results (kind 4) fell
// through to the default __nucleor_print_str. For typed arithmetic
// (i64+i64, f64*f64, comparisons), `print(a + b)` treated the
// numeric/bool result as a pointer -- SIGSEGV when the helper
// dereferenced.
//
// `print(a + b)` where a, b: i64 SIGSEGV'd. Same hazard class as
// the v0.3.143 print(int) fix and the v0.3.163-164 incremental
// extensions. Adopter writes the canonical arithmetic-print
// pattern, gets a crash with no diagnostic.
//
// Fix (v0.3.165): in the print() dispatch, when arg kind is 4
// (binop), select the helper by op code:
//   - 30/31/32/33/34/35/36/37 (== != < > <= >= && ||) -> bool
//   - binop_float_type returns f32/f64 -> f64
//   - else -> i64 (arith on ints + bitwise)
// The default-to-i64 is sound because Nucleor binops only produce
// i64, f32/f64, or bool (no operator overloading; str + str not
// supported; bool arith is TYP-002).

fn main() -> i64 {
    let a: i64 = 7;
    let b: i64 = 8;
    // Pre-fix all three SIGSEGV'd. Post-fix print 15, 1, 0.
    print(a + b);     // i64 arith -- pre-fix SIGSEGV
    print(a < b);     // bool cmp -- pre-fix SIGSEGV
    print(a > b);     // bool cmp -- pre-fix SIGSEGV
    let x: f64 = 1.5;
    let y: f64 = 2.5;
    print(x + y);     // f64 arith -- pre-fix SIGSEGV
    return 42;
}
