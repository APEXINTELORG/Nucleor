// RFC-0007 Track H: bounded capacity exhaustion behavior.
import "stdlib/rods/spsc_queue.nr"
import "stdlib/rods/mpsc_queue.nr"

fn main() -> i32 {
    let mut fail: i64 = 0;
    let mut s: SpscQueue<i64> = spsc_new(2);
    if !spsc_push(&mut s, 10) { fail = fail + 1; };
    if !spsc_push(&mut s, 20) { fail = fail + 1; };
    if spsc_push(&mut s, 30) { fail = fail + 1; print("FAIL spsc accepted full push\n"); };
    match spsc_pop(&mut s) {
        Some(v) => { if v != 10 { fail = fail + 1; }; },
        None => { fail = fail + 1; },
    };
    if !spsc_push(&mut s, 30) { fail = fail + 1; print("FAIL spsc did not reuse slot\n"); };

    let mut m: MpscQueue<i64> = mpsc_new(2);
    if !mpsc_push(&mut m, 1) { fail = fail + 1; };
    if !mpsc_push(&mut m, 2) { fail = fail + 1; };
    if mpsc_push(&mut m, 3) { fail = fail + 1; print("FAIL mpsc accepted full push\n"); };
    match mpsc_pop(&mut m) {
        Some(v2) => { if v2 != 1 { fail = fail + 1; }; },
        None => { fail = fail + 1; },
    };
    if !mpsc_push(&mut m, 3) { fail = fail + 1; print("FAIL mpsc did not reuse slot\n"); };
    if fail != 0 { return 1; };
    print("OK rfc0007_queue_capacity\n");
    return 0;
}
