// rods/rrt — verify rod wrapper compiles + links (v0.2.179 ship).
// Build-only smoke; full RRT planning needs a callback function
// pointer + double[] vars not easily set up in a single test file.
import "stdlib/rods/rrt.nr"

fn main() -> i64 {
    let r: i64 = rrt_new(2, 42);
    if r == 0 { print("FAIL rrt_new"); return 1; };
    if rrt_node_count(r) != 0 { print("FAIL initial node count"); return 1; };
    rrt_free(r);
    print("OK rrt_smoke");
    return 0;
}
