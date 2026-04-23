// rods/thread — verify rod wrapper compiles + links (v0.2.150 wrap)
import "stdlib/rods/thread.nr"

fn main() -> i64 {
    let p: i64 = thread_pool_new(2);
    if p == 0 { print("FAIL thread_pool_new"); return 1; };
    thread_pool_free(p);
    print("OK thread_smoke");
    return 0;
}
