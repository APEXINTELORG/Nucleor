// Lane 3 (F-CONC-016): channel contention smoke test.
//
// 4 producers × 4 consumers × 10000 messages each.
// Each producer pushes 10000 distinct ints; each consumer pulls 10000.
// Total send count = total recv count = 40000.

import "stdlib/rods/concurrency.nr"

fn producer(arg: i64) -> i64 {
    // arg is the channel handle.
    let ch: i64 = arg;
    let mut i: i64 = 0;
    while i < 10000 {
        conc_send(ch, i + 1);
        i = i + 1;
    };
    return 0;
}

fn consumer(arg: i64) -> i64 {
    // arg packs ch (high 32) and counter (low 32).
    let ch: i64 = arg / 4294967296;
    let ctr: i64 = arg - ((arg / 4294967296) * 4294967296);
    let mut i: i64 = 0;
    while i < 10000 {
        let _v: i64 = conc_recv(ch);
        conc_atomic_inc(ctr);
        i = i + 1;
    };
    return 0;
}

fn main() -> i64 {
    // Capacity 64: forces real producer-consumer interleaving (not just
    // a queued buffer drain).
    let ch: i64 = conc_channel(64);
    let ctr: i64 = conc_atomic(0);
    let carg: i64 = (ch * 4294967296) + ctr;
    let p0: i64 = conc_spawn(producer, ch);
    let p1: i64 = conc_spawn(producer, ch);
    let p2: i64 = conc_spawn(producer, ch);
    let p3: i64 = conc_spawn(producer, ch);
    let c0: i64 = conc_spawn(consumer, carg);
    let c1: i64 = conc_spawn(consumer, carg);
    let c2: i64 = conc_spawn(consumer, carg);
    let c3: i64 = conc_spawn(consumer, carg);
    conc_join(p0);
    conc_join(p1);
    conc_join(p2);
    conc_join(p3);
    conc_join(c0);
    conc_join(c1);
    conc_join(c2);
    conc_join(c3);
    let total: i64 = conc_atomic_get(ctr);
    if total != 40000 {
        return 1;
    };
    print("OK lane3_channel_contention");
    return 0;
}
