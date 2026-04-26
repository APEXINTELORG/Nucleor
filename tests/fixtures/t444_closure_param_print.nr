// t444_closure_param_print.nr -- v0.3.177 regression fixture.
//
// Pre-v0.3.177, closure parameters were never registered with
// __type_<name> in clo_sym. So `print(n)` inside the closure
// body fell through the kind-3 (var ref) print() dispatch to
// print_str, which dereferenced the i64 param value as a string
// pointer -- SIGSEGV.
//
// Same hazard class as v0.3.175 (for-loop var) and v0.3.176
// (match arm binding) -- closure params were the third missing
// site in the var-type-registration sweep.
//
// Fix (v0.3.177): in the closure-lowering param loop, after
// sym_set(clo_sym, cpname, car), also set
// sym_set(clo_sym, "__type_<cpname>", "i64"). Default i64
// matches Nucleor's i64-everywhere ABI. The closure param_list
// stores only names (not parsed types), so type inference for
// non-i64 closure params is deferred.

fn apply(f: fn(i64), x: i64) { f(x); }

fn main() -> i64 {
    apply(|n: i64| { print(n); }, 42);     // pre-fix SIGSEGV
    apply(|m: i64| { print(m + 1); }, 99);
    return 42;
}
