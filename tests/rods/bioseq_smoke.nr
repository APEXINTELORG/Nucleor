// rods/bioseq — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/bioseq.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;
    let gc: i64 = bio_gc("ATCGATCG");
    if gc < 0 { fail = fail + 1; print("FAIL gc"); };
    let h: i64 = bio_hamming("ATCG", "ATGG");
    if h != 1 { fail = fail + 1; print("FAIL hamming"); };
    if fail == 0 { print("OK bioseq_smoke"); };
    return fail;
}
