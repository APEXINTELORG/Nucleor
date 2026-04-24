// rods/astar — verify rod wrapper compiles + links (v0.2.186 ship).
// Build-only smoke; functional A* needs callback fn pointers
// for neighbor + heuristic which are non-trivial to set up
// in a single test file.
import "stdlib/rods/astar.nr"

fn main() -> i64 {
    let a: i64 = astar_new(10);
    if a == 0 { print("FAIL astar_new"); return 1; };
    if astar_path_len(a) != 0 { print("FAIL initial path_len"); return 1; };
    astar_free(a);
    print("OK astar_smoke");
    return 0;
}
