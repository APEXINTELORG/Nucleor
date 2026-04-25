// T3.35 (v0.3.60) — regression test for the trait-method-
// result-in-binop codegen bug fixed in v0.3.60.
//
// Pre-v0.3.60: `r1.area() + r2.area()` where `area` is a
// trait method returning f64 returned -0.0 instead of the
// sum. Same bug class as v0.3.54 — type-info loss when
// binop_float_type encounters an AST kind that isn't in
// its enumeration. Trait methods are kind 8 (`obj.method(args)`);
// regular fn calls are kind 7. v0.3.54 fixed kind 7;
// v0.3.60 adds kind 8.
//
// The fix has two parts:
//   1. Pass-1.5 (collect_impls) now also pushes the mangled
//      trait method into fn_decls so populate_fn_returns_in_sym
//      seeds an `__fnret_<TYPE>__<METHOD>` entry.
//   2. binop_float_type's new kind==8 branch resolves the
//      receiver type via expr_struct_type, constructs the
//      mangled name, and looks up __fnret_.
//
// This is production-relevant — traits are core Nucleor
// surface and `r.area() + r.perimeter()` style inline
// composition is the natural way to use them.
//
// Verify gate (T3.35) asserts trait method results compose
// correctly in inline binops.

trait Shape {
    fn area(self) -> f64;
}

struct Rect {
    w: f64,
    h: f64,
}

impl Shape for Rect {
    fn area(self) -> f64 {
        self.w * self.h
    }
}

fn main() -> i32 {
    let r1: Rect = Rect { w: 3.0, h: 4.0 };  // area = 12
    let r2: Rect = Rect { w: 2.0, h: 5.0 };  // area = 10
    // Inline binop on two trait method results.
    let total: f64 = r1.area() + r2.area();
    print_f64(total);   // 22.0

    // Trait method result × literal.
    let scaled: f64 = r1.area() * 2.0;
    print_f64(scaled);  // 24.0

    // Trait method result × trait method result.
    let prod: f64 = r1.area() * r2.area();
    print_f64(prod);    // 120.0
    0
}
