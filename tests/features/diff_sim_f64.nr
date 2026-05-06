// stdlib/rods/diff_sim — `*_f64` ergonomic wrappers smoke test.
//
// v0.4.267: closes the f64-arc started in v0.4.260. Build a
// 2-qubit clean-mode differentiable simulator, apply a couple
// of gates via the f64-typed `diff_gate_f64` (angle in radians),
// run a backward pass via `diff_backward_f64`, and check the
// gate count round-trips.
//
// Mode bits = 0 (clean, no noise) so the gate-importance /
// noisy-gate counts are simple. Gate types follow the runtime's
// enum (RZ = 6 in `diff_sim_rt.c` v0.2.150 onward).
//
// EXPECT: build success, runtime exit 0, output "OK diff_sim_f64".

import "stdlib/rods/diff_sim.nr"

fn main() -> i32 {
    // 2 qubits, 2 cores, clean mode (mode_bits = 0), seed 42.
    let h: i64 = diff_sim_init(2, 2, 0, 42);
    if h == 0 { print("FAIL diff_sim_init"); return 1; };

    // Initially zero gates.
    if diff_n_gates(h) != 0 { print("FAIL initial gate count"); return 1; };

    // Apply two RZ gates via the f64 wrapper. Gate-type 6
    // matches the runtime's RZ slot (single-qubit rotation
    // about z by `angle`). q1 is unused for single-qubit
    // gates but required by the signature shape.
    diff_gate_f64(h, 6, 0, 0, 0.5);
    diff_gate_f64(h, 6, 1, 0, 1.0);

    // Two gates registered.
    if diff_n_gates(h) != 2 { print("FAIL n_gates after 2"); return 1; };

    // Backward pass with a unit gradient. Doesn't move logits
    // in clean mode (no noisy gates) but exercises the f64
    // wrapper call path.
    diff_backward_f64(h, 1.0);

    diff_free(h);

    print("OK diff_sim_f64");
    0
}
