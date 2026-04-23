// rods/diffusion — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/diffusion.nr"

fn main() -> i64 {
    let sched: i64 = diff_linear_schedule(10, 1, 100);
    if sched == 0 { print("FAIL diff_linear_schedule"); return 1; };
    print("OK diffusion_smoke");
    return 0;
}
