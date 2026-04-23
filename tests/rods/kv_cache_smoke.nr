// rods/kv_cache — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/kv_cache.nr"

fn main() -> i64 {
    let ch: i64 = kv_new(1, 1, 4, 8);
    if ch == 0 { print("FAIL kv_new"); return 1; };
    print("OK kv_cache_smoke");
    return 0;
}
