// rods/pgs — verify rod wrapper compiles + links (v0.2.228 ship).
// Build a tiny graph, exercise alloc/insert/optimize/free.
// Correctness coverage in the direct C unit test (4-node loop
// with simulated drift; Gauss-Newton reduces residual to near 0).
import "stdlib/rods/pgs.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;
    let g: i64 = pgs_new(3);
    if g == 0 { print("FAIL pgs_new"); return 1; };

    pgs_set_node(g, 0, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    pgs_set_node(g, 1, f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    pgs_set_node(g, 2, f64_to_bits(2.0), f64_to_bits(0.0), f64_to_bits(0.0));

    // Edge 0→1 says j is 1m forward: matches initial estimate exactly.
    let _e0: i64 = pgs_add_edge(g, 0, 1,
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    // Edge 1→2 same.
    let _e1: i64 = pgs_add_edge(g, 1, 2,
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));

    // No drift — initial cost should already be ≈ 0.
    let _initial_cost: i64 = pgs_total_cost(g);

    let _iters: i64 = pgs_optimize(g, 20, f64_to_bits(1e-9));

    pgs_free(g);
    if fail == 0 { print("OK pgs_smoke"); };
    return fail;
}
