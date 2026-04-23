// rods/comm — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/comm.nr"

fn main() -> i64 {
    let wh: i64 = comm_init(4, 1024);
    if wh == 0 { print("FAIL comm_init"); return 1; };
    print("OK comm_smoke");
    return 0;
}
