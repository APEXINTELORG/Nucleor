// v0.6.89 V1.4 ext: derive(PartialEq) on generic structs.
// Pre-fix v0.6.84 SKIPPED generic structs (the textual pre-pass
// bailed on `<...>` after the struct name) — adopters writing
// `#[derive(PartialEq)] struct Pair<T>` got the DERIVE-001
// warning with no helper. Now the textual pass captures the
// generic params verbatim and re-emits them on the helper fn
// signature, producing `fn Pair__derived_eq<T>(a: Pair<T>, b: Pair<T>)
// -> i64`. Auto-dispatch's lookup at the binop site uses
// type_base_name for the helper-name lookup so all instantiations
// (Pair<i64>, Pair<str>, ...) dispatch to the single generic helper.
#[derive(PartialEq)]
struct Pair<T> { x: T, y: T }

fn main() -> i32 {
    let a: Pair<i64> = Pair { x: 5, y: 7 };
    let b: Pair<i64> = Pair { x: 5, y: 7 };
    let c: Pair<i64> = Pair { x: 5, y: 8 };
    if a == b { print_int(11); } else { print_int(0); };
    if a == c { print_int(0); } else { print_int(22); };
    if a != c { print_int(33); } else { print_int(0); };
    return 0;
}
