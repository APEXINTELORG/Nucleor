// t443_match_arm_payload_print.nr -- v0.3.176 regression fixture.
//
// Pre-v0.3.176, match arm pattern bindings (the variable bound by
// matching an enum variant payload, e.g. `Some(v)`) were never
// registered with __type_<name> in the sym table. So
// `match x { Some(v) => print(v), ... }` SIGSEGV'd because the
// kind-3 (var ref) print() dispatch fell through to print_str and
// dereferenced the payload as a string pointer.
//
// Same hazard class as v0.3.175 for-loop variable fix.
//
// Fix (v0.3.176): two sites updated:
//   1. match_bind_payloads helper (used by enum variant arms,
//      e.g. Some(v), Variant(a, b, c)): set __type_<name> to "i64"
//      after each payload binding.
//   2. The 6 sym_set(arm_sym, binding, bar) sites (used by __wild,
//      __int, __str pattern bindings): same i64 default.
//
// All bindings default to i64 (Nucleor's i64-everywhere ABI for
// enum payloads and primitive match captures).

fn main() -> i64 {
    let some_v: Option<i64> = Some(42);
    match some_v {
        Some(v) => print(v),     // pre-fix SIGSEGV
        None => print(0),
    }
    let none_v: Option<i64> = None;
    match none_v {
        Some(v) => print(v),
        None => print(99),
    }
    return 42;
}
