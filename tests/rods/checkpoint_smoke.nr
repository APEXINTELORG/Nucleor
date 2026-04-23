// rods/checkpoint — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/checkpoint.nr"

fn main() -> i64 {
    let cs: i64 = ckpt_new(10);
    if cs == 0 { print("FAIL ckpt_new"); return 1; };
    print("OK checkpoint_smoke");
    return 0;
}
