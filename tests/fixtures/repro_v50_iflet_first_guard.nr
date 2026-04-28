// repro_v50_iflet_first_guard.nr
//
// v0.4.50 NUC-FEEDBACK silent-segfault guard. Pre-fix
// `if let Some(x) = v.first()` SILENTLY SEGFAULTED at runtime
// because v.first() returns a bare i64 (not Option<T>); the
// match-arm dispatcher then called vec_get on the i64 value
// treating it as an Option pointer and dereferenced garbage.
//
// v0.4.50 detects the pattern at parse time (kind-8 method call
// to first/last/pop or kind-7 fn call to vec_first/vec_last/
// vec_pop, paired with a Some/None pattern) and panics the
// compiler before clang is invoked, with a clear workaround
// hint pointing at the explicit length-branch idiom.
//
// Real fix (wrap the helpers in Option<T>) is RFC-0024 Phase 4
// territory.

fn main() -> i64 {
    let v: Vec<i64> = vec![1, 2, 3];
    if let Some(first) = v.first() {     // panic expected
        println!("{}", first);
    } else {
        println!("empty");
    };
    return 0;
}
