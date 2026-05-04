// =====================================================
// rods/graph — Classical graph algorithms
// =====================================================
// Import: import "stdlib/rods/graph.nr"
// Provides: graph construction with weighted edges, BFS, DFS,
//   Dijkstra, Bellman-Ford, topological sort, connected components,
//   Kruskal's MST, PageRank.
// =====================================================

#cfile "../runtime/graph_rt.c"

extern fn nuc_graph_new(n_nodes: i64) -> i64;
extern fn nuc_graph_add_edge(g: i64, u: i64, v: i64, w: i64);
extern fn nuc_graph_add_edge_undirected(g: i64, u: i64, v: i64, w: i64);
extern fn nuc_graph_bfs(g: i64, start: i64) -> i64;
extern fn nuc_graph_dfs(g: i64, start: i64) -> i64;
extern fn nuc_graph_dijkstra(g: i64, src: i64) -> i64;
extern fn nuc_graph_bellman_ford(g: i64, src: i64) -> i64;
extern fn nuc_graph_topo_sort(g: i64) -> i64;
extern fn nuc_graph_connected_components(g: i64) -> i64;
extern fn nuc_graph_mst_kruskal(g: i64) -> i64;
extern fn nuc_graph_pagerank(g: i64, damping: i64, iters: i64) -> i64;
extern fn nuc_graph_free(g: i64);
// v0.7.80 — RFC-0061 Tier 1: negative-cycle detection
extern fn nuc_graph_has_negative_cycle(g: i64, src: i64) -> i64;
extern fn nuc_graph_negative_cycle_path(g: i64, src: i64) -> i64;
// v0.7.81 — RFC-0061 Tier 1: adjacency-matrix view
extern fn nuc_graph_to_adjacency_matrix(g: i64) -> i64;
extern fn nuc_graph_from_adjacency_matrix(matrix: i64, n_nodes: i64) -> i64;
extern fn nuc_graph_adjacency_density(g: i64) -> i64;

fn graph_new(n_nodes: i64) -> i64 { return nuc_graph_new(n_nodes); }
fn graph_add_edge(g: i64, u: i64, v: i64, w: i64) { nuc_graph_add_edge(g, u, v, w); }
fn graph_add_edge_undirected(g: i64, u: i64, v: i64, w: i64) { nuc_graph_add_edge_undirected(g, u, v, w); }
fn graph_bfs(g: i64, start: i64) -> i64 { return nuc_graph_bfs(g, start); }
fn graph_dfs(g: i64, start: i64) -> i64 { return nuc_graph_dfs(g, start); }
fn graph_dijkstra(g: i64, src: i64) -> i64 { return nuc_graph_dijkstra(g, src); }
fn graph_bellman_ford(g: i64, src: i64) -> i64 { return nuc_graph_bellman_ford(g, src); }
fn graph_topo_sort(g: i64) -> i64 { return nuc_graph_topo_sort(g); }
fn graph_connected_components(g: i64) -> i64 { return nuc_graph_connected_components(g); }
fn graph_mst_kruskal(g: i64) -> i64 { return nuc_graph_mst_kruskal(g); }
fn graph_pagerank(g: i64, damping: i64, iters: i64) -> i64 { return nuc_graph_pagerank(g, damping, iters); }
fn graph_free(g: i64) { nuc_graph_free(g); }
// v0.7.80 — RFC-0061 Tier 1 wrappers (negative-cycle detection)
fn graph_has_negative_cycle(g: i64, src: i64) -> i64 { return nuc_graph_has_negative_cycle(g, src); }
fn graph_negative_cycle_path(g: i64, src: i64) -> i64 { return nuc_graph_negative_cycle_path(g, src); }
// v0.7.81 — RFC-0061 Tier 1 wrappers (adjacency-matrix view)
fn graph_to_adjacency_matrix(g: i64) -> i64 { return nuc_graph_to_adjacency_matrix(g); }
fn graph_from_adjacency_matrix(matrix: i64, n_nodes: i64) -> i64 { return nuc_graph_from_adjacency_matrix(matrix, n_nodes); }
fn graph_adjacency_density(g: i64) -> i64 { return nuc_graph_adjacency_density(g); }
