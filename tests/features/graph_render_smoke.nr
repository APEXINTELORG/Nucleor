// v0.8.192 stdlib/rods/graph_render.nr first test coverage.
//
// RFC-0061 Tier 2 Phase A graph-rendering format helpers (text /
// JSON / DOT / Mermaid). Sister to v0.8.149 `nuc deps graph`
// (Tier 2 implementation in tools_suite). Pre-v0.8.192: zero
// coverage on the rod surface.
//
// Locks five textbook format invariants on a 3-node graph
// (0 → 1, 1 → 2):
//   1. Format ID stable: text=1, json=2, dot=3, mermaid=4.
//   2. Format name round-trip: name(3) == "dot"; round-trip
//      via format_id matches.
//   3. DOT output: contains "digraph" or "->" markers.
//   4. JSON output: contains "nodes" + "edges" keys.
//   5. Mermaid output: contains "graph" keyword.
//
// Expected: rc=0.

import "stdlib/rods/graph_render.nr"
import "stdlib/rods/strings.nr"

fn check_format_ids() -> i64 {
    if graph_render_format_text() != 1 { return 1; };
    if graph_render_format_json() != 2 { return 2; };
    if graph_render_format_dot() != 3 { return 4; };
    if graph_render_format_mermaid() != 4 { return 8; };
    return 0;
}

fn check_format_name_round_trip() -> i64 {
    if str_eq(graph_render_format_name(3), "dot") != 1 { return 16; };
    if graph_render_format_id("dot") != 3 { return 32; };
    if graph_render_format_id("mermaid") != 4 { return 64; };
    if str_eq(graph_render_format_name(99), "unknown") != 1 { return 128; };
    return 0;
}

fn make_graph_3() -> i64 {
    let g: i64 = graph_new(3);
    graph_add_edge(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge(g, 1, 2, f64_to_bits(1.0));
    return g;
}

fn check_dot_format() -> i64 {
    let g: i64 = make_graph_3();
    let names: Vec<str> = graph_render_anon_names();
    let s: str = graph_render_dot(g, names);
    graph_free(g);
    if strings_index_of(s, "->") < 0 { return 256; };
    return 0;
}

fn check_json_format() -> i64 {
    let g: i64 = make_graph_3();
    let names: Vec<str> = graph_render_anon_names();
    let s: str = graph_render_json(g, names);
    graph_free(g);
    if strings_index_of(s, "nodes") < 0 { return 512; };
    if strings_index_of(s, "edges") < 0 { return 1024; };
    return 0;
}

fn check_mermaid_format() -> i64 {
    let g: i64 = make_graph_3();
    let names: Vec<str> = graph_render_anon_names();
    let s: str = graph_render_mermaid(g, names);
    graph_free(g);
    if strings_index_of(s, "graph") < 0 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_format_ids();
    fails = fails + check_format_name_round_trip();
    fails = fails + check_dot_format();
    fails = fails + check_json_format();
    fails = fails + check_mermaid_format();
    return fails;
}
