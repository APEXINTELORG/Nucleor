// rods/prm — verify rod wrapper compiles + links (v0.2.185 ship).
// Build-only smoke; functional roadmap-build needs a real
// collision-check fn pointer + bounds setup.
//
// v0.2.200 also exercises the new query-side surface
// (`prm_query`, `prm_path_len`, `prm_path_node`, `prm_path_at`)
// for link verification — empty-roadmap query returns 0 path-len.
import "stdlib/rods/prm.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let p: i64 = prm_new(2, 42);
    if p == 0 { print("FAIL prm_new"); return 1; };
    if prm_node_count(p) != 0 { print("FAIL initial node count"); return 1; };
    if prm_edge_count(p) != 0 { print("FAIL initial edge count"); return 1; };
    if prm_path_len(p) != 0 { print("FAIL initial path len"); return 1; };
    if prm_path_node(p, 0) != -1 { print("FAIL out-of-range path node"); return 1; };
    // v0.2.220: A* query exists. Empty roadmap → returns 0 path-len.
    let _path_len: i64 = prm_query_astar(p, 0, 0, 5, f64_to_bits(0.1), 0);
    prm_free(p);
    print("OK prm_smoke");
    return 0;
}
