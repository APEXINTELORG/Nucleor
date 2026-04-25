// T3.41 (v0.3.66) — regression test for method calls on
// indexed struct field receivers (`p.rects[0].area()`).
//
// Pre-v0.3.66: `p.rects[0].area()` failed compilation with
// `error: use of undefined value '@vec_area'`. Same bug
// class as v0.3.65 but in `expr_struct_type` instead of
// `binop_float_type`. The kind==10 branch in expr_struct_type
// only handled direct variable indexing (`v[i]`); when the
// indexed expression was a struct field (`p.rects[i]`),
// type info was lost and the dispatcher generated a wrong
// mangled method name (`Vec__area` instead of `R__area`).
//
// v0.3.66 mirrors v0.3.65's struct-field-operand fix into
// expr_struct_type's kind==10 branch.
//
// Production-relevant: pools of shapes, particle batches,
// any struct with a `Vec<T>` field whose elements need
// trait-dispatched processing in inline form.
//
// Verify gate (T3.41) asserts the indexed-method call
// compiles AND produces correct values.

trait Sized { fn area(self) -> f64; }

#[repr(C)]
struct R { w: f64, h: f64 }

impl Sized for R {
    fn area(self) -> f64 { self.w * self.h }
}

#[repr(C)]
struct Pool { rects: Vec<R>, weight: f64 }

fn main() -> i32 {
    let mut shapes: Vec<R> = Vec::new();
    shapes.push(R { w: 3.0, h: 4.0 });   // area 12
    shapes.push(R { w: 2.0, h: 5.0 });   // area 10
    let p: Pool = Pool { rects: shapes, weight: 0.5 };

    // Method on indexed struct field, * scalar field of parent struct.
    let r1: f64 = p.rects[0].area() * p.weight;
    print_f64(r1);   // 6.0

    // Composition: two indexed-field method results in inline binop.
    let r2: f64 = p.rects[0].area() + p.rects[1].area();
    print_f64(r2);   // 22.0
    0
}
