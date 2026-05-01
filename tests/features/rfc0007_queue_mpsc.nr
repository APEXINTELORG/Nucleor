// RFC-0007 Track H: MPSC queue structural and concurrent producer test.
import "stdlib/rods/mpsc_queue.nr"

struct MpscShared {
    queue: MpscQueue<i64>,
    ticket: AtomicI64,
    per_producer: i64,
}

fn mpsc_worker(shared: &MpscShared) -> i64 {
    let mut i: i64 = 0;
    while i < shared.per_producer {
        let v: i64 = atomic_fetch_add(&shared.ticket, 1, MemOrder::SeqCst);
        let mut done: bool = false;
        while !done {
            done = mpsc_push_shared(&shared.queue, v);
        };
        i = i + 1;
    };
    return 0;
}

fn main() -> i32 {
    let producers: i64 = 4;
    let per: i64 = 256;
    let total: i64 = producers * per;
    let shared: MpscShared = MpscShared {
        queue: mpsc_new(total + 8),
        ticket: atomic_i64(0),
        per_producer: per,
    };

    let h1: i64 = thread_spawn(mpsc_worker, &shared);
    let h2: i64 = thread_spawn(mpsc_worker, &shared);
    let h3: i64 = thread_spawn(mpsc_worker, &shared);
    let h4: i64 = thread_spawn(mpsc_worker, &shared);
    thread_join(h1);
    thread_join(h2);
    thread_join(h3);
    thread_join(h4);

    if mpsc_len(&shared.queue) != total { print("FAIL mpsc len after producers\n"); return 1; };

    let mut seen: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < total {
        seen.push(0);
        i = i + 1;
    };

    let mut count: i64 = 0;
    let mut fail: i64 = 0;
    while count < total {
        let got: Option<i64> = mpsc_pop_shared(&shared.queue);
        match got {
            Some(v) => {
                if v < 0 || v >= total {
                    fail = fail + 1;
                    print("FAIL mpsc out of range\n");
                } else {
                    if seen.get(v) != 0 {
                        fail = fail + 1;
                        print("FAIL mpsc duplicate\n");
                    };
                    seen.set(v, 1);
                };
            },
            None => {
                fail = fail + 1;
                print("FAIL mpsc unexpected empty\n");
            },
        };
        count = count + 1;
    };

    i = 0;
    while i < total {
        if seen.get(i) != 1 { fail = fail + 1; print("FAIL mpsc missing value\n"); };
        i = i + 1;
    };
    match mpsc_pop_shared(&shared.queue) {
        Some(_) => { fail = fail + 1; print("FAIL mpsc expected empty\n"); },
        None => { },
    };
    if fail != 0 { return 1; };
    print("OK rfc0007_queue_mpsc\n");
    return 0;
}
