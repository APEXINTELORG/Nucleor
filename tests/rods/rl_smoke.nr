// rods/rl — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/rl.nr"

fn main() -> i64 {
    let rb: i64 = rl_replay_new(100, 4);
    if rb == 0 { print("FAIL rl_replay_new"); return 1; };
    let n: i64 = rl_replay_size(rb);
    if n != 0 { print("FAIL rl_replay_size_initial"); return 1; };
    print("OK rl_smoke");
    return 0;
}
