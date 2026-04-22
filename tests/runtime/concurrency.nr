// concurrency.nr — mutex + thread spawn/join
import "stdlib/rods/concurrency.nr"

fn worker(x: i64) -> i64 {
    return x + 1;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    let m: i64 = conc_mutex();
    conc_lock(m);
    conc_unlock(m);
    let h: i64 = conc_spawn(|x| { return x * 2; }, 21);
    conc_join(h);
    if fail == 0 { print("OK concurrency"); return 0; };
    return 1;
}
