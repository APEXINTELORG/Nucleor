// rods/embedding — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/embedding.nr"

fn main() -> i64 {
    let eh: i64 = emb_new(10, 4);
    if eh == 0 { print("FAIL emb_new"); return 1; };
    print("OK embedding_smoke");
    return 0;
}
