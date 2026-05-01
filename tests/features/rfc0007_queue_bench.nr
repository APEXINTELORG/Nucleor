// RFC-0007 Track H: queue benchmark smoke.
// Compares SPSC and MPSC queue loops against an existing mutex+queue baseline.
import "stdlib/rods/spsc_queue.nr"
import "stdlib/rods/mpsc_queue.nr"
import "stdlib/rods/queue.nr"
import "stdlib/rods/time_typed.nr"

struct MpscBenchShared {
    queue: MpscQueue<i64>,
    ticket: AtomicI64,
    per_producer: i64,
}

struct MutexBenchShared {
    queue: Vec<i32>,
    mutex: i64,
    ticket: AtomicI64,
    per_producer: i64,
}

fn mpsc_bench_worker(shared: &MpscBenchShared) -> i64 {
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

fn mutex_bench_worker(shared: &MutexBenchShared) -> i64 {
    let mut i: i64 = 0;
    while i < shared.per_producer {
        let v: i64 = atomic_fetch_add(&shared.ticket, 1, MemOrder::SeqCst);
        mutex_lock(shared.mutex);
        queue_push(shared.queue, v);
        mutex_unlock(shared.mutex);
        i = i + 1;
    };
    return 0;
}

fn bench_spsc(n: i64) -> i64 {
    let mut q: SpscQueue<i64> = spsc_new(n + 1);
    let start: i64 = time_mono_ns();
    let mut i: i64 = 0;
    while i < n {
        let _ = spsc_push(&mut q, i);
        i = i + 1;
    };
    i = 0;
    while i < n {
        let _ = spsc_pop(&mut q);
        i = i + 1;
    };
    return time_elapsed_ns(start);
}

fn bench_mpsc(n: i64) -> i64 {
    let mut q: MpscQueue<i64> = mpsc_new(n + 1);
    let start: i64 = time_mono_ns();
    let mut i: i64 = 0;
    while i < n {
        let _ = mpsc_push(&mut q, i);
        i = i + 1;
    };
    i = 0;
    while i < n {
        let _ = mpsc_pop(&mut q);
        i = i + 1;
    };
    return time_elapsed_ns(start);
}

fn bench_mpsc_contended(per: i64) -> i64 {
    let total: i64 = per * 4;
    let shared: MpscBenchShared = MpscBenchShared {
        queue: mpsc_new(total + 8),
        ticket: atomic_i64(0),
        per_producer: per,
    };
    let start: i64 = time_mono_ns();
    let h1: i64 = thread_spawn(mpsc_bench_worker, &shared);
    let h2: i64 = thread_spawn(mpsc_bench_worker, &shared);
    let h3: i64 = thread_spawn(mpsc_bench_worker, &shared);
    let h4: i64 = thread_spawn(mpsc_bench_worker, &shared);
    thread_join(h1);
    thread_join(h2);
    thread_join(h3);
    thread_join(h4);
    let mut i: i64 = 0;
    while i < total {
        let _ = mpsc_pop_shared(&shared.queue);
        i = i + 1;
    };
    return time_elapsed_ns(start);
}

fn bench_mutex_queue(n: i64) -> i64 {
    let q: Vec<i32> = queue_new();
    let m: i64 = mutex_new();
    let start: i64 = time_mono_ns();
    let mut i: i64 = 0;
    while i < n {
        mutex_lock(m);
        queue_push(q, i);
        mutex_unlock(m);
        i = i + 1;
    };
    i = 0;
    while i < n {
        mutex_lock(m);
        let _ = queue_pop(q);
        mutex_unlock(m);
        i = i + 1;
    };
    return time_elapsed_ns(start);
}

fn bench_mutex_queue_contended(per: i64) -> i64 {
    let total: i64 = per * 4;
    let shared: MutexBenchShared = MutexBenchShared {
        queue: queue_new(),
        mutex: mutex_new(),
        ticket: atomic_i64(0),
        per_producer: per,
    };
    let start: i64 = time_mono_ns();
    let h1: i64 = thread_spawn(mutex_bench_worker, &shared);
    let h2: i64 = thread_spawn(mutex_bench_worker, &shared);
    let h3: i64 = thread_spawn(mutex_bench_worker, &shared);
    let h4: i64 = thread_spawn(mutex_bench_worker, &shared);
    thread_join(h1);
    thread_join(h2);
    thread_join(h3);
    thread_join(h4);
    let mut i: i64 = 0;
    while i < total {
        mutex_lock(shared.mutex);
        let _ = queue_pop(shared.queue);
        mutex_unlock(shared.mutex);
        i = i + 1;
    };
    return time_elapsed_ns(start);
}

fn main() -> i32 {
    let n: i64 = 20000;
    let ops: i64 = n * 2;
    let spsc_ns: i64 = bench_spsc(n);
    let mpsc_ns: i64 = bench_mpsc(n);
    let mutex_ns: i64 = bench_mutex_queue(n);
    let per: i64 = 2000;
    let contended_ops: i64 = per * 4 * 2;
    let mpsc_contended_ns: i64 = bench_mpsc_contended(per);
    let mutex_contended_ns: i64 = bench_mutex_queue_contended(per);
    if spsc_ns <= 0 || mpsc_ns <= 0 || mutex_ns <= 0 || mpsc_contended_ns <= 0 || mutex_contended_ns <= 0 {
        print("FAIL queue bench clock\n");
        return 1;
    };
    print("OK rfc0007_queue_bench\n");
    println!("spsc: {} ns for {} ops", spsc_ns, ops);
    println!("mpsc: {} ns for {} ops", mpsc_ns, ops);
    println!("mutex_queue: {} ns for {} ops", mutex_ns, ops);
    println!("mpsc_4prod: {} ns for {} ops", mpsc_contended_ns, contended_ops);
    println!("mutex_queue_4prod: {} ns for {} ops", mutex_contended_ns, contended_ops);
    return 0;
}
