// v0.7.78 RFC-0061 Tier 1 smoke fixture — gnn rod canonical
// wrapper-fn surface. The RFC-0061 spec called out
// `gnn_circuit_to_graph` as a missing wrapper (extern existed,
// safe-name fn did not). v0.7.78 adds that wrapper plus the
// paired surface so adopters can use the rod's canonical names.
//
// This fixture compiles a reference to each wrapper to verify
// the surface is callable; no runtime invocation (which would
// require valid gate / param handles).
import "stdlib/rods/gnn.nr"

fn ref_all() -> i64 {
    let mut sink: i64 = 0;
    if 0 == 1 { sink = sink + gnn_circuit_to_graph(0, 0); };
    if 0 == 1 { sink = sink + gnn_graph_n_nodes(0); };
    if 0 == 1 { sink = sink + gnn_graph_new(0, 0, 0, 0, 0, 0); };
    if 0 == 1 { sink = sink + gnn_graph_free(0); };
    if 0 == 1 { sink = sink + gnn_gatv2_new(0, 0); };
    if 0 == 1 { sink = sink + gnn_gatv2_forward(0, 0); };
    if 0 == 1 { sink = sink + gnn_gatv2_zero_grad(0); };
    if 0 == 1 { sink = sink + gnn_gatv2_param_count(0); };
    if 0 == 1 { sink = sink + gnn_global_attn_new(0); };
    if 0 == 1 { sink = sink + gnn_global_mean_pool(0, 0, 0); };
    if 0 == 1 { sink = sink + gnn_layer_norm(0, 0); };
    if 0 == 1 { sink = sink + gnn_relu(0); };
    return sink;
}

fn main() -> i64 {
    return ref_all();
}
