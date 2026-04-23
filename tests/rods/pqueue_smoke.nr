// rods/pqueue — verify rod wrapper compiles + links (v0.2.150 wrap)
import "stdlib/rods/pqueue.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;
    let h: i64 = pq_min();
    if h == 0 { print("FAIL pq_min"); return 1; };

    pq_push(h, 5, 50);
    pq_push(h, 1, 10);
    pq_push(h, 3, 30);

    if pq_size(h) != 3 { fail = fail + 1; print("FAIL size"); };
    if pq_peek_key(h) != 1 { fail = fail + 1; print("FAIL peek_key (min)"); };
    if pq_pop(h) != 10 { fail = fail + 1; print("FAIL pop value 1"); };
    if pq_pop(h) != 30 { fail = fail + 1; print("FAIL pop value 2"); };
    if pq_pop(h) != 50 { fail = fail + 1; print("FAIL pop value 3"); };
    if pq_empty(h) != 1 { fail = fail + 1; print("FAIL empty after drain"); };

    pq_free(h);

    let m: i64 = pq_max();
    pq_push(m, 5, 50);
    pq_push(m, 1, 10);
    pq_push(m, 3, 30);
    if pq_pop(m) != 50 { fail = fail + 1; print("FAIL max pop 1"); };
    if pq_pop(m) != 30 { fail = fail + 1; print("FAIL max pop 2"); };
    pq_free(m);

    if fail == 0 { print("OK pqueue_smoke"); };
    return fail;
}
