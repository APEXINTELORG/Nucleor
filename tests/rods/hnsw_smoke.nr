// rods/hnsw — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/hnsw.nr"

fn main() -> i64 {
    let idx: i64 = hnsw_new(4, 8, 16);
    if idx == 0 { print("FAIL hnsw_new"); return 1; };
    print("OK hnsw_smoke");
    return 0;
}
