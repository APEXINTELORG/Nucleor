// rods/mps — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/mps.nr"

fn main() -> i64 {
    let h: i64 = mps_init(2, 4);
    if h == 0 { print("FAIL mps_init"); return 1; };
    mps_free(h);
    print("OK mps_smoke");
    return 0;
}
