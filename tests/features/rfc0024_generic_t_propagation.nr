// RFC-0024 generic-T propagation through call-site rtype inference (v0.5.13).
//
// Probe-agent finding 2026-05-01-generic-T-propagation-spsc-option-str:
// pre-fix `let r1 = spsc_pop(&mut q)` where `q: SpscQueue<str>`
// returned `Option<T>` with T unsubstituted, so the match-arm
// binding `s` from `Some(s)` typed as i64 (the i64-everywhere-ABI
// default for unknown types). `print(s)` then halted with TYP-006
// because s wasn't typed as str.
//
// v0.5.13 substitutes gparam bindings extracted from arg types
// into the rtype before returning, so the inferred-let binding
// gets the concrete `Option<str>` type and the match-arm Some(s)
// types s as str.
//
// EXPECT: build success, runtime exit 0, prints "hello", "world"
// (one per pop), then "OK rfc0024_generic_t_propagation".

import "stdlib/rods/spsc_queue.nr"

fn main() -> i32 {
    let mut q: SpscQueue<str> = spsc_new::<str>(2);
    spsc_push(&mut q, "hello");
    spsc_push(&mut q, "world");

    // First pop. r1 is INFERRED — pre-fix this dropped T=str.
    let r1 = spsc_pop(&mut q);
    match r1 {
        Some(s) => print(s),
        None => { print("FAIL no first item"); return 1; },
    };

    // Second pop, also inferred.
    let r2 = spsc_pop(&mut q);
    match r2 {
        Some(s) => print(s),
        None => { print("FAIL no second item"); return 1; },
    };

    // Empty queue → None on the inferred rtype.
    let r3 = spsc_pop(&mut q);
    match r3 {
        Some(_) => { print("FAIL queue should be empty"); return 1; },
        None => print("OK rfc0024_generic_t_propagation"),
    };

    0
}
