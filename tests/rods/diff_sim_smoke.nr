// rods/diff_sim — verify rod wrapper compiles + links (v0.2.150 wrap)
import "stdlib/rods/diff_sim.nr"

fn main() -> i64 {
    let h: i64 = diff_sim_init(2, 2, 0, 42);
    if h == 0 { print("FAIL diff_sim_init"); return 1; };
    if diff_n_gates(h) != 0 { print("FAIL diff_n_gates initial"); return 1; };
    diff_free(h);
    print("OK diff_sim_smoke");
    return 0;
}
