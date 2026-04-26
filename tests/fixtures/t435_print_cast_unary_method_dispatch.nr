// t435_print_cast_unary_method_dispatch.nr -- v0.3.168 regression
// fixture.
//
// Pre-v0.3.168, the print() type-aware dispatch handled AST kinds
// 1, 71/72, 3, 7, 9, 10, 4. Several more shapes silently
// miscompiled (printed bit patterns, garbage, or SIGSEGV'd):
//   - kind 99 (cast):       `print(x as i64)`
//   - kind 5 (unary minus): `print(-n)` SIGSEGV
//   - kind 6 (unary not):   `print(!b)` SIGSEGV / "(null)"
//   - kind 8 (method call): `print(h.get())` SIGSEGV
//   - kind 8 (builtin):     `print(v.len())` SIGSEGV
//
// Same hazard class as v0.3.143/163/164/165 -- adopter writes a
// canonical pattern, gets garbage or crashes with no diagnostic.
//
// Fix (v0.3.168): five new branches in the print() dispatch.
//   - kind 99: use cast target type (node field 2).
//   - kind 5: inherit operand type via binop_float_type, default i64.
//   - kind 6: always bool.
//   - kind 8 user method: look up __fnret_<TYPE>__<METHOD>.
//   - kind 8 builtin fallback: hardcoded names (len/count/capacity
//     -> i64; is_empty/contains/contains_key -> bool).
//
// Note: `print(x as i64)` for f64 x correctly dispatches to
// print_i64 -- the value remains the f64 bit pattern only because
// the `as` cast itself is currently a no-op for f64->i64 (separate
// ABI issue, queued).

struct Holder { val: i64 }
impl Holder {
    fn get(self) -> i64 { return self.val; }
}

fn main() -> i64 {
    let n: i64 = 42;
    let b: bool = true;
    let h: Holder = Holder { val: 99 };
    let mut v: Vec<i64> = Vec::new();
    v.push(10); v.push(20); v.push(30);
    print(-n);             // unary minus: -42
    print(!b);             // unary not: false
    print(h.get());        // user method: 99
    print(v.len());        // builtin method (fallback): 3
    return 42;
}
