// rods/gpu — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/gpu.nr"

fn main() -> i64 {
    // gpu_available returns 0 (no GPU on CI) or 1; either is OK
    let _avail: i64 = gpu_available();
    print("OK gpu_smoke");
    return 0;
}
