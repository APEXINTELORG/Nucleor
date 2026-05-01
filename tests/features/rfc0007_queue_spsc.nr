// RFC-0007 Track H: SPSC queue round-trip and order preservation.
import "stdlib/rods/spsc_queue.nr"

fn main() -> i32 {
    let mut q: SpscQueue<i64> = spsc_new(128);
    let mut fail: i64 = 0;
    let n: i64 = 64;
    let mut i: i64 = 0;
    while i < n {
        if !spsc_push(&mut q, i * 3) { fail = fail + 1; };
        i = i + 1;
    };
    if spsc_len(&q) != n { fail = fail + 1; print("FAIL spsc len after push\n"); };
    if spsc_capacity(&q) != 128 { fail = fail + 1; print("FAIL spsc capacity\n"); };

    i = 0;
    while i < n {
        let got: Option<i64> = spsc_pop(&mut q);
        match got {
            Some(v) => { if v != i * 3 { fail = fail + 1; print("FAIL spsc order\n"); }; },
            None => { fail = fail + 1; print("FAIL spsc unexpected empty\n"); },
        };
        i = i + 1;
    };
    match spsc_pop(&mut q) {
        Some(_) => { fail = fail + 1; print("FAIL spsc expected empty\n"); },
        None => { },
    };
    if spsc_len(&q) != 0 { fail = fail + 1; print("FAIL spsc final len\n"); };
    if fail != 0 { return 1; };
    print("OK rfc0007_queue_spsc\n");
    return 0;
}
