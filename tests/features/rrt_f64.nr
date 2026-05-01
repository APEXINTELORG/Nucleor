// stdlib/rods/rrt — `*_f64` ergonomic wrappers smoke test.
//
// v0.4.265: build-only smoke that exercises rrt_set_bounds_f64.
// Full RRT planning needs a callback fn pointer + double[]
// vars — those keep the bits-ABI for now. This fixture confirms
// the f64-typed bound setter compiles + links + the planner
// constructor + node-count round-trip works through the
// f64-wrapper call site.
//
// EXPECT: build success, runtime exit 0, output "OK rrt_f64".

import "stdlib/rods/rrt.nr"

fn main() -> i32 {
    let r: i64 = rrt_new(2, 42);
    if r == 0 { print("FAIL rrt_new"); return 1; };

    // Set 2D joint bounds via the f64 wrapper:
    //   dim 0: [-1.0, 1.0]
    //   dim 1: [-3.14, 3.14]
    rrt_set_bounds_f64(r, 0, 0.0 - 1.0, 1.0);
    rrt_set_bounds_f64(r, 1, 0.0 - 3.14, 3.14);

    // Initial tree is empty.
    if rrt_node_count(r) != 0 { print("FAIL initial node count"); return 1; };

    rrt_free(r);

    print("OK rrt_f64");
    0
}
