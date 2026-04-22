// =====================================================
// rods/gnn — Graph Neural Network
// =====================================================
// GATv2Conv, GlobalAttention pooling, graph construction.
// Wraps gnn_rt.c via extern fn.
// Import: import "stdlib/rods/gnn.nr"
// =====================================================

#cfile "../runtime/gnn_rt.c"

// Graph data structure
extern fn nuc_gnn_graph_new(node_feats: i64, n_nodes: i64, feat_dim: i64, edge_src: i64, edge_dst: i64, n_edges: i64) -> i64;
extern fn nuc_gnn_graph_free(handle: i64) -> i64;
extern fn nuc_gnn_graph_n_nodes(handle: i64) -> i64;
extern fn nuc_gnn_circuit_to_graph(gates: i64, nq: i64) -> i64;

// GATv2Conv
extern fn nuc_gnn_gatv2_new(in_dim: i64, out_dim: i64) -> i64;
extern fn nuc_gnn_gatv2_forward(layer: i64, graph: i64) -> i64;
extern fn nuc_gnn_gatv2_backward(layer: i64, graph: i64, grad_out: i64) -> i64;
extern fn nuc_gnn_gatv2_adam_step(layer: i64, opt: i64, offset: i64) -> i64;
extern fn nuc_gnn_gatv2_zero_grad(layer: i64) -> i64;
extern fn nuc_gnn_gatv2_param_count(layer: i64) -> i64;

// Pooling
extern fn nuc_gnn_global_attn_new(dim: i64) -> i64;
extern fn nuc_gnn_global_attn_forward(pool: i64, node_feats: i64, n_nodes: i64) -> i64;
extern fn nuc_gnn_global_mean_pool(node_feats: i64, n_nodes: i64, dim: i64) -> i64;

// Utilities
extern fn nuc_gnn_layer_norm(vec: i64, dim: i64) -> i64;
extern fn nuc_gnn_relu(vec: i64) -> i64;
