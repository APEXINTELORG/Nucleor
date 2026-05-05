// v0.8.148 RFC-0061 Tier 1 — gnn_circuit_to_graph smoke fixture.
//
// Locks the gnn rod's canonical wrapper for converting a quantum
// circuit (gates as [type, q0, q1] triples) into a GNN graph
// where each node is a gate and edges connect gates on the same
// qubit wire (data-dependence).
//
// Lock conditions:
//   1. circuit_to_graph on a 3-gate H-CNOT-H circuit produces a
//      valid graph handle (non-zero).
//   2. graph has 3 nodes (one per gate).
//   3. graph_free succeeds (no leak / no fault).
//
// Expected: rc=0.

import "stdlib/rods/gnn.nr"

fn main() -> i64 {
    // Bell-state circuit: H q0; CNOT q0,q1; H q0
    // Gate type encoding: 0=H, 1=CNOT (per gnn_rt.c)
    let mut gates: Vec<i64> = Vec::new();
    // H q0
    gates.push(0); gates.push(0); gates.push(0 - 1);
    // CNOT q0 -> q1
    gates.push(1); gates.push(0); gates.push(1);
    // H q0
    gates.push(0); gates.push(0); gates.push(0 - 1);
    let g: i64 = gnn_circuit_to_graph(gates, 2);
    if g == 0 { return 1; };
    if gnn_graph_n_nodes(g) != 3 { gnn_graph_free(g); return 2; };
    gnn_graph_free(g);
    return 0;
}
