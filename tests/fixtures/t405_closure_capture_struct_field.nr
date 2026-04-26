// t405_closure_capture_struct_field.nr — v0.3.129 regression fixture.
//
// Pins struct-field access on captured variables inside closures.
// Pre-v0.3.129, the closure setup populated `clo_sym` with the
// captured variable's slot but NOT its `__type_<name>` entry, so
// `expr_struct_type` failed when the closure body did `cfg.factor`
// — the field-access lowering returned register -1 and clang link
// failed with `use of undefined value '%r.-1'`.
//
// Adopters reaching for the canonical "closure captures a config
// struct" pattern (very common in builder/dependency-injection
// code, event handlers, partial-application wrappers) hit this
// on first use.
//
// Fix: in lower_expr kind-42 (closure literal), after pushing each
// captured slot to clo_sym, also propagate `__type_<capname>` and
// `__fulltype_<capname>` from the parent sym. expr_struct_type
// can then resolve the captured struct's type and find the field.
//
// Returns 40 = 5 * 8, proving cfg.factor (5) is read from the
// captured struct and used in arithmetic with the closure's param.

struct Cfg { factor: i64 }

fn main() -> i64 {
    let cfg: Cfg = Cfg { factor: 5 };
    let f = |x: i64| -> i64 { return x * cfg.factor; };
    return f(8);
}
